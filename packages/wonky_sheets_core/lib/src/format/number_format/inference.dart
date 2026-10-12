import '../../input/input_parser.dart';
import 'presets.dart';

/// Auto-detection of number formats from typed input (06 §5.9), used by
/// `InputParser`. Detection only applies when the target cell's effective
/// format is Automatic ([appliesTo]).
abstract final class FormatInference {
  /// Detected pattern for scientific input (`1.5E3`).
  static const String scientific = '0.00E+00';

  /// Detected pattern for durations with seconds (`36:15:00`).
  static const String durationWithSeconds = '[h]:mm:ss';

  /// Detected pattern for durations without seconds (`36:15`).
  static const String duration = '[h]:mm';

  /// Whether detection applies to a target cell with [targetFormat].
  static bool appliesTo(String? targetFormat) => NumberFormatPresets.isAutomatic(targetFormat);

  static String _decimals(int n) => n > 0 ? '.${'0' * n}' : '';

  /// Percent with [decimals] as typed (`12%` → `0%`, `12.50%` → `0.00%`).
  static String percent(int decimals, {bool grouped = false}) =>
      '${grouped ? '#,##0' : '0'}${_decimals(decimals)}%';

  /// Grouped number (`1,234` → `#,##0`, `1,234.5` → `#,##0.0`).
  static String grouped(int decimals) => '#,##0${_decimals(decimals)}';

  /// Currency for a typed [symbol] (`$` → `"$"`, others `[$€]`); decimals as
  /// typed, at least 2 when any were typed.
  static String currency(String symbol, int decimals, {bool before = true, bool spaced = false}) {
    final d = decimals == 0 ? 0 : (decimals < 2 ? 2 : decimals);
    final tok = symbol == r'$' ? r'"$"' : '[\$$symbol]';
    final num = '#,##0${_decimals(d)}';
    final sp = spaced ? ' ' : '';
    return before ? '$tok$sp$num' : '$num$sp$tok';
  }

  /// Time of day as typed: `h:mm`, `h:mm:ss`, `h:mm:ss.000`, with ` AM/PM`
  /// when typed with a 12-hour marker.
  static String time({bool seconds = false, bool fraction = false, bool twelveHour = false}) {
    final b = StringBuffer('h:mm');
    if (seconds) b.write(':ss');
    if (seconds && fraction) b.write('.000');
    if (twelveHour) b.write(' AM/PM');
    return b.toString();
  }

  /// Elapsed duration (`[h]:mm` / `[h]:mm:ss`).
  static String elapsed({bool seconds = true}) => seconds ? durationWithSeconds : duration;

  /// ISO date shape (`yyyy-mm-dd`, optionally ` hh:mm` / ` hh:mm:ss`).
  static String isoDate({bool time = false, bool seconds = false}) {
    if (!time) return 'yyyy-mm-dd';
    return seconds ? 'yyyy-mm-dd hh:mm:ss' : 'yyyy-mm-dd hh:mm';
  }

  /// The format detected for typed [input] in [locale], or null (Automatic).
  static String? infer(String input, {String locale = 'en_US', DateTime? today}) =>
      InputParser.instance.parse(input, locale: locale, today: today).autoNumberFormat;
}
