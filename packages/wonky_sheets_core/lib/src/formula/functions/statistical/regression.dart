import 'dart:math' as math;

import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../helpers.dart';
import '../registry.dart';
import 'common.dart';

final _pairParams = [
  P.array(
    'data_y',
    'The range representing the array or matrix of dependent data.',
  ),
  P.array(
    'data_x',
    'The range representing the array or matrix of independent data.',
  ),
];

/// Means and centered sums of a paired sample.
final class _Moments {
  final int n;
  final double mx, my, sxx, syy, sxy;
  const _Moments(this.n, this.mx, this.my, this.sxx, this.syy, this.sxy);

  factory _Moments.of(List<double> ys, List<double> xs) {
    final mx = meanOf(xs), my = meanOf(ys);
    final dx = [for (final x in xs) x - mx], dy = [for (final y in ys) y - my];
    return _Moments(
      ys.length,
      mx,
      my,
      sumOf(dx.map((d) => d * d)),
      sumOf(dy.map((d) => d * d)),
      sumOf([for (var i = 0; i < dx.length; i++) dx[i] * dy[i]]),
    );
  }
}

_Moments _moments(Args a, int iy, int ix, {int min = 1}) {
  final (ys, xs) = pairs(a, iy, ix, min: min);
  return _Moments.of(ys, xs);
}

/// Correlation, regression on pairs, covariance, FREQUENCY and the LINEST family.
void registerRegression(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.statistical;
  FValue correl(Args a) {
    final m = _moments(a, 0, 1);
    if (m.sxx == 0 || m.syy == 0) divZero(a);
    return numResult(m.sxy / math.sqrt(m.sxx * m.syy));
  }

  b.fn(
    'CORREL',
    'Calculates r, the Pearson product-moment correlation coefficient of a dataset.',
    _pairParams,
    correl,
    priority: Priority.p0,
    examples: ['CORREL(A2:A100, B2:B100)'],
    seeAlso: ['PEARSON', 'RSQ', 'COVARIANCE.P'],
  );
  b.fn(
    'PEARSON',
    'Calculates r, the Pearson product-moment correlation coefficient of a dataset.',
    _pairParams,
    correl,
    examples: ['PEARSON(A2:A100, B2:B100)'],
    seeAlso: ['CORREL', 'RSQ'],
  );
  b.fn(
    'RSQ',
    'Calculates the square of r, the Pearson product-moment correlation coefficient of a dataset.',
    _pairParams,
    (a) {
      final m = _moments(a, 0, 1);
      if (m.sxx == 0 || m.syy == 0) divZero(a);
      return numResult(m.sxy * m.sxy / (m.sxx * m.syy));
    },
    examples: ['RSQ(A2:A100, B2:B100)'],
    seeAlso: ['CORREL', 'PEARSON', 'LINEST'],
  );
  b.fn(
    'SLOPE',
    'Calculates the slope of the line resulting from linear regression of a dataset.',
    _pairParams,
    (a) {
      final m = _moments(a, 0, 1);
      if (m.sxx == 0) divZero(a);
      return numResult(m.sxy / m.sxx);
    },
    examples: ['SLOPE(A2:A100, B2:B100)'],
    seeAlso: ['INTERCEPT', 'LINEST', 'FORECAST'],
  );
  b.fn(
    'INTERCEPT',
    'Calculates the y-value at which the line resulting from linear regression of a dataset will intersect the y-axis (x=0).',
    _pairParams,
    (a) {
      final m = _moments(a, 0, 1);
      if (m.sxx == 0) divZero(a);
      return numResult(m.my - m.sxy / m.sxx * m.mx);
    },
    examples: ['INTERCEPT(A2:A100, B2:B100)'],
    seeAlso: ['SLOPE', 'LINEST', 'FORECAST'],
  );
  b.fn(
    'STEYX',
    'Calculates the standard error of the predicted y-value for each x in the regression of a dataset.',
    _pairParams,
    (a) {
      final m = _moments(a, 0, 1);
      if (m.n < 3 || m.sxx == 0) divZero(a);
      final resid = math.max(0.0, m.syy - m.sxy * m.sxy / m.sxx);
      return numResult(math.sqrt(resid / (m.n - 2)));
    },
    examples: ['STEYX(A2:A100, B2:B100)'],
    seeAlso: ['SLOPE', 'LINEST'],
  );
  b.fn(
    'FORECAST',
    'Calculates the expected y-value for a specified x based on a linear regression of a dataset.',
    [
      P.num('x', 'The value on the x-axis to forecast.'),
      P.array(
        'data_y',
        'The range representing the array or matrix of dependent data.',
      ),
      P.array(
        'data_x',
        'The range representing the array or matrix of independent data.',
      ),
    ],
    (a) {
      final x = a.number(0);
      final m = _moments(a, 1, 2);
      if (m.sxx == 0) divZero(a);
      final slope = m.sxy / m.sxx;
      return numResult(m.my + slope * (x - m.mx));
    },
    aliases: ['FORECAST.LINEAR'],
    examples: ['FORECAST(A1, A2:A100, B2:B100)'],
    seeAlso: ['TREND', 'SLOPE', 'INTERCEPT'],
  );
  b.fn(
    'COVARIANCE.P',
    'Calculates the covariance of a dataset, where the dataset is the entire population.',
    _pairParams,
    (a) {
      final m = _moments(a, 0, 1);
      return numResult(m.sxy / m.n);
    },
    aliases: ['COVAR'],
    examples: ['COVARIANCE.P(A2:A100, B2:B100)'],
    seeAlso: ['COVARIANCE.S', 'CORREL'],
  );
  b.fn(
    'COVARIANCE.S',
    'Calculates the covariance of a dataset, where the dataset is a sample of the total population.',
    _pairParams,
    (a) {
      final m = _moments(a, 0, 1, min: 2);
      return numResult(m.sxy / (m.n - 1));
    },
    examples: ['COVARIANCE.S(A2:A100, B2:B100)'],
    seeAlso: ['COVARIANCE.P', 'CORREL'],
  );
  _registerArrays(b);
}

