import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show OfflineSyncSpaceRole;
import 'package:wonky_client/wonky_client.dart'
    show AccessRole, SpaceStats, SubscribeResult, UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart' show SyncState, SyncStatus;

import '../model/memory_workbook_session.dart';
import '../model/row_loading.dart';
import '../model/workbook_session.dart';
import '../model/loading_gate.dart';
import 'remote_patch.dart';
import 'sheets_replica.dart';
import 'sheets_session_host.dart';

/// A [WorkbookSession] on the synced local replica (suite 12 §2, Sheets 02
/// §6–7).
///
/// Opening: `sheets.subscribe(itemUuid)` when online (grants membership,
/// returns the role and row counts), then waits for the space to arrive
/// ([WorkbookLoading] with progress from local vs server row counts), loads
/// every row of the space into [model] and turns [WorkbookReady]. A
/// spreadsheet already on the device opens at once, also offline; one that
/// isn't on the device while offline is [WorkbookUnavailable] (`offline:
/// true`) and opens by itself when the connection returns.
///
/// Writes: the model is updated synchronously by the base class; [persist]
/// queues the changes for the `SheetsWriter` (one transaction per ≤ 5,000
/// changes plus the `ChangeLog` row), strictly in order. [flush] awaits the
/// queue.
///
/// Remote changes: after every merge of the space, the rows the change
/// journal recorded since the session's cursor are re-read and patched into
/// the model ([RemotePatch]); queued local writes are overlaid so an
/// optimistic edit never flickers back. The patch is emitted on
/// [remoteBatches].
class SyncedWorkbookSession extends WorkbookSessionBase {
  SyncedWorkbookSession._(
    this.host, {
    required super.itemUuid,
    required super.userId,
    required super.model,
    required this.spaceUuid,
    super.role,
    super.maxCells,
  });

  /// Opens the spreadsheet [spaceUuid] of drive item [itemUuid]. Returns at
  /// once; follow [loadState].
  static SyncedWorkbookSession open(
    SheetsSessionHost host, {
    required UuidValue itemUuid,
    required UuidValue spaceUuid,
    Role role = Role.viewer,
    int maxCells = 1000000,
    Duration settleTimeout = const Duration(seconds: 8),
    ViewportHint? viewport,
  }) {
    final s =
        SyncedWorkbookSession._(
            host,
            itemUuid: itemUuid,
            userId: host.replica.userUuid.uuid,
            model: WorkbookModel(spreadsheetId: spaceUuid.uuid),
            spaceUuid: spaceUuid,
            role: role,
            maxCells: maxCells,
          )
          .._settleTimeout = settleTimeout
          ..viewportHint = viewport;
    s._openFuture = s._open();
    return s;
  }

  final SheetsSessionHost host;
  final UuidValue spaceUuid;
  late Duration _settleTimeout;

  /// Where the user looks first (restored view state, `?gid=`): these rows
  /// load before [WorkbookReady]. Set before the space has been read.
  ViewportHint? viewportHint;

  /// Rows per sheet loaded before [WorkbookReady] (03 §2.8: the first
  /// visible window plus a margin).
  static const viewportRows = 200;

  /// Spreadsheets with at most this many rows (all sheets) load completely
  /// before [WorkbookReady].
  static const smallSpaceRows = 2000;

  /// Max cells applied to the model between two frames while streaming.
  static const streamApplyCells = 5000;

  final RowLoadTracker _rows = RowLoadTracker();

  @override
  WorkbookRowLoading get rowLoading => _rows;

  /// Cell ids written locally or patched from the journal while streaming:
  /// a streamed (possibly older) copy never overwrites them.
  final Set<String> _touched = {};

  bool _disposed = false;

  /// Whether [dispose] ran.
  bool get isDisposed => _disposed;
  int? _spaceKey;

  /// Journal position of the last ingested change (null until loaded).
  int? cursor;

  /// Full or incremental model refreshes performed (tests, diagnostics).
  int fullReloads = 0;
  int patches = 0;

  StreamSubscription<UuidValue>? _mergeSub;
  Future<void> _queue = Future.value();
  final List<_PendingWrite> _pending = [];
  Future<void>? _ingesting;
  bool _ingestAgain = false;
  bool _needsReload = false;
  Object? _lastError;

  bool get _ready => loadStateNotifier.value is WorkbookReady;

