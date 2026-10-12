import 'dart:math' as math;

import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/compare.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../criteria.dart';
import '../helpers.dart';
import '../registry.dart';
import 'common.dart';

const _v1 = 'The first value or range to consider.';
const _v2 = 'Additional values or ranges to consider.';

List<ArgSpec> _values() => [
  P.range('value1', _v1),
  P.rep('value2', ArgKind.range, _v2),
];

/// Registers a `NAME(value1, [value2, …])` aggregate.
void _agg(
  FunctionRegistryBuilder b,
  String name,
  String summary,
  FValue Function(Args a) impl, {
  List<String> aliases = const [],
  Priority priority = Priority.p1,
  List<String> examples = const [],
  List<String> seeAlso = const [],
  bool handlesErrors = false,
  String? notes,
}) {
  b.fn(
    name,
    summary,
    _values(),
    impl,
    aliases: aliases,
    priority: priority,
    examples: examples.isEmpty ? ['$name(A2:A100)'] : examples,
    seeAlso: seeAlso,
    handlesErrors: handlesErrors,
    notes: notes,
  );
}

/// Counting, central tendency, spread and shape (05 §15.2).
void registerDescriptive(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.statistical;
  _registerCounts(b);
  _registerMeans(b);
  _registerOrder(b);
  _registerSpread(b);
  _registerMisc(b);
}

// -------------------------------------------------------------------- counts

void _registerCounts(FunctionRegistryBuilder b) {
  _agg(
    b,
    'COUNT',
    'Returns a count of the number of numeric values in a dataset.',
    (a) {
      var n = 0;
      for (var i = 0; i < a.length; i++) {
        final v = a[i];
        if (v is FRef || v is FArray) {
          a.forEach(i, (x) {
            if (x is FRich) x = x.scalar;
            if (x is FNumber) n++;
          });
        } else if (v is! FOmitted && isCountableScalar(v, a)) {
          n++;
        }
      }
      return FNumber(n.toDouble());
    },
    priority: Priority.p0,
    handlesErrors: true,
    examples: ['COUNT(A2:A100, B2:B100, 4, 26)'],
    seeAlso: ['COUNTA', 'COUNTIF', 'COUNTBLANK'],
    notes:
        'Numeric text inside ranges is not counted; numeric text given directly is.',
  );
  _agg(
    b,
    'COUNTA',
    'Returns a count of the number of values in a dataset.',
    (a) {
      var n = 0;
      for (var i = 0; i < a.length; i++) {
        final v = a[i];
        if (v is FRef || v is FArray) {
          a.forEach(i, (x) {
            if (x is! FEmpty && x is! FOmitted) n++;
          });
        } else if (v is! FOmitted && v is! FEmpty) {
          n++;
        }
      }
      return FNumber(n.toDouble());
    },
    priority: Priority.p0,
    handlesErrors: true,
    examples: ['COUNTA(A2:A100, B2:B100, 4, 26)'],
    seeAlso: ['COUNT', 'COUNTBLANK'],
    notes: 'Cells with formulas that return "" are counted.',
  );
  b.fn(
    'COUNTBLANK',
    'Returns the number of empty cells in a given range.',
    [P.range('range', 'The range in which to count empty cells.')],
    (a) {
      final v = a[0];
      if (v is FRef) {
        final area = v.area;
        var filled = 0;
        a.forEach(0, (x) {
          if (!(x is FText && x.v.isEmpty)) filled++;
        });
        return FNumber((area.cellCount - filled).toDouble());
      }
      var n = 0;
      for (final x in a.flat(0)) {
        if (x is FEmpty || (x is FText && x.v.isEmpty)) n++;
      }
      return FNumber(n.toDouble());
    },
    priority: Priority.p0,
    handlesErrors: true,
    examples: ['COUNTBLANK(A2:C100)'],
    seeAlso: ['COUNTA', 'COUNT'],
    notes: 'Cells with formulas that return "" are counted as blank.',
  );
  _agg(
    b,
    'COUNTUNIQUE',
    'Counts the number of unique values in a list of specified values and ranges.',
    (a) {
      final seen = <Object>{};
      for (var i = 0; i < a.length; i++) {
        final v = a[i];
        if (v is FOmitted) continue;
        for (final x in a.flat(i)) {
          _addUnique(seen, x);
        }
      }
      return FNumber(seen.length.toDouble());
    },
    priority: Priority.p0,
    examples: ['COUNTUNIQUE(A1:C10, 1, 2, 3, 5, 8, 13)'],
    seeAlso: ['COUNTUNIQUEIFS', 'UNIQUE', 'COUNTA'],
    notes: 'Text is compared case-insensitively; blank cells are not counted.',
  );
  b.fn(
    'COUNTUNIQUEIFS',
    'Returns the unique count of a range depending on multiple criteria.',
    [
      P.range(
        'count_unique_range',
        'The range from which the number of unique values will be counted.',
      ),
      P.range('criteria_range1', 'The range to check against criterion1.'),
      P.scalar(
        'criterion1',
        'The pattern or test to apply to criteria_range1.',
      ),
      P.rep('criteria_range2', ArgKind.range, 'Additional ranges to check.'),
      P.rep('criterion2', ArgKind.scalar, 'Additional criteria to check.'),
    ],
    (a) {
      if ((a.length - 1).isOdd) {
        fail(ErrorKind.na, ErrorMessages.wrongArgCount(a.fn, 3, 255, a.length));
      }
      final values = a.array(0);
      final tests = <(FArray, Criterion)>[];
      for (var i = 1; i < a.length; i += 2) {
        final r = a.array(i);
        if (r.rows != values.rows || r.cols != values.cols) {
          fail(ErrorKind.value, ErrorMessages.arraySizeMismatch(a.fn));
        }
        final c = a.scalarOrError(i + 1);
        tests.add((r, Criterion.of(c, a.locale)));
      }
      final seen = <Object>{};
      for (var k = 0; k < values.length; k++) {
        var ok = true;
        for (final (r, c) in tests) {
          if (!c.test(r.atIndex(k))) {
            ok = false;
            break;
          }
        }
        if (ok) _addUnique(seen, values.atIndex(k));
      }
      return FNumber(seen.length.toDouble());
    },
    examples: ['COUNTUNIQUEIFS(A1:A10, B1:B10, ">20")'],
    seeAlso: ['COUNTUNIQUE', 'COUNTIFS'],
  );
}

