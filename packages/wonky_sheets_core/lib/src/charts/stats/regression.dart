import 'dart:math' as math;
import 'dart:typed_data';

import 'least_squares.dart';
import 'stat_number_format.dart';

/// Trendline model types (specs/wonky_sheets/08-charts-and-objects.md §7).
enum RegressionKind { linear, exponential, polynomial, logarithmic, power, movingAverage }

/// A fitted trendline model.
final class RegressionResult {
  /// Creates a result from coefficients in the layout documented on [coefficients].
  ///
  /// [degree] defaults to `coefficients.length − 1` for polynomials and 1 otherwise.
  RegressionResult({
    required this.kind,
    required this.coefficients,
    this.r2,
    required this.pointCount,
    this.skippedCount = 0,
    int? degree,
  }) : degree = degree ?? (kind == RegressionKind.polynomial ? coefficients.length - 1 : 1),
       _tCoefficients = null,
       _center = 0,
       _scale = 1,
       _termScale = 1 {
    if (kind == RegressionKind.movingAverage) {
      throw ArgumentError.value(kind, 'kind', 'moving averages have no regression result');
    }
    final expected = kind == RegressionKind.polynomial ? this.degree + 1 : 2;
    if (coefficients.length != expected) {
      throw ArgumentError.value(coefficients.length, 'coefficients', 'expected $expected');
    }
  }

  RegressionResult._(
    this.kind,
    this.coefficients,
    this.r2,
    this.pointCount,
    this.skippedCount,
    this.degree, {
    this._tCoefficients,
    this._center = 0,
    this._scale = 1,
    this._termScale = 1,
  });

  final RegressionKind kind;

  /// Model coefficients:
  /// linear: `[b, m]` for y = m·x + b; polynomial: `[c0, c1, …, cd]` for y = Σ cᵢxⁱ;
  /// exponential: `[a, b]` for y = a·e^(b·x); logarithmic: `[a, b]` for y = a·ln x + b;
  /// power: `[a, b]` for y = a·x^b.
  final Float64List coefficients;

  /// Coefficient of determination; original scale for linear and polynomial, transformed
  /// scale for exponential (ln y), logarithmic (ln x) and power (ln x, ln y). When the total
  /// sum of squares is 0 it is 1 if the fit is exact and 0 otherwise.
  final double? r2;

  /// Number of valid points used for the fit.
  final int pointCount;

  /// Number of points skipped (NaN / non-finite, or invalid for the model such as y ≤ 0 for
  /// exponential, x ≤ 0 for logarithmic).
  final int skippedCount;

  /// Polynomial degree actually used (1 for the other kinds).
  final int degree;

  // Polynomial in the internal scaled basis t = (x − _center) / _scale, for accurate predict.
  final Float64List? _tCoefficients;
  final double _center;
  final double _scale;

  // Magnitude of the regressor over the fitted range (max |x|, or max |ln x| for
  // logarithmic), used to drop negligible terms from the equation label.
  final double _termScale;

  /// Evaluates the model at [x]. Logarithmic models return NaN for x ≤ 0.
  double predict(double x) {
    final c = coefficients;
    switch (kind) {
      case RegressionKind.linear:
        return c[0] + c[1] * x;
      case RegressionKind.polynomial:
        final tc = _tCoefficients;
        final basis = tc ?? c;
        final t = tc == null ? x : (x - _center) / _scale;
        var v = 0.0;
        for (var i = basis.length - 1; i >= 0; i--) {
          v = v * t + basis[i];
        }
        return v;
      case RegressionKind.exponential:
        return c[0] * math.exp(c[1] * x);
      case RegressionKind.logarithmic:
        return x > 0 ? c[0] * math.log(x) + c[1] : double.nan;
      case RegressionKind.power:
        return c[0] * math.pow(x, c[1]).toDouble();
      case RegressionKind.movingAverage:
        return double.nan;
    }
  }

  /// Relative contribution below which a term is left out of the [equation] label.
  static const double negligibleTermRatio = 1e-12;

