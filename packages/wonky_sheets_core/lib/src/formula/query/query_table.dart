import '../values/format_hint.dart';
import '../values/fvalue.dart';
import '../values/numeric.dart';

/// Value types of query columns (GViz types).
enum QType {
  number,
  string,
  boolean,
  date,
  datetime,
  timeofday;

  /// Whether values are serial numbers (numbers, dates, date-times, times).
  bool get isNumeric => this != string && this != boolean;
}

/// A column-typed table built from QUERY's `data` argument (05 §16.2).
///
/// Values are stored per column: `double` for numeric types (dates/times as serials), `String`,
/// `bool`, or `null` (empty cells, errors and values of a minority type).
final class QueryTable {
  /// Column identifiers (sheet column letters or `Col1…`).
  final List<String> ids;

  /// Header labels (empty when there is no header row).
  final List<String> labels;

  final List<QType> types;
  final List<List<Object?>> columns;

  /// Display format of each column's first typed value (bare column output).
  final List<FormatHint> hints;

  final int rowCount;

  QueryTable._(this.ids, this.labels, this.types, this.columns, this.hints, this.rowCount);

  /// Index of the column with identifier [id] (case-insensitive), or -1.
  int indexOf(String id) {
    final u = id.toUpperCase();
    for (var i = 0; i < ids.length; i++) {
      if (ids[i].toUpperCase() == u) return i;
    }
    return -1;
  }

  /// Builds the table from [data] with the column [ids]; [headers] < 0 auto-detects.
  factory QueryTable.build(FArray data, List<String> ids, int headers) {
    final rows = data.rows, cols = data.cols;
    var h = headers < 0 ? _detectHeaders(data) : headers;
    if (h > rows) h = rows;
    final labels = <String>[];
    final types = <QType>[];
    final columns = <List<Object?>>[];
    final hints = <FormatHint>[];
    final n = rows - h;
    final kinds = List<QType?>.filled(n, null);
    for (var c = 0; c < cols; c++) {
      final parts = <String>[];
      for (var r = 0; r < h; r++) {
        final t = _headerText(data.at(r, c));
        if (t.isNotEmpty) parts.add(t);
      }
      labels.add(parts.join(' '));
      final counts = List<int>.filled(QType.values.length, 0);
      for (var r = 0; r < n; r++) {
        final k = classify(data.at(h + r, c));
        kinds[r] = k;
        if (k != null) counts[k.index]++;
      }
      var type = QType.string;
      var best = 0;
      for (final t in const [
        QType.number,
        QType.date,
        QType.datetime,
        QType.timeofday,
        QType.boolean,
        QType.string,
      ]) {
        if (counts[t.index] > best) {
          best = counts[t.index];
          type = t;
        }
      }
      final values = List<Object?>.filled(n, null);
      FormatHint? hint;
      for (var r = 0; r < n; r++) {
        if (kinds[r] != type) continue;
        var v = data.at(h + r, c);
        if (v is FRich) v = v.scalar;
        switch (v) {
          case FNumber(:final v, hint: final fh):
            values[r] = v;
            hint ??= fh;
          case FText(:final v):
            values[r] = v;
          case FBool(:final v):
            values[r] = v;
          default:
            break;
        }
      }
      types.add(type);
      columns.add(values);
      hints.add(hint ?? FormatHint.none);
    }
    return QueryTable._(ids, labels, types, columns, hints, n);
  }

  static String _headerText(FValue v) => switch (v) {
    FText(:final v) => v.trim(),
    FNumber(:final v) => Numeric.toText(v),
    FBool(:final v) => v ? 'TRUE' : 'FALSE',
    FRich(:final scalar) => _headerText(scalar),
    _ => '',
  };

  /// One header row when, in some column, the first row is text while most non-empty values
  /// below it are not text; otherwise none.
  static int _detectHeaders(FArray data) {
    if (data.rows < 2) return 0;
    for (var c = 0; c < data.cols; c++) {
      final first = classify(data.at(0, c));
      if (first != QType.string) continue;
      var text = 0, other = 0;
      for (var r = 1; r < data.rows; r++) {
        final k = classify(data.at(r, c));
        if (k == null) continue;
        if (k == QType.string) {
          text++;
        } else {
          other++;
        }
      }
      if (other > text) return 1;
    }
    return 0;
  }

  static final Map<String, QType> _patternTypes = {};

  /// Query type of a cell value (null for empty cells, empty text and errors).
  static QType? classify(FValue v) {
    if (v is FRich) v = v.scalar;
    switch (v) {
      case FNumber(:final hint):
        return switch (hint.kind) {
          FormatHintKind.date => QType.date,
          FormatHintKind.dateTime => QType.datetime,
          FormatHintKind.time => QType.timeofday,
          FormatHintKind.fromCell => _patternTypes[hint.detail ?? ''] ??= patternType(hint.detail ?? ''),
          _ => QType.number,
        };
      case FText(:final v):
        return v.isEmpty ? null : QType.string;
      case FBool():
        return QType.boolean;
      default:
        return null;
    }
  }

  /// Type implied by a number format pattern: date tokens (`y`, `d`) → date, time tokens
  /// (`h`, `s`, AM/PM) → time of day, both → date-time, neither → number.
  static QType patternType(String pattern) {
    switch (pattern) {
      case 'preset:date':
        return QType.date;
      case 'preset:dateTime':
        return QType.datetime;
      case 'preset:time':
        return QType.timeofday;
    }
    if (pattern.startsWith('preset:')) return QType.number;
    var date = false, time = false, inQuote = false;
    final p = pattern.split(';').first;
    for (var i = 0; i < p.length; i++) {
      final c = p[i];
      if (c == '"') {
        inQuote = !inQuote;
        continue;
      }
      if (inQuote) continue;
      if (c == '\\') {
        i++;
        continue;
      }
      if (c == '[') {
        final end = p.indexOf(']', i);
        if (end < 0) break;
        final inner = p.substring(i + 1, end).toLowerCase();
        if (inner == 'h' || inner == 'hh' || inner == 'm' || inner == 'mm' || inner == 's' || inner == 'ss') {
          time = true;
        }
        i = end;
        continue;
      }
      final l = c.toLowerCase();
      if (l == 'y' || l == 'd') date = true;
      if (l == 'h' || l == 's') time = true;
      if (l == 'a' && p.substring(i).toLowerCase().startsWith('am/pm')) time = true;
    }
    if (date && time) return QType.datetime;
    if (date) return QType.date;
    if (time) return QType.timeofday;
    return QType.number;
  }
}
