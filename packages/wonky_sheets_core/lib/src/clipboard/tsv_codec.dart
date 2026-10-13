/// Maximum characters per pasted cell; longer text is truncated with a
/// warning (03 §12.5).
const int kMaxPastedCellChars = 50000;

/// Suggestion to split single-column pasted text (03 §12.5 "Split text to
/// columns" chip).
final class SplitSuggestion {
  /// Creates a suggestion.
  const SplitSuggestion(this.delimiter, this.ratio);

  /// `,` or `;`.
  final String delimiter;

  /// Fraction of non-empty lines containing the delimiter.
  final double ratio;

  @override
  String toString() => 'SplitSuggestion("$delimiter", $ratio)';
}

/// Result of [TsvCodec.parseWithReport].
final class TsvParseResult {
  /// Creates a result.
  const TsvParseResult(this.rows, {this.truncatedCells = 0, this.suggestSplit});

  /// Rectangular rows (ragged input is padded with empty strings).
  final List<List<String>> rows;

  /// Number of cells truncated to [kMaxPastedCellChars].
  final int truncatedCells;

  /// Non-null when the text is one column of comma/semicolon separated text.
  final SplitSuggestion? suggestSplit;
}

/// TSV for the clipboard's `text/plain` (03 §12.2/§12.5): tab-separated,
/// newline-terminated rows; fields containing tabs, line breaks or quotes are
/// quoted RFC-4180 style (`"a""b"`).
abstract final class TsvCodec {
  /// Encodes rows (no trailing line break).
  static String encode(List<List<String>> rows, {String lineEnding = '\n'}) {
    final b = StringBuffer();
    for (var r = 0; r < rows.length; r++) {
      if (r > 0) b.write(lineEnding);
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        if (c > 0) b.write('\t');
        b.write(encodeField(row[c]));
      }
    }
    return b.toString();
  }

  /// Quotes [field] when needed.
  static String encodeField(String field) {
    for (var i = 0; i < field.length; i++) {
      final c = field.codeUnitAt(i);
      if (c == 0x09 || c == 0x0a || c == 0x0d || c == 0x22) {
        return '"${field.replaceAll('"', '""')}"';
      }
    }
    return field;
  }

  /// Parses TSV text into rectangular rows (truncating oversized cells).
  static List<List<String>> parse(String text) => parseWithReport(text).rows;

  /// Parses TSV text; reports truncations and the split-to-columns suggestion.
  ///
  /// Quotes are only special at the start of a field; inside a quoted field
  /// `""` is a quote and tabs/newlines are literal. A closing quote followed by
  /// other text keeps that text (lenient). `\r\n`, `\n` and `\r` end rows; a
  /// trailing line break does not add an empty row.
  static TsvParseResult parseWithReport(
    String text, {
    String delimiter = '\t',
  }) {
    final d = delimiter.codeUnitAt(0);
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var truncated = 0;
    var i = 0;
    final n = text.length;
    var atFieldStart = true;

    void endField() {
      var v = field.toString();
      if (v.length > kMaxPastedCellChars) {
        v = v.substring(0, kMaxPastedCellChars);
        truncated++;
      }
      row.add(v);
      field.clear();
      atFieldStart = true;
    }

    void endRow() {
      endField();
      rows.add(row);
      row = <String>[];
    }

    if (n > 0 && text.codeUnitAt(0) == 0xfeff) i = 1;
    while (i < n) {
      final c = text.codeUnitAt(i);
      if (atFieldStart && c == 0x22) {
        // Quoted field.
        i++;
        while (i < n) {
          final q = text.codeUnitAt(i);
          if (q == 0x22) {
            if (i + 1 < n && text.codeUnitAt(i + 1) == 0x22) {
              field.writeCharCode(0x22);
              i += 2;
              continue;
            }
            i++;
            break;
          }
          field.writeCharCode(q);
          i++;
        }
        atFieldStart = false;
        continue;
      }
      atFieldStart = false;
      if (c == d) {
        endField();
        i++;
      } else if (c == 0x0d || c == 0x0a) {
        endRow();
        i += (c == 0x0d && i + 1 < n && text.codeUnitAt(i + 1) == 0x0a) ? 2 : 1;
      } else {
        field.writeCharCode(c);
        i++;
      }
    }
    if (!atFieldStart || field.isNotEmpty || row.isNotEmpty) endRow();
    var width = 0;
    for (final r in rows) {
      if (r.length > width) width = r.length;
    }
    for (final r in rows) {
      while (r.length < width) {
        r.add('');
      }
    }
    return TsvParseResult(
      rows,
      truncatedCells: truncated,
      suggestSplit: detectSplit(rows),
    );
  }

  /// "Split text to columns" detection: a single column whose non-empty
  /// lines contain commas (or semicolons) in ≥ 80 % of the lines.
  static SplitSuggestion? detectSplit(List<List<String>> rows) {
    if (rows.isEmpty || rows.any((r) => r.length != 1)) return null;
    final lines = [
      for (final r in rows)
        if (r.single.trim().isNotEmpty) r.single,
    ];
    if (lines.isEmpty) return null;
    SplitSuggestion? best;
    for (final delim in const [',', ';']) {
      final hits = lines.where((l) => l.contains(delim)).length;
      final ratio = hits / lines.length;
      if (ratio >= 0.8 && (best == null || ratio > best.ratio)) {
        best = SplitSuggestion(delim, ratio);
      }
    }
    return best;
  }
}
