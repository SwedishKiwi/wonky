import 'dart:math' as math;
import 'dart:typed_data';

import '../../formula/values/dates.dart';

/// A continuous value → pixel mapping.
sealed class ChartScale {
  const ChartScale(this.r0, this.r1);

  /// Pixel position of the domain minimum and maximum.
  final double r0;
  final double r1;

  /// Domain bounds.
  double get min;
  double get max;

  /// Maps a domain value to px (NaN for unmappable values, e.g. ≤ 0 on a log scale).
  double map(double v);

  /// Inverse of [map].
  double invert(double px);

  /// Major tick values.
  Float64List get ticks;

  /// Minor tick values between majors ([perMajor] lines per interval).
  Float64List minorTicks(int perMajor);
}

/// Linear scale.
final class LinearScale extends ChartScale {
  /// Creates a scale mapping [min]..[max] to [r0]..[r1].
  LinearScale(this.min, this.max, super.r0, super.r1, {Float64List? ticks})
    : ticks = ticks ?? Float64List(0);

  @override
  final double min;
  @override
  final double max;
  @override
  final Float64List ticks;

  @override
  double map(double v) =>
      max == min ? (r0 + r1) / 2 : r0 + (v - min) / (max - min) * (r1 - r0);

  @override
  double invert(double px) =>
      r1 == r0 ? min : min + (px - r0) / (r1 - r0) * (max - min);

  @override
  Float64List minorTicks(int perMajor) {
    if (ticks.length < 2 || perMajor < 1) return Float64List(0);
    final step = ticks[1] - ticks[0];
    final out = <double>[];
    final sub = step / (perMajor + 1);
    for (var t = ticks.first - step; t <= ticks.last + step; t += step) {
      for (var k = 1; k <= perMajor; k++) {
        final v = t + k * sub;
        if (v > min && v < max) out.add(v);
      }
    }
    return Float64List.fromList(out);
  }
}

/// Base-10 log scale.
final class LogScale extends ChartScale {
  /// Creates a scale; [min] must be > 0.
  LogScale(this.min, this.max, super.r0, super.r1, {Float64List? ticks})
    : ticks = ticks ?? Float64List(0);

  @override
  final double min;
  @override
  final double max;
  @override
  final Float64List ticks;

  double get _l0 => math.log(min) / math.ln10;
  double get _l1 => math.log(max) / math.ln10;

  @override
  double map(double v) {
    if (!(v > 0)) return double.nan;
    final l = math.log(v) / math.ln10;
    return _l1 == _l0
        ? (r0 + r1) / 2
        : r0 + (l - _l0) / (_l1 - _l0) * (r1 - r0);
  }

  @override
  double invert(double px) =>
      math.pow(10, _l0 + (px - r0) / (r1 - r0) * (_l1 - _l0)).toDouble();

  @override
  Float64List minorTicks(int perMajor) {
    final out = <double>[];
    for (var e = _l0.floor(); e <= _l1.ceil(); e++) {
      final base = math.pow(10, e).toDouble();
      for (var m = 2; m <= 9; m++) {
        final v = base * m;
        if (v > min && v < max && !ticks.contains(v)) out.add(v);
      }
    }
    return Float64List.fromList(out);
  }
}

/// Discrete bands (categorical domain).
final class BandScale {
  /// Creates [count] bands over [r0]..[r1].
  const BandScale(this.count, this.r0, this.r1);

  final int count;
  final double r0;
  final double r1;

  /// Width of one band (signed when reversed).
  double get step => count == 0 ? 0 : (r1 - r0) / count;

  /// Absolute band width.
  double get bandWidth => step.abs();

  /// Center of band [i].
  double center(int i) => r0 + (i + 0.5) * step;

  /// Start edge of band [i] (smaller px of the band).
  double start(int i) => math.min(r0 + i * step, r0 + (i + 1) * step);

