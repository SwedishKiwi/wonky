import 'dart:math' as math;

/// Decimal digits of a finite double at 15 significant digits: value = 0.d1d2… × 10^[point],
/// i.e. [point] digits are before the decimal point.
final class _Dec {
  final bool negative;
  final List<int> digits; // no leading zeros (empty = zero)
  final int point;
  const _Dec(this.negative, this.digits, this.point);

  static _Dec of(double x, [int precision = 15]) {
    if (x == 0) return const _Dec(false, [], 0);
    final neg = x < 0;
    final s = x.abs().toStringAsPrecision(precision);
    var mantissa = s;
    var exp = 0;
    final e = s.indexOf('e');
    if (e >= 0) {
      mantissa = s.substring(0, e);
      exp = int.parse(s.substring(e + 1));
    }
    final dot = mantissa.indexOf('.');
    final intPart = dot < 0 ? mantissa : mantissa.substring(0, dot);
    final fracPart = dot < 0 ? '' : mantissa.substring(dot + 1);
    final all = '$intPart$fracPart';
    var point = intPart.length + exp;
    var start = 0;
    while (start < all.length && all.codeUnitAt(start) == 0x30) {
      start++;
      point--;
    }
    var end = all.length;
    while (end > start && all.codeUnitAt(end - 1) == 0x30) {
      end--;
    }
    if (start >= end) return _Dec(neg, const [], 0);
    final digits = [for (var i = start; i < end; i++) all.codeUnitAt(i) - 0x30];
    return _Dec(neg, digits, point);
  }

  double toDouble() {
    if (digits.isEmpty) return 0;
    final b = StringBuffer(negative ? '-0.' : '0.');
    for (final d in digits) {
      b.writeCharCode(0x30 + d);
    }
    b
      ..write('e')
      ..write(point);
    return double.parse(b.toString());
  }

  /// Keeps [keep] digits (from the left), rounding per [mode].
  _Dec roundTo(int keep, _RoundMode mode) {
    if (keep >= digits.length) return this;
    if (keep < 0) {
      if (mode == _RoundMode.up && digits.isNotEmpty) {
        return _Dec(negative, const [1], point - keep);
      }
      return _Dec(negative, const [], 0);
    }
    final kept = digits.sublist(0, keep);
    var increment = false;
    switch (mode) {
      case _RoundMode.halfAway:
        increment = digits[keep] >= 5;
      case _RoundMode.up:
        increment = digits.skip(keep).any((d) => d != 0);
      case _RoundMode.down:
        increment = false;
    }
    var newPoint = point;
    if (increment) {
      var i = kept.length - 1;
      while (i >= 0) {
        if (kept[i] == 9) {
          kept[i] = 0;
          i--;
        } else {
          kept[i]++;
          break;
        }
      }
      if (i < 0) {
        kept.insert(0, 1);
        newPoint++;
      }
    }
    while (kept.isNotEmpty && kept.last == 0) {
      kept.removeLast();
    }
    if (kept.isEmpty) return _Dec(negative, const [], 0);
    return _Dec(negative, kept, newPoint);
  }
}

enum _RoundMode { halfAway, up, down }

/// Numeric helpers with Sheets/Excel semantics (05 §6.4–6.5).
abstract final class Numeric {
  /// 2⁻⁴⁹, relative tolerance for equality and cancellation snapping.
  static final double epsilon = math.pow(2, -49).toDouble();

  /// `a == b` within the relative tolerance.
  static bool approxEqual(double a, double b) {
    if (a == b) return true;
    final m = math.max(a.abs(), b.abs());
    return (a - b).abs() <= epsilon * m;
  }

  /// Three-way compare with tolerance.
  static int compare(double a, double b) {
    if (approxEqual(a, b)) return 0;
    return a < b ? -1 : 1;
  }

