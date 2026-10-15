// Offline collaboration scenarios of Sheets 10 §10 with two users, each on
// their own device (replica + sync controller) against an in-process sync
// server. Both edit "offline" (no sync), then both reconnect.
//
// Each scenario syncs a 1,000 × 26 spreadsheet several times (15–25 s on an
// idle machine), so the default 30 s test timeout is too tight under load.
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets/features/sync/sheets_sync_controller.dart';
import 'package:wonky_sheets/features/sync/synced_workbook_session.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../../sync/support/sync_harness.dart';

final anna = UuidValue.fromString('0190a000-0000-7000-8000-0000000000a1');
final bo = UuidValue.fromString('0190a000-0000-7000-8000-0000000000b2');

void main() {
  group('Given Anna and Bo with the same spreadsheet on their devices', () {
    late SheetsSyncController a;
    late SheetsSyncController b;
    late SyncedWorkbookSession sa;
    late SyncedWorkbookSession sb;
    late String sheet;

    setUp(() async {
      final server = await FakeSheetsServer.open();
      a = SheetsSyncController(
        replica: await openTestReplica(user: anna),
        remote: FakeRemote(server, anna),
        connectivity: FakeConnectivity(),
      );
      b = SheetsSyncController(
        replica: await openTestReplica(user: bo),
        remote: FakeRemote(server, bo),
        connectivity: FakeConnectivity(),
      );
      addTearDown(a.stop);
      addTearDown(b.stop);
      await a.syncNow();
      await a.refillReservations();
      await a.syncNow();
      final space = await a.createLocalSpreadsheet(title: 'Shared');
      await a.syncNow();
      await server.grant(bo, space);
      await b.syncNow();
      sa = a.openSession(itemUuid: space, spaceUuid: space, role: Role.owner);
      sb = b.openSession(itemUuid: space, spaceUuid: space, role: Role.editor);
      addTearDown(sa.dispose);
      addTearDown(sb.dispose);
      await sa.opened;
      await sb.opened;
      sheet = sa.model.sheets.first.id;
      expect(sb.model.sheets.first.id, sheet);
    });

    /// Both reconnect: sync both ways until both models are identical.
    Future<void> reconnect() async {
      await sa.flush();
      await sb.flush();
      for (var i = 0; i < 2; i++) {
        await a.syncNow();
        await b.syncNow();
      }
      await eventually(
        () => _same(canonical(sa.model), canonical(sb.model)),
        timeout: const Duration(seconds: 45),
      );
    }

    /// A later write (HLC order follows the wall clock).
    Future<void> later() =>
        Future<void>.delayed(const Duration(milliseconds: 5));

    MutationPlan type(SyncedWorkbookSession s, int row, int col, String v) =>
        s.execute(
          SetCellInputs(
            sheetId: sheet,
            row: row,
            col: col,
            inputs: [
              [CellInput.user(v)],
            ],
          ),
        );

    String? content(SyncedWorkbookSession s, int row, int col) =>
        s.model.cellAt(sheet, row, col)?.content;

    test('#1 when both type into the same cell then the later value wins '
        'everywhere', () async {
      type(sa, 4, 2, 'Anna');
      await later();
      type(sb, 4, 2, 'Bo');
      await reconnect();
      expect(content(sa, 4, 2), 's:Bo');
      expect(content(sb, 4, 2), 's:Bo');
    });

    test('#2 when both edit different cells of the same row then both '
        'survive', () async {
      type(sa, 4, 2, 'C5');
      type(sb, 4, 3, 'D5');
      await reconnect();
      expect((content(sa, 4, 2), content(sa, 4, 3)), ('s:C5', 's:D5'));
    });

    test('#3 when Anna sets a value and Bo makes the cell bold then both '
        'survive', () async {
      type(sa, 4, 2, '10');
      await later();
      sb.execute(
        SetFormat(
          [ResolvedRange(sheet, GridRect.cell(4, 2))],
          {FormatAttr.bold: true},
        ),
      );
      await reconnect();
      expect(content(sa, 4, 2), 'n:10');
      expect(
        sa.model.explicitFormatChain(sheet, 4, 2).has(FormatAttr.bold),
        isTrue,
      );
    });

    test('#4 when both insert a row below row 4 and type into it then both '
        'rows are kept in the same order everywhere', () async {
      final rows = sa.model.sheet(sheet)!.rows.length;
      sa.execute(InsertDimension(sheet, Dimension.rows, 4, 1));
      type(sa, 4, 0, 'Anna row');
      sb.execute(InsertDimension(sheet, Dimension.rows, 4, 1));
      type(sb, 4, 0, 'Bo row');
      await reconnect();
      expect(sa.model.sheet(sheet)!.rows.length, rows + 2);
      final values = {content(sa, 4, 0), content(sa, 5, 0)};
      expect(values, {'s:Anna row', 's:Bo row'});
      expect(sa.model.sheet(sheet)!.rows.ids, sb.model.sheet(sheet)!.rows.ids);
    });

    test('#5 when Anna deletes row 7 while Bo edits it then the row is gone '
        'and Bo\'s edit is not visible', () async {
      final rowId = sa.model.sheet(sheet)!.rows.idAt(6);
      sa.execute(DeleteDimension(sheet, Dimension.rows, [rowId]));
      await later();
      type(sb, 6, 2, 'Bo edit');
      await reconnect();
      expect(sa.model.sheet(sheet)!.rows.contains(rowId), isFalse);
      bool visible(SyncedWorkbookSession s) =>
          s.model.sheet(sheet)!.cells.all.any((c) => c.content == 's:Bo edit');
      expect(visible(sa), isFalse);
      expect(visible(sb), isFalse);
    });

    test('#6 when Bo deletes column C while Anna edits C5 then the column is '
        'gone', () async {
      final colId = sa.model.sheet(sheet)!.columns.idAt(2);
      type(sa, 4, 2, 'Anna');
      await later();
      sb.execute(DeleteDimension(sheet, Dimension.columns, [colId]));
      await reconnect();
      expect(sa.model.sheet(sheet)!.columns.contains(colId), isFalse);
      expect(
        sa.model.sheet(sheet)!.cells.all.any((c) => c.content == 's:Anna'),
        isFalse,
      );
    });

    test(
      '#7 when Anna deletes a sheet that Bo edits then the sheet is gone',
      () async {
        final plan = sa.execute(const AddSheet(name: 'Q3'));
        await reconnect();
        final q3 =
            plan.result['sheetId'] as String? ??
            sa.model.sheets.firstWhere((s) => s.name == 'Q3').id;
        sa.execute(DeleteSheet(q3));
        await later();
        sb.execute(
          SetCellInputs(
            sheetId: q3,
            row: 0,
            col: 0,
            inputs: const [
              [CellInput.user('lost')],
            ],
          ),
        );
        await reconnect();
        expect(sa.model.sheet(q3), isNull);
        expect(sb.model.sheet(q3), isNull);
      },
    );

    test(
      '#11 when both rename the same sheet then the later name wins',
      () async {
        sa.execute(RenameSheet(sheet, 'Anna'));
        await later();
        sb.execute(RenameSheet(sheet, 'Bo'));
        await reconnect();
        expect(sa.model.sheet(sheet)!.name, 'Bo');
      },
    );

    test('#15 when Anna sums B2:B9 and Bo deletes row 9 then the range '
        'shrinks to B2:B8', () async {
      type(sa, 0, 3, '=SUM(B2:B9)');
      final row9 = sb.model.sheet(sheet)!.rows.idAt(8);
      sb.execute(DeleteDimension(sheet, Dimension.rows, [row9]));
      await reconnect();
      final stored = content(sa, 0, 3)!;
      final a1 = EngineFormulaHooks(
        sa.model,
        engine: sa.engine.engine,
        view: sa.engine.view,
      ).toA1(stored, sheetId: sheet, row: 0, col: 3);
      expect(a1, '=SUM(B2:B8)');
    });

    test('#16 when Anna undoes an edit after Bo changed the same cell then '
        'the undo skips the cell', () async {
      final plan = type(sa, 4, 2, 'Anna');
      await reconnect();
      await later();
      type(sb, 4, 2, 'Bo');
      await reconnect();
      var skipped = 0;
      final inverse = SheetsUndo.invertChanges(
        plan.changes,
        sa.model,
        skipped: (_, _, _) => skipped++,
      );
      expect(skipped, greaterThan(0));
      expect(
        inverse.where(
          (c) =>
              c.table == SheetsTables.cell &&
              c.columnsAfter.containsKey(CellCols.content),
        ),
        isEmpty,
      );
    });
  });
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