// -------------------------------------------------------------------- FREQUENCY & LINEST family

List<double> _numbersOf(FArray arr) {
  final out = <double>[];
  for (var v in arr.elements) {
    if (v is FRich) v = v.scalar;
    if (v is FError) throw FormulaError(v);
    if (v is FNumber) out.add(v.v);
  }
  return out;
}

/// All elements must be numbers (`#VALUE!` otherwise).
List<double> _strict(Args a, FArray arr) {
  final out = <double>[];
  for (var v in arr.elements) {
    if (v is FRich) v = v.scalar;
    if (v is FError) throw FormulaError(v);
    if (v is! FNumber) {
      fail(ErrorKind.value, 'Function ${a.fn} expects number values.');
    }
    out.add(v.v);
  }
  return out;
}

/// Regression data: n observations of k variables.
final class _Data {
  final List<double> y;
  final List<List<double>> x; // k columns of length n
  /// Orientation of observations: true when observations run down rows.
  final bool byRows;
  final FArray yShape;
  const _Data(this.y, this.x, this.byRows, this.yShape);
  int get n => y.length;
  int get k => x.length;
}

_Data _data(Args a, {required bool log}) {
  final ya = a.array(0);
  var y = _strict(a, ya);
  if (log) {
    if (y.any((v) => v <= 0)) fail(ErrorKind.num);
    y = [for (final v in y) math.log(v)];
  }
  final n = y.length;
  final byRows = !(ya.rows == 1 && ya.cols > 1);
  if (!a.has(1)) {
    return _Data(y, [List<double>.generate(n, (i) => i + 1.0)], byRows, ya);
  }
  final xa = a.array(1);
  if (xa.rows == ya.rows && xa.cols == ya.cols) {
    return _Data(y, [_strict(a, xa)], byRows, ya);
  }
  final List<List<double>> cols;
  if (ya.cols == 1 && xa.rows == n) {
    cols = [
      for (var c = 0; c < xa.cols; c++)
        _strict(a, FArray(xa.rows, 1, xa.column(c))),
    ];
  } else if (ya.rows == 1 && xa.cols == n) {
    cols = [
      for (var r = 0; r < xa.rows; r++)
        _strict(a, FArray(1, xa.cols, xa.row(r))),
    ];
  } else {
    fail(ErrorKind.ref, 'Array arguments to ${a.fn} are of different size.');
  }
  return _Data(y, cols, byRows, ya);
}

