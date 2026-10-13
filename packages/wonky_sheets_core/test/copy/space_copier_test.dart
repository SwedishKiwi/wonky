import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sync_models/ids.dart';

import '../support/planner_harness.dart';

void main() {
  group('Given a spreadsheet with formulas, rules and objects', () {
    late PlannerHarness h;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 5, cols: 3);
      b.values('A1', [
        [1],
        [2],
      ]);
      h = PlannerHarness(b);
      h.apply(
        SetCellInputs(
          sheetId: h.sheetId,
          row: 2,
          col: 0,
          inputs: [
            [const CellInput.user('=SUM(A1:A2)')],
          ],
        ),
      );
      h.apply(
        AddCfRule(
          h.sheetId,
          [h.range('A1:A3').rect],
          '{"v":1,"type":"boolean","condition":{"type":"customFormula","values":[{"v":"=⟦R:x⟧"}]}}',
        ),
      );
      h.apply(AddNamedRange('Nums', range: h.range('A1:A2')));
    });

    test(
      'when copying the space then every id is new and formulas point at the copy',
      () {
        const target = '11111111-1111-4111-8111-111111111111';
        final copy = SpaceCopier.copy(
          h.model.allRows(),
          sourceSpaceId: h.model.spreadsheetId,
          targetSpaceId: target,
          ids: SeededIdGenerator(9),
          userId: 'u',
          now: DateTime.utc(2026),
        );
        final m = WorkbookModel.fromRows(target, copy.rows);
        expect(m.spreadsheet.id, target);
        final s = m.sheets.single;
        expect(s.id, isNot(h.sheetId));
        final f = s.cellAt(2, 0)!.content!;
        final hooks = EngineFormulaHooks(m);
        expect(hooks.toA1(f, sheetId: s.id, row: 2, col: 0), '=SUM(A1:A2)');
        expect(s.cfRules.values.single.rangesJson, contains(s.id));
        expect(m.namedRange('Nums')!.rangeJson, contains(s.id));
        for (final (t, c) in copy.rows) {
          if (t == SheetsTables.cell) {
            expect(
              c[Cols.id],
              SheetsIds.cellId(
                c[Cols.sheetId]! as String,
                c[CellCols.rowId]! as String,
                c[CellCols.columnId]! as String,
              ),
            );
          }
        }
        final originalIds = {
          for (final (_, c) in h.model.allRows()) c[Cols.id],
        };
        expect(
          copy.rows.where((r) => originalIds.contains(r.$2[Cols.id])),
          isEmpty,
        );
      },
    );
  });
}
