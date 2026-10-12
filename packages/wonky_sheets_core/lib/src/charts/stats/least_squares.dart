import 'dart:math' as math;
import 'dart:typed_data';

/// Result of a general multiple linear least-squares fit (see [LeastSquares.fit]).
///
/// The statistics follow Excel's / Google Sheets' `LINEST(…, verbose = TRUE)` conventions, so
/// the formula engine's `LINEST`, `LOGEST`, `TREND` and `GROWTH` can read them directly:
///
/// | Field | LINEST row/cell |
/// |-------|-----------------|
/// | [coefficients], [intercept] | row 1 (LINEST lists the columns in reverse order) |
/// | [standardErrors], [interceptStandardError] | row 2 |
/// | [r2], [standardErrorY] | row 3 |
/// | [fStatistic], [degreesOfFreedom] | row 4 |
/// | [ssRegression], [ssResidual] | row 5 |
///
/// Columns that are (numerically) linearly dependent on earlier-chosen columns (or, with an
/// intercept, constant columns) get coefficient 0 and standard error 0 and do not count towards
/// [rank]; [degreesOfFreedom] is `n − rank − 1` with intercept and `n − rank` without.
final class LeastSquaresFit {
  /// Creates a fit result. Usually produced by [LeastSquares.fit].
  LeastSquaresFit({
    required this.coefficients,
    required this.intercept,
    required this.standardErrors,
    required this.interceptStandardError,
    required this.r2,
    required this.standardErrorY,
    required this.fStatistic,
    required this.degreesOfFreedom,
    required this.ssRegression,
    required this.ssResidual,
    required this.rank,
    required this.observationCount,
    required this.hasIntercept,
  });

  /// One coefficient per X column, in the order the columns were given (0 for dependent ones).
  final Float64List coefficients;

  /// The constant term; 0 when the fit was made without intercept.
  final double intercept;

  /// Standard error per column (same order; 0 for dependent columns), or null when
  /// [degreesOfFreedom] ≤ 0.
  final Float64List? standardErrors;

  /// Standard error of [intercept], or null without intercept or when [degreesOfFreedom] ≤ 0.
  final double? interceptStandardError;

  /// Coefficient of determination `ssRegression / (ssRegression + ssResidual)`.
  ///
  /// With intercept the total sum of squares is centered (Σ(y − ȳ)²), without intercept it is
  /// uncentered (Σy²), as in Excel. When the total sum of squares is 0, R² is defined as 1 if
  /// all residuals are 0 and 0 otherwise.
  final double r2;

  /// Standard error of the y estimate, `sqrt(ssResidual / df)`; NaN when df ≤ 0.
  final double standardErrorY;

  /// F statistic `(ssRegression / rank) / (ssResidual / df)`.
  ///
  /// NaN when df ≤ 0 or rank = 0; +∞ when the fit is exact (ssResidual = 0) with
  /// ssRegression > 0.
  final double fStatistic;

  /// Residual degrees of freedom.
  final int degreesOfFreedom;

  /// Regression sum of squares: Σ(ŷ − ȳ)² with intercept, Σŷ² without.
  final double ssRegression;

  /// Residual sum of squares Σ(y − ŷ)². Snapped to exactly 0 when it is below
  /// [LeastSquares.exactFitTolerance] of the total sum of squares (rounding noise of an exact
  /// fit), so exact data yields R² = 1, sey = 0 and F = +∞.
  final double ssResidual;

  /// Number of linearly independent regressors used (excluding the intercept).
  final int rank;

  /// Number of rows used (rows with a NaN or non-finite value are skipped).
  final int observationCount;

  /// Whether the model includes a constant term.
  final bool hasIntercept;

  /// Evaluates the fitted model for one row of regressor values ([xs] has one value per column).
  double predict(List<double> xs) {
    if (xs.length != coefficients.length) {
      throw ArgumentError.value(xs.length, 'xs', 'expected ${coefficients.length} values');
    }
    var sum = intercept;
    for (var j = 0; j < coefficients.length; j++) {
      final c = coefficients[j];
      if (c != 0) sum += c * xs[j];
    }
    return sum;
  }
}

/// General multiple linear least squares (Householder QR with column pivoting).
abstract final class LeastSquares {
  /// Relative tolerance for rank detection: a column whose component orthogonal to the
  /// already-chosen columns is below this fraction of its norm counts as dependent.
  static const double rankTolerance = 1e-10;

  /// Relative size (to the total sum of squares) below which the residual sum of squares is
  /// treated as 0.
  static const double exactFitTolerance = 1e-24;

