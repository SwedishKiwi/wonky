import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show OfflineSyncSubscription;
import 'package:wonky_app/wonky_app.dart' show LocalStore, isOfflineError;
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' show Role, UuidV7Generator;
import 'package:wonky_sheets_core/model.dart';

import 'sheets_remote.dart';
import 'sheets_replica.dart';
import 'sheets_session_host.dart';
import 'sheets_writer.dart';
import 'synced_workbook_session.dart';

/// Connection state for the controller (the shell's `ConnectivityService`
/// in the app, a plain notifier in tests).
abstract interface class SheetsConnectivity {
  /// Whether the server is reachable (false while *Simulate offline*).
  ValueListenable<bool> get online;

  void reportFailure();
  void reportSuccess();
}

/// Thrown by [SheetsSyncController.createLocalSpreadsheet] when no reserved
/// space is usable (offline before the first reservation arrived).
class NoReservedSpaceException implements Exception {
  const NoReservedSpaceException();

  @override
  String toString() =>
      'NoReservedSpaceException: connect to the internet to create a '
      'spreadsheet.';
}

/// The signed-in user's Sheets sync (suite 12 §2.5): owns the replica
/// `sheets_<userId>.db`, keeps it in sync through the custom
/// `sheetsSync.sync` endpoint while the app is visible and online, and
/// hosts the open [SyncedWorkbookSession]s.
///
/// Lifecycle of the loop: pending-change guard (`ensureSubscribed` for
/// spaces with local writes) → `syncOnce` → reservation refill →
/// `syncContinuously` until the stream ends → reconnect with backoff (1 s →
/// 30 s, jitter). Going offline (incl. *Simulate offline*) cancels the
/// stream; coming back online wakes the loop. [setVisible] (false) pauses
/// after [hiddenGrace].
class SheetsSyncController implements SheetsSessionHost {
  SheetsSyncController({
    required this.replica,
    required this.remote,
    required this.connectivity,
    String? sessionId,
    this.reservationTarget = 3,
    this.hiddenGrace = const Duration(seconds: 30),
    this.cellCap,
    this.lastOpened,
    this.maintenanceStore,
    Random? random,
  }) : sessionId = sessionId ?? UuidV7Generator.instance.nextString(),
       _random = random ?? Random() {
    writer = SheetsWriter(replica);
    connectivity.online.addListener(_onConnectivity);
  }

  @override
  final SheetsReplica replica;
  final SheetsRemote remote;
  final SheetsConnectivity connectivity;

  @override
  late final SheetsWriter writer;

  @override
  final String sessionId;

  /// Reserved spaces kept per device for offline creation.
  final int reservationTarget;

  /// How long sync keeps running after the app was hidden.
  final Duration hiddenGrace;

  /// Max cells kept on this device (the IndexedDB fallback of the web,
  /// suite 12 intro; null = unlimited). Above it, the spreadsheets opened
  /// least recently leave the active set ([enforceCellCap]).
  final int? cellCap;

  /// When each spreadsheet (space UUID) was last opened on this device
  /// (the `LocalViewState` times), for [enforceCellCap].
  final Future<Map<String, DateTime>> Function()? lastOpened;

  /// Where the time of the last weekly purge is kept (the user store).
  final LocalStore? maintenanceStore;

  /// How often hidden spaces' rows are purged (suite 12 §2.3).
  static const purgeInterval = Duration(days: 7);

  final Random _random;

  @override
  ValueListenable<bool> get online => connectivity.online;

  final StreamController<UuidValue> _merges = StreamController.broadcast();

  @override
  Stream<UuidValue> get merges => _merges.stream;

  /// Whether a continuous sync stream is up.
  final ValueNotifier<bool> connected = ValueNotifier(false);

  /// Completed sync cycles (`syncOnce` or a continuous round with merges).
  final ValueNotifier<int> cycles = ValueNotifier(0);

  /// The last sync error (null after a successful cycle).
  final ValueNotifier<Object?> lastError = ValueNotifier(null);

