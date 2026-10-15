/// Compact number formatting for trendline equation and R² labels
/// (specs/wonky_sheets/08-charts-and-objects.md §7).
abstract final class StatNumberFormat {
  /// Formats [value] with [significantDigits] significant digits, trailing zeros stripped.
  ///
  /// Values whose rounded magnitude is ≥ 1e6 or < 1e-4 (non-zero) use exponent form with an
  /// upper-case `E`, a sign and at least two exponent digits (`1.234E+05`, `1.2E-07`, `1E+06`);
  /// all others use plain decimal notation (`123500`, `0.0001234`). Zero formats as `0`,
  /// non-finite values as `NaN`, `Infinity` and `-Infinity`.
  static String format(double value, {int significantDigits = 4}) {
    if (significantDigits < 1 || significantDigits > 21) {
      throw RangeError.range(significantDigits, 1, 21, 'significantDigits');
    }
    if (value.isNaN) return 'NaN';
    if (value.isInfinite) return value > 0 ? 'Infinity' : '-Infinity';
    if (value == 0) return '0';
    final negative = value < 0;
    // toStringAsExponential rounds to the requested digits: "d.ddde+x".
    final expForm = value.abs().toStringAsExponential(significantDigits - 1);
    final eIndex = expForm.indexOf('e');
    final digits = expForm.substring(0, eIndex).replaceAll('.', '');
    final exponent = int.parse(expForm.substring(eIndex + 1));
    final body = (exponent >= 6 || exponent < -4)
        ? _exponentForm(digits, exponent)
        : _decimalForm(digits, exponent);
    return negative ? '-$body' : body;
  }

  static String _exponentForm(String digits, int exponent) {
    var mantissa = digits.length == 1
        ? digits
        : '${digits[0]}.${digits.substring(1)}';
    mantissa = _stripFraction(mantissa);
    final sign = exponent < 0 ? '-' : '+';
    final e = exponent.abs().toString().padLeft(2, '0');
    return '${mantissa}E$sign$e';
  }

  static String _decimalForm(String digits, int exponent) {
    final String text;
    if (exponent < 0) {
      text = '0.${'0' * (-exponent - 1)}$digits';
    } else if (exponent >= digits.length - 1) {
      text = digits + '0' * (exponent - digits.length + 1);
    } else {
      text =
          '${digits.substring(0, exponent + 1)}.${digits.substring(exponent + 1)}';
    }
    return _stripFraction(text);
  }

  static String _stripFraction(String text) {
    if (!text.contains('.')) return text;
    var end = text.length;
    while (text.codeUnitAt(end - 1) == 0x30) {
      end--;
    }
    if (text.codeUnitAt(end - 1) == 0x2E) end--;
    return text.substring(0, end);
  }
}
