import 'decimal_digits.dart';
import 'locale_data.dart';

/// Automatic / `General` display of numbers (06 §5.9):
/// - integers with |x| < 10¹⁵ → all digits, no grouping;
/// - other numbers → 10 significant digits (integer digits are never
///   dropped), trailing zeros trimmed;
/// - |x| ≥ 10¹⁵ or 0 < |x| < 10⁻⁹ → scientific with up to 5 decimals.
abstract final class AutomaticFormatter {
  /// Significant digits shown for non-integers.
  static const int significantDigits = 10;

  /// Maximum mantissa decimals in automatic scientific display.
  static const int scientificDecimals = 5;

  /// Formats [value] for display in [locale].
  static String format(double value, {String locale = 'en_US'}) =>
      formatWith(value, LocaleFormatData.forId(locale));

  /// Formats [value] with locale data [locale].
  static String formatWith(double value, LocaleFormatData locale) {
    if (!value.isFinite) return '#NUM!';
    if (value == 0) return '0';
    if (_isScientific(value)) return scientific(value, scientificDecimals, locale);
    if (value == value.truncateToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return _plain(_rounded(value), value < 0, locale);
  }

  static bool _isScientific(double v) {
    final a = v.abs();
    return a >= 1e15 || (a > 0 && a < 1e-9);
  }

  static DecimalDigits _rounded(double value) {
    final d = DecimalDigits.of(value);
    return d.point >= significantDigits
        ? d.roundToDecimals(0)
        : d.roundToSignificant(significantDigits);
  }

  static String _plain(DecimalDigits d, bool negative, LocaleFormatData locale) {
    if (d.isZero) return '0';
    final i = d.integerString();
    final fd = d.fractionDigitCount;
    final b = StringBuffer();
    if (negative) b.write(locale.minus);
    b.write(i.isEmpty ? '0' : i);
    if (fd > 0) {
      b
        ..write(locale.decimal)
        ..write(d.fractionString(fd));
    }
    return b.toString();
  }

  /// Number of decimals shown by automatic display of [value] (0 for
  /// integers; mantissa decimals when the display is scientific).
  static int displayedDecimals(double value) {
    if (!value.isFinite || value == 0) return 0;
    if (_isScientific(value)) {
      final m = DecimalDigits.of(value).roundToSignificant(scientificDecimals + 1);
      return m.digits.length - 1;
    }
    if (value == value.truncateToDouble() && value.abs() < 1e15) return 0;
    return _rounded(value).fractionDigitCount;
  }

  /// Whether automatic display of [value] uses scientific notation.
  static bool isScientificDisplay(double value) => value.isFinite && _isScientific(value);

  /// [value] in scientific notation with at most [maxDecimals] mantissa
  /// decimals (trailing zeros trimmed) and a two-digit exponent (`1.23E+04`).
  static String scientific(double value, int maxDecimals, LocaleFormatData locale) {
    if (value == 0) return '0E+00';
    var m = DecimalDigits.of(value).roundToSignificant(maxDecimals + 1);
    final exp = m.point - 1;
    m = m.shift(-exp);
    final b = StringBuffer();
    if (value < 0) b.write(locale.minus);
    b.write(m.integerString());
    final fd = m.fractionDigitCount;
    if (fd > 0) {
      b
        ..write(locale.decimal)
        ..write(m.fractionString(fd));
    }
    b
      ..write(locale.exponent)
      ..write(exp < 0 ? '-' : '+')
      ..write(exp.abs().toString().padLeft(2, '0'));
    return b.toString();
  }

  /// The automatic display of [value] that fits [maxWidthPx] as measured by
  /// [measure]: decimals are reduced (down to 0), then scientific notation
  /// is tried, then `#` characters (as many as fit, at least one).
  static String fit(
    double value,
    double maxWidthPx,
    double Function(String text) measure, {
    String locale = 'en_US',
  }) {
    final loc = LocaleFormatData.forId(locale);
    final full = formatWith(value, loc);
    if (measure(full) <= maxWidthPx) return full;
    if (value.isFinite && !_isScientific(value)) {
      final d = DecimalDigits.of(value);
      final shown = _rounded(value).fractionDigitCount;
      for (var dec = shown - 1; dec >= 0; dec--) {
        final t = _plain(d.roundToDecimals(dec), value < 0, loc);
        if (t == '0' || t == '${loc.minus}0') break;
        if (measure(t) <= maxWidthPx) return t;
      }
    }
    if (value.isFinite && value != 0) {
      for (var dec = scientificDecimals; dec >= 0; dec--) {
        final t = scientific(value, dec, loc);
        if (measure(t) <= maxWidthPx) return t;
      }
    }
    var hashes = '#';
    while (hashes.length < 64 && measure('$hashes#') <= maxWidthPx) {
      hashes = '$hashes#';
    }
    return hashes;
  }
}
