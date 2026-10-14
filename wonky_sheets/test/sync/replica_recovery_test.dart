import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show Client, UuidValue;
import 'package:wonky_sheets/features/sync/replica_recovery.dart';
import 'package:wonky_sheets/features/sync/sheets_replica.dart';
import 'package:wonky_sheets/features/sync/sheets_writer.dart';
import 'package:wonky_sheets_core/model.dart';

import 'support/sync_harness.dart';

final dirtySpace = UuidValue.fromString('0190a000-0000-7000-8000-0000000000f1');
final cleanSpace = UuidValue.fromString('0190a000-0000-7000-8000-0000000000f2');

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wonky_sheets_recovery_');
    path = '${dir.path}/sheets.db';
    addTearDown(() => dir.delete(recursive: true));
  });

  Future<SheetsReplica> openReplica() => SheetsReplica.open(
    client: Client('http://localhost:1/'),
    path: path,
    userUuid: testUser,
  );

  test('Given a replica with unsynced changes, when it is read for recovery '
      'then the dirty spreadsheets come back complete and zip as XLSX plus '
      'raw rows', () async {
    final replica = await openReplica();
    await createSpreadsheet(replica, dirtySpace, title: 'Budget', rows: 5);
    await createSpreadsheet(replica, cleanSpace, title: 'Synced', rows: 5);
    final model = await reloadModel(replica, dirtySpace);
    final plan = const SheetsMutationPlanner().plan(
      SetCellInputs(
        sheetId: model.sheets.single.id,
        row: 1,
        col: 1,
        inputs: [
          [CellInput.user('42'), CellInput.user('unsynced')],
        ],
      ),
      model,
      PlanContext(userId: testUser.uuid, now: DateTime.utc(2026, 10, 3)),
    );
    await SheetsWriter(replica).write(
      spaceId: dirtySpace,
      changes: plan.changes,
      plan: plan,
      label: plan.label,
      actorKind: 'user',
      sessionId: 'test',
    );
    // The other spreadsheet finished syncing.
    await replica.clearDirty([
      cleanSpace,
    ], DateTime.now().add(Duration(days: 1)));
    final expected = canonical(await reloadModel(replica, dirtySpace));
    await replica.close();

    final recovery = await ReplicaRecovery.read(path);

    expect(recovery, isNotNull);
    expect(recovery!.spreadsheets.map((s) => s.title), ['Budget']);
    final recovered = recovery.spreadsheets.single;
    expect(
      canonical(WorkbookModel.fromRows(recovered.spaceUuid, recovered.rows)),
      expected,
    );

    final zip = ZipDecoder().decodeBytes(recovery.toZip());
    expect(
      zip.files.map((f) => f.name),
      containsAll(['Budget.xlsx', 'rows.json']),
    );
    final rows =
        jsonDecode(
              utf8.decode(
                zip.files.firstWhere((f) => f.name == 'rows.json').content,
              ),
            )
            as Map<String, Object?>;
    final sheets = rows['spreadsheets']! as List;
    expect((sheets.single as Map)['title'], 'Budget');
    expect(
      ReplicaRecovery.fileName(DateTime(2026, 10, 3)),
      'Wonky Sheets unsynced changes 2026-10-03.zip',
    );
  });

  test('Given a file that is not a database, when it is read for recovery '
      'then nothing is recovered', () async {
    await File(path).writeAsString('not sqlite');

    expect(await ReplicaRecovery.read(path), isNull);
  });
}