  /// Fits `y ≈ intercept + Σ coefficients[j] · xColumns[j]` by least squares.
  ///
  /// Every column must have the same length as [y]. Rows where y or any x is NaN or
  /// non-finite are skipped. Returns null when no usable row remains. With [intercept] the
  /// columns and y are centered before the QR decomposition (better conditioning, and constant
  /// columns become exactly dependent on the intercept).
  static LeastSquaresFit? fit(List<Float64List> xColumns, Float64List y, {bool intercept = true}) {
    final total = y.length;
    final k = xColumns.length;
    for (var j = 0; j < k; j++) {
      if (xColumns[j].length != total) {
        throw ArgumentError.value(
          xColumns[j].length,
          'xColumns[$j]',
          'length must equal y.length ($total)',
        );
      }
    }
    final rows = Int32List(total);
    var n = 0;
    for (var i = 0; i < total; i++) {
      if (!y[i].isFinite) continue;
      var ok = true;
      for (var j = 0; j < k; j++) {
        if (!xColumns[j][i].isFinite) {
          ok = false;
          break;
        }
      }
      if (ok) rows[n++] = i;
    }
    if (n == 0) return null;

    // Design matrix (column-major) and right-hand side, centered when fitting an intercept.
    final design = Float64List(n * k);
    final means = Float64List(k);
    final rhs = Float64List(n);
    for (var j = 0; j < k; j++) {
      final col = xColumns[j];
      for (var r = 0; r < n; r++) {
        design[j * n + r] = col[rows[r]];
      }
    }
    for (var r = 0; r < n; r++) {
      rhs[r] = y[rows[r]];
    }
    var meanY = 0.0;
    if (intercept) {
      meanY = _center(rhs, 0, n);
      for (var j = 0; j < k; j++) {
        means[j] = _center(design, j * n, n);
      }
    }

    final qr = _PivotedQr.solve(
      Float64List.fromList(design),
      n,
      k,
      Float64List.fromList(rhs),
      intercept ? n - 1 : n,
    );
    final coef = qr.coefficients;

    var ssResid = 0.0;
    var ssReg = 0.0;
    var ssTot = 0.0;
    for (var r = 0; r < n; r++) {
      var fitted = 0.0;
      for (var j = 0; j < k; j++) {
        final c = coef[j];
        if (c != 0) fitted += c * design[j * n + r];
      }
      final res = rhs[r] - fitted;
      ssResid += res * res;
      ssReg += fitted * fitted;
      ssTot += rhs[r] * rhs[r];
    }
    if (ssResid <= exactFitTolerance * ssTot) ssResid = 0;
    var b0 = 0.0;
    if (intercept) {
      b0 = meanY;
      for (var j = 0; j < k; j++) {
        b0 -= coef[j] * means[j];
      }
    }

    final double r2;
    final denominator = ssReg + ssResid;
    if (ssTot == 0 || denominator == 0) {
      r2 = ssResid == 0 ? 1 : 0;
    } else {
      r2 = (ssReg / denominator).clamp(0.0, 1.0);
    }
    final rank = qr.rank;
    final df = intercept ? n - rank - 1 : n - rank;
    final sey = df > 0 ? math.sqrt(ssResid / df) : double.nan;
    final double f;
    if (df <= 0 || rank == 0) {
      f = double.nan;
    } else if (ssResid == 0) {
      f = ssReg > 0 ? double.infinity : double.nan;
    } else {
      f = (ssReg / rank) / (ssResid / df);
    }

    Float64List? se;
    double? seIntercept;
    if (df > 0) {
      se = Float64List(k);
      final rinv = qr.rInverse;
      for (var q = 0; q < rank; q++) {
        var s = 0.0;
        for (var c = q; c < rank; c++) {
          final v = rinv[q * rank + c];
          s += v * v;
        }
        se[qr.permutation[q]] = sey * math.sqrt(s);
      }
      if (intercept) {
        // Var(b0) = σ²·(1/n + x̄ᵀ (XcᵀXc)⁻¹ x̄) with (XcᵀXc)⁻¹ = R⁻¹R⁻ᵀ.
        var quad = 0.0;
        for (var c = 0; c < rank; c++) {
          var w = 0.0;
          for (var q = 0; q <= c; q++) {
            w += rinv[q * rank + c] * means[qr.permutation[q]];
          }
          quad += w * w;
        }
        seIntercept = sey * math.sqrt(1 / n + quad);
      }
    }

    return LeastSquaresFit(
      coefficients: coef,
      intercept: b0,
      standardErrors: se,
      interceptStandardError: seIntercept,
      r2: r2,
      standardErrorY: sey,
      fStatistic: f,
      degreesOfFreedom: df,
      ssRegression: ssReg,
      ssResidual: ssResid,
      rank: rank,
      observationCount: n,
      hasIntercept: intercept,
    );
  }

