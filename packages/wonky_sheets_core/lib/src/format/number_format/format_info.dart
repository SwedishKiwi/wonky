import 'ast.dart';
import 'parser.dart';
import 'presets.dart';

/// Kind of a number format, from its first (positive) section.
enum NumberFormatKind {
  /// Automatic / General (also invalid patterns).
  automatic,

  /// Plain number (`#,##0.00`).
  number,

  /// Percent (`0.00%`).
  percent,

  /// Currency (`"$"#,##0.00`, `[$€]…`).
  currency,

  /// Scientific (`0.00E+00`).
  scientific,

  /// Fraction (`# ?/?`).
  fraction,

  /// Date only.
  date,

  /// Time of day only.
  time,

  /// Date and time.
  dateTime,

  /// Elapsed time (`[h]:mm:ss`).
  duration,

  /// Text (`@`).
  text,
}

/// Classification of a number format (toolbar state, fill series, format
/// hints, exporters).
final class NumberFormatInfo {
  const NumberFormatInfo._(this.kind, this.decimals, this.grouping, this.valid, this.pattern);

  /// Kind.
  final NumberFormatKind kind;

  /// Decimal placeholders of the first numeric section (fractional-second
  /// digits for times).
  final int decimals;

  /// Whether the first numeric section groups thousands.
  final bool grouping;

  /// Whether the pattern parses.
  final bool valid;

  /// The resolved pattern (null for Automatic).
  final String? pattern;

  /// Whether values display as dates (date or date time).
  bool get isDateLike => kind == NumberFormatKind.date || kind == NumberFormatKind.dateTime;

  /// Whether values display as a time of day or duration.
  bool get isTimeLike => kind == NumberFormatKind.time || kind == NumberFormatKind.duration;

  /// Whether values display as any date/time/duration.
  bool get isDateOrTime => isDateLike || isTimeLike;

  /// Whether the kind is [NumberFormatKind.percent].
  bool get isPercent => kind == NumberFormatKind.percent;

  /// Whether the kind is [NumberFormatKind.currency].
  bool get isCurrency => kind == NumberFormatKind.currency;

  static const NumberFormatInfo _automatic = NumberFormatInfo._(
    NumberFormatKind.automatic,
    0,
    false,
    true,
    null,
  );

  static final Map<(String, String), NumberFormatInfo> _cache = {};

  /// Info for a stored format (pattern or preset id) in [locale].
  static NumberFormatInfo of(String? format, {String locale = 'en_US'}) {
    if (NumberFormatPresets.isAutomatic(format)) return _automatic;
    final key = (format!, locale);
    final cached = _cache[key];
    if (cached != null) return cached;
    final info = _compute(NumberFormatPresets.resolve(format, locale));
    if (_cache.length > 4096) _cache.clear();
    _cache[key] = info;
    return info;
  }

  /// Whether [format] displays dates.
  static bool isDatePattern(String? format, {String locale = 'en_US'}) =>
      of(format, locale: locale).isDateLike;

  /// Whether [format] displays a time of day or a duration.
  static bool isTimePattern(String? format, {String locale = 'en_US'}) =>
      of(format, locale: locale).isTimeLike;

  /// Whether [format] is a percent format.
  static bool isPercentPattern(String? format, {String locale = 'en_US'}) =>
      of(format, locale: locale).isPercent;

  /// Whether [format] is a currency format.
  static bool isCurrencyPattern(String? format, {String locale = 'en_US'}) =>
      of(format, locale: locale).isCurrency;

  static const Set<String> _currencySymbols = {
    r'$', '€', '£', '¥', '₹', '₩', '₽', '₺', '₪', '₫', '฿', '₴', '₱', '₦', '¢', 'kr', 'zł', //
    'CHF', 'Kč', 'Ft', 'R', r'R$', 'lei', 'лв', 'USD', 'EUR', 'GBP', 'JPY',
  };

  static NumberFormatInfo _compute(String? pattern) {
    if (pattern == null) return _automatic;
    final ast = NumberFormatParser.tryParse(pattern);
    if (ast == null) {
      return NumberFormatInfo._(NumberFormatKind.automatic, 0, false, false, pattern);
    }
    final sections = ast.numberSections;
    if (sections.isEmpty) {
      return NumberFormatInfo._(NumberFormatKind.text, 0, false, true, pattern);
    }
    final s = sections.first;
    switch (s.kind) {
      case NfSectionKind.general || NfSectionKind.empty || NfSectionKind.literal:
        return NumberFormatInfo._(NumberFormatKind.automatic, 0, false, true, pattern);
      case NfSectionKind.text:
        return NumberFormatInfo._(NumberFormatKind.text, 0, false, true, pattern);
      case NfSectionKind.fraction:
        return NumberFormatInfo._(NumberFormatKind.fraction, 0, false, true, pattern);
      case NfSectionKind.scientific:
        return NumberFormatInfo._(
          NumberFormatKind.scientific,
          s.layout!.decimalPlaceholders,
          false,
          true,
          pattern,
        );
      case NfSectionKind.dateTime:
        var date = false;
        var time = false;
        var elapsed = false;
        var frac = 0;
        for (final t in s.tokens) {
          switch (t) {
            case NfDatePart(:final unit):
              if (unit == NfDateUnit.day ||
                  unit == NfDateUnit.weekday ||
                  unit == NfDateUnit.month ||
                  unit == NfDateUnit.year) {
                date = true;
              } else {
                time = true;
              }
            case NfElapsed():
              elapsed = true;
            case NfAmPm():
              time = true;
            case NfFractionalSeconds(:final digits):
              frac = digits;
            default:
              break;
          }
        }
        final kind = elapsed
            ? NumberFormatKind.duration
            : date && time
            ? NumberFormatKind.dateTime
            : date
            ? NumberFormatKind.date
            : NumberFormatKind.time;
        return NumberFormatInfo._(kind, frac, false, true, pattern);
      case NfSectionKind.number:
        final l = s.layout!;
        var kind = NumberFormatKind.number;
        for (final t in s.tokens) {
          if (t is NfPercent) {
            kind = NumberFormatKind.percent;
            break;
          }
          if (t is NfLocaleTag && t.symbol.isNotEmpty) kind = NumberFormatKind.currency;
          if (t is NfLiteral && _currencySymbols.contains(t.text.trim())) {
            kind = NumberFormatKind.currency;
          }
        }
        return NumberFormatInfo._(kind, l.decimalPlaceholders, l.grouping, true, pattern);
    }
  }

  @override
  String toString() => 'NumberFormatInfo(${kind.name}, decimals: $decimals)';
}
