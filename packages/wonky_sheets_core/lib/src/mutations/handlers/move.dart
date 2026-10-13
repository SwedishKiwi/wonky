import 'dart:convert';

import '../../addressing/grid_geometry.dart';
import '../../engine_bridge/stored_formula.dart';
import '../../model/events.dart';
import '../../model/grid_range.dart';
import '../../model/records.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'helpers.dart';

const Set<String> _cellDataColumns = {
  CellCols.content,
  CellCols.note,
  CellCols.numberFormat,
  CellCols.fontFamily,
  CellCols.fontSize,
  CellCols.bold,
  CellCols.italic,
  CellCols.underline,
  CellCols.strikethrough,
  CellCols.textColor,
  CellCols.fillColor,
  CellCols.hAlign,
  CellCols.vAlign,
  CellCols.wrap,
  CellCols.rotation,
  CellCols.borderTop,
  CellCols.borderRight,
  CellCols.borderBottom,
  CellCols.borderLeft,
  CellCols.linkUrl,
};

/// The data columns of a cell (content, note, formats) with nulls for unset.
Map<String, Object?> cellData(Map<String, Object?>? cell) => {
  for (final k in _cellDataColumns) k: cell?[k],
};

/// Ensures [s] has at least [rows] × [cols]; returns `(rowIdAt, colIdAt)`.
(String Function(int), String Function(int)) ensureGridSize(
  PlanBuilder b,
  SheetModel s,
  int rows,
  int cols,
) {
  final needRows = rows - s.rows.length;
  final needCols = cols - s.columns.length;
  final extraRows = <String>[];
  final extraCols = <String>[];
  if (needRows > 0 || needCols > 0) {
    b.checkCellLimit(
      b.gridCellsWith(
        s.id,
        rows > s.rows.length ? rows : s.rows.length,
        cols > s.columns.length ? cols : s.columns.length,
      ),
    );
    extraRows.addAll(b.appendDimension(s, Dimension.rows, needRows));
    extraCols.addAll(b.appendDimension(s, Dimension.columns, needCols));
  }
  return (
    (i) => i < s.rows.length ? s.rows.idAt(i) : extraRows[i - s.rows.length],
    (i) => i < s.columns.length
        ? s.columns.idAt(i)
        : extraCols[i - s.columns.length],
  );
}

/// Refuses writes that would break apart merges in [dest] of [s], ignoring
/// merges in [ignore].
void checkMergesNotSplit(
  SheetModel s,
  GridRect dest, {
  Set<String> ignore = const {},
}) {
  for (final (id, m) in s.mergesIntersecting(dest)) {
    if (ignore.contains(id)) continue;
    if (!dest.containsRect(m)) {
      throw const PlanException(
        'merge_conflict',
        "You can't paste here because it would break apart a merged cell",
      );
    }
  }
}

/// [MoveRange]: move (cut/paste, drag) or copy a block (03 §11, §12.6).
MutationPlan planMoveRange(PlanBuilder b, MoveRange op) {
  applyMoveRange(b, op);
  return b.build(
    op.copy ? 'Copy' : 'Move',
    kinds: [ChangeKinds.values, ChangeKinds.format],
  );
}

