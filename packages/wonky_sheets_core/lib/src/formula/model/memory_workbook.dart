import '../../addressing/grid_geometry.dart';
import 'workbook_view.dart';

/// Minimal fractional keys (base-62, lexicographic) for [MemoryAxis].
abstract final class _Keys {
  static const String digits =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

  static String midpoint(String a, String? b) {
    if (b != null) {
      var n = 0;
      while (n < b.length && (n < a.length ? a[n] : '0') == b[n]) {
        n++;
      }
      if (n > 0) {
        return b.substring(0, n) + midpoint(n < a.length ? a.substring(n) : '', b.substring(n));
      }
    }
    final da = a.isEmpty ? 0 : digits.indexOf(a[0]);
    final db = b == null ? digits.length : digits.indexOf(b[0]);
    if (db - da > 1) {
      return digits[((da + db) / 2).round()];
    }
    if (b != null && b.length > 1) return b.substring(0, 1);
    return digits[da] + midpoint(a.length > 1 ? a.substring(1) : '', null);
  }

  static List<String> initial(int n) {
    // Evenly spaced 4-digit keys.
    final out = <String>[];
    const space = 62 * 62 * 62 * 62;
    final step = space ~/ (n + 1);
    for (var i = 1; i <= n; i++) {
      var v = step * i;
      final c = List<String>.filled(4, '0');
      for (var k = 3; k >= 0; k--) {
        c[k] = digits[v % 62];
        v ~/= 62;
      }
      var s = c.join();
      while (s.endsWith('0') && s.length > 1) {
        s = s.substring(0, s.length - 1);
      }
      out.add(s);
    }
    return out;
  }
}

/// Generates deterministic UUID-shaped ids for in-memory workbooks.
final class MemoryIdGenerator {
  int _next;
  final int _prefix;
  MemoryIdGenerator({int seed = 1, int prefix = 0}) : _next = seed, _prefix = prefix;

  String next() {
    final n = _next++;
    final p = _prefix.toRadixString(16).padLeft(8, '0');
    return '$p-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';
  }
}

/// In-memory [AxisView] with insert/delete/move.
final class MemoryAxis implements AxisView {
  final List<String> _ids;
  final List<String> _keys;
  final Map<String, int> _index = {};
  final Set<String> hidden = {};
  final MemoryIdGenerator _gen;

  MemoryAxis(int length, this._gen) : _ids = [], _keys = _Keys.initial(length) {
    for (var i = 0; i < length; i++) {
      _ids.add(_gen.next());
    }
    _reindex();
  }

  void _reindex() {
    _index.clear();
    for (var i = 0; i < _ids.length; i++) {
      _index[_ids[i]] = i;
    }
  }

  @override
  int get length => _ids.length;

  @override
  String idAt(int index) => _ids[index];

  @override
  int indexOf(String id) => _index[id] ?? -1;

  @override
  String sortKeyAt(int index) => _keys[index];

