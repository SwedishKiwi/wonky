import '../data_tools/groups/group_layout.dart';
import '../data_tools/names/name_rules.dart';
import '../model/events.dart';
import '../model/grid_range.dart';
import '../model/schema.dart';
import '../model/sheet_model.dart';
import '../model/workbook_model.dart';
import '../objects/maintenance.dart';
import 'plan_builder.dart';
import 'row_change.dart';

/// Deterministic, idempotent invariant repairs run after merges by the first
/// client that notices (02 §8, 08 A-08-4, 07 §8.3). Concurrent fixers write
/// identical values, so the fixes converge.
abstract final class WorkbookMaintenance {
  /// Plans the repairs needed by [model] (empty plan when consistent).
  static MutationPlan plan(WorkbookModel model, PlanContext ctx) {
    final b = PlanBuilder(model, ctx);
    _sheetNames(b);
    _namedRanges(b);
    for (final s in model.sheets) {
      final rec = s.record!;
      // Frozen counts beyond the grid.
      final maxRows = s.rows.length > 0 ? s.rows.length - 1 : 0;
      final maxCols = s.columns.length > 0 ? s.columns.length - 1 : 0;
      final writes = <String, Object?>{
        if (rec.frozenRows > maxRows) SheetCols.frozenRows: maxRows,
        if (rec.frozenColumns > maxCols) SheetCols.frozenColumns: maxCols,
      };
      if (writes.isNotEmpty) b.update(SheetsTables.sheet, s.id, writes);
      // Overlapping merges: keep the smaller id.
      final ids = s.merges.keys.toList()..sort();
      final kept = <String>[];
      for (final id in ids) {
        final rects = s.ruleRects(RuleKind.merge, id);
        if (rects.isEmpty) {
          b.delete(SheetsTables.mergedRange, id);
          continue;
        }
        final overlaps = kept.any(
          (k) => s
              .ruleRects(RuleKind.merge, k)
              .any((r) => r.intersects(rects.first)),
        );
        if (overlaps) {
          b.delete(SheetsTables.mergedRange, id);
        } else {
          kept.add(id);
        }
      }
      // Basic filter whose range no longer resolves.
      final bf = s.basicFilter;
      if (bf != null) {
        final g = GridRange.tryParse(bf.rangeJson);
        if (g == null || s.resolve(g) == null) {
          b.delete(SheetsTables.basicFilter, bf.id);
        }
      }
      // Pivot anchors on deleted rows/columns move to the nearest surviving
      // row/column (02 §8): the next one by the deleted entry's last known
      // sort key, else the previous one; the first one only when the
      // deleted entry was never seen by this client.
      for (final p in s.pivots.values) {
        final w = <String, Object?>{};
        final row = _survivor(s, Dimension.rows, p.anchorRowId);
        if (row != null) w['anchorRowId'] = row;
        final col = _survivor(s, Dimension.columns, p.anchorColId);
        if (col != null) w['anchorColId'] = col;
        if (w.isNotEmpty) b.update(SheetsTables.pivotTable, p.id, w);
      }
      // Objects anchored on deleted rows/columns (08 §1.2).
      for (final e in AnchorMaintenance.plan(s).entries) {
        b.update(SheetsTables.embeddedObject, e.key, {
          'anchorJson': e.value.encode(),
        });
      }
      // Group depth normalization (07 §16.3).
      for (final d in Dimension.values) {
        final changes = GroupLayout(
          s.id,
          d,
          s.axis(d),
          s.groups.values,
        ).normalize();
        for (final id in changes.deletes) {
          b.delete(SheetsTables.dimensionGroup, id);
        }
        for (final u in changes.updates.entries) {
          b.update(SheetsTables.dimensionGroup, u.key, u.value);
        }
      }
    }
    return b.build('Maintenance', kinds: [ChangeKinds.structure]);
  }

  /// The id of the nearest surviving row/column replacing the missing [id]
  /// of [d], or null when [id] exists (or the axis is empty).
  static String? _survivor(SheetModel s, Dimension d, String id) {
    final axis = s.axis(d);
    if (axis.length == 0 || axis.contains(id)) return null;
    final key = s.removedSortKey(d, id);
    if (key == null) return axis.idAt(0);
    final i = axis.insertionIndex(key, id);
    return axis.idAt(i < axis.length ? i : axis.length - 1);
  }

  /// Duplicate sheet names: the sheet with the larger id gets " (2)", " (3)"…
  /// ([NameRules.sheetRenames]).
  static void _sheetNames(PlanBuilder b) {
    final renames = NameRules.sheetRenames([
      for (final s in b.model.sheets) (s.id, s.name),
    ]);
    for (final e in renames.entries) {
      b.update(SheetsTables.sheet, e.key, {Cols.name: e.value});
    }
  }

  /// Duplicate named range names: larger id gets `_2`, `_3`… (07 §8.3,
  /// [NameRules.dedupeRenames]).
  static void _namedRanges(PlanBuilder b) {
    final renames = NameRules.dedupeRenames([
      for (final n in b.model.namedRanges) (n.id, n.name),
    ]);
    for (final e in renames.entries) {
      b.update(SheetsTables.namedRange, e.key, {Cols.name: e.value});
    }
  }
}
