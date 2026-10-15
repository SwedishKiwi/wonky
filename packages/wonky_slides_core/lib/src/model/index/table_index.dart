import '../api/deck_reader.dart';
import '../api/kinds.dart';
import '../api/records.dart';

/// A merge of table cells: the origin cell spans [rowSpan] × [colSpan] axes.
final class TableMerge {
  /// Creates a merge.
  const TableMerge(
    this.origin,
    this.row,
    this.column,
    this.rowSpan,
    this.colSpan,
  );

  /// The origin cell row.
  final SlideTableCellRec origin;

  /// Row index of the origin.
  final int row;

  /// Column index of the origin.
  final int column;

  /// Rows spanned (clipped to the table).
  final int rowSpan;

  /// Columns spanned (clipped to the table).
  final int colSpan;

  /// Whether the merge covers cell ([r], [c]).
  bool covers(int r, int c) =>
      r >= row && r < row + rowSpan && c >= column && c < column + colSpan;

  /// Whether two merges overlap.
  bool overlaps(TableMerge o) =>
      row < o.row + o.rowSpan &&
      o.row < row + rowSpan &&
      column < o.column + o.colSpan &&
      o.column < column + colSpan;
}

/// One table's structure (02 §11 `TableIndex`): axes by `(sortKey, id)`,
/// cells by `(row, column)`, and merges with the overlap rule of 02 §10
/// (the merge whose origin has the smaller id wins).
final class TableIndex {
  TableIndex._(
    this.elementId,
    this.rows,
    this.columns,
    this._cells,
    this.merges,
    this.overlapping,
    this.danglingCells,
  );

  /// Builds the index of table [elementId].
  factory TableIndex.of(DeckReader deck, String elementId) {
    final rows = deck.axesOf(elementId, TableAxisDimension.row);
    final cols = deck.axesOf(elementId, TableAxisDimension.column);
    final rowIndex = {for (final (i, r) in rows.indexed) r.id: i};
    final colIndex = {for (final (i, c) in cols.indexed) c.id: i};
    final cells = <String, SlideTableCellRec>{};
    final dangling = <SlideTableCellRec>[];
    final candidates = <TableMerge>[];
    for (final c in deck.cellsOf(elementId)) {
      final r = rowIndex[c.rowId], k = colIndex[c.columnId];
      if (r == null || k == null) {
        dangling.add(c);
        continue;
      }
      cells['${c.rowId}|${c.columnId}'] = c;
      if (c.rowSpan > 1 || c.colSpan > 1) {
        candidates.add(
          TableMerge(
            c,
            r,
            k,
            (c.rowSpan).clamp(1, rows.length - r),
            (c.colSpan).clamp(1, cols.length - k),
          ),
        );
      }
    }
    candidates.sort((a, b) => a.origin.id.compareTo(b.origin.id));
    final merges = <TableMerge>[];
    final overlapping = <TableMerge>[];
    for (final m in candidates) {
      if (merges.any(m.overlaps)) {
        overlapping.add(m);
      } else {
        merges.add(m);
      }
    }
    return TableIndex._(
      elementId,
      rows,
      cols,
      cells,
      merges,
      overlapping,
      dangling,
    );
  }

  /// The table element.
  final String elementId;

  /// Row axes in order.
  final List<SlideTableAxisRec> rows;

  /// Column axes in order.
  final List<SlideTableAxisRec> columns;

  final Map<String, SlideTableCellRec> _cells;

  /// Effective merges (no two overlap).
  final List<TableMerge> merges;

  /// Merges that lose to an overlapping merge with a smaller origin id.
  final List<TableMerge> overlapping;

  /// Cells whose row or column axis is gone (hidden, 02 §10).
  final List<SlideTableCellRec> danglingCells;

  /// The cell at row [rowId] and column [columnId], or null.
  SlideTableCellRec? cell(String rowId, String columnId) =>
      _cells['$rowId|$columnId'];

  /// The cell at indexes ([r], [c]), or null.
  SlideTableCellRec? cellAt(int r, int c) {
    if (r < 0 || c < 0 || r >= rows.length || c >= columns.length) {
      return null;
    }
    return cell(rows[r].id, columns[c].id);
  }

  /// The effective merge covering ([r], [c]), or null.
  TableMerge? mergeAt(int r, int c) {
    for (final m in merges) {
      if (m.covers(r, c)) return m;
    }
    return null;
  }

  /// Index of axis [axisId] in its dimension, or -1.
  int indexOf(String axisId) {
    final r = rows.indexWhere((a) => a.id == axisId);
    if (r >= 0) return r;
    return columns.indexWhere((a) => a.id == axisId);
  }
}
