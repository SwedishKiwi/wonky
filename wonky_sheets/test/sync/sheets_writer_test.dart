import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show Cell, ChangeLog, SheetRow, UuidValue;
import 'package:wonky_sheets/features/sync/sheets_replica.dart';
import 'package:wonky_sheets/features/sync/sheets_writer.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/ids.dart';

import 'support/sync_harness.dart';

/// Names of the columns the engine recorded as written for [rowId]
/// (`crdt_data_fields`; an insert records the row only).
Future<Set<String>> touchedFields(SheetsReplica replica, String rowId) async {
  final hex = rowId.replaceAll('-', '');
  final r = await replica.db.unsafeQuery(
    'SELECT c."name" FROM "crdt_data_fields" f '
    'JOIN "crdt_schema_columns" c ON c."id" = f."columnId" '
    'JOIN "crdt_data_rows" r ON r."id" = f."rowId" '
    "WHERE r.\"uuidRowId\" = x'$hex'",
  );
  return {for (final row in r) row[0]! as String};
}

void main() {
  group('Given a spreadsheet in the local replica', () {
    late SheetsReplica replica;
    late SheetsWriter writer;
    late UuidValue space;
    late WorkbookModel model;

    setUp(() async {
      replica = await openTestReplica();
      writer = SheetsWriter(replica);
      space = UuidValue.fromString('0190a000-0000-7000-8000-0000000000b1');
      await createSpreadsheet(replica, space, title: 'Budget');
      model = await reloadModel(replica, space);
    });

    Future<void> write(List<RowChange> changes, {MutationPlan? plan}) =>
        writer.write(
          spaceId: space,
          changes: changes,
          plan: plan,
          label: plan?.label ?? 'Test',
          actorKind: 'user',
          sessionId: 'writer-test',
        );

    MutationPlan plan(SheetsOperation op) => const SheetsMutationPlanner().plan(
      op,
      model,
      PlanContext(userId: testUser.uuid, now: DateTime.utc(2026)),
    );

    test('when created then the spreadsheet, its sheet and grid are stored '
        'with one change log row', () async {
      expect(model.spreadsheet.title, 'Budget');
      expect(model.sheets.single.rows.length, 50);
      expect(model.sheets.single.columns.length, 10);
      final logs = await ChangeLog.db.find(replica.session);
      expect(logs.single.spreadsheetId, space);
      expect(logs.single.sessionId, 'test');
    });

    test('when a cell is formatted bold then the update names only the bold '
        'column', () async {
      final sheet = model.sheets.single;
      final set = plan(
        SetCellInputs(
          sheetId: sheet.id,
          row: 0,
          col: 0,
          inputs: const [
            [CellInput.user('42')],
          ],
        ),
      );
      await write(set.changes, plan: set);
      model.applyPlan(set);
      final cellId = SheetsIds.cellId(
        sheet.id,
        sheet.rows.idAt(0),
        sheet.columns.idAt(0),
      );
      // Inserts record the row (and the engine's foreign-key fields) only.
      final afterInsert = await touchedFields(replica, cellId);
      expect(afterInsert, isNot(contains('content')));

      final bold = plan(
        SetFormat(
          [ResolvedRange(sheet.id, const GridRect(0, 0, 0, 0))],
          const {FormatAttr.bold: true},
        ),
      );
      expect(bold.changes.single.op, RowOp.update);
      await write(bold.changes, plan: bold);

      expect(await touchedFields(replica, cellId), {...afterInsert, 'bold'});
      final stored = await Cell.db.findById(
        replica.session,
        UuidValue.fromString(cellId),
      );
      expect(stored?.bold, isTrue);
      expect(stored?.content, 'n:42');
    });

    test('when a plan is written then the change log row carries its label, '
        'actor kind and summary', () async {
      final sheet = model.sheets.single;
      final set = plan(
        SetCellInputs(
          sheetId: sheet.id,
          row: 1,
          col: 1,
          inputs: const [
            [CellInput.user('x')],
          ],
        ),
      );
      await writer.write(
        spaceId: space,
        changes: set.changes,
        plan: set,
        label: set.label,
        actorKind: 'mcp',
        sessionId: 's1',
      );

      final log = (await ChangeLog.db.find(
        replica.session,
        orderBy: (t) => t.createdAt,
      )).last;
      expect(log.label, set.label);
      expect(log.actorKind.name, 'mcp');
      expect(log.sessionId, 's1');
      expect(ChangeSummary.parse(log.summaryJson).sheets, {sheet.id});
      expect(log.detailJson, set.detailJson);
    });

    test('when more than 5,000 changes are written then they are chunked and '
        'one change log row is written', () async {
      final sheet = model.sheets.single;
      final grow = plan(InsertDimension(sheet.id, Dimension.rows, 50, 12000));
      expect(grow.changes.length, greaterThan(SheetsWriter.chunkSize * 2));

      await write(grow.changes, plan: grow);

      expect(
        await SheetRow.db.count(
          replica.session,
          where: (t) => t.sheetId.equals(UuidValue.fromString(sheet.id)),
        ),
        12050,
      );
      expect(await ChangeLog.db.count(replica.session), 2);
    });

    test('when a deleted row is inserted again then it is revived with the '
        'same id', () async {
      final sheet = model.sheets.single;
      final rowId = sheet.rows.idAt(3);
      final row = model.currentColumns(SheetsTables.sheetRow, rowId)!;

      await write([RowChange.delete(SheetsTables.sheetRow, rowId, row)]);
      expect(
        await SheetRow.db.findById(
          replica.session,
          UuidValue.fromString(rowId),
        ),
        isNull,
      );
      await write([RowChange.insert(SheetsTables.sheetRow, rowId, row)]);

      expect(
        (await SheetRow.db.findById(
          replica.session,
          UuidValue.fromString(rowId),
        ))?.sortKey,
        row[Cols.sortKey],
      );
    });

    test('when an insert hits a visible row then it updates the given '
        'columns', () async {
      final sheet = model.sheets.single;
      final id = SheetsIds.cellId(
        sheet.id,
        sheet.rows.idAt(0),
        sheet.columns.idAt(0),
      );
      final columns = {
        Cols.sheetId: sheet.id,
        CellCols.rowId: sheet.rows.idAt(0),
        CellCols.columnId: sheet.columns.idAt(0),
        Cols.createdAt: DateTime.utc(2026),
      };
      await write([
        RowChange.insert(SheetsTables.cell, id, {
          ...columns,
          CellCols.content: 's:one',
        }),
      ]);

      await write([
        RowChange.insert(SheetsTables.cell, id, {
          ...columns,
          CellCols.content: 's:two',
        }),
      ]);

      expect(
        (await Cell.db.findById(
          replica.session,
          UuidValue.fromString(id),
        ))?.content,
        's:two',
      );
    });

    test('when written then the space is marked dirty for the pending-change '
        'guard', () async {
      expect(await replica.dirtySpaces(), [space]);

      await replica.clearDirty([
        space,
      ], DateTime.now().add(const Duration(seconds: 1)));

      expect(await replica.dirtySpaces(), isEmpty);
    });
  });
}