  @override
  int lowerBound(String sortKey, String id) {
    var lo = 0, hi = _ids.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      final c = _keys[mid].compareTo(sortKey);
      final less = c < 0 || (c == 0 && _ids[mid].compareTo(id) < 0);
      if (less) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  @override
  bool isHidden(int index) => hidden.contains(_ids[index]);

  /// Inserts [count] new entries before [index]; returns their ids.
  List<String> insert(int index, int count) {
    final before = index > 0 ? _keys[index - 1] : '';
    final after = index < _keys.length ? _keys[index] : null;
    final ids = <String>[];
    final keys = <String>[];
    var lo = before;
    for (var i = 0; i < count; i++) {
      final k = _Keys.midpoint(lo, after);
      keys.add(k);
      ids.add(_gen.next());
      lo = k;
    }
    _ids.insertAll(index, ids);
    _keys.insertAll(index, keys);
    _reindex();
    return ids;
  }

  /// Deletes [count] entries at [index]; returns their ids.
  List<String> delete(int index, int count) {
    final ids = _ids.sublist(index, index + count);
    _ids.removeRange(index, index + count);
    _keys.removeRange(index, index + count);
    _reindex();
    return ids;
  }

  /// Moves [count] entries at [from] so that they start at [to] (index in the result).
  List<String> move(int from, int count, int to) {
    final ids = _ids.sublist(from, from + count);
    _ids.removeRange(from, from + count);
    _keys.removeRange(from, from + count);
    final before = to > 0 ? _keys[to - 1] : '';
    final after = to < _keys.length ? _keys[to] : null;
    final keys = <String>[];
    var lo = before;
    for (var i = 0; i < count; i++) {
      final k = _Keys.midpoint(lo, after);
      keys.add(k);
      lo = k;
    }
    _ids.insertAll(to, ids);
    _keys.insertAll(to, keys);
    _reindex();
    return ids;
  }

  /// Applies a permutation: new order = [order] (list of old indices). Sort keys are reassigned.
  void permute(List<int> order) {
    final ids = [for (final i in order) _ids[i]];
    _ids
      ..clear()
      ..addAll(ids);
    final keys = _Keys.initial(ids.length);
    _keys
      ..clear()
      ..addAll(keys);
    _reindex();
  }
}

/// In-memory [SheetView]; cells are keyed by (rowId, colId) so structural changes move them.
final class MemorySheet implements SheetView {
  @override
  final String id;
  @override
  String name;
  @override
  final MemoryAxis rows;
  @override
  final MemoryAxis columns;

  final Map<String, Map<String, CellInput>> _cells = {};
  final Map<String, Map<String, String>> _formats = {};
  final Set<String> filterHiddenRows = {};
  final Map<String, double> columnWidths = {};
  int _usedRows = -1;
  int _usedCols = -1;

  MemorySheet(this.id, this.name, int rowCount, int colCount, MemoryIdGenerator gen)
    : rows = MemoryAxis(rowCount, gen),
      columns = MemoryAxis(colCount, gen);

  void _invalidate() {
    _usedRows = -1;
    _usedCols = -1;
  }

  /// Sets (or clears with null) the content at current indices.
  void setInput(int row, int col, CellInput? input) {
    final rid = rows.idAt(row);
    final cid = columns.idAt(col);
    if (input == null) {
      final m = _cells[rid];
      m?.remove(cid);
      if (m != null && m.isEmpty) _cells.remove(rid);
    } else {
      (_cells[rid] ??= {})[cid] = input;
    }
    _invalidate();
  }

  void setNumberFormat(int row, int col, String? format) {
    final rid = rows.idAt(row);
    final cid = columns.idAt(col);
    if (format == null) {
      _formats[rid]?.remove(cid);
    } else {
      (_formats[rid] ??= {})[cid] = format;
    }
  }

  /// Removes cells whose row or column no longer exists (after deletes).
  void purgeDeleted() {
    _cells.removeWhere((rid, _) => rows.indexOf(rid) < 0);
    for (final m in _cells.values) {
      m.removeWhere((cid, _) => columns.indexOf(cid) < 0);
    }
    _cells.removeWhere((_, m) => m.isEmpty);
    _invalidate();
  }

  /// Notifies the sheet that the axes changed (used extent cache).
  void structureChanged() => _invalidate();

  @override
  CellInput? inputAt(int row, int col) {
    if (row < 0 || col < 0 || row >= rows.length || col >= columns.length) return null;
    final m = _cells[rows.idAt(row)];
    if (m == null) return null;
    return m[columns.idAt(col)];
  }

  @override
  void forEachInput(GridRect rect, void Function(int row, int col, CellInput input) visit) {
    final r2 = rect.bottom < usedRowCount - 1 ? rect.bottom : usedRowCount - 1;
    final c2 = rect.right < usedColumnCount - 1 ? rect.right : usedColumnCount - 1;
    final r1 = rect.top < 0 ? 0 : rect.top;
    final c1 = rect.left < 0 ? 0 : rect.left;
    if (r1 > r2 || c1 > c2) return;
    final width = c2 - c1 + 1;
    for (var r = r1; r <= r2; r++) {
      final m = _cells[rows.idAt(r)];
      if (m == null) continue;
      if (width <= m.length * 2) {
        for (var c = c1; c <= c2; c++) {
          final v = m[columns.idAt(c)];
          if (v != null) visit(r, c, v);
        }
      } else {
        final entries = <(int, CellInput)>[];
        m.forEach((cid, v) {
          final c = columns.indexOf(cid);
          if (c >= c1 && c <= c2) entries.add((c, v));
        });
        entries.sort((a, b) => a.$1 - b.$1);
        for (final (c, v) in entries) {
          visit(r, c, v);
        }
      }
    }
  }