  /// Equation label with [significantDigits] significant digits (08 §7), e.g.
  /// `y = 1.234x + 5.678`, `y = 0.5x^2 - 1.2x + 3`, `y = 1.2e^(0.5x)`, `y = 1.2ln(x) + 3`,
  /// `y = 1.2x^0.5`.
  ///
  /// Negative terms are joined with ` - `; zero terms are left out (a lone constant is kept;
  /// all-zero gives `y = 0`), and for linear, polynomial and logarithmic models so are terms
  /// whose magnitude over the fitted x range is below [negligibleTermRatio] of the total
  /// (floating-point noise such as `4.4E-16`). A coefficient that formats as 1 is written as
  /// `x` (not `1x`), −1 as `-x`. Numbers use [StatNumberFormat.format].
  String equation({int significantDigits = 4}) {
    String fmt(double v) => StatNumberFormat.format(v, significantDigits: significantDigits);
    final c = coefficients;
    switch (kind) {
      case RegressionKind.linear:
        return 'y = ${_joinTerms([(c[1], 'x', _termScale), (c[0], '', 1.0)], fmt)}';
      case RegressionKind.polynomial:
        final terms = <(double, String, double)>[
          for (var i = c.length - 1; i >= 0; i--)
            (
              c[i],
              i == 0
                  ? ''
                  : i == 1
                  ? 'x'
                  : 'x^$i',
              math.pow(_termScale, i).toDouble(),
            ),
        ];
        return 'y = ${_joinTerms(terms, fmt)}';
      case RegressionKind.logarithmic:
        return 'y = ${_joinTerms([(c[0], 'ln(x)', _termScale), (c[1], '', 1.0)], fmt)}';
      case RegressionKind.exponential:
        final inner = _joinTerms([(c[1], 'x', 0.0)], fmt);
        if (inner == '0') return 'y = ${fmt(c[0])}';
        return 'y = ${_joinTerms([(c[0], 'e^($inner)', 0.0)], fmt)}';
      case RegressionKind.power:
        if (c[1] == 0) return 'y = ${fmt(c[0])}';
        final exponent = fmt(c[1]);
        final suffix = exponent == '1' ? 'x' : 'x^$exponent';
        return 'y = ${_joinTerms([(c[0], suffix, 0.0)], fmt)}';
      case RegressionKind.movingAverage:
        return '';
    }
  }

  /// `R² = 0.9876` with [significantDigits] significant digits, or null when [r2] is null.
  String? r2Label({int significantDigits = 4}) {
    final v = r2;
    if (v == null) return null;
    return 'R² = ${StatNumberFormat.format(v, significantDigits: significantDigits)}';
  }

  /// Joins `(coefficient, suffix, scale)` terms. A scale of 0 disables negligible-term dropping
  /// for that term; otherwise `|coefficient| · scale` is the term's magnitude.
  static String _joinTerms(List<(double, String, double)> terms, String Function(double) fmt) {
    var total = 0.0;
    var snapping = true;
    for (final (c, _, scale) in terms) {
      if (scale == 0) continue;
      final m = c.abs() * scale;
      if (!m.isFinite) snapping = false;
      total += m;
    }
    final out = StringBuffer();
    var first = true;
    for (final (c, suffix, scale) in terms) {
      if (c == 0) continue;
      if (snapping && scale != 0 && c.abs() * scale <= negligibleTermRatio * total) continue;
      final magnitude = fmt(c.abs());
      final coefText = suffix.isNotEmpty && magnitude == '1' ? '' : magnitude;
      final term = '$coefText$suffix';
      if (first) {
        out.write(c < 0 ? '-$term' : term);
        first = false;
      } else {
        out.write(c < 0 ? ' - $term' : ' + $term');
      }
    }
    return first ? '0' : out.toString();
  }

  @override
  String toString() => 'RegressionResult(${kind.name}, $coefficients, r2: $r2)';
}

/// Trendline regressions over `Float64List` series (NaN or non-finite = missing, skipped).
///
/// x and y must have the same length; a mismatch throws [ArgumentError].
abstract final class Regression {
  /// Highest supported polynomial degree.
  static const int maxPolynomialDegree = 10;

  /// Ordinary least squares y = m·x + b (two-pass centered sums). Null with fewer than two
  /// valid points or when all x are equal.
  static RegressionResult? linear(Float64List x, Float64List y) {
    final p = _Points.collect(x, y, _validAll);
    final line = _Line.fit(p.xs, p.ys, p.n);
    if (line == null) return null;
    return RegressionResult._(
      RegressionKind.linear,
      Float64List.fromList([line.intercept, line.slope]),
      line.r2,
      p.n,
      p.skipped,
      1,
      termScale: p.maxAbsX,
    );
  }

  /// y = a·e^(b·x), fitted by OLS on (x, ln y); points with y ≤ 0 are skipped. R² is on the
  /// ln y scale.
  static RegressionResult? exponential(Float64List x, Float64List y) {
    final p = _Points.collect(x, y, _validPositiveY);
    _logInPlace(p.ys, p.n);
    final line = _Line.fit(p.xs, p.ys, p.n);
    if (line == null) return null;
    return RegressionResult._(
      RegressionKind.exponential,
      Float64List.fromList([math.exp(line.intercept), line.slope]),
      line.r2,
      p.n,
      p.skipped,
      1,
    );
  }