void _addUnique(Set<Object> seen, FValue x) {
  if (x is FRich) x = x.scalar;
  if (x is FError) throw FormulaError(x);
  if (x is FText && x.v.isEmpty) return;
  final k = Compare.matchKey(x);
  if (k != null) seen.add(k);
}

// -------------------------------------------------------------------- means

FValue _hinted(
  Args a,
  double Function(List<double> xs) f, {
  bool empty0 = false,
  ErrorKind? emptyError,
}) {
  final xs = <double>[];
  final hint = a.collectNumbers(xs);
  if (xs.isEmpty) {
    if (empty0) return FNumber.zero;
    if (emptyError == ErrorKind.div0) divZero(a);
    fail(emptyError ?? ErrorKind.num);
  }
  return numResult(f(xs), hint);
}

void _registerMeans(FunctionRegistryBuilder b) {
  _agg(
    b,
    'AVERAGE',
    'Returns the numerical average value in a dataset, ignoring text.',
    (a) => _hinted(a, meanOf, emptyError: ErrorKind.div0),
    priority: Priority.p0,
    examples: [
      'AVERAGE(A2:A100, B2:B100, 4, 26)',
      'AVERAGE(1, 2, 3, 4, 5, C6:C20)',
    ],
    seeAlso: ['AVERAGEA', 'AVERAGEIF', 'MEDIAN'],
  );
  _agg(
    b,
    'AVERAGEA',
    'Returns the numerical average value in a dataset, counting text as 0 and booleans as 0 or 1.',
    (a) {
      final xs = a.numbers(mode: AggMode.a);
      if (xs.isEmpty) divZero(a);
      return numResult(meanOf(xs));
    },
    examples: ['AVERAGEA(A2:A100, B2:B100, 4, 26)'],
    seeAlso: ['AVERAGE'],
  );
  b.fn(
    'AVERAGE.WEIGHTED',
    'Finds the weighted average of a set of values, given the values and the corresponding weights.',
    [
      P.range('values', 'The values to be averaged.'),
      P.range('weights', 'The corresponding list of weights to apply.'),
      P.rep(
        'additional_values',
        ArgKind.range,
        'Additional values to average.',
      ),
      P.rep(
        'additional_weights',
        ArgKind.range,
        'Additional weights to apply.',
      ),
    ],
    (a) {
      if (a.length.isOdd) {
        fail(ErrorKind.na, ErrorMessages.wrongArgCount(a.fn, 2, 255, a.length));
      }
      var sum = 0.0, wsum = 0.0;
      for (var i = 0; i < a.length; i += 2) {
        final vs = a.array(i), ws = a.array(i + 1);
        if (vs.length != ws.length) {
          fail(ErrorKind.value, ErrorMessages.arraySizeMismatch(a.fn));
        }
        for (var k = 0; k < vs.length; k++) {
          var v = vs.atIndex(k), w = ws.atIndex(k);
          if (v is FRich) v = v.scalar;
          if (w is FRich) w = w.scalar;
          if (v is FError) throw FormulaError(v);
          if (w is FError) throw FormulaError(w);
          if (v is! FNumber || w is! FNumber) continue;
          if (w.v < 0) {
            fail(ErrorKind.num, 'Weight in ${a.fn} cannot be negative.');
          }
          sum += v.v * w.v;
          wsum += w.v;
        }
      }
      if (wsum == 0) divZero(a);
      return numResult(sum / wsum);
    },
    examples: ['AVERAGE.WEIGHTED(A2:A10, B2:B10)'],
    seeAlso: ['AVERAGE', 'SUMPRODUCT'],
  );
  _agg(
    b,
    'GEOMEAN',
    'Calculates the geometric mean of a dataset.',
    (a) {
      final xs = a.numbers();
      if (xs.isEmpty) fail(ErrorKind.num);
      var s = 0.0;
      for (final x in xs) {
        if (x <= 0) fail(ErrorKind.num);
        s += math.log(x);
      }
      return stableResult(math.exp(s / xs.length));
    },
    examples: ['GEOMEAN(1, 2, 3, 4, 5)'],
    seeAlso: ['HARMEAN', 'AVERAGE'],
  );
  _agg(
    b,
    'HARMEAN',
    'Calculates the harmonic mean of a dataset.',
    (a) {
      final xs = a.numbers();
      if (xs.isEmpty) fail(ErrorKind.num);
      var s = 0.0;
      for (final x in xs) {
        if (x <= 0) fail(ErrorKind.num);
        s += 1 / x;
      }
      return numResult(xs.length / s);
    },
    examples: ['HARMEAN(1, 2, 3, 4, 5)'],
    seeAlso: ['GEOMEAN', 'AVERAGE'],
  );
  b.fn(
    'TRIMMEAN',
    'Calculates the mean of a dataset excluding some proportion of data from the high and low ends of the dataset.',
    [
      P.range('data', 'Array or range containing the dataset to consider.'),
      P.num(
        'exclude_proportion',
        'The proportion of the dataset to exclude, from the extremities of the set.',
      ),
    ],
    (a) {
      final p = a.number(1);
      final xs = sortedNumbers(a, 0);
      if (p < 0 || p >= 1 || xs.isEmpty) fail(ErrorKind.num);
      final k = ((xs.length * p) / 2).floor();
      return numResult(meanOf(xs.sublist(k, xs.length - k)));
    },
    examples: ['TRIMMEAN(A2:A100, 0.1)'],
    seeAlso: ['AVERAGE', 'MEDIAN'],
  );
  _agg(
    b,
    'MEDIAN',
    'Returns the median value in a numeric dataset.',
    (a) => _hinted(a, (xs) {
      xs.sort();
      final n = xs.length;
      return n.isOdd ? xs[n ~/ 2] : (xs[n ~/ 2 - 1] + xs[n ~/ 2]) / 2;
    }),
    priority: Priority.p0,
    examples: ['MEDIAN(A2:A100, B2:B100, 4, 26)'],
    seeAlso: ['AVERAGE', 'MODE', 'QUARTILE'],
  );
  _agg(
    b,
    'MODE',
    'Returns the most commonly occurring value in a dataset.',
    (a) {
      final xs = orderedNumbers(a);
      final m = modes(xs);
      if (m.isEmpty) fail(ErrorKind.na, 'No mode for the data in ${a.fn}.');
      return numResult(m.first);
    },
    aliases: ['MODE.SNGL'],
    priority: Priority.p0,
    examples: ['MODE(A2:A100, B2:B100, 4, 26)'],
    seeAlso: ['MODE.MULT', 'MEDIAN', 'AVERAGE'],
  );
  b.fn(
    'MODE.MULT',
    'Returns the most commonly occurring values in a dataset, as a vertical array.',
    _values(),
    (a) {
      final m = modes(orderedNumbers(a));
      if (m.isEmpty) fail(ErrorKind.na, 'No mode for the data in ${a.fn}.');
      return FArray(m.length, 1, [for (final x in m) FNumber(x)]);
    },
    returns: ReturnKind.array,
    examples: ['MODE.MULT(A2:A100)'],
    seeAlso: ['MODE'],
  );
}

