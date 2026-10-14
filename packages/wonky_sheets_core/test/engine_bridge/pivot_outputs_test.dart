import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

import '../support/planner_harness.dart';

void main() {
  group('Given a sales table with a pivot table at E1', () {
    late PlannerHarness h;
    late String pivotId;

    void type(String a1, List<List<String>> rows) {
      final r = h.range(a1);
      h.apply(
        SetCellInputs(
          sheetId: h.sheetId,
          row: r.rect.top,
          col: r.rect.left,
          inputs: [
            for (final row in rows) [for (final v in row) CellInput.user(v)],
          ],
        ),
      );
    }

    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 30, cols: 10);
      h = PlannerHarness(b);
      type('A1', [
        ['Region', 'Revenue'],
        ['East', '100'],
        ['West', '50'],
        ['East', '25'],
      ]);
      final s = h.model.sheets.first;
      final spec = PivotSpec(
        rows: [PivotGroupSpec(s.columns.idAt(0))],
        values: [PivotValueSpec(source: s.columns.idAt(1))],
      );
      final p = h.apply(
        AddPivotTable(h.sheetId, 0, 4, h.range('A1:B4'), spec.encode()),
      );
      pivotId = p.result['pivotId']! as String;
    });

    test('when computing the outputs headlessly then the pivot is placed '
        'at its anchor', () {
      final binding = ModelEngineBinding.create(h.model);
      addTearDown(binding.dispose);
      final out = PivotOutputs.compute(h.model, binding.engine);
      expect(out, hasLength(1));
      expect(out.single.pivotId, pivotId);
      expect(out.single.rect, const GridRect(0, 4, 3, 5));
      expect(out.single.cellAt(1, 4)?.value, const TextValue('East'));
      expect(out.single.cellAt(1, 5)?.value, const NumberValue(125));
    });

    test('when exporting to the IR then the pivot output is written as '
        'cells with bold headers', () {
      final binding = ModelEngineBinding.create(h.model);
      addTearDown(binding.dispose);
      final source = EngineIrValueSource(binding.engine);
      final doc = ModelToIr.convert(
        h.model,
        values: source,
        formatHints: false,
      );
      final cells = doc.sheets.single.cells;
      expect(cells.get(1, 4)?.value?.toCellValue(), const TextValue('East'));
      expect(cells.get(1, 5)?.value?.toCellValue(), const NumberValue(125));
      expect(
        cells.get(3, 5)?.value?.toCellValue(),
        const NumberValue(175),
        reason: 'grand total',
      );
      expect(source.overlayFormat(h.sheetId, 0, 4)?[FormatAttr.bold], isTrue);
      expect(source.overlayFormat(h.sheetId, 1, 5)?[FormatAttr.bold], isNull);
    });

    test('when content is typed into the output area then the pivot is not '
        'exported', () {
      type('F3', [
        ['x'],
      ]);
      final binding = ModelEngineBinding.create(h.model);
      addTearDown(binding.dispose);
      expect(PivotOutputs.compute(h.model, binding.engine), isEmpty);
    });

    test('when an earlier dynamic array covers the output then the array '
        'wins and the pivot is left out', () {
      type('D1', [
        ['=SEQUENCE(1,3)'],
      ]);
      final binding = ModelEngineBinding.create(h.model);
      addTearDown(binding.dispose);
      binding.engine.computedAt(h.sheetId, 0, 3);
      expect(binding.engine.spillAreas(h.sheetId), [
        const SpillArea(0, 3, GridRect(0, 3, 0, 5)),
      ]);
      expect(PivotOutputs.compute(h.model, binding.engine), isEmpty);
    });
  });
}