  /// y = a·ln x + b, fitted by OLS on (ln x, y); points with x ≤ 0 are skipped. R² is on the
  /// ln x scale (the same value as the original y scale, since y is not transformed).
  static RegressionResult? logarithmic(Float64List x, Float64List y) {
    final p = _Points.collect(x, y, _validPositiveX);
    _logInPlace(p.xs, p.n);
    final line = _Line.fit(p.xs, p.ys, p.n);
    if (line == null) return null;
    var maxAbs = 0.0;
    for (var i = 0; i < p.n; i++) {
      maxAbs = math.max(maxAbs, p.xs[i].abs());
    }
    return RegressionResult._(
      RegressionKind.logarithmic,
      Float64List.fromList([line.slope, line.intercept]),
      line.r2,
      p.n,
      p.skipped,
      1,
      termScale: maxAbs,
    );
  }

  /// y = a·x^b, fitted by OLS on (ln x, ln y); points with x ≤ 0 or y ≤ 0 are skipped. R² is
  /// on the (ln x, ln y) scale.
  static RegressionResult? power(Float64List x, Float64List y) {
    final p = _Points.collect(x, y, _validPositiveXY);
    _logInPlace(p.xs, p.n);
    _logInPlace(p.ys, p.n);
    final line = _Line.fit(p.xs, p.ys, p.n);
    if (line == null) return null;
    return RegressionResult._(
      RegressionKind.power,
      Float64List.fromList([math.exp(line.intercept), line.slope]),
      line.r2,
      p.n,
      p.skipped,
      1,
    );
  }

  /// Polynomial y = Σ cᵢxⁱ by least squares (Householder QR on the Vandermonde matrix of the
  /// internally centered and scaled x; coefficients are returned in the original x basis).
  ///
  /// The degree used is `min(degree, 10, distinctX − 1)`, so it never exceeds n − 1. Null when
  /// fewer than two valid points or fewer than two distinct x values remain. [degree] must be
  /// ≥ 1.
  static RegressionResult? polynomial(Float64List x, Float64List y, int degree) {
    if (degree < 1) throw RangeError.range(degree, 1, maxPolynomialDegree, 'degree');
    final p = _Points.collect(x, y, _validAll);
    final n = p.n;
    if (n < 2) return null;
    final sorted = Float64List.sublistView(p.xs, 0, n).toList()..sort();
    var distinct = 1;
    for (var i = 1; i < n; i++) {
      if (sorted[i] != sorted[i - 1]) distinct++;
    }
    final d = math.min(math.min(degree, maxPolynomialDegree), distinct - 1);
    if (d < 1) return null;
    final lo = sorted.first;
    final hi = sorted.last;
    final center = lo / 2 + hi / 2;
    final scale = hi / 2 - lo / 2;
    final columns = List<Float64List>.generate(d, (_) => Float64List(n));
    for (var i = 0; i < n; i++) {
      final t = (p.xs[i] - center) / scale;
      var power = t;
      for (var k = 0; k < d; k++) {
        columns[k][i] = power;
        power *= t;
      }
    }
    final fit = LeastSquares.fit(columns, Float64List.sublistView(p.ys, 0, n))!;
    final tCoef = Float64List(d + 1);
    tCoef[0] = fit.intercept;
    for (var k = 0; k < d; k++) {
      tCoef[k + 1] = fit.coefficients[k];
    }
    // Convert p(t), t = (x − c)/s, to the x basis: q(u) = Σ (aₖ/sᵏ)uᵏ with u = x − c, then a
    // Taylor shift by c (Horner: r ← r·(x − c) + qₖ).
    final q = Float64List(d + 1);
    var sk = 1.0;
    for (var k = 0; k <= d; k++) {
      q[k] = tCoef[k] / sk;
      sk *= scale;
    }
    final r = Float64List(d + 1);
    for (var k = d; k >= 0; k--) {
      for (var i = d; i >= 1; i--) {
        r[i] = r[i - 1] - center * r[i];
      }
      r[0] = -center * r[0] + q[k];
    }
    return RegressionResult._(
      RegressionKind.polynomial,
      r,
      fit.r2,
      n,
      p.skipped,
      d,
      tCoefficients: tCoef,
      center: center,
      scale: scale,
      termScale: math.max(lo.abs(), hi.abs()),
    );
  }