  void _computeUsed() {
    var mr = 0, mc = 0;
    _cells.forEach((rid, m) {
      final r = rows.indexOf(rid);
      if (r < 0) return;
      var any = false;
      for (final cid in m.keys) {
        final c = columns.indexOf(cid);
        if (c < 0) continue;
        any = true;
        if (c + 1 > mc) mc = c + 1;
      }
      if (any && r + 1 > mr) mr = r + 1;
    });
    _usedRows = mr;
    _usedCols = mc;
  }

  @override
  int get usedRowCount {
    if (_usedRows < 0) _computeUsed();
    return _usedRows;
  }

  @override
  int get usedColumnCount {
    if (_usedCols < 0) _computeUsed();
    return _usedCols;
  }

  @override
  String? numberFormatAt(int row, int col) {
    if (row < 0 || col < 0 || row >= rows.length || col >= columns.length) return null;
    return _formats[rows.idAt(row)]?[columns.idAt(col)];
  }

  @override
  bool isRowFilterHidden(int row) => filterHiddenRows.contains(rows.idAt(row));

  @override
  double columnWidthAt(int col) => columnWidths[columns.idAt(col)] ?? 100;
}

/// In-memory named range / named function.
final class MemoryNamedRange implements NamedRangeView {
  @override
  final String id;
  @override
  String name;
  @override
  IdRange? range;
  @override
  String? formula;
  @override
  String? comment;
  @override
  String? metaJson;

  MemoryNamedRange(this.id, this.name, {this.range, this.formula, this.comment, this.metaJson});
}

/// In-memory [WorkbookView] for tests, previews and headless use.
final class MemoryWorkbook implements WorkbookView {
  @override
  final String spreadsheetId;
  final MemoryIdGenerator ids;
  final List<MemorySheet> _sheets = [];
  final List<MemoryNamedRange> names = [];
  @override
  CalcSettings settings;

  MemoryWorkbook({
    this.spreadsheetId = 'spreadsheet',
    this.settings = const CalcSettings(),
    MemoryIdGenerator? ids,
  }) : ids = ids ?? MemoryIdGenerator();

  /// Adds a sheet with [rows] × [cols] entities.
  MemorySheet addSheet(String name, {int rows = 1000, int cols = 26, int? at}) {
    final s = MemorySheet(ids.next(), name, rows, cols, ids);
    if (at == null) {
      _sheets.add(s);
    } else {
      _sheets.insert(at, s);
    }
    return s;
  }

  void removeSheet(String id) => _sheets.removeWhere((s) => s.id == id);

  /// Re-inserts a previously removed sheet (undo of delete keeps the id).
  void restoreSheet(MemorySheet sheet, {int? at}) {
    if (at == null) {
      _sheets.add(sheet);
    } else {
      _sheets.insert(at, sheet);
    }
  }

  @override
  List<MemorySheet> get sheets => List.unmodifiable(_sheets);

  @override
  MemorySheet? sheetById(String id) {
    for (final s in _sheets) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  MemorySheet? sheetByName(String name) {
    final u = name.toLowerCase();
    for (final s in _sheets) {
      if (s.name.toLowerCase() == u) return s;
    }
    return null;
  }

  @override
  Iterable<NamedRangeView> get namedRanges => names;

  MemoryNamedRange addNamedRange(String name, IdRange range, {String? comment}) {
    final n = MemoryNamedRange(ids.next(), name, range: range, comment: comment);
    names.add(n);
    return n;
  }

  MemoryNamedRange addNamedFunction(String name, String storedFormula, {String? metaJson, String? comment}) {
    final n = MemoryNamedRange(
      ids.next(),
      name,
      formula: storedFormula,
      metaJson: metaJson,
      comment: comment,
    );
    names.add(n);
    return n;
  }
}
