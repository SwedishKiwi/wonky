import 'dart:math' as math;

import 'package:test/test.dart';

/// Exact rational number (BigInt numerator / positive denominator), for reference values.
final class Fraction {
  Fraction._(this.num, this.den);

  factory Fraction(BigInt num, [BigInt? den]) {
    var d = den ?? BigInt.one;
    var n = num;
    if (d.isNegative) {
      d = -d;
      n = -n;
    }
    final g = n.gcd(d);
    return g == BigInt.zero || g == BigInt.one ? Fraction._(n, d) : Fraction._(n ~/ g, d ~/ g);
  }

  factory Fraction.int(int v) => Fraction(BigInt.from(v));

  /// The exact value of a finite double.
  factory Fraction.fromDouble(double v) {
    var d = v;
    var k = 0;
    while (d != d.truncateToDouble()) {
      d *= 2;
      k++;
    }
    return Fraction(BigInt.from(d), BigInt.one << k);
  }

  static final zero = Fraction.int(0);
  static final one = Fraction.int(1);

  final BigInt num;
  final BigInt den;

  bool get isZero => num == BigInt.zero;

  Fraction operator +(Fraction o) => Fraction(num * o.den + o.num * den, den * o.den);
  Fraction operator -(Fraction o) => Fraction(num * o.den - o.num * den, den * o.den);
  Fraction operator *(Fraction o) => Fraction(num * o.num, den * o.den);
  Fraction operator /(Fraction o) => Fraction(num * o.den, den * o.num);
  Fraction operator -() => Fraction._(-num, den);

  /// Correctly scaled conversion (no overflow for large numerators and denominators).
  double toDouble() {
    if (isZero) return 0;
    final a = num.abs();
    final shift = den.bitLength - a.bitLength + 64;
    final q = shift >= 0 ? (a << shift) ~/ den : a ~/ (den << -shift);
    final v = q.toDouble() * math.pow(2.0, -shift);
    return num.isNegative ? -v : v;
  }
}

/// LINEST statistics computed with exact rational normal equations (textbook formulas):
/// β = (XᵀX)⁻¹Xᵀy, σ² = SSres/df, se = sqrt(σ²·diag((XᵀX)⁻¹)), SS_tot centered with intercept
/// and uncentered without.
final class ExactLinest {
  ExactLinest._(
    this.coefficients,
    this.intercept,
    this.standardErrors,
    this.interceptStandardError,
    this.r2,
    this.standardErrorY,
    this.fStatistic,
    this.degreesOfFreedom,
    this.ssRegression,
    this.ssResidual,
  );

  /// Requires full column rank and df > 0.
  factory ExactLinest.of(List<List<Fraction>> columns, List<Fraction> y, {bool intercept = true}) {
    final n = y.length;
    final design = [if (intercept) List<Fraction>.filled(n, Fraction.one), ...columns];
    final p = design.length;
    // Normal matrix XᵀX augmented with identity (for the inverse) and Xᵀy.
    final m = List.generate(p, (i) {
      return [
        for (var j = 0; j < p; j++) _dot(design[i], design[j]),
        for (var j = 0; j < p; j++) i == j ? Fraction.one : Fraction.zero,
        _dot(design[i], y),
      ];
    });
    // Gauss–Jordan elimination.
    for (var c = 0; c < p; c++) {
      final pivot = m.indexWhere((row) => !row[c].isZero, c);
      final t = m[c];
      m[c] = m[pivot];
      m[pivot] = t;
      final inv = Fraction.one / m[c][c];
      m[c] = [for (final v in m[c]) v * inv];
      for (var r = 0; r < p; r++) {
        if (r == c || m[r][c].isZero) continue;
        final f = m[r][c];
        m[r] = [for (var k = 0; k < m[r].length; k++) m[r][k] - f * m[c][k]];
      }
    }
    final beta = [for (var i = 0; i < p; i++) m[i][2 * p]];
    var ssRes = Fraction.zero;
    var ssTot = Fraction.zero;
    var mean = Fraction.zero;
    for (final v in y) {
      mean = mean + v;
    }
    mean = mean / Fraction.int(n);
    for (var r = 0; r < n; r++) {
      var fitted = Fraction.zero;
      for (var j = 0; j < p; j++) {
        fitted = fitted + beta[j] * design[j][r];
      }
      final res = y[r] - fitted;
      ssRes = ssRes + res * res;
      final dy = intercept ? y[r] - mean : y[r];
      ssTot = ssTot + dy * dy;
    }
    final df = n - p;
    final ssReg = ssTot - ssRes;
    final sigma2 = ssRes / Fraction.int(df);
    final se = [for (var i = 0; i < p; i++) math.sqrt((sigma2 * m[i][p + i]).toDouble())];
    final k = columns.length;
    return ExactLinest._(
      [for (var j = 0; j < k; j++) beta[j + (intercept ? 1 : 0)].toDouble()],
      intercept ? beta[0].toDouble() : 0,
      [for (var j = 0; j < k; j++) se[j + (intercept ? 1 : 0)]],
      intercept ? se[0] : null,
      (ssReg / ssTot).toDouble(),
      math.sqrt(sigma2.toDouble()),
      ((ssReg / Fraction.int(k)) / sigma2).toDouble(),
      df,
      ssReg.toDouble(),
      ssRes.toDouble(),
    );
  }

  final List<double> coefficients;
  final double intercept;
  final List<double> standardErrors;
  final double? interceptStandardError;
  final double r2;
  final double standardErrorY;
  final double fStatistic;
  final int degreesOfFreedom;
  final double ssRegression;
  final double ssResidual;

  static Fraction _dot(List<Fraction> a, List<Fraction> b) {
    var s = Fraction.zero;
    for (var i = 0; i < a.length; i++) {
      s = s + a[i] * b[i];
    }
    return s;
  }
}

/// Exact fractions of the given doubles.
List<Fraction> exact(Iterable<double> values) => [for (final v in values) Fraction.fromDouble(v)];

/// Matcher: within [rel] relative error of [expected] (absolute [rel] when |expected| < 1).
Matcher closeToRel(double expected, {double rel = 1e-9}) =>
    closeTo(expected, rel * math.max(1.0, expected.abs()));

/// Element-wise [closeToRel] for lists.
Matcher allCloseToRel(List<double> expected, {double rel = 1e-9}) =>
    pairwiseCompare<double, double>(
      expected,
      (e, a) => (a - e).abs() <= rel * math.max(1.0, e.abs()),
      'within $rel relative of',
    );
