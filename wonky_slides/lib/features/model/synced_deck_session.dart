import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart'
    show SpaceStats, SubscribeResult, UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides_core/interfaces.dart' show SlideImageResolver;
import 'package:wonky_slides_core/maintenance.dart' show DeckMaintenance;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart' show SlidesTables;
import 'package:wonky_sync_kit/rows.dart' show RowChange;
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show HostedSpaceSession, JournalIngestion, SpaceOpening, SpaceWriteQueue;

import '../sync/deck_remote_patch.dart';
import '../sync/slides_replica.dart';
import '../sync/slides_session_host.dart';
import 'deck_session.dart';
import 'memory_deck_session.dart';

/// The user-facing messages of a [SyncedDeckSession]'s load states
/// (localized by `openDeckSession` from the Slides ARB files; English
/// defaults for tests).
@immutable
class SyncedDeckStrings {
  const SyncedDeckStrings({
    this.downloading = 'Downloading presentation…',
    this.opening = _openingEn,
    this.notAvailableOffline = 'This presentation isn’t available offline.',
    this.noAccess = 'You don’t have access to this presentation.',
    this.downloadFailed = 'This presentation could not be downloaded.',
    this.openFailed = 'This presentation could not be opened.',
    this.notOnDevice = 'This presentation isn’t on this device.',
    this.accessRemoved = 'You no longer have access to this presentation.',
    this.stillOpening = 'The presentation is still opening.',
  });

  /// [DeckLoading] message while the deck downloads (with a progress).
  final String downloading;

  /// [DeckLoading] message while the rows are read (rows read so far).
  final String Function(int rows) opening;

  final String notAvailableOffline;
  final String noAccess;
  final String downloadFailed;
  final String openFailed;
  final String notOnDevice;
  final String accessRemoved;

  /// `PlanException` message for writes before the deck is ready.
  final String stillOpening;

  static String _openingEn(int rows) => 'Opening presentation… ($rows rows)';
}

/// A [DeckSession] on the synced local replica (Slides 02 §9, §11–12; suite
/// 12 §2). Mirrors Sheets' `SyncedWorkbookSession` on the shared kit's
/// building blocks.
///
/// Opening: `slides.subscribe(itemUuid)` when online (grants membership —
/// membership is the subscription — and returns the role and row counts),
/// then waits for the deck to arrive ([DeckLoading] "Downloading
/// presentation… 42 %" from local vs server row counts,
/// `SpaceOpening.waitForSpace`), loads **every** row of the deck into
/// [model] (decks are small: no viewport-first loading, 02 §9.1) and turns
/// [DeckReady]. A deck already on the device opens at once, also offline;
/// one that isn't on the device while offline is [DeckUnavailable]
/// (`offline: true`) and opens by itself when the connection returns.
///
/// Writes: the model is updated synchronously by the core `DeckWritePath`;
/// [persist] queues the changes for the `SlidesWriter` (≤ 5,000 changes per
/// transaction plus the `DeckChangeLog` row), strictly in order (the kit's
/// [SpaceWriteQueue]); [flush] awaits the queue; [syncStatus] mirrors it.
///
/// Remote changes: after every merge of the deck, the rows the change
/// journal recorded since the session's cursor are re-read and patched into
/// the model ([DeckRemotePatch] driven by the kit's [JournalIngestion]);
/// queued local writes are overlaid so an optimistic edit never flickers
/// back. The patch is applied with `applyRemote` and so arrives on
/// [remoteBatches].
///
/// Maintenance: [DeckMaintenance] repairs (02 §10) are written by editors
/// one second after merges ([runMaintenance]).
///
/// Role: the subscribe result, then the membership cache after every
/// ingestion (`SpaceOpening.roleFromMembership`); a removed membership
/// turns the open deck [DeckUnavailable], and a membership that returns
/// (unshare + reshare) reloads the deck and turns it [DeckReady] again.
class SyncedDeckSession extends DeckSessionBase implements HostedSpaceSession {
  SyncedDeckSession._(
    this.host, {
    required super.itemUuid,
    required super.userId,
    required super.model,
    required super.planner,
    required this.spaceUuid,
    required this.strings,
    super.role,
    super.images,
  }) {
    _writes = SpaceWriteQueue(
      writer: host.writer,
      spaceUuid: spaceUuid,
      sessionId: host.sessionId,
      onStored: host.kick,
      onFailed: (_) {
        // The optimistic model change was not stored: bring the model back
        // in line with the replica.
        _ingestion.needsReload = true;
        unawaited(ingestRemote());
      },
      onChanged: _updateStatus,
    );
    _ingestion = JournalIngestion(
      host: host,
      modelTables: _modelTables,
      applyRows: _applyJournalRows,
      reloadRows: _reloadRows,
      isDisposed: () => _disposed,
      afterIngest: _syncRoleFromMembership,
    );
  }

