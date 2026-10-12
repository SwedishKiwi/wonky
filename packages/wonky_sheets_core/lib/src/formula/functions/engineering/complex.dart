import 'dart:math' as math;

import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../helpers.dart';
import '../registry.dart';

/// A complex number with the imaginary unit suffix it was written with (`i`, `j`, or null when
/// the text had no imaginary part).
final class _C {
  final double re;
  final double im;
  final String? unit;

  const _C(this.re, [this.im = 0, this.unit]);

  double get abs {
    final a = re.abs(), b = im.abs();
    if (a == 0) return b;
    if (b == 0) return a;
    return a > b
        ? a * math.sqrt(1 + (b / a) * (b / a))
        : b * math.sqrt(1 + (a / b) * (a / b));
  }

  double get arg => math.atan2(im, re);
  bool get isZero => re == 0 && im == 0;

  _C operator +(_C o) => _C(Numeric.add(re, o.re), Numeric.add(im, o.im));
  _C operator -(_C o) => _C(Numeric.sub(re, o.re), Numeric.sub(im, o.im));
  _C operator *(_C o) =>
      _C(Numeric.sub(re * o.re, im * o.im), Numeric.add(re * o.im, im * o.re));

  /// Division (Smith's algorithm); division by zero → `#NUM!`.
  _C operator /(_C o) {
    if (o.isZero) fail(ErrorKind.num, 'Division by a complex zero.');
    if (o.re.abs() >= o.im.abs()) {
      final r = o.im / o.re, d = o.re + o.im * r;
      return _C((re + im * r) / d, (im - re * r) / d);
    }
    final r = o.re / o.im, d = o.re * r + o.im;
    return _C((re * r + im) / d, (im * r - re) / d);
  }

  _C get reciprocal => const _C(1) / this;
}

/// sinh without cancellation for small arguments.
double _sinh(double x) {
  if (x.abs() >= 0.5) return (math.exp(x) - math.exp(-x)) / 2;
  final x2 = x * x;
  var term = x, sum = x;
  for (var n = 1; n < 30; n++) {
    term *= x2 / ((2 * n) * (2 * n + 1));
    sum += term;
    if (term.abs() <= 1e-17 * sum.abs()) break;
  }
  return sum;
}

double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;

_C _exp(_C z) {
  final m = math.exp(z.re);
  return _C(m * math.cos(z.im), m * math.sin(z.im));
}

_C _ln(_C z) {
  if (z.isZero) fail(ErrorKind.num, 'The logarithm of zero is undefined.');
  return _C(math.log(z.abs), z.arg);
}

_C _sin(_C z) => _C(math.sin(z.re) * _cosh(z.im), math.cos(z.re) * _sinh(z.im));
_C _cos(_C z) =>
    _C(math.cos(z.re) * _cosh(z.im), -math.sin(z.re) * _sinh(z.im));
_C _sinhC(_C z) =>
    _C(_sinh(z.re) * math.cos(z.im), _cosh(z.re) * math.sin(z.im));
_C _coshC(_C z) =>
    _C(_cosh(z.re) * math.cos(z.im), _sinh(z.re) * math.sin(z.im));

/// tan(a+bi) = (sin 2a + i·sinh 2b) / (cos 2a + cosh 2b) (no cancellation in small parts).
_C _tan(_C z) {
  if (z.im.abs() > 350) return _C(0, z.im.sign);
  final d = math.cos(2 * z.re) + _cosh(2 * z.im);
  if (d == 0) fail(ErrorKind.num);
  return _C(math.sin(2 * z.re) / d, _sinh(2 * z.im) / d);
}

/// cot(a+bi) = (sin 2a − i·sinh 2b) / (cosh 2b − cos 2a).
_C _cot(_C z) {
  if (z.im.abs() > 350) return _C(0, -z.im.sign);
  final d = _cosh(2 * z.im) - math.cos(2 * z.re);
  if (d == 0) fail(ErrorKind.num, 'The cotangent of zero is undefined.');
  return _C(math.sin(2 * z.re) / d, -_sinh(2 * z.im) / d);
}

/// tanh(a+bi) = (sinh 2a + i·sin 2b) / (cosh 2a + cos 2b).
_C _tanhC(_C z) {
  if (z.re.abs() > 350) return _C(z.re.sign);
  final d = _cosh(2 * z.re) + math.cos(2 * z.im);
  if (d == 0) fail(ErrorKind.num);
  return _C(_sinh(2 * z.re) / d, math.sin(2 * z.im) / d);
}

