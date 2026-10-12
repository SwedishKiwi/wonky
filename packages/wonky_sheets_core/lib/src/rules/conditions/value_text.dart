import '../../content/cell_content.dart';
import '../../formula/parser/formula_locale.dart';
import '../../formula/values/coercion.dart';
import '../../formula/values/dates.dart';
import '../../formula/values/fvalue.dart';
import '../../formula/values/numeric.dart';
import '../../input/input_parser.dart';

/// Text/number conversions shared by conditions, data validation, filters and
/// find & replace.
abstract final class ValueText {
  /// The value converted to text with Automatic rules (05 §6.3): numbers with
  /// ≤ 15 significant digits and the locale decimal separator, no grouping;
  /// booleans `TRUE`/`FALSE`; errors their literal; blanks `""`.
  static String automatic(CellValue v, {String decimal = '.'}) => switch (v) {
    EmptyValue() => '',
    NumberValue(:final number) => Numeric.toText(number, decimal: decimal),
    TextValue(:final text) => text,
    BoolValue(:final value) => value ? 'TRUE' : 'FALSE',
    ErrorValue(:final kind) => kind.literal,
  };

  /// Case folding for case-insensitive comparisons (simple folding).
  static String fold(String s) => s.toLowerCase();

  /// Parses [text] like typed input in [locale] into a number (dates, times,
  /// percentages and currency included), or null.
  static double? parseNumber(String text, {String locale = 'en_US', InputParser? parser}) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final parsed = (parser ?? InputParser.instance).parse(t, locale: locale);
    final content = parsed.content;
    if (content is NumberContent) return content.number;
    final r = TextNumberParser.parse(t, FormulaLocale.forId(locale));
    return r?.$1;
  }

  /// Parses [text] as a date (serial, time of day included), or null.
  static double? parseDate(String text, {String locale = 'en_US', InputParser? parser}) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final parsed = (parser ?? InputParser.instance).parse(t, locale: locale);
    final content = parsed.content;
    if (content is NumberContent) return content.number;
    final dt = DateTimeParser.parse(t, FormulaLocale.forId(locale));
    if (dt != null) return dt.serial;
    final r = TextNumberParser.parse(t, FormulaLocale.forId(locale));
    return r?.$1;
  }

  /// Whether [text] parses as a date (with a date part).
  static bool isDateText(String text, {String locale = 'en_US'}) {
    final dt = DateTimeParser.parse(text.trim(), FormulaLocale.forId(locale));
    return dt != null && dt.hasDate;
  }

  /// Number of an engine value for comparisons: numbers, booleans (1/0),
  /// empty (0) and numeric text; null for errors and other text.
  static double? numberOf(FValue v, {String locale = 'en_US'}) => switch (v) {
    FNumber(:final v) => v,
    FBool(:final v) => v ? 1 : 0,
    FEmpty() || FOmitted() => 0,
    FText(:final v) => parseNumber(v, locale: locale),
    FRich(:final scalar) => numberOf(scalar, locale: locale),
    FArray() => numberOf(v.topLeft, locale: locale),
    _ => null,
  };

  /// Text of an engine value (formula coercion rules); null for errors.
  static String? textOf(FValue v, {String locale = 'en_US'}) {
    final r = Coerce.toText(v, FormulaLocale.forId(locale));
    return r is String ? r : null;
  }

  /// Whether an engine result is truthy for custom formulas (06 §15.3):
  /// TRUE or a non-zero number; arrays use the top-left element.
  static bool truthy(FValue v) => switch (v) {
    FBool(:final v) => v,
    FNumber(:final v) => v != 0,
    FArray() => truthy(v.topLeft),
    FRich(:final scalar) => truthy(scalar),
    _ => false,
  };
}
