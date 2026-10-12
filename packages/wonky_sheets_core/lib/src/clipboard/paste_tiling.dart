import '../addressing/grid_geometry.dart';

/// Paste target computation (03 §12.3): the source is tiled when the
/// selection is an exact multiple of the source size, otherwise the source
/// size is used from the selection's top-left.
abstract final class PasteTiling {
  /// The rectangle written by pasting a [sourceRows] × [sourceCols] block
  /// into [selection].
  static GridRect target(int sourceRows, int sourceCols, GridRect selection) {
    if (sourceRows <= 0 || sourceCols <= 0) {
      return GridRect.cell(selection.top, selection.left);
    }
    if (tiles(sourceRows, sourceCols, selection) != null) return selection;
    return GridRect(
      selection.top,
      selection.left,
      selection.top + sourceRows - 1,
      selection.left + sourceCols - 1,
    );
  }

  /// `(down, across)` repetitions when [selection] is an exact multiple of
  /// the source size (including 1 × 1), else null.
  static (int down, int across)? tiles(int sourceRows, int sourceCols, GridRect selection) {
    if (sourceRows <= 0 || sourceCols <= 0) return null;
    final rows = selection.rowCount;
    final cols = selection.colCount;
    if (rows < sourceRows || cols < sourceCols) return null;
    if (rows % sourceRows != 0 || cols % sourceCols != 0) return null;
    return (rows ~/ sourceRows, cols ~/ sourceCols);
  }

  /// The source cell (relative row, column) that lands on the target cell at
  /// ([row], [col]) of a paste anchored at ([top], [left]).
  static (int, int) sourceCellFor(
    int row,
    int col, {
    required int top,
    required int left,
    required int sourceRows,
    required int sourceCols,
  }) => ((row - top) % sourceRows, (col - left) % sourceCols);
}
