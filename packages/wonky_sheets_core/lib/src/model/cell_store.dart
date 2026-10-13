import 'axis_index.dart';
import 'records.dart';

/// Sparse cell storage of one sheet (02 §6), keyed by row and column ids so
/// structural changes (insert/delete/move rows) never re-key cells.
final class CellStore {
  final Map<String, CellRecord> _byId = {};
  final Map<String, Map<String, CellRecord>> _rows = {};
  final Map<String, Map<String, CellRecord>> _cols = {};
  int _contentCount = 0;

  /// Number of cell rows (content or format-only).
  int get count => _byId.length;

  /// Number of cells with content.
  int get contentCount => _contentCount;

  /// Cell at (rowId, colId) or null.
  CellRecord? at(String rowId, String colId) => _rows[rowId]?[colId];

  /// Cell by id or null.
  CellRecord? byId(String id) => _byId[id];

  /// All cells (unordered).
  Iterable<CellRecord> get all => _byId.values;

  /// Cells of a row (unordered).
  Iterable<CellRecord> inRow(String rowId) => _rows[rowId]?.values ?? const [];

  /// Cells of a column (unordered).
  Iterable<CellRecord> inColumn(String colId) =>
      _cols[colId]?.values ?? const [];

  /// Number of cells in a row.
  int rowCount(String rowId) => _rows[rowId]?.length ?? 0;

  /// Number of cells in a column.
  int columnCount(String colId) => _cols[colId]?.length ?? 0;

  /// Row ids that hold at least one cell.
  Iterable<String> get rowIds => _rows.keys;

  /// Column ids that hold at least one cell.
  Iterable<String> get columnIds => _cols.keys;

  /// Inserts or replaces a cell. A blank record (all fields null) is removed.
  void put(CellRecord cell) {
    final old = _byId[cell.id];
    if (old != null) _detach(old);
    if (cell.isBlankRow) return;
    _byId[cell.id] = cell;
    (_rows[cell.rowId] ??= {})[cell.columnId] = cell;
    (_cols[cell.columnId] ??= {})[cell.rowId] = cell;
    if (cell.content != null) _contentCount++;
  }

  /// Removes a cell by id; returns the removed record.
  CellRecord? remove(String id) {
    final old = _byId[id];
    if (old != null) _detach(old);
    return old;
  }

  void _detach(CellRecord c) {
    _byId.remove(c.id);
    final r = _rows[c.rowId];
    if (r != null) {
      r.remove(c.columnId);
      if (r.isEmpty) _rows.remove(c.rowId);
    }
    final col = _cols[c.columnId];
    if (col != null) {
      col.remove(c.rowId);
      if (col.isEmpty) _cols.remove(c.columnId);
    }
    if (c.content != null) _contentCount--;
  }

  /// Removes every cell of a row; returns them.
  List<CellRecord> removeRow(String rowId) {
    final cells = List.of(_rows[rowId]?.values ?? const <CellRecord>[]);
    for (final c in cells) {
      _detach(c);
    }
    return cells;
  }

  /// Removes every cell of a column; returns them.
  List<CellRecord> removeColumn(String colId) {
    final cells = List.of(_cols[colId]?.values ?? const <CellRecord>[]);
    for (final c in cells) {
      _detach(c);
    }
    return cells;
  }

  /// Removes all cells.
  void clear() {
    _byId.clear();
    _rows.clear();
    _cols.clear();
    _contentCount = 0;
  }

  /// Cells inside the index rectangle, in row-major index order.
  ///
  /// Iterates whichever is smaller: the rows of the rectangle or the stored
  /// cells, so whole-column ranges cost O(non-empty cells).
  Iterable<(int row, int col, CellRecord cell)> cellsIn(
    AxisIndex rows,
    AxisIndex cols,
    int top,
    int left,
    int bottom,
    int right, {
    bool contentOnly = false,
  }) sync* {
    if (_byId.isEmpty) return;
    final rTop = top < 0 ? 0 : top;
    final rBottom = bottom >= rows.length ? rows.length - 1 : bottom;
    final cLeft = left < 0 ? 0 : left;
    final cRight = right >= cols.length ? cols.length - 1 : right;
    if (rBottom < rTop || cRight < cLeft) return;
    final rowSpan = rBottom - rTop + 1;
    if (rowSpan <= _rows.length) {
      for (var r = rTop; r <= rBottom; r++) {
        final rowCells = _rows[rows.idAt(r)];
        if (rowCells == null) continue;
        yield* _rowCells(r, rowCells, cols, cLeft, cRight, contentOnly);
      }
    } else {
      final hits = <(int, String)>[];
      for (final rowId in _rows.keys) {
        final r = rows.indexOf(rowId);
        if (r >= rTop && r <= rBottom) hits.add((r, rowId));
      }
      hits.sort((a, b) => a.$1.compareTo(b.$1));
      for (final (r, rowId) in hits) {
        yield* _rowCells(r, _rows[rowId]!, cols, cLeft, cRight, contentOnly);
      }
    }
  }

  Iterable<(int, int, CellRecord)> _rowCells(
    int r,
    Map<String, CellRecord> rowCells,
    AxisIndex cols,
    int cLeft,
    int cRight,
    bool contentOnly,
  ) sync* {
    final colSpan = cRight - cLeft + 1;
    if (colSpan <= rowCells.length) {
      for (var c = cLeft; c <= cRight; c++) {
        final cell = rowCells[cols.idAt(c)];
        if (cell == null || (contentOnly && cell.content == null)) continue;
        yield (r, c, cell);
      }
    } else {
      final hits = <(int, CellRecord)>[];
      for (final cell in rowCells.values) {
        if (contentOnly && cell.content == null) continue;
        final c = cols.indexOf(cell.columnId);
        if (c >= cLeft && c <= cRight) hits.add((c, cell));
      }
      hits.sort((a, b) => a.$1.compareTo(b.$1));
      for (final (c, cell) in hits) {
        yield (r, c, cell);
      }
    }
  }

  /// The bounding rectangle `(bottomRow, rightCol)` of cells with content
  /// (or any cell when [includeFormatOnly]), as indices; null when empty.
  (int lastRow, int lastCol)? usedExtent(
    AxisIndex rows,
    AxisIndex cols, {
    bool includeFormatOnly = false,
  }) {
    var lastRow = -1;
    var lastCol = -1;
    for (final e in _rows.entries) {
      if (!includeFormatOnly && !e.value.values.any((c) => c.content != null)) {
        continue;
      }
      final r = rows.indexOf(e.key);
      if (r > lastRow) lastRow = r;
    }
    for (final e in _cols.entries) {
      if (!includeFormatOnly && !e.value.values.any((c) => c.content != null)) {
        continue;
      }
      final c = cols.indexOf(e.key);
      if (c > lastCol) lastCol = c;
    }
    if (lastRow < 0 || lastCol < 0) return null;
    return (lastRow, lastCol);
  }
}
