import 'dart:math' as math;

import '../../values/fvalue.dart';
import '../helpers.dart';
import '../registry.dart';

const double _twoOverSqrtPi = 1.1283791670955126;
const double _oneOverSqrtPi = 0.5641895835477563;

/// erf(x) for |x| < 0.5 by the all-positive series
/// erf(x) = 2/√π · e^(−x²) · Σ (2x²)ⁿ · x / (2n+1)!! (no cancellation).
double _erfSeries(double x) {
  final x2 = 2 * x * x;
  var term = x, sum = x;
  for (var n = 1; n < 200; n++) {
    term *= x2 / (2 * n + 1);
    sum += term;
    if (term.abs() <= 1e-17 * sum.abs()) break;
  }
  return _twoOverSqrtPi * math.exp(-x * x) * sum;
}

/// erfc(x) for x ≥ 0.5 by Laplace's continued fraction
/// erfc(x) = e^(−x²)/√π · 1/(x + (1/2)/(x + 1/(x + (3/2)/(x + …)))),
/// evaluated bottom-up (numerically stable; relative error ≈ 1e-16).
double _erfcFraction(double x) {
  if (x > 27) return 0;
  final terms = (400 / (x * x)).ceil() + 40;
  var t = x;
  for (var k = terms; k >= 1; k--) {
    t = x + (k / 2) / t;
  }
  return math.exp(-x * x) * _oneOverSqrtPi / t;
}

/// The error function.
double erf(double x) {
  if (x.isNaN) return x;
  final ax = x.abs();
  if (ax < 0.5) return _erfSeries(x);
  final r = 1 - _erfcFraction(ax);
  return x < 0 ? -r : r;
}

/// The complementary error function 1 − erf(x), accurate in the tail.
double erfc(double x) {
  if (x.isNaN) return x;
  if (x.abs() < 0.5) return 1 - _erfSeries(x);
  if (x > 0) return _erfcFraction(x);
  return 2 - _erfcFraction(-x);
}

/// ERF, ERF.PRECISE, ERFC, ERFC.PRECISE, DELTA, GESTEP and the Bessel stubs (05 §15.13).
void registerErfAndSteps(FunctionRegistryBuilder b) {
  b.fn(
    'ERF',
    'The ERF function returns the integral of the Gauss error function over an interval of values.',
    [
      P.num(
        'lower_bound',
        'The lower bound for integrating ERF. When upper_bound is omitted, ERF integrates from 0 to lower_bound.',
      ),
      P.num('upper_bound', 'The upper bound for integrating ERF.', true),
    ],
    (a) {
      final lo = a.number(0);
      if (!a.has(1)) return stableResult(erf(lo));
      final hi = a.number(1);
      // Tail-accurate difference when both bounds are on the same side.
      if (lo > 0 && hi > 0) return stableResult(erfc(lo) - erfc(hi));
      if (lo < 0 && hi < 0) return stableResult(erfc(-hi) - erfc(-lo));
      return stableResult(erf(hi) - erf(lo));
    },
    examples: ['ERF(1)', 'ERF(0, 1.5)'],
    seeAlso: ['ERF.PRECISE', 'ERFC'],
  );
  b.fn(
    'ERF.PRECISE',
    'Returns the error function integrated between 0 and a given value.',
    [P.num('x', 'The upper bound for integrating ERF.PRECISE.')],
    (a) => stableResult(erf(a.number(0))),
    examples: ['ERF.PRECISE(0.745)'],
    seeAlso: ['ERF', 'ERFC.PRECISE'],
  );
  b.fn(
    'ERFC',
    'Returns the complementary Gauss error function of a value (1 − ERF).',
    [
      P.num(
        'z',
        'The number for which to calculate the complementary Gauss error function.',
      ),
    ],
    (a) => stableResult(erfc(a.number(0))),
    aliases: ['ERFC.PRECISE'],
    examples: ['ERFC(1)', 'ERFC.PRECISE(2)'],
    seeAlso: ['ERF'],
  );
  b.fn(
    'DELTA',
    'Compare two numeric values, returning 1 if they are equal and 0 otherwise.',
    [
      P.num('number1', 'The first number to compare.'),
      P.num('number2', 'The second number to compare.', true, 0),
    ],
    (a) => FNumber(a.number(0) == a.numberOr(1, 0) ? 1 : 0),
    examples: ['DELTA(5, 4)', 'DELTA(0.5)'],
    seeAlso: ['GESTEP', 'EQ'],
  );
  b.fn(
    'GESTEP',
    'Returns 1 if the rate is strictly greater than or equal to the provided step value or 0 otherwise. If no step value is provided then the default value of 0 will be used.',
    [
      P.num('value', 'The value to be tested against step.'),
      P.num('step', 'The value of the step to compare against.', true, 0),
    ],
    (a) => FNumber(a.number(0) >= a.numberOr(1, 0) ? 1 : 0),
    examples: ['GESTEP(5, 4)', 'GESTEP(-1)'],
    seeAlso: ['DELTA', 'GTE'],
  );
  for (final (name, kind) in [
    ('BESSELI', 'modified Bessel function In(x)'),
    ('BESSELJ', 'Bessel function Jn(x)'),
    ('BESSELK', 'modified Bessel function Kn(x)'),
    ('BESSELY', 'Bessel function Yn(x)'),
  ]) {
    b.stub(
      name,
      'Returns the $kind (Excel only; not available in Google Sheets).',
      message:
          "$name isn't available in Wonky Sheets (it is not in Google Sheets).",
      syntax: '$name(x, n)',
    );
  }
}
