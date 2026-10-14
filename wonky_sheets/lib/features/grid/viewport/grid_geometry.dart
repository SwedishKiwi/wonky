import 'dart:math' as math;
import 'dart:ui';

import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

/// Which frozen quadrant a pane is (03 §2.3).
enum PaneKind { corner, top, left, main }

/// One pane of the grid: a screen rectangle showing rows from [firstRow]
/// and columns from [firstCol], scrolled by [scrollX]/[scrollY] (frozen
/// panes don't scroll on their frozen axis).
class GridPane {
  GridPane({
    required this.kind,
    required this.rect,
    required this.geometry,
    required this.firstRow,
    required this.firstCol,
    required this.lastRowLimit,
    required this.lastColLimit,
    required this.scrollX,
    required this.scrollY,
  }) {
    final g = geometry;
    final rows = g.sheet.rows;
    final cols = g.sheet.columns;
    final baseY = rows.offsetOf(firstRow);
    final baseX = cols.offsetOf(firstCol);
    if (rect.isEmpty || rows.length == 0 || cols.length == 0) {
      rowStart = 0;
      rowEnd = -1;
      colStart = 0;
      colEnd = -1;
      return;
    }
    rowStart = math.max(firstRow, rows.indexAtOffset(baseY + scrollY / g.zoom));
    rowEnd = math.min(
      lastRowLimit,
      rows.indexAtOffset(baseY + (scrollY + rect.height) / g.zoom),
    );
    colStart = math.max(firstCol, cols.indexAtOffset(baseX + scrollX / g.zoom));
    colEnd = math.min(
      lastColLimit,
      cols.indexAtOffset(baseX + (scrollX + rect.width) / g.zoom),
    );
    _baseX = baseX;
    _baseY = baseY;
  }

  final PaneKind kind;

  /// Screen rectangle (clip) of the pane.
  final Rect rect;
  final GridGeometry geometry;
  final int firstRow;
  final int firstCol;

  /// Inclusive index limits shown by this pane (frozen panes stop at the
  /// freeze line).
  final int lastRowLimit;
  final int lastColLimit;
  final double scrollX;
  final double scrollY;

  /// Visible index window (inclusive; empty when end < start).
  late final int rowStart;
  late final int rowEnd;
  late final int colStart;
  late final int colEnd;

  double _baseX = 0;
  double _baseY = 0;

  bool get isEmpty => rowEnd < rowStart || colEnd < colStart;

  /// Whether the pane shows cell (row, col).
  bool showsRow(int row) => row >= firstRow && row <= lastRowLimit;
  bool showsCol(int col) => col >= firstCol && col <= lastColLimit;

  /// Left edge of column [col] (snapped).
  double x(int col) => geometry.snap(
    rect.left +
        (geometry.sheet.columns.offsetOf(col) - _baseX) * geometry.zoom -
        scrollX,
  );

  /// Top edge of row [row] (snapped).
  double y(int row) => geometry.snap(
    rect.top +
        (geometry.sheet.rows.offsetOf(row) - _baseY) * geometry.zoom -
        scrollY,
  );

  /// Screen rectangle of one cell.
  Rect cellRect(int row, int col) =>
      Rect.fromLTRB(x(col), y(row), x(col + 1), y(row + 1));

  /// Screen rectangle of [r] (may extend beyond the pane).
  Rect rangeRect(GridRect r) =>
      Rect.fromLTRB(x(r.left), y(r.top), x(r.right + 1), y(r.bottom + 1));

  /// The cell under a screen point inside this pane.
  (int, int) cellAt(Offset p) {
    final g = geometry;
    final row = g.sheet.rows.indexAtOffset(
      _baseY + (p.dy - rect.top + scrollY) / g.zoom,
    );
    final col = g.sheet.columns.indexAtOffset(
      _baseX + (p.dx - rect.left + scrollX) / g.zoom,
    );
    return (row, col);
  }
}