/// Result of a least-squares fit.
final class _Fit {
  final List<double> coef; // per variable (dependent variables get 0)
  final List<double> se;
  final double intercept;
  final double seIntercept;
  final double r2, seY, f, df, ssReg, ssResid;
  const _Fit(
    this.coef,
    this.se,
    this.intercept,
    this.seIntercept,
    this.r2,
    this.seY,
    this.f,
    this.df,
    this.ssReg,
    this.ssResid,
  );
}

/// Least squares by Householder QR with rank detection (collinear columns get coefficient 0).
_Fit _fit(_Data d, bool constant) {
  final n = d.n, k = d.k;
  final mx = [for (final c in d.x) constant ? meanOf(c) : 0.0];
  final my = constant ? meanOf(d.y) : 0.0;
  final cols = [
    for (var j = 0; j < k; j++) [for (final v in d.x[j]) v - mx[j]],
  ];
  final qty = [for (final v in d.y) v - my];
  final accepted = <int>[];
  final maxRank = constant ? n - 1 : n;
  for (var j = 0; j < k; j++) {
    final col = cols[j];
    final r = accepted.length;
    var orig = 0.0;
    for (final v in d.x[j]) {
      orig = math.max(orig, (v - mx[j]).abs());
    }
    if (r >= maxRank || orig == 0) continue;
    var norm = 0.0;
    for (var i = r; i < n; i++) {
      norm += col[i] * col[i];
    }
    norm = math.sqrt(norm);
    if (norm <= 1e-10 * orig * math.sqrt(n)) continue;
    // Householder vector v = x − alpha·e_r
    final alpha = col[r] > 0 ? -norm : norm;
    final v = List<double>.filled(n, 0);
    for (var i = r; i < n; i++) {
      v[i] = col[i];
    }
    v[r] -= alpha;
    var vv = 0.0;
    for (var i = r; i < n; i++) {
      vv += v[i] * v[i];
    }
    void reflect(List<double> target) {
      var dot = 0.0;
      for (var i = r; i < n; i++) {
        dot += v[i] * target[i];
      }
      final s = 2 * dot / vv;
      for (var i = r; i < n; i++) {
        target[i] -= s * v[i];
      }
    }

    if (vv > 0) {
      for (var jj = j; jj < k; jj++) {
        reflect(cols[jj]);
      }
      reflect(qty);
    }
    accepted.add(j);
  }
  final r = accepted.length;
  // R (r×r) and back substitution.
  final rr = [
    for (var i = 0; i < r; i++)
      [for (var c = 0; c < r; c++) cols[accepted[c]][i]],
  ];
  final beta = List<double>.filled(r, 0);
  for (var i = r - 1; i >= 0; i--) {
    var s = qty[i];
    for (var c = i + 1; c < r; c++) {
      s -= rr[i][c] * beta[c];
    }
    beta[i] = s / rr[i][i];
  }
  // R⁻¹ (upper triangular).
  final rinv = List.generate(r, (_) => List<double>.filled(r, 0));
  for (var c = 0; c < r; c++) {
    rinv[c][c] = 1 / rr[c][c];
    for (var i = c - 1; i >= 0; i--) {
      var s = 0.0;
      for (var m = i + 1; m <= c; m++) {
        s += rr[i][m] * rinv[m][c];
      }
      rinv[i][c] = -s / rr[i][i];
    }
  }
  var ssResid = 0.0;
  for (var i = r; i < n; i++) {
    ssResid += qty[i] * qty[i];
  }
  final ssTotal = sumOf([for (final v in d.y) (v - my) * (v - my)]);
  final ssReg = math.max(0.0, ssTotal - ssResid);
  final df = (n - r - (constant ? 1 : 0)).toDouble();
  final sigma2 = df > 0 ? ssResid / df : double.nan;
  final coef = List<double>.filled(k, 0);
  final se = List<double>.filled(k, 0);
  for (var i = 0; i < r; i++) {
    coef[accepted[i]] = beta[i];
    var s = 0.0;
    for (var m = i; m < r; m++) {
      s += rinv[i][m] * rinv[i][m];
    }
    se[accepted[i]] = math.sqrt(sigma2 * s);
  }
  var intercept = 0.0, seB = double.nan;
  if (constant) {
    intercept = my;
    for (var j = 0; j < k; j++) {
      intercept -= coef[j] * mx[j];
    }
    var w2 = 0.0;
    for (var m = 0; m < r; m++) {
      var w = 0.0;
      for (var i = 0; i <= m; i++) {
        w += rinv[i][m] * mx[accepted[i]];
      }
      w2 += w * w;
    }
    seB = math.sqrt(sigma2 * (1 / n + w2));
  }
  final r2 = ssTotal == 0 ? double.nan : ssReg / ssTotal;
  final f = r == 0 ? double.nan : (ssReg / r) / sigma2;
  return _Fit(
    coef,
    se,
    intercept,
    seB,
    r2,
    math.sqrt(sigma2),
    f,
    df,
    ssReg,
    ssResid,
  );
}