  /// Trailing moving average: `out[i] = mean(y[i−period+1 .. i])` for i ≥ period − 1 and NaN
  /// before. A window containing a NaN (or non-finite) input yields NaN. [period] must be ≥ 1;
  /// a period longer than the series gives all NaN.
  static Float64List movingAverage(Float64List y, int period) {
    if (period < 1) throw RangeError.value(period, 'period', 'must be at least 1');
    final n = y.length;
    final out = Float64List(n)..fillRange(0, n, double.nan);
    if (period > n) return out;
    var sum = 0.0;
    var missing = 0;
    for (var i = 0; i < n; i++) {
      if ((i + 1) % period == 0) {
        // Recompute the window from scratch once per period to stop drift (O(n) overall).
        sum = 0;
        missing = 0;
        for (var j = i - period + 1; j <= i; j++) {
          final v = y[j];
          if (v.isFinite) {
            sum += v;
          } else {
            missing++;
          }
        }
      } else {
        final v = y[i];
        if (v.isFinite) {
          sum += v;
        } else {
          missing++;
        }
        if (i >= period) {
          final old = y[i - period];
          if (old.isFinite) {
            sum -= old;
          } else {
            missing--;
          }
        }
      }
      if (i >= period - 1) out[i] = missing > 0 ? double.nan : sum / period;
    }
    return out;
  }

  /// Fits [kind] ([degree] for polynomials). Returns null for [RegressionKind.movingAverage];
  /// use [movingAverage] for that.
  static RegressionResult? fit(
    RegressionKind kind,
    Float64List x,
    Float64List y, {
    int degree = 2,
  }) => switch (kind) {
    RegressionKind.linear => linear(x, y),
    RegressionKind.exponential => exponential(x, y),
    RegressionKind.polynomial => polynomial(x, y, degree),
    RegressionKind.logarithmic => logarithmic(x, y),
    RegressionKind.power => power(x, y),
    RegressionKind.movingAverage => null,
  };

  /// x = 1..n, the domain used for categorical axes (08 §7).
  static Float64List categoricalX(int n) {
    if (n < 0) throw RangeError.value(n, 'n', 'must not be negative');
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      out[i] = i + 1.0;
    }
    return out;
  }

  static bool _validAll(double x, double y) => true;
  static bool _validPositiveY(double x, double y) => y > 0;
  static bool _validPositiveX(double x, double y) => x > 0;
  static bool _validPositiveXY(double x, double y) => x > 0 && y > 0;

  static void _logInPlace(Float64List v, int n) {
    for (var i = 0; i < n; i++) {
      v[i] = math.log(v[i]);
    }
  }
}

/// Valid (finite and model-valid) points copied out of the inputs.
final class _Points {
  _Points(this.xs, this.ys, this.n, this.skipped, this.maxAbsX);

  final Float64List xs;
  final Float64List ys;
  final int n;
  final int skipped;
  final double maxAbsX;

  static _Points collect(Float64List x, Float64List y, bool Function(double, double) valid) {
    if (x.length != y.length) {
      throw ArgumentError.value(y.length, 'y', 'length must equal x.length (${x.length})');
    }
    final total = x.length;
    final xs = Float64List(total);
    final ys = Float64List(total);
    var n = 0;
    var maxAbs = 0.0;
    for (var i = 0; i < total; i++) {
      final xi = x[i];
      final yi = y[i];
      if (!xi.isFinite || !yi.isFinite || !valid(xi, yi)) continue;
      xs[n] = xi;
      ys[n] = yi;
      n++;
      if (xi.abs() > maxAbs) maxAbs = xi.abs();
    }
    return _Points(xs, ys, n, total - n, maxAbs);
  }
}

/// Simple linear OLS with two-pass centered sums.
final class _Line {
  _Line(this.intercept, this.slope, this.r2);

  final double intercept;
  final double slope;
  final double r2;

  static _Line? fit(Float64List xs, Float64List ys, int n) {
    if (n < 2) return null;
    final mx = _mean(xs, n);
    final my = _mean(ys, n);
    var sxx = 0.0;
    var sxy = 0.0;
    var syy = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = xs[i] - mx;
      final dy = ys[i] - my;
      sxx += dx * dx;
      sxy += dx * dy;
      syy += dy * dy;
    }
    if (sxx == 0) return null;
    final m = sxy / sxx;
    final b = my - m * mx;
    var ssRes = 0.0;
    for (var i = 0; i < n; i++) {
      final r = (ys[i] - my) - m * (xs[i] - mx);
      ssRes += r * r;
    }
    final double r2;
    if (syy == 0) {
      r2 = ssRes == 0 ? 1 : 0;
    } else {
      r2 = (1 - ssRes / syy).clamp(0.0, 1.0);
    }
    return _Line(b, m, r2);
  }

  /// Mean with a second-pass correction; exact for constant data.
  static double _mean(Float64List v, int n) {
    var sum = 0.0;
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      final x = v[i];
      sum += x;
      if (x < min) min = x;
      if (x > max) max = x;
    }
    if (min == max) return min;
    final mean = sum / n;
    var correction = 0.0;
    for (var i = 0; i < n; i++) {
      correction += v[i] - mean;
    }
    return mean + correction / n;
  }
}
