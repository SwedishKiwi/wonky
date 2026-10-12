import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

import '../support/planner_harness.dart';

void main() {
  group('Given a model bound to the formula engine', () {
    late PlannerHarness h;
    late ModelEngineBinding binding;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 3);
      b.values('A1', [
        [1],
        [2],
        [3],
      ]);
      h = PlannerHarness(b);
      binding = ModelEngineBinding.create(h.model);
      h.apply(
        SetCellInputs(
          sheetId: h.sheetId,
          row: 4,
          col: 0,
          inputs: [
            [const CellInput.user('=SUM(A1:A3)')],
          ],
        ),
      );
    });
    tearDown(() => binding.dispose());

    test('when a precedent changes then the formula value updates', () {
      expect(binding.engine.valueAt(h.sheetId, 4, 0).toCellValue(), const NumberValue(6));
      h.apply(
        SetCellInputs(
          sheetId: h.sheetId,
          row: 0,
          col: 0,
          inputs: [
            [const CellInput.user('10')],
          ],
        ),
      );
      expect(binding.engine.valueAt(h.sheetId, 4, 0).toCellValue(), const NumberValue(15));
    });

    test('when a row inside the range is deleted then the sum shrinks', () {
      final s = h.model.sheets.first;
      h.apply(DeleteDimension(s.id, Dimension.rows, [s.rows.idAt(1)]));
      expect(binding.engine.valueAt(h.sheetId, 3, 0).toCellValue(), const NumberValue(4));
    });

    test('when a CF custom formula is evaluated relative to an anchor then offsets apply', () {
      final hooks = EngineFormulaHooks(h.model, engine: binding.engine);
      final stored = hooks.toStored('=A1>1', sheetId: h.sheetId, row: 0, col: 1);
      expect(
        hooks
            .evaluateRelative(
              stored,
              sheetId: h.sheetId,
              anchorRow: 0,
              anchorCol: 1,
              row: 0,
              col: 1,
            )
            .toCellValue(),
        const BoolValue(false),
      );
      expect(
        hooks
            .evaluateRelative(
              stored,
              sheetId: h.sheetId,
              anchorRow: 0,
              anchorCol: 1,
              row: 2,
              col: 1,
            )
            .toCellValue(),
        const BoolValue(true),
      );
    });

    test('when running maintenance on a consistent workbook then the plan is empty', () {
      expect(WorkbookMaintenance.plan(h.model, h.ctx).isEmpty, isTrue);
    });
  });
}