  /// Band index at [px] or -1.
  int indexAt(double px) {
    if (count == 0 || step == 0) return -1;
    final i = ((px - r0) / step).floor();
    return i < 0 || i >= count ? -1 : i;
  }
}

/// A nice tick range.
final class NiceRange {
  /// Creates a range.
  const NiceRange(this.min, this.max, this.step, this.ticks, this.decimals);

  final double min;
  final double max;
  final double step;
  final Float64List ticks;

  /// Fraction digits needed to print the ticks.
  final int decimals;
}

/// The nice-number tick algorithm (Heckbert, with 1/2/2.5/5 steps).
abstract final class NiceTicks {
  /// Nice step ≥ [raw] from 1, 2, 2.5, 5 × 10ᵏ.
  static double niceStep(double raw) {
    if (!(raw > 0) || !raw.isFinite) return 1;
    final e = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / e;
    final m = f <= 1 + 1e-9
        ? 1.0
        : f <= 2 + 1e-9
        ? 2.0
        : f <= 2.5 + 1e-9
        ? 2.5
        : f <= 5 + 1e-9
        ? 5.0
        : 10.0;
    return m * e;
  }

  /// Decimals needed for multiples of [step].
  static int decimalsFor(double step) {
    if (!(step > 0)) return 0;
    for (var d = 0; d <= 12; d++) {
      final scaled = step * math.pow(10, d);
      if ((scaled - scaled.roundToDouble()).abs() <
          1e-6 * math.max(1, scaled.abs())) {
        return d;
      }
    }
    return 12;
  }

  /// Ticks covering [lo]..[hi] with about [target] ticks. [fixedMin]/[fixedMax] pin the axis
  /// ends (ticks inside); [count] asks for that many major lines; [spacing] fixes the step.
  static NiceRange compute(
    double lo,
    double hi, {
    int target = 5,
    double? fixedMin,
    double? fixedMax,
    int? count,
    double? spacing,
  }) {
    var a = fixedMin ?? lo;
    var b = fixedMax ?? hi;
    if (!a.isFinite || !b.isFinite) {
      a = 0;
      b = 1;
    }
    if (a > b) {
      final t = a;
      a = b;
      b = t;
    }
    if (a == b) {
      if (a == 0) {
        b = 1;
      } else {
        final d = a.abs() * 0.1;
        if (fixedMin == null) a -= d;
        if (fixedMax == null) b += d;
        if (a == b) b = a + 1;
      }
    }
    final wanted = count != null && count >= 2 ? count : math.max(2, target);
    double step;
    if (spacing != null && spacing > 0) {
      step = spacing;
      if ((b - a) / step > 1000) step = niceStep((b - a) / 1000);
    } else {
      step = niceStep((b - a) / (wanted - 1));
    }
    final niceMin = fixedMin ?? (a / step).floor() * step;
    final niceMax = fixedMax ?? (b / step).ceil() * step;
    final decimals = decimalsFor(step);
    final ticks = <double>[];
    final first = (niceMin / step - 1e-9).ceil();
    final last = (niceMax / step + 1e-9).floor();
    for (var i = first; i <= last && ticks.length < 1001; i++) {
      ticks.add(_clean(i * step, decimals));
    }
    return NiceRange(
      _clean(niceMin, decimals + 2),
      _clean(niceMax, decimals + 2),
      step,
      Float64List.fromList(ticks),
      decimals,
    );
  }

  /// Log-scale ticks (decades, plus 2 and 5 when fewer than 3 decades).
  static NiceRange log(double lo, double hi) {
    var a = lo > 0 ? lo : 1.0;
    var b = hi > a ? hi : a * 10;
    final e0 = (math.log(a) / math.ln10 + 1e-9).floor();
    final e1 = (math.log(b) / math.ln10 - 1e-9).ceil();
    a = math.pow(10, e0).toDouble();
    b = math.pow(10, math.max(e1, e0 + 1)).toDouble();
    final ticks = <double>[];
    final decades = math.max(e1, e0 + 1) - e0;
    for (var e = e0; e <= e0 + decades; e++) {
      final base = math.pow(10, e).toDouble();
      ticks.add(base);
      if (decades < 3 && e < e0 + decades) {
        ticks
          ..add(base * 2)
          ..add(base * 5);
      }
    }
    return NiceRange(a, b, 10, Float64List.fromList(ticks), e0 < 0 ? -e0 : 0);
  }

