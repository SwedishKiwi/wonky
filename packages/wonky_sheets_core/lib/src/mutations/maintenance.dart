import 'dart:convert';

import 'package:wonky_sync_models/ids.dart';

import '../model/events.dart';
import '../model/grid_range.dart';
import '../model/schema.dart';
import '../model/workbook_model.dart';
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
      // Pivot anchors on deleted rows/columns move to the nearest survivor
      // (by sort key hint: first row at/after the deleted position).
      for (final p in s.pivots.values) {
        final w = <String, Object?>{};
        if (!s.rows.contains(p.anchorRowId) && s.rows.length > 0) {
          w['anchorRowId'] = s.rows.idAt(0);
        }
        if (!s.columns.contains(p.anchorColId) && s.columns.length > 0) {
          w['anchorColId'] = s.columns.idAt(0);
        }
        if (w.isNotEmpty) b.update(SheetsTables.pivotTable, p.id, w);
      }
      // Objects anchored on missing rows/columns.
      for (final o in s.objects.values) {
        Map<String, Object?> anchor;
        try {
          anchor = (jsonDecode(o.anchorJson) as Map).cast<String, Object?>();
        } on Object {
          continue;
        }
        if (anchor['ownSheet'] == true) continue;
        String? canon(Object? v) {
          if (v is! String) return null;
          if (!v.contains('-') && Base62Uuid.isValid(v)) {
            return Base62Uuid.decode(v);
          }
          return v;
        }

        final row = canon(anchor['rowId']);
        final col = canon(anchor['colId']);
        var changed = false;
        if (row != null && !s.rows.contains(row) && s.rows.length > 0) {
          anchor['rowId'] = Base62Uuid.encode(s.rows.idAt(0));
          changed = true;
        }
        if (col != null && !s.columns.contains(col) && s.columns.length > 0) {
          anchor['colId'] = Base62Uuid.encode(s.columns.idAt(0));
          changed = true;
        }
        if (changed) {
          anchor['dx'] = 0.0;
          anchor['dy'] = 0.0;
          b.update(SheetsTables.embeddedObject, o.id, {
            'anchorJson': jsonEncode(anchor),
          });
        }
      }
    }
    return b.build('Maintenance', kinds: [ChangeKinds.structure]);
  }

  /// Duplicate sheet names: the sheet with the larger id gets " (2)", " (3)"…
  static void _sheetNames(PlanBuilder b) {
    final byName = <String, List<String>>{};
    for (final s in b.model.sheets) {
      (byName[s.name.toLowerCase()] ??= []).add(s.id);
    }
    final taken = {for (final s in b.model.sheets) s.name.toLowerCase()};
    for (final e in byName.entries) {
      if (e.value.length < 2) continue;
      final ids = e.value..sort();
      for (final id in ids.skip(1)) {
        final base = b.model.sheet(id)!.name;
        var n = 2;
        var name = '$base ($n)';
        while (taken.contains(name.toLowerCase())) {
          n++;
          name = '$base ($n)';
        }
        taken.add(name.toLowerCase());
        b.update(SheetsTables.sheet, id, {Cols.name: name});
      }
    }
  }

  /// Duplicate named range names: larger id gets `_2`, `_3`… (07 §8.3).
  static void _namedRanges(PlanBuilder b) {
    final byName = <String, List<String>>{};
    for (final n in b.model.namedRanges) {
      (byName[n.name.toLowerCase()] ??= []).add(n.id);
    }
    final taken = {for (final n in b.model.namedRanges) n.name.toLowerCase()};
    for (final e in byName.entries) {
      if (e.value.length < 2) continue;
      final ids = e.value..sort();
      for (final id in ids.skip(1)) {
        final base =
            b.current(SheetsTables.namedRange, id)![Cols.name] as String;
        var n = 2;
        var name = '${base}_$n';
        while (taken.contains(name.toLowerCase())) {
          n++;
          name = '${base}_$n';
        }
        taken.add(name.toLowerCase());
        b.update(SheetsTables.namedRange, id, {Cols.name: name});
      }
    }
  }
}
