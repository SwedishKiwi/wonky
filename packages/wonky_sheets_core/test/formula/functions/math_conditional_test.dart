import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';

import 'function_vectors.dart';

void main() {
  final t = FormulaTestBench();
  t.setColumn('A1', [1, 2, 3, 4, 5]);
  t.setColumn('B1', ['x', 'y', 'x', 'z', 'w']);

  group('Given criteria functions over ranges', () {
    formulaVectors(t, const [
      ('=SUMIF(A1:A5, ">2")', 12),
      ('=SUMIF(B1:B5, "x", A1:A5)', 4),
      ('=COUNTIF(B1:B5, "x")', 2),
      ('=COUNTIFS(A1:A5, ">1", B1:B5, "x")', 1),
      ('=SUMIFS(A1:A5, B1:B5, "x")', 4),
      ('=AVERAGEIFS(A1:A5, B1:B5, "x")', 2),
      ('=MAXIFS(A1:A5, B1:B5, "x")', 3),
      ('=MINIFS(A1:A5, B1:B5, "x")', 1),
      ('=COUNTIF(1, 1)', '#VALUE!'),
    ]);
  });

  // Regression: arrays were rejected with "Argument must be a range." (Sheets accepts them).
  group('Given criteria functions over arrays', () {
    formulaVectors(t, const [
      ('=SUMIF({1, 2, 3, 4}, ">2")', 7),
      ('=COUNTIF({"a", "b", "a"}, "a")', 2),
      ('=COUNTIF({1, 2, 3}, "<>2")', 2),
      ('=AVERAGEIF({2, 4, 6}, ">=4")', 5),
      ('=SUMIF({"a", "b", "a"}, "a", {1, 2, 3})', 4),
      ('=COUNTIFS({1, 2, 3}, ">1", {"x", "y", "y"}, "y")', 2),
      ('=SUMIFS({1, 2, 3}, {"x", "y", "y"}, "y")', 5),
      ('=COUNTIFS({1, 2, 3}, ">1", {"x", "y"}, "y")', '#VALUE!'),
    ]);
  });

  // Regression: an array of criteria returned only the first result (no lifting).
  group('Given criteria functions with an array of criteria', () {
    formulaVectors(t, const [
      (
        '=COUNTIF(B1:B5, {"x", "y"})',
        [
          [2, 1],
        ],
      ),
      ('=SUM(COUNTIF(B1:B5, {"x", "y"}))', 3),
      (
        '=ARRAYFORMULA(COUNTIF(B1:B5, B1:B3))',
        [
          [2],
          [1],
          [2],
        ],
      ),
      (
        '=ARRAYFORMULA(SUMIF(B1:B5, B1:B2, A1:A5))',
        [
          [4],
          [2],
        ],
      ),
    ]);
  });
}
