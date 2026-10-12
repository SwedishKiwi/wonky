import 'dart:math' as math;

import '../../eval/eval_context.dart';
import '../../values/errors.dart';

/// Numerical kernels of the statistical functions (05 §15.2): erf/erfc (Cody), Φ⁻¹ (Wichura
/// AS241), lnΓ (Lanczos g=7), regularized incomplete gamma (series + Lentz continued fraction)
/// and beta (Lentz), and a bracketed Newton/bisection solver for inverse distributions.
abstract final class Special {
  static const double _sqrt2 = 1.4142135623730951;
  static const double _sqrtPi = 1.7724538509055160;
  static const double _ln2Pi = 1.8378770664093453;
  static const double _invSqrt2Pi = 0.3989422804014327;
  static const double _eps = 1e-16;
  static const double _tiny = 1e-300;

  // ------------------------------------------------------------------ erf / erfc (Cody)

  static const List<double> _a = [
    3.16112374387056560e00,
    1.13864154151050156e02,
    3.77485237685302021e02,
    3.20937758913846947e03,
    1.85777706184603153e-1,
  ];
  static const List<double> _b = [
    2.36012909523441209e01,
    2.44024637934444173e02,
    1.28261652607737228e03,
    2.84423683343917062e03,
  ];
  static const List<double> _c = [
    5.64188496988670089e-1,
    8.88314979438837594e00,
    6.61191906371416295e01,
    2.98635138197400131e02,
    8.81952221241769090e02,
    1.71204761263407058e03,
    2.05107837782607147e03,
    1.23033935479799725e03,
    2.15311535474403846e-8,
  ];
  static const List<double> _d = [
    1.57449261107098347e01,
    1.17693950891312499e02,
    5.37181101862009858e02,
    1.62138957456669019e03,
    3.29079923573345963e03,
    4.36261909014324716e03,
    3.43936767414372164e03,
    1.23033935480374942e03,
  ];
  static const List<double> _p = [
    3.05326634961232344e-1,
    3.60344899949804439e-1,
    1.25781726111229246e-1,
    1.60837851487422766e-2,
    6.58749161529837803e-4,
    1.63153871373020978e-2,
  ];
  static const List<double> _q = [
    2.56852019228982242e00,
    1.87295284992346725e00,
    5.27905102951428412e-1,
    6.05183413124413191e-2,
    2.33520497626869185e-3,
  ];

  /// erfc(|x|) for |x| > 0.46875 (Cody, CALERF).
  static double _erfcPos(double y) {
    double r;
    if (y <= 4) {
      var num = _c[8] * y, den = y;
      for (var i = 0; i < 7; i++) {
        num = (num + _c[i]) * y;
        den = (den + _d[i]) * y;
      }
      r = (num + _c[7]) / (den + _d[7]);
    } else {
      if (y >= 26.55) return 0;
      final z = 1 / (y * y);
      var num = _p[5] * z, den = z;
      for (var i = 0; i < 4; i++) {
        num = (num + _p[i]) * z;
        den = (den + _q[i]) * z;
      }
      r = z * (num + _p[4]) / (den + _q[4]);
      r = (1 / _sqrtPi - r) / y;
    }
    final ysq = (y * 16).truncateToDouble() / 16;
    final del = (y - ysq) * (y + ysq);
    return math.exp(-ysq * ysq) * math.exp(-del) * r;
  }

  static double _erfSmall(double x) {
    final z = x * x;
    var num = _a[4] * z, den = z;
    for (var i = 0; i < 3; i++) {
      num = (num + _a[i]) * z;
      den = (den + _b[i]) * z;
    }
    return x * (num + _a[3]) / (den + _b[3]);
  }

  /// Error function.
  static double erf(double x) {
    final y = x.abs();
    if (y <= 0.46875) return _erfSmall(x);
    final r = 1 - _erfcPos(y);
    return x < 0 ? -r : r;
  }

  /// Complementary error function.
  static double erfc(double x) {
    final y = x.abs();
    if (y <= 0.46875) return 1 - _erfSmall(x);
    final r = _erfcPos(y);
    return x < 0 ? 2 - r : r;
  }