  static double _clean(double v, int decimals) {
    final d = decimals.clamp(0, 15);
    final r = double.parse(v.toStringAsFixed(d));
    return r == 0 ? 0 : r;
  }
}

/// Calendar ticks for date/time axes (values are spreadsheet date serials).
abstract final class TimeTicks {
  static const _sec = 1 / 86400;
  static const _units = <(double days, String pattern)>[
    (_sec, 'h:mm:ss'),
    (5 * _sec, 'h:mm:ss'),
    (15 * _sec, 'h:mm:ss'),
    (30 * _sec, 'h:mm:ss'),
    (60 * _sec, 'h:mm'),
    (300 * _sec, 'h:mm'),
    (900 * _sec, 'h:mm'),
    (1800 * _sec, 'h:mm'),
    (1 / 24, 'h:mm'),
    (3 / 24, 'h:mm'),
    (6 / 24, 'h:mm'),
    (12 / 24, 'mmm d h:mm'),
    (1, 'mmm d'),
    (2, 'mmm d'),
    (7, 'mmm d'),
    (14, 'mmm d'),
  ];

  /// Ticks within [lo]..[hi] with at most about [target] ticks and the number format pattern to
  /// label them.
  static (Float64List ticks, String pattern) compute(
    double lo,
    double hi,
    int target,
  ) {
    final span = hi - lo;
    final t = math.max(2, target);
    if (!(span > 0)) return (Float64List.fromList([lo]), 'yyyy-mm-dd');
    for (final (step, pattern) in _units) {
      if (span / step <= t) {
        final out = <double>[];
        // Weeks start on Sunday (serial 1 = Sunday 1899-12-31).
        final origin = step == 7 || step == 14 ? 1.0 : 0.0;
        var v = ((lo - origin) / step).ceil() * step + origin;
        while (v <= hi + 1e-9 && out.length < 500) {
          out.add(double.parse(v.toStringAsFixed(9)));
          v += step;
        }
        return (Float64List.fromList(out), pattern);
      }
    }
    // Months and years.
    final a = DateSerial.toYmd(lo);
    final months = span / 30.44;
    for (final (m, pattern) in const [
      (1, 'mmm yyyy'),
      (3, 'mmm yyyy'),
      (6, 'mmm yyyy'),
    ]) {
      if (months / m <= t) {
        final out = <double>[];
        var y = a.year, mo = a.month;
        // First month boundary ≥ lo aligned to the step.
        mo = ((mo - 1) ~/ m) * m + 1;
        while (out.length < 500) {
          final s = DateSerial.fromYmd(y, mo, 1).toDouble();
          if (s > hi + 1e-9) break;
          if (s >= lo - 1e-9) out.add(s);
          mo += m;
          while (mo > 12) {
            mo -= 12;
            y++;
          }
        }
        if (out.isNotEmpty) return (Float64List.fromList(out), pattern);
      }
    }
    final years = span / 365.25;
    final yStep = math.max(1, NiceTicks.niceStep(years / (t - 1)).ceil());
    final out = <double>[];
    var y = (a.year / yStep).ceil() * yStep;
    while (out.length < 500) {
      final s = DateSerial.fromYmd(y, 1, 1).toDouble();
      if (s > hi + 1e-9) break;
      if (s >= lo - 1e-9) out.add(s);
      y += yStep;
    }
    if (out.isEmpty) out.add(lo);
    return (Float64List.fromList(out), 'yyyy');
  }
}
