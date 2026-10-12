import 'dart:math' as math;

import '../content/cell_content.dart';
import 'pivot_spec.dart';

/// A streaming aggregator of one pivot value cell (07 §7.4 step 3) with the
/// formula library's range semantics: numeric aggregates use numbers only
/// (text, booleans and blanks ignored) and propagate the first error;
/// COUNT/COUNTA/COUNTUNIQUE never propagate errors.
abstract class Aggregator {
  /// Creates the aggregator for [by] (custom → SUM of evaluated results).
  factory Aggregator.create(PivotSummarize by) => switch (by) {
    PivotSummarize.sum || PivotSummarize.custom => _Sum(),
    PivotSummarize.counta => _CountA(),
    PivotSummarize.count => _Count(),
    PivotSummarize.countunique => _CountUnique(),
    PivotSummarize.average => _Average(),
    PivotSummarize.max => _MinMax(true),
    PivotSummarize.min => _MinMax(false),
    PivotSummarize.median => _Median(),
    PivotSummarize.product => _Product(),
    PivotSummarize.stdev => _Welford(sample: true, sqrt: true),
    PivotSummarize.stdevp => _Welford(sample: false, sqrt: true),
    PivotSummarize.variance => _Welford(sample: true, sqrt: false),
    PivotSummarize.variancep => _Welford(sample: false, sqrt: false),
  };

  Aggregator._();

  /// Adds one source value.
  void add(CellValue v);

  /// The aggregated value.
  CellValue get result;
}

abstract class _Numeric extends Aggregator {
  _Numeric() : super._();
  ErrorValue? error;

  void addNumber(double x);

  @override
  void add(CellValue v) {
    if (error != null) return;
    switch (v) {
      case NumberValue(:final number):
        addNumber(number);
      case ErrorValue():
        error = v;
      default:
        break;
    }
  }

  CellValue numeric();

  @override
  CellValue get result => error ?? numeric();
}

final class _Sum extends _Numeric {
  double sum = 0;
  @override
  void addNumber(double x) => sum += x;
  @override
  CellValue numeric() => NumberValue(sum);
}

final class _Product extends _Numeric {
  double p = 1;
  int n = 0;
  @override
  void addNumber(double x) {
    p *= x;
    n++;
  }

  @override
  CellValue numeric() => NumberValue(n == 0 ? 0 : p);
}

final class _Average extends _Numeric {
  double sum = 0;
  int n = 0;
  @override
  void addNumber(double x) {
    sum += x;
    n++;
  }

  @override
  CellValue numeric() => n == 0 ? const ErrorValue(CellErrorKind.div0) : NumberValue(sum / n);
}

final class _MinMax extends _Numeric {
  _MinMax(this.isMax);
  final bool isMax;
  double? best;
  @override
  void addNumber(double x) {
    final b = best;
    if (b == null || (isMax ? x > b : x < b)) best = x;
  }

  @override
  CellValue numeric() => NumberValue(best ?? 0);
}

final class _Median extends _Numeric {
  final List<double> xs = [];
  @override
  void addNumber(double x) => xs.add(x);
  @override
  CellValue numeric() {
    if (xs.isEmpty) return const ErrorValue(CellErrorKind.num);
    xs.sort();
    final m = xs.length ~/ 2;
    return NumberValue(xs.length.isOdd ? xs[m] : (xs[m - 1] + xs[m]) / 2);
  }
}

/// Welford's online variance.
final class _Welford extends _Numeric {
  _Welford({required this.sample, required this.sqrt});
  final bool sample;
  final bool sqrt;
  int n = 0;
  double mean = 0;
  double m2 = 0;

  @override
  void addNumber(double x) {
    n++;
    final d = x - mean;
    mean += d / n;
    m2 += d * (x - mean);
  }

  @override
  CellValue numeric() {
    final denom = sample ? n - 1 : n;
    if (denom <= 0) return const ErrorValue(CellErrorKind.div0);
    final v = m2 / denom;
    return NumberValue(sqrt ? math.sqrt(v) : v);
  }
}

final class _CountA extends Aggregator {
  _CountA() : super._();
  int n = 0;
  @override
  void add(CellValue v) {
    if (v is! EmptyValue) n++;
  }

  @override
  CellValue get result => NumberValue(n.toDouble());
}

final class _Count extends Aggregator {
  _Count() : super._();
  int n = 0;
  @override
  void add(CellValue v) {
    if (v is NumberValue) n++;
  }

  @override
  CellValue get result => NumberValue(n.toDouble());
}

final class _CountUnique extends Aggregator {
  _CountUnique() : super._();
  final Set<Object> seen = {};
  @override
  void add(CellValue v) {
    if (v.isBlank()) return;
    seen.add(switch (v) {
      NumberValue(:final number) => number == 0 ? 0.0 : number,
      TextValue(:final text) => 't:$text',
      BoolValue(:final value) => value,
      ErrorValue(:final kind) => kind,
      EmptyValue() => 0,
    });
  }

  @override
  CellValue get result => NumberValue(seen.length.toDouble());
}
