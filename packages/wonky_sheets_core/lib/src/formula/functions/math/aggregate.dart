import '../../values/format_hint.dart';
import '../../values/fvalue.dart';
import '../helpers.dart';
import '../registry.dart';

/// SUM, PRODUCT, SUMSQ (05 §15.1).
void registerMathAggregate(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.math;
  b.fn(
    'SUM',
    'Returns the sum of a series of numbers and/or cells.',
    [
      P.range('value1', 'The first number or range to add together.'),
      P.rep('value2', ArgKind.range, 'Additional numbers or ranges to add to value1.'),
    ],
    (a) {
      final xs = <double>[];
      final hint = a.collectNumbers(xs);
      return numResult(sumOf(xs), _aggHint(hint));
    },
    priority: Priority.p0,
    examples: ['SUM(A2:A100)', 'SUM(1, 2, 3)'],
    seeAlso: ['SUMIF', 'SUMIFS', 'SUMPRODUCT'],
  );
  b.fn(
    'PRODUCT',
    'Returns the result of multiplying a series of numbers together.',
    [
      P.range('factor1', 'The first number or range to calculate for the product.'),
      P.rep('factor2', ArgKind.range, 'More numbers or ranges to multiply.'),
    ],
    (a) {
      final xs = a.numbers();
      if (xs.isEmpty) return FNumber.zero;
      var p = 1.0;
      for (final x in xs) {
        p *= x;
      }
      return numResult(p);
    },
    priority: Priority.p0,
    examples: ['PRODUCT(A2:A10)', 'PRODUCT(2, 3, 4)'],
  );
  b.fn(
    'SUMSQ',
    'Returns the sum of the squares of a series of numbers and/or cells.',
    [
      P.range('value1', 'The first number or range whose squares to add together.'),
      P.rep('value2', ArgKind.range, 'More numbers or ranges.'),
    ],
    (a) => numResult(sumOf(a.numbers().map((x) => x * x))),
    examples: ['SUMSQ(1, 2, 3)'],
  );
}

/// Aggregate results keep date/currency/percent formats of the first number (05 §6.2).
FormatHint _aggHint(FormatHint h) => switch (h.kind) {
  FormatHintKind.fromCell ||
  FormatHintKind.currency ||
  FormatHintKind.percent ||
  FormatHintKind.date ||
  FormatHintKind.dateTime ||
  FormatHintKind.time ||
  FormatHintKind.duration => h,
  _ => FormatHint.none,
};

/// Exposed for statistical aggregates.
FormatHint aggregateHint(FormatHint h) => _aggHint(h);
