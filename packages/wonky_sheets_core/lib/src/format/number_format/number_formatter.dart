// Signatures in this file are a contract used by charts, IO, data tools and
// the planner: keep them stable.

import '../../content/cell_content.dart';
import '../../formula/values/format_hint.dart';
import 'cache.dart';
import 'formatter.dart';
import 'locale_data.dart';
import 'presets.dart';

/// One piece of formatted output (06 §5.11).
sealed class FormatSegment {
  const FormatSegment();
}

/// Literal text.
final class TextSegment extends FormatSegment {
  /// Creates a text segment.
  const TextSegment(this.text);

  /// The text.
  final String text;

  @override
  bool operator ==(Object other) => other is TextSegment && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'text($text)';
}

/// `_c`: blank as wide as [char].
final class SpacerSegment extends FormatSegment {
  /// Creates a spacer.
  const SpacerSegment(this.char);

  /// The reference character.
  final String char;

  @override
  bool operator ==(Object other) =>
      other is SpacerSegment && other.char == char;

  @override
  int get hashCode => char.hashCode ^ 0x5bace;

  @override
  String toString() => 'spacer($char)';
}

/// `*c`: repeat [char] to fill the cell width (painter expands).
final class RepeatSegment extends FormatSegment {
  /// Creates a repeat segment.
  const RepeatSegment(this.char);

  /// The repeated character.
  final String char;

  @override
  bool operator ==(Object other) =>
      other is RepeatSegment && other.char == char;

  @override
  int get hashCode => char.hashCode ^ 0x7e9ea7;

  @override
  String toString() => 'repeat($char)';
}

/// Result of [NumberFormatter.format].
final class FormattedValue {
  /// Creates a formatted value.
  const FormattedValue(
    this.segments, {
    this.colorArgb,
    this.overflowHashes = false,
  });

  /// Plain text result.
  factory FormattedValue.text(
    String text, {
    int? colorArgb,
    bool overflowHashes = false,
  }) => FormattedValue(
    [TextSegment(text)],
    colorArgb: colorArgb,
    overflowHashes: overflowHashes,
  );

  /// Output segments.
  final List<FormatSegment> segments;

  /// Color from `[Red]`/`[ColorN]` (opaque ARGB), if any.
  final int? colorArgb;

  /// Whether the caller should render `####` when the text doesn't fit
  /// (numbers and dates).
  final bool overflowHashes;

  /// Segments flattened: repeat → nothing, spacer → one space.
  String get plainText {
    final b = StringBuffer();
    for (final s in segments) {
      switch (s) {
        case TextSegment(:final text):
          b.write(text);
        case SpacerSegment():
          b.write(' ');
        case RepeatSegment():
          break;
      }
    }
    return b.toString();
  }

