import 'cache.dart';
import 'formatted_value.dart';
import 'formatter.dart';
import 'locale_data.dart';
import 'presets.dart';

/// Formats numbers and text with spreadsheet number formats (Sheets 06 §5.11):
/// patterns (`#,##0.00`, `0%`, `[$€]#,##0`, `yyyy-mm-dd`) or `preset:` ids
/// resolved for the locale. Pure, synchronous and cached.
///
/// Wonky Sheets formats cell values through its `NumberFormatter`, which adds
/// booleans, errors and formula format hints on top of this class; charts
/// (axes, labels, tooltips) use it directly.
final class NumberPatternFormatter {
  /// Creates a formatter with its own [cache].
  NumberPatternFormatter({NumberFormatCache? cache})
    : cache = cache ?? NumberFormatCache();

  /// Shared instance (caches inside).
  static final NumberPatternFormatter instance = NumberPatternFormatter();

  /// Pattern and value caches.
  final NumberFormatCache cache;

  /// Formats the number [x] with [patternOrPreset] (null/`preset:automatic` =
  /// Automatic) in [locale] (e.g. `en_US`). Invalid patterns render with
  /// Automatic rules; non-finite numbers display `#NUM!`.
  FormattedValue formatNumber(
    double x,
    String? patternOrPreset, {
    String locale = 'en_US',
  }) {
    final pattern = _pattern(patternOrPreset, locale);
    if (pattern == null) return _automaticNumber(x, locale);
    if (!x.isFinite) return FormattedValue.text('#NUM!');
    final key = x == 0 ? 0.0 : x;
    final hit = cache.lookup(pattern, locale, key);
    if (hit != null) return hit;
    final ast = cache.ast(pattern);
    final result = ast == null
        ? _automaticNumber(x, locale)
        : NumberFormatRenderer.renderNumber(
            ast,
            x,
            LocaleFormatData.forId(locale),
          );
    cache.store(pattern, locale, key, result);
    return result;
  }

  /// Formats the text [text] with [patternOrPreset]: the pattern's text
  /// section (`@`) if any, else the text as is.
  FormattedValue formatString(
    String text,
    String? patternOrPreset, {
    String locale = 'en_US',
  }) {
    final pattern = _pattern(patternOrPreset, locale);
    if (pattern == null) return FormattedValue.text(text);
    if (text.length > 256) return _renderText(pattern, text, locale);
    final hit = cache.lookup(pattern, locale, text);
    if (hit != null) return hit;
    final result = _renderText(pattern, text, locale);
    cache.store(pattern, locale, text, result);
    return result;
  }

  /// [formatNumber] flattened to plain text.
  String formatNumberText(
    double x,
    String? patternOrPreset, {
    String locale = 'en_US',
  }) => formatNumber(x, patternOrPreset, locale: locale).plainText;

  static String? _pattern(String? patternOrPreset, String locale) =>
      NumberFormatPresets.isAutomatic(patternOrPreset)
      ? null
      : NumberFormatPresets.resolve(patternOrPreset, locale);

  FormattedValue _renderText(String pattern, String text, String locale) {
    final ast = cache.ast(pattern);
    if (ast == null) return FormattedValue.text(text);
    return NumberFormatRenderer.renderText(
      ast,
      text,
      LocaleFormatData.forId(locale),
    );
  }

  static FormattedValue _automaticNumber(double x, String locale) =>
      NumberFormatRenderer.automatic(x, LocaleFormatData.forId(locale));
}
