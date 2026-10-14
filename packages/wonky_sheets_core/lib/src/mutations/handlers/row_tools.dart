import 'dart:math';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../data_tools/cleanup/dedupe.dart';
import '../../data_tools/random/row_shuffle.dart';
import '../../data_tools/sort/sort_permutation.dart';
import '../../data_tools/sort/sort_spec.dart';
import '../../engine_bridge/model_cell_source.dart';
import '../../engine_bridge/value_bridge.dart';
import '../../format/attributes.dart';
import '../../formula/model/workbook_view.dart' show CellSource;
import '../../model/sheet_model.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'helpers.dart';
import 'row_move.dart';

/// Computed values for data tools: the context's source, else literal values
/// of the model (formulas read as empty).
CellSource planValues(PlanBuilder b) =>
    b.ctx.values ?? ModelCellSource(b.model);

/// Reads the computed value at a cell of [sheetId].
CellValue Function(int row, int col) valueReader(
  PlanBuilder b,
  String sheetId,
) {
  final values = planValues(b);
  return (row, col) => values.valueAt(sheetId, row, col).toCellValue();
}

/// The data rows of [rect] (the first row excluded when [hasHeader]).
GridRect? dataRows(GridRect rect, {required bool hasHeader}) {
  final top = hasHeader ? rect.top + 1 : rect.top;
  if (top > rect.bottom) return null;
  return GridRect(top, rect.left, rect.bottom, rect.right);
}

/// Index of [colId] in [s] inside [rect], or an `invalid_argument` error.
int columnInRange(SheetModel s, GridRect rect, String colId) {
  final c = s.columns.indexOf(colId);
  if (c < rect.left || c > rect.right) {
    throw PlanException(
      'invalid_argument',
      'The column is not part of the range',
      details: {'colId': colId},
    );
  }
  return c;
}

/// [SortRange] (07 §2): a stable multi-key sort of the data rows (Google
/// ordering, blanks last, computed values), applied with the shared row-move
/// machinery (strategy per §2.2, copy semantics for formulas §2.5).
///
/// Result: `strategy` (`rowReorder` / `contentMove`) and `movedRows`.
MutationPlan planSortRange(PlanBuilder b, SortRange op) =>
    drainPlanSteps(planSortRangeSteps(b, op));

/// [planSortRange] as cooperative steps (progress 0–1, 07 §1.4); the last
/// element is the plan.
Iterable<Object> planSortRangeSteps(PlanBuilder b, SortRange op) sync* {
  final label = op.label ?? 'Sort range';
  final s = b.sheetOf(op.range.sheetId);
  final rect = op.range.rect;
  b.checkRect(s, rect);
  if (op.specs.isEmpty) {
    throw const PlanException('invalid_argument', 'Choose a column to sort by');
  }
  if (op.specs.length > rect.colCount) {
    throw const PlanException(
      'invalid_argument',
      'There are more sort columns than columns in the range',
    );
  }
  final specs = <SortSpec>[
    for (final k in op.specs)
      if (k.fillColor != null || k.textColor != null)
        ColorSortSpec(k.colId, fillColor: k.fillColor, textColor: k.textColor)
      else
        ValueSortSpec(k.colId, ascending: k.ascending),
  ];
  for (final k in specs) {
    columnInRange(s, rect, k.colId);
  }
  final data = dataRows(rect, hasHeader: op.hasHeader);
  b.addResolvedRange(op.range);
  if (data == null || data.rowCount < 2) {
    b.result['movedRows'] = 0;
    yield b.build(label);
    return;
  }
  checkRowMoveAllowed(b, s, data);
  final table = SortTable.fromSheet(
    s,
    planValues(b),
    data,
    specs,
    colors: (row, col) {
      final f = b.model.explicitFormatChain(s.id, row, col);
      return (
        fill: f[FormatAttr.fillColor] as String?,
        text: f[FormatAttr.textColor] as String?,
      );
    },
  );
  yield 0.1;
  final perm = SortPermutation.compute(table, specs);
  yield 0.15;
  final out = RowMoveOutcome();
  for (final p in applyRowPermutationSteps(b, s, data, perm, out)) {
    yield 0.15 + 0.85 * p;
  }
  b.result['strategy'] = out.strategy!.name;
  b.result['movedRows'] = _moved(perm);
  yield b.build(label, kinds: [ChangeKinds.values]);
}

