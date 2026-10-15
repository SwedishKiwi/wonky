import 'text_layout.dart';

/// One visible cell of a [TableGrid] (a merge origin covers its span).
final class TableGridCell {
  /// Creates a grid cell.
  const TableGridCell({
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.colSpan,
    required this.rowId,
    required this.columnId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.padding,
    required this.vAlign,
    required this.styles,
    this.layout,
  });

  /// Row index of the cell (the merge origin's).
  final int row;

  /// Column index of the cell.
  final int column;

  /// Rows covered (1 unless merged).
  final int rowSpan;

  /// Columns covered.
  final int colSpan;

  /// Row axis id.
  final String rowId;

  /// Column axis id.
  final String columnId;

  /// Box in element-local su (the table's frame origin is 0, 0).
  final double x;
  final double y;
  final double width;
  final double height;

  /// Padding `[t, r, b, l]` (su).
  final List<double> padding;

  /// `top`, `middle` or `bottom`.
  final String vAlign;

  /// The text styles of the cell (theme table areas, 05 §2.8).
  final ResolvedTextStyles styles;

  /// The laid-out text, or null for a blank cell.
  final TextLayoutResult? layout;

  /// Width available to the text (su).
  double get textWidth => (width - padding[1] - padding[3]).clamp(1.0, 1e9);

  /// The text origin (element-local su) for a body of [textHeight].
  ({double x, double y}) textOrigin(double textHeight) {
    final avail = height - padding[0] - padding[2];
    final free = avail - textHeight;
    final dy = switch (vAlign) {
      'middle' => free / 2,
      'bottom' => free,
      _ => 0.0,
    };
    return (x: x + padding[3], y: y + padding[0] + dy);
  }

  /// Whether element-local point ([px], [py]) is inside the cell.
  bool contains(double px, double py) =>
      px >= x && px <= x + width && py >= y && py <= y + height;

  /// `"<rowId>|<columnId>"` (the cell's `TextNode.partId`).
  String get partId => '$rowId|$columnId';
}

/// The laid-out grid of a table element (SL-15; 02 §3.6, 03 §6.6): column
/// and row edges in element-local su (rows grown to fit their text) and
/// the visible cells. Canvas hit tests, cell editing, border dragging and
/// range highlights use it; the renderer draws the same layout.
final class TableGrid {
  /// Creates a grid.
  const TableGrid({
    required this.elementId,
    required this.columnX,
    required this.rowY,
    required this.cells,
    required this.rowIds,
    required this.columnIds,
  });

  /// The table element.
  final String elementId;

  /// Column edges (`columns + 1` values, first 0).
  final List<double> columnX;

  /// Row edges (`rows + 1` values, first 0; the last is the grown height).
  final List<double> rowY;

  /// Visible cells (merge origins and unmerged cells), row-major.
  final List<TableGridCell> cells;

  /// Row axis ids in order.
  final List<String> rowIds;

  /// Column axis ids in order.
  final List<String> columnIds;

  /// Number of rows.
  int get rows => rowIds.length;

  /// Number of columns.
  int get columns => columnIds.length;

  /// The grown table height (su).
  double get height => rowY.last;

  /// The table width (su).
  double get width => columnX.last;

  /// The visible cell covering ([r], [c]), or null.
  TableGridCell? cellAt(int r, int c) {
    for (final cell in cells) {
      if (r >= cell.row &&
          r < cell.row + cell.rowSpan &&
          c >= cell.column &&
          c < cell.column + cell.colSpan) {
        return cell;
      }
    }
    return null;
  }

  /// The visible cell at element-local point ([x], [y]), or null.
  TableGridCell? cellAtPoint(double x, double y) {
    for (final cell in cells) {
      if (cell.contains(x, y)) return cell;
    }
    return null;
  }

  /// The visible cell of [rowId] × [columnId] (or the merge covering it).
  TableGridCell? cellOf(String rowId, String columnId) {
    final r = rowIds.indexOf(rowId), c = columnIds.indexOf(columnId);
    return r < 0 || c < 0 ? null : cellAt(r, c);
  }
}