/// Pixel ⇄ index mapping of one frame (03 §2.3): zoom, device pixel ratio,
/// header sizes, frozen panes and scroll offsets.
class GridGeometry {
  GridGeometry({
    required this.sheet,
    required this.size,
    required this.zoom,
    required this.scrollX,
    required this.scrollY,
    this.devicePixelRatio = 1,
    this.showHeaders = true,
    this.rowGutter = 0,
    this.colGutter = 0,
  }) {
    final rows = sheet.rows;
    final cols = sheet.columns;
    final rec = sheet.record;
    frozenRows = math.min(rec?.frozenRows ?? 0, math.max(0, rows.length - 1));
    frozenCols = math.min(
      rec?.frozenColumns ?? 0,
      math.max(0, cols.length - 1),
    );
    final digits = math.max(1, '${rows.length}'.length);
    rowHeaderWidth = showHeaders
        ? snap(math.max(46, digits * 8 + 16) * zoom) + rowGutter
        : 0;
    colHeaderHeight = showHeaders ? snap(24 * zoom) + colGutter : 0;
    frozenWidth = snap(cols.offsetOf(frozenCols) * zoom);
    frozenHeight = snap(rows.offsetOf(frozenRows) * zoom);
    final cellsLeft = rowHeaderWidth;
    final cellsTop = colHeaderHeight;
    final mainLeft = cellsLeft + frozenWidth;
    final mainTop = cellsTop + frozenHeight;
    final lastRow = rows.length - 1;
    final lastCol = cols.length - 1;
    main = GridPane(
      kind: PaneKind.main,
      rect: Rect.fromLTRB(
        mainLeft,
        mainTop,
        math.max(mainLeft, size.width),
        math.max(mainTop, size.height),
      ),
      geometry: this,
      firstRow: frozenRows,
      firstCol: frozenCols,
      lastRowLimit: lastRow,
      lastColLimit: lastCol,
      scrollX: scrollX,
      scrollY: scrollY,
    );
    panes = [
      main,
      if (frozenRows > 0)
        GridPane(
          kind: PaneKind.top,
          rect: Rect.fromLTRB(mainLeft, cellsTop, size.width, mainTop),
          geometry: this,
          firstRow: 0,
          firstCol: frozenCols,
          lastRowLimit: frozenRows - 1,
          lastColLimit: lastCol,
          scrollX: scrollX,
          scrollY: 0,
        ),
      if (frozenCols > 0)
        GridPane(
          kind: PaneKind.left,
          rect: Rect.fromLTRB(cellsLeft, mainTop, mainLeft, size.height),
          geometry: this,
          firstRow: frozenRows,
          firstCol: 0,
          lastRowLimit: lastRow,
          lastColLimit: frozenCols - 1,
          scrollX: 0,
          scrollY: scrollY,
        ),
      if (frozenRows > 0 && frozenCols > 0)
        GridPane(
          kind: PaneKind.corner,
          rect: Rect.fromLTRB(cellsLeft, cellsTop, mainLeft, mainTop),
          geometry: this,
          firstRow: 0,
          firstCol: 0,
          lastRowLimit: frozenRows - 1,
          lastColLimit: frozenCols - 1,
          scrollX: 0,
          scrollY: 0,
        ),
    ];
  }

  final SheetModel sheet;
  final Size size;
  final double zoom;
  final double scrollX;
  final double scrollY;
  final double devicePixelRatio;
  final bool showHeaders;

  /// Outline gutter left of the row headers (07 §16.3); included in
  /// [rowHeaderWidth] (the row numbers start at this x).
  final double rowGutter;

  /// Outline gutter above the column headers; included in [colHeaderHeight].
  final double colGutter;

  late final int frozenRows;
  late final int frozenCols;
  late final double rowHeaderWidth;
  late final double colHeaderHeight;
  late final double frozenWidth;
  late final double frozenHeight;
  late final GridPane main;

  /// Main pane first, then top, left, corner.
  late final List<GridPane> panes;

  /// Width of a 1-px line in logical pixels at this DPR.
  double get hairline =>
      math.max(1, devicePixelRatio.floorToDouble()) / devicePixelRatio;

  /// Snaps a coordinate to the device pixel grid.
  double snap(double v) =>
      (v * devicePixelRatio).roundToDouble() / devicePixelRatio;

  /// The cell area (below and right of the headers).
  Rect get cellsRect =>
      Rect.fromLTRB(rowHeaderWidth, colHeaderHeight, size.width, size.height);

  /// Total scrollable extents (screen px).
  double get contentWidth =>
      (sheet.columns.totalSize - sheet.columns.offsetOf(frozenCols)) * zoom;
  double get contentHeight =>
      (sheet.rows.totalSize - sheet.rows.offsetOf(frozenRows)) * zoom;