/// coth(a+bi) = (sinh 2a − i·sin 2b) / (cosh 2a − cos 2b).
_C _cothC(_C z) {
  if (z.re.abs() > 350) return _C(z.re.sign);
  final d = _cosh(2 * z.re) - math.cos(2 * z.im);
  if (d == 0) {
    fail(ErrorKind.num, 'The hyperbolic cotangent of zero is undefined.');
  }
  return _C(_sinh(2 * z.re) / d, -math.sin(2 * z.im) / d);
}

_C _sqrt(_C z) {
  if (z.isZero) return const _C(0);
  final r = z.abs;
  if (z.re >= 0) {
    final t = math.sqrt((r + z.re) / 2);
    return _C(t, z.im / (2 * t));
  }
  final t = math.sqrt((r - z.re) / 2);
  return _C(z.im.abs() / (2 * t), z.im < 0 ? -t : t);
}

_C _power(_C z, double p) {
  if (z.isZero) {
    if (p > 0) return const _C(0);
    fail(ErrorKind.num, 'Zero cannot be raised to a non-positive power.');
  }
  if (p == p.truncateToDouble() && p.abs() <= 1024) {
    // Exact for integer powers (binary exponentiation).
    var n = p.abs().toInt();
    var base = z, acc = const _C(1);
    while (n > 0) {
      if (n.isOdd) acc = acc * base;
      base = base * base;
      n ~/= 2;
    }
    return p < 0 ? acc.reciprocal : acc;
  }
  final m = math.pow(z.abs, p).toDouble(), t = z.arg * p;
  return _C(m * math.cos(t), m * math.sin(t));
}

final RegExp _complexPattern = RegExp(
  r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)?' // real part, or the imaginary coefficient
  r'(?:([+-])((?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)?)?' // sign and imaginary coefficient
  r'([ij])?$',
);

/// Parses complex number text (`3+4i`, `-2.5j`, `i`, `1e3-i`, `7`).
_C _parseText(String text) {
  final s = text.trim();
  if (s.isEmpty) return const _C(0);
  Never bad() => fail(ErrorKind.num, "'$text' is not a valid complex number.");
  final m = _complexPattern.firstMatch(s);
  if (m == null) bad();
  final first = m.group(1),
      sign = m.group(2),
      second = m.group(3),
      unit = m.group(4);
  if (unit == null) {
    // Plain real number.
    if (sign != null || first == null) bad();
    return _C(double.parse(first));
  }
  if (sign == null) {
    // Pure imaginary: `4i`, `-i`, `+2.5j`, `i`.
    if (first == null) return _C(0, 1, unit);
    return _C(0, double.parse(first), unit);
  }
  if (first == null) {
    // `-i`, `+3i` matched as sign + coefficient.
    final c = second == null ? 1.0 : double.parse(second);
    return _C(0, sign == '-' ? -c : c, unit);
  }
  final c = second == null ? 1.0 : double.parse(second);
  return _C(double.parse(first), sign == '-' ? -c : c, unit);
}

/// A complex argument value: numbers are real, text is parsed, blank is zero.
_C _of(FValue v) => switch (v) {
  FNumber(v: final x) => _C(x),
  FText(v: final t) => _parseText(t),
  FEmpty() || FOmitted() => const _C(0),
  final FError e => throw FormulaError(e),
  _ => fail(ErrorKind.value, 'Expected a complex number.'),
};

_C _arg(Args a, int i) => _of(a.scalar(i));

/// The common imaginary unit of [values] (`i` by default); mixing `i` and `j` → `#VALUE!`.
String _unitOf(Iterable<_C> values) {
  String? unit;
  for (final c in values) {
    final u = c.unit;
    if (u == null) continue;
    if (unit != null && unit != u) {
      fail(
        ErrorKind.value,
        'Complex numbers use different imaginary units (i and j).',
      );
    }
    unit = u;
  }
  return unit ?? 'i';
}

String _num(double x) => Numeric.toText(Numeric.stabilize(x));

/// Formats a complex number as text (`3+4i`, `-i`, `2`, `0`).
String _text(double re, double im, String unit) {
  if (!re.isFinite || !im.isFinite) fail(ErrorKind.num);
  re = Numeric.stabilize(re);
  im = Numeric.stabilize(im);
  final coefficient = switch (im) {
    1 => '',
    -1 => '-',
    _ => _num(im),
  };
  if (im == 0) return _num(re);
  if (re == 0) return '$coefficient$unit';
  return '${_num(re)}${im > 0 ? '+' : ''}$coefficient$unit';
}

FValue _result(_C c, String unit) => FText(_text(c.re, c.im, unit));

ArgSpec _z([String name = 'number']) => P.scalar(
  name,
  'A complex number as text in the form "x+yi" or "x+yj" (a real number is also accepted).',
);

