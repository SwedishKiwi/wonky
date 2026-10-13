import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../helpers.dart';
import '../registry.dart';

/// Rounding family (05 §15.1): decimal-correct on the 15-digit representation (§6.5).
void registerRounding(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.math;

  void places(
    String name,
    String summary,
    double Function(double x, int p) f, {
    Priority priority = Priority.p0,
    List<String> examples = const [],
  }) {
    b.fn(
      name,
      summary,
      [
        P.num('value', 'The value to round.'),
        P.num(
          'places',
          'The number of decimal places to which to round. May be negative.',
          true,
          0,
        ),
      ],
      (a) {
        final x = a.number(0);
        final p = a.intOr(1, 0);
        final hint = a[0] is FNumber ? (a[0] as FNumber).hint : null;
        final r = f(x, p);
        return hint == null ? numResult(r) : numResult(r, hint);
      },
      priority: priority,
      examples: examples,
    );
  }

  places(
    'ROUND',
    'Rounds a number to a certain number of decimal places according to standard rules (half away from zero).',
    Numeric.roundHalfAway,
    examples: ['ROUND(2.675, 2)', 'ROUND(1234.5, -2)'],
  );
  places(
    'ROUNDUP',
    'Rounds a number to a certain number of decimal places, always rounding up (away from zero) to the next valid increment.',
    Numeric.roundUp,
    examples: ['ROUNDUP(3.141, 2)'],
  );
  places(
    'ROUNDDOWN',
    'Rounds a number to a certain number of decimal places, always rounding down (toward zero) to the next valid increment.',
    Numeric.roundDown,
    examples: ['ROUNDDOWN(3.149, 2)'],
  );
  places(
    'TRUNC',
    'Truncates a number to a certain number of significant digits by omitting less significant digits.',
    Numeric.roundDown,
    examples: ['TRUNC(-3.7)', 'TRUNC(3.14159, 2)'],
  );

  b.fn(
    'MROUND',
    'Rounds one number to the nearest integer multiple of another.',
    [
      P.num(
        'value',
        'The number to round to the nearest integer multiple of another.',
      ),
      P.num('factor', 'The number to whose multiples value will be rounded.'),
    ],
    (a) {
      final x = a.number(0), f = a.number(1);
      if (f == 0 || x == 0) return FNumber.zero;
      if ((x < 0) != (f < 0)) fail(ErrorKind.num);
      final q = Numeric.roundHalfAway(x / f, 0);
      return numResult(Numeric.roundSignificant(q * f, 15));
    },
    examples: ['MROUND(10, 3)', 'MROUND(-10, -3)'],
  );

  b.fn(
    'CEILING',
    'Rounds a number up to the nearest integer multiple of specified significance.',
    [
      P.num(
        'value',
        'The value to round up to the nearest integer multiple of factor.',
      ),
      P.num(
        'factor',
        'The number to whose multiples value will be rounded.',
        true,
        1,
      ),
    ],
    (a) {
      final x = a.number(0);
      final f = a.numberOr(1, 1);
      if (f == 0 || x == 0) return FNumber.zero;
      if (x > 0 && f < 0) {
        fail(ErrorKind.num, 'Parameters of CEILING must have the same sign.');
      }
      return numResult(_toward(x, f.abs(), up: true, awayForNegative: f < 0));
    },
    priority: Priority.p0,
    examples: ['CEILING(23.25, 0.1)', 'CEILING(-2.5, 1)'],
  );

  b.fn(
    'FLOOR',
    'Rounds a number down to the nearest integer multiple of specified significance.',
    [
      P.num(
        'value',
        'The value to round down to the nearest integer multiple of factor.',
      ),
      P.num(
        'factor',
        'The number to whose multiples value will be rounded.',
        true,
        1,
      ),
    ],
    (a) {
      final x = a.number(0);
      final f = a.numberOr(1, 1);
      if (f == 0 && x != 0) {
        fail(ErrorKind.div0, ErrorMessages.divByZero('FLOOR', 2));
      }
      if (x == 0) return FNumber.zero;
      if (x > 0 && f < 0) {
        fail(ErrorKind.num, 'Parameters of FLOOR must have the same sign.');
      }
      return numResult(_toward(x, f.abs(), up: false, awayForNegative: f < 0));
    },
    priority: Priority.p0,
    examples: ['FLOOR(23.25, 0.1)', 'FLOOR(-2.5, 1)'],
  );

  FValue math(Args a, {required bool ceiling}) {
    final x = a.number(0);
    final s = a.numberOr(1, x < 0 ? -1 : 1).abs();
    final mode = a.numberOr(2, 0);
    if (s == 0 || x == 0) return FNumber.zero;
    final towardZeroForNegative = mode == 0;
    if (x >= 0) return numResult(_round(x, s, ceiling));
    // negative numbers: mode 0 → toward +∞ for CEILING (toward zero), mode ≠ 0 → away from zero
    final up = ceiling ? towardZeroForNegative : !towardZeroForNegative;
    return numResult(_round(x, s, up));
  }

  b.fn(
    'CEILING.MATH',
    'Rounds a number up to the nearest integer multiple of specified significance, with negative numbers rounding toward or away from 0 depending on the mode.',
    [
      P.num(
        'number',
        'The value to round up to the nearest integer multiple of significance.',
      ),
      P.num(
        'significance',
        'The number to whose multiples number will be rounded. The sign of significance will be ignored.',
        true,
        1,
      ),
      P.num(
        'mode',
        'If number is negative, specifies the rounding direction. If 0 or blank, it is rounded towards zero. Otherwise, it is rounded away from zero.',
        true,
        0,
      ),
    ],
    (a) => math(a, ceiling: true),
    examples: ['CEILING.MATH(-5.5, 2, 1)'],
  );
  b.fn(
    'FLOOR.MATH',
    'Rounds a number down to the nearest integer multiple of specified significance, with negative numbers rounding toward or away from 0 depending on the mode.',
    [
      P.num(
        'number',
        'The value to round down to the nearest integer multiple of significance.',
      ),
      P.num(
        'significance',
        'The number to whose multiples number will be rounded. The sign of significance will be ignored.',
        true,
        1,
      ),
      P.num(
        'mode',
        'If number is negative, specifies the rounding direction. If 0 or blank, it is rounded away from zero. Otherwise, it is rounded towards zero.',
        true,
        0,
      ),
    ],
    (a) => math(a, ceiling: false),
    examples: ['FLOOR.MATH(-5.5, 2, 1)'],
  );

  FValue precise(Args a, bool ceiling) {
    final x = a.number(0);
    final s = a.numberOr(1, 1).abs();
    if (s == 0 || x == 0) return FNumber.zero;
    return numResult(_round(x, s, ceiling));
  }

  b.fn(
    'CEILING.PRECISE',
    'Rounds a number up to the nearest integer multiple of specified significance. If the number is positive or negative, it is rounded up.',
    [
      P.num('number', 'The value to round up.'),
      P.num('significance', 'The multiple; its sign is ignored.', true, 1),
    ],
    (a) => precise(a, true),
    aliases: ['ISO.CEILING'],
    examples: ['CEILING.PRECISE(-4.5, 2)'],
  );
  b.fn(
    'FLOOR.PRECISE',
    'Rounds a number down to the nearest integer multiple of specified significance. If the number is positive or negative, it is rounded down.',
    [
      P.num('number', 'The value to round down.'),
      P.num('significance', 'The multiple; its sign is ignored.', true, 1),
    ],
    (a) => precise(a, false),
    examples: ['FLOOR.PRECISE(-4.5, 2)'],
  );

  b.fn(
    'EVEN',
    'Rounds a number up to the nearest even integer (away from zero).',
    [P.num('value', 'The value to round to the next even integer.')],
    (a) {
      final x = a.number(0);
      final m = (x.abs() / 2).ceilToDouble() * 2;
      return numResult(x < 0 ? -m : m);
    },
    examples: ['EVEN(3)', 'EVEN(-1.5)'],
  );
  b.fn(
    'ODD',
    'Rounds a number up to the nearest odd integer (away from zero).',
    [P.num('value', 'The value to round to the next odd integer.')],
    (a) {
      final x = a.number(0);
      var m = x.abs().ceilToDouble();
      if (m % 2 == 0) m += 1;
      return numResult(x < 0 ? -m : m);
    },
    examples: ['ODD(2)', 'ODD(-1.5)'],
  );
}

double _snap(double q) {
  final r = q.roundToDouble();
  return Numeric.approxEqual(q, r) || (q - r).abs() < 1e-9 ? r : q;
}

/// Rounds x to a multiple of s (s > 0): [up] toward +∞, else toward −∞.
double _round(double x, double s, bool up) {
  final q = _snap(x / s);
  final m = up ? q.ceilToDouble() : q.floorToDouble();
  return Numeric.roundSignificant(m * s, 15);
}

/// Sheets CEILING/FLOOR: positive factor → round toward +∞ (CEILING) / −∞ (FLOOR); negative
/// factor with negative value → away from / toward zero.
double _toward(
  double x,
  double s, {
  required bool up,
  required bool awayForNegative,
}) {
  if (awayForNegative && x < 0) {
    // CEILING(-2.5,-1) = -3 (away from zero); FLOOR(-2.5,-1) = -2 (toward zero)
    return up ? _round(x, s, false) : _round(x, s, true);
  }
  return _round(x, s, up);
}
