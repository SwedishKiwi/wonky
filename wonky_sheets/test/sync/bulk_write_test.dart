import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets/features/sync/sheets_replica.dart';
import 'package:wonky_sheets/features/sync/sheets_writer.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/ids.dart';
import 'package:wonky_sync_models/tables.dart';

import 'support/replica_harness.dart';

/// Offline-sync patch OS-7: the set-based engine write (`bulkWrite`) the
/// `SheetsWriter` uses must leave exactly the CRDT records the per-row ORM
/// calls leave (row visibility, tombstone generations, which fields carry
/// their own HLC) and the same domain rows. Two replicas apply the same
/// plans, one through the writer, one through the per-row calls of the
/// previous writer, and their records are compared after every step.
final space = UuidValue.fromString('0190a000-0000-7000-8000-0000000000f1');

/// The previous writer: one engine call per row change.
Future<void> writePerRow(SheetsReplica replica, List<RowChange> changes) =>
    replica.db.transactionForUser(replica.userUuid, (tx) async {
      for (final c in changes) {
        final spec = SyncedTables.of(c.table);
        final id = UuidValue.fromString(c.rowId);
        switch (c.op) {
          case RowOp.delete:
            await spec.deleteByIds(replica.session, [id], transaction: tx);
          case RowOp.update:
            await spec.updateColumns(
              replica.session,
              id,
              c.columnsAfter,
              transaction: tx,
            );
          case RowOp.insert:
            final visible = await spec.findByIds(replica.session, [
              id,
            ], transaction: tx);
            if (visible.isNotEmpty) {
              await spec.updateColumns(
                replica.session,
                id,
                {...c.columnsAfter}..remove(Cols.id),
                transaction: tx,
              );
            } else {
              await spec.insertRows(replica.session, [
                {...c.columnsAfter, Cols.id: c.rowId},
              ], transaction: tx);
            }
        }
      }
    }, spaceId: space);

/// Every CRDT row of the space: `table id → visibility, tombstone
/// generation and reason, the columns with their own field record, and the
/// domain values`.
Future<Map<String, String>> records(SheetsReplica replica) async {
  final key = await replica.spaceKey(space);
  final rows = await replica.db.unsafeQuery(
    'SELECT t."name", r."uuidRowId", r."visibility", d."clFlag", d."reason", '
    '(SELECT group_concat(c."name", \',\') FROM (SELECT c."name" FROM '
    '"crdt_data_fields" f JOIN "crdt_schema_columns" c ON c."id" = f."columnId" '
    'WHERE f."rowId" = r."id" ORDER BY c."name") c) '
    'FROM "crdt_data_rows" r JOIN "crdt_schema_tables" t ON t."id" = r."tblId" '
    'LEFT JOIN "crdt_data_tombstone" d ON d."rowId" = r."id" '
    'WHERE r."spaceId" = $key',
  );
  final out = <String, String>{};
  for (final r in rows) {
    final table = r[0]! as String;
    // The writer's change log rows (the per-row path writes none).
    if (table == 'change_log') continue;
    final id = UuidValue.fromByteList(Uint8List.fromList(r[1]! as List<int>));
    out['$table ${id.uuid}'] =
        'vis=${r[2]} tomb=${r[3]}/${r[4]} fields=${r[5]}';
  }
  final model = await reloadModel(replica, space);
  for (final (table, columns) in model.allRows()) {
    final id = columns[Cols.id];
    final values = (columns.keys.toList()..sort())
        .where((k) => k != Cols.createdAt)
        .map((k) => '$k=${columns[k]}')
        .join(' ');
    out['$table $id'] = '${out['$table $id']} $values';
  }
  return out;
}

