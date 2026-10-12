import 'dart:math' as math;

import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/coercion.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../helpers.dart';
import '../registry.dart';

/// Shared helpers of the statistical functions.

/// Fails with `#DIV/0!` "Evaluation of function F caused a divide by zero error.".
Never divZero(Args a) => fail(ErrorKind.div0, ErrorMessages.divZeroEval(a.fn));

/// Numbers of arguments [from]..[to] in argument order, row-major within ranges (references
/// are materialized). Aggregate rules of 05 §6.3; errors throw.
List<double> orderedNumbers(
  Args a, {
  int from = 0,
  int? to,
  AggMode mode = AggMode.numbers,
}) {
  final out = <double>[];
  final end = to ?? a.length;
  for (var i = from; i < end; i++) {
    final v = a[i];
    if (v is FRef || v is FArray) {
      for (var x in a.array(i).elements) {
        if (x is FRich) x = x.scalar;
        switch (x) {
          case FNumber(:final v):
            out.add(v);
          case FError():
            throw FormulaError(x);
          case FBool(:final v):
            if (mode == AggMode.a) out.add(v ? 1 : 0);
          case FText():
            if (mode == AggMode.a) out.add(0);
          default:
            break;
        }
      }
    } else {
      out.addAll(a.numbers(from: i, to: i + 1, mode: mode));
    }
  }
  return out;
}

/// Numbers of a single data argument, sorted ascending.
List<double> sortedNumbers(Args a, int i) =>
    a.numbers(from: i, to: i + 1)..sort();

/// Sample variance (n − 1) or population variance (n).
double variance(Args a, List<double> xs, {required bool sample}) {
  final n = xs.length;
  if (n == 0 || (sample && n < 2)) divZero(a);
  return devSq(xs) / (sample ? n - 1 : n);
}

/// Inclusive percentile of sorted [xs] (linear interpolation, h = (n − 1)p).
double percentileInc(List<double> xs, double p) {
  final h = (xs.length - 1) * p;
  final lo = h.floor();
  final hi = math.min(lo + 1, xs.length - 1);
  return xs[lo] + (h - lo) * (xs[hi] - xs[lo]);
}

/// Exclusive percentile of sorted [xs]; null when p is outside [1/(n+1), n/(n+1)].
double? percentileExc(List<double> xs, double p) {
  final n = xs.length;
  final h = (n + 1) * p - 1;
  if (h < -1e-12 || h > n - 1 + 1e-12) return null;
  final hc = h.clamp(0, n - 1).toDouble();
  final lo = hc.floor();
  final hi = math.min(lo + 1, n - 1);
  return xs[lo] + (hc - lo) * (xs[hi] - xs[lo]);
}

/// Most frequent value of [xs] (first occurrence wins ties); null when nothing repeats.
List<double> modes(List<double> xs) {
  final counts = <double, int>{};
  final order = <double>[];
  for (final x in xs) {
    final k = x == 0 ? 0.0 : x;
    final c = counts[k];
    if (c == null) order.add(k);
    counts[k] = (c ?? 0) + 1;
  }
  var best = 1;
  for (final c in counts.values) {
    if (c > best) best = c;
  }
  if (best < 2) return const [];
  return [
    for (final k in order)
      if (counts[k] == best) k,
  ];
}

/// Checks a probability-like parameter.
void requireRange(bool ok) {
  if (!ok) fail(ErrorKind.num);
}

/// Truncates a double toward zero (for integer parameters of distributions).
double trunc(double x) => x.truncateToDouble();

/// Numeric value of a direct scalar argument for COUNT (numeric text counts), or null.
bool isCountableScalar(FValue v, Args a) {
  if (v is FRich) v = v.scalar;
  switch (v) {
    case FNumber() || FBool():
      return true;
    case FText():
      return Coerce.toNumber(v, a.locale, fn: a.fn, param: 1) is double;
    default:
      return false;
  }
}

/// Paired data (y, x) of two array arguments; `#DIV/0!` when no pairs remain.
(List<double>, List<double>) pairs(Args a, int iy, int ix, {int min = 1}) {
  final (ys, xs) = pairedNumbers(a, iy, ix);
  if (ys.length < min) divZero(a);
  return (ys, xs);
}

/// Shorthand for registering with a priority.
typedef Reg = FunctionRegistryBuilder;
