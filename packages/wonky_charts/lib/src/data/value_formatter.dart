import 'package:wonky_numfmt/wonky_numfmt.dart';

/// Formats numbers for axis labels, data labels, tooltips and table charts (08 §6.6).
abstract interface class ChartValueFormatter {
  /// Formats [value] with [numberFormat] (pattern or `preset:*`; null = Automatic).
  String format(double value, String? numberFormat);
}

/// The default formatter: the spreadsheet number-format engine (`wonky_numfmt`) in [locale].
final class DefaultChartValueFormatter implements ChartValueFormatter {
  /// Creates a formatter for [locale] (`Spreadsheet.locale`).
  const DefaultChartValueFormatter({this.locale = 'en_US', this._formatter});

  final String locale;
  final NumberPatternFormatter? _formatter;

  @override
  String format(double value, String? numberFormat) {
    if (value.isNaN) return '';
    return (_formatter ?? NumberPatternFormatter.instance).formatNumberText(
      value,
      numberFormat,
      locale: locale,
    );
  }
}

/// Helpers for number format patterns used by charts.
abstract final class ChartFormats {
  /// Whether [pattern] displays dates or times (`preset:date`, `yyyy-mm-dd`, `h:mm`, …);
  /// durations (`[h]:mm`) are not date/time.
  static bool isDateTime(String? pattern) {
    if (pattern == null || pattern.isEmpty) return false;
    if (pattern.startsWith('preset:')) {
      return pattern == 'preset:date' ||
          pattern == 'preset:time' ||
          pattern == 'preset:dateTime';
    }
    var inQuote = false;
    for (var i = 0; i < pattern.length; i++) {
      final c = pattern[i];
      if (c == '"') {
        inQuote = !inQuote;
        continue;
      }
      if (inQuote) continue;
      if (c == '\\') {
        i++;
        continue;
      }
      if (c == '[') {
        final end = pattern.indexOf(']', i);
        if (end < 0) return false;
        final inner = pattern.substring(i + 1, end).toLowerCase();
        if (inner == 'h' ||
            inner == 'hh' ||
            inner == 'm' ||
            inner == 'mm' ||
            inner == 's' ||
            inner == 'ss') {
          return false; // elapsed time
        }
        i = end;
        continue;
      }
      final l = c.toLowerCase();
      if (l == 'y' || l == 'd' || l == 'h' || l == 's') return true;
    }
    return false;
  }

  /// Whether [pattern] is a percent format.
  static bool isPercent(String? pattern) {
    if (pattern == null || pattern.startsWith('preset:')) return false;
    var inQuote = false;
    for (var i = 0; i < pattern.length; i++) {
      final c = pattern[i];
      if (c == '"') inQuote = !inQuote;
      if (!inQuote && c == '%') return true;
      if (!inQuote && c == '\\') i++;
    }
    return false;
  }

  /// An Automatic-like pattern for axis ticks with [decimals] fraction digits (`#,##0.00`).
  static String tickPattern(int decimals, {bool percent = false}) {
    final base = decimals <= 0 ? '#,##0' : '#,##0.${'0' * decimals}';
    return percent ? (decimals <= 0 ? '0%' : '0.${'0' * decimals}%') : base;
  }
}