  static final Set<String> _modelTables = {
    for (final s in SheetsReplica.modelTables) s.name,
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
      debugPrint('Opening spreadsheet $spaceUuid failed: $e\n$st');
      if (_disposed) return;
      loadStateNotifier.value = WorkbookUnavailable(
        'This spreadsheet could not be opened.',
        offline: !host.online.value,
      );
    }
  }

  bool _opening = false;

  Future<void> _openOnce() async {
    if (_opening || _disposed || _ready) return;
    _opening = true;
    try {
      loadStateNotifier.value = const WorkbookLoading();
      final replica = host.replica;
      final local = await replica.hasSpreadsheet(spaceUuid);
      SubscribeResult? sub;
      if (host.online.value) {
        try {
          sub = await host.subscribe(itemUuid);
          roleValue = _roleOf(sub.role);
          if (!sub.alreadyMember) host.kick();
        } on SheetsOfflineException {
          sub = null;
        } on Exception catch (e) {
          if (!local) {
            loadStateNotifier.value = WorkbookUnavailable(
              'You don\'t have access to this spreadsheet.',
            );
            debugPrint('subscribe($itemUuid) failed: $e');
            return;
          }
        }
      }
      if (_disposed) return;
      if (!local) {
        if (sub == null) {
          loadStateNotifier.value = const WorkbookUnavailable(
            'This spreadsheet isn\'t available offline.',
            offline: true,
          );
          return;
        }
        await _waitForSpace(sub.stats);
        if (_disposed) return;
        if (!await replica.hasSpreadsheet(spaceUuid)) {
          loadStateNotifier.value = WorkbookUnavailable(
            'This spreadsheet could not be downloaded.',
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
    if (host.online.value && state is WorkbookUnavailable && state.offline) {
      _openFuture = _open();
    }
    _updateStatus();
  }

  /// Waits until the local row count of the space reaches the server's
  /// (`spaceStats`), reporting progress; gives up waiting for the last rows
  /// once the spreadsheet row is there and nothing arrived for
  /// [_settleTimeout] (the rest is patched in as it arrives).
  Future<void> _waitForSpace(SpaceStats stats) async {
    final total = stats.totalRows <= 0 ? 1 : stats.totalRows;
    var last = -1;
    var lastChange = DateTime.now();
    while (!_disposed) {
      final counts = await host.replica.rowCounts(spaceUuid);
      final have = counts.values.fold(0, (a, b) => a + b);
      final present = (counts['spreadsheet'] ?? 0) > 0;
      if (present && have >= stats.totalRows) return;
      if (have != last) {
        last = have;
        lastChange = DateTime.now();
        loadStateNotifier.value = WorkbookLoading(
          progress: (have / total).clamp(0.0, 1.0),
          message: 'Downloading spreadsheet…',
        );
      } else if (present &&
          DateTime.now().difference(lastChange) > _settleTimeout) {
        return;
      } else if (!host.online.value && !present) {
        return;
      }
      await Future.any<void>([
        host.merges.firstWhere((s) => s == spaceUuid).then((_) {}),
        Future<void>.delayed(const Duration(milliseconds: 500)),
      ]);
    }
  }

  /// Viewport-first loading (02 §6): the metadata (every table but cells),
  /// then the cells of the first visible window of the active sheet
  /// ([viewportHint], frozen rows) → [WorkbookReady]; the remaining rows
  /// stream in afterwards ([_streamRest], [rowLoading]). Small spreadsheets
  /// load completely before turning ready.
  Future<void> _loadAll() async {
    final replica = host.replica;
    final key = await replica.spaceKey(spaceUuid);
    if (key == null || _disposed) {
      loadStateNotifier.value = const WorkbookUnavailable(
        'This spreadsheet isn\'t on this device.',
      );
      return;
    }
    _spaceKey = key;
    // Journal first, then read: anything written while loading is in the
    // journal after the cursor and re-applied (idempotently).
    await replica.journal.track(key);
    final start = await replica.journal.head();
    final meta = await replica.loadSpace(
      key,
      skipTables: const {SheetsTables.cell},
      onPage: (n) {
        if (_disposed) return;
        loadStateNotifier.value = WorkbookLoading(
          progress: null,
          message: 'Opening spreadsheet… ($n rows)',
        );
      },
    );
    if (_disposed) return;
    model.applyChanges(RemotePatch.reconcile(model, meta, _pendingOverlay()));
    final sheets = model.sheets;
    final totalRows = sheets.fold(0, (a, s) => a + s.rows.length);
    for (final sheet in sheets) {
      _rows.track(sheet.id, sheet.rows.ids);
    }
    if (totalRows <= smallSpaceRows) {
      for (final sheet in sheets) {
        await _loadRows(sheet.id, List.of(sheet.rows.ids), stream: false);
        if (_disposed) return;
      }
    } else {
      final first = _viewportSheet();
      if (first != null) {
        await _loadRows(first.id, _viewportRowIds(first), stream: false);
        if (_disposed) return;
      }
    }
    cursor = start;
    fullReloads++;
    host.journalCursorsChanged();
    _mergeSub ??= host.merges
        .where((s) => s == spaceUuid)
        .listen((_) => unawaited(ingestRemote()));
    if (_rows.pendingSheets.isEmpty) _rows.finish();
    loadStateNotifier.value = const WorkbookReady();
    _updateStatus();
    // Changes that landed while loading.
    unawaited(ingestRemote());
    if (!_rows.complete) unawaited(_streamRest());
  }

  SheetModel? _viewportSheet() {
    final hinted = viewportHint?.sheetId;
    final s = hinted == null ? null : model.sheet(hinted);
    if (s != null) return s;
    final visible = model.visibleSheets;
    if (visible.isNotEmpty) return visible.first;
    return model.sheets.firstOrNull;
  }

  /// The frozen rows and [viewportRows] rows from the hinted top row.
  List<String> _viewportRowIds(SheetModel sheet) {
    final n = sheet.rows.length;
    final frozen = (sheet.record?.frozenRows ?? 0).clamp(0, n);
    final hint = viewportHint;
    final top = hint != null && hint.sheetId == sheet.id
        ? hint.topRow.clamp(0, n)
        : 0;
    final from = (top - 20).clamp(0, n);
    final to = (top + viewportRows).clamp(0, n);
    return [
      for (var r = 0; r < frozen; r++) sheet.rows.idAt(r),
      for (var r = from < frozen ? frozen : from; r < to; r++)
        sheet.rows.idAt(r),
    ];
  }

  /// Reads the cells of [rowIds] of [sheetId] and applies those the model
  /// doesn't have yet (and nothing touched them meanwhile), in slices of
  /// [streamApplyCells] with a frame between slices when [stream] is set.
  Future<void> _loadRows(
    String sheetId,
    List<String> rowIds, {
    required bool stream,
  }) async {
    final missing = _rows.missingOf(sheetId);
    final ids = [
      for (final id in rowIds)
        if (missing.contains(id)) id,
    ];
    if (ids.isEmpty) return;
    final cells = await host.replica.loadCells(sheetId, ids);
    if (_disposed || _rows.complete) return;
    for (var i = 0; i < cells.length; i += streamApplyCells) {
      final end = i + streamApplyCells > cells.length
          ? cells.length
          : i + streamApplyCells;
      final changes = <RowChange>[];
      for (final c in cells.sublist(i, end)) {
        final id = '${c[Cols.id]}';
        if (_touched.contains(id) ||
            model.currentColumns(SheetsTables.cell, id) != null) {
          continue;
        }
        changes.add(RowChange.insert(SheetsTables.cell, id, c));
      }
      if (changes.isNotEmpty) {
        final batch = model.applyChanges(changes);
        // Announced like remote data: nothing of it is a local edit.
        if (stream && !batch.isEmpty && !remoteController.isClosed) {
          remoteController.add(batch);
        }
      }
      if (stream && end < cells.length) {
        await Future<void>.delayed(Duration.zero);
        if (_disposed || _rows.complete) return;
      }
    }
    _rows.markLoaded(sheetId, ids);
  }

  /// Streams the cells of the rows not loaded yet: the active sheet first,
  /// in blocks of `SheetsReplica.cellQueryRows` rows; rows the grid asks
  /// for ([WorkbookRowLoading.prioritize]) jump the queue.
  Future<void> _streamRest() async {
    final order = [
      if (_viewportSheet() case final s?) s.id,
      for (final s in model.sheets) s.id,
    ];
    try {
      while (!_disposed && !_rows.complete) {
        final next = _nextBlock(order);
        if (next == null) break;
        await _loadRows(next.$1, next.$2, stream: true);
        _rows.changed();
        await Future<void>.delayed(Duration.zero);
      }
      if (!_disposed) _finishStreaming();
    } catch (e, st) {
      if (_disposed) return;
      debugPrint('Streaming spreadsheet rows failed, reloading: $e\n$st');
      _needsReload = true;
      unawaited(ingestRemote());
    }
  }

  (String, List<String>)? _nextBlock(List<String> order) {
    const block = SheetsReplica.cellQueryRows;
    while (true) {
      final req = _rows.takeRequest();
      if (req == null) break;
      final (sheetId, first, last) = req;
      final sheet = model.sheet(sheetId);
      if (sheet == null || _rows.isSheetLoaded(sheetId)) continue;
      final n = sheet.rows.length;
      final ids = <String>[];
      for (
        var r = (first - 50).clamp(0, n);
        r < n && r <= last + 50 && ids.length < block;
        r++
      ) {
        final id = sheet.rows.idAt(r);
        if (!_rows.isRowLoaded(sheetId, id)) ids.add(id);
      }
      if (ids.isNotEmpty) return (sheetId, ids);
    }
    for (final sheetId in order) {
      if (_rows.isSheetLoaded(sheetId)) continue;
      final sheet = model.sheet(sheetId);
      final missing = _rows.missingOf(sheetId);
      final ids = <String>[];
      if (sheet != null) {
        for (final id in sheet.rows.ids) {
          if (missing.remove(id)) ids.add(id);
          if (ids.length >= block) break;
        }
      }
      if (ids.isEmpty) {
        // Rows deleted meanwhile: nothing left to read for this sheet.
        _rows.markLoaded(sheetId, missing);
        continue;
      }
      return (sheetId, ids);
    }
    return null;
  }

  void _finishStreaming() {
    _touched.clear();
    _rows.finish();
  }

  // ------------------------------------------------------------ ingestion

  /// Applies the rows changed since [cursor] (after a merge). Coalesces
  /// concurrent calls; completes when the model is current.
  Future<void> ingestRemote() {
    if (_disposed || _spaceKey == null || cursor == null) {
      return Future.value();
    }
    if (_ingesting != null) {
      _ingestAgain = true;
      return _ingesting!;
    }
    final f = _ingestLoop();
    _ingesting = f;
    return f.whenComplete(() => _ingesting = null);
  }

  Future<void> _ingestLoop() async {
    do {
      _ingestAgain = false;
      try {
        if (_needsReload) {
          await _reload();
        } else {
          await _ingestOnce();
        }
      } catch (e, st) {
        debugPrint('Applying remote changes failed, reloading: $e\n$st');
        _needsReload = true;
        _ingestAgain = !_disposed;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } while (_ingestAgain && !_disposed);
  }

  Future<void> _ingestOnce() async {
    final replica = host.replica;
    while (!_disposed) {
      final changes = await replica.journal.changesSince(_spaceKey!, cursor!);
      if (changes.head == cursor) break;
      if (!changes.isEmpty) {
        changes.rows.removeWhere((t, _) => !_modelTables.contains(t));
        final rows = await replica.readRows(changes.rows);
        if (_disposed) return;
        final patch = RemotePatch.build(
          model,
          changes.rows,
          rows,
          _pendingOverlay(),
        );
        if (patch.isNotEmpty) {
          if (!_rows.complete) {
            for (final c in patch) {
              if (c.table == SheetsTables.cell) _touched.add(c.rowId);
            }
          }
          final batch = model.applyChanges(patch);
          patches++;
          if (!batch.isEmpty && !remoteController.isClosed) {
            remoteController.add(batch);
          }
        }
      }
      cursor = changes.head;
      host.journalCursorsChanged();
    }
    await _syncRoleFromMembership();
  }

  /// Fallback after errors: diff the whole space against the model.
  Future<void> _reload() async {
    final replica = host.replica;
    final head = await replica.journal.head();
    final rows = await replica.loadSpace(_spaceKey!);
    if (_disposed) return;
    final patch = RemotePatch.reconcile(model, rows, _pendingOverlay());
    if (patch.isNotEmpty) {
      final batch = model.applyChanges(patch);
      if (!batch.isEmpty && !remoteController.isClosed) {
        remoteController.add(batch);
      }
    }
    cursor = head;
    fullReloads++;
    _needsReload = false;
    _finishStreaming();
    host.journalCursorsChanged();
  }

  // ----------------------------------------------------------------- role

  Future<void> _syncRoleFromMembership({bool initial = false}) async {
    if (spaceUuid == host.replica.userUuid) return;
    final space = await host.replica.roleOf(spaceUuid);
    if (_disposed) return;
    final current = role.value;
    switch (space) {
      case OfflineSyncSpaceRole.readWrite:
        if (current < Role.editor) roleValue = Role.editor;
      case OfflineSyncSpaceRole.readOnly:
        if (current >= Role.editor) roleValue = Role.viewer;
      case null:
        // Membership removed (unshared, trashed, evicted). Offline opens of
        // a spreadsheet still on the device keep the cached role.
        if (!initial && _ready) {
          loadStateNotifier.value = const WorkbookUnavailable(
            'You no longer have access to this spreadsheet.',
          );
        }
    }
  }

  static Role _roleOf(AccessRole r) => switch (r) {
    AccessRole.viewer => Role.viewer,
    AccessRole.commenter => Role.commenter,
    AccessRole.editor => Role.editor,
    AccessRole.owner => Role.owner,
  };

  final List<FutureOr<void> Function()> _onDispose = [];

  /// Runs [callback] when the session is disposed.
  void addDisposeCallback(FutureOr<void> Function() callback) =>
      _onDispose.add(callback);

  /// Applies a role learned elsewhere (drive item, sharing dialog).
  void updateRole(Role value) {
    if (!_disposed) roleValue = value;
  }

  // --------------------------------------------------------------- writes

  @override
  void persist(
    List<RowChange> changes, {
    MutationPlan? plan,
    required String label,
    required String actorKind,
  }) {
    if (_disposed || changes.isEmpty) return;
    if (!_rows.complete) {
      for (final c in changes) {
        if (c.table == SheetsTables.cell) _touched.add(c.rowId);
      }
    }
    final write = _PendingWrite(changes);
    _pending.add(write);
    _updateStatus();
    _queue = _queue.then((_) async {
      try {
        await host.writer.write(
          spaceId: spaceUuid,
          changes: changes,
          plan: plan,
          label: label,
          actorKind: actorKind,
          sessionId: host.sessionId,
        );
        _lastError = null;
        host.kick();
      } catch (e, st) {
        debugPrint('Saving "$label" failed: $e\n$st');
        _lastError = e;
        // The optimistic model change was not stored: bring the model back
        // in line with the replica.
        _needsReload = true;
        unawaited(ingestRemote());
      } finally {
        _pending.remove(write);
        _updateStatus();
      }
    });
  }

  @override
  void checkPlan(SheetsOperation op, MutationPlan plan) =>
      LoadingGate.check(op, plan, model, _rows);

  @override
  Future<void> flush() => _queue;

  /// Changes queued but not yet stored, oldest first (overlaid on rows read
  /// from the replica).
  List<RowChange> _pendingOverlay() => [for (final w in _pending) ...w.changes];

  /// Number of row changes waiting to be stored.
  int get pendingChanges => _pending.fold(0, (a, w) => a + w.changes.length);

  void _updateStatus() {
    if (_disposed) return;
    final pending = pendingChanges;
    final SyncStatus status;
    if (_lastError != null) {
      status = SyncStatus(
        state: SyncState.error,
        pendingChanges: pending,
        error: '$_lastError',
      );
    } else if (pending > 0) {
      status = SyncStatus(state: SyncState.saving, pendingChanges: pending);
    } else if (!host.online.value) {
      status = const SyncStatus(state: SyncState.offline);
    } else {
      status = SyncStatus.saved;
    }
    syncStatusNotifier.value = status;
  }

  // -------------------------------------------------------------- dispose

  Future<void>? _disposing;

  @override
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    await flush();
    _disposed = true;
    host.online.removeListener(_onOnline);
    await _mergeSub?.cancel();
    for (final f in _onDispose) {
      await f();
    }
    final key = _spaceKey;
    cursor = null;
    host.journalCursorsChanged();
    if (key != null && !host.replica.isClosed) {
      try {
        await host.replica.journal.untrack(key);
      } catch (_) {}
    }
    await super.dispose();
    _rows.dispose();
  }
}

/// Where the user will look first when a spreadsheet opens (restored
/// `LocalViewState`, `?gid=`).
@immutable
class ViewportHint {
  const ViewportHint({this.sheetId, this.topRow = 0});

  final String? sheetId;
  final int topRow;
}

class _PendingWrite {
  _PendingWrite(this.changes);

  final List<RowChange> changes;
}
