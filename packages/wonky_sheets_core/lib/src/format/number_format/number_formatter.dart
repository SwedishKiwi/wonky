// Signatures in this file are a contract used by charts, IO, data tools and
// the planner: keep them stable.

import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../../content/cell_content.dart';
import '../../formula/values/format_hint.dart';

export 'package:wonky_numfmt/wonky_numfmt.dart'
    show
        FormatSegment,
        FormattedValue,
        NumberFormatCache,
        NumberPatternFormatter,
        RepeatSegment,
        SpacerSegment,
        TextSegment;

/// Formats cell values for display with Sheets/Excel number formats
/// (06 §5.11). Pure, synchronous and cached.
///
/// The pattern engine is `wonky_numfmt` ([NumberPatternFormatter]); this class
/// adds the cell value kinds (empty, booleans, errors) and formula format
/// hints.
final class NumberFormatter {
  /// Creates a formatter with its own [cache].
  NumberFormatter({NumberFormatCache? cache})
    : this._(NumberPatternFormatter(cache: cache));

  NumberFormatter._(this.patterns);

  /// Shared instance (caches inside; shares them with
  /// [NumberPatternFormatter.instance]).
  static final NumberFormatter instance = NumberFormatter._(
    NumberPatternFormatter.instance,
  );

  /// The pattern formatter doing the work.
  final NumberPatternFormatter patterns;

  /// Pattern and value caches.
  NumberFormatCache get cache => patterns.cache;

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
  }) => switch (value) {
    EmptyValue() => _empty,
    BoolValue(:final value) => value ? _true : _false,
    ErrorValue(:final kind) => FormattedValue.text(kind.literal),
    NumberValue(:final number) => patterns.formatNumber(
      number,
      patternOrPreset,
      locale: locale,
    ),
    TextValue(:final text) => patterns.formatString(
      text,
      patternOrPreset,
      locale: locale,
    ),
  };

  /// Renders [value] with [ast] in [locale], uncached (06 §5.3–5.8).
  static FormattedValue render(
    NumberFormatAst ast,
    CellValue value,
    LocaleFormatData locale,
  ) => switch (value) {
    EmptyValue() => _empty,
    BoolValue(:final value) => FormattedValue.text(value ? 'TRUE' : 'FALSE'),
    ErrorValue(:final kind) => FormattedValue.text(kind.literal),
    TextValue(:final text) => NumberFormatRenderer.renderText(
      ast,
      text,
      locale,
    ),
    NumberValue(:final number) => NumberFormatRenderer.renderNumber(
      ast,
      number,
      locale,
    ),
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
      NumberFormatPresets.currencySymbolFor(code);
}
