/// CSV/TSV reading for previews (Drive 02 §6.4): delimiter sniffing with
/// the Sheets rules (Sheets 11 §4.2: a leading `sep=` line, else the
/// candidate with the most consistent field count; `.tsv` and `,` break
/// ties) and a lenient RFC 4180 parser (quotes with `""` escapes, embedded
/// delimiters and line breaks, CR/LF/CRLF, ragged rows, unterminated quotes
/// closed at the end). No type conversion: every cell stays text.
///
/// Sheets' own importer (`wonky_sheets_core`) keeps its streaming parser;
/// this is the small, dependency-free reader Drive's table preview needs.
library;

/// The result of [CsvSniffer.parse].
final class CsvTable {
  /// Creates a table.
  const CsvTable({
    required this.rows,
    required this.delimiter,
    required this.columnCount,
    required this.truncated,
  });

  /// The records (at most `maxRows`), each a list of cell texts.
  final List<List<String>> rows;

  /// The delimiter used.
  final String delimiter;

  /// The widest row's field count.
  final int columnCount;

  /// Whether the text has more records than [rows].
  final bool truncated;
}

/// Delimiter detection and parsing of CSV/TSV text (Drive 02 §6.4).
abstract final class CsvSniffer {
  /// Candidate delimiters in tie-break order.
  static const candidates = [',', ';', '\t', '|'];

  static final RegExp _sep = RegExp(
    r'^"?sep=(.)"?(\r\n|\n|\r|$)',
    caseSensitive: false,
  );

  /// Characters of the text looked at for detection.
  static const sampleLength = 64 * 1024;

  /// The delimiter of [text]: a leading `sep=;` line wins; otherwise the
  /// candidate whose first 50 records have the most consistent field count
  /// (≥ 2). Ties prefer tab for a `.tsv` [fileName], then `,`. Text without
  /// any candidate gives `,` (tab for `.tsv`).
  static String detectDelimiter(String text, {String? fileName}) {
    final m = _sep.firstMatch(text);
    if (m != null) return m.group(1)!;
    final sample = text.length > sampleLength
        ? text.substring(0, sampleLength)
        : text;
    final isTsv = fileName != null && fileName.toLowerCase().endsWith('.tsv');
    var best = 0.0;
    final scores = <String, double>{};
    for (final d in candidates) {
      final s = score(sample, d);
      scores[d] = s;
      if (s > best) best = s;
    }
    if (best <= 0) return isTsv ? '\t' : ',';
    final tied = [
      for (final d in candidates)
        if ((scores[d]! - best).abs() < 1e-9) d,
    ];
    if (tied.length == 1) return tied.single;
    if (isTsv && tied.contains('\t')) return '\t';
    return tied.contains(',') ? ',' : tied.first;
  }

  /// Score of [delimiter] on the first 50 records of [sample]: (records
  /// with the modal field count) × modal count − variance; 0 when the modal
  /// count is below 2.
  static double score(String sample, String delimiter) {
    final records = _parse(sample, delimiter, maxRows: 51, dropLast: true);
    final counts = [
      for (final r in records.rows.take(50))
        if (r.isNotEmpty) r.length,
    ];
    if (counts.isEmpty) return 0;
    final freq = <int, int>{};
    for (final c in counts) {
      freq[c] = (freq[c] ?? 0) + 1;
    }
    var modal = counts.first;
    for (final e in freq.entries) {
      if (e.value > freq[modal]! ||
          (e.value == freq[modal]! && e.key > modal)) {
        modal = e.key;
      }
    }
    if (modal < 2) return 0;
    final mean = counts.reduce((a, b) => a + b) / counts.length;
    var variance = 0.0;
    for (final c in counts) {
      variance += (c - mean) * (c - mean);
    }
    variance /= counts.length;
    return freq[modal]! * modal - variance;
  }

  /// Parses [text] into at most [maxRows] records with [delimiter] (sniffed
  /// with [detectDelimiter] when null). A leading `sep=` line is skipped.
  /// Blank lines are kept as empty records.
  static CsvTable parse(
    String text, {
    String? delimiter,
    String? fileName,
    int maxRows = 1000,
  }) {
    var body = text;
    final sep = _sep.firstMatch(text);
    final d = delimiter ?? detectDelimiter(text, fileName: fileName);
    if (sep != null && (delimiter == null || delimiter == sep.group(1))) {
      body = text.substring(sep.end);
    }
    return _parse(body, d, maxRows: maxRows);
  }

  static CsvTable _parse(
    String text,
    String delimiter, {
    required int maxRows,
    bool dropLast = false,
  }) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var wasQuoted = false;
    var started = false;
    var truncated = false;
    final n = text.length;
    final d0 = delimiter.codeUnitAt(0);
    final single = delimiter.length == 1;

    void endField() {
      row.add(field.toString());
      field.clear();
      wasQuoted = false;
    }

    bool endRow() {
      if (row.length == 1 && row.first.isEmpty && !started) row = [];
      if (rows.length >= maxRows) {
        truncated = true;
        return false;
      }
      rows.add(row);
      row = <String>[];
      started = false;
      return true;
    }

    var i = 0;
    var complete = true;
    while (i < n) {
      final c = text.codeUnitAt(i);
      if (inQuotes) {
        if (c == 0x22) {
          if (i + 1 < n && text.codeUnitAt(i + 1) == 0x22) {
            field.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        field.writeCharCode(c);
        i++;
        continue;
      }
      if (c == d0 && (single || text.startsWith(delimiter, i))) {
        started = true;
        endField();
        i += delimiter.length;
        continue;
      }
      if (c == 0x0d || c == 0x0a) {
        final crlf = c == 0x0d && i + 1 < n && text.codeUnitAt(i + 1) == 0x0a;
        endField();
        if (!endRow()) {
          complete = false;
          break;
        }
        i += crlf ? 2 : 1;
        continue;
      }
      if (c == 0x22 && field.isEmpty && !wasQuoted) {
        inQuotes = true;
        wasQuoted = true;
        started = true;
        i++;
        continue;
      }
      started = true;
      field.writeCharCode(c);
      i++;
    }
    if (complete && !dropLast && (started || field.isNotEmpty)) {
      endField();
      endRow();
    } else if (complete && dropLast && rows.isEmpty && started) {
      // A sample with a single (unterminated) record still counts.
      endField();
      endRow();
    }
    var columns = 0;
    for (final r in rows) {
      if (r.length > columns) columns = r.length;
    }
    return CsvTable(
      rows: rows,
      delimiter: delimiter,
      columnCount: columns,
      truncated: truncated,
    );
  }
}
