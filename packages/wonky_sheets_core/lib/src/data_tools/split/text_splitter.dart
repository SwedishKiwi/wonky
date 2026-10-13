import 'dart:math' as math;

import '../../input/input_parser.dart';

/// Separators of split text to columns (07 §13), in tie-break priority order.
enum SplitSeparator {
  comma(','),
  semicolon(';'),
  tab('\t'),
  pipe('|'),
  space(' '),
  period('.');

  const SplitSeparator(this.char);

  /// The separator text.
  final String char;

  /// Whether CSV-style quoting applies.
  bool get quoting => this == comma || this == semicolon;
}

/// Detects the separator of a column (07 §13): among `, ; tab | space .`, the
/// one present in the most cells, then with the most consistent count per
/// cell (lowest coefficient of variation), ties by priority.
abstract final class SeparatorDetector {
  /// Maximum number of sampled non-empty cells.
  static const int sampleSize = 1000;

  /// The detected separator, or null ("Couldn't detect a separator").
  static SplitSeparator? detect(Iterable<String> texts) {
    final sample = <String>[];
    for (final t in texts) {
      final s = t.trim();
      if (s.isEmpty) continue;
      sample.add(s);
      if (sample.length >= sampleSize) break;
    }
    if (sample.isEmpty) return null;
    SplitSeparator? best;
    var bestPresent = 0;
    var bestCv = double.infinity;
    for (final sep in SplitSeparator.values) {
      final counts = <int>[];
      for (final s in sample) {
        final c = TextSplitter.countSeparators(
          s,
          sep.char,
          quoting: sep.quoting,
        );
        if (c > 0) counts.add(c);
      }
      if (counts.isEmpty) continue;
      final mean = counts.reduce((a, b) => a + b) / counts.length;
      var variance = 0.0;
      for (final c in counts) {
        variance += (c - mean) * (c - mean);
      }
      variance /= counts.length;
      final cv = mean == 0 ? 0.0 : math.sqrt(variance) / mean;
      if (counts.length > bestPresent ||
          (counts.length == bestPresent && cv < bestCv - 1e-12)) {
        best = sep;
        bestPresent = counts.length;
        bestCv = cv;
      }
    }
    return best;
  }
}

/// Splits cell texts into parts (07 §13).
abstract final class TextSplitter {
  /// Number of separator occurrences outside quotes.
  static int countSeparators(String text, String sep, {bool quoting = false}) {
    if (sep.isEmpty) return 0;
    var n = 0;
    var inQuotes = false;
    var i = 0;
    while (i < text.length) {
      final ch = text[i];
      if (quoting && ch == '"') {
        inQuotes = !inQuotes;
        i++;
        continue;
      }
      if (!inQuotes && text.startsWith(sep, i)) {
        n++;
        i += sep.length;
        continue;
      }
      i++;
    }
    return n;
  }

  /// Splits [text] by [separator]. CSV-style quoting (`"Doe, John"`, `""`
  /// escapes) applies when [quoting] (default: for `,` and `;`); consecutive
  /// separators produce empty parts; parts are trimmed of surrounding spaces
  /// unless the separator is a space.
  static List<String> split(String text, String separator, {bool? quoting}) {
    if (separator.isEmpty) return [text];
    final q = quoting ?? (separator == ',' || separator == ';');
    final trim = separator != ' ';
    final parts = <String>[];
    final cur = StringBuffer();
    var i = 0;
    var inQuotes = false;
    var quotedPart = false;
    void flush() {
      final s = cur.toString();
      parts.add(
        trim && !quotedPart ? s.trim() : (trim ? _trimOutsideQuoted(s) : s),
      );
      cur.clear();
      quotedPart = false;
    }

    while (i < text.length) {
      final ch = text[i];
      if (q && ch == '"') {
        if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
          cur.write('"');
          i += 2;
          continue;
        }
        if (!inQuotes && cur.toString().trim().isEmpty) {
          cur.clear();
          inQuotes = true;
          quotedPart = true;
          i++;
          continue;
        }
        if (inQuotes) {
          inQuotes = false;
          i++;
          continue;
        }
      }
      if (!inQuotes && text.startsWith(separator, i)) {
        flush();
        i += separator.length;
        continue;
      }
      cur.write(ch);
      i++;
    }
    flush();
    return parts;
  }

  // A quoted part keeps its inner spaces; only text after the closing quote is trimmed.
  static String _trimOutsideQuoted(String s) => s.trimRight();

  /// Splits every text of a column; returns the parts per row and the maximum
  /// part count (number of target columns).
  static (List<List<String>>, int) splitColumn(
    Iterable<String?> texts,
    String separator,
  ) {
    final out = <List<String>>[];
    var max = 0;
    for (final t in texts) {
      final parts = t == null || t.isEmpty
          ? const <String>[]
          : split(t, separator);
      if (parts.length > max) max = parts.length;
      out.add(parts);
    }
    return (out, max);
  }

  /// Parses one part like typed input (locale-aware) unless the target
  /// column's number format is plain text (`@`).
  static ParsedInput parsePart(
    String part, {
    String locale = 'en_US',
    String? targetNumberFormat,
    DateTime? today,
    InputParser? parser,
  }) => (parser ?? InputParser.instance).parse(
    part,
    locale: locale,
    targetNumberFormat: targetNumberFormat,
    today: today,
  );
}
