// API skeleton — the full implementation is built in this folder (06 §5).
// Signatures in this file are a contract used by charts, IO, data tools and
// the planner: keep them stable.

import '../../content/cell_content.dart';

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
}

/// `_c`: blank as wide as [char].
final class SpacerSegment extends FormatSegment {
  /// Creates a spacer.
  const SpacerSegment(this.char);

  /// The reference character.
  final String char;
}

/// `*c`: repeat [char] to fill the cell width (painter expands).
final class RepeatSegment extends FormatSegment {
  /// Creates a repeat segment.
  const RepeatSegment(this.char);

  /// The repeated character.
  final String char;
}

/// Result of [NumberFormatter.format].
final class FormattedValue {
  /// Creates a formatted value.
  const FormattedValue(this.segments, {this.colorArgb, this.overflowHashes = false});

  /// Plain text result.
  factory FormattedValue.text(String text, {int? colorArgb, bool overflowHashes = false}) =>
      FormattedValue([TextSegment(text)], colorArgb: colorArgb, overflowHashes: overflowHashes);

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
  String toString() => 'FormattedValue($plainText)';
}

/// Formats cell values for display with Sheets/Excel number formats.
final class NumberFormatter {
  /// Creates a formatter.
  NumberFormatter();

  /// Shared instance (caches inside).
  static final NumberFormatter instance = NumberFormatter();

  /// Formats [value] with [patternOrPreset] (null/`preset:automatic` =
  /// Automatic) in [locale] (`Spreadsheet.locale`, e.g. `en_US`).
  FormattedValue format(CellValue value, String? patternOrPreset, {String locale = 'en_US'}) {
    return switch (value) {
      EmptyValue() => const FormattedValue([]),
      TextValue(:final text) => FormattedValue.text(text),
      BoolValue(:final value) => FormattedValue.text(value ? 'TRUE' : 'FALSE'),
      ErrorValue(:final kind) => FormattedValue.text(kind.literal),
      NumberValue(:final number) => FormattedValue.text(
        CellContent.formatNumber(number),
        overflowHashes: true,
      ),
    };
  }

  /// [format] flattened to plain text.
  String formatText(CellValue value, String? patternOrPreset, {String locale = 'en_US'}) =>
      format(value, patternOrPreset, locale: locale).plainText;
}
