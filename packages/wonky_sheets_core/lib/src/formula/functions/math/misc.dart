import 'dart:math' as math;

import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../eval/range_access.dart';
import '../../eval/runtime_services.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../helpers.dart';
import '../registry.dart';

double _fact(int n) {
  var r = 1.0;
  for (var i = 2; i <= n; i++) {
    r *= i;
  }
  return r;
}

double _gcd(double a, double b) {
  while (b != 0) {
    final t = a % b;
    a = b;
    b = t;
  }
  return a;
}

/// Combinations and related integer math, random numbers, SEQUENCE, MUNIT, BASE/DECIMAL.
void registerMathMisc(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.math;

  List<double> integers(Args a) {
    final xs = a.numbers();
    for (final x in xs) {
      if (x < 0) fail(ErrorKind.num);
    }
    return [for (final x in xs) x.truncateToDouble()];
  }

  b.fn(
    'GCD',
    'Returns the greatest common divisor of one or more integers.',
    [P.range('value1', 'The first value or range whose factors to consider.'), P.rep('value2', ArgKind.range, 'Additional values or ranges.')],
    (a) {
      final xs = integers(a);
      var g = 0.0;
      for (final x in xs) {
        g = _gcd(g, x);
      }
      return numResult(g);
    },
    examples: ['GCD(24, 36)', 'GCD(A1:A5)'],
  );
  b.fn(
    'LCM',
    'Returns the least common multiple of one or more integers.',
    [P.range('value1', 'The first value or range whose factors to consider.'), P.rep('value2', ArgKind.range, 'Additional values or ranges.')],
    (a) {
      final xs = integers(a);
      if (xs.isEmpty) return FNumber.zero;
      var l = 1.0;
      for (final x in xs) {
        if (x == 0) return FNumber.zero;
        l = l / _gcd(l, x) * x;
      }
      return numResult(l);
    },
    examples: ['LCM(4, 6)'],
  );
  b.fn(
    'FACT',
    'Returns the factorial of a number.',
    [P.num('value', 'The number or reference to a number whose factorial will be calculated and returned.')],
    (a) {
      final x = a.number(0);
      if (x < 0) fail(ErrorKind.num);
      final n = x.truncate();
      if (n > 170) fail(ErrorKind.num);
      return numResult(_fact(n));
    },
    examples: ['FACT(5)'],
  );
  b.fn(
    'FACTDOUBLE',
    'Returns the "double factorial" of a number.',
    [P.num('value', 'The number or reference to a number whose double factorial will be calculated and returned.')],
    (a) {
      final x = a.number(0);
      if (x < -1) fail(ErrorKind.num);
      var n = x.truncate();
      var r = 1.0;
      while (n > 1) {
        r *= n;
        n -= 2;
      }
      return numResult(r);
    },
    examples: ['FACTDOUBLE(6)'],
  );
  b.fn(
    'COMBIN',
    'Returns the number of ways to choose some number of objects from a pool of a given size of objects.',
    [P.num('n', 'The size of the pool of objects to choose from.'), P.num('k', 'The number of objects to choose.')],
    (a) {
      final n = a.number(0).truncate(), k = a.number(1).truncate();
      if (n < 0 || k < 0 || k > n) fail(ErrorKind.num);
      return numResult(combin(n, k));
    },
    examples: ['COMBIN(4, 2)'],
  );
  b.fn(
    'COMBINA',
    'Returns the number of ways to choose some number of objects from a pool of a given size of objects, including ways that choose the same object multiple times.',
    [P.num('n', 'The size of the pool of objects to choose from.'), P.num('k', 'The number of objects to choose.')],
    (a) {
      final n = a.number(0).truncate(), k = a.number(1).truncate();
      if (n < 0 || k < 0) fail(ErrorKind.num);
      if (n == 0 && k == 0) return FNumber.one;
      if (n == 0) return FNumber.zero;
      return numResult(combin(n + k - 1, k));
    },
    examples: ['COMBINA(4, 3)'],
  );
  b.fn(
    'MULTINOMIAL',
    'Returns the factorial of the sum of values divided by the product of the values\' factorials.',
    [P.range('value1', 'The first value or range to consider.'), P.rep('value2', ArgKind.range, 'Additional values or ranges.')],
    (a) {
      final xs = a.numbers();
      var sum = 0;
      var r = 1.0;
      for (final x in xs) {
        if (x < 0) fail(ErrorKind.num);
        final n = x.truncate();
        for (var i = 1; i <= n; i++) {
          sum++;
          r = r * sum / i;
        }
      }
      return numResult(r.roundToDouble());
    },
    priority: Priority.p2,
    examples: ['MULTINOMIAL(2, 3, 4)'],
  );
  b.fn(
    'SERIESSUM',
    'Given parameters x, n, m, and a, returns the power series sum a1x^n + a2x^(n+m) + … + aix^(n+(i-1)m).',
    [
      P.num('x', 'The input to the power series.'),
      P.num('n', 'The initial power to which to raise x in the power series.'),
      P.num('m', 'The additive increment by which to increase x.'),
      P.range('a', 'The array or range containing the coefficients of the power series.'),
    ],
    (a) {
      final x = a.number(0), n = a.number(1), m = a.number(2);
      final coeffs = <double>[];
      for (final v in a.array(3).elements) {
        if (v is FError) throw FormulaError(v);
        if (v is FNumber) {
          coeffs.add(v.v);
        } else if (v is! FEmpty) {
          fail(ErrorKind.value);
        }
      }
      var s = 0.0;
      for (var i = 0; i < coeffs.length; i++) {
        s += coeffs[i] * math.pow(x, n + i * m);
      }
      return stableResult(s);
    },
    priority: Priority.p2,
    examples: ['SERIESSUM(2, 0, 2, {1, 2, 3})'],
  );
  b.fn(
    'BASE',
    'Converts a number into a text representation in another base, for example, base 2 for binary.',
    [
      P.num('value', 'The number to convert into another base. Must be a non-negative integer less than 2^53.'),
      P.num('base', 'The base to convert the value into (2–36).'),
      P.num('min_length', 'The minimum length of the text returned; padded with zeros.', true),
    ],
    (a) {
      final v = a.number(0), base = a.integer(1);
      final minLen = a.intOr(2, 0);
      if (v < 0 || v >= 9007199254740992 || base < 2 || base > 36 || minLen < 0 || minLen > 255) {
        fail(ErrorKind.num);
      }
      final s = BigInt.from(v.truncate()).toRadixString(base).toUpperCase();
      return FText(s.padLeft(minLen, '0'));
    },
    examples: ['BASE(255, 16)', 'BASE(7, 2, 8)'],
  );
  b.fn(
    'DECIMAL',
    'Converts the text representation of a number in another base, to base 10.',
    [P.text('value', 'The text to convert.'), P.num('base', 'The base of the value (2–36).')],
    (a) {
      final s = a.text(0).trim();
      final base = a.integer(1);
      if (base < 2 || base > 36 || s.isEmpty || s.length > 255) fail(ErrorKind.num);
      final n = BigInt.tryParse(s.toLowerCase(), radix: base);
      if (n == null || n.isNegative) fail(ErrorKind.num);
      return numResult(n.toDouble());
    },
    examples: ['DECIMAL("FF", 16)'],
  );

  // ---- random numbers (volatile, deterministic seeds, 05 §12)
  b.fn(
    'RAND',
    'Returns a random number between 0 inclusive and 1 exclusive.',
    const [],
    (a) => FNumber(_rand(a.ctx)),
    volatile: true,
    priority: Priority.p0,
    examples: ['RAND()'],
  );
  b.fn(
    'RANDBETWEEN',
    'Returns a uniformly random integer between two values, inclusive.',
    [P.num('low', 'The low end of the random range.'), P.num('high', 'The high end of the random range.')],
    (a) {
      final lo = a.number(0).ceilToDouble(), hi = a.number(1).floorToDouble();
      if (lo > hi) fail(ErrorKind.num);
      return numResult(lo + (_rand(a.ctx) * (hi - lo + 1)).floorToDouble());
    },
    volatile: true,
    priority: Priority.p0,
    examples: ['RANDBETWEEN(1, 10)'],
  );
  b.fn(
    'RANDARRAY',
    'Generates an array of random numbers between 0 and 1.',
    [
      P.num('rows', 'The number of rows to return.', true, 1),
      P.num('columns', 'The number of columns to return.', true, 1),
      P.num('min', 'The minimum random number (Excel compatibility).', true, 0),
      P.num('max', 'The maximum random number (Excel compatibility).', true, 1),
      P.bool_('whole_number', 'Return integers (Excel compatibility).', true, false),
    ],
    (a) {
      final rows = a.intOr(0, 1), cols = a.intOr(1, 1);
      final lo = a.numberOr(2, 0), hi = a.numberOr(3, 1);
      final whole = a.boolOr(4, false);
      if (rows < 1 || cols < 1 || lo > hi) fail(ErrorKind.value);
      if (rows * cols > maxArrayCells) fail(ErrorKind.num, ErrorMessages.resultTooLarge);
      return FArray.generate(rows, cols, (_, _) {
        final u = _rand(a.ctx);
        if (whole) {
          final l = lo.ceilToDouble(), h = hi.floorToDouble();
          return FNumber(l + (u * (h - l + 1)).floorToDouble());
        }
        return FNumber(lo + u * (hi - lo));
      });
    },
    volatile: true,
    returns: ReturnKind.array,
    examples: ['RANDARRAY(3, 2)'],
  );

  b.fn(
    'SEQUENCE',
    'Returns an array of sequential numbers, such as 1, 2, 3, 4.',
    [
      P.num('rows', 'The number of rows to return.'),
      P.num('columns', 'The number of columns to return.', true, 1),
      P.num('start', 'The number to start the sequence at.', true, 1),
      P.num('step', 'The amount to increase/decrease each number in the sequence.', true, 1),
    ],
    (a) {
      final rows = a.integer(0);
      final cols = a.intOr(1, 1);
      final start = a.numberOr(2, 1, blankIsDefault: true);
      final step = a.numberOr(3, 1, blankIsDefault: true);
      if (rows < 1 || cols < 1) {
        fail(ErrorKind.value, 'SEQUENCE has mismatched row size. Expected: 1. Actual: $rows.');
      }
      if (rows * cols > maxArrayCells) fail(ErrorKind.num, ErrorMessages.resultTooLarge);
      return FArray.generate(rows, cols, (r, c) => FNumber(Numeric.add(start, (r * cols + c) * step)));
    },
    returns: ReturnKind.array,
    priority: Priority.p0,
    examples: ['SEQUENCE(5)', 'SEQUENCE(2, 3, 10, 5)'],
  );
  b.fn(
    'MUNIT',
    'Returns a unit matrix of size dimension × dimension.',
    [P.num('dimension', 'An integer specifying the dimension size of the unit matrix.')],
    (a) {
      final n = a.integer(0);
      if (n < 1) fail(ErrorKind.value);
      if (n * n > maxArrayCells) fail(ErrorKind.num, ErrorMessages.resultTooLarge);
      return FArray.generate(n, n, (r, c) => r == c ? FNumber.one : FNumber.zero);
    },
    returns: ReturnKind.array,
    examples: ['MUNIT(3)'],
  );
}

/// n choose k as double.
double combin(int n, int k) {
  if (k > n - k) k = n - k;
  var r = 1.0;
  for (var i = 1; i <= k; i++) {
    r = r * (n - k + i) / i;
  }
  return r.roundToDouble();
}

double _rand(EvalContext ctx) {
  ctx.deps.volatile = true;
  return DeterministicRandom.uniform(
    ctx.host.workbook.spreadsheetId,
    ctx.cellId,
    ctx.randCounter++,
    ctx.host.randomEpoch,
  );
}
