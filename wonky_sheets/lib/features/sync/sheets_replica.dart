import 'dart:typed_data';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sheets_core/model.dart' show SheetsTables;
import 'package:wonky_sync_models/tables.dart';

import 'change_journal.dart';

/// Opens the local database of a user (tests pass their own opener).
typedef SheetsReplicaOpener = Future<SheetsReplica> Function(UuidValue user);

/// The signed-in user's Sheets replica: `sheets_<userId>.db`, the synced
/// tables plus the local-only tables (`ReservedSpace`, `SheetsDirtySpace`,
/// the change journal), suite 12 §2 and Sheets 02 §4.
///
/// Pure Dart (no Flutter): the app's `SheetsSyncController` owns one, and
/// tests open one on a temporary file.
class SheetsReplica {
  SheetsReplica(this.session, {required this.userUuid})
    : journal = SheetsChangeJournal(session);

  /// Opens (creating and migrating) the replica at [path].
  static Future<SheetsReplica> open({
    required Client client,
    required String path,
    required UuidValue userUuid,
    bool isDebugMode = false,
  }) async {
    final session = await client.createSyncSession(
      path,
      isDebugMode: isDebugMode,
      persistentUserId: userUuid,
    );
    final replica = SheetsReplica(session, userUuid: userUuid);
    await replica._tune();
    await replica.journal.install();
    return replica;
  }

  /// SQLite page cache of the writer connection (KiB). The default 2 MB
  /// makes big writes spill: the random-UUID indexes of `cell` and
  /// `crdt_data_rows` outgrow it after ~50k cells and every insert then
  /// touches uncached pages (Sheets 13 §7.5).
  static const cacheSizeKiB = 65536;

  Future<void> _tune() => db.transaction((tx) async {
    await db.unsafeExecute(
      'PRAGMA cache_size = -$cacheSizeKiB',
      transaction: tx,
    );
    await db.unsafeExecute('PRAGMA temp_store = MEMORY', transaction: tx);
    await db.unsafeExecute(
      'PRAGMA wal_autocheckpoint = 20000',
      transaction: tx,
    );
  });

  /// `sheets_<userId>.db`.
  static String fileNameFor(String userUuid) => 'sheets_$userUuid.db';

  final OfflineSyncDatabaseSession session;
  final UuidValue userUuid;
  final SheetsChangeJournal journal;

  OfflineSyncDatabase get db => session.db;