  double get maxScrollX =>
      math.max(0, contentWidth - main.rect.width + 2 * zoom);
  double get maxScrollY => math.max(
    0,
    contentHeight - main.rect.height + 2 * zoom + addRowsFooterHeight,
  );

  /// Room for the "Add more rows" footer below the last row (03 §5).
  static const addRowsFooterHeight = 48.0;

  /// The pane that displays cell (row, col).
  GridPane paneFor(int row, int col) {
    for (final p in panes) {
      if (p.showsRow(row) && p.showsCol(col)) return p;
    }
    return main;
  }

  /// The pane containing screen point [p] (null over headers/outside).
  GridPane? paneAt(Offset p) {
    for (final pane in panes.reversed) {
      if (pane.rect.contains(p)) return pane;
    }
    return null;
  }

  /// Column at screen x (header strip / cells), clamped.
  int columnAtX(double x) {
    final xx = math.max(x, rowHeaderWidth);
    if (frozenCols > 0 && xx < rowHeaderWidth + frozenWidth) {
      return sheet.columns.indexAtOffset((xx - rowHeaderWidth) / zoom);
    }
    return sheet.columns.indexAtOffset(
      sheet.columns.offsetOf(frozenCols) +
          (xx - rowHeaderWidth - frozenWidth + scrollX) / zoom,
    );
  }

  /// Row at screen y, clamped.
  int rowAtY(double y) {
    final yy = math.max(y, colHeaderHeight);
    if (frozenRows > 0 && yy < colHeaderHeight + frozenHeight) {
      return sheet.rows.indexAtOffset((yy - colHeaderHeight) / zoom);
    }
    return sheet.rows.indexAtOffset(
      sheet.rows.offsetOf(frozenRows) +
          (yy - colHeaderHeight - frozenHeight + scrollY) / zoom,
    );
  }

  /// Left edge of column [col] on screen (in the pane that shows it).
  double colX(int col) =>
      (col < frozenCols && frozenCols > 0
              ? panes.firstWhere(
                  (p) => p.kind == PaneKind.left || p.kind == PaneKind.corner,
                  orElse: () => main,
                )
              : main)
          .x(col);

  /// Top edge of row [row] on screen.
  double rowY(int row) =>
      (row < frozenRows && frozenRows > 0
              ? panes.firstWhere(
                  (p) => p.kind == PaneKind.top || p.kind == PaneKind.corner,
                  orElse: () => main,
                )
              : main)
          .y(row);

  /// Screen rect of a cell in the pane that shows it.
  Rect cellRect(int row, int col) => paneFor(row, col).cellRect(row, col);

  /// Screen rect of [r] anchored in the pane of its top-left cell.
  Rect rangeRect(GridRect r) => paneFor(r.top, r.left).rangeRect(r);

  /// Visible rows in the main pane (inclusive).
  (int, int) get visibleRows => (main.rowStart, main.rowEnd);
  (int, int) get visibleCols => (main.colStart, main.colEnd);

  /// The scroll offsets that bring cell (row, col) fully into view (null
  /// when nothing needs to scroll). Frozen rows/columns never scroll.
  ({double x, double y})? scrollToReveal(
    int row,
    int col, {
    double margin = 0,
  }) {
    var x = scrollX;
    var y = scrollY;
    final cols = sheet.columns;
    final rows = sheet.rows;
    if (col >= frozenCols) {
      final left = (cols.offsetOf(col) - cols.offsetOf(frozenCols)) * zoom;
      final right = left + cols.sizeAt(col) * zoom;
      final w = main.rect.width;
      if (left - margin < x) {
        x = math.max(0, left - margin);
      } else if (right + margin > x + w) {
        x = math.min(right + margin - w, math.max(left - margin, 0));
      }
    }
    if (row >= frozenRows) {
      final top = (rows.offsetOf(row) - rows.offsetOf(frozenRows)) * zoom;
      final bottom = top + rows.sizeAt(row) * zoom;
      final h = main.rect.height;
      if (top - margin < y) {
        y = math.max(0, top - margin);
      } else if (bottom + margin > y + h) {
        y = math.min(bottom + margin - h, math.max(top - margin, 0));
      }
    }
    if (x == scrollX && y == scrollY) return null;
    return (x: x, y: y);
  }
}