  /// `a + b` with cancellation snapping to 0.
  static double add(double a, double b) {
    final r = a + b;
    if (r == 0) return 0;
    final m = math.max(a.abs(), b.abs());
    if (r.abs() <= epsilon * m) return 0;
    return r;
  }

  /// `a - b` with cancellation snapping to 0.
  static double sub(double a, double b) => add(a, -b);

  /// Rounds half away from zero at [places] decimals (negative = left of the point), decimal
  /// correct on the 15-significant-digit representation.
  static double roundHalfAway(double x, int places) =>
      _round(x, places, _RoundMode.halfAway);

  /// Rounds away from zero.
  static double roundUp(double x, int places) =>
      _round(x, places, _RoundMode.up);

  /// Rounds toward zero (truncate).
  static double roundDown(double x, int places) =>
      _round(x, places, _RoundMode.down);

  static double _round(double x, int places, _RoundMode mode) {
    if (!x.isFinite || x == 0) return x;
    if (places > 300) return x;
    if (places < -308) return mode == _RoundMode.up ? x : 0.0;
    final d = _Dec.of(x);
    final keep = d.point + places;
    final r = d.roundTo(keep, mode).toDouble();
    return r == 0 ? 0.0 : r;
  }

  /// Rounds to [digits] significant digits (`stabilize` for transcendental results, §12).
  static double roundSignificant(double x, int digits) {
    if (!x.isFinite || x == 0) return x;
    return double.parse(x.toStringAsPrecision(digits));
  }

  /// Removes last-ulp platform differences of transcendental functions (05 §12).
  static double stabilize(double x) => roundSignificant(x, 15);

  /// Number → text with at most 15 significant digits, no grouping (05 §6.3).
  static String toText(double x, {String decimal = '.'}) {
    if (x.isNaN) return 'NaN';
    if (x.isInfinite) return x > 0 ? 'Infinity' : '-Infinity';
    if (x == 0) return '0';
    if (x == x.truncateToDouble() && x.abs() < 1e15) {
      return x.toInt().toString();
    }
    final d = _Dec.of(x);
    final digits = d.digits;
    final sciExp = d.point - 1;
    final b = StringBuffer();
    if (d.negative) b.write('-');
    if (sciExp >= 15 || sciExp < -9) {
      b.writeCharCode(0x30 + digits[0]);
      if (digits.length > 1) {
        b.write(decimal);
        for (var i = 1; i < digits.length; i++) {
          b.writeCharCode(0x30 + digits[i]);
        }
      }
      b
        ..write('E')
        ..write(sciExp < 0 ? '-' : '+')
        ..write(sciExp.abs().toString().padLeft(2, '0'));
      return b.toString();
    }
    if (d.point <= 0) {
      b.write('0');
      b.write(decimal);
      for (var i = 0; i < -d.point; i++) {
        b.write('0');
      }
      for (final dg in digits) {
        b.writeCharCode(0x30 + dg);
      }
      return b.toString();
    }
    for (var i = 0; i < d.point; i++) {
      b.writeCharCode(0x30 + (i < digits.length ? digits[i] : 0));
    }
    if (digits.length > d.point) {
      b.write(decimal);
      for (var i = d.point; i < digits.length; i++) {
        b.writeCharCode(0x30 + digits[i]);
      }
    }
    return b.toString();
  }

  /// Whether [x] is an integer value.
  static bool isInteger(double x) => x.isFinite && x == x.truncateToDouble();

  /// Truncates toward zero, safe for large values.
  static int truncInt(double x) {
    if (!x.isFinite) return 0;
    if (x.abs() > 9007199254740992) {
      return x < 0 ? -9007199254740992 : 9007199254740992;
    }
    return x.truncate();
  }

  /// Floor as int, safe for large values.
  static int floorInt(double x) {
    if (!x.isFinite) return 0;
    if (x.abs() > 9007199254740992) {
      return x < 0 ? -9007199254740992 : 9007199254740992;
    }
    return x.floor();
  }
}
