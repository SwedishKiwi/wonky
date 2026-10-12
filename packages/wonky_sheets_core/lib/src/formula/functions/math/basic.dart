import 'dart:math' as math;

import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../../eval/operators.dart';
import '../helpers.dart';
import '../registry.dart';

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
double _tanh(double x) {
  if (x > 20) return 1;
  if (x < -20) return -1;
  final e2 = math.exp(2 * x);
  return (e2 - 1) / (e2 + 1);
}

/// Math & trigonometry basics (05 §15.1).
void registerMathBasic(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.math;
  unaryMath(b, 'ABS', 'Returns the absolute value of a number.', (x) => x.abs(), priority: Priority.p0, examples: ['ABS(-2)']);
  b.fn(
    'SIGN',
    'Given an input number, returns -1 if it is negative, 1 if positive, and 0 if it is zero.',
    [P.num('value', 'The value whose sign will be evaluated.')],
    (a) {
      final x = a.number(0);
      return FNumber(x > 0 ? 1 : (x < 0 ? -1 : 0));
    },
    priority: Priority.p0,
    examples: ['SIGN(-3)'],
  );
  unaryMath(b, 'SQRT', 'Returns the positive square root of a positive number.', math.sqrt, domain: (x) => x >= 0, priority: Priority.p0, examples: ['SQRT(9)']);
  unaryMath(b, 'SQRTPI', 'Returns the positive square root of the product of Pi and the given positive number.', (x) => math.sqrt(x * math.pi), domain: (x) => x >= 0, stable: true, examples: ['SQRTPI(2)']);
  unaryMath(b, 'EXP', "Returns Euler's number, e (~2.718) raised to a power.", math.exp, arg: 'exponent', stable: true, priority: Priority.p0, examples: ['EXP(1)']);
  unaryMath(b, 'LN', "Returns the logarithm of a number, base e (Euler's number).", math.log, domain: (x) => x > 0, stable: true, priority: Priority.p0, examples: ['LN(100)']);
  unaryMath(b, 'LOG10', 'Returns the logarithm of a number, base 10.', (x) => math.log(x) / math.ln10, domain: (x) => x > 0, stable: true, priority: Priority.p0, examples: ['LOG10(1000)']);
  b.fn(
    'LOG',
    'Returns the logarithm of a number given a base.',
    [P.num('value', 'The value for which to calculate the logarithm.'), P.num('base', 'The base to use for calculation of logarithm.', true, 10)],
    (a) {
      final x = a.number(0);
      final base = a.numberOr(1, 10);
      if (x <= 0 || base <= 0) fail(ErrorKind.num);
      if (base == 1) fail(ErrorKind.div0);
      if (base == 10) return stableResult(math.log(x) / math.ln10);
      return stableResult(math.log(x) / math.log(base));
    },
    priority: Priority.p0,
    examples: ['LOG(128, 2)', 'LOG(100)'],
  );
  b.fn('PI', 'Returns the value of Pi to 14 decimal places.', const [], (_) => const FNumber(math.pi), priority: Priority.p0, examples: ['PI()']);
  b.fn(
    'POWER',
    'Returns a number raised to a power.',
    [P.num('base', 'The number to raise to the exponent power.'), P.num('exponent', 'The exponent to raise base to.')],
    (a) => Operators.power(a.number(0), a.number(1)),
    priority: Priority.p0,
    examples: ['POWER(2, 0.5)'],
  );
  b.fn(
    'MOD',
    'Returns the result of the modulo operator, the remainder after a division operation.',
    [P.num('dividend', 'The number to be divided to find the remainder.'), P.num('divisor', 'The number to divide by.')],
    (a) {
      final x = a.number(0), y = a.number(1);
      if (y == 0) fail(ErrorKind.div0, ErrorMessages.divByZero('MOD', 2));
      final r = x - y * (x / y).floorToDouble();
      // snap tiny residues from floating point division
      if (Numeric.approxEqual(r, y)) return FNumber.zero;
      return numResult(Numeric.roundSignificant(r, 15) == 0 ? 0 : r);
    },
    priority: Priority.p0,
    examples: ['MOD(10, 4)', 'MOD(-3, 2)'],
  );
  b.fn(
    'QUOTIENT',
    'Returns one number divided by another, without the remainder.',
    [P.num('dividend', 'The number to be divided.'), P.num('divisor', 'The number to divide by.')],
    (a) {
      final x = a.number(0), y = a.number(1);
      if (y == 0) fail(ErrorKind.div0, ErrorMessages.divByZero('QUOTIENT', 2));
      return numResult((x / y).truncateToDouble());
    },
    examples: ['QUOTIENT(15, 4)'],
  );
  unaryMath(b, 'INT', 'Rounds a number down to the nearest integer that is less than or equal to it.', (x) => x.floorToDouble(), priority: Priority.p0, examples: ['INT(-1.5)']);
  unaryMath(b, 'DEGREES', 'Converts an angle value in radians to degrees.', (x) => x * 180 / math.pi, arg: 'angle', priority: Priority.p0, examples: ['DEGREES(PI())']);
  unaryMath(b, 'RADIANS', 'Converts an angle value in degrees to radians.', (x) => x * math.pi / 180, arg: 'angle', priority: Priority.p0, examples: ['RADIANS(180)']);
  // trig
  unaryMath(b, 'SIN', 'Returns the sine of an angle provided in radians.', math.sin, arg: 'angle', stable: true, priority: Priority.p0, examples: ['SIN(PI()/2)']);
  unaryMath(b, 'COS', 'Returns the cosine of an angle provided in radians.', math.cos, arg: 'angle', stable: true, priority: Priority.p0, examples: ['COS(PI())']);
  unaryMath(b, 'TAN', 'Returns the tangent of an angle provided in radians.', math.tan, arg: 'angle', stable: true, priority: Priority.p0, examples: ['TAN(PI()/4)']);
  unaryMath(b, 'COT', 'Returns the cotangent of an angle provided in radians.', (x) => 1 / math.tan(x), arg: 'angle', stable: true, domain: (x) => x != 0, domainError: ErrorKind.div0, examples: ['COT(1)']);
  unaryMath(b, 'SEC', 'Returns the secant of an angle, measured in radians.', (x) => 1 / math.cos(x), arg: 'angle', stable: true, examples: ['SEC(0)']);
  unaryMath(b, 'CSC', 'Returns the cosecant of an angle provided in radians.', (x) => 1 / math.sin(x), arg: 'angle', stable: true, domain: (x) => x != 0, domainError: ErrorKind.div0, examples: ['CSC(1)']);
  unaryMath(b, 'ASIN', 'Returns the inverse sine of a value, in radians.', math.asin, domain: (x) => x.abs() <= 1, stable: true, examples: ['ASIN(0.5)']);
  unaryMath(b, 'ACOS', 'Returns the inverse cosine of a value, in radians.', math.acos, domain: (x) => x.abs() <= 1, stable: true, examples: ['ACOS(0)']);
  unaryMath(b, 'ATAN', 'Returns the inverse tangent of a value, in radians.', math.atan, stable: true, examples: ['ATAN(1)']);
  unaryMath(b, 'ACOT', 'Returns the inverse cotangent of a value, in radians.', (x) => x == 0 ? math.pi / 2 : math.atan(1 / x) + (x < 0 ? math.pi : 0), stable: true, examples: ['ACOT(1)']);
  b.fn(
    'ATAN2',
    'Returns the angle between the x-axis and a line segment from the origin (0,0) to specified coordinate pair (x,y), in radians.',
    [P.num('x', 'The x coordinate of the endpoint of the line segment.'), P.num('y', 'The y coordinate of the endpoint of the line segment.')],
    (a) {
      final x = a.number(0), y = a.number(1);
      if (x == 0 && y == 0) fail(ErrorKind.div0);
      return stableResult(math.atan2(y, x));
    },
    examples: ['ATAN2(1, 1)'],
  );
  unaryMath(b, 'SINH', 'Returns the hyperbolic sine of any real number.', _sinh, stable: true, examples: ['SINH(1)']);
  unaryMath(b, 'COSH', 'Returns the hyperbolic cosine of any real number.', _cosh, stable: true, examples: ['COSH(1)']);
  unaryMath(b, 'TANH', 'Returns the hyperbolic tangent of any real number.', _tanh, stable: true, examples: ['TANH(1)']);
  unaryMath(b, 'COTH', 'Returns the hyperbolic cotangent of any real number.', (x) => 1 / _tanh(x), stable: true, domain: (x) => x != 0, domainError: ErrorKind.div0, examples: ['COTH(1)']);
  unaryMath(b, 'SECH', 'Returns the hyperbolic secant of an angle.', (x) => 1 / _cosh(x), stable: true, examples: ['SECH(1)']);
  unaryMath(b, 'CSCH', 'Returns the hyperbolic cosecant of any real number.', (x) => 1 / _sinh(x), stable: true, domain: (x) => x != 0, domainError: ErrorKind.div0, examples: ['CSCH(1)']);
  unaryMath(b, 'ASINH', 'Returns the inverse hyperbolic sine of a number.', (x) => math.log(x + math.sqrt(x * x + 1)) * (x < 0 ? 1 : 1), stable: true, examples: ['ASINH(1)']);
  unaryMath(b, 'ACOSH', 'Returns the inverse hyperbolic cosine of a number.', (x) => math.log(x + math.sqrt(x * x - 1)), domain: (x) => x >= 1, stable: true, examples: ['ACOSH(2)']);
  unaryMath(b, 'ATANH', 'Returns the inverse hyperbolic tangent of a number.', (x) => 0.5 * math.log((1 + x) / (1 - x)), domain: (x) => x.abs() < 1, stable: true, examples: ['ATANH(0.5)']);
  unaryMath(b, 'ACOTH', 'Returns the inverse hyperbolic cotangent of a value, in radians. Must not be between -1 and 1, inclusive.', (x) => 0.5 * math.log((x + 1) / (x - 1)), domain: (x) => x.abs() > 1, stable: true, examples: ['ACOTH(2)']);
}