  /// Opens the deck [spaceUuid] of drive item [itemUuid] with [planner].
  /// Returns at once; follow [loadState] (or await [opened]).
  static SyncedDeckSession open(
    SlidesSessionHost host, {
    required UuidValue itemUuid,
    required UuidValue spaceUuid,
    required SlidesMutationPlanner planner,
    Role role = Role.viewer,
    SlideImageResolver? images,
    SyncedDeckStrings strings = const SyncedDeckStrings(),
    Duration settleTimeout = const Duration(seconds: 8),
    Duration maintenanceDelay = const Duration(seconds: 1),
  }) {
    final s =
        SyncedDeckSession._(
            host,
            itemUuid: itemUuid,
            userId: host.replica.userUuid.uuid,
            model: DeckModel(deckId: spaceUuid.uuid),
            planner: planner,
            spaceUuid: spaceUuid,
            strings: strings,
            role: role,
            images: images,
          )
          .._settleTimeout = settleTimeout
          .._maintenanceDelay = maintenanceDelay;
    s.loadStateNotifier.value = const DeckLoading();
    s._openFuture = s._open();
    return s;
  }

  final SlidesSessionHost host;

  @override
  final UuidValue spaceUuid;

  /// Load-state messages.
  final SyncedDeckStrings strings;

  late Duration _settleTimeout;
  late Duration _maintenanceDelay;
  Timer? _maintenanceTimer;

  /// Repairs written by [runMaintenance] (tests, diagnostics).
  int repairs = 0;

  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  late final SpaceWriteQueue _writes;
  late final JournalIngestion _ingestion;

  /// Journal position of the last ingested change (null until loaded).
  @override
  int? get cursor => _ingestion.cursor;

  /// Full and incremental model refreshes performed (tests, diagnostics).
  int fullReloads = 0;
  int patches = 0;

  StreamSubscription<UuidValue>? _mergeSub;

  bool get _ready => loadStateNotifier.value is DeckReady;

  static final Set<String> _modelTables = {
    for (final s in SlidesReplica.modelTables) s.name,
  };

  Future<void> _openFuture = Future.value();

  /// Completes when the latest open attempt finished (ready, unavailable
  /// or failed); a later attempt (back online) replaces it.
  Future<void> get opened => _openFuture;

  // ------------------------------------------------------------------ open

  Future<void> _open() async {
    host.online.addListener(_onOnline);
    try {
      await _openOnce();
    } catch (e, st) {
      debugPrint('Opening presentation $spaceUuid failed: $e\n$st');
      if (_disposed) return;
      loadStateNotifier.value = DeckUnavailable(
        strings.openFailed,
        offline: !host.online.value,
      );
    }
  }

  bool _opening = false;

  Future<void> _openOnce() async {
    if (_opening || _disposed || _ready) return;
    _opening = true;
    try {
      loadStateNotifier.value = const DeckLoading();
      final replica = host.replica;
      final local = await replica.hasDeck(spaceUuid);
      SubscribeResult? sub;
      if (host.online.value) {
        try {
          sub = await host.subscribe(itemUuid);
          roleValue = SpaceOpening.roleOf(sub.role);
          if (!sub.alreadyMember) host.kick();
        } on SlidesOfflineException {
          sub = null;
        } on Exception catch (e) {
          if (!local) {
            debugPrint('subscribe($itemUuid) failed: $e');
            if (!_disposed) {
              loadStateNotifier.value = DeckUnavailable(strings.noAccess);
            }
            return;
          }
        }
      }
      if (_disposed) return;
      if (!local) {
        if (sub == null) {
          loadStateNotifier.value = DeckUnavailable(
            strings.notAvailableOffline,
            offline: true,
          );
          return;
        }
        await _waitForSpace(sub.stats);
        if (_disposed) return;
        if (!await replica.hasDeck(spaceUuid)) {
          loadStateNotifier.value = DeckUnavailable(
            strings.downloadFailed,
            offline: !host.online.value,
          );
          return;
        }
      }
      await _syncRoleFromMembership(initial: sub == null);
      await _loadAll();
    } finally {
      _opening = false;
    }
  }