  @override
  bool operator ==(Object other) {
    if (other is! FormattedValue ||
        other.colorArgb != colorArgb ||
        other.overflowHashes != overflowHashes ||
        other.segments.length != segments.length) {
      return false;
    }
    for (var i = 0; i < segments.length; i++) {
      if (other.segments[i] != segments[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(segments), colorArgb, overflowHashes);

  @override
  String toString() => 'FormattedValue($plainText)';
}

/// Formats cell values for display with Sheets/Excel number formats
/// (06 §5.11). Pure, synchronous and cached.
final class NumberFormatter {
  /// Creates a formatter with its own [cache].
  NumberFormatter({NumberFormatCache? cache})
    : cache = cache ?? NumberFormatCache();

  /// Shared instance (caches inside).
  static final NumberFormatter instance = NumberFormatter();

  /// Pattern and value caches.
  final NumberFormatCache cache;

  static const FormattedValue _empty = FormattedValue([]);
  static const FormattedValue _true = FormattedValue([TextSegment('TRUE')]);
  static const FormattedValue _false = FormattedValue([TextSegment('FALSE')]);

  /// Formats [value] with [patternOrPreset] (null/`preset:automatic` =
  /// Automatic) in [locale] (`Spreadsheet.locale`, e.g. `en_US`).
  ///
  /// Booleans always display `TRUE`/`FALSE`, errors their literal. Invalid
  /// patterns render with Automatic rules.
  FormattedValue format(
    CellValue value,
    String? patternOrPreset, {
    String locale = 'en_US',
  }) {
    switch (value) {
      case EmptyValue():
        return _empty;
      case BoolValue(:final value):
        return value ? _true : _false;
      case ErrorValue(:final kind):
        return FormattedValue.text(kind.literal);
      case TextValue() || NumberValue():
        break;
    }
    final pattern = NumberFormatPresets.isAutomatic(patternOrPreset)
        ? null
        : NumberFormatPresets.resolve(patternOrPreset, locale);
    if (pattern == null) return _automatic(value, locale);
    final Object key;
    if (value is NumberValue) {
      final n = value.number;
      if (!n.isFinite) return FormattedValue.text('#NUM!');
      key = n == 0 ? 0.0 : n;
    } else {
      final text = (value as TextValue).text;
      if (text.length > 256) return _render(pattern, value, locale);
      key = text;
    }
    final hit = cache.lookup(pattern, locale, key);
    if (hit != null) return hit;
    final result = _render(pattern, value, locale);
    cache.store(pattern, locale, key, result);
    return result;
  }

  FormattedValue _render(String pattern, CellValue value, String locale) {
    final ast = cache.ast(pattern);
    if (ast == null) return _automatic(value, locale);
    return NumberFormatRenderer.render(
      ast,
      value,
      LocaleFormatData.forId(locale),
    );
  }

  FormattedValue _automatic(CellValue value, String locale) => switch (value) {
    NumberValue(:final number) => NumberFormatRenderer.automatic(
      number,
      LocaleFormatData.forId(locale),
    ),
    TextValue(:final text) => FormattedValue.text(text),
    _ => format(value, null, locale: locale),
  };

  /// [format] flattened to plain text.
  String formatText(
    CellValue value,
    String? patternOrPreset, {
    String locale = 'en_US',
  }) => format(value, patternOrPreset, locale: locale).plainText;

  /// Formats a formula result: when [pattern] is Automatic, the result's
  /// format hint pattern [hintPattern] (see [hintFor]) is used instead
  /// (05 §6.2). Explicit formats always win.
  FormattedValue formatWithHint(
    CellValue value,
    String? pattern, {
    String locale = 'en_US',
    String? hintPattern,
  }) {
    if (NumberFormatPresets.isAutomatic(pattern) &&
        hintPattern != null &&
        value is NumberValue) {
      return format(value, hintPattern, locale: locale);
    }
    return format(value, pattern, locale: locale);
  }

  /// The pattern (or preset id) displaying a [hint] in [locale], or null
  /// for Automatic.
  static String? hintFor(FormatHint hint, String locale) {
    switch (hint.kind) {
      case FormatHintKind.none:
        return null;
      case FormatHintKind.date:
        return NumberFormatPresets.date;
      case FormatHintKind.time:
        return NumberFormatPresets.time;
      case FormatHintKind.dateTime:
        return NumberFormatPresets.dateTime;
      case FormatHintKind.duration:
        return NumberFormatPresets.duration;
      case FormatHintKind.percent:
        return NumberFormatPresets.percent;
      case FormatHintKind.scientific:
        return NumberFormatPresets.scientific;
      case FormatHintKind.currency:
        final code = hint.detail;
        final loc = LocaleFormatData.forId(locale);
        if (code == null || code == loc.currencyCode) {
          return NumberFormatPresets.currency;
        }
        return NumberFormatPresets.currencyPattern(
          loc,
          symbol: currencySymbolFor(code),
        );
      case FormatHintKind.fromCell:
        final p = hint.detail;
        return NumberFormatPresets.isAutomatic(p) ? null : p;
    }
  }

  /// Display symbol of an ISO currency code (`EUR` → `€`); the code itself
  /// when no common symbol exists.
  static String currencySymbolFor(String code) =>
      _currencySymbols[code.toUpperCase()] ?? code;

  static const Map<String, String> _currencySymbols = {
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
    'INR': '₹',
    'KRW': '₩', //
    'BRL': r'R$',
    'RUB': '₽',
    'CHF': 'CHF',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr', //
    'PLN': 'zł',
    'CZK': 'Kč',
    'TRY': '₺',
    'AUD': r'A$',
    'CAD': r'CA$',
    'NZD': r'NZ$', //
    'MXN': r'MX$',
    'ZAR': 'R',
    'ILS': '₪',
    'HUF': 'Ft',
    'UAH': '₴',
    'VND': '₫',
    'THB': '฿', //
    'PHP': '₱', 'NGN': '₦', 'HKD': r'HK$', 'SGD': r'S$', 'TWD': r'NT$',
  };
}
