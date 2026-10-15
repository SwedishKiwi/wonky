import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show OfflineSyncSubscription;
import 'package:wonky_app/wonky_app.dart' show LocalStore, isOfflineError;
import 'package:wonky_client/wonky_client.dart'
    show SpaceStats, SubscribeResult, UuidValue;
import 'package:wonky_core/wonky_core.dart' show UuidV7Generator;

import '../replica/sync_replica.dart';
import '../writer/sync_writer.dart';
import 'sync_remote.dart';
import 'sync_session_host.dart';

/// A cap on the rows of one table kept on the device (the IndexedDB
/// fallback of the web keeps the whole database in memory, suite 12 intro):
/// above it, the files opened least recently leave the active set.
final class DeviceRowCap {
  const DeviceRowCap({required this.table, required this.maxRows});

  /// The counted table (Sheets: `cell`).
  final String table;

  /// Max visible rows of [table] on the device.
  final int maxRows;
}

/// The signed-in user's sync of one app (suite 12 §2.5, Slides 02 §9):
/// owns the replica `<app>_<userId>.db`, keeps it in sync through the app's
/// custom sync endpoint while the app is visible and online, and hosts the
/// open file sessions.
///
/// Lifecycle of the loop: pending-change guard (`ensureSubscribed` for
/// spaces with local writes) → `syncOnce` → reservation refill →
/// `syncContinuously` until the stream ends → reconnect with backoff (1 s →
/// 30 s, jitter). Going offline (incl. *Simulate offline*) cancels the
/// stream; coming back online wakes the loop. [setVisible] (false) pauses
/// after [hiddenGrace]. After a sync: the device cap ([enforceRowCap]) and
/// the weekly purge of hidden spaces ([purgeHiddenSpaces]).
///
/// Apps subclass it with their replica, writer and session types and add
/// file creation (on [createInReservedSpace]) and session opening (on
/// [registerSession]).
class AppSyncController<
  R extends SyncReplica,
  W extends SyncWriter,
  S extends HostedSpaceSession
>
    implements SyncSessionHost<R, W> {
  AppSyncController({
    required this.replica,
    required this.writer,
    required this.remote,
    required this.connectivity,
    required this.name,
    String? sessionId,
    this.reservationTarget = 3,
    this.hiddenGrace = const Duration(seconds: 30),
    this.rowCap,
    this.lastOpened,
    this.maintenanceStore,
    Random? random,
  }) : sessionId = sessionId ?? UuidV7Generator.instance.nextString(),
       _random = random ?? Random() {
    connectivity.online.addListener(_onConnectivity);
  }

  @override
  final R replica;

  @override
  final W writer;

  final SyncRemote remote;
  final SyncConnectivity connectivity;

  /// The app's key (`sheets`, `slides`): log messages and the
  /// [maintenanceStore] keys.
  final String name;

  @override
  final String sessionId;

  /// Reserved spaces kept per device for offline creation.
  final int reservationTarget;

  /// How long sync keeps running after the app was hidden.
  final Duration hiddenGrace;

  /// The device cap (null = unlimited), [enforceRowCap].
  final DeviceRowCap? rowCap;

  /// When each file (space UUID) was last opened on this device, for
  /// [enforceRowCap].
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

  /// Whether [close] ran.
  bool get isClosed => _closed;

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
    _pruneTimer?.cancel();
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
      debugPrint('Cancelling the $name sync stream failed: $e');
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
        debugPrint('$name sync failed: $e');
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

  /// After a sync: the device cap ([enforceRowCap]) and the weekly purge of
  /// hidden spaces ([purgeHiddenSpaces]). Errors are logged.
  Future<void> runMaintenance() => _maintenance ??= () async {
    try {
      await enforceRowCap();
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
      debugPrint('$name maintenance failed: $e');
    }
  }().whenComplete(() => _maintenance = null);

  String get _purgeKey => '$name.lastPurge';

  /// Files this device stopped keeping (device cap), most recent run.
  final List<UuidValue> evicted = [];

  Set<UuidValue> get _openSpaces => {
    for (final s in _sessions)
      if (!s.isDisposed) s.spaceUuid,
  };

  /// Keeps the device under [rowCap]: leaves the active set of the files
  /// opened least recently that are not open, have no unsynced writes and
  /// aren't the personal space, then purges them. The server keeps owned
  /// files on their owner's devices (they stay and are not asked again).
  Future<void> enforceRowCap() async {
    final cap = rowCap;
    if (cap == null || replica.isClosed) return;
    final counts = await replica.rowCountsBySpace(cap.table);
    var total = counts.values.fold(0, (a, b) => a + b);
    if (total <= cap.maxRows) return;
    final open = _openSpaces;
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
      if (total <= cap.maxRows) break;
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
    final open = _openSpaces;
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

  /// Creates a file in a usable reserved space (works offline): [create]
  /// writes the file's first rows into the space; the reservation is then
  /// used up and the pool refilled. Throws [NoReservedSpaceException] when
  /// no reservation is usable. Registering the file in the drive is the
  /// caller's job.
  Future<UuidValue> createInReservedSpace(
    Future<void> Function(UuidValue space) create,
  ) async {
    final usable = await replica.usableReservations();
    if (usable.isEmpty) throw const NoReservedSpaceException();
    final space = usable.first;
    await create(space);
    await replica.removeReservation(space);
    kick();
    if (connectivity.online.value) unawaited(refillReservations());
    return space;
  }

  // ------------------------------------------------------------- sessions

  final List<S> _sessions = [];

  /// Tracks [session] (open set for maintenance, journal cursors).
  @protected
  S registerSession(S session) {
    _sessions.add(session);
    return session;
  }

  /// Open sessions (diagnostics).
  List<S> get sessions => List.unmodifiable(_sessions);

  @override
  Future<SubscribeResult> subscribe(UuidValue itemUuid) async {
    if (!connectivity.online.value) throw const SyncOfflineException();
    try {
      final r = await remote.subscribe(itemUuid);
      connectivity.reportSuccess();
      return r;
    } catch (e) {
      if (isOfflineError(e)) {
        connectivity.reportFailure();
        throw const SyncOfflineException();
      }
      rethrow;
    }
  }

  @override
  Future<SpaceStats> spaceStats(UuidValue itemUuid) async {
    if (!connectivity.online.value) throw const SyncOfflineException();
    try {
      return await remote.spaceStats(itemUuid);
    } catch (e) {
      if (isOfflineError(e)) throw const SyncOfflineException();
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
      final cursors = [for (final s in _sessions) ?s.cursor];
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
