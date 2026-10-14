import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../model/sheet_model.dart';
import '../protection/protection_guard.dart';
import 'sort_keys.dart';

/// "Looks like a header" (07 §2.6): every non-empty cell of the first row is
/// text, and at least one column below has a different dominant type.
abstract final class HeaderDetector {
  /// Checks the first row of [rect] using [value] (computed values). At most
  /// [sampleRows] data rows are inspected.
  static bool looksLikeHeader(
    CellValue Function(int row, int col) value,
    GridRect rect, {
    int sampleRows = 500,
  }) {
    if (rect.rowCount < 2) return false;
    var anyHeader = false;
    for (var c = rect.left; c <= rect.right; c++) {
      final v = value(rect.top, c);
      if (v.isBlank()) continue;
      if (v is! TextValue) return false;
      anyHeader = true;
    }
    if (!anyHeader) return false;
    final last = rect.top + sampleRows < rect.bottom
        ? rect.top + sampleRows
        : rect.bottom;
    for (var c = rect.left; c <= rect.right; c++) {
      final counts = List<int>.filled(4, 0);
      for (var r = rect.top + 1; r <= last; r++) {
        final g = SortKeys.groupOf(value(r, c));
        if (g < 4) counts[g]++;
      }
      var best = -1;
      var bestCount = 0;
      for (var g = 0; g < 4; g++) {
        if (counts[g] > bestCount) {
          best = g;
          bestCount = counts[g];
        }
      }
      if (best >= 0 && best != SortKeys.text) return true;
    }
    return false;
  }
}

/// Physical sort strategies (07 §2.2).
enum SortStrategyKind {
  /// Permute `SheetRow.sortKey`s (full-row sorts).
  rowReorder,

  /// Move cell contents (partial-range sorts).
  contentMove,
}

/// Why a sort / randomize / dedupe is refused (07 §2.4).
enum SortRefusalKind { verticalMerge, overlay, protected }

/// A refusal with its dialog message.
final class SortRefusal {
  /// Creates a refusal.
  const SortRefusal(this.kind, this.message, {this.guard});

  final SortRefusalKind kind;
  final String message;

  /// The guard result for protection refusals.
  final GuardResult? guard;

  static const String verticalMergeMessage =
      "Can't sort a range with vertically merged cells";
  static const String overlayMessage =
      "You can't sort a range that contains part of an array result or pivot table";

  @override
  String toString() => 'SortRefusal(${kind.name}: $message)';
}

/// Strategy choice and refusal checks shared by sort, randomize and remove duplicates.
abstract final class SortStrategy {
  /// Whether any merge with more than one row intersects [rect].
  static bool hasVerticalMerge(SheetModel sheet, GridRect rect) =>
      sheet.mergesIntersecting(rect).any((m) => m.$2.rowCount > 1);

  /// [SortStrategyKind.rowReorder] when the rows of [rect] have no cells
  /// outside its columns and no merge spanning several rows touches them (in
  /// any column); else contentMove. Single-row merges move with their row.
  static SortStrategyKind choose(SheetModel sheet, GridRect rect) {
    final grid = sheet.gridRect;
    if (grid == null) return SortStrategyKind.rowReorder;
    final rows = GridRect(rect.top, grid.left, rect.bottom, grid.right);
    if (hasVerticalMerge(sheet, rows)) return SortStrategyKind.contentMove;
    if (rect.left <= grid.left && rect.right >= grid.right) {
      return SortStrategyKind.rowReorder;
    }
    for (var r = rect.top; r <= rect.bottom; r++) {
      final rowId = sheet.rows.tryIdAt(r);
      if (rowId == null || sheet.cells.rowCount(rowId) == 0) continue;
      for (final cell in sheet.cells.inRow(rowId)) {
        final c = sheet.columns.indexOf(cell.columnId);
        if (c >= 0 && (c < rect.left || c > rect.right)) {
          return SortStrategyKind.contentMove;
        }
      }
    }
    return SortStrategyKind.rowReorder;
  }

  /// The first refusal for sorting [rect], or null: vertical merges, overlay
  /// output ([hasOverlay], e.g. spills/pivots from the engine's OverlayIndex),
  /// protected cells (when [guard] is given).
  static SortRefusal? refusal(
    SheetModel sheet,
    GridRect rect, {
    bool Function(GridRect rect)? hasOverlay,
    ProtectionGuard? guard,
    String? userId,
    bool isOwner = false,
  }) {
    if (hasVerticalMerge(sheet, rect)) {
      return const SortRefusal(
        SortRefusalKind.verticalMerge,
        SortRefusal.verticalMergeMessage,
      );
    }
    if (hasOverlay?.call(rect) ?? false) {
      return const SortRefusal(
        SortRefusalKind.overlay,
        SortRefusal.overlayMessage,
      );
    }
    if (guard != null && userId != null) {
      final g = guard.check(
        CellWrites(sheet.id, [rect]),
        userId,
        isOwner: isOwner,
      );
      if (g.isBlocked) {
        return SortRefusal(
          SortRefusalKind.protected,
          GuardResult.blockedMessage,
          guard: g,
        );
      }
    }
    return null;
  }
}