  /// Subtracts the mean of `data[offset .. offset+n)` in place and returns it. Two-pass with a
  /// correction term; a constant segment becomes exactly zero.
  static double _center(Float64List data, int offset, int n) {
    var sum = 0.0;
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      final v = data[offset + i];
      sum += v;
      if (v < min) min = v;
      if (v > max) max = v;
    }
    double mean;
    if (min == max) {
      mean = min;
    } else {
      mean = sum / n;
      var correction = 0.0;
      for (var i = 0; i < n; i++) {
        correction += data[offset + i] - mean;
      }
      mean += correction / n;
    }
    for (var i = 0; i < n; i++) {
      data[offset + i] -= mean;
    }
    return mean;
  }
}

/// Householder QR with scale-invariant column pivoting, solving min ‖A·x − b‖.
final class _PivotedQr {
  _PivotedQr(this.coefficients, this.rank, this.rInverse, this.permutation);

  /// Solution in the original column order (0 for dependent columns).
  final Float64List coefficients;
  final int rank;

  /// Row-major `rank × rank` inverse of the leading R block (pivoted order).
  final Float64List rInverse;

  /// `permutation[q]` = original column of pivot position q.
  final Int32List permutation;

  /// [a] is column-major `n × p` and is overwritten, as is [b].
  static _PivotedQr solve(Float64List a, int n, int p, Float64List b, int maxRank) {
    final perm = Int32List(p);
    final orig = Float64List(p);
    for (var j = 0; j < p; j++) {
      perm[j] = j;
      orig[j] = _norm(a, j * n, 0, n);
    }
    final diag = Float64List(p);
    final limit = math.max(0, math.min(maxRank, p));
    var rank = 0;
    for (var k = 0; k < limit; k++) {
      var best = -1;
      var bestRatio = 0.0;
      var bestNorm = 0.0;
      for (var j = k; j < p; j++) {
        if (orig[j] == 0) continue;
        final rem = _norm(a, j * n, k, n);
        final ratio = rem / orig[j];
        if (ratio > bestRatio) {
          bestRatio = ratio;
          best = j;
          bestNorm = rem;
        }
      }
      if (best < 0 || bestRatio <= LeastSquares.rankTolerance) break;
      if (best != k) {
        for (var i = 0; i < n; i++) {
          final t = a[k * n + i];
          a[k * n + i] = a[best * n + i];
          a[best * n + i] = t;
        }
        final tp = perm[k];
        perm[k] = perm[best];
        perm[best] = tp;
        final to = orig[k];
        orig[k] = orig[best];
        orig[best] = to;
      }
      final kk = k * n + k;
      final akk = a[kk];
      final alpha = akk > 0 ? -bestNorm : bestNorm;
      a[kk] = akk - alpha; // Householder vector v lives in column k, rows k..n-1.
      final tau = alpha * (alpha - akk); // vᵀv / 2
      for (var j = k + 1; j < p; j++) {
        _reflect(a, k * n, a, j * n, k, n, tau);
      }
      _reflect(a, k * n, b, 0, k, n, tau);
      diag[k] = alpha;
      rank = k + 1;
    }

    // Back substitution on the leading rank × rank block.
    final z = Float64List(rank);
    for (var q = rank - 1; q >= 0; q--) {
      var s = b[q];
      for (var c = q + 1; c < rank; c++) {
        s -= a[c * n + q] * z[c];
      }
      z[q] = s / diag[q];
    }
    final rinv = Float64List(rank * rank);
    for (var c = 0; c < rank; c++) {
      rinv[c * rank + c] = 1 / diag[c];
      for (var q = c - 1; q >= 0; q--) {
        var s = 0.0;
        for (var m = q + 1; m <= c; m++) {
          s += a[m * n + q] * rinv[m * rank + c];
        }
        rinv[q * rank + c] = -s / diag[q];
      }
    }
    final coef = Float64List(p);
    for (var q = 0; q < rank; q++) {
      coef[perm[q]] = z[q];
    }
    return _PivotedQr(coef, rank, rinv, perm);
  }

  /// Applies `I − v·vᵀ/tau` (v = `v[vOff+k ..]`) to `x[xOff+k ..]`.
  static void _reflect(Float64List v, int vOff, Float64List x, int xOff, int k, int n, double tau) {
    var s = 0.0;
    for (var i = k; i < n; i++) {
      s += v[vOff + i] * x[xOff + i];
    }
    if (s == 0) return;
    final f = s / tau;
    for (var i = k; i < n; i++) {
      x[xOff + i] -= f * v[vOff + i];
    }
  }

  /// Euclidean norm of `data[off+from .. off+to)`, scaled to avoid overflow/underflow.
  static double _norm(Float64List data, int off, int from, int to) {
    var scale = 0.0;
    for (var i = from; i < to; i++) {
      final v = data[off + i].abs();
      if (v > scale) scale = v;
    }
    if (scale == 0) return 0;
    var sum = 0.0;
    for (var i = from; i < to; i++) {
      final v = data[off + i] / scale;
      sum += v * v;
    }
    return scale * math.sqrt(sum);
  }
}
