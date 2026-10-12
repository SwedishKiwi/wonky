import 'dart:convert';

import 'package:wonky_sync_models/ids.dart';

import '../../addressing/grid_geometry.dart';
import '../../engine_bridge/stored_formula.dart';
import '../../model/grid_range.dart';
import '../../model/records.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../plan_builder.dart';
import 'helpers.dart';
import 'move.dart';

/// Physical strategy of a row permutation (07 §2.2).
enum RowMoveStrategy { rowReorder, contentMove }

/// Chooses the strategy for permuting the rows of [rect]: row-entity reorder
/// when the rows have no cells outside the rect's columns and no merge spans
/// several rows; otherwise content move.
RowMoveStrategy chooseRowMoveStrategy(SheetModel s, GridRect rect) {
  for (var r = rect.top; r <= rect.bottom; r++) {
    for (final cell in s.cells.inRow(s.rows.idAt(r))) {
      final c = s.columns.indexOf(cell.columnId);
      if (c < rect.left || c > rect.right) return RowMoveStrategy.contentMove;
    }
  }
  for (final (_, m) in s.mergesIntersecting(
    GridRect(rect.top, 0, rect.bottom, s.columns.length - 1),
  )) {
    if (m.rowCount > 1) return RowMoveStrategy.contentMove;
  }
  return RowMoveStrategy.rowReorder;
}

/// Refuses permutations over vertical merges (07 §2.4).
void checkNoVerticalMerges(SheetModel s, GridRect rect) {
  for (final (_, m) in s.mergesIntersecting(rect)) {
    if (m.rowCount > 1) {
      throw const PlanException(
        'merge_conflict',
        "Can't sort a range with vertically merged cells",
      );
    }
  }
}

/// Applies a row permutation to the data rows [rect] of [s]: after the
/// operation, position `rect.top + i` holds the record that was at
/// `rect.top + permutation[i]`. Rows past [keepCount] (dedupe) are cleared
/// (contents of the range columns). Formulas in moved rows get copy
/// semantics (07 §2.5); references from outside keep pointing at positions.
RowMoveStrategy applyRowPermutation(
  PlanBuilder b,
  SheetModel s,
  GridRect rect,
  List<int> permutation, {
  int? keepCount,
  RowMoveStrategy? strategy,
}) {
  final n = rect.rowCount;
  assert(permutation.length == n, 'permutation length must match rows');
  final keep = keepCount ?? n;
  final st = strategy ?? (keep < n ? RowMoveStrategy.contentMove : chooseRowMoveStrategy(s, rect));
  var identity = true;
  for (var i = 0; i < n; i++) {
    if (permutation[i] != i) identity = false;
  }
  if (identity && keep == n) return st;
  final hooks = b.ctx.formulas;
  if (st == RowMoveStrategy.contentMove) {
    final snapshot = <int, Map<int, Map<String, Object?>>>{};
    for (final (r, c, _, _, cur) in b.cellsIn(s, rect)) {
      (snapshot[r - rect.top] ??= {})[c - rect.left] = cellData(cur);
    }
    for (var i = 0; i < n; i++) {
      final targetRow = rect.top + i;
      final rowId = s.rows.idAt(targetRow);
      final from = i < keep ? permutation[i] : -1;
      if (from == i) continue;
      final srcCells = from < 0
          ? const <int, Map<String, Object?>>{}
          : (snapshot[from] ?? const {});
      for (var c = rect.left; c <= rect.right; c++) {
        final colId = s.columns.idAt(c);
        final data = srcCells[c - rect.left];
        if (data == null) {
          b.deleteCell(s.id, rowId, colId);
          continue;
        }
        final out = Map<String, Object?>.of(data);
        final content = out[CellCols.content] as String?;
        if (content != null && content.startsWith('=') && hooks != null) {
          out[CellCols.content] = hooks.translate(
            content,
            fromSheetId: s.id,
            fromRow: rect.top + from,
            fromCol: c,
            toSheetId: s.id,
            toRow: targetRow,
            toCol: c,
          );
        }
        b.writeCell(s.id, rowId, colId, out);
      }
    }
    return st;
  }
  // Row reorder: permute the existing sort keys among the rows.
  final oldIds = [for (var i = 0; i < n; i++) s.rows.idAt(rect.top + i)];
  var keys = [for (var i = 0; i < n; i++) s.rows.sortKeyAt(rect.top + i)];
  if (keys.toSet().length != n) {
    // Ties: generate fresh distinct keys inside the block's bounds.
    final before = rect.top > 0 ? s.rows.sortKeyAt(rect.top - 1) : null;
    final after = rect.bottom + 1 < s.rows.length ? s.rows.sortKeyAt(rect.bottom + 1) : null;
    keys = FractionalIndex.nBetween(
      before == keys.first ? null : before,
      after == keys.last ? null : after,
      n,
    );
  }
  final newIdAt = [for (var i = 0; i < n; i++) oldIds[permutation[i]]];
  for (var i = 0; i < n; i++) {
    b.update(SheetsTables.sheetRow, newIdAt[i], {Cols.sortKey: keys[i]});
  }
  final oldIndex = {for (var i = 0; i < n; i++) oldIds[i]: rect.top + i};
  String newRowIdAt(int pos) =>
      pos >= rect.top && pos <= rect.bottom ? newIdAt[pos - rect.top] : s.rows.idAt(pos);
  int oldIndexOf(String id) => oldIndex[id] ?? s.rows.indexOf(id);
  final newPos = {for (var i = 0; i < n; i++) newIdAt[i]: rect.top + i};

  // Formulas: inside moved rows → translate (copy semantics) then re-pin;
  // elsewhere → re-pin references into the block.
  if (hooks != null) {
    for (final sheet in b.model.sheets) {
      for (final cell in sheet.cells.all) {
        final content = cell.content;
        if (content == null || !content.startsWith('=')) continue;
        var f = content;
        final moved = sheet.id == s.id ? newPos[cell.rowId] : null;
        if (moved != null) {
          final from = oldIndex[cell.rowId]!;
          final c = s.columns.indexOf(cell.columnId);
          if (from != moved) {
            f = hooks.translate(
              f,
              fromSheetId: s.id,
              fromRow: from,
              fromCol: c,
              toSheetId: s.id,
              toRow: moved,
              toCol: c,
            );
          }
        } else if (!StoredFormula.mayReference(f, oldIds)) {
          continue;
        }
        final repinned = hooks.repinRows(
          f,
          hostSheetId: sheet.id,
          sheetId: s.id,
          blockTop: rect.top,
          blockBottom: rect.bottom,
          newRowIdAt: newRowIdAt,
          oldIndexOf: oldIndexOf,
        );
        if (repinned != null) f = repinned;
        if (f != content) b.update(SheetsTables.cell, cell.id, {CellCols.content: f});
      }
    }
  }
  // Id ranges with endpoints inside the block keep covering positions.
  GridRange? repin(GridRange g) {
    if (g.sheetId != s.id) return null;
    String? map(String? id) {
      if (id == null) return null;
      final p = oldIndex[id];
      if (p == null) return id;
      return newRowIdAt(p);
    }

    final r1 = map(g.r1);
    final r2 = map(g.r2);
    if (r1 == g.r1 && r2 == g.r2) return null;
    return g.copyWith(
      r1: r1,
      r2: r2,
      r1k: r1 == null ? null : _keyOf(s, r1, newIdAt, keys, rect),
      r2k: r2 == null ? null : _keyOf(s, r2, newIdAt, keys, rect),
    );
  }

  _repinRuleRanges(b, s, repin);
  return st;
}