/// Adds the writes of [op] to [b].
void applyMoveRange(PlanBuilder b, MoveRange op) {
  final src = b.sheetOf(op.source.sheetId);
  final dst = b.sheetOf(op.destSheetId);
  final s = op.source.rect;
  b.checkRect(src, s);
  final d = GridRect(
    op.destRow,
    op.destCol,
    op.destRow + s.rowCount - 1,
    op.destCol + s.colCount - 1,
  );
  if (d.top < 0 || d.left < 0) {
    throw const PlanException('invalid_range', 'Destination outside the grid');
  }
  if (!op.copy && dst.id == src.id && d == s) return;
  final (rowIdAt, colIdAt) = ensureGridSize(b, dst, d.bottom + 1, d.right + 1);
  // Merges moving along.
  final srcMerges = [
    for (final (id, m) in src.mergesIntersecting(s))
      if (s.containsRect(m)) (id, m),
  ];
  for (final (_, m) in src.mergesIntersecting(s)) {
    if (!s.containsRect(m)) {
      throw const PlanException(
        'merge_conflict',
        "You can't move only part of a merged cell",
      );
    }
  }
  if (d.bottom < dst.rows.length && d.right < dst.columns.length) {
    checkMergesNotSplit(
      dst,
      d,
      ignore: {
        if (!op.copy && dst.id == src.id)
          for (final (id, _) in srcMerges) id,
      },
    );
  }
  // Snapshot source cells.
  final snapshot = <(int, int), Map<String, Object?>>{};
  for (final (r, c, _, _, cur) in b.cellsIn(src, s)) {
    snapshot[(r - s.top, c - s.left)] = cellData(cur);
  }
  final hooks = b.ctx.formulas;
  // Clear the source (move only) except where the destination overlaps.
  if (!op.copy) {
    for (final (r, c, rowId, colId, _) in b.cellsIn(src, s).toList()) {
      final inDest = dst.id == src.id && d.contains(r, c);
      if (!inDest) b.deleteCell(src.id, rowId, colId);
    }
  }
  // Write the destination.
  for (var r = 0; r < s.rowCount; r++) {
    for (var c = 0; c < s.colCount; c++) {
      final rowId = rowIdAt(d.top + r);
      final colId = colIdAt(d.left + c);
      final data = snapshot[(r, c)];
      if (data == null) {
        b.deleteCell(dst.id, rowId, colId);
        continue;
      }
      final out = Map<String, Object?>.of(data);
      final content = out[CellCols.content] as String?;
      if (content != null && content.startsWith('=') && hooks != null) {
        if (op.copy) {
          out[CellCols.content] = hooks.translate(
            content,
            fromSheetId: src.id,
            fromRow: s.top + r,
            fromCol: s.left + c,
            toSheetId: dst.id,
            toRow: d.top + r,
            toCol: d.left + c,
          );
        } else {
          out[CellCols.content] =
              hooks.remap(
                content,
                hostSheetId: dst.id,
                sourceSheetId: src.id,
                source: s,
                destSheetId: dst.id,
                dest: d,
              ) ??
              (dst.id == src.id ? content : _pinSheet(content, src.id));
        }
      }
      b.writeCell(dst.id, rowId, colId, out);
    }
  }
  // Destination merges overwritten.
  if (d.bottom < dst.rows.length && d.right < dst.columns.length) {
    for (final (id, m) in dst.mergesIntersecting(d)) {
      if (d.containsRect(m) && !(srcMerges.any((e) => e.$1 == id) && op.copy)) {
        b.delete(SheetsTables.mergedRange, id);
      }
    }
  }
  for (final (id, m) in srcMerges) {
    final moved = GridRect(
      m.top - s.top + d.top,
      m.left - s.left + d.left,
      m.bottom - s.top + d.top,
      m.right - s.left + d.left,
    );
    final json = GridRange(
      sheetId: dst.id,
      r1: rowIdAt(moved.top),
      r2: rowIdAt(moved.bottom),
      c1: colIdAt(moved.left),
      c2: colIdAt(moved.right),
    ).encode();
    if (op.copy) {
      b.insert(SheetsTables.mergedRange, b.ctx.ids.newId(), {
        Cols.sheetId: dst.id,
        Cols.rangeJson: json,
      });
    } else if (dst.id == src.id) {
      b.update(SheetsTables.mergedRange, id, {Cols.rangeJson: json});
    } else {
      b.delete(SheetsTables.mergedRange, id);
      b.insert(SheetsTables.mergedRange, b.ctx.ids.newId(), {
        Cols.sheetId: dst.id,
        Cols.rangeJson: json,
      });
    }
  }
  _moveValidation(b, src, s, dst, d, rowIdAt, colIdAt, copy: op.copy);
  if (!op.copy && hooks != null) _remapReferences(b, src, s, dst, d);
  b.addResolvedRange(ResolvedRange(src.id, s));
  if (d.bottom < dst.rows.length && d.right < dst.columns.length) {
    b.addResolvedRange(ResolvedRange(dst.id, d));
  }
}

String _pinSheet(String stored, String sheetId) => StoredFormula.mapTokens(
  stored,
  (t) => t.sheetId == null && !t.isUnbound ? t.copyWith(sheetId: sheetId) : t,
);

void _moveValidation(
  PlanBuilder b,
  SheetModel src,
  GridRect s,
  SheetModel dst,
  GridRect d,
  String Function(int) rowIdAt,
  String Function(int) colIdAt, {
  required bool copy,
}) {
  final moved =
      <
        (
          String criteria,
          bool strict,
          String? style,
          String? help,
          List<GridRect> rects,
        )
      >[];
  for (final rule in src.dvRules.values) {
    final rects = src.ruleRects(RuleKind.dataValidation, rule.id);
    final inside = [
      for (final r in rects)
        if (r.intersection(s) case final GridRect i) i,
    ];
    if (inside.isEmpty) continue;
    moved.add((
      rule.criteriaJson,
      rule.strict,
      rule.displayStyle,
      rule.helpText,
      [for (final i in inside) i.shift(d.top - s.top, d.left - s.left)],
    ));
  }
  if (moved.isEmpty) return;
  // Remove validation from the moved-out source (move) and the destination.
  if (!copy) _subtractDv(b, src, [s]);
  if (d.bottom < dst.rows.length && d.right < dst.columns.length) {
    _subtractDv(b, dst, [d]);
  }
  for (final (criteria, strict, style, help, rects) in moved) {
    final ranges = [
      for (final r in rects)
        GridRange(
          sheetId: dst.id,
          r1: rowIdAt(r.top),
          r2: rowIdAt(r.bottom),
          c1: colIdAt(r.left),
          c2: colIdAt(r.right),
        ),
    ];
    b.insert(SheetsTables.dataValidationRule, b.ctx.ids.newId(), {
      Cols.sheetId: dst.id,
      Cols.rangesJson: GridRange.encodeList(ranges),
      'criteriaJson': criteria,
      'strict': strict,
      'showDropdown': style != 'plainText',
      'displayStyle': style,
      'helpText': help,
    });
  }
}