FValue _num(double v) => v.isFinite ? FNumber(v == 0 ? 0.0 : v) : FError.num;

FArray _linestResult(
  _Fit fit, {
  required bool stats,
  required bool log,
  required bool constant,
}) {
  final k = fit.coef.length;
  FValue coef(double v) => _num(log ? math.exp(v) : v);
  final row1 = [
    for (var j = k - 1; j >= 0; j--) coef(fit.coef[j]),
    constant ? coef(fit.intercept) : coef(0),
  ];
  if (!stats) return FArray(1, k + 1, row1);
  final cols = k + 1;
  FValue at(List<FValue> row, int i) => i < row.length ? row[i] : FError.na;
  final row2 = [
    for (var j = k - 1; j >= 0; j--) _num(fit.se[j]),
    constant ? _num(fit.seIntercept) : FError.na,
  ];
  final row3 = [_num(fit.r2), _num(fit.seY)];
  final row4 = [_num(fit.f), _num(fit.df)];
  final row5 = [_num(fit.ssReg), _num(fit.ssResid)];
  return FArray(5, cols, [
    ...row1,
    ...row2,
    for (var i = 0; i < cols; i++) at(row3, i),
    for (var i = 0; i < cols; i++) at(row4, i),
    for (var i = 0; i < cols; i++) at(row5, i),
  ]);
}

FValue _trend(Args a, {required bool log}) {
  final d = _data(a, log: log);
  final constant = a.boolOr(3, true);
  final fit = _fit(d, constant);
  FValue predict(List<double> xs) {
    var v = constant ? fit.intercept : 0.0;
    for (var j = 0; j < xs.length; j++) {
      v += fit.coef[j] * xs[j];
    }
    return _num(log ? math.exp(v) : v);
  }

  FArray nx;
  if (a.has(2)) {
    nx = a.array(2);
  } else if (a.has(1)) {
    nx = a.array(1);
  } else {
    final s = d.yShape;
    var i = 0;
    nx = FArray.generate(s.rows, s.cols, (_, _) => FNumber(++i + 0.0));
  }
  final nv = _strict(a, nx);
  if (d.k == 1) {
    return FArray(nx.rows, nx.cols, [
      for (final x in nv) predict([x]),
    ]);
  }
  if (d.byRows) {
    if (nx.cols != d.k) {
      fail(ErrorKind.ref, 'Array arguments to ${a.fn} are of different size.');
    }
    return FArray(nx.rows, 1, [
      for (var r = 0; r < nx.rows; r++)
        predict([for (var c = 0; c < nx.cols; c++) nv[r * nx.cols + c]]),
    ]);
  }
  if (nx.rows != d.k) {
    fail(ErrorKind.ref, 'Array arguments to ${a.fn} are of different size.');
  }
  return FArray(1, nx.cols, [
    for (var c = 0; c < nx.cols; c++)
      predict([for (var r = 0; r < nx.rows; r++) nv[r * nx.cols + c]]),
  ]);
}

