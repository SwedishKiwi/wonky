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

/// Result of formatting a value with a number format (`NumberPatternFormatter`).
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
