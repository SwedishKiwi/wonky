import 'dart:async';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_sheets_core/model.dart'
    show RowChange, SheetsTables, WorkbookModel;

import '../../platform/cluster/cluster.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../sync/sheets_sync_service.dart';
import '../sync/sync_db.dart';
import '../sync/synced_tables.dart';
import '../versions/sheets_version_provider.dart';
import 'headless_workbook.dart';

/// The per-instance cache of [HeadlessWorkbook]s (Sheets 12 §2.2): LRU by
/// spreadsheet (space) uuid, bounded by an estimated memory budget and a
/// count; idle entries are evicted.
///
/// **Invalidation**: the sync endpoint's `onMergeSuccess` posts
/// `sheets:merged:<space>` (relayed to every instance by the cluster bus);
/// the cached entry is marked stale and **patched** on its next use: the
/// rows of the space whose CRDT tuples (row, fields or tombstone) changed
/// since the workbook's transaction watermark are re-read and applied like
/// the client's remote change tracker. More than [maxPatchRows] changed
/// rows, or a failure, drop the entry (reload on next use). Entries not
/// checked for [recheckAfter] are patched too, which covers server writes
/// that do not signal (restores, imports).
///
/// Tool writes are applied to the cached model synchronously
/// ([writeThrough]) so read-after-write is consistent.
abstract final class HeadlessWorkbookProvider {
  /// Memory budget (`sheets.headlessCacheMb`, default 2,048 MB).
  static int budgetBytes = 2048 * 1024 * 1024;

  /// Maximum number of cached workbooks.
  static int maxEntries = 50;

  /// Entries idle longer than this are evicted.
  static Duration idleTimeout = const Duration(minutes: 15);

  /// Entries are re-checked against the database after this long.
  static Duration recheckAfter = const Duration(seconds: 60);

  /// A patch touching more rows than this reloads instead.
  static int maxPatchRows = 50000;

  /// How long a mutating call waits for the spreadsheet's write lock.
  static Duration lockTimeout = const Duration(seconds: 30);

  static const _chunk = 5000;

  static final Map<String, HeadlessWorkbook> _entries = {};
  static final Map<String, Future<HeadlessWorkbook>> _loading = {};
  static final Map<String, Future<void>> _locks = {};
  static Session? _listenerSession;
  static final Map<String, void Function(SerializableModel)> _listeners = {};

  /// The `hlc` of the merge signals this instance posts after its own tool
  /// writes (ignored by its own listeners).
  static String get ownSignal => 'server:${Cluster.instanceId}';

  /// Number of full loads (tests, diagnostics).
  static int loads = 0;

  /// Cached spaces (tests).
  static Iterable<UuidValue> get cachedSpaces =>
      _entries.values.map((e) => e.space);

  /// The cached workbook of [space] without loading (tests).
  static HeadlessWorkbook? peek(UuidValue space) => _entries[space.uuid];

  /// Opens the workbook of [space]: from the cache (patched when stale) or
  /// loaded from the synced tables.
  static Future<HeadlessWorkbook> open(Session session, UuidValue space) async {
    final key = space.uuid;
    _evictIdle();
    final cached = _entries[key];
    if (cached != null) {
      cached.lastUsed = clock.now();
      if (cached.stale ||
          clock.now().difference(cached.lastChecked) > recheckAfter) {
        final ok = await _patch(session, cached);
        if (!ok) {
          _drop(key);
          return open(session, space);
        }
      }
      return cached;
    }
    final pending = _loading[key];
    if (pending != null) return pending;
    final future = _load(session, space);
    _loading[key] = future;
    try {
      final wb = await future;
      _entries[key] = wb;
      await _listen(session, space);
      _enforceBudget(keep: key);
      return wb;
    } finally {
      unawaited(_loading.remove(key));
    }
  }

  /// Applies rows written by a tool to the cached model (if cached).
  static void writeThrough(UuidValue space, List<RowChange> applied) {
    final wb = _entries[space.uuid];
    if (wb == null || applied.isEmpty) return;
    try {
      wb.apply(applied);
    } on Object {
      _drop(space.uuid);
    }
  }

  /// Marks the cached workbook of [space] stale (merge signal).
  static void markStale(UuidValue space) => _entries[space.uuid]?.stale = true;

  /// Drops the cached workbook of [space].
  static void invalidate(UuidValue space) => _drop(space.uuid);

  /// Drops every entry (tests).
  static void clear() {
    for (final k in _entries.keys.toList()) {
      _drop(k);
    }
  }

