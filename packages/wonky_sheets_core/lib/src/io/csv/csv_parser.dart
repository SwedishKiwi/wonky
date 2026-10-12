/// One parsed CSV record.
final class CsvRecord {
  /// Creates a record.
  const CsvRecord(this.fields, this.line);

  /// Field texts (quotes removed, `""` unescaped).
  final List<String> fields;

  /// 1-based physical line where the record starts.
  final int line;

  @override
  String toString() => 'CsvRecord($line, $fields)';
}

/// A lenient RFC 4180 streaming parser (11 §4.3): `"` quoting with `""`
/// escapes, embedded delimiters and newlines, CR/LF/CRLF line endings,
/// ragged rows, literal quotes inside unquoted fields, unterminated quotes
/// closed at EOF, and a maximum field length (longer fields are truncated).
///
/// Feed decoded text with [feed] (chunks may split anywhere) and finish with
/// [close].
final class CsvParser {
  /// Creates a parser. [delimiter] may be any non-empty string.
  CsvParser({this.delimiter = ',', this.maxFieldLength = 50000}) : assert(delimiter.isNotEmpty);

  /// Field delimiter.
  final String delimiter;

  /// Maximum field length in UTF-16 code units.
  final int maxFieldLength;

  final StringBuffer _field = StringBuffer();
  int _fieldLen = 0;
  bool _truncatedThis = false;
  List<String> _record = [];
  bool _inQuotes = false;
  bool _wasQuoted = false;
  bool _recordStarted = false;
  int _line = 1;
  int _recordLine = 1;
  int _quoteLine = 1;
  String _carry = '';
  bool _closed = false;

  /// Number of truncated fields so far.
  int truncatedFields = 0;

  /// First line of a truncated field, if any.
  int? firstTruncatedLine;

  /// Line of an unterminated quote closed at EOF, if any.
  int? unterminatedQuoteLine;

  /// Number of records emitted.
  int recordCount = 0;

  /// Parses the next text chunk; returns completed records.
  List<CsvRecord> feed(String chunk) {
    if (_closed) throw StateError('CsvParser is closed');
    return _run(_carry + chunk, last: false);
  }

  /// Ends the input; returns the remaining records.
  List<CsvRecord> close() {
    if (_closed) return const [];
    final out = _run(_carry, last: true);
    _closed = true;
    if (_inQuotes) {
      unterminatedQuoteLine = _quoteLine;
      _inQuotes = false;
    }
    if (_recordStarted || _fieldLen > 0 || _record.isNotEmpty) {
      _endField();
      out.add(_emit());
    }
    return out;
  }

  /// Parses complete [text].
  static List<CsvRecord> parseAll(String text, {String delimiter = ',', int maxFieldLength = 50000}) {
    final p = CsvParser(delimiter: delimiter, maxFieldLength: maxFieldLength);
    return [...p.feed(text), ...p.close()];
  }

  List<CsvRecord> _run(String text, {required bool last}) {
    final out = <CsvRecord>[];
    final n = text.length;
    final look = delimiter.length > 2 ? delimiter.length : 2;
    final d0 = delimiter.codeUnitAt(0);
    final single = delimiter.length == 1;
    var i = 0;
    while (i < n) {
      if (!last && n - i < look) break;
      final c = text.codeUnitAt(i);
      if (_inQuotes) {
        if (c == 0x22) {
          if (i + 1 < n && text.codeUnitAt(i + 1) == 0x22) {
            _append('"');
            i += 2;
            continue;
          }
          _inQuotes = false;
          i++;
          continue;
        }
        if (c == 0x0a) _line++;
        if (c == 0x0d) {
          if (!(i + 1 < n && text.codeUnitAt(i + 1) == 0x0a)) _line++;
        }
        _appendCode(c);
        i++;
        continue;
      }
      if (c == d0 && (single || text.startsWith(delimiter, i))) {
        _recordStarted = true;
        _endField();
        i += delimiter.length;
        continue;
      }
      if (c == 0x0d || c == 0x0a) {
        final crlf = c == 0x0d && i + 1 < n && text.codeUnitAt(i + 1) == 0x0a;
        _endField();
        out.add(_emit());
        _line++;
        _recordLine = _line;
        i += crlf ? 2 : 1;
        continue;
      }
      if (c == 0x22 && _fieldLen == 0 && !_wasQuoted) {
        _inQuotes = true;
        _wasQuoted = true;
        _recordStarted = true;
        _quoteLine = _line;
        i++;
        continue;
      }
      _recordStarted = true;
      _appendCode(c);
      i++;
    }
    _carry = i < n ? text.substring(i) : '';
    return out;
  }

