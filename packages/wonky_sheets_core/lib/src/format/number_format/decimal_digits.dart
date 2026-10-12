/// Exact decimal arithmetic on the 15-significant-digit representation of a
/// double (06 §5.3): rounding is half away from zero on the decimal digits,
/// so `2.675` rounds to `2.68` and `1.005` to `1.01`.
library;

/// The magnitude of a finite double as decimal digits:
/// `value = 0.d₁d₂d₃… × 10^point`, i.e. [point] digits stand before the
/// decimal point. Zero has no digits.
final class DecimalDigits {
  /// Creates a digit representation (digits most significant first, no
  /// leading or trailing zeros).
  const DecimalDigits(this.digits, this.point);

  /// Zero.
  static const DecimalDigits zero = DecimalDigits([], 0);

  /// Significant digits (0–9), most significant first; no leading or
  /// trailing zeros. Empty for zero.
  final List<int> digits;

  /// Position of the decimal point relative to the first digit.
  final int point;

  /// Whether the value is zero.
  bool get isZero => digits.isEmpty;

  /// Decimal digits of `|x|` rounded to [precision] significant digits
  /// (default 15). [x] must be finite.
  factory DecimalDigits.of(double x, [int precision = 15]) {
    if (x == 0 || !x.isFinite) return zero;
    final s = x.abs().toStringAsExponential(precision - 1);
    final e = s.indexOf('e');
    final exp = int.parse(s.substring(e + 1));
    final digits = <int>[];
    for (var i = 0; i < e; i++) {
      final c = s.codeUnitAt(i);
      if (c >= 0x30 && c <= 0x39) digits.add(c - 0x30);
    }
    return _normalized(digits, exp + 1);
  }

  /// Parses an unsigned decimal string such as `1234.5` or `.5`.
  factory DecimalDigits.parse(String text) {
    final digits = <int>[];
    var point = -1;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x2e) {
        point = digits.length;
      } else if (c >= 0x30 && c <= 0x39) {
        digits.add(c - 0x30);
      }
    }
    return _normalized(digits, point < 0 ? digits.length : point);
  }

  static DecimalDigits _normalized(List<int> digits, int point) {
    var start = 0;
    while (start < digits.length && digits[start] == 0) {
      start++;
    }
    var end = digits.length;
    while (end > start && digits[end - 1] == 0) {
      end--;
    }
    if (start >= end) return zero;
    if (start == 0 && end == digits.length) return DecimalDigits(digits, point);
    return DecimalDigits(digits.sublist(start, end), point - start);
  }

  /// Multiplies by 10^[n] (exact).
  DecimalDigits shift(int n) => n == 0 || isZero ? this : DecimalDigits(digits, point + n);

  /// Exponent of the leading digit (`floor(log10(value))`); 0 for zero.
  int get leadingExponent => isZero ? 0 : point - 1;

  /// Rounds half away from zero to [decimals] digits after the decimal point
  /// (may be negative to round to tens, hundreds, …).
  DecimalDigits roundToDecimals(int decimals) => _roundKeep(point + decimals);

  /// Rounds half away from zero to [significant] significant digits.
  DecimalDigits roundToSignificant(int significant) => _roundKeep(significant);

  /// Truncates (rounds toward zero) to [decimals] digits after the point.
  DecimalDigits truncateToDecimals(int decimals) {
    final keep = point + decimals;
    if (keep >= digits.length) return this;
    if (keep <= 0) return zero;
    return _normalized(digits.sublist(0, keep), point);
  }

  DecimalDigits _roundKeep(int keep) {
    if (keep >= digits.length) return this;
    if (keep < 0) return zero;
    if (digits[keep] < 5) {
      return keep == 0 ? zero : _normalized(digits.sublist(0, keep), point);
    }
    final kept = keep == 0 ? <int>[] : digits.sublist(0, keep);
    var i = kept.length - 1;
    while (i >= 0 && kept[i] == 9) {
      kept[i] = 0;
      i--;
    }
    if (i >= 0) {
      kept[i]++;
      return _normalized(kept, point);
    }
    return _normalized([1, ...kept], point + 1);
  }

  /// Number of digits before the decimal point (0 for values below 1).
  int get integerDigitCount => point > 0 ? point : 0;

  /// The integer part as a digit string without leading zeros (empty for
  /// values below 1).
  String integerString() {
    if (point <= 0) return '';
    final b = StringBuffer();
    for (var i = 0; i < point; i++) {
      b.writeCharCode(0x30 + (i < digits.length ? digits[i] : 0));
    }
    return b.toString();
  }

  /// The first [count] fraction digits, zero padded.
  String fractionString(int count) {
    if (count <= 0) return '';
    final b = StringBuffer();
    for (var k = 0; k < count; k++) {
      final i = point + k;
      b.writeCharCode(0x30 + (i >= 0 && i < digits.length ? digits[i] : 0));
    }
    return b.toString();
  }

  /// Number of fraction digits needed to represent the value exactly.
  int get fractionDigitCount {
    final n = digits.length - point;
    return n > 0 ? n : 0;
  }

  /// The value as a double (correctly rounded).
  double toDouble({bool negative = false}) {
    if (isZero) return 0;
    final b = StringBuffer(negative ? '-0.' : '0.');
    for (final d in digits) {
      b.writeCharCode(0x30 + d);
    }
    b
      ..write('e')
      ..write(point);
    return double.parse(b.toString());
  }

  /// Plain decimal text (`1234.5`, `0.001`), no grouping.
  String toPlainString() {
    if (isZero) return '0';
    final i = integerString();
    final f = fractionString(fractionDigitCount);
    return '${i.isEmpty ? '0' : i}${f.isEmpty ? '' : '.$f'}';
  }

  @override
  bool operator ==(Object other) =>
      other is DecimalDigits && other.point == point && _listEq(other.digits, digits);

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(point, Object.hashAll(digits));

  @override
  String toString() => 'DecimalDigits(${toPlainString()})';
}

/// Rounds [x] half away from zero to [decimals] decimals using the
/// 15-significant-digit decimal representation (`2.675 → 2.68`).
double roundHalfAwayFromZero(double x, int decimals) {
  if (!x.isFinite) return x;
  final r = DecimalDigits.of(x).roundToDecimals(decimals);
  return r.toDouble(negative: x < 0);
}

/// Rounds [x] to [significant] significant digits (default 15), removing
/// binary floating-point noise (`0.1 + 0.2 → 0.3`).
double roundToSignificantDigits(double x, [int significant = 15]) {
  if (!x.isFinite || x == 0) return x;
  return DecimalDigits.of(x, significant).toDouble(negative: x < 0);
}