void _subtractDv(PlanBuilder b, SheetModel s, List<GridRect> rects) {
  for (final rule in s.dvRules.values.toList()) {
    final cur = b.current(SheetsTables.dataValidationRule, rule.id);
    if (cur == null) continue;
    final current = [
      for (final g in GridRange.parseList(cur[Cols.rangesJson] as String?))
        if (s.resolve(g) case final ResolvedRange r) r.rect,
    ];
    var remaining = current;
    for (final q in rects) {
      remaining = RectSet.subtractAll(remaining, q);
    }
    if (RectSet.sameCells(remaining, current)) continue;
    if (remaining.isEmpty) {
      b.delete(SheetsTables.dataValidationRule, rule.id);
    } else {
      b.update(SheetsTables.dataValidationRule, rule.id, {
        Cols.rangesJson: b.rangesJson(s, remaining),
      });
    }
  }
}

/// Retargets formulas (outside the moved block) and id ranges fully inside the
/// moved block to the destination (05 §5.5).
void _remapReferences(
  PlanBuilder b,
  SheetModel src,
  GridRect s,
  SheetModel dst,
  GridRect d,
) {
  final hooks = b.formulas;
  final srcRowIds = [for (var r = s.top; r <= s.bottom; r++) src.rows.idAt(r)];
  final destRowIds = <int, String>{};
  for (final sheet in b.model.sheets) {
    for (final cell in sheet.cells.all) {
      final content = cell.content;
      if (content == null || !content.startsWith('=')) continue;
      // Cells written by this plan were handled above.
      if (b.touched(SheetsTables.cell, cell.id)) continue;
      if (!StoredFormula.mayReference(content, srcRowIds)) continue;
      final r = hooks.remap(
        content,
        hostSheetId: sheet.id,
        sourceSheetId: src.id,
        source: s,
        destSheetId: dst.id,
        dest: d,
      );
      if (r != null && r != content) {
        b.update(SheetsTables.cell, cell.id, {CellCols.content: r});
      }
    }
  }
  // Id ranges fully inside the source block (named ranges, CF, chart ranges).
  GridRange? remapRange(GridRange g) {
    if (g.sheetId != src.id) return null;
    final rr = src.resolve(g);
    if (rr == null ||
        !s.containsRect(rr.rect) ||
        rr.wholeRows ||
        rr.wholeColumns) {
      return null;
    }
    final m = rr.rect.shift(d.top - s.top, d.left - s.left);
    if (m.bottom >= dst.rows.length || m.right >= dst.columns.length) {
      return null;
    }
    destRowIds[m.top] = dst.rows.idAt(m.top);
    return dst.gridRange(m);
  }

  for (final n in b.model.namedRanges) {
    final g = GridRange.tryParse(n.rangeJson);
    if (g == null) continue;
    final r = remapRange(g);
    if (r != null) {
      b.update(SheetsTables.namedRange, n.id, {Cols.rangeJson: r.encode()});
    }
  }
  if (src.id == dst.id) {
    for (final rule in src.cfRules.values) {
      final ranges = GridRange.parseList(rule.rangesJson);
      var changed = false;
      final out = [
        for (final g in ranges)
          if (remapRange(g) case final GridRange r)
            () {
              changed = true;
              return r;
            }()
          else
            g,
      ];
      if (changed) {
        b.update(SheetsTables.conditionalFormatRule, rule.id, {
          Cols.rangesJson: GridRange.encodeList(out),
        });
      }
    }
  }
  for (final sheet in b.model.sheets) {
    for (final o in sheet.objects.values) {
      final spec = PlanBuilderHelpers.decodeMap(o.specJson);
      var changed = false;
      Object? walk(Object? v) {
        if (v is Map) {
          if (v['s'] is String &&
              (v.containsKey('r1') || v.containsKey('c1'))) {
            final g = GridRange.tryParse(v);
            final r = g == null ? null : remapRange(g);
            if (r != null) {
              changed = true;
              return r.toJson();
            }
            return v;
          }
          return {for (final e in v.entries) e.key: walk(e.value)};
        }
        if (v is List) return [for (final e in v) walk(e)];
        return v;
      }

      final out = walk(spec);
      if (changed) {
        b.update(SheetsTables.embeddedObject, o.id, {
          'specJson': jsonEncode(out),
        });
      }
    }
  }
}

/// Re-exported for paste.
Map<String, Object?> cellDataOf(CellRecord? c) => cellData(c?.toColumns());
