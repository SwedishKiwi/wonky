import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:wonky_client/wonky_client.dart'
    show AccessRole, Client, SpaceStats, SubscribeResult, UuidValue;
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_kit/tables.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart';
import 'package:wonky_sync_models/tables.dart';
import 'package:wonky_sync_models/wonky_sync_models.dart';

/// The kit is table-agnostic; its tests use the synced tables that exist
/// (the Sheets ones) with `spreadsheet` as the root table.
final testTables = SyncTableSet(
  SyncedTables.all,
  nonModelTables: const {'change_log', 'script_user_property'},
  rootTable: 'spreadsheet',
);

/// Test user of the replicas.
final testUser = UuidValue.fromString('0190a000-0000-7000-8000-0000000000aa');

/// Space ids for tests.
UuidValue space(int n) => UuidValue.fromString(
  '0190a000-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}',
);

/// A writer recording its change-log entries instead of storing them.
class RecordingWriter extends SyncWriter {
  RecordingWriter(super.replica);

  final List<ChangeLogEntry> logs = [];

  @override
  Future<void> writeChangeLog(
    DatabaseSession session,
    ChangeLogEntry entry,
    Transaction transaction,
  ) async => logs.add(entry);

  @override
  ChangeSummary summarize(List<RowChange> changes) =>
      JsonChangeSummary({'count': changes.length});
}

/// Opens a replica of [testTables] on a temporary file (closed and deleted
/// after the test).
Future<SyncReplica> openTestReplica({String? path}) async {
  final String file;
  if (path == null) {
    final dir = await Directory.systemTemp.createTemp('wonky_sync_kit_');
    addTearDown(() => dir.delete(recursive: true));
    file = '${dir.path}/kit.db';
  } else {
    file = path;
  }
  final session = await SyncReplica.openSession(
    client: Client('http://localhost:1/'),
    path: file,
    userUuid: testUser,
  );
  final replica = SyncReplica(session, userUuid: testUser, tables: testTables);
  await replica.prepare();
  addTearDown(replica.close);
  return replica;
}

String hexOf(UuidValue u) => [
  for (final b in Uint8List.fromList(u.toBytes()))
    b.toRadixString(16).padLeft(2, '0'),
].join();

/// Puts [space] into the replica's membership cache, as a sync cycle does.
Future<void> grantLocally(
  SyncReplica replica,
  UuidValue space, {
  String role = 'readWrite',
}) async {
  final db = replica.db;
  await db.unsafeExecute(
    'INSERT OR IGNORE INTO "offline_sync_spaces" ("uuidSpaceId") '
    "VALUES (x'${hexOf(space)}')",
  );
  await db.unsafeExecute(
    'DELETE FROM "offline_sync_space_members" WHERE "userUuid" = '
    "x'${hexOf(replica.userUuid)}' AND \"spaceId\" = (SELECT \"id\" FROM "
    "\"offline_sync_spaces\" WHERE \"uuidSpaceId\" = x'${hexOf(space)}')",
  );
  await db.unsafeExecute(
    'INSERT INTO "offline_sync_space_members" ("spaceId", "userUuid", "role") '
    "SELECT \"id\", x'${hexOf(replica.userUuid)}', '$role' FROM "
    "\"offline_sync_spaces\" WHERE \"uuidSpaceId\" = x'${hexOf(space)}'",
  );
}

/// Removes [space] from the membership cache (unshared).
Future<void> revokeLocally(SyncReplica replica, UuidValue space) =>
    replica.db.unsafeExecute(
      'DELETE FROM "offline_sync_space_members" WHERE "spaceId" = (SELECT '
      "\"id\" FROM \"offline_sync_spaces\" WHERE \"uuidSpaceId\" = "
      "x'${hexOf(space)}')",
    );

/// The root row of [space] as an insert.
RowChange rootRow(UuidValue space, {String title = 'Test'}) => RowChange.insert(
  'spreadsheet',
  space.uuid,
  testTables
      .of('spreadsheet')
      .toColumns(
        Spreadsheet(
          id: space,
          title: title,
          locale: 'en_US',
          timeZone: 'UTC',
          themeJson: '{}',
          createdBy: testUser,
          createdAt: DateTime.utc(2026, 10, 15),
        ),
      ),
);

/// A child row ([n]th sheet) of [space].
RowChange childRow(UuidValue space, int n, {String name = 'Sheet'}) =>
    RowChange.insert(
      'sheet',
      sheetId(space, n).uuid,
      testTables
          .of('sheet')
          .toColumns(
            Sheet(
              id: sheetId(space, n),
              spreadsheetId: space,
              name: '$name $n',
              sortKey: 'a$n',
              createdAt: DateTime.utc(2026, 10, 15),
            ),
          ),
    );

/// The id of the [n]th child row of [space].
UuidValue sheetId(UuidValue space, int n) => UuidValue.fromString(
  '0190b000-0000-7000-8000-'
  '${space.uuid.substring(28)}${n.toRadixString(16).padLeft(4, '0')}',
);

/// Writes the root row and [children] child rows into [space] (granted
/// first).
Future<void> createFile(
  SyncReplica replica,
  SyncWriter writer,
  UuidValue space, {
  int children = 1,
}) async {
  await grantLocally(replica, space);
  await writer.write(
    spaceId: space,
    changes: [
      rootRow(space),
      for (var i = 0; i < children; i++) childRow(space, i),
    ],
    label: 'Create',
    actorKind: 'user',
    sessionId: 'test',
  );
}

/// Polls [condition] (real async work: SQLite runs in a worker).
Future<void> eventually(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met in $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// A [SyncConnectivity] on a plain notifier.
class FakeConnectivity implements SyncConnectivity {
  FakeConnectivity({bool online = true}) : online = ValueNotifier(online);

  @override
  final ValueNotifier<bool> online;

  int failures = 0;
  int successes = 0;

  @override
  void reportFailure() => failures++;

  @override
  void reportSuccess() => successes++;
}

/// A [SyncSessionHost] on a local replica without a server.
class FakeHost implements SyncSessionHost<SyncReplica, RecordingWriter> {
  FakeHost(this.replica, {bool online = false})
    : writer = RecordingWriter(replica),
      online = ValueNotifier(online);

  @override
  final SyncReplica replica;

  @override
  final RecordingWriter writer;

  @override
  final ValueNotifier<bool> online;

  @override
  String get sessionId => 'test-session';

  final StreamController<UuidValue> mergesController =
      StreamController.broadcast();

  @override
  Stream<UuidValue> get merges => mergesController.stream;

  int kicks = 0;
  int cursorChanges = 0;

  @override
  Future<SubscribeResult> subscribe(UuidValue itemUuid) async =>
      throw const SyncOfflineException();

  @override
  Future<SpaceStats> spaceStats(UuidValue itemUuid) async =>
      throw const SyncOfflineException();

  @override
  void kick() => kicks++;

  @override
  void journalCursorsChanged() => cursorChanges++;
}

/// A subscribe result for [space] with [totalRows] rows on the server.
SubscribeResult subscribed(UuidValue space, {int totalRows = 2}) =>
    SubscribeResult(
      spaceUuid: space,
      role: AccessRole.editor,
      canWrite: true,
      alreadyMember: false,
      stats: SpaceStats(
        spaceUuid: space,
        rowCounts: const {},
        totalRows: totalRows,
        sheetCount: 0,
        cellCount: 0,
        gridCells: 0,
      ),
    );
