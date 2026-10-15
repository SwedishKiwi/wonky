import 'dart:typed_data';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:wonky_client/wonky_client.dart'
    show Client, ReservedSpace, SheetsDirtySpace;
import 'package:wonky_sync_kit/tables.dart';
import 'package:wonky_sync_models/tables.dart';

import '../journal/change_journal.dart';

/// A signed-in user's local replica of one app (suite 12 §2, Slides 02 §9):
/// `<app>_<userId>.db` with the app's synced tables plus the local-only
/// bookkeeping tables (reserved spaces, dirty marks, the change journal).
///
/// Pure Dart (no Flutter): the app's sync controller owns one, and tests
/// open one on a temporary file. Apps subclass it for their table set and
/// app-specific reads (Sheets' `SheetsReplica`).
///
/// The local-only tables are the `database: client` models `ReservedSpace`,
/// `SheetsDirtySpace` and the journal's (every replica of the generated
/// client has them; each app's replica is its own file).
class SyncReplica {
  SyncReplica(
    this.session, {
    required this.userUuid,
    required this.tables,
    ChangeJournal? journal,
  }) : journal =
           journal ??
           ChangeJournal(
             session,
             tables: [for (final s in tables.modelTables) s.name],
           );

  /// Opens (creating and migrating) the database at [path] for [userUuid]
  /// (subclasses wrap it and call [prepare]).
  static Future<OfflineSyncDatabaseSession> openSession({
    required Client client,
    required String path,
    required UuidValue userUuid,
    bool isDebugMode = false,
  }) => client.createSyncSession(
    path,
    isDebugMode: isDebugMode,
    persistentUserId: userUuid,
  );

  /// Tunes the connection and installs the change journal (after
  /// [openSession]).
  Future<void> prepare() async {
    await _tune();
    await journal.install();
  }

  /// `<prefix>_<userId>.db` (`sheets_…`, `slides_…`).
  static String fileName(String prefix, String userUuid) =>
      '${prefix}_$userUuid.db';

  /// SQLite page cache of the writer connection (KiB). The default 2 MB
  /// makes big writes spill: random-UUID indexes outgrow it after ~50k rows
  /// and every insert then touches uncached pages (Sheets 13 §7.5).
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

  final OfflineSyncDatabaseSession session;
  final UuidValue userUuid;

  /// The app's synced tables.
  final SyncTableSet tables;

  final ChangeJournal journal;

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

  /// Whether the visible row [id] of [table] is on the device.
  Future<bool> hasRow(String table, UuidValue id) async =>
      (await tables.of(table).findByIds(session, [id])).isNotEmpty;

  /// Whether the root row of [space] (`SyncTableSet.rootTable`, whose id is
  /// the space id) is on the device: the file has arrived.
  Future<bool> hasRoot(UuidValue space) => hasRow(
    tables.rootTable ?? (throw StateError('The table set has no root table')),
    space,
  );

  /// Ids of the visible root rows on the device (the files available
  /// offline).
  Future<Set<UuidValue>> rootIds() async {
    final root = tables.rootTable;
    if (root == null) return const {};
    final rows = await tables.of(root).findWhere(session);
    return {for (final r in rows) r.id};
  }

  /// Visible row counts per table of [space] (download progress, compared
  /// with the server's `spaceStats`).
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

  /// Visible rows of [table] per space on this device (device caps, suite
  /// 12 intro).
  Future<Map<UuidValue, int>> rowCountsBySpace(String table) async {
    final result = await db.unsafeQuery(
      'SELECT s."uuidSpaceId", count(*) FROM "crdt_data_rows" r '
      'JOIN "crdt_schema_tables" t ON t."id" = r."tblId" '
      'JOIN "offline_sync_spaces" s ON s."id" = r."spaceId" '
      "WHERE t.\"name\" = '$table' AND r.\"visibility\" <= 2 "
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
      for (final spec in tables.all.reversed) {
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

  /// The reserved space ids on this device, oldest first.
  Future<List<UuidValue>> reservedSpaces() async => [
    for (final r in await reservations()) r.spaceUuid,
  ];

  Future<void> addReservations(List<UuidValue> spaces) async {
    if (spaces.isEmpty) return;
    final known = {for (final r in await reservations()) r.spaceUuid};
    await ReservedSpace.db.insert(session, [
      for (final s in spaces)
        if (!known.contains(s)) ReservedSpace(spaceUuid: s),
    ]);
  }

  /// Reservations whose membership has reached this device (usable for
  /// creating a file now, online or offline), oldest first.
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

  /// Every model row of the space with local id [spaceKey], table by table
  /// in dependency order, in pages of [pageSize] (keyset paging by id).
  /// Tables in [skipTables] are left out (Sheets' viewport-first loading
  /// reads the cells separately). [onPage] reports the rows read so far.
  Future<List<(String, Map<String, Object?>)>> loadSpace(
    int spaceKey, {
    int pageSize = 10000,
    Set<String> skipTables = const {},
    void Function(int rowsRead)? onPage,
  }) async {
    final out = <(String, Map<String, Object?>)>[];
    for (final spec in tables.modelTables) {
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

  /// Current visible rows of [ids] per table (column maps by row id).
  Future<Map<String, Map<String, Map<String, Object?>>>> readRows(
    Map<String, Set<UuidValue>> ids,
  ) async {
    final out = <String, Map<String, Map<String, Object?>>>{};
    for (final e in ids.entries) {
      final spec = tables.byName[e.key];
      if (spec == null || e.value.isEmpty) continue;
      final rows = await spec.findByIds(session, e.value);
      out[e.key] = {for (final r in rows) r.id.uuid: spec.toColumns(r)};
    }
    return out;
  }

  /// Empties every table of the database (*Clear local data* on the web,
  /// where the database file can't be deleted). One transaction with
  /// deferred foreign keys, so the table order doesn't matter.
  Future<void> clearAllTables() => db.transaction((tx) async {
    await db.unsafeExecute('PRAGMA defer_foreign_keys = ON', transaction: tx);
    final names = await db.unsafeQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'serverpod_migration%'",
      transaction: tx,
    );
    for (final t in names) {
      await db.unsafeExecute('DELETE FROM "${t[0]}"', transaction: tx);
    }
  });
}

/// Hex of the 16 bytes of [u] (SQLite blob literals `x'…'`).
String _hex(UuidValue u) => [
  for (final b in Uint8List.fromList(u.toBytes()))
    b.toRadixString(16).padLeft(2, '0'),
].join();