  bool _running = false;
  bool _visible = true;
  bool _closed = false;
  Future<void>? _loop;
  OfflineSyncSubscription? _subscription;
  Completer<void>? _wake;
  Timer? _hiddenTimer;
  int _failures = 0;
  Future<void>? _refill;

  // ------------------------------------------------------------ lifecycle

  /// Starts syncing (idempotent).
  void start() {
    if (_closed || _running) return;
    _running = true;
    final loop = _syncLoop();
    _loop = loop;
    unawaited(loop.whenComplete(() => _loop = null));
  }

  /// Stops syncing; local reads and writes keep working.
  Future<void> stop() async {
    _running = false;
    _wakeUp();
    await _cancelStream();
    await _loop;
  }

  /// Stops syncing, closes the sessions and the replica.
  Future<void> close() async {
    if (_closed) return;
    await stop();
    _closed = true;
    _hiddenTimer?.cancel();
    connectivity.online.removeListener(_onConnectivity);
    for (final s in List.of(_sessions)) {
      await s.dispose();
    }
    await _merges.close();
    await replica.close();
  }

  /// The app became visible / hidden (web `visibilitychange`, desktop
  /// lifecycle): hidden for [hiddenGrace] pauses sync.
  void setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    _hiddenTimer?.cancel();
    if (visible) {
      if (_closed) return;
      start();
      _wakeUp();
    } else {
      _hiddenTimer = Timer(hiddenGrace, () => unawaited(stop()));
    }
  }

  @override
  void kick() => _wakeUp();

  void _onConnectivity() {
    if (connectivity.online.value) {
      _wakeUp();
    } else {
      unawaited(_cancelStream());
    }
  }

  void _wakeUp() {
    final w = _wake;
    if (w != null && !w.isCompleted) w.complete();
  }

  Future<void> _cancelStream() async {
    final s = _subscription;
    _subscription = null;
    try {
      await s?.cancel();
    } catch (e) {
      debugPrint('Cancelling the Sheets sync stream failed: $e');
    }
  }

  Future<void> _waitForWake(Duration? delay) async {
    final w = _wake = Completer<void>();
    await Future.any<void>([
      w.future,
      if (delay != null) Future<void>.delayed(delay),
    ]);
    _wake = null;
  }

  /// Backoff for the [n]th consecutive failure (1 s → 30 s, ±20 %).
  @visibleForTesting
  Duration backoff(int n) {
    final base = min(30.0, pow(2, max(0, n - 1)).toDouble());
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    return Duration(milliseconds: (base * 1000 * jitter).round());
  }

  Future<void> _syncLoop() async {
    while (_running && !_closed) {
      if (!connectivity.online.value) {
        await _waitForWake(null);
        continue;
      }
      try {
        await syncNow();
        if (!_running || !connectivity.online.value) continue;
        unawaited(refillReservations());
        unawaited(runMaintenance());
        final sub = remote.sync.syncContinuously(
          replica.session,
          onMergeSuccess: _onMerged,
        );
        _subscription = sub;
        connected.value = true;
        await sub.done;
        _failures = 0;
      } catch (e) {
        _failures++;
        lastError.value = e;
        if (isOfflineError(e)) connectivity.reportFailure();
        debugPrint('Sheets sync failed: $e');
      } finally {
        _subscription = null;
        connected.value = false;
      }
      if (_running && !_closed) {
        // A normal end (server restart, cancelled while going offline)
        // reconnects after a second; failures back off.
        await _waitForWake(
          _failures == 0 ? const Duration(seconds: 1) : backoff(_failures),
        );
      }
    }
  }

  /// One complete sync cycle with the pending-change guard first. Clears
  /// the dirty marks of spaces that are still members afterwards.
  Future<void> syncNow() async {
    final started = clock.now();
    final dirty = await replica.dirtySpaces();
    if (dirty.isNotEmpty) {
      await remote.ensureSubscribed(dirty);
    }
    await remote.sync.syncOnce(replica.session, onMergeSuccess: _onMerged);
    connectivity.reportSuccess();
    lastError.value = null;
    cycles.value++;
    if (dirty.isNotEmpty) {
      final members = await replica.memberSpaces();
      await replica.clearDirty(dirty.where(members.contains), started);
    }
  }

  Future<void> _onMerged(UuidValue space, Object _) async {
    if (!_merges.isClosed) _merges.add(space);
  }

  // ----------------------------------------------------------- maintenance

  Future<void>? _maintenance;
  final Set<UuidValue> _capTried = {};

  /// After a sync: the cell cap ([enforceCellCap]) and the weekly purge of
  /// hidden spaces ([purgeHiddenSpaces]). Errors are logged.
  Future<void> runMaintenance() => _maintenance ??= () async {
    try {
      await enforceCellCap();
      final store = maintenanceStore;
      final last = store == null
          ? null
          : DateTime.tryParse('${await store.read(_purgeKey) ?? ''}');
      final now = clock.now();
      if (last == null || now.difference(last) >= purgeInterval) {
        await purgeHiddenSpaces();
        await store?.write(_purgeKey, now.toUtc().toIso8601String());
      }
    } catch (e) {
      debugPrint('Sheets maintenance failed: $e');
    }
  }().whenComplete(() => _maintenance = null);

  static const _purgeKey = 'sheets.lastPurge';

  /// Spreadsheets this device stops keeping (cell cap), most recent run.
  final List<UuidValue> evicted = [];

  /// Keeps the device under [cellCap] cells: leaves the active set of the
  /// spreadsheets opened least recently that are not open, have no
  /// unsynced writes and aren't the personal space, then purges them. The
  /// server keeps owned spreadsheets on their owner's devices (they stay
  /// and are not asked again).
  Future<void> enforceCellCap() async {
    final cap = cellCap;
    if (cap == null || replica.isClosed) return;
    final counts = await replica.cellCountsBySpace();
    var total = counts.values.fold(0, (a, b) => a + b);
    if (total <= cap) return;
    final open = {
      for (final s in _sessions)
        if (!s.isDisposed) s.spaceUuid,
    };
    final dirty = (await replica.dirtySpaces()).toSet();
    final opened = await lastOpened?.call() ?? const {};
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final candidates =
        [
          for (final space in counts.keys)
            if (!open.contains(space) &&
                !dirty.contains(space) &&
                space != replica.userUuid &&
                !_capTried.contains(space))
              space,
        ]..sort(
          (a, b) =>
              (opened[a.uuid] ?? epoch).compareTo(opened[b.uuid] ?? epoch),
        );
    for (final space in candidates) {
      if (total <= cap) break;
      _capTried.add(space);
      try {
        await remote.unsubscribe(space);
        total -= counts[space] ?? 0;
        evicted.add(space);
      } catch (e) {
        if (isOfflineError(e)) return;
        debugPrint('Unsubscribing $space failed: $e');
      }
    }
    if (evicted.isNotEmpty) kick();
  }

  /// Deletes the rows of spaces that are no longer members of this device
  /// (evicted, unshared, trashed) and have no unsynced writes. Returns the
  /// purged spaces.
  Future<List<UuidValue>> purgeHiddenSpaces() async {
    if (replica.isClosed) return const [];
    final dirty = (await replica.dirtySpaces()).toSet();
    final open = {
      for (final s in _sessions)
        if (!s.isDisposed) s.spaceUuid,
    };
    final purged = <UuidValue>[];
    for (final (key, space) in await replica.hiddenSpaces()) {
      if (dirty.contains(space) ||
          open.contains(space) ||
          space == replica.userUuid) {
        continue;
      }
      await replica.purgeSpace(key);
      purged.add(space);
    }
    return purged;
  }

  // --------------------------------------------------------- reservations

  /// Tops the pool of reserved spaces up to [reservationTarget] (online).
  /// New reservations are usable once the next cycle delivers membership.
  Future<void> refillReservations() => _refill ??= () async {
    try {
      final have = (await replica.reservations()).length;
      final missing = reservationTarget - have;
      if (missing <= 0) return;
      final spaces = await remote.reserveSpaces(missing);
      await replica.addReservations(spaces);
      if (spaces.isNotEmpty) kick();
    } catch (e) {
      if (isOfflineError(e)) connectivity.reportFailure();
      debugPrint('Reserving spaces failed: $e');
    }
  }().whenComplete(() => _refill = null);

  /// Creates a spreadsheet in a usable reserved space (works offline):
  /// writes the `CreateSpreadsheet` plan (spreadsheet row, one sheet of
  /// 1,000 × 26) and returns the space (= spreadsheet id). Registering it
  /// in the drive is the caller's job (`drive.registerSpreadsheet`).
  Future<UuidValue> createLocalSpreadsheet({
    required String title,
    String locale = 'en_US',
    String timeZone = 'UTC',
    String? fontFamily,
    double? fontSize,
  }) async {
    final usable = await replica.usableReservations();
    if (usable.isEmpty) throw const NoReservedSpaceException();
    final space = usable.first;
    final model = WorkbookModel(spreadsheetId: space.uuid);
    final plan = const SheetsMutationPlanner().plan(
      CreateSpreadsheet(
        spreadsheetId: space.uuid,
        title: title,
        locale: locale,
        timeZone: timeZone,
        fontFamily: fontFamily,
        fontSize: fontSize,
      ),
      model,
      PlanContext(userId: replica.userUuid.uuid, now: clock.now().toUtc()),
    );
    await writer.write(
      spaceId: space,
      changes: plan.changes,
      plan: plan,
      label: plan.label,
      actorKind: 'user',
      sessionId: sessionId,
    );
    await replica.removeReservation(space);
    kick();
    if (connectivity.online.value) unawaited(refillReservations());
    return space;
  }

  // ------------------------------------------------------------- sessions

  final List<SyncedWorkbookSession> _sessions = [];

  /// Opens a session on [spaceUuid] (see [SyncedWorkbookSession.open]).
  SyncedWorkbookSession openSession({
    required UuidValue itemUuid,
    required UuidValue spaceUuid,
    Role role = Role.viewer,
    int maxCells = 1000000,
    ViewportHint? viewport,
  }) {
    final s = SyncedWorkbookSession.open(
      this,
      itemUuid: itemUuid,
      spaceUuid: spaceUuid,
      role: role,
      maxCells: maxCells,
      viewport: viewport,
    );
    _sessions.add(s);
    return s;
  }

  /// Open sessions (diagnostics).
  List<SyncedWorkbookSession> get sessions => List.unmodifiable(_sessions);

  @override
  Future<SubscribeResult> subscribe(UuidValue itemUuid) async {
    if (!connectivity.online.value) throw const SheetsOfflineException();
    try {
      final r = await remote.subscribe(itemUuid);
      connectivity.reportSuccess();
      return r;
    } catch (e) {
      if (isOfflineError(e)) {
        connectivity.reportFailure();
        throw const SheetsOfflineException();
      }
      rethrow;
    }
  }

  @override
  Future<SpaceStats> spaceStats(UuidValue itemUuid) async {
    if (!connectivity.online.value) throw const SheetsOfflineException();
    try {
      return await remote.spaceStats(itemUuid);
    } catch (e) {
      if (isOfflineError(e)) throw const SheetsOfflineException();
      rethrow;
    }
  }

  Timer? _pruneTimer;

  @override
  void journalCursorsChanged() {
    _sessions.removeWhere((s) => s.cursor == null && s.isDisposed);
    _pruneTimer?.cancel();
    _pruneTimer = Timer(const Duration(seconds: 2), () async {
      if (replica.isClosed) return;
      final cursors = [
        for (final s in _sessions)
          if (s.cursor != null) s.cursor!,
      ];
      final upTo = cursors.isEmpty
          ? await replica.journal.head()
          : cursors.reduce(min);
      try {
        await replica.journal.prune(upTo);
      } catch (e) {
        debugPrint('Pruning the change journal failed: $e');
      }
    });
  }
}