void _registerArrays(FunctionRegistryBuilder b) {
  b.fn(
    'FREQUENCY',
    'Calculates the frequency distribution of a one-column array into specified classes.',
    [
      P.array(
        'data',
        'The array or range containing the values to be counted.',
      ),
      P.array('classes', 'The array or range containing the set of classes.'),
    ],
    (a) {
      final data = _numbersOf(a.array(0));
      final bins = _numbersOf(a.array(1));
      final order = List<int>.generate(bins.length, (i) => i)
        ..sort((x, y) {
          final c = bins[x].compareTo(bins[y]);
          return c != 0 ? c : x.compareTo(y);
        });
      final counts = List<double>.filled(bins.length + 1, 0);
      for (final v in data) {
        var lo = 0, hi = order.length;
        while (lo < hi) {
          final mid = (lo + hi) >> 1;
          if (bins[order[mid]] < v) {
            lo = mid + 1;
          } else {
            hi = mid;
          }
        }
        counts[lo == order.length ? bins.length : order[lo]]++;
      }
      return FArray(counts.length, 1, [for (final c in counts) FNumber(c)]);
    },
    category: FunctionCategory.array,
    returns: ReturnKind.array,
    examples: ['FREQUENCY(A2:A40, B2:B5)'],
    seeAlso: ['COUNTIFS'],
  );
  final fitParams = [
    P.array(
      'known_data_y',
      'The array or range containing dependent (y) values that are already known.',
    ),
    P.array(
      'known_data_x',
      'The values of the independent variable(s) corresponding with known_data_y.',
      true,
    ),
  ];
  for (final (name, log, summary) in const [
    (
      'LINEST',
      false,
      'Given partial data about a linear trend, calculates various parameters about the ideal linear trend using the least-squares method.',
    ),
    (
      'LOGEST',
      true,
      'Given partial data about an exponential growth curve, calculates various parameters about the best fit ideal exponential growth curve.',
    ),
  ]) {
    b.fn(
      name,
      summary,
      [
        ...fitParams,
        P.bool_(
          'calculate_b',
          'Whether to calculate the intercept (b) or force it to be ${log ? 1 : 0}.',
          true,
          true,
        ),
        P.bool_(
          'verbose',
          'Whether to return additional regression statistics.',
          true,
          false,
        ),
      ],
      (a) {
        final d = _data(a, log: log);
        final constant = a.boolOr(2, true);
        final stats = a.boolOr(3, false);
        return _linestResult(
          _fit(d, constant),
          stats: stats,
          log: log,
          constant: constant,
        );
      },
      category: FunctionCategory.array,
      returns: ReturnKind.array,
      priority: Priority.p2,
      examples: ['$name(B2:B10, A2:A10)'],
      seeAlso: log ? ['GROWTH', 'LINEST'] : ['TREND', 'LOGEST', 'SLOPE'],
    );
  }
  for (final (name, log, summary) in const [
    (
      'TREND',
      false,
      'Fits an ideal linear trend using the least squares method to partial data and then extrapolates further values.',
    ),
    (
      'GROWTH',
      true,
      'Given partial data about an exponential growth trend, fits an ideal exponential growth trend and/or predicts further values.',
    ),
  ]) {
    b.fn(
      name,
      summary,
      [
        ...fitParams,
        P.array(
          'new_data_x',
          'The data points to return the y values for on the ideal curve fit.',
          true,
        ),
        P.bool_(
          'b',
          'Whether to calculate the intercept or force it to be ${log ? 1 : 0}.',
          true,
          true,
        ),
      ],
      (a) => _trend(a, log: log),
      category: FunctionCategory.array,
      returns: ReturnKind.array,
      priority: Priority.p2,
      examples: ['$name(B2:B10, A2:A10, A11:A13)'],
      seeAlso: log ? ['LOGEST', 'TREND'] : ['LINEST', 'FORECAST', 'GROWTH'],
    );
  }
}