  /// Runs [body] holding the write lock of [space] (Sheets 12 §2.3:
  /// mutating calls to one spreadsheet are serialized per instance). Fails
  /// with `busy` after [lockTimeout].
  static Future<T> withWriteLock<T>(
    UuidValue space,
    Future<T> Function() body,
  ) async {
    final key = space.uuid;
    final previous = _locks[key];
    final done = Completer<void>();
    final mine = done.future;
    _locks[key] = mine;
    try {
      if (previous != null) {
        try {
          await previous.timeout(lockTimeout);
        } on TimeoutException {
          throw Errors.busy(
            'Another change to this spreadsheet is still running. Try again.',
          );
        }
      }
      return await body();
    } finally {
      done.complete();
      if (identical(_locks[key], mine)) unawaited(_locks.remove(key));
    }
  }

  // ------------------------------------------------------------ loading

  static Future<HeadlessWorkbook> _load(
    Session session,
    UuidValue space,
  ) async {
    final watermark = await _snapshotXmin(session);
    final rows = await readSpace(session, space);
    final model = WorkbookModel.fromRows(space.uuid, [
      for (final table in SheetsTables.dependencyOrder)
        for (final row in rows[table]?.values ?? const <Map<String, dynamic>>[])
          (table, row.cast<String, Object?>()),
    ]);
    loads++;
    return HeadlessWorkbook(
      space: space,
      model: model,
      watermark: watermark,
      estimatedBytes: HeadlessWorkbook.estimate({
        for (final e in rows.entries) e.key: e.value.length,
      }),
    );
  }

  /// `txid_snapshot_xmin` of the current snapshot: every transaction that
  /// commits later has an id at or after it.
  static Future<int> _snapshotXmin(Session session) async {
    final r = await session.db.unsafeQuery(
      'SELECT txid_snapshot_xmin(txid_current_snapshot())',
    );
    return (r.first[0] as int);
  }

  /// Re-reads the rows of [wb]'s space changed since its watermark. Returns
  /// false when the entry must be reloaded.
  static Future<bool> _patch(Session session, HeadlessWorkbook wb) async {
    try {
      final spaceRow = await OfflineSyncSpace.db.findFirstRow(
        session,
        where: (t) => t.uuidSpaceId.equals(wb.space),
      );
      if (spaceRow == null) return false;
      final next = await _snapshotXmin(session);
      // `age(xmin) <= age(w)` ⇔ the tuple was written by transaction w or a
      // later one (32-bit xids; the epoch is irrelevant for live entries).
      final xid = wb.watermark & 0xFFFFFFFF;
      final changed = await session.db.unsafeQuery(
        r'''
        SELECT t.name, r."uuidRowId", r.visibility FROM crdt_data_rows r
        JOIN crdt_schema_tables t ON t.id = r."tblId"
        WHERE r."spaceId" = @space AND (
          age(r.xmin) <= age(@xid::text::xid)
          OR EXISTS (SELECT 1 FROM crdt_data_fields f
                     WHERE f."rowId" = r.id
                       AND age(f.xmin) <= age(@xid::text::xid))
          OR EXISTS (SELECT 1 FROM crdt_data_tombstone d
                     WHERE d."rowId" = r.id
                       AND age(d.xmin) <= age(@xid::text::xid)))
        LIMIT @limit
        ''',
        parameters: QueryParameters.named({
          'space': spaceRow.id,
          'xid': '$xid',
          'limit': maxPatchRows + 1,
        }),
      );
      if (changed.length > maxPatchRows) return false;
      final visible = <String, Set<UuidValue>>{};
      final hidden = <(String, UuidValue)>[];
      for (final row in changed) {
        final table = row[0] as String;
        if (SheetsVersionProvider.excluded.contains(table)) continue;
        if (syncedTablesByName[table] == null) continue;
        final id = _uuid(row[1]);
        final visibility = _visibilityIndex(row[2]);
        if (visibility <= 2) {
          visible.putIfAbsent(table, () => {}).add(id);
        } else {
          hidden.add((table, id));
        }
      }
      final db = syncSessionOf(session);
      final changes = <RowChange>[];
      for (final table in SheetsTables.dependencyOrder) {
        final ids = visible[table];
        if (ids == null) continue;
        final synced = syncedTablesByName[table]!;
        final list = ids.toList();
        final found = <String>{};
        for (var i = 0; i < list.length; i += _chunk) {
          final chunk = list.sublist(
            i,
            i + _chunk > list.length ? list.length : i + _chunk,
          );
          for (final r in await synced.findByIds(db, chunk.toSet())) {
            final json = (r.toJson() as Map).cast<String, Object?>()
              ..remove('spaceId');
            final id = json['id'] as String;
            found.add(id);
            changes.add(RowChange.insert(table, id, json));
          }
        }
        for (final id in list) {
          if (!found.contains(id.uuid)) {
            changes.add(RowChange.delete(table, id.uuid, const {}));
          }
        }
      }
      // Children first for deletions.
      for (final table in SheetsTables.dependencyOrder.reversed) {
        for (final (t, id) in hidden) {
          if (t == table) changes.add(RowChange.delete(t, id.uuid, const {}));
        }
      }
      if (changes.isNotEmpty) wb.apply(changes);
      wb
        ..watermark = next
        ..stale = false
        ..lastChecked = clock.now()
        ..patches += 1;
      return true;
    } on Object catch (e, st) {
      session.log(
        'Headless workbook patch of ${wb.space} failed: $e',
        level: LogLevel.warning,
        stackTrace: st,
      );
      return false;
    }
  }