  bool _closed = false;
  bool get isClosed => _closed;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await session.close();
  }

  // ---------------------------------------------------------------- spaces

  /// The local integer id (`offline_sync_spaces.id`) of [space], or null when
  /// the space hasn't reached this device.
  Future<int?> spaceKey(UuidValue space) async {
    final row = await OfflineSyncSpace.db.findFirstRow(
      session,
      where: (t) => t.uuidSpaceId.equals(space),
    );
    return row?.id;
  }

  /// The user's role in [space] from the membership cache (null = not a
  /// member on this device).
  Future<OfflineSyncSpaceRole?> roleOf(UuidValue space) =>
      OfflineSyncSpaceMembership.roleOf(
        session,
        userUuid: userUuid,
        spaceUuid: space,
      );

  /// Spaces this device is a member of (membership cache).
  Future<Set<UuidValue>> memberSpaces() async => {
    ...await OfflineSyncSpaceMembership.memberSpaces(session, userUuid),
  };

  /// Whether the spreadsheet row of [space] is on the device.
  Future<bool> hasSpreadsheet(UuidValue space) async =>
      (await Spreadsheet.db.findById(session, space)) != null;

  /// Visible row counts per table of [space] (download progress, compared
  /// with `sheets.spaceStats`).
  Future<Map<String, int>> rowCounts(UuidValue space) async {
    final key = await spaceKey(space);
    if (key == null) return const {};
    final result = await db.unsafeQuery(
      'SELECT t."name", count(*) FROM "crdt_data_rows" r '
      'JOIN "crdt_schema_tables" t ON t."id" = r."tblId" '
      'WHERE r."spaceId" = $key AND r."visibility" <= 2 GROUP BY t."name"',
    );
    return {for (final row in result) row[0]! as String: row[1]! as int};
  }

  // ----------------------------------------------------------- maintenance

  /// Visible cells per space on this device (the IndexedDB cell cap, suite
  /// 12 intro).
  Future<Map<UuidValue, int>> cellCountsBySpace() async {
    final result = await db.unsafeQuery(
      'SELECT s."uuidSpaceId", count(*) FROM "crdt_data_rows" r '
      'JOIN "crdt_schema_tables" t ON t."id" = r."tblId" '
      'JOIN "offline_sync_spaces" s ON s."id" = r."spaceId" '
      "WHERE t.\"name\" = 'cell' AND r.\"visibility\" <= 2 "
      'GROUP BY r."spaceId"',
    );
    return {
      for (final row in result)
        UuidValue.fromByteList(Uint8List.fromList(row[0]! as List<int>)):
            row[1]! as int,
    };
  }

  /// Spaces whose rows are still on disk although this user is no longer
  /// a member (evicted, unshared, trashed): candidates for [purgeSpace].
  Future<List<(int, UuidValue)>> hiddenSpaces() async {
    final result = await db.unsafeQuery(
      'SELECT s."id", s."uuidSpaceId" FROM "offline_sync_spaces" s '
      'WHERE EXISTS (SELECT 1 FROM "crdt_data_rows" r '
      'WHERE r."spaceId" = s."id") '
      'AND NOT EXISTS (SELECT 1 FROM "offline_sync_space_members" m '
      'WHERE m."spaceId" = s."id" AND m."userUuid" = '
      "x'${_hex(userUuid)}')",
    );
    return [
      for (final row in result)
        (
          row[0]! as int,
          UuidValue.fromByteList(Uint8List.fromList(row[1]! as List<int>)),
        ),
    ];
  }

  /// Deletes every row of the space with local id [spaceKey] and its sync
  /// metadata, including the space's sync checkpoint, so a later grant
  /// downloads the space again from scratch (suite 12 §2.3 weekly purge;
  /// upstream U2). Only for spaces that are no longer members and have no
  /// unsynced writes.
  Future<void> purgeSpace(int spaceKey) async {
    await db.transaction((tx) async {
      for (final spec in SyncedTables.all.reversed) {
        await db.unsafeExecute(
          'DELETE FROM "${spec.name}" WHERE "spaceId" = $spaceKey',
          transaction: tx,
        );
      }
      await db.unsafeExecute(
        'DELETE FROM "crdt_data_rows" WHERE "spaceId" = $spaceKey',
        transaction: tx,
      );
      await db.unsafeExecute(
        'DELETE FROM "offline_sync_space_nodes" WHERE "spaceId" = $spaceKey',
        transaction: tx,
      );
    });
  }

  // ---------------------------------------------------------- reservations

  /// Reserved spaces on this device, oldest first.
  Future<List<ReservedSpace>> reservations() =>
      ReservedSpace.db.find(session, orderBy: (t) => t.reservedAt);

  Future<void> addReservations(List<UuidValue> spaces) async {
    if (spaces.isEmpty) return;
    final known = {for (final r in await reservations()) r.spaceUuid};
    await ReservedSpace.db.insert(session, [
      for (final s in spaces)
        if (!known.contains(s)) ReservedSpace(spaceUuid: s),
    ]);
  }

  /// Reservations whose membership has reached this device (usable for
  /// creating a spreadsheet now, online or offline), oldest first.
  Future<List<UuidValue>> usableReservations() async {
    final all = await reservations();
    if (all.isEmpty) return const [];
    final members = await memberSpaces();
    return [
      for (final r in all)
        if (members.contains(r.spaceUuid)) r.spaceUuid,
    ];
  }

  Future<void> removeReservation(UuidValue space) => ReservedSpace.db
      .deleteWhere(session, where: (t) => t.spaceUuid.equals(space));

  // ----------------------------------------------------------- dirty spaces

  /// Records that [space] has local writes (pending-change guard).
  Future<void> markDirty(UuidValue space) async {
    if (space == userUuid) return;
    await db.unsafeExecute(
      'INSERT INTO "sheets_dirty_space" ("spaceUuid", "markedAt") '
      "VALUES (x'${_hex(space)}', ${DateTime.now().millisecondsSinceEpoch}) "
      'ON CONFLICT ("spaceUuid") DO UPDATE SET "markedAt" = excluded."markedAt"',
    );
  }

  /// Spaces with local writes since the last complete sync.
  Future<List<UuidValue>> dirtySpaces() async => [
    for (final d in await SheetsDirtySpace.db.find(session)) d.spaceUuid,
  ];

  /// Clears the dirty marks of [spaces] marked at or before [before].
  Future<void> clearDirty(Iterable<UuidValue> spaces, DateTime before) async {
    final set = spaces.toSet();
    if (set.isEmpty) return;
    await SheetsDirtySpace.db.deleteWhere(
      session,
      where: (t) =>
          t.spaceUuid.inSet(set) &
          ((t.markedAt < before) | t.markedAt.equals(before)),
    );
  }

  // ------------------------------------------------------------------ rows

  /// Tables loaded into a workbook model (the change log and per-user
  /// script properties are not part of the model).
  static final List<SyncedTableSpec<TableRow<UuidValue>>> modelTables = [
    for (final s in SyncedTables.all)
      if (s.name != 'change_log' && s.name != 'script_user_property') s,
  ];

  /// Every model row of the space with local id [spaceKey], table by table
  /// in dependency order, in pages of [pageSize] (keyset paging by id).
  /// Tables in [skipTables] are left out (viewport-first loading reads the
  /// cells separately, [loadCells]). [onPage] reports the rows read so far.
  Future<List<(String, Map<String, Object?>)>> loadSpace(
    int spaceKey, {
    int pageSize = 10000,
    Set<String> skipTables = const {},
    void Function(int rowsRead)? onPage,
  }) async {
    final out = <(String, Map<String, Object?>)>[];
    for (final spec in modelTables) {
      if (skipTables.contains(spec.name)) continue;
      final spaceColumn = spec.column(SyncedTableSpec.spaceIdColumn);
      if (spaceColumn is! ColumnInt) continue;
      final ColumnInt column = spaceColumn;
      UuidValue? last;
      while (true) {
        final after = last;
        final rows = await spec.findWhere(
          session,
          where: after == null
              ? column.equals(spaceKey)
              : column.equals(spaceKey) & (spec.idColumn > after),
          limit: pageSize,
        );
        for (final r in rows) {
          out.add((spec.name, spec.toColumns(r)));
        }
        onPage?.call(out.length);
        if (rows.length < pageSize) break;
        last = rows.last.id;
      }
    }
    return out;
  }

  /// Max row ids per [loadCells] query.
  static const cellQueryRows = 500;

  /// The cells of the rows [rowIds] of sheet [sheetId] (column maps), read
  /// through the `(sheetId, rowId)` index in queries of [cellQueryRows]
  /// rows.
  Future<List<Map<String, Object?>>> loadCells(
    String sheetId,
    List<String> rowIds,
  ) async {
    final spec = SyncedTables.of(SheetsTables.cell);
    final sheetColumn = spec.column('sheetId')! as ColumnUuid;
    final rowColumn = spec.column('rowId')! as ColumnUuid;
    final sheet = UuidValue.fromString(sheetId);
    final out = <Map<String, Object?>>[];
    for (var i = 0; i < rowIds.length; i += cellQueryRows) {
      final end = i + cellQueryRows > rowIds.length
          ? rowIds.length
          : i + cellQueryRows;
      final rows = await session.db.find<Cell>(
        where:
            sheetColumn.equals(sheet) &
            rowColumn.inSet({
              for (final id in rowIds.sublist(i, end)) UuidValue.fromString(id),
            }),
      );
      for (final r in rows) {
        out.add(spec.toColumns(r));
      }
    }
    return out;
  }

  /// Current visible rows of [ids] per table (column maps by row id).
  Future<Map<String, Map<String, Map<String, Object?>>>> readRows(
    Map<String, Set<UuidValue>> ids,
  ) async {
    final out = <String, Map<String, Map<String, Object?>>>{};
    for (final e in ids.entries) {
      final spec = SyncedTables.byName[e.key];
      if (spec == null || e.value.isEmpty) continue;
      final rows = await spec.findByIds(session, e.value);
      out[e.key] = {for (final r in rows) r.id.uuid: spec.toColumns(r)};
    }
    return out;
  }
}

String _hex(UuidValue u) => [
  for (final b in Uint8List.fromList(u.toBytes()))
    b.toRadixString(16).padLeft(2, '0'),
].join();