/// [RandomizeRange] (07 §14): Fisher–Yates over the rows (the context's
/// [PlanContext.random], else `Random.secure()`), sort machinery.
///
/// Result: `strategy` and `movedRows`.
MutationPlan planRandomizeRange(PlanBuilder b, RandomizeRange op) =>
    drainPlanSteps(planRandomizeRangeSteps(b, op));

/// [planRandomizeRange] as cooperative steps (see [planSortRangeSteps]).
Iterable<Object> planRandomizeRangeSteps(
  PlanBuilder b,
  RandomizeRange op,
) sync* {
  const label = 'Randomize range';
  final s = b.sheetOf(op.range.sheetId);
  final rect = op.range.rect;
  b.checkRect(s, rect);
  b.addResolvedRange(op.range);
  if (rect.rowCount < 2) {
    b.result['movedRows'] = 0;
    yield b.build(label);
    return;
  }
  checkRowMoveAllowed(b, s, rect);
  final perm = RowShuffle.permutation(
    rect.rowCount,
    b.ctx.random ?? Random.secure(),
  );
  final out = RowMoveOutcome();
  for (final p in applyRowPermutationSteps(b, s, rect, perm, out)) {
    yield p;
  }
  b.result['strategy'] = out.strategy!.name;
  b.result['movedRows'] = _moved(perm);
  yield b.build(label, kinds: [ChangeKinds.values]);
}

/// [RemoveDuplicates] (07 §12.1): keeps the first occurrence of each row
/// (compared columns: [RemoveDuplicates.colIds] or all), compacts the kept
/// rows upward within the range and clears the vacated rows at the bottom.
///
/// Result: `duplicatesRemoved`, `uniqueRemaining` and the dialog `message`.
MutationPlan planRemoveDuplicates(PlanBuilder b, RemoveDuplicates op) =>
    drainPlanSteps(planRemoveDuplicatesSteps(b, op));

/// [planRemoveDuplicates] as cooperative steps (see [planSortRangeSteps]).
Iterable<Object> planRemoveDuplicatesSteps(
  PlanBuilder b,
  RemoveDuplicates op,
) sync* {
  const label = 'Remove duplicates';
  final s = b.sheetOf(op.range.sheetId);
  final rect = op.range.rect;
  b.checkRect(s, rect);
  final cols = [
    for (final id in op.colIds ?? const <String>[]) columnInRange(s, rect, id),
  ];
  if (op.colIds != null && cols.isEmpty) {
    throw const PlanException(
      'invalid_argument',
      'Select at least one column to compare',
    );
  }
  b.addResolvedRange(op.range);
  final data = dataRows(rect, hasHeader: op.hasHeader);
  if (data == null) {
    b.result['duplicatesRemoved'] = 0;
    b.result['uniqueRemaining'] = 0;
    b.result['message'] = DedupeResult.noDuplicatesMessage;
    yield b.build(label);
    return;
  }
  final result = Dedupe.findDuplicates(valueReader(b, s.id), data, cols: cols);
  b.result['duplicatesRemoved'] = result.duplicateCount;
  b.result['uniqueRemaining'] = result.uniqueCount;
  b.result['message'] = result.message;
  if (result.duplicateCount == 0) {
    yield b.build(label);
    return;
  }
  yield 0.05;
  checkRowMoveAllowed(b, s, data);
  final perm = Dedupe.compactPermutation(result, data.top);
  final out = RowMoveOutcome();
  for (final p in applyRowPermutationSteps(
    b,
    s,
    data,
    perm,
    out,
    keepCount: result.uniqueCount,
  )) {
    yield 0.05 + 0.95 * p;
  }
  yield b.build(label, kinds: [ChangeKinds.values]);
}

/// Runs plan steps to the end and returns the plan (their last element).
MutationPlan drainPlanSteps(Iterable<Object> steps) {
  Object? last;
  for (final x in steps) {
    last = x;
  }
  return last! as MutationPlan;
}

int _moved(List<int> perm) {
  var n = 0;
  for (var i = 0; i < perm.length; i++) {
    if (perm[i] != i) n++;
  }
  return n;
}
