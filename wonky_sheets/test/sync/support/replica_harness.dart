import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sheets/features/sync/sheets_replica.dart';
import 'package:wonky_sheets/features/sync/sheets_writer.dart';
import 'package:wonky_sheets_core/model.dart';

/// Replica helpers without the sync controller (no `wonky_app` import), for
/// writer and engine tests.

/// Test user of the local replicas.
final testUser = UuidValue.fromString('0190a000-0000-7000-8000-0000000000aa');

/// Opens a replica on a temporary file (closed and deleted after the test).
/// No server is involved: memberships are granted with [grantLocally].
Future<SheetsReplica> openTestReplica({UuidValue? user}) async {
  final dir = await Directory.systemTemp.createTemp('wonky_sheets_replica_');
  final replica = await SheetsReplica.open(
    client: Client('http://localhost:1/'),
    path: '${dir.path}/sheets.db',
    userUuid: user ?? testUser,
  );
  addTearDown(() async {
    await replica.close();
    await dir.delete(recursive: true);
  });
  return replica;
}

String hexOf(UuidValue u) => [
  for (final b in Uint8List.fromList(u.toBytes()))
    b.toRadixString(16).padLeft(2, '0'),
].join();

/// Puts [space] into the replica's membership cache, as a sync cycle does
/// after `sheets.subscribe` / `reserveSpaces`.
Future<void> grantLocally(
  SheetsReplica replica,
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
Future<void> revokeLocally(SheetsReplica replica, UuidValue space) =>
    replica.db.unsafeExecute(
      'DELETE FROM "offline_sync_space_members" WHERE "spaceId" = (SELECT '
      "\"id\" FROM \"offline_sync_spaces\" WHERE \"uuidSpaceId\" = "
      "x'${hexOf(space)}')",
    );

/// Writes a new spreadsheet into [space] (granted first) like
/// `createLocalSpreadsheet`, returning the plan.
Future<MutationPlan> createSpreadsheet(
  SheetsReplica replica,
  UuidValue space, {
  String title = 'Test',
  int rows = 50,
  int columns = 10,
}) async {
  await grantLocally(replica, space);
  final plan = const SheetsMutationPlanner().plan(
    CreateSpreadsheet(
      spreadsheetId: space.uuid,
      title: title,
      rows: rows,
      columns: columns,
    ),
    WorkbookModel(spreadsheetId: space.uuid),
    PlanContext(userId: replica.userUuid.uuid, now: DateTime.utc(2026, 10, 1)),
  );
  await SheetsWriter(replica).write(
    spaceId: space,
    changes: plan.changes,
    plan: plan,
    label: plan.label,
    actorKind: 'user',
    sessionId: 'test',
  );
  return plan;
}

/// A model of [space] read back from the replica (the "full reload").
Future<WorkbookModel> reloadModel(
  SheetsReplica replica,
  UuidValue space,
) async {
  final key = await replica.spaceKey(space);
  return WorkbookModel.fromRows(space.uuid, await replica.loadSpace(key!));
}

/// Canonical, comparable dump of a model (rows sorted, values normalized).
List<String> canonical(WorkbookModel model) {
  Object? norm(Object? v) => switch (v) {
    num() => v.toDouble(),
    DateTime() => v.toUtc().millisecondsSinceEpoch,
    _ => v,
  };
  return [
    for (final (table, columns) in model.allRows())
      '$table ${(columns.keys.toList()..sort()).map((k) => '$k=${norm(columns[k])}').join(' ')}',
  ]..sort();
}
