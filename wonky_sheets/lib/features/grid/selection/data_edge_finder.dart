import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

/// Direction of keyboard navigation.
enum NavDirection {
  up(-1, 0),
  down(1, 0),
  left(0, -1),
  right(0, 1);

  const NavDirection(this.dRow, this.dCol);

  final int dRow;
  final int dCol;

  bool get vertical => dRow != 0;

  static NavDirection? tryParse(String? name) =>
      values.where((d) => d.name == name).firstOrNull;
}

/// Data edges for Mod+arrows and the data region for Mod+A (03 §6.3).
///
/// "Non-empty" means a cell with content; spilled values count through
/// [hasValue] when given.
class DataEdgeFinder {
  DataEdgeFinder(this.sheet, {this.hasValue});

  final SheetModel sheet;
  final bool Function(int row, int col)? hasValue;

  bool occupied(int row, int col) {
    final c = sheet.cellAt(row, col);
    if (c?.content != null) return true;
    return hasValue?.call(row, col) ?? false;
  }

  AxisIndex _axis(NavDirection d) => d.vertical ? sheet.rows : sheet.columns;

  /// The next visible index after [from] in [d], or null at the edge.
  int? _step(NavDirection d, int from) {
    final axis = _axis(d);
    final dir = d.vertical ? d.dRow : d.dCol;
    final next = from + dir;
    if (next < 0 || next >= axis.length) return null;
    return axis.nextVisible(next, dir);
  }

  /// The target of Mod+arrow from (row, col) in [d].
  (int, int) next(int row, int col, NavDirection d) {
    bool occ(int i) => d.vertical ? occupied(i, col) : occupied(row, i);
    final cur = d.vertical ? row : col;
    final n = _step(d, cur);
    if (n == null) return (row, col);
    int result;
    if (occ(cur) && occ(n)) {
      var last = n;
      while (true) {
        final m = _step(d, last);
        if (m == null || !occ(m)) break;
        last = m;
      }
      result = last;
    } else {
      final found = _firstOccupied(d, row, col, n);
      result = found ?? _edge(d);
    }
    return d.vertical ? (result, col) : (row, result);
  }

  int _edge(NavDirection d) {
    final axis = _axis(d);
    final dir = d.vertical ? d.dRow : d.dCol;
    final start = dir > 0 ? axis.length - 1 : 0;
    return axis.nextVisible(start, -dir) ?? start;
  }

  /// First occupied visible index at or after [from] in [d] on the line.
  int? _firstOccupied(NavDirection d, int row, int col, int from) {
    final dir = d.vertical ? d.dRow : d.dCol;
    final candidates = <int>[];
    if (d.vertical) {
      final colId = sheet.columns.tryIdAt(col);
      if (colId == null) return null;
      for (final c in sheet.cells.inColumn(colId)) {
        if (c.content == null) continue;
        final r = sheet.rows.indexOf(c.rowId);
        if (r >= 0) candidates.add(r);
      }
    } else {
      final rowId = sheet.rows.tryIdAt(row);
      if (rowId == null) return null;
      for (final c in sheet.cells.inRow(rowId)) {
        if (c.content == null) continue;
        final i = sheet.columns.indexOf(c.columnId);
        if (i >= 0) candidates.add(i);
      }
    }
    candidates.sort();
    final axis = _axis(d);
    int? best;
    if (dir > 0) {
      for (final i in candidates) {
        if (i >= from && !axis.isHidden(i)) {
          best = i;
          break;
        }
      }
    } else {
      for (final i in candidates.reversed) {
        if (i <= from && !axis.isHidden(i)) {
          best = i;
          break;
        }
      }
    }
    // Spilled values next to the start count too.
    if (hasValue != null) {
      var i = from;
      for (var k = 0; k < 200; k++) {
        final occupiedHere = d.vertical ? hasValue!(i, col) : hasValue!(row, i);
        if (occupiedHere) {
          if (best == null || (dir > 0 ? i < best : i > best)) best = i;
          break;
        }
        final m = _step(d, i);
        if (m == null) break;
        i = m;
      }
    }
    return best;
  }

  /// The contiguous (8-connected) data region around (row, col), or null
  /// when the cell and its neighbours are empty (03 §6.3).
  GridRect? region(int row, int col) {
    final maxR = sheet.rows.length - 1;
    final maxC = sheet.columns.length - 1;
    if (maxR < 0 || maxC < 0) return null;
    var rect = GridRect.cell(row, col);
    bool anyIn(GridRect r) {
      final clipped = r.intersection(GridRect(0, 0, maxR, maxC));
      if (clipped == null) return false;
      return sheet.cellsIn(clipped, contentOnly: true).isNotEmpty;
    }

    if (!occupied(row, col) &&
        !anyIn(GridRect(row - 1, col - 1, row + 1, col + 1))) {
      return null;
    }
    for (var guard = 0; guard < 100000; guard++) {
      var grown = rect;
      if (rect.top > 0 &&
          anyIn(
            GridRect(rect.top - 1, rect.left - 1, rect.top - 1, rect.right + 1),
          )) {
        grown = GridRect(rect.top - 1, grown.left, grown.bottom, grown.right);
      }
      if (rect.bottom < maxR &&
          anyIn(
            GridRect(
              rect.bottom + 1,
              rect.left - 1,
              rect.bottom + 1,
              rect.right + 1,
            ),
          )) {
        grown = GridRect(grown.top, grown.left, rect.bottom + 1, grown.right);
      }
      if (rect.left > 0 &&
          anyIn(
            GridRect(
              rect.top - 1,
              rect.left - 1,
              rect.bottom + 1,
              rect.left - 1,
            ),
          )) {
        grown = GridRect(grown.top, rect.left - 1, grown.bottom, grown.right);
      }
      if (rect.right < maxC &&
          anyIn(
            GridRect(
              rect.top - 1,
              rect.right + 1,
              rect.bottom + 1,
              rect.right + 1,
            ),
          )) {
        grown = GridRect(grown.top, grown.left, grown.bottom, rect.right + 1);
      }
      if (grown == rect) break;
      rect = grown;
      if (rect.cellCount > 1000000) break;
    }
    return rect;
  }

  /// The last used cell (max used row × max used column) for Mod+End.
  (int, int) lastUsed() {
    final used = sheet.usedRect();
    if (used == null) return (0, 0);
    return (used.bottom, used.right);
  }

  /// The last non-empty column of [row] (End).
  int rowEnd(int row) {
    final rowId = sheet.rows.tryIdAt(row);
    var last = 0;
    if (rowId == null) return 0;
    for (final c in sheet.cells.inRow(rowId)) {
      if (c.content == null) continue;
      final i = sheet.columns.indexOf(c.columnId);
      if (i > last) last = i;
    }
    return last;
  }
}