void main() {
  late SheetsReplica bulk;
  late SheetsReplica perRow;
  late WorkbookModel model;

  setUp(() async {
    bulk = await openTestReplica();
    perRow = await openTestReplica();
    await grantLocally(bulk, space);
    await grantLocally(perRow, space);
    model = WorkbookModel(spreadsheetId: space.uuid);
  });

  var step = 0;
  Future<MutationPlan> apply(SheetsOperation op) async {
    final plan = const SheetsMutationPlanner().plan(
      op,
      model,
      PlanContext(userId: testUser.uuid, now: DateTime.utc(2026, 10, 1)),
    );
    model.applyPlan(plan);
    await SheetsWriter(bulk).write(
      spaceId: space,
      changes: plan.changes,
      plan: plan,
      label: plan.label,
      actorKind: 'user',
      sessionId: 'bulk-${step++}',
    );
    await writePerRow(perRow, plan.changes);
    return plan;
  }

  Future<void> writeBoth(List<RowChange> changes) async {
    model.applyChanges(changes);
    await SheetsWriter(bulk).write(
      spaceId: space,
      changes: changes,
      label: 'raw',
      actorKind: 'user',
      sessionId: 'bulk-${step++}',
    );
    await writePerRow(perRow, changes);
  }

  Future<void> expectSameRecords() async {
    final a = await records(bulk);
    final b = await records(perRow);
    expect(
      a.keys.toSet().difference(b.keys.toSet()),
      isEmpty,
      reason: 'only set-based',
    );
    expect(
      b.keys.toSet().difference(a.keys.toSet()),
      isEmpty,
      reason: 'only per row',
    );
    for (final k in a.keys) {
      expect(a[k], b[k], reason: k);
    }
  }

  test(
    'Given the same plans, when written set-based and per row, then the '
    'CRDT records and rows are identical: new cells, value and format '
    'updates, deletes, revives by undo, and a cell under a deleted row',
    // ~23 s alone: two SQLite replicas, one written row by row on purpose
    // (the previous writer is the reference). In a whole-suite run under
    // load it passed the default 30 s and failed; the time is not what is
    // tested here.
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      await apply(
        CreateSpreadsheet(
          spreadsheetId: space.uuid,
          title: 'Bulk',
          rows: 40,
          columns: 6,
        ),
      );
      final sheet = model.sheets.single;
      await expectSameRecords();

      // New cells (fresh inserts).
      await apply(
        SetCellInputs(
          sheetId: sheet.id,
          row: 0,
          col: 0,
          inputs: [
            for (var r = 0; r < 30; r++)
              [for (var c = 0; c < 6; c++) CellInput.user('v$r.$c')],
          ],
        ),
      );
      await expectSameRecords();

      // Value updates and a format update (named columns).
      await apply(
        SetCellInputs(
          sheetId: sheet.id,
          row: 5,
          col: 1,
          inputs: [
            for (var r = 0; r < 10; r++)
              [for (var c = 0; c < 3; c++) CellInput.user('${r * c}')],
          ],
        ),
      );
      await apply(
        SetFormat(
          [ResolvedRange(sheet.id, const GridRect(0, 0, 20, 5))],
          const {FormatAttr.bold: true},
        ),
      );
      await expectSameRecords();

      // Deleting rows tombstones them and their cells; undo revives both.
      final ids = [for (var r = 2; r < 12; r++) sheet.rows.idAt(r)];
      final delete = await apply(
        DeleteDimension(sheet.id, Dimension.rows, ids),
      );
      await expectSameRecords();
      await writeBoth(delete.inverse().changes);
      await expectSameRecords();

      // Cleared cells are tombstoned; writing them again revives them.
      final clear = await apply(
        ClearRanges([ResolvedRange(sheet.id, const GridRect(20, 0, 25, 5))]),
      );
      await writeBoth(clear.inverse().changes);
      await expectSameRecords();

      // A cell whose row is deleted cannot skip the projection: the
      // set-based write falls back to the planned insert.
      final rowId = sheet.rows.idAt(35);
      await apply(DeleteDimension(sheet.id, Dimension.rows, [rowId]));
      final colId = sheet.columns.idAt(0);
      await writeBoth([
        RowChange.insert(
          SheetsTables.cell,
          SheetsIds.cellId(sheet.id, rowId, colId),
          {
            Cols.sheetId: sheet.id,
            CellCols.rowId: rowId,
            CellCols.columnId: colId,
            CellCols.content: 's:orphan',
            Cols.createdAt: DateTime.utc(2026, 10, 1),
          },
        ),
      ]);
      await expectSameRecords();
    },
  );

  test('Given rows that are not visible, when updated set-based, then the '
      'updates are skipped and reported', () async {
    await apply(
      CreateSpreadsheet(
        spreadsheetId: space.uuid,
        title: 'Bulk',
        rows: 5,
        columns: 2,
      ),
    );
    final sheet = model.sheets.single;
    await apply(
      SetCellInputs(
        sheetId: sheet.id,
        row: 0,
        col: 0,
        inputs: const [
          [CellInput.user('a'), CellInput.user('b')],
        ],
      ),
    );
    final a = SheetsIds.cellId(
      sheet.id,
      sheet.rows.idAt(0),
      sheet.columns.idAt(0),
    );
    final b = SheetsIds.cellId(
      sheet.id,
      sheet.rows.idAt(0),
      sheet.columns.idAt(1),
    );
    final missing = SheetsIds.cellId(
      sheet.id,
      sheet.rows.idAt(3),
      sheet.columns.idAt(1),
    );
    await bulk.db.transactionForUser(
      bulk.userUuid,
      (tx) => SyncedTables.of(
        SheetsTables.cell,
      ).deleteByIds(bulk.session, [UuidValue.fromString(b)], transaction: tx),
      spaceId: space,
    );
    final result = await bulk.db.transactionForUser(
      bulk.userUuid,
      (tx) => SyncedTables.of(SheetsTables.cell).bulkWrite(bulk.session, [
        SyncedRowWrite.updateColumns(UuidValue.fromString(a), const {
          CellCols.content: 's:A',
        }),
        SyncedRowWrite.updateColumns(UuidValue.fromString(b), const {
          CellCols.content: 's:B',
        }),
        SyncedRowWrite.updateColumns(UuidValue.fromString(missing), const {
          CellCols.content: 's:C',
        }),
      ], transaction: tx),
      spaceId: space,
    );
    expect(result.updated, {UuidValue.fromString(a)});
    expect(result.skipped, {
      UuidValue.fromString(b),
      UuidValue.fromString(missing),
    });
    final reloaded = await reloadModel(bulk, space);
    expect(reloaded.cellAt(sheet.id, 0, 0)?.content, 's:A');
    expect(reloaded.cellAt(sheet.id, 0, 1), isNull);
  });
}