  // ------------------------------------------------------------------ normal

  /// Standard normal density φ(x).
  static double normPdf(double x) => _invSqrt2Pi * math.exp(-0.5 * x * x);

  /// Standard normal CDF Φ(x).
  static double normCdf(double x) => 0.5 * erfc(-x / _sqrt2);

  static double _poly(List<double> c, double x) {
    var r = 0.0;
    for (var i = c.length - 1; i >= 0; i--) {
      r = r * x + c[i];
    }
    return r;
  }

  static const List<double> _asA = [
    3.3871328727963666080e0,
    1.3314166789178437745e+2,
    1.9715909503065514427e+3,
    1.3731693765509461125e+4,
    4.5921953931549871457e+4,
    6.7265770927008700853e+4,
    3.3430575583588128105e+4,
    2.5090809287301226727e+3,
  ];
  static const List<double> _asB = [
    1.0,
    4.2313330701600911252e+1,
    6.8718700749205790830e+2,
    5.3941960214247511077e+3,
    2.1213794301586595867e+4,
    3.9307895800092710610e+4,
    2.8729085735721942674e+4,
    5.2264952788528545610e+3,
  ];
  static const List<double> _asC = [
    1.42343711074968357734e0,
    4.63033784615654529590e0,
    5.76949722146069140550e0,
    3.64784832476320460504e0,
    1.27045825245236838258e0,
    2.41780725177450611770e-1,
    2.27238449892691845833e-2,
    7.74545014278341407640e-4,
  ];
  static const List<double> _asD = [
    1.0,
    2.05319162663775882187e0,
    1.67638483018380384940e0,
    6.89767334985100004550e-1,
    1.48103976427480074590e-1,
    1.51986665636164571966e-2,
    5.47593808499534494600e-4,
    1.05075007164441684324e-9,
  ];
  static const List<double> _asE = [
    6.65790464350110377720e0,
    5.46378491116411436990e0,
    1.78482653991729133580e0,
    2.96560571828504891230e-1,
    2.65321895265761230930e-2,
    1.24266094738807843860e-3,
    2.71155556874348757815e-5,
    2.01033439929228813265e-7,
  ];
  static const List<double> _asF = [
    1.0,
    5.99832206555887937690e-1,
    1.36929880922735805310e-1,
    1.48753612908506148525e-2,
    7.86869131145613259100e-4,
    1.84631831751005468180e-5,
    1.42151175831644588870e-7,
    2.04426310338993978564e-15,
  ];

  /// Inverse standard normal CDF (Wichura AS241, PPND16); p in (0, 1).
  static double normInv(double p) {
    final q = p - 0.5;
    if (q.abs() <= 0.425) {
      final r = 0.180625 - q * q;
      return q * _poly(_asA, r) / _poly(_asB, r);
    }
    var r = q < 0 ? p : 1 - p;
    r = math.sqrt(-math.log(r));
    double v;
    if (r <= 5) {
      r -= 1.6;
      v = _poly(_asC, r) / _poly(_asD, r);
    } else {
      r -= 5;
      v = _poly(_asE, r) / _poly(_asF, r);
    }
    return q < 0 ? -v : v;
  }

  // ------------------------------------------------------------------ gamma

  static const List<double> _lanczos = [
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];

  /// ln|Γ(x)| (Lanczos g=7, reflection for x < 0.5).
  static double lnGamma(double x) {
    if (x < 0.5) {
      final s = math.sin(math.pi * x).abs();
      return math.log(math.pi / s) - lnGamma(1 - x);
    }
    if (x == 1 || x == 2) return 0;
    final z = x - 1;
    var sum = _lanczos[0];
    for (var i = 1; i < 9; i++) {
      sum += _lanczos[i] / (z + i);
    }
    final t = z + 7.5;
    return 0.5 * _ln2Pi + (z + 0.5) * math.log(t) - t + math.log(sum);
  }

  static final List<double> _fact = () {
    final f = <double>[1];
    for (var i = 1; i <= 170; i++) {
      f.add(f[i - 1] * i);
    }
    return f;
  }();