  void _onOnline() {
    if (_disposed) return;
    final state = loadStateNotifier.value;
    if (host.online.value && state is DeckUnavailable && state.offline) {
      _openFuture = _open();
    }
    _updateStatus();
  }

  /// Waits until the local row count of the deck reaches the server's
  /// (`spaceStats`), reporting progress ("Downloading presentation… 42 %").
  Future<void> _waitForSpace(SpaceStats stats) => SpaceOpening.waitForSpace(
    host,
    spaceUuid,
    stats,
    rootTable: SlidesTables.deck,
    settleTimeout: _settleTimeout,
    isDisposed: () => _disposed,
    onProgress: (progress) => loadStateNotifier.value = DeckLoading(
      progress: progress,
      message: strings.downloading,
    ),
  );

  /// Loads every model row of the deck (02 §9.1), then [DeckReady].
  Future<void> _loadAll() async {
    final replica = host.replica;
    final key = await replica.spaceKey(spaceUuid);
    if (key == null || _disposed) {
      if (!_disposed) {
        loadStateNotifier.value = DeckUnavailable(strings.notOnDevice);
      }
      return;
    }
    _ingestion.spaceKey = key;
    // Journal first, then read: anything written while loading is in the
    // journal after the cursor and re-applied (idempotently).
    await replica.journal.track(key);
    final start = await replica.journal.head();
    final rows = await replica.loadSpace(
      key,
      onPage: (n) {
        if (_disposed) return;
        loadStateNotifier.value = DeckLoading(message: strings.opening(n));
      },
    );
    if (_disposed) return;
    model.applyChanges(
      DeckRemotePatch.reconcile(model, rows, _writes.pendingOverlay),
      origin: DeckChangeOrigin.load,
    );
    _ingestion.cursor = start;
    fullReloads++;
    host.journalCursorsChanged();
    _mergeSub ??= host.merges
        .where((s) => s == spaceUuid)
        .listen((_) => unawaited(ingestRemote()));
    loadStateNotifier.value = const DeckReady();
    _updateStatus();
    _scheduleMaintenance();
    // Changes that landed while loading.
    unawaited(ingestRemote());
  }

  // ------------------------------------------------------------ ingestion

  /// Applies the rows changed since [cursor] (after a merge). Coalesces
  /// concurrent calls; completes when the model is current.
  Future<void> ingestRemote() => _ingestion.ingest();

  /// Patches the model with the journaled rows (incremental ingestion).
  void _applyJournalRows(
    Map<String, Set<UuidValue>> changed,
    Map<String, Map<String, Map<String, Object?>>> rows,
  ) {
    final patch = DeckRemotePatch.build(
      model,
      changed,
      rows,
      _writes.pendingOverlay,
    );
    if (patch.isEmpty) return;
    applyRemote(patch);
    patches++;
    _scheduleMaintenance();
  }

  /// Fallback after errors: diff the whole deck against the model.
  void _reloadRows(List<(String, Map<String, Object?>)> rows) {
    final patch = DeckRemotePatch.reconcile(
      model,
      rows,
      _writes.pendingOverlay,
    );
    if (patch.isNotEmpty) {
      applyRemote(patch);
      _scheduleMaintenance();
    }
    fullReloads++;
  }

  // ---------------------------------------------------------- maintenance

  /// Merges can leave a deck violating an invariant (02 §10: orphan slides,
  /// duplicate or dangling placeholders, group cycles, …). Editors repair
  /// them [_maintenanceDelay] (1 s) after the last merge; every rule is
  /// deterministic, so concurrent repairs on several devices converge.
  void _scheduleMaintenance() {
    if (_disposed) return;
    _maintenanceTimer?.cancel();
    _maintenanceTimer = Timer(_maintenanceDelay, () => runMaintenance());
  }