String? _keyOf(SheetModel s, String rowId, List<String> newIdAt, List<String> keys, GridRect rect) {
  final i = newIdAt.indexOf(rowId);
  if (i >= 0) return keys[i];
  return s.rows.sortKeyOf(rowId);
}

void _repinRuleRanges(PlanBuilder b, SheetModel s, GridRange? Function(GridRange) repin) {
  void single(String table, Iterable<SyncRecord> recs, String column) {
    for (final r in recs) {
      final g = GridRange.tryParse(r.column(column) as String?);
      if (g == null) continue;
      final n = repin(g);
      if (n != null) b.update(table, r.id, {column: n.encode()});
    }
  }

  void multi(String table, Iterable<SyncRecord> recs) {
    for (final r in recs) {
      final list = GridRange.parseList(r.column(Cols.rangesJson) as String?);
      var changed = false;
      final out = [
        for (final g in list)
          if (repin(g) case final GridRange n)
            () {
              changed = true;
              return n;
            }()
          else
            g,
      ];
      if (changed) b.update(table, r.id, {Cols.rangesJson: GridRange.encodeList(out)});
    }
  }

  single(SheetsTables.mergedRange, s.merges.values, Cols.rangeJson);
  single(SheetsTables.banding, s.bandings.values, Cols.rangeJson);
  single(SheetsTables.filterView, s.filterViews.values, Cols.rangeJson);
  if (s.basicFilter != null) single(SheetsTables.basicFilter, [s.basicFilter!], Cols.rangeJson);
  single(SheetsTables.protectedRange, s.protections.values, Cols.rangeJson);
  multi(SheetsTables.conditionalFormatRule, s.cfRules.values);
  multi(SheetsTables.dataValidationRule, s.dvRules.values);
  single(SheetsTables.namedRange, b.model.namedRanges, Cols.rangeJson);
  for (final other in b.model.sheets) {
    single(SheetsTables.pivotTable, other.pivots.values, 'sourceRangeJson');
    for (final o in other.objects.values) {
      final spec = PlanBuilderHelpers.decodeMap(o.specJson);
      var changed = false;
      Object? walk(Object? v) {
        if (v is Map) {
          if (v['s'] is String && (v.containsKey('r1') || v.containsKey('c1'))) {
            final g = GridRange.tryParse(v);
            final n = g == null ? null : repin(g);
            if (n != null) {
              changed = true;
              return n.toJson();
            }
            return v;
          }
          return {for (final e in v.entries) e.key: walk(e.value)};
        }
        if (v is List) return [for (final e in v) walk(e)];
        return v;
      }

      final out = walk(spec);
      if (changed) b.update(SheetsTables.embeddedObject, o.id, {'specJson': jsonEncode(out)});
    }
  }
  // Groups: endpoints at positions.
  for (final g in s.groups.values) {
    if (g.dimension != Dimension.rows) continue;
    final n = repin(GridRange(sheetId: s.id, r1: g.startId, r2: g.endId));
    if (n != null) b.update(SheetsTables.dimensionGroup, g.id, {'startId': n.r1, 'endId': n.r2});
  }
}