// -------------------------------------------------------------------- min/max, order statistics

void _registerOrder(FunctionRegistryBuilder b) {
  _agg(
    b,
    'MAX',
    'Returns the maximum value in a numeric dataset.',
    (a) => _hinted(a, (xs) => xs.reduce(math.max), empty0: true),
    priority: Priority.p0,
    examples: ['MAX(A2:A100, B2:B100, 4, 26)'],
    seeAlso: ['MIN', 'MAXA', 'LARGE', 'MAXIFS'],
  );
  _agg(
    b,
    'MIN',
    'Returns the minimum value in a numeric dataset.',
    (a) => _hinted(a, (xs) => xs.reduce(math.min), empty0: true),
    priority: Priority.p0,
    examples: ['MIN(A2:A100, B2:B100, 4, 26)'],
    seeAlso: ['MAX', 'MINA', 'SMALL', 'MINIFS'],
  );
  _agg(
    b,
    'MAXA',
    'Returns the maximum numeric value in a dataset, counting text as 0 and booleans as 0 or 1.',
    (a) {
      final xs = a.numbers(mode: AggMode.a);
      return xs.isEmpty ? FNumber.zero : numResult(xs.reduce(math.max));
    },
    examples: ['MAXA(A2:A100, B2:B100, 4, 26)'],
    seeAlso: ['MAX', 'MINA'],
  );
  _agg(
    b,
    'MINA',
    'Returns the minimum numeric value in a dataset, counting text as 0 and booleans as 0 or 1.',
    (a) {
      final xs = a.numbers(mode: AggMode.a);
      return xs.isEmpty ? FNumber.zero : numResult(xs.reduce(math.min));
    },
    examples: ['MINA(A2:A100, B2:B100, 4, 26)'],
    seeAlso: ['MIN', 'MAXA'],
  );
  for (final (name, largest) in const [('LARGE', true), ('SMALL', false)]) {
    b.fn(
      name,
      largest
          ? 'Returns the nth largest element from a data set, where n is user-defined.'
          : 'Returns the nth smallest element from a data set, where n is user-defined.',
      [
        P.range('data', 'Array or range containing the dataset to consider.'),
        P.num(
          'n',
          largest
              ? 'The rank from largest to smallest of the element to return.'
              : 'The rank from smallest to largest of the element to return.',
        ),
      ],
      (a) {
        final n = a.number(1).ceil();
        final xs = sortedNumbers(a, 0);
        if (n < 1 || n > xs.length) {
          fail(
            ErrorKind.num,
            'Function $name parameter 2 value $n is out of range.',
          );
        }
        return numResult(largest ? xs[xs.length - n] : xs[n - 1]);
      },
      priority: Priority.p0,
      examples: ['$name(A2:B100, 4)'],
      seeAlso: largest ? ['SMALL', 'MAX', 'RANK'] : ['LARGE', 'MIN', 'RANK'],
    );
  }
  for (final (name, avg, aliases, p) in const [
    ('RANK', false, ['RANK.EQ'], Priority.p0),
    ('RANK.AVG', true, <String>[], Priority.p1),
  ]) {
    b.fn(
      name,
      avg
          ? 'Returns the rank of a specified value in a dataset. If there is more than one entry of the same value in the dataset, the average rank of the entries will be returned.'
          : 'Returns the rank of a specified value in a dataset. If there is more than one entry of the same value in the dataset, the top rank of the entries will be returned.',
      [
        P.num('value', 'The value whose rank will be determined.'),
        P.range(
          'data',
          'The array or range containing the dataset to consider.',
        ),
        P.bool_(
          'is_ascending',
          'Whether to consider the values in data in descending or ascending order.',
          true,
          false,
        ),
      ],
      (a) {
        final x = a.number(0);
        final asc = a.boolOr(2, false);
        final xs = a.numbers(from: 1, to: 2);
        var before = 0, equal = 0;
        for (final v in xs) {
          if (v == x) {
            equal++;
          } else if (asc ? v < x : v > x) {
            before++;
          }
        }
        if (equal == 0) {
          fail(
            ErrorKind.na,
            "Value ${Numeric.toText(x)} does not exist in the data of $name.",
          );
        }
        return FNumber(avg ? before + (equal + 1) / 2 : before + 1.0);
      },
      aliases: aliases,
      priority: p,
      examples: ['$name(A10, A1:A100, TRUE)'],
      seeAlso: ['RANK', 'RANK.AVG', 'PERCENTRANK', 'LARGE'],
    );
  }
  b.fn(
    'PERCENTILE',
    'Returns the value at a given percentile of a dataset.',
    [
      P.range('data', 'The array or range containing the dataset to consider.'),
      P.num(
        'percentile',
        'The percentile whose value within data is to be calculated and returned.',
      ),
    ],
    (a) {
      final p = a.number(1);
      final xs = sortedNumbers(a, 0);
      if (xs.isEmpty || p < 0 || p > 1) fail(ErrorKind.num);
      return numResult(percentileInc(xs, p));
    },
    aliases: ['PERCENTILE.INC'],
    priority: Priority.p0,
    examples: ['PERCENTILE(A2:A100, 0.25)'],
    seeAlso: ['PERCENTILE.EXC', 'QUARTILE', 'PERCENTRANK'],
  );
  b.fn(
    'PERCENTILE.EXC',
    'Returns the value at a given percentile of a dataset, exclusive of 0 and 1.',
    [
      P.range('data', 'The array or range containing the dataset to consider.'),
      P.num(
        'percentile',
        'The percentile, exclusive of 0 and 1, whose value within data will be calculated and returned.',
      ),
    ],
    (a) {
      final p = a.number(1);
      final xs = sortedNumbers(a, 0);
      if (xs.isEmpty || p <= 0 || p >= 1) fail(ErrorKind.num);
      final r = percentileExc(xs, p);
      if (r == null) fail(ErrorKind.num);
      return numResult(r);
    },
    examples: ['PERCENTILE.EXC(A2:A100, 0.25)'],
    seeAlso: ['PERCENTILE', 'QUARTILE.EXC'],
  );
  b.fn(
    'QUARTILE',
    'Returns a value nearest to a specified quartile of a dataset.',
    [
      P.range('data', 'The array or range containing the dataset to consider.'),
      P.num('quartile_number', 'Which quartile value to return (0 to 4).'),
    ],
    (a) {
      final q = a.integer(1);
      final xs = sortedNumbers(a, 0);
      if (xs.isEmpty || q < 0 || q > 4) fail(ErrorKind.num);
      return numResult(percentileInc(xs, q / 4));
    },
    aliases: ['QUARTILE.INC'],
    priority: Priority.p0,
    examples: ['QUARTILE(A2:A100, 3)'],
    seeAlso: ['QUARTILE.EXC', 'PERCENTILE', 'MEDIAN'],
  );
  b.fn(
    'QUARTILE.EXC',
    'Returns value nearest to a given quartile of a dataset, exclusive of 0 and 4.',
    [
      P.range('data', 'The array or range containing the dataset to consider.'),
      P.num('quartile_number', 'Which quartile to return (1 to 3).'),
    ],
    (a) {
      final q = a.integer(1);
      final xs = sortedNumbers(a, 0);
      if (xs.isEmpty || q < 1 || q > 3) fail(ErrorKind.num);
      final r = percentileExc(xs, q / 4);
      if (r == null) fail(ErrorKind.num);
      return numResult(r);
    },
    examples: ['QUARTILE.EXC(A2:A100, 3)'],
    seeAlso: ['QUARTILE', 'PERCENTILE.EXC'],
  );
  for (final (name, exc, aliases) in const [
    ('PERCENTRANK', false, ['PERCENTRANK.INC']),
    ('PERCENTRANK.EXC', true, <String>[]),
  ]) {
    b.fn(
      name,
      exc
          ? 'Returns the percentage rank (percentile) from 0 to 1 exclusive of a specified value in a dataset.'
          : 'Returns the percentage rank (percentile) of a specified value in a dataset.',
      [
        P.range(
          'data',
          'The array or range containing the dataset to consider.',
        ),
        P.num('value', 'The value whose percentage rank will be determined.'),
        P.num(
          'significant_digits',
          'The number of significant figures to use in the calculation.',
          true,
          3,
        ),
      ],
      (a) {
        final x = a.number(1);
        final digits = a.has(2) ? a.integer(2) : 3;
        if (digits < 1) fail(ErrorKind.num);
        final xs = sortedNumbers(a, 0);
        if (xs.isEmpty) fail(ErrorKind.num);
        final r = _percentRank(xs, x, exc);
        if (r == null) {
          fail(ErrorKind.na, "${a.fn} does not have valid input data.");
        }
        return numResult(Numeric.roundDown(r, digits));
      },
      aliases: aliases,
      examples: ['$name(A2:A100, A2)'],
      seeAlso: ['PERCENTILE', 'RANK'],
    );
  }
}