/// Complex numbers (05 §15.13): COMPLEX and the IM* family. Complex values are text.
void registerComplex(FunctionRegistryBuilder b) {
  b.fn(
    'COMPLEX',
    'Creates a complex number given real and imaginary coefficients.',
    [
      P.num('real_part', 'The real coefficient.'),
      P.num('imaginary_part', 'The imaginary coefficient.'),
      P.text(
        'suffix',
        'The suffix for the imaginary coefficient: "i" or "j".',
        true,
        'i',
      ),
    ],
    (a) {
      final re = a.number(0), im = a.number(1);
      final suffix = a.textOr(2, 'i');
      if (suffix != 'i' && suffix != 'j' && suffix.isNotEmpty) {
        fail(
          ErrorKind.value,
          'Function COMPLEX parameter 3 must be "i" or "j".',
        );
      }
      return FText(_text(re, im, suffix.isEmpty ? 'i' : suffix));
    },
    priority: Priority.p2,
    examples: ['COMPLEX(3, 4)', 'COMPLEX(3, 4, "j")'],
    seeAlso: ['IMREAL', 'IMAGINARY'],
  );

  // ---- complex → real
  void real(
    String name,
    String summary,
    double Function(_C z) f, {
    String? example,
  }) {
    b.fn(
      name,
      summary,
      [_z()],
      (a) => stableResult(f(_arg(a, 0))),
      priority: Priority.p2,
      examples: [example ?? '$name("3+4i")'],
      seeAlso: ['COMPLEX'],
    );
  }

  real(
    'IMREAL',
    'Returns the real coefficient of a complex number.',
    (z) => z.re,
  );
  real(
    'IMAGINARY',
    'Returns the imaginary coefficient of a complex number.',
    (z) => z.im,
  );
  real(
    'IMABS',
    'Returns the absolute value (modulus) of a complex number.',
    (z) => z.abs,
  );
  b.fn(
    'IMARGUMENT',
    'The IMARGUMENT function returns the angle (also known as the argument or θ) of the given complex number in radians.',
    [_z()],
    (a) {
      final z = _arg(a, 0);
      if (z.isZero) fail(ErrorKind.div0, 'The argument of zero is undefined.');
      return stableResult(z.arg);
    },
    priority: Priority.p2,
    examples: ['IMARGUMENT("3+4i")'],
    seeAlso: ['IMABS'],
  );

  // ---- complex → complex
  void unary(
    String name,
    String summary,
    _C Function(_C z) f, {
    String? example,
  }) {
    b.fn(
      name,
      summary,
      [_z()],
      (a) {
        final z = _arg(a, 0);
        return _result(f(z), z.unit ?? 'i');
      },
      priority: Priority.p2,
      examples: [example ?? '$name("3+4i")'],
      seeAlso: ['COMPLEX'],
    );
  }

  unary(
    'IMCONJUGATE',
    'Returns the complex conjugate of a number.',
    (z) => _C(z.re, -z.im),
  );
  unary(
    'IMEXP',
    "Returns Euler's number, e (~2.718) raised to a complex power.",
    _exp,
  );
  unary(
    'IMLN',
    'Returns the logarithm of a complex number, base e (Euler\'s number).',
    _ln,
  );
  unary(
    'IMLOG10',
    'The IMLOG10 function returns the logarithm of a complex number with base 10.',
    (z) {
      final l = _ln(z);
      return _C(l.re / math.ln10, l.im / math.ln10);
    },
  );
  unary(
    'IMLOG2',
    'The IMLOG2 function returns the logarithm of a complex number with base 2.',
    (z) {
      final l = _ln(z);
      return _C(l.re / math.ln2, l.im / math.ln2);
    },
  );
  unary(
    'IMSQRT',
    'Computes the square root of a complex number.',
    _sqrt,
    example: 'IMSQRT("-4")',
  );
  unary('IMSIN', 'Returns the sine of the given complex number.', _sin);
  unary(
    'IMCOS',
    'The IMCOS function returns the cosine of the given complex number.',
    _cos,
  );
  unary(
    'IMTAN',
    'The IMTAN function returns the tangent of the given complex number.',
    _tan,
  );
  unary(
    'IMCOT',
    'The IMCOT function returns the cotangent of the given complex number.',
    _cot,
  );
  unary(
    'IMSEC',
    'The IMSEC function returns the secant of the given complex number.',
    (z) => _cos(z).reciprocal,
  );
  unary(
    'IMCSC',
    'The IMCSC function returns the cosecant of the given complex number.',
    (z) => _sin(z).reciprocal,
  );
  unary(
    'IMSINH',
    'The IMSINH function returns the hyperbolic sine of the given complex number.',
    _sinhC,
  );
  unary(
    'IMCOSH',
    'The IMCOSH function returns the hyperbolic cosine of the given complex number.',
    _coshC,
  );
  unary(
    'IMTANH',
    'The IMTANH function returns the hyperbolic tangent of the given complex number.',
    _tanhC,
  );
  unary(
    'IMCOTH',
    'The IMCOTH function returns the hyperbolic cotangent of the given complex number.',
    _cothC,
  );
  unary(
    'IMSECH',
    'The IMSECH function returns the hyperbolic secant of the given complex number.',
    (z) => _coshC(z).reciprocal,
  );
  unary(
    'IMCSCH',
    'The IMCSCH function returns the hyperbolic cosecant of the given complex number.',
    (z) => _sinhC(z).reciprocal,
  );

  b.fn(
    'IMLOG',
    'Returns the logarithm of a complex number for a specified base.',
    [
      _z('value'),
      P.num(
        'base',
        'The base to use when calculating the logarithm, a positive real number.',
      ),
    ],
    (a) {
      final z = _arg(a, 0);
      final base = a.number(1);
      if (base <= 0 || base == 1) {
        fail(ErrorKind.num, 'The base must be positive and not 1.');
      }
      final l = _ln(z), lb = math.log(base);
      return _result(_C(l.re / lb, l.im / lb), z.unit ?? 'i');
    },
    priority: Priority.p2,
    examples: ['IMLOG("42+2i", 4)'],
    seeAlso: ['IMLN', 'IMLOG10', 'IMLOG2'],
  );
  b.fn(
    'IMPOWER',
    'Returns a complex number raised to a power.',
    [
      _z('complex_base'),
      P.num('exponent', 'The real exponent to raise the complex base to.'),
    ],
    (a) {
      final z = _arg(a, 0);
      return _result(_power(z, a.number(1)), z.unit ?? 'i');
    },
    priority: Priority.p2,
    examples: ['IMPOWER("2+3i", 3)'],
    seeAlso: ['IMSQRT', 'IMEXP'],
  );

  // ---- binary
  b.fn(
    'IMDIV',
    'Returns one complex number divided by another.',
    [_z('dividend'), _z('divisor')],
    (a) {
      final x = _arg(a, 0), y = _arg(a, 1);
      return _result(x / y, _unitOf([x, y]));
    },
    priority: Priority.p2,
    examples: ['IMDIV("-238+240i", "10+24i")'],
    seeAlso: ['IMPRODUCT'],
  );
  b.fn(
    'IMSUB',
    'Returns the difference between two complex numbers.',
    [_z('first_number'), _z('second_number')],
    (a) {
      final x = _arg(a, 0), y = _arg(a, 1);
      return _result(x - y, _unitOf([x, y]));
    },
    priority: Priority.p2,
    examples: ['IMSUB("13+4i", "5+3i")'],
    seeAlso: ['IMSUM'],
  );

  // ---- variadic (ranges accepted)
  List<_C> collect(Args a) {
    final out = <_C>[];
    for (var i = 0; i < a.length; i++) {
      if (a[i] is FOmitted) continue;
      a.forEach(i, (v) {
        if (v is FRich) v = v.scalar;
        if (v is FEmpty) return;
        out.add(_of(v));
      });
    }
    return out;
  }

  b.fn(
    'IMSUM',
    'Returns the sum of a series of complex numbers.',
    [
      P.range(
        'value1',
        'The first complex number (or range of complex numbers) to add.',
      ),
      P.rep('value2', ArgKind.range, 'More complex numbers or ranges to add.'),
    ],
    (a) {
      final values = collect(a);
      var acc = const _C(0);
      for (final c in values) {
        acc = acc + c;
      }
      return _result(acc, _unitOf(values));
    },
    priority: Priority.p2,
    examples: ['IMSUM("3+4i", "5-3i")', 'IMSUM(A1:A5)'],
    seeAlso: ['IMSUB', 'IMPRODUCT'],
  );
  b.fn(
    'IMPRODUCT',
    'Returns the result of multiplying a series of complex numbers together.',
    [
      P.range(
        'factor1',
        'The first complex number (or range of complex numbers) to multiply.',
      ),
      P.rep(
        'factor2',
        ArgKind.range,
        'More complex numbers or ranges to multiply.',
      ),
    ],
    (a) {
      final values = collect(a);
      var acc = const _C(1);
      for (final c in values) {
        acc = acc * c;
      }
      return _result(acc, _unitOf(values));
    },
    priority: Priority.p2,
    examples: ['IMPRODUCT("3+4i", "5-3i")', 'IMPRODUCT(A1:A5)'],
    seeAlso: ['IMDIV', 'IMSUM'],
  );
}
