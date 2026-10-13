import 'dart:math' as math;

import '../eval/args.dart';
import '../eval/eval_context.dart';
import '../eval/range_access.dart';
import '../values/errors.dart';
import '../values/format_hint.dart';
import '../values/fvalue.dart';
import '../values/numeric.dart';
import 'registry.dart';

/// Shared helpers for function implementations.

/// Number result; NaN/∞ → `#NUM!`.
FValue numResult(double v, [FormatHint hint = FormatHint.none]) =>
    v.isFinite ? FNumber(v == 0 ? 0.0 : v, hint) : FError.num;

/// Number result passed through [Numeric.stabilize] (transcendental functions, 05 §12).
FValue stableResult(double v) =>
    v.isFinite ? FNumber(Numeric.stabilize(v)) : FError.num;

FValue boolResult(bool b) => FBool(b);

/// Registers a unary numeric function.
void unaryMath(
  FunctionRegistryBuilder b,
  String name,
  String summary,
  double Function(double x) f, {
  String arg = 'value',
  String argDesc = 'The number.',
  bool stable = false,
  bool Function(double x)? domain,
  ErrorKind domainError = ErrorKind.num,
  Priority priority = Priority.p1,
  List<String> examples = const [],
  List<String> aliases = const [],
}) {
  b.fn(
    name,
    summary,
    [P.num(arg, argDesc)],
    (a) {
      final x = a.number(0);
      if (domain != null && !domain(x)) fail(domainError);
      final r = f(x);
      return stable ? stableResult(r) : numResult(r);
    },
    priority: priority,
    examples: examples.isEmpty ? ['$name(1)'] : examples,
    aliases: aliases,
  );
}

/// Throws `#VALUE!` "… expects number values" style error for a parameter.
Never valueError(String message) => fail(ErrorKind.value, message);

/// Validates that two shapes are equal.
void requireSameShape(Args a, int i, int j) {
  final s1 = a.shape(i), s2 = a.shape(j);
  if (s1 != s2) fail(ErrorKind.value, ErrorMessages.arraySizeMismatch(a.fn));
}

/// Numbers (row-major) of an array-like argument, keeping position (null for non-numbers).
List<double?> numericCells(Args a, int i) {
  final arr = a.array(i);
  return [
    for (final v in arr.elements)
      switch (v) {
        FNumber(:final v) => v,
        FError() => throw FormulaError(v),
        _ => null,
      },
  ];
}

/// Paired numbers of two same-shaped ranges (pairs with any non-number dropped).
(List<double>, List<double>) pairedNumbers(Args a, int iy, int ix) {
  final ay = a.array(iy), ax = a.array(ix);
  if (ay.length != ax.length) {
    fail(ErrorKind.na, ErrorMessages.arraySizeMismatch(a.fn));
  }
  final ys = <double>[], xs = <double>[];
  for (var k = 0; k < ay.length; k++) {
    final y = ay.atIndex(k), x = ax.atIndex(k);
    if (y is FError) throw FormulaError(y);
    if (x is FError) throw FormulaError(x);
    if (y is FNumber && x is FNumber) {
      ys.add(y.v);
      xs.add(x.v);
    }
  }
  return (ys, xs);
}

double sumOf(Iterable<double> xs) {
  // Neumaier compensated summation for stable totals.
  var s = 0.0, c = 0.0;
  for (final x in xs) {
    final t = s + x;
    if (s.abs() >= x.abs()) {
      c += (s - t) + x;
    } else {
      c += (x - t) + s;
    }
    s = t;
  }
  return s + c;
}

double meanOf(List<double> xs) => sumOf(xs) / xs.length;

/// Sum of squared deviations.
double devSq(List<double> xs) {
  final m = meanOf(xs);
  return sumOf(xs.map((x) => (x - m) * (x - m)));
}

/// Converts a lookup/array argument to a 1-D list with orientation.
List<FValue> vectorOf(FArray a) {
  if (a.rows == 1 || a.cols == 1) return a.elements.toList();
  return a.elements.toList();
}

/// Builds a column array.
FArray columnOf(List<FValue> values) => FArray(values.length, 1, values);

/// Builds a row array.
FArray rowOf(List<FValue> values) => FArray(1, values.length, values);

/// Clamps an int.
int clampInt(int v, int lo, int hi) => math.min(hi, math.max(lo, v));

/// Gets a value of a reference or array argument at position, without materializing.
FValue elementOf(EvalContext ctx, FValue v, int r, int c) =>
    RangeAccess.elementAt(ctx, v, r, c);