double? _percentRank(List<double> xs, double x, bool exc) {
  final n = xs.length;
  if (x < xs.first || x > xs.last) return null;
  var less = 0;
  while (less < n && xs[less] < x) {
    less++;
  }
  final double
  pos; // 0-based position of x among the sorted values (fractional between)
  if (less < n && xs[less] == x) {
    pos = less.toDouble();
  } else {
    final lo = xs[less - 1], hi = xs[less];
    pos = less - 1 + (x - lo) / (hi - lo);
  }
  if (exc) return (pos + 1) / (n + 1);
  if (n == 1) return 1;
  return pos / (n - 1);
}

// -------------------------------------------------------------------- spread & shape

void _registerSpread(FunctionRegistryBuilder b) {
  for (final (name, sample, mode, aliases, p, summary) in const [
    (
      'STDEV',
      true,
      AggMode.numbers,
      ['STDEV.S'],
      Priority.p0,
      'Calculates the standard deviation based on a sample.',
    ),
    (
      'STDEV.P',
      false,
      AggMode.numbers,
      ['STDEVP'],
      Priority.p0,
      'Calculates the standard deviation based on an entire population.',
    ),
    (
      'STDEVA',
      true,
      AggMode.a,
      <String>[],
      Priority.p1,
      'Calculates the standard deviation based on a sample, setting text to the value 0.',
    ),
    (
      'STDEVPA',
      false,
      AggMode.a,
      <String>[],
      Priority.p1,
      'Calculates the standard deviation based on an entire population, setting text to the value 0.',
    ),
  ]) {
    _agg(
      b,
      name,
      summary,
      (a) => numResult(
        math.sqrt(variance(a, a.numbers(mode: mode), sample: sample)),
      ),
      aliases: aliases,
      priority: p,
      examples: ['$name(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)'],
      seeAlso: ['STDEV', 'STDEV.P', 'VAR'],
    );
  }
  for (final (name, sample, mode, aliases, p, summary) in const [
    (
      'VAR',
      true,
      AggMode.numbers,
      ['VAR.S'],
      Priority.p0,
      'Calculates the variance based on a sample.',
    ),
    (
      'VAR.P',
      false,
      AggMode.numbers,
      ['VARP'],
      Priority.p0,
      'Calculates the variance based on an entire population.',
    ),
    (
      'VARA',
      true,
      AggMode.a,
      <String>[],
      Priority.p1,
      'Calculates an estimate of variance based on a sample, setting text to the value 0.',
    ),
    (
      'VARPA',
      false,
      AggMode.a,
      <String>[],
      Priority.p1,
      'Calculates the variance based on an entire population, setting text to the value 0.',
    ),
  ]) {
    _agg(
      b,
      name,
      summary,
      (a) => numResult(variance(a, a.numbers(mode: mode), sample: sample)),
      aliases: aliases,
      priority: p,
      examples: ['$name(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)'],
      seeAlso: ['VAR', 'VAR.P', 'STDEV'],
    );
  }
  _agg(
    b,
    'DEVSQ',
    'Calculates the sum of squares of deviations based on a sample.',
    (a) {
      final xs = a.numbers();
      if (xs.isEmpty) fail(ErrorKind.num);
      return numResult(devSq(xs));
    },
    examples: ['DEVSQ(1, 2, 3, 4, 5)'],
    seeAlso: ['VAR', 'STDEV'],
  );
  _agg(
    b,
    'AVEDEV',
    'Calculates the average of the magnitudes of deviations of data from a dataset\'s mean.',
    (a) {
      final xs = a.numbers();
      if (xs.isEmpty) fail(ErrorKind.num);
      final m = meanOf(xs);
      return numResult(sumOf(xs.map((x) => (x - m).abs())) / xs.length);
    },
    examples: ['AVEDEV(1, 2, 3, 4, 5)'],
    seeAlso: ['DEVSQ', 'STDEV'],
  );
  _agg(
    b,
    'KURT',
    'Calculates the kurtosis of a dataset, which describes the shape, and in particular the "peakedness" of that dataset.',
    (a) {
      final xs = a.numbers();
      final n = xs.length.toDouble();
      if (n < 4) divZero(a);
      final m = meanOf(xs);
      final s2 = devSq(xs) / (n - 1);
      if (s2 == 0) divZero(a);
      final s4 =
          sumOf(xs.map((x) => math.pow((x - m), 4).toDouble())) / (s2 * s2);
      return numResult(
        n * (n + 1) / ((n - 1) * (n - 2) * (n - 3)) * s4 -
            3 * (n - 1) * (n - 1) / ((n - 2) * (n - 3)),
      );
    },
    examples: ['KURT(1, 2, 3, 4, 5)'],
    seeAlso: ['SKEW'],
  );
  _agg(
    b,
    'SKEW',
    'Calculates the skewness of a dataset, which describes the symmetry of that dataset about the mean.',
    (a) {
      final xs = a.numbers();
      final n = xs.length.toDouble();
      if (n < 3) divZero(a);
      final m = meanOf(xs);
      final s = math.sqrt(devSq(xs) / (n - 1));
      if (s == 0) divZero(a);
      final s3 = sumOf(xs.map((x) => math.pow((x - m) / s, 3).toDouble()));
      return numResult(n / ((n - 1) * (n - 2)) * s3);
    },
    examples: ['SKEW(1, 2, 3, 4, 5, 6, 100)'],
    seeAlso: ['SKEW.P', 'KURT'],
  );
  _agg(
    b,
    'SKEW.P',
    'Calculates the skewness of a dataset that represents the entire population.',
    (a) {
      final xs = a.numbers();
      final n = xs.length.toDouble();
      if (n < 1) divZero(a);
      final m = meanOf(xs);
      final s = math.sqrt(devSq(xs) / n);
      if (s == 0) divZero(a);
      final s3 = sumOf(xs.map((x) => math.pow((x - m) / s, 3).toDouble()));
      return numResult(s3 / n);
    },
    examples: ['SKEW.P(1, 2, 3, 4, 5, 6, 100)'],
    seeAlso: ['SKEW', 'KURT'],
  );
}