  /// n! for 0 ≤ n ≤ 170 (∞ above).
  static double factorial(int n) => n <= 170 ? _fact[n] : double.infinity;

  /// ln(n!) (exact table for n ≤ 170).
  static double lnFactorial(double n) {
    if (n <= 170 && n == n.truncateToDouble()) {
      return math.log(_fact[n.toInt()]);
    }
    return lnGamma(n + 1);
  }

  /// ln C(n, k).
  static double lnCombin(double n, double k) =>
      lnFactorial(n) - lnFactorial(k) - lnFactorial(n - k);

  /// Γ(x); NaN at poles (0, negative integers).
  static double gamma(double x) {
    if (x == x.truncateToDouble()) {
      if (x <= 0) return double.nan;
      if (x <= 171) return _fact[x.toInt() - 1];
      return double.infinity;
    }
    if (x < 0.5) return math.pi / (math.sin(math.pi * x) * gamma(1 - x));
    if (x > 171.7) return double.infinity;
    final z = x - 1;
    var sum = _lanczos[0];
    for (var i = 1; i < 9; i++) {
      sum += _lanczos[i] / (z + i);
    }
    final t = z + 7.5;
    // split the power to avoid overflow for x near 171
    final h = math.pow(t, (z + 0.5) / 2).toDouble();
    return math.sqrt(2 * math.pi) * h * (h * math.exp(-t)) * sum;
  }

  /// ln B(a, b).
  static double lnBeta(double a, double b) =>
      lnGamma(a) + lnGamma(b) - lnGamma(a + b);

  /// Regularized lower incomplete gamma P(a, x).
  static double gammaP(double a, double x) {
    if (x <= 0) return 0;
    if (x.isInfinite) return 1;
    if (x < a + 1) return _gammaSeries(a, x);
    return 1 - _gammaCf(a, x);
  }

  /// Regularized upper incomplete gamma Q(a, x).
  static double gammaQ(double a, double x) {
    if (x <= 0) return 1;
    if (x.isInfinite) return 0;
    if (x < a + 1) return 1 - _gammaSeries(a, x);
    return _gammaCf(a, x);
  }

  static double _gammaPrefix(double a, double x) =>
      math.exp(-x + a * math.log(x) - lnGamma(a));

  static double _gammaSeries(double a, double x) {
    var ap = a, sum = 1 / a, del = sum;
    for (var n = 0; n < 100000; n++) {
      ap += 1;
      del *= x / ap;
      sum += del;
      if (del.abs() < sum.abs() * _eps) return sum * _gammaPrefix(a, x);
    }
    fail(ErrorKind.num);
  }

  static double _gammaCf(double a, double x) {
    var b = x + 1 - a, c = 1 / _tiny, d = 1 / b, h = d;
    for (var i = 1; i < 100000; i++) {
      final an = -i * (i - a);
      b += 2;
      d = an * d + b;
      if (d.abs() < _tiny) d = _tiny;
      c = b + an / c;
      if (c.abs() < _tiny) c = _tiny;
      d = 1 / d;
      final del = d * c;
      h *= del;
      if ((del - 1).abs() < _eps) return _gammaPrefix(a, x) * h;
    }
    fail(ErrorKind.num);
  }

