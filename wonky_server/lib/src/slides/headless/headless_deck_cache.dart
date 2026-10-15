import 'dart:async';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_slides_core/model.dart' show DeckModel;
import 'package:wonky_slides_core/schema.dart' show SlidesTables;
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_models/tables.dart' show SlidesSyncedTables;

import '../../platform/cluster/cluster.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../sheets/sync/sync_db.dart';
import '../sync/slides_sync_service.dart';

/// One cached deck of [HeadlessDeckCache]: the core [DeckModel] of a deck
/// space (admin read of every synced row) and its freshness.
class CachedDeck {
  CachedDeck({
    required this.space,
    required this.model,
    required this.watermark,
    required this.estimatedBytes,
  }) : loadedAt = clock.now(),
       lastUsed = clock.now(),
       lastChecked = clock.now();

  /// The deck (space) uuid.
  final UuidValue space;

  final DeckModel model;

  /// `txid_snapshot_xmin` when the model was last loaded or patched: rows
  /// written by that transaction or later ones are re-read by a patch.
  int watermark;

  /// Rough memory footprint (cache budget).
  int estimatedBytes;

  final DateTime loadedAt;
  DateTime lastUsed;
  DateTime lastChecked;

  /// Set by merge signals: the next open patches first.
  bool stale = false;

  /// Incremental patches applied (tests, diagnostics).
  int patches = 0;

  /// Applies row changes (write-through or patch).
  void apply(Iterable<RowChange> changes) {
    model.applyChanges(changes);
    lastUsed = clock.now();
  }

  /// Estimates the memory of a deck from its row counts (elements carry
  /// JSON and text: ~1 KB; other rows ~300 bytes).
  static int estimate(Map<String, int> counts) {
    var bytes = 64 * 1024;
    counts.forEach((table, n) {
      bytes += table == SlidesTables.slideElement ? n * 1024 : n * 300;
    });
    return bytes;
  }
}

/// The per-instance cache of headless decks (Slides 11 §2.1, pattern of
/// Sheets' `HeadlessWorkbookProvider`): LRU by deck uuid, ≤ [maxEntries]
/// decks or [budgetBytes], idle entries evicted after [idleTimeout].
///
/// **Invalidation**: `slidesSync`'s `onMergeSuccess` posts
/// `slides:merged:<space>` (relayed to every instance by the cluster bus);
/// the cached entry is marked stale and **patched** on its next use by
/// re-reading the rows of the space whose CRDT tuples changed since the
/// entry's transaction watermark. More than [maxPatchRows] changed rows,
/// or a failure, reload the entry. Entries not checked for [recheckAfter]
/// are patched too (server writes of other instances whose signal was
/// lost). This instance's own server writes are written through
/// ([writeThrough]) and their signal ([ownSignal]) ignored here.
abstract final class HeadlessDeckCache {
  /// Memory budget (`wonky.slides.headlessCacheMb`, default 512 MB).
  static int budgetBytes = 512 * 1024 * 1024;

  /// Maximum number of cached decks.
  static int maxEntries = 200;

  /// Entries idle longer than this are evicted.
  static Duration idleTimeout = const Duration(minutes: 15);

  /// Entries are re-checked against the database after this long.
  static Duration recheckAfter = const Duration(seconds: 60);

  /// A patch touching more rows than this reloads instead.
  static int maxPatchRows = 20000;

  /// How long a mutating call waits for the deck's write lock.
  static Duration lockTimeout = const Duration(seconds: 30);

  static const _chunk = 5000;

  static final Map<String, CachedDeck> _entries = {};
  static final Map<String, Future<CachedDeck>> _loading = {};
  static final Map<String, Future<void>> _locks = {};
  static Session? _listenerSession;
  static final Map<String, void Function(SerializableModel)> _listeners = {};

  /// The `hlc` of the merge signals this instance posts after its own
  /// server writes.
  static String get ownSignal => 'server:${Cluster.instanceId}';

  /// Full loads (tests, diagnostics).
  static int loads = 0;

  /// The cached deck of [space] without loading (tests).
  static CachedDeck? peek(UuidValue space) => _entries[space.uuid];

  /// Cached decks (tests).
  static Iterable<UuidValue> get cachedSpaces =>
      _entries.values.map((e) => e.space);