// -------------------------------------------------------------------- misc

void _registerMisc(FunctionRegistryBuilder b) {
  b.fn(
    'STANDARDIZE',
    'Calculates the normalized equivalent of a random variable given mean and standard deviation of the distribution.',
    [
      P.num('value', 'The value of the random variable to normalize.'),
      P.num('mean', 'The mean of the distribution.'),
      P.num(
        'standard_deviation',
        'The standard deviation of the distribution.',
      ),
    ],
    (a) {
      final x = a.number(0), m = a.number(1), s = a.number(2);
      if (s <= 0) fail(ErrorKind.num);
      return numResult((x - m) / s);
    },
    examples: ['STANDARDIZE(96, 80, 6.7)'],
    seeAlso: ['NORM.S.DIST', 'NORM.DIST'],
  );
  b.fn(
    'FISHER',
    'Returns the Fisher transformation of a specified value.',
    [
      P.num(
        'value',
        'The value for which to calculate the Fisher transformation.',
      ),
    ],
    (a) {
      final x = a.number(0);
      if (x <= -1 || x >= 1) fail(ErrorKind.num);
      return stableResult(0.5 * math.log((1 + x) / (1 - x)));
    },
    examples: ['FISHER(0.962)'],
    seeAlso: ['FISHERINV'],
  );
  b.fn(
    'FISHERINV',
    'Returns the inverse Fisher transformation of a specified value.',
    [
      P.num(
        'value',
        'The value for which to calculate the inverse Fisher transformation.',
      ),
    ],
    (a) {
      final y = a.number(0);
      if (y > 350) return FNumber.one;
      if (y < -350) return const FNumber(-1);
      final e = math.exp(2 * y);
      return stableResult((e - 1) / (e + 1));
    },
    examples: ['FISHERINV(0.962)'],
    seeAlso: ['FISHER'],
  );
  b.fn(
    'PERMUT',
    'Returns the number of ways to choose some number of objects from a pool of a given size of objects, considering order.',
    [
      P.num('n', 'The size of the pool of objects to choose from.'),
      P.num('k', 'The number of objects to choose.'),
    ],
    (a) {
      final n = a.integer(0), k = a.integer(1);
      if (n < 0 || k < 0 || n < k) fail(ErrorKind.num);
      var r = 1.0;
      for (var i = 0; i < k; i++) {
        r *= n - i;
        if (r.isInfinite) fail(ErrorKind.num);
      }
      return numResult(r);
    },
    examples: ['PERMUT(4, 2)'],
    seeAlso: ['PERMUTATIONA', 'COMBIN'],
  );
  b.fn(
    'PERMUTATIONA',
    'Returns the number of permutations for selecting a group of objects (with replacement) from a total number of objects.',
    [
      P.num('number', 'An integer specifying the number of objects.'),
      P.num(
        'number_chosen',
        'An integer specifying the number of objects in each permutation.',
      ),
    ],
    (a) {
      final n = a.integer(0), k = a.integer(1);
      if (n < 0 || k < 0) fail(ErrorKind.num);
      return numResult(math.pow(n, k).toDouble());
    },
    priority: Priority.p2,
    examples: ['PERMUTATIONA(4, 2)'],
    seeAlso: ['PERMUT', 'COMBINA'],
  );
  b.fn(
    'PROB',
    'Given a set of values and corresponding probabilities, calculates the probability that a value chosen at random falls between two limits.',
    [
      P.array('data', 'Array or range containing the dataset to consider.'),
      P.array(
        'probabilities',
        'Array or range containing probabilities corresponding to data.',
      ),
      P.num(
        'low_limit',
        'The lower bound on the value range for which to calculate the probability.',
      ),
      P.num(
        'high_limit',
        'The upper bound on the value range for which to calculate the probability.',
        true,
      ),
    ],
    (a) {
      final lo = a.number(2);
      final hi = a.has(3) ? a.number(3) : lo;
      final (xs, ps) = pairedNumbers(a, 0, 1);
      var total = 0.0, r = 0.0;
      for (var k = 0; k < xs.length; k++) {
        final p = ps[k];
        if (p < 0 || p > 1) fail(ErrorKind.num);
        total += p;
        if (xs[k] >= lo && xs[k] <= hi) r += p;
      }
      if ((total - 1).abs() > 1e-7) fail(ErrorKind.num);
      return numResult(r);
    },
    priority: Priority.p2,
    examples: ['PROB(A3:A6, B3:B6, 3, 4)'],
    seeAlso: ['BINOM.DIST'],
  );
}