  void _append(String s) {
    _recordStarted = true;
    if (_fieldLen + s.length > maxFieldLength) {
      _markTruncated();
      return;
    }
    _field.write(s);
    _fieldLen += s.length;
  }

  void _appendCode(int c) {
    _recordStarted = true;
    if (_fieldLen >= maxFieldLength) {
      _markTruncated();
      return;
    }
    _field.writeCharCode(c);
    _fieldLen++;
  }

  void _markTruncated() {
    if (_truncatedThis) return;
    _truncatedThis = true;
    truncatedFields++;
    firstTruncatedLine ??= _recordLine;
  }

  void _endField() {
    _record.add(_field.toString());
    _field.clear();
    _fieldLen = 0;
    _wasQuoted = false;
    _truncatedThis = false;
  }

  CsvRecord _emit() {
    var fields = _record;
    // A blank line is a record without fields.
    if (fields.length == 1 && fields.first.isEmpty && !_recordStarted) fields = const [];
    final r = CsvRecord(fields, _recordLine);
    _record = [];
    _recordStarted = false;
    recordCount++;
    return r;
  }
}

/// Result of delimiter detection.
final class DetectedDelimiter {
  /// Creates a result.
  const DetectedDelimiter(this.delimiter, {this.sepLineLength = 0, this.fromSepLine = false});

  final String delimiter;

  /// Length (code units, incl. line break) of a leading `sep=` line to skip.
  final int sepLineLength;

  /// Whether the delimiter came from a `sep=` line.
  final bool fromSepLine;
}

/// Scores candidate delimiters on a text sample (11 §4.2).
abstract final class CsvDelimiterDetector {
  /// Candidate delimiters in tie-break order.
  static const candidates = [',', ';', '\t', '|'];

  static final RegExp _sep = RegExp(r'^"?sep=(.)"?(\r\n|\n|\r|$)', caseSensitive: false);

  /// Detects the delimiter of [sample] (decoded start of the file).
  static DetectedDelimiter detect(String sample, {String? fileName, bool decimalCommaLocale = false}) {
    final m = _sep.firstMatch(sample);
    if (m != null) return DetectedDelimiter(m.group(1)!, sepLineLength: m.end, fromSepLine: true);
    final scores = <String, double>{};
    for (final d in candidates) {
      scores[d] = score(sample, d);
    }
    final best = scores.values.fold<double>(0, (a, b) => b > a ? b : a);
    final isTsv = fileName != null && fileName.toLowerCase().endsWith('.tsv');
    if (best <= 0) return DetectedDelimiter(isTsv ? '\t' : ',');
    final tied = [for (final d in candidates) if ((scores[d]! - best).abs() < 1e-9) d];
    if (tied.length == 1) return DetectedDelimiter(tied.single);
    if (isTsv && tied.contains('\t')) return const DetectedDelimiter('\t');
    if (decimalCommaLocale && tied.contains(';')) return const DetectedDelimiter(';');
    return DetectedDelimiter(tied.contains(',') ? ',' : tied.first);
  }

  /// Score of [delimiter] on the first 50 records of [sample]:
  /// (records with the modal field count ≥ 2) × modal count − variance.
  static double score(String sample, String delimiter) {
    final p = CsvParser(delimiter: delimiter);
    final records = p.feed(sample);
    // The last (possibly truncated) record of a sample is ignored unless it is the only one.
    if (records.isEmpty) records.addAll(p.close());
    final counts = [
      for (final r in records.take(50))
        if (r.fields.isNotEmpty) r.fields.length,
    ];
    if (counts.isEmpty) return 0;
    final freq = <int, int>{};
    for (final c in counts) {
      freq[c] = (freq[c] ?? 0) + 1;
    }
    var modal = counts.first;
    for (final e in freq.entries) {
      if (e.value > freq[modal]! || (e.value == freq[modal]! && e.key > modal)) modal = e.key;
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
}
