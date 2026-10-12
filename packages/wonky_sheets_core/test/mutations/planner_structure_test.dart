import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/planner_harness.dart';

PlannerHarness _harness() {
  final b = WorkbookBuilder()..sheet('Sheet1', rows: 20, cols: 6);
  b.values('A1', [
    for (var i = 1; i <= 10; i++) [i],
  ]);
  return PlannerHarness(b);
}

void _formula(PlannerHarness h, String a1, String formula) {
  final r = h.range(a1);
  h.apply(
    SetCellInputs(
      sheetId: r.sheetId,
      row: r.rect.top,
      col: r.rect.left,
      inputs: [
        [CellInput.user(formula)],
      ],
    ),
  );
}

void main() {
  group('Given a column of numbers and a SUM formula', () {
    late PlannerHarness h;
    setUp(() {
      h = _harness();
      _formula(h, 'C1', '=SUM(A1:A10)');
      _formula(h, 'C2', '=A5');
    });

    test('when inserting rows above row 5 then formulas need no rewrite and follow their ids', () {
      final p = h.apply(InsertDimension(h.sheetId, Dimension.rows, 4, 3));
      expect(p.changes.where((c) => c.table == SheetsTables.cell && c.op == RowOp.update), isEmpty);
      expect(h.formulaA1('C1'), '=SUM(A1:A13)');
      expect(h.formulaA1('C2'), '=A8');
      expect(h.model.sheets.first.rows.length, 23);
    });

    test('when deleting rows 1–3 then the range shrinks and single refs survive (03 §13 AC)', () {
      final s = h.model.sheets.first;
      final before = h.dump();
      h.apply(
        DeleteDimension(s.id, Dimension.rows, [s.rows.idAt(0), s.rows.idAt(1), s.rows.idAt(2)]),
      );
      // C1 and C2 were in deleted rows; check the remaining formula on another cell.
      expect(h.model.sheets.first.rows.length, 17);
      h.undo();
      expect(h.dump(), before);
      expect(h.formulaA1('C1'), '=SUM(A1:A10)');
    });

    test('when deleting the range end rows then the formula elsewhere shrinks', () {
      _formula(h, 'D15', '=SUM(A1:A10)');
      _formula(h, 'D16', '=A10');
      final s = h.model.sheets.first;
      h.apply(DeleteDimension(s.id, Dimension.rows, [s.rows.idAt(8), s.rows.idAt(9)]));
      expect(h.formulaA1('D13'), '=SUM(A1:A8)');
      expect(h.formulaA1('D14'), '=#REF!');
    });

    test('when deleting every row then it is refused', () {
      final s = h.model.sheets.first;
      expect(
        () => h.plan(DeleteDimension(s.id, Dimension.rows, s.rows.ids.toList())),
        throwsA(isA<PlanException>()),
      );
    });

    test('when moving rows then only sort keys change', () {
      final s = h.model.sheets.first;
      final id = s.rows.idAt(0);
      final p = h.apply(MoveDimension(s.id, Dimension.rows, [id], s.rows.idAt(5)));
      expect(p.changes.every((c) => c.table == SheetsTables.sheetRow), isTrue);
      expect(s.rows.indexOf(id), 4);
      expect(h.content('A5'), 'n:1');
    });

    test('when hiding and resizing columns then the axis reflects it', () {
      final s = h.model.sheets.first;
      h.apply(SetDimensionHidden(s.id, Dimension.columns, [s.columns.idAt(1)], hidden: true));
      h.apply(ResizeDimension(s.id, Dimension.columns, [s.columns.idAt(0)], 50));
      expect(s.columns.sizeAt(1), 0);
      expect(s.columns.sizeAt(0), 50);
    });

    test('when inserting rows below a formatted row then the new rows copy its formats', () {
      h.apply(SetFormat([h.range('A2')], {FormatAttr.fillColor: '#FFFF00'}));
      h.apply(InsertDimension(h.sheetId, Dimension.rows, 2, 2));
      expect(h.cell('A3')!.format[FormatAttr.fillColor], '#FFFF00');
      expect(h.cell('A3')!.content, isNull);
      expect(h.cell('A4')!.format[FormatAttr.fillColor], '#FFFF00');
    });

    test(
      'when a CF rule range loses its last rows then it shrinks; all deleted → rule deleted',
      () {
        final s = h.model.sheets.first;
        h.apply(AddCfRule(s.id, [const GridRect(0, 0, 4, 0)], '{"v":1,"type":"boolean"}'));
        final ruleId = s.cfRules.keys.single;
        h.apply(DeleteDimension(s.id, Dimension.rows, [s.rows.idAt(3), s.rows.idAt(4)]));
        expect(s.ruleRects(RuleKind.conditionalFormat, ruleId), [const GridRect(0, 0, 2, 0)]);
        h.apply(
          DeleteDimension(s.id, Dimension.rows, [s.rows.idAt(0), s.rows.idAt(1), s.rows.idAt(2)]),
        );
        expect(s.cfRules, isEmpty);
      },
    );
  });

  group('Given sheet operations', () {
    late PlannerHarness h;
    setUp(() => h = _harness());

    test('when adding a sheet with a taken name then duplicate_name is raised', () {
      expect(
        () => h.plan(const AddSheet(name: 'sheet1')),
        throwsA(isA<PlanException>().having((e) => e.code, 'code', 'duplicate_name')),
      );
      final p = h.apply(const AddSheet(rows: 5, columns: 3));
      final s = h.model.sheet(p.result['sheetId']! as String)!;
      expect(s.name, 'Sheet2');
      expect(s.rows.length, 5);
    });

    test('when deleting a sheet and undoing then cells are revived', () {
      h.apply(const AddSheet(name: 'Other', rows: 3, columns: 3));
      final before = h.dump();
      h.apply(DeleteSheet(h.sheetId));
      expect(h.model.sheets.map((s) => s.name), ['Other']);
      h.undo();
      expect(h.dump(), before);
    });

    test('when deleting the last visible sheet then it is refused', () {
      expect(() => h.plan(DeleteSheet(h.sheetId)), throwsA(isA<PlanException>()));
    });

    test('when duplicating a sheet then same-sheet formulas point at the copy', () {
      _formula(h, 'B1', '=A1+A2');
      final p = h.apply(DuplicateSheet(h.sheetId));
      final copy = h.model.sheet(p.result['sheetId']! as String)!;
      expect(copy.name, 'Copy of Sheet1');
      expect(h.model.sheets[1].id, copy.id);
      final c = copy.cellAt(0, 1)!;
      final a1 = h.hooks.toA1(c.content!, sheetId: copy.id, row: 0, col: 1);
      expect(a1, '=A1+A2');
      expect(c.content, isNot(h.content('B1')));
    });

    test('when renaming and moving sheets then names and order update', () {
      h.apply(const AddSheet(name: 'B'));
      h.apply(RenameSheet(h.sheetId, 'A'));
      h.apply(MoveSheet(h.sheetId, 1));
      expect(h.model.sheets.map((s) => s.name), ['B', 'A']);
    });
  });
}
