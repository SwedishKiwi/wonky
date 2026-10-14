import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/pivot/pivot.dart';

CellValue aggregate(PivotSummarize by, List<Object?> values) {
  final a = Aggregator.create(by);
  for (final v in values) {
    a.add(CellValue.from(v));
  }
  return a.result;
}

void main() {
  group('Given the values 2, 4, 4, "x", TRUE, blank, 4, 5, 7, 9', () {
    final values = <Object?>[2, 4, 4, 'x', true, null, 4, 5, 7, 9];
    final cases = <(PivotSummarize, CellValue)>[
      (PivotSummarize.sum, const NumberValue(35)),
      (PivotSummarize.counta, const NumberValue(9)),
      (PivotSummarize.count, const NumberValue(7)),
      (PivotSummarize.countunique, const NumberValue(7)),
      (PivotSummarize.average, const NumberValue(5)),
      (PivotSummarize.max, const NumberValue(9)),
      (PivotSummarize.min, const NumberValue(2)),
      (PivotSummarize.median, const NumberValue(4)),
      (PivotSummarize.product, const NumberValue(40320)),
      (PivotSummarize.variancep, NumberValue(32 / 7)),
      (PivotSummarize.stdevp, NumberValue(math.sqrt(32 / 7))),
    ];
    for (final (by, expected) in cases) {
      test('when summarizing by ${by.label} then the result is $expected', () {
        expect(aggregate(by, values), expected);
      });
    }

    test('when computing the sample variance then it uses n − 1', () {
      final v = aggregate(PivotSummarize.variance, values) as NumberValue;
      final s = aggregate(PivotSummarize.stdev, values) as NumberValue;

      expect(v.number, closeTo(32 / 6, 1e-12));
      expect(s.number, closeTo(math.sqrt(32 / 6), 1e-12));
    });
  });

  group('Given degenerate inputs', () {
    final cases = <(String, PivotSummarize, List<Object?>, CellValue)>[
      ('no numbers', PivotSummarize.sum, ['a'], const NumberValue(0)),
      (
        'no numbers',
        PivotSummarize.average,
        ['a'],
        const ErrorValue(CellErrorKind.div0),
      ),
      ('no numbers', PivotSummarize.max, [], const NumberValue(0)),
      ('no numbers', PivotSummarize.product, [], const NumberValue(0)),
      (
        'no numbers',
        PivotSummarize.median,
        [],
        const ErrorValue(CellErrorKind.num),
      ),
      (
        'one number',
        PivotSummarize.stdev,
        [3],
        const ErrorValue(CellErrorKind.div0),
      ),
      (
        'an error',
        PivotSummarize.sum,
        [1, CellErrorKind.na, 2],
        const ErrorValue(CellErrorKind.na),
      ),
      (
        'an error',
        PivotSummarize.counta,
        [1, CellErrorKind.na],
        const NumberValue(2),
      ),
      (
        'case variants',
        PivotSummarize.countunique,
        ['a', 'A', 'a', 0, -0.0],
        const NumberValue(3),
      ),
    ];
    for (final (what, by, values, expected) in cases) {
      test('when ${by.label} gets $what then it is $expected', () {
        expect(aggregate(by, values), expected);
      });
    }
  });

  group('Given the summarize ids', () {
    test('when parsing ids then var/varp map to the variance pair and '
        'unknown ids to SUM', () {
      expect(PivotSummarize.byId('var'), PivotSummarize.variance);
      expect(PivotSummarize.byId('varp'), PivotSummarize.variancep);
      expect(PivotSummarize.byId('nope'), PivotSummarize.sum);
      expect(PivotSummarize.variance.id, 'var');
    });
  });
}