  /// Writes `DeckMaintenance.repairOp` ("Repair presentation") when the
  /// deck violates an invariant and the user can edit. Not undoable (the
  /// plan is not pushed on the undo stack). Returns the plan, or null.
  SlidesPlan? runMaintenance() {
    if (_disposed || !_ready || !canEdit) return null;
    final op = DeckMaintenance.repairOp(model);
    if (op == null) return null;
    try {
      final plan = execute(op);
      if (!plan.isEmpty) repairs++;
      return plan;
    } on PlanException catch (e) {
      debugPrint('Repairing presentation $spaceUuid failed: $e');
      return null;
    }
  }

  // ----------------------------------------------------------------- role

  Future<void> _syncRoleFromMembership({bool initial = false}) async {
    if (spaceUuid == host.replica.userUuid) return;
    final space = await host.replica.roleOf(spaceUuid);
    if (_disposed) return;
    if (space == null) {
      // Membership removed (unshared, trashed, evicted). Offline opens of
      // a deck still on the device keep the cached role.
      if (!initial && _ready) {
        _accessRemoved = true;
        loadStateNotifier.value = DeckUnavailable(strings.accessRemoved);
      }
      return;
    }
    final next = SpaceOpening.roleFromMembership(space, role.value);
    if (next != null) roleValue = next;
    if (_accessRemoved) _onAccessRestored();
  }

  /// Whether the open deck turned unavailable because its membership
  /// disappeared (and may come back: unshare + reshare).
  bool _accessRemoved = false;

  /// The membership came back while the deck was open (re-shared): rows
  /// the engine's membership read filter hid and showed again produced no
  /// journal entries, so the whole deck is re-read
  /// (`JournalIngestion.needsReload`) before it turns [DeckReady] again.
  void _onAccessRestored() {
    _accessRemoved = false;
    _ingestion.needsReload = true;
    // Called from the ingestion's `afterIngest`: the running loop picks
    // the reload up (`ingest` coalesces), so don't await it here.
    unawaited(
      _ingestion.ingest().then((_) {
        if (_disposed || _accessRemoved) return;
        if (loadStateNotifier.value is DeckUnavailable) {
          loadStateNotifier.value = const DeckReady();
          _updateStatus();
          _scheduleMaintenance();
        }
      }),
    );
  }

  final List<FutureOr<void> Function()> _onDispose = [];

  /// Runs [callback] when the session is disposed.
  void addDisposeCallback(FutureOr<void> Function() callback) =>
      _onDispose.add(callback);

  /// Applies a role learned elsewhere (drive item, sharing dialog).
  void updateRole(Role value) {
    if (!_disposed) roleValue = value;
  }

  // --------------------------------------------------------------- writes

  /// Refuses writes while the deck is opening (the model is incomplete)
  /// and, through the base class, writes of viewers and commenters.
  @override
  void checkPlan(SlidesOperation op, SlidesPlan plan) {
    if (!_ready) {
      throw PlanException(PlanException.locked, strings.stillOpening);
    }
    super.checkPlan(op, plan);
  }

  @override
  void persist(
    List<RowChange> changes, {
    SlidesPlan? plan,
    required String label,
    required String actorKind,
  }) {
    if (_disposed || changes.isEmpty) return;
    _writes.enqueue(changes, plan: plan, label: label, actorKind: actorKind);
  }

  @override
  Future<void> flush() => _writes.flush();

  /// Number of row changes waiting to be stored.
  int get pendingChanges => _writes.pendingChanges;

  void _updateStatus() {
    if (_disposed) return;
    syncStatusNotifier.value = _writes.status(online: host.online.value);
  }

  // -------------------------------------------------------------- dispose

  Future<void>? _disposing;

  @override
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _maintenanceTimer?.cancel();
    await flush();
    _disposed = true;
    _maintenanceTimer?.cancel();
    host.online.removeListener(_onOnline);
    await _mergeSub?.cancel();
    for (final f in _onDispose) {
      await f();
    }
    final key = _ingestion.spaceKey;
    _ingestion.cursor = null;
    host.journalCursorsChanged();
    if (key != null && !host.replica.isClosed) {
      try {
        await host.replica.journal.untrack(key);
      } catch (_) {}
    }
    await super.dispose();
  }
}
