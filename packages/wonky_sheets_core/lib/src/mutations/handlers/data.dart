import 'dart:math';

import '../../addressing/grid_geometry.dart';
import '../../model/grid_range.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'helpers.dart';
import 'move.dart';
import 'row_move.dart';

export 'paste.dart' show planPaste;

/// [ShiftCells] (03 §13.3): insert cells shifting right/down or delete cells
/// shifting left/up, implemented as a block move of the affected strip.
MutationPlan planShiftCells(PlanBuilder b, ShiftCells op) {
  final s = b.sheetOf(op.range.sheetId);
  final r = op.range.rect;
  b.checkRect(s, r);
  final used = s.usedRect(includeFormatOnly: true);
  final lastCol = used == null
      ? r.right
      : (used.right > r.right ? used.right : r.right);
  final lastRow = used == null
      ? r.bottom
      : (used.bottom > r.bottom ? used.bottom : r.bottom);
  // Merges crossing the strip boundary are refused.
  GridRect strip;
  switch (op.direction) {
    case ShiftDirection.right:
    case ShiftDirection.left:
      strip = GridRect(r.top, r.left, r.bottom, lastCol);
    case ShiftDirection.down:
    case ShiftDirection.up:
      strip = GridRect(r.top, r.left, lastRow, r.right);
  }
  for (final (_, m) in s.mergesIntersecting(strip)) {
    if (!strip.containsRect(m)) {
      throw const PlanException(
        'merge_conflict',
        "You can't shift cells that would break apart a merged cell",
      );
    }
  }
  switch (op.direction) {
    case ShiftDirection.right:
      final width = r.colCount;
      if (strip.right >= r.left) {
        applyMoveRange(
          b,
          MoveRange(ResolvedRange(s.id, strip), s.id, r.top, r.left + width),
        );
      }
    case ShiftDirection.down:
      final height = r.rowCount;
      applyMoveRange(
        b,
        MoveRange(ResolvedRange(s.id, strip), s.id, r.top + height, r.left),
      );
    case ShiftDirection.left:
      for (final (_, _, rowId, colId, _) in b.cellsIn(s, r).toList()) {
        b.deleteCell(s.id, rowId, colId);
      }
      if (lastCol > r.right) {
        applyMoveRange(
          b,
          MoveRange(
            ResolvedRange(
              s.id,
              GridRect(r.top, r.right + 1, r.bottom, lastCol),
            ),
            s.id,
            r.top,
            r.left,
          ),
        );
      }
    case ShiftDirection.up:
      for (final (_, _, rowId, colId, _) in b.cellsIn(s, r).toList()) {
        b.deleteCell(s.id, rowId, colId);
      }
      if (lastRow > r.bottom) {
        applyMoveRange(
          b,
          MoveRange(
            ResolvedRange(
              s.id,
              GridRect(r.bottom + 1, r.left, lastRow, r.right),
            ),
            s.id,
            r.top,
            r.left,
          ),
        );
      }
  }
  final label = switch (op.direction) {
    ShiftDirection.right => 'Insert cells and shift right',
    ShiftDirection.down => 'Insert cells and shift down',
    ShiftDirection.left => 'Delete cells and shift left',
    ShiftDirection.up => 'Delete cells and shift up',
  };
  return b.build(label, kinds: [ChangeKinds.values, ChangeKinds.format]);
}

/// [RandomizeRange] (07 §14): Fisher–Yates over the rows, sort machinery.
MutationPlan planRandomizeRange(PlanBuilder b, RandomizeRange op) {
  final s = b.sheetOf(op.range.sheetId);
  final rect = op.range.rect;
  b.checkRect(s, rect);
  if (rect.rowCount < 2) return b.build('Randomize range');
  checkNoVerticalMerges(s, rect);
  final random = b.ctx.random ?? Random.secure();
  final perm = List<int>.generate(rect.rowCount, (i) => i);
  for (var i = perm.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final t = perm[i];
    perm[i] = perm[j];
    perm[j] = t;
  }
  applyRowPermutation(b, s, rect, perm);
  b.addResolvedRange(op.range);
  return b.build('Randomize range', kinds: [ChangeKinds.values]);
}

Never _pending(String what) =>
    throw PlanException('unsupported', '$what is not available yet');

/// [SortRange].
MutationPlan planSortRange(PlanBuilder b, SortRange op) => _pending('Sort');

/// [RemoveDuplicates].
MutationPlan planRemoveDuplicates(PlanBuilder b, RemoveDuplicates op) =>
    _pending('Remove duplicates');

/// [TrimWhitespace].
MutationPlan planTrimWhitespace(PlanBuilder b, TrimWhitespace op) =>
    _pending('Trim whitespace');

/// [SplitTextToColumns].
MutationPlan planSplitTextToColumns(PlanBuilder b, SplitTextToColumns op) =>
    _pending('Split text');

/// [FindReplace].
MutationPlan planFindReplace(PlanBuilder b, FindReplace op) =>
    _pending('Find and replace');

/// [FillSeries].
MutationPlan planFillSeries(PlanBuilder b, FillSeries op) => _pending('Fill');

/// [AdjustDecimals].
MutationPlan planAdjustDecimals(PlanBuilder b, AdjustDecimals op) =>
    _pending('Decimals');

/// [GroupOperation].
MutationPlan planGroupOperation(PlanBuilder b, GroupOperation op) =>
    _pending('Groups');