  /// The deck of [space]: cached (patched when stale or due) or loaded.
  static Future<CachedDeck> open(Session session, UuidValue space) async {
    final key = space.uuid;
    _evictIdle();
    final cached = _entries[key];
    if (cached != null) {
      cached.lastUsed = clock.now();
      if (cached.stale ||
          clock.now().difference(cached.lastChecked) > recheckAfter) {
        if (!await _patch(session, cached)) {
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
      final deck = await future;
      _entries[key] = deck;
      await _listen(session, space);
      _enforceBudget(keep: key);
      return deck;
    } finally {
      unawaited(_loading.remove(key));
    }
  }

  /// Applies rows written on this instance to the cached model (if any).
  static void writeThrough(UuidValue space, List<RowChange> applied) {
    final deck = _entries[space.uuid];
    if (deck == null || applied.isEmpty) return;
    try {
      deck.apply(applied);
    } on Object {
      _drop(space.uuid);
    }
  }

  /// Marks the cached deck of [space] stale (merge signal).
  static void markStale(UuidValue space) => _entries[space.uuid]?.stale = true;

  /// Drops the cached deck of [space].
  static void invalidate(UuidValue space) => _drop(space.uuid);

  /// Drops every entry (tests).
  static void clear() {
    for (final k in _entries.keys.toList()) {
      _drop(k);
    }
  }

  /// Runs [body] holding the write lock of [space] (11 §2.1: mutating
  /// calls on one deck are serialized per instance); `busy` after
  /// [lockTimeout].
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
            'Another change to this presentation is still running. Try '
            'again.',
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

  static Future<CachedDeck> _load(Session session, UuidValue space) async {
    final watermark = await _snapshotXmin(session);
    final rows = await readSpace(session, space);
    if (rows[SlidesTables.deck]?.isEmpty ?? true) {
      throw Errors.notFound('Presentation');
    }
    final model = DeckModel.fromRows(space.uuid, [
      for (final table in SlidesTables.dependencyOrder)
        for (final row in rows[table]?.values ?? const <Map<String, Object?>>[])
          (table, row),
    ]);
    loads++;
    return CachedDeck(
      space: space,
      model: model,
      watermark: watermark,
      estimatedBytes: CachedDeck.estimate({
        for (final e in rows.entries) e.key: e.value.length,
      }),
    );
  }

  static Future<int> _snapshotXmin(Session session) async {
    final r = await session.db.unsafeQuery(
      'SELECT txid_snapshot_xmin(txid_current_snapshot())',
    );
    return r.first[0] as int;
  }

  static Future<bool> _patch(Session session, CachedDeck deck) async {
    try {
      final spaceRow = await OfflineSyncSpace.db.findFirstRow(
        session,
        where: (t) => t.uuidSpaceId.equals(deck.space),
      );
      if (spaceRow == null) return false;
      final next = await _snapshotXmin(session);
      final xid = deck.watermark & 0xFFFFFFFF;
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
        if (SlidesTables.nonModelTables.contains(table)) continue;
        if (SlidesSyncedTables.byName[table] == null) continue;
        final id = _uuid(row[1]);
        if (_visibilityIndex(row[2]) <= 2) {
          visible.putIfAbsent(table, () => {}).add(id);
        } else {
          hidden.add((table, id));
        }
      }
      final db = syncSessionOf(session);
      final changes = <RowChange>[];
      for (final table in SlidesTables.dependencyOrder) {
        final ids = visible[table];
        if (ids == null) continue;
        final spec = SlidesSyncedTables.of(table);
        final found = <String>{};
        for (final r in await spec.findByIds(db, ids)) {
          final cols = spec.toColumns(r);
          final id = cols['id']! as String;
          found.add(id);
          changes.add(RowChange.insert(table, id, cols));
        }
        for (final id in ids) {
          if (!found.contains(id.uuid)) {
            changes.add(RowChange.delete(table, id.uuid, const {}));
          }
        }
      }
      for (final table in SlidesTables.dependencyOrder.reversed) {
        for (final (t, id) in hidden) {
          if (t == table) changes.add(RowChange.delete(t, id.uuid, const {}));
        }
      }
      if (changes.isNotEmpty) deck.apply(changes);
      deck
        ..watermark = next
        ..stale = false
        ..lastChecked = clock.now()
        ..patches += 1;
      return true;
    } on Object catch (e, st) {
      session.log(
        'Headless deck patch of ${deck.space} failed: $e',
        level: LogLevel.warning,
        stackTrace: st,
      );
      return false;
    }
  }

  static UuidValue _uuid(Object? v) =>
      v is UuidValue ? v : UuidValue.withValidation('$v');

  static int _visibilityIndex(Object? v) {
    if (v is int) return v;
    if (v is Enum) return v.index;
    return int.tryParse('$v') ?? 0;
  }

  /// Every visible row of deck [space] by table (admin read, no
  /// membership needed), as column maps (`SyncedTableSpec.toColumns`:
  /// UUIDs as strings — the client model's form). The change log is
  /// skipped.
  static Future<Map<String, Map<String, Map<String, Object?>>>> readSpace(
    Session session,
    UuidValue space,
  ) async {
    final spaceRow = await OfflineSyncSpace.db.findFirstRow(
      session,
      where: (t) => t.uuidSpaceId.equals(space),
    );
    final result = <String, Map<String, Map<String, Object?>>>{};
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
    for (final name in SlidesTables.dependencyOrder) {
      if (SlidesTables.nonModelTables.contains(name)) continue;
      final spec = SlidesSyncedTables.byName[name];
      final tableIds = byTable[name];
      if (spec == null || tableIds == null) continue;
      final list = tableIds.toList();
      final rows = <String, Map<String, Object?>>{};
      for (var i = 0; i < list.length; i += _chunk) {
        final chunk = list.sublist(
          i,
          i + _chunk > list.length ? list.length : i + _chunk,
        );
        for (final r in await spec.findByIds(db, chunk)) {
          final cols = spec.toColumns(r);
          rows[cols['id']! as String] = cols;
        }
      }
      result[name] = rows;
    }
    return result;
  }

  // ------------------------------------------------------------- signals

  static Future<void> _listen(Session session, UuidValue space) async {
    final key = space.uuid;
    if (_listeners.containsKey(key)) return;
    final s = _listenerSession ??= await session.serverpod.createSession(
      enableLogging: false,
    );
    void listener(SerializableModel m) {
      if (m is SheetsMergedSignal && m.hlc == ownSignal) return;
      markStale(space);
    }

    _listeners[key] = listener;
    s.messages.addListener(SlidesSyncService.mergedChannel(space), listener);
  }

  static void _drop(String key) {
    final deck = _entries.remove(key);
    final listener = _listeners.remove(key);
    final s = _listenerSession;
    if (listener != null && s != null && deck != null) {
      s.messages.removeListener(
        SlidesSyncService.mergedChannel(deck.space),
        listener,
      );
    }
    if (deck != null) unawaited(deck.model.dispose());
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
