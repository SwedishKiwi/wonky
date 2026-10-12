import '../../addressing/grid_geometry.dart';
import '../values/format_hint.dart';
import '../values/fvalue.dart';

/// A computed cell value (05 §7.1).
final class ComputedValue {
  final FValue value;
  final FormatHint hint;
  final SpillInfo? spill;

  /// Shown with the previous value while recalculation is pending.
  final bool stale;

  const ComputedValue(this.value, {this.hint = FormatHint.none, this.spill, this.stale = false});

  static const ComputedValue empty = ComputedValue(FEmpty.instance);

  @override
  String toString() => 'ComputedValue(${value.debugText}${stale ? ', stale' : ''})';
}

/// Spill extent of an array formula host.
final class SpillInfo {
  final int rows;
  final int cols;
  final GridRect rect;
  const SpillInfo(this.rows, this.cols, this.rect);
}

/// A cell inside a spill area (05 §7.5).
final class OverlayCell {
  final String hostSheetId;
  final int hostRow;
  final int hostCol;
  final FValue value;
  const OverlayCell(this.hostSheetId, this.hostRow, this.hostCol, this.value);
}

/// One changed cell reported in a [RecalcBatch].
final class ChangedCell {
  final String sheetId;
  final int row;
  final int col;
  const ChangedCell(this.sheetId, this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is ChangedCell && other.sheetId == sheetId && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(sheetId, row, col);

  @override
  String toString() => 'ChangedCell($sheetId, ${CellPos(row, col).a1})';
}

/// Cells whose computed values changed during one drain slice.
final class RecalcBatch {
  final List<ChangedCell> cells;

  /// Spill rectangles that appeared, disappeared or changed (per sheet).
  final Map<String, List<GridRect>> spillRects;
  const RecalcBatch(this.cells, this.spillRects);

  bool get isEmpty => cells.isEmpty && spillRects.isEmpty;
}

/// Outcome of [FormulaEngine.drain].
final class RecalcBudgetResult {
  final int evaluated;
  final int remaining;
  const RecalcBudgetResult(this.evaluated, this.remaining);
  bool get done => remaining == 0;
}

/// Structural change of a sheet axis (05 §9.1).
enum AxisChangeKind { inserted, deleted, moved, resized }

final class AxisChange {
  final AxisChangeKind kind;

  /// First affected index (in the new order for inserts, the old order for deletes).
  final int index;
  final int count;

  /// Deleted or moved ids.
  final List<String> ids;

  const AxisChange.inserted(this.index, this.count) : kind = AxisChangeKind.inserted, ids = const [];
  const AxisChange.deleted(this.index, this.count, this.ids) : kind = AxisChangeKind.deleted;
  const AxisChange.moved(this.ids)
    : kind = AxisChangeKind.moved,
      index = 0,
      count = 0;
  const AxisChange.resized()
    : kind = AxisChangeKind.resized,
      index = 0,
      count = 0,
      ids = const [];
}

/// Visible area hint for prioritizing recalculation (05 §10.1).
final class Viewport {
  final String sheetId;
  final GridRect rect;
  const Viewport(this.sheetId, this.rect);
}

/// Cooperative cancellation for long operations.
final class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Engine tunables.
final class EngineConfig {
  /// LRU size of the template cache (05 §7.2).
  final int templateCapacity;

  /// Nested pull-evaluation depth before switching to the explicit work stack.
  final int maxNestedEvaluation;

  /// Evaluations between budget checks (05 §10.2).
  final int budgetCheckInterval;

  const EngineConfig({
    this.templateCapacity = 50000,
    this.maxNestedEvaluation = 48,
    this.budgetCheckInterval = 64,
  });
}

/// A formula cell found by dependency queries.
final class FormulaCellRef {
  final String sheetId;
  final int row;
  final int col;
  final String stored;
  const FormulaCellRef(this.sheetId, this.row, this.col, this.stored);

  @override
  String toString() => 'FormulaCellRef($sheetId!${CellPos(row, col).a1} =$stored)';
}

/// Precedents/dependents of a cell (05 §7.1 `dependencies`).
final class DependencyInfo {
  /// Areas the formula reads (current indices).
  final List<ResolvedArea> precedents;

  /// Formula cells reading the cell.
  final List<FormulaCellRef> dependents;
  const DependencyInfo(this.precedents, this.dependents);
}