  /// Regularized incomplete beta I_x(a, b).
  static double betaI(double x, double a, double b) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    final lnFront = a * math.log(x) + b * math.log(1 - x) - lnBeta(a, b);
    if (x < (a + 1) / (a + b + 2)) {
      return math.exp(lnFront) * _betaCf(x, a, b) / a;
    }
    return 1 - math.exp(lnFront) * _betaCf(1 - x, b, a) / b;
  }

  /// 1 − I_x(a, b) without cancellation.
  static double betaIc(double x, double a, double b) => betaI(1 - x, b, a);

  static double _betaCf(double x, double a, double b) {
    final qab = a + b, qap = a + 1, qam = a - 1;
    var c = 1.0, d = 1 - qab * x / qap;
    if (d.abs() < _tiny) d = _tiny;
    d = 1 / d;
    var h = d;
    for (var m = 1; m < 100000; m++) {
      final m2 = 2 * m;
      var aa = m * (b - m) * x / ((qam + m2) * (a + m2));
      d = 1 + aa * d;
      if (d.abs() < _tiny) d = _tiny;
      c = 1 + aa / c;
      if (c.abs() < _tiny) c = _tiny;
      d = 1 / d;
      h *= d * c;
      aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
      d = 1 + aa * d;
      if (d.abs() < _tiny) d = _tiny;
      c = 1 + aa / c;
      if (c.abs() < _tiny) c = _tiny;
      d = 1 / d;
      final del = d * c;
      h *= del;
      if ((del - 1).abs() < _eps) return h;
    }
    fail(ErrorKind.num);
  }

  // ------------------------------------------------------------------ distributions

  /// Student t CDF.
  static double tCdf(double t, double df) {
    final tail = 0.5 * betaI(df / (df + t * t), df / 2, 0.5);
    return t > 0 ? 1 - tail : tail;
  }

  /// Student t upper tail P(T > t).
  static double tSf(double t, double df) {
    final tail = 0.5 * betaI(df / (df + t * t), df / 2, 0.5);
    return t > 0 ? tail : 1 - tail;
  }

  static double tPdf(double t, double df) => math.exp(
    lnGamma((df + 1) / 2) -
        lnGamma(df / 2) -
        0.5 * math.log(df * math.pi) -
        (df + 1) / 2 * math.log(1 + t * t / df),
  );

  /// Upper t quantile: t ≥ 0 with P(T > t) = p, p in (0, 0.5].
  static double tInvUpper(double p, double df) {
    if (p == 0.5) return 0;
    final guess = math.max(-normInv(p), 1e-3);
    return solve(
      (x) => tSf(x, df),
      p,
      0,
      math.max(1, guess * 2),
      decreasing: true,
      pdf: (x) => tPdf(x, df),
      guess: guess,
      openHi: true,
      positive: true,
    );
  }

  static double chiPdf(double x, double k) {
    if (x < 0) return 0;
    if (x == 0) {
      if (k == 2) return 0.5;
      return k < 2 ? double.infinity : 0;
    }
    return math.exp(
      (k / 2 - 1) * math.log(x) - x / 2 - (k / 2) * math.ln2 - lnGamma(k / 2),
    );
  }

  static double gammaPdf(double x, double a, double b) {
    if (x < 0) return 0;
    if (x == 0) {
      if (a == 1) return 1 / b;
      return a < 1 ? double.infinity : 0;
    }
    return math.exp(
      (a - 1) * math.log(x) - x / b - lnGamma(a) - a * math.log(b),
    );
  }

  /// Inverse of the gamma CDF with shape [a] and scale [b] (lower tail [p], or upper tail when
  /// [upper]).
  static double gammaInv(double p, double a, double b, {bool upper = false}) {
    final mean = a * b;
    // Wilson–Hilferty start, or the small-x expansion P(a, x) ≈ xᵃ / Γ(a + 1).
    final z = upper ? -normInv(p) : normInv(p);
    final c = 1 - 1 / (9 * a) + z / (3 * math.sqrt(a));
    var guess = a * c * c * c * b;
    if (!upper && (a < 1 || c <= 0)) {
      final small = b * math.exp((math.log(p) + lnGamma(a + 1)) / a);
      if (c <= 0 || small < mean) guess = small;
    }
    return solve(
      upper ? (x) => gammaQ(a, x / b) : (x) => gammaP(a, x / b),
      p,
      0,
      math.max(mean * 2, math.max(guess * 2, b)),
      decreasing: upper,
      pdf: (x) => gammaPdf(x, a, b),
      guess: guess.isFinite && guess > 0 ? guess : mean,
      openHi: true,
      positive: true,
    );
  }

  static double fPdf(double x, double d1, double d2) {
    if (x < 0) return 0;
    if (x == 0) {
      if (d1 == 2) return 1;
      return d1 < 2 ? double.infinity : 0;
    }
    return math.exp(
      0.5 *
              (d1 * math.log(d1 * x) +
                  d2 * math.log(d2) -
                  (d1 + d2) * math.log(d1 * x + d2)) -
          math.log(x) -
          lnBeta(d1 / 2, d2 / 2),
    );
  }

  static double fCdf(double x, double d1, double d2) =>
      x <= 0 ? 0 : betaI(d1 * x / (d1 * x + d2), d1 / 2, d2 / 2);

  static double fSf(double x, double d1, double d2) =>
      x <= 0 ? 1 : betaI(d2 / (d2 + d1 * x), d2 / 2, d1 / 2);

  static double fInv(double p, double d1, double d2, {bool upper = false}) {
    return solve(
      upper ? (x) => fSf(x, d1, d2) : (x) => fCdf(x, d1, d2),
      p,
      0,
      2,
      decreasing: upper,
      pdf: (x) => fPdf(x, d1, d2),
      guess: 1,
      openHi: true,
      positive: true,
    );
  }

  static double betaPdf(double x, double a, double b) {
    if (x < 0 || x > 1) return 0;
    if (x == 0) {
      if (a == 1) return b;
      return a < 1 ? double.infinity : 0;
    }
    if (x == 1) {
      if (b == 1) return a;
      return b < 1 ? double.infinity : 0;
    }
    return math.exp(
      (a - 1) * math.log(x) + (b - 1) * math.log(1 - x) - lnBeta(a, b),
    );
  }

  static double betaInv(double p, double a, double b) {
    if (p <= 0) return 0;
    if (p >= 1) return 1;
    // Start from the tail expansions I_x(a, b) ≈ xᵃ / (a·B(a, b)) near 0 (and mirrored near 1).
    final mean = a / (a + b);
    final lb = lnBeta(a, b);
    final low = math.exp((math.log(p) + math.log(a) + lb) / a);
    final high = 1 - math.exp((math.log(1 - p) + math.log(b) + lb) / b);
    final guess = low < mean ? low : (high > mean ? high : mean);
    return solve(
      (x) => betaI(x, a, b),
      p,
      0,
      1,
      pdf: (x) => betaPdf(x, a, b),
      guess: guess,
      positive: true,
    );
  }

  // ------------------------------------------------------------------ solver

  /// Solves `f(x) = target` for monotone [f] (increasing, or [decreasing]) in [lo, hi] by
  /// bracketed Newton (using [pdf] = |f'|) with bisection fallback. [openHi] expands the
  /// upper bound until it brackets the root; [positive] bisects geometrically on (0, hi]. Max 100 iterations, tolerance 1e-12 relative;
  /// otherwise `#NUM!`.
  static double solve(
    double Function(double x) f,
    double target,
    double lo,
    double hi, {
    bool decreasing = false,
    double Function(double x)? pdf,
    double? guess,
    bool openHi = false,
    bool positive = false,
  }) {
    final s = decreasing ? -1.0 : 1.0;
    double g(double x) => s * (f(x) - target);
    if (openHi) {
      var n = 0;
      while (g(hi) < 0) {
        lo = hi;
        hi = hi <= 0 ? 1 : hi * 2;
        if (++n > 2000 || hi.isInfinite) fail(ErrorKind.num);
      }
    }
    var x = guess != null && guess > lo && guess < hi ? guess : (lo + hi) / 2;
    for (var i = 0; i < 100; i++) {
      final gx = g(x);
      if (gx == 0) return x;
      if (gx < 0) {
        lo = x;
      } else {
        hi = x;
      }
      var next = (lo + hi) / 2;
      if (positive && (lo <= 0 || hi / lo > 16)) {
        // geometric bisection for roots spanning many orders of magnitude
        next = lo <= 0 ? hi / 1024 : math.sqrt(lo * hi);
      }
      if (pdf != null) {
        final d = pdf(x);
        if (d > 0 && d.isFinite) {
          final n = x - gx / d;
          if (n > lo && n < hi) next = n;
        }
      }
      final scale = math.max(next.abs(), 1e-300);
      if ((next - x).abs() <= 1e-12 * scale || (hi - lo) <= 1e-15 * scale) {
        return next;
      }
      x = next;
    }
    fail(ErrorKind.num);
  }
}
