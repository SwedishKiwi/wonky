import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

import '../support/planner_harness.dart';

/// Overlay values at fixed positions of one sheet.
final class _Overlays implements ComputedOverlaySource {
  _Overlays(this.sheetId);

  final String sheetId;
  final Map<(int, int), EngineCellInput> cells = {};
  GridRect? rect;

  void set(GridRect r, num Function(int row, int col) value) {
    cells.clear();
    rect = r;
    for (var row = r.top; row <= r.bottom; row++) {
      for (var col = r.left; col <= r.right; col++) {
        cells[(row, col)] = EngineCellInput.value(
          FNumber(value(row, col).toDouble()),
        );
      }
    }
  }

  @override
  EngineCellInput? inputAt(String sheetId, int row, int col) =>
      sheetId == this.sheetId ? cells[(row, col)] : null;

  @override
  String? numberFormatAt(String sheetId, int row, int col) =>
      inputAt(sheetId, row, col) == null ? null : '0.00%';

  @override
  Iterable<GridRect> rectsOf(String sheetId) =>
      sheetId == this.sheetId && rect != null ? [rect!] : const [];
}

void main() {
  group('Given computed overlay values in B2:C3 of an engine-bound model', () {
    late PlannerHarness h;
    late ModelEngineBinding binding;
    late _Overlays overlays;

    void type(int row, int col, String input) => h.apply(
      SetCellInputs(
        sheetId: h.sheetId,
        row: row,
        col: col,
        inputs: [
          [CellInput.user(input)],
        ],
      ),
    );

    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 20, cols: 6);
      h = PlannerHarness(b);
      binding = ModelEngineBinding.create(h.model);
      overlays = _Overlays(h.sheetId)
        ..set(const GridRect(1, 1, 2, 2), (r, c) => r * 10 + c);
      binding.view.overlays = overlays;
    });
    tearDown(() => binding.dispose());

    test('when a formula sums the overlay range then it reads the overlay '
        'values', () {
      type(0, 0, '=SUM(B2:C3)');
      expect(
        binding.engine.valueAt(h.sheetId, 0, 0).toCellValue(),
        const NumberValue(11 + 12 + 21 + 22),
      );
    });

    test('when the overlay changes and the owner reports the rect then the '
        'formula recalculates', () {
      type(0, 0, '=B2*2');
      expect(
        binding.engine.valueAt(h.sheetId, 0, 0).toCellValue(),
        const NumberValue(22),
      );

      overlays.set(const GridRect(1, 1, 2, 2), (r, c) => 100);
      binding.engine.rectChanged(h.sheetId, const GridRect(1, 1, 2, 2));

      expect(
        binding.engine.valueAt(h.sheetId, 0, 0).toCellValue(),
        const NumberValue(200),
      );
    });

    test('when a cell has content then its content wins over the overlay', () {
      type(1, 1, '7');
      expect(
        binding.engine.valueAt(h.sheetId, 1, 1).toCellValue(),
        const NumberValue(7),
      );
    });

    test('when reading the number format then the overlay format applies to '
        'empty cells only', () {
      expect(binding.engine.numberFormatAt(h.sheetId, 1, 1), '0.00%');
      expect(binding.engine.numberFormatAt(h.sheetId, 0, 0), isNull);
    });

    test('when an overlay appears over a spilled array and the owner reports '
        'it then the array is blocked, and spills again when it goes away', () {
      type(4, 1, '=SEQUENCE(3)');
      binding.engine.valueAt(h.sheetId, 4, 1);
      expect(binding.engine.spillAreas(h.sheetId), [
        const SpillArea(4, 1, GridRect(4, 1, 6, 1)),
      ]);

      overlays.set(const GridRect(5, 1, 5, 1), (r, c) => 1);
      binding.engine.rectChanged(h.sheetId, const GridRect(5, 1, 5, 1));
      expect(
        binding.engine.valueAt(h.sheetId, 4, 1).toCellValue(),
        isA<ErrorValue>().having((e) => e.kind, 'kind', CellErrorKind.spill),
      );
      expect(binding.engine.spillAreas(h.sheetId), [
        const SpillArea(4, 1, GridRect(4, 1, 6, 1), blocked: true),
      ]);

      overlays
        ..cells.clear()
        ..rect = null;
      binding.engine.rectChanged(h.sheetId, const GridRect(5, 1, 5, 1));
      expect(
        binding.engine.valueAt(h.sheetId, 4, 1).toCellValue(),
        const NumberValue(1),
      );
      expect(
        binding.engine.valueAt(h.sheetId, 6, 1).toCellValue(),
        const NumberValue(3),
      );
    });

    test('when a whole-column formula reads the overlay then the used extent '
        'includes it', () {
      type(0, 4, '=COUNT(C:C)');
      expect(
        binding.engine.valueAt(h.sheetId, 0, 4).toCellValue(),
        const NumberValue(2),
      );
    });
  });
}
