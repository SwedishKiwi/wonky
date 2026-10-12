import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/format_hint.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';

/// Shared helpers of the financial functions (05 §15.7).

/// Number result rounded to 15 significant digits (05 §12); NaN/∞ → `#NUM!`.
FValue finResult(double v, [FormatHint hint = FormatHint.none]) {
  if (!v.isFinite) return FError.num;
  final s = Numeric.stabilize(v);
  return FNumber(s == 0 ? 0.0 : s, hint);
}

/// Currency-hinted result (PMT, IPMT, PPMT, FV, PV, NPV; 05 §6.2).
FValue currencyResult(double v) => finResult(v, FormatHint.currencyDefault);

/// Fails with `#NUM!` and a Sheets-style message about parameter [param] (1-based).
Never numError(String fn, int param, String requirement) =>
    fail(ErrorKind.num, 'Function $fn parameter $param $requirement');

/// Argument [i] must be > 0.
double positive(Args a, int i) {
  final v = a.number(i);
  if (v <= 0) {
    numError(
      a.fn,
      i + 1,
      'value is ${Numeric.toText(v)}. It should be greater than 0.',
    );
  }
  return v;
}

/// Argument [i] must be ≥ 0.
double nonNegative(Args a, int i) {
  final v = a.number(i);
  if (v < 0) {
    numError(
      a.fn,
      i + 1,
      'value is ${Numeric.toText(v)}. It should be greater than or equal to 0.',
    );
  }
  return v;
}

/// `end_or_beginning`: 0 = end of period, any other value = beginning.
int paymentType(Args a, int i) => a.numberOr(i, 0) == 0 ? 0 : 1;

/// Values of a cash-flow argument in row-major order: numbers only inside references and
/// arrays (text, booleans and blanks ignored, errors propagate); direct scalars are coerced.
void collectCashFlows(Args a, int i, List<double> out) {
  final v = a[i];
  if (v is FOmitted) return;
  if (v is FRef || v is FArray) {
    for (var x in a.array(i).elements) {
      if (x is FRich) x = x.scalar;
      switch (x) {
        case FNumber(:final v):
          out.add(v);
        case FError():
          throw FormulaError(x);
        default:
          break;
      }
    }
    return;
  }
  out.add(a.number(i));
}

/// Cash flows of argument [i].
List<double> cashFlows(Args a, int i) {
  final out = <double>[];
  collectCashFlows(a, i, out);
  return out;
}

/// Paired numeric cells of two same-sized cash-flow arguments (XNPV, XIRR): a pair is used
/// only when both cells are numbers; errors propagate; different sizes → `#NUM!`.
(List<double>, List<double>) pairedFlows(Args a, int iv, int id) {
  List<FValue> cells(int i) {
    final v = a[i];
    if (v is FRef || v is FArray) return a.array(i).elements.toList();
    return [FNumber(a.number(i))];
  }

  final vs = cells(iv), ds = cells(id);
  if (vs.length != ds.length) {
    fail(ErrorKind.num, ErrorMessages.arraySizeMismatch(a.fn));
  }
  final values = <double>[], dates = <double>[];
  for (var k = 0; k < vs.length; k++) {
    var x = vs[k], d = ds[k];
    if (x is FRich) x = x.scalar;
    if (d is FRich) d = d.scalar;
    if (x is FError) throw FormulaError(x);
    if (d is FError) throw FormulaError(d);
    if (x is FNumber && d is FNumber) {
      values.add(x.v);
      dates.add(d.v.truncateToDouble());
    }
  }
  return (values, dates);
}

/// Whether [xs] has at least one positive and one negative value.
bool hasSignChange(List<double> xs) =>
    xs.any((x) => x > 0) && xs.any((x) => x < 0);

/// Newton's method: at most [maxIter] steps, converged when the step is below [tol].
/// Returns null when it does not converge or leaves the domain `x > lower`.
double? newton(
  double Function(double x) f,
  double Function(double x) df,
  double guess, {
  int maxIter = 100,
  double tol = 1e-10,
  double lower = double.negativeInfinity,
}) {
  var x = guess;
  for (var i = 0; i < maxIter; i++) {
    final fx = f(x);
    if (!fx.isFinite) return null;
    if (fx == 0) return x;
    final d = df(x);
    if (!d.isFinite || d == 0) return null;
    final next = x - fx / d;
    if (!next.isFinite || next <= lower) return null;
    if ((next - x).abs() < tol) return next;
    x = next;
  }
  return null;
}

/// Finds a root of [f] in (`lower`, ∞) by bracketing around [guess] and bisection.
double? bracketAndBisect(
  double Function(double x) f,
  double guess, {
  double lower = -1,
}) {
  // Candidate points ordered by distance from the guess, so the root nearest to it wins.
  final pts = <double>{};
  for (var k = 1; k <= 200; k++) {
    pts.add(lower + (guess - lower) * k / 200);
  }
  for (var e = 1e-2; e > 1e-12; e /= 10) {
    pts.add(lower + e);
  }
  for (var x = guess; x < 1e6; x = x <= 0 ? x + 0.05 : x * 1.25 + 0.01) {
    pts.add(x);
  }
  final xs = pts.where((x) => x > lower).toList()..sort();
  double? best;
  for (var k = 0; k + 1 < xs.length; k++) {
    final a = xs[k], b = xs[k + 1];
    final fa = f(a), fb = f(b);
    if (!fa.isFinite || !fb.isFinite) continue;
    if (fa == 0) return a;
    if (fa.sign == fb.sign) continue;
    final r = _bisect(f, a, b, fa);
    if (best == null || (r - guess).abs() < (best - guess).abs()) best = r;
  }
  return best;
}

double _bisect(double Function(double x) f, double a, double b, double fa) {
  for (var i = 0; i < 200; i++) {
    final m = (a + b) / 2;
    final fm = f(m);
    if (fm == 0 || (b - a).abs() < 1e-15 * (1 + m.abs())) return m;
    if (fm.sign == fa.sign) {
      a = m;
      fa = fm;
    } else {
      b = m;
    }
  }
  return (a + b) / 2;
}