  static UuidValue _uuid(Object? v) =>
      v is UuidValue ? v : UuidValue.withValidation('$v');

  /// All visible rows of [space] by table name (admin read), in dependency
  /// order, as JSON maps without `spaceId` (the tables excluded from
  /// snapshots are skipped).
  static Future<Map<String, Map<String, Map<String, dynamic>>>> readSpace(
    Session session,
    UuidValue space,
  ) async {
    final spaceRow = await OfflineSyncSpace.db.findFirstRow(
      session,
      where: (t) => t.uuidSpaceId.equals(space),
    );
    final result = <String, Map<String, Map<String, dynamic>>>{};
    if (spaceRow == null) return result;
    final ids = await session.db.unsafeQuery(
      r'''
      SELECT t.name, r."uuidRowId" FROM crdt_data_rows r
      JOIN crdt_schema_tables t ON t.id = r."tblId"
      WHERE r."spaceId" = @space AND r.visibility <= 2
      ''',
      parameters: QueryParameters.named({'space': spaceRow.id}),
    );
    final byTable = <String, Set<UuidValue>>{};
    for (final row in ids) {
      byTable.putIfAbsent(row[0] as String, () => {}).add(_uuid(row[1]));
    }
    final db = syncSessionOf(session);
    for (final name in SheetsTables.dependencyOrder) {
      if (SheetsVersionProvider.excluded.contains(name)) continue;
      final table = syncedTablesByName[name];
      final tableIds = byTable[name];
      if (table == null || tableIds == null) continue;
      final list = tableIds.toList();
      final rows = <String, Map<String, dynamic>>{};
      for (var i = 0; i < list.length; i += _chunk) {
        final chunk = list.sublist(
          i,
          i + _chunk > list.length ? list.length : i + _chunk,
        );
        for (final r in await table.findByIds(db, chunk.toSet())) {
          final json = (r.toJson() as Map).cast<String, dynamic>()
            ..remove('spaceId');
          rows[json['id'] as String] = json;
        }
      }
      result[name] = rows;
    }
    return result;
  }

  static int _visibilityIndex(Object? v) {
    if (v is int) return v;
    if (v is Enum) return v.index;
    return int.tryParse('$v') ?? 0;
  }

  // ------------------------------------------------------------- signals

  static Future<void> _listen(Session session, UuidValue space) async {
    final key = space.uuid;
    if (_listeners.containsKey(key)) return;
    final s = _listenerSession ??= await session.serverpod.createSession(
      enableLogging: false,
    );
    void listener(SerializableModel m) {
      // This instance's own tool writes are already written through.
      if (m is SheetsMergedSignal && m.hlc == ownSignal) return;
      markStale(space);
    }

    _listeners[key] = listener;
    s.messages.addListener(SheetsSyncService.mergedChannel(space), listener);
  }

  static void _drop(String key) {
    final wb = _entries.remove(key);
    wb?.dispose();
    final listener = _listeners.remove(key);
    final s = _listenerSession;
    if (listener != null && s != null && wb != null) {
      s.messages.removeListener(
        SheetsSyncService.mergedChannel(wb.space),
        listener,
      );
    }
  }

  static void _evictIdle() {
    final now = clock.now();
    for (final e in _entries.entries.toList()) {
      if (now.difference(e.value.lastUsed) > idleTimeout) _drop(e.key);
    }
  }

  static void _enforceBudget({required String keep}) {
    int total() => _entries.values.fold(0, (s, e) => s + e.estimatedBytes);
    while ((_entries.length > maxEntries || total() > budgetBytes) &&
        _entries.length > 1) {
      final lru = _entries.entries
          .where((e) => e.key != keep)
          .reduce(
            (a, b) => a.value.lastUsed.isBefore(b.value.lastUsed) ? a : b,
          );
      _drop(lru.key);
    }
  }
}
