import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/planner_harness.dart';

PlannerHarness _harness() {
  final b = WorkbookBuilder()..sheet('Sheet1', rows: 20, cols: 6);
  b
    ..value('A1', 1)
    ..value('A2', 2)
    ..value('A3', 3)
    ..value('B1', 'x');
  return PlannerHarness(b);
}

void main() {
  group('Given a sheet with values', () {
    late PlannerHarness h;
    setUp(() => h = _harness());

    test(
      'when typing inputs then contents are parsed and formulas stored by id',
      () {
        h.apply(
          SetCellInputs(
            sheetId: h.sheetId,
            row: 0,
            col: 2,
            inputs: [
              [
                const CellInput.user('42'),
                const CellInput.user('=A1*2'),
                const CellInput.user("'007"),
              ],
            ],
          ),
        );
        expect(h.content('C1'), 'n:42');
        expect(h.content('D1'), startsWith('='));
        expect(h.content('D1'), contains('⟦'));
        expect(h.formulaA1('D1'), '=A1*2');
        expect(h.content('E1'), 's:007');
      },
    );

    test('when undoing an edit then the state equals the original', () {
      final before = h.dump();
      h.apply(
        SetCellInputs(
          sheetId: h.sheetId,
          row: 0,
          col: 0,
          inputs: [
            [const CellInput.user('9'), const CellInput.raw(null)],
          ],
        ),
      );
      expect(h.content('A1'), 'n:9');
      expect(h.content('B1'), isNull);
      h.undo();
      expect(h.dump(), before);
    });

    test(
      'when the input extends beyond the grid without growGrid then it is refused',
      () {
        expect(
          () => h.plan(
            SetCellInputs(
              sheetId: h.sheetId,
              row: 19,
              col: 0,
              inputs: [
                [const CellInput.user('1')],
                [const CellInput.user('2')],
              ],
            ),
          ),
          throwsA(
            isA<PlanException>().having((e) => e.code, 'code', 'invalid_range'),
          ),
        );
      },
    );

    test('when growGrid is set then rows are appended', () {
      h.apply(
        SetCellInputs(
          sheetId: h.sheetId,
          row: 19,
          col: 0,
          growGrid: true,
          inputs: [
            [const CellInput.user('1')],
            [const CellInput.user('2')],
          ],
        ),
      );
      expect(h.model.sheets.first.rows.length, 21);
      expect(h.content('A21'), 'n:2');
    });

    test('when clearing contents then formats are kept', () {
      h.apply(SetFormat([h.range('A1')], {FormatAttr.bold: true}));
      h.apply(ClearRanges([h.range('A1:B1')]));
      expect(h.content('A1'), isNull);
      expect(h.cell('A1')!.format[FormatAttr.bold], true);
      expect(h.cell('B1'), isNull);
    });

    test('when a plan touches ≤ 200 cells then detail lists before/after', () {
      final p = h.apply(
        SetCellInputs(
          sheetId: h.sheetId,
          row: 0,
          col: 0,
          inputs: [
            [const CellInput.user('5')],
          ],
        ),
      );
      final cells = (p.detail!['cells']! as List).cast<Map<String, Object?>>();
      expect(cells.single['b'], 'n:1');
      expect(cells.single['a'], 'n:5');
      expect(p.summary.kinds, contains('values'));
    });

    test(
      'when setting a note and then removing it then the cell row disappears',
      () {
        h.apply(SetNote(h.sheetId, 5, 5, 'hello'));
        expect(h.cell('F6')!.note, 'hello');
        h.apply(SetNote(h.sheetId, 5, 5, null));
        expect(h.cell('F6'), isNull);
      },
    );
  });

  group('Given formatting operations', () {
    late PlannerHarness h;
    setUp(() => h = _harness());

    test(
      'when toggling bold on A1:A2 with A1 bold then both become bold, then both plain (AC-F1)',
      () {
        h.apply(SetFormat([h.range('A1')], {FormatAttr.bold: true}));
        h.apply(ToggleFormat([h.range('A1:A2')], FormatAttr.bold));
        expect(h.cell('A1')!.format[FormatAttr.bold], true);
        expect(h.cell('A2')!.format[FormatAttr.bold], true);
        h.apply(ToggleFormat([h.range('A1:A2')], FormatAttr.bold));
        expect(h.cell('A1')!.format[FormatAttr.bold], false);
        expect(h.cell('A2')!.format[FormatAttr.bold], false);
      },
    );

    test(
      'when bolding a whole column then one column default is written (AC-F2)',
      () {
        final s = h.model.sheets.first;
        final rowId = s.rows.idAt(4);
        h.apply(
          SetFormat(
            [ResolvedRange(s.id, GridRect(4, 0, 4, 5), wholeRows: true)],
            {FormatAttr.bold: false},
          ),
        );
        final p = h.apply(SetFormat([h.range('B:B')], {FormatAttr.bold: true}));
        final colChanges = p.changes
            .where((c) => c.table == SheetsTables.sheetColumn)
            .toList();
        expect(colChanges, hasLength(1));
        expect(
          CellFormat.fromJson(
            s.columnRecords[s.columns.idAt(1)]!.formatJson,
          )[FormatAttr.bold],
          true,
        );
        expect(
          h.model.cell(s.id, rowId, s.columns.idAt(1))!.format[FormatAttr.bold],
          true,
        );
        expect(
          p.changes.where((c) => c.table == SheetsTables.cell),
          hasLength(1),
        );
      },
    );

    test(
      'when applying outer thick red then inner thin then a framed grid results (AC-B1)',
      () {
        h.apply(
          SetBorders(
            [h.range('B2:D4')],
            BorderPreset.outer,
            style: BorderStyle.thick,
            color: '#FF0000',
          ),
        );
        h.apply(SetBorders([h.range('B2:D4')], BorderPreset.inner));
        expect(h.cell('B2')!.format[FormatAttr.borderTop], 'thick|#FF0000');
        expect(h.cell('B2')!.format[FormatAttr.borderBottom], 'thin|auto');
        expect(h.cell('C3')!.format[FormatAttr.borderRight], 'thin|auto');
        expect(h.cell('D4')!.format[FormatAttr.borderRight], 'thick|#FF0000');
        h.undo();
        expect(h.cell('B2')!.format[FormatAttr.borderBottom], isNull);
        expect(h.cell('C3'), isNull);
      },
    );

    test(
      'when merging cells with data then the warning is raised and force keeps the top-left (AC-F8)',
      () {
        h.apply(
          SetCellInputs(
            sheetId: h.sheetId,
            row: 1,
            col: 1,
            inputs: [
              [const CellInput.user('b2'), const CellInput.raw(null)],
              [const CellInput.raw(null), const CellInput.user('c3')],
            ],
          ),
        );
        final before = h.dump();
        expect(
          () => h.plan(MergeCells([h.range('B2:C3')])),
          throwsA(
            isA<PlanException>().having(
              (e) => e.code,
              'code',
              'merge_data_loss',
            ),
          ),
        );
        h.apply(MergeCells([h.range('B2:C3')], force: true));
        expect(h.content('B2'), 's:b2');
        expect(h.content('C3'), isNull);
        expect(h.model.sheets.first.merges, hasLength(1));
        h.undo();
        expect(h.dump(), before);
      },
    );

    test('when stepping font size then each cell moves to the next size', () {
      h.apply(SetFormat([h.range('A1')], {FormatAttr.fontSize: 12.0}));
      h.apply(StepFontSize([h.range('A1:A2')], increase: true));
      expect(h.cell('A1')!.format[FormatAttr.fontSize], 14.0);
      expect(h.cell('A2')!.format[FormatAttr.fontSize], 11.0);
    });
  });
}
