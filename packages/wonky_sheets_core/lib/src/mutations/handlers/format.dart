import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../content/rich_text.dart';
import '../../format/attributes.dart';
import '../../format/borders.dart';
import '../../model/grid_range.dart';
import '../../model/records.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'helpers.dart';
import 'values.dart';

/// Attributes that are also rich-text run keys (06 §11).
const Map<FormatAttr, String> _runKeys = {
  FormatAttr.bold: RichRunKeys.bold,
  FormatAttr.italic: RichRunKeys.italic,
  FormatAttr.underline: RichRunKeys.underline,
  FormatAttr.strikethrough: RichRunKeys.strikethrough,
  FormatAttr.textColor: RichRunKeys.textColor,
  FormatAttr.fontFamily: RichRunKeys.fontFamily,
  FormatAttr.fontSize: RichRunKeys.fontSize,
};

Map<String, Object?> _colValues(Map<FormatAttr, Object?> values) => {
  for (final e in values.entries)
    e.key.column: e.key.toColumnValue(e.key.normalize(e.value)),
};

/// Writes explicit attributes to one cell, removing rich-run keys of those
/// attributes so the whole cell becomes uniform (06 §11).
void writeCellFormat(
  PlanBuilder b,
  SheetModel s,
  String rowId,
  String colId,
  Map<FormatAttr, Object?> values,
) {
  final writes = _colValues(values);
  final cur = b.currentCell(s.id, rowId, colId);
  final content = CellContent.decode(cur?[CellCols.content] as String?);
  if (content is RichTextContent) {
    var rich = content.rich;
    for (final a in values.keys) {
      final k = _runKeys[a];
      if (k != null) rich = rich.withoutKey(k);
    }
    if (rich != content.rich) {
      final n = rich.normalize();
      writes[CellCols.content] = n.rich == null
          ? TextContent(rich.text).encode()
          : RichTextContent(n.rich!).encode();
    }
  }
  b.writeCell(s.id, rowId, colId, writes);
}

/// Applies [values] to one range with the strategies of 06 §1.3.
void applyFormatToRange(
  PlanBuilder b,
  ResolvedRange range,
  Map<FormatAttr, Object?> values,
) {
  final s = b.sheetOf(range.sheetId);
  final rect = range.rect;
  final attrs = values.keys.toSet();
  final nulls = {for (final a in attrs) a: null};
  if (range.wholeSheet) {
    b.writeFormatJson(SheetsTables.sheet, s.id, values);
    for (final id in s.rowRecords.keys) {
      if (attrs.any(b.formatJsonOf(SheetsTables.sheetRow, id).has)) {
        b.writeFormatJson(SheetsTables.sheetRow, id, nulls);
      }
    }
    for (final id in s.columnRecords.keys) {
      if (attrs.any(b.formatJsonOf(SheetsTables.sheetColumn, id).has)) {
        b.writeFormatJson(SheetsTables.sheetColumn, id, nulls);
      }
    }
    for (final (_, _, rowId, colId, cur) in b.cellsIn(s, rect).toList()) {
      if (attrs.any((a) => cur[a.column] != null) || _hasRunKeys(cur, attrs)) {
        writeCellFormat(b, s, rowId, colId, nulls);
      }
    }
    return;
  }
  if (range.wholeColumns) {
    final colIds = [
      for (var c = rect.left; c <= rect.right; c++) s.columns.idAt(c),
    ];
    for (final id in colIds) {
      b.writeFormatJson(SheetsTables.sheetColumn, id, values);
    }
    for (final (_, _, rowId, colId, cur) in b.cellsIn(s, rect).toList()) {
      if (attrs.any((a) => cur[a.column] != null) || _hasRunKeys(cur, attrs)) {
        writeCellFormat(b, s, rowId, colId, nulls);
      }
    }
    // Rows whose default format sets an attribute out-rank the column default:
    // write explicit values at the intersections (Google "last applied wins").
    for (final rowRec in s.rowRecords.values) {
      final rf = b.formatJsonOf(SheetsTables.sheetRow, rowRec.id);
      final over = {
        for (final a in attrs)
          if (rf.has(a)) a: values[a],
      };
      if (over.isEmpty) continue;
      for (final colId in colIds) {
        writeCellFormat(b, s, rowRec.id, colId, over);
      }
    }
    return;
  }
  if (range.wholeRows) {
    for (var r = rect.top; r <= rect.bottom; r++) {
      b.writeFormatJson(SheetsTables.sheetRow, s.rows.idAt(r), values);
    }
    for (final (_, _, rowId, colId, cur) in b.cellsIn(s, rect).toList()) {
      if (attrs.any((a) => cur[a.column] != null) || _hasRunKeys(cur, attrs)) {
        writeCellFormat(b, s, rowId, colId, nulls);
      }
    }
    return;
  }
  for (var r = rect.top; r <= rect.bottom; r++) {
    final rowId = s.rows.idAt(r);
    for (var c = rect.left; c <= rect.right; c++) {
      writeCellFormat(b, s, rowId, s.columns.idAt(c), values);
    }
  }
}

bool _hasRunKeys(Map<String, Object?> cell, Set<FormatAttr> attrs) {
  final content = cell[CellCols.content];
  if (content is! String || !content.startsWith('r:')) return false;
  return attrs.any(_runKeys.containsKey);
}

/// [SetFormat].
MutationPlan planSetFormat(PlanBuilder b, SetFormat op) {
  if (op.values.isEmpty) return b.build(op.label ?? 'Format');
  for (final v in op.values.entries) {
    if (v.value != null && v.key.normalize(v.value) == null) {
      throw PlanException(
        'invalid_argument',
        'Invalid value for ${v.key.column}: ${v.value}',
      );
    }
  }
  for (final range in op.ranges) {
    b.addResolvedRange(range);
    applyFormatToRange(b, range, op.values);
  }
  return b.build(
    op.label ?? _formatLabel(op.values.keys),
    kinds: [ChangeKinds.format],
  );
}

String _formatLabel(Iterable<FormatAttr> attrs) {
  if (attrs.length != 1) return 'Format';
  return switch (attrs.single) {
    FormatAttr.numberFormat => 'Number format',
    FormatAttr.fontFamily => 'Font',
    FormatAttr.fontSize => 'Font size',
    FormatAttr.bold => 'Bold',
    FormatAttr.italic => 'Italic',
    FormatAttr.underline => 'Underline',
    FormatAttr.strikethrough => 'Strikethrough',
    FormatAttr.textColor => 'Text color',
    FormatAttr.fillColor => 'Fill color',
    FormatAttr.hAlign => 'Horizontal align',
    FormatAttr.vAlign => 'Vertical align',
    FormatAttr.wrap => 'Text wrapping',
    FormatAttr.rotation => 'Text rotation',
    FormatAttr.linkUrl => 'Insert link',
    _ => 'Borders',
  };
}

/// Whether every cell of [ranges] is effectively true for [attr] (06 §1.4),
/// computed from row/column/sheet defaults plus explicit cells without
/// visiting empty cells one by one.
bool allTrue(PlanBuilder b, List<ResolvedRange> ranges, FormatAttr attr) {
  for (final range in ranges) {
    final s = b.sheetOf(range.sheetId);
    final rect = range.rect;
    final width = rect.colCount;
    final sheetVal = s.record?.format[attr] as bool?;
    // Explicit cells.
    final explicitPerRow = <String, int>{};
    final explicitPerCol = <String, int>{};
    final rowVal = <String, bool>{};
    for (final rec in s.rowRecords.values) {
      final v = b.formatJsonOf(SheetsTables.sheetRow, rec.id)[attr] as bool?;
      if (v == null) continue;
      final i = s.rows.indexOf(rec.id);
      if (i >= rect.top && i <= rect.bottom) rowVal[rec.id] = v;
    }
    for (final (_, _, rowId, colId, cur) in b.cellsIn(s, rect)) {
      final v = cur[attr.column];
      if (v is! bool) continue;
      if (!v) return false;
      explicitPerRow[rowId] = (explicitPerRow[rowId] ?? 0) + 1;
      if (!rowVal.containsKey(rowId)) {
        explicitPerCol[colId] = (explicitPerCol[colId] ?? 0) + 1;
      }
    }
    // Rows with a row-level value.
    for (final e in rowVal.entries) {
      if (!e.value && (explicitPerRow[e.key] ?? 0) < width) return false;
    }
    // Rows without a row-level value use column ?? sheet ?? false.
    final rowsWithout = rect.rowCount - rowVal.length;
    if (rowsWithout > 0) {
      for (var c = rect.left; c <= rect.right; c++) {
        final colId = s.columns.idAt(c);
        final v =
            b.formatJsonOf(SheetsTables.sheetColumn, colId)[attr] as bool? ??
            sheetVal ??
            false;
        if (!v && (explicitPerCol[colId] ?? 0) < rowsWithout) return false;
      }
    }
  }
  return true;
}

/// [ToggleFormat].
MutationPlan planToggleFormat(PlanBuilder b, ToggleFormat op) {
  if (op.attr.type != FormatValueType.bool) {
    throw PlanException(
      'invalid_argument',
      '${op.attr.column} is not a toggle',
    );
  }
  final value = !allTrue(b, op.ranges, op.attr);
  return planSetFormat(b, SetFormat(op.ranges, {op.attr: value}));
}

/// [ClearFormatting].
MutationPlan planClearFormatting(PlanBuilder b, ClearFormatting op) =>
    planClearRanges(b, ClearRanges(op.ranges, what: ClearWhat.formats));

/// [SetBorders] (06 §8.3).
MutationPlan planSetBorders(PlanBuilder b, SetBorders op) {
  final spec = BorderSpec(op.style, op.color);
  final v = spec.encode();
  for (final range in op.ranges) {
    final s = b.sheetOf(range.sheetId);
    b.addResolvedRange(range);
    final rect = range.rect;
    if (range.wholeRows || range.wholeColumns) {
      _wholeBorders(b, s, range, op.preset, v);
      continue;
    }
    // Merges are treated as their bounding cells: edges inside a merge are not
    // written (06 §8.5).
    final merges = s.mergesIntersecting(rect).map((e) => e.$2).toList();
    bool insideMerge(int r, int c, FormatAttr a) {
      for (final m in merges) {
        if (!m.contains(r, c)) continue;
        switch (a) {
          case FormatAttr.borderBottom:
            if (r < m.bottom) return true;
          case FormatAttr.borderTop:
            if (r > m.top) return true;
          case FormatAttr.borderRight:
            if (c < m.right) return true;
          case FormatAttr.borderLeft:
            if (c > m.left) return true;
          default:
        }
      }
      return false;
    }

    final writes = BorderPresetPlanner.plan(
      op.preset,
      rect,
      spec,
      rowCount: s.rows.length,
      colCount: s.columns.length,
    );
    for (final w in writes) {
      if (w.value != null && insideMerge(w.row, w.col, w.attr)) continue;
      final rowId = s.rows.idAt(w.row);
      final colId = s.columns.idAt(w.col);
      final cur = b.currentCell(s.id, rowId, colId);
      if (w.value == null && (cur == null || cur[w.attr.column] == null)) {
        continue;
      }
      b.writeCell(s.id, rowId, colId, {w.attr.column: w.value});
    }
  }
  return b.build('Borders', kinds: [ChangeKinds.format]);
}

void _wholeBorders(
  PlanBuilder b,
  SheetModel s,
  ResolvedRange range,
  BorderPreset preset,
  String v,
) {
  final rect = range.rect;
  final cols = range.wholeColumns;
  // Along = the dimension the range spans entirely.
  final table = cols ? SheetsTables.sheetColumn : SheetsTables.sheetRow;
  final first = cols ? rect.left : rect.top;
  final last = cols ? rect.right : rect.bottom;
  String idAt(int i) => cols ? s.columns.idAt(i) : s.rows.idAt(i);
  // Edges across (between entities) and along (between cells inside an entity).
  final startEdge = cols ? FormatAttr.borderLeft : FormatAttr.borderTop;
  final endEdge = cols ? FormatAttr.borderRight : FormatAttr.borderBottom;
  final alongA = cols ? FormatAttr.borderTop : FormatAttr.borderLeft;
  final alongB = cols ? FormatAttr.borderBottom : FormatAttr.borderRight;
  void fj(int i, Map<FormatAttr, Object?> m) =>
      b.writeFormatJson(table, idAt(i), m);

  void explicitEdge(int otherIndex, FormatAttr edge) {
    // Writes an edge on every cell of the first/last row (columns ranges) or
    // first/last column (rows ranges): only existing + needed cells.
    for (var i = first; i <= last; i++) {
      if (cols) {
        b.writeCellAt(s.id, otherIndex, i, {edge.column: v});
      } else {
        b.writeCellAt(s.id, i, otherIndex, {edge.column: v});
      }
    }
  }

  final otherLast = cols ? s.rows.length - 1 : s.columns.length - 1;
  switch (preset) {
    case BorderPreset.all:
      for (var i = first; i <= last; i++) {
        fj(i, {startEdge: v, endEdge: v, alongA: v, alongB: v});
      }
    case BorderPreset.inner:
      for (var i = first; i <= last; i++) {
        fj(i, {if (i < last) endEdge: v, alongB: v});
      }
    case BorderPreset.horizontal:
      for (var i = first; i <= last; i++) {
        fj(i, cols ? {alongB: v} : {if (i < last) endEdge: v});
      }
    case BorderPreset.vertical:
      for (var i = first; i <= last; i++) {
        fj(i, cols ? {if (i < last) endEdge: v} : {alongB: v});
      }
    case BorderPreset.outer:
      fj(first, {startEdge: v});
      fj(last, {endEdge: v});
      explicitEdge(0, alongA);
      explicitEdge(otherLast, alongB);
    case BorderPreset.top:
      if (cols) {
        explicitEdge(0, FormatAttr.borderTop);
      } else {
        fj(first, {FormatAttr.borderTop: v});
      }
    case BorderPreset.bottom:
      if (cols) {
        explicitEdge(otherLast, FormatAttr.borderBottom);
      } else {
        fj(last, {FormatAttr.borderBottom: v});
      }
    case BorderPreset.left:
      if (cols) {
        fj(first, {FormatAttr.borderLeft: v});
      } else {
        explicitEdge(0, FormatAttr.borderLeft);
      }
    case BorderPreset.right:
      if (cols) {
        fj(last, {FormatAttr.borderRight: v});
      } else {
        explicitEdge(otherLast, FormatAttr.borderRight);
      }
    case BorderPreset.clear:
      final nulls = {for (final a in FormatAttr.borders) a: null};
      for (var i = first; i <= last; i++) {
        fj(i, nulls);
      }
      for (final (_, _, rowId, colId, cur) in b.cellsIn(s, rect).toList()) {
        if (FormatAttr.borders.any((a) => cur[a.column] != null)) {
          b.writeCell(s.id, rowId, colId, {
            for (final a in FormatAttr.borders) a.column: null,
          });
        }
      }
  }
}

/// [StepFontSize] (06 §6.2 list `6 7 8 9 10 11 12 14 18 24 36 48 72 96`).
MutationPlan planStepFontSize(PlanBuilder b, StepFontSize op) {
  const steps = [6.0, 7, 8, 9, 10, 11, 12, 14, 18, 24, 36, 48, 72, 96];
  double step(double size) {
    if (op.increase) {
      for (final s in steps) {
        if (s > size + 1e-9) return s.toDouble();
      }
      return size < 400 ? (size + 10).clamp(1, 400).toDouble() : 400;
    }
    for (final s in steps.reversed) {
      if (s < size - 1e-9) return s.toDouble();
    }
    return size > 1 ? (size - 1).clamp(1, 400).toDouble() : 1;
  }

  final defaultSize = b.model.spreadsheet.defaultFontSize;
  for (final range in op.ranges) {
    final s = b.sheetOf(range.sheetId);
    b.addResolvedRange(range);
    final rect = range.rect;
    if (range.wholeRows || range.wholeColumns) {
      // Default-level step from the active defaults, plus explicit cells.
      final base =
          (b.model.explicitFormatChain(
                s.id,
                rect.top,
                rect.left,
              )[FormatAttr.fontSize]
              as double?) ??
          defaultSize;
      applyFormatToRange(b, range, {FormatAttr.fontSize: step(base)});
      continue;
    }
    for (var r = rect.top; r <= rect.bottom; r++) {
      for (var c = rect.left; c <= rect.right; c++) {
        final rowId = s.rows.idAt(r);
        final colId = s.columns.idAt(c);
        final explicit = b.currentCell(s.id, rowId, colId)?[CellCols.fontSize];
        final cur = explicit is num
            ? explicit.toDouble()
            : (b.model.explicitFormatChain(s.id, r, c)[FormatAttr.fontSize]
                      as double? ??
                  defaultSize);
        writeCellFormat(b, s, rowId, colId, {FormatAttr.fontSize: step(cur)});
      }
    }
  }
  return b.build(
    op.increase ? 'Increase font size' : 'Decrease font size',
    kinds: [ChangeKinds.format],
  );
}

/// [MergeCells] (06 §10).
MutationPlan planMerge(PlanBuilder b, MergeCells op) {
  for (final range in op.ranges) {
    final s = b.sheetOf(range.sheetId);
    final rect = range.rect;
    b.checkRect(s, rect);
    b.addResolvedRange(range);
    final pieces = <GridRect>[];
    switch (op.mode) {
      case MergeMode.all:
        pieces.add(rect);
      case MergeMode.horizontal:
        if (rect.colCount > 1) {
          for (var r = rect.top; r <= rect.bottom; r++) {
            pieces.add(GridRect(r, rect.left, r, rect.right));
          }
        }
      case MergeMode.vertical:
        if (rect.rowCount > 1) {
          for (var c = rect.left; c <= rect.right; c++) {
            pieces.add(GridRect(rect.top, c, rect.bottom, c));
          }
        }
    }
    if (pieces.isEmpty || pieces.every((p) => p.isSingleCell)) {
      if (op.mode == MergeMode.all) {
        throw const PlanException(
          'invalid_range',
          'Select more than one cell to merge',
        );
      }
      continue;
    }
    final fr = s.record?.frozenRows ?? 0;
    final fc = s.record?.frozenColumns ?? 0;
    for (final p in pieces) {
      if ((fr > 0 && p.top < fr && p.bottom >= fr) ||
          (fc > 0 && p.left < fc && p.right >= fc)) {
        throw const PlanException(
          'merge_conflict',
          "You can't merge frozen and non-frozen cells",
        );
      }
    }
    for (final pv in s.pivots.values) {
      final ar = s.rows.indexOf(pv.anchorRowId);
      final ac = s.columns.indexOf(pv.anchorColId);
      if (ar >= 0 && ac >= 0 && pieces.any((p) => p.contains(ar, ac))) {
        throw const PlanException(
          'merge_conflict',
          "You can't merge cells that overlap a pivot table",
        );
      }
    }
    if (s.rows.visibleIndices(rect.top, rect.bottom).length != rect.rowCount &&
        s.basicFilter != null &&
        pieces.any((p) => p.rowCount > 1)) {
      throw const PlanException(
        'merge_conflict',
        "You can't merge cells in a filtered range with hidden rows",
      );
    }
    if (s.merges.length + pieces.length > 50000) {
      throw const PlanException(
        'limit_exceeded',
        'A sheet can have at most 50,000 merges',
      );
    }
    // Data loss.
    final losing = <(int, int)>[];
    for (final p in pieces) {
      for (final (r, c, _, _, cur) in b.cellsIn(s, p)) {
        if ((r != p.top || c != p.left) && cur[CellCols.content] != null) {
          losing.add((r, c));
        }
      }
    }
    if (losing.isNotEmpty && !op.force) {
      throw PlanException(
        'merge_data_loss',
        'Merging cells only preserves the top-leftmost value. Merge anyway?',
        details: {'cells': losing.length},
      );
    }
    if (losing.isNotEmpty) b.warnings.add('Only the top-left value was kept');
    // Remove overlapping merges.
    for (final (id, _) in s.mergesIntersecting(rect)) {
      b.delete(SheetsTables.mergedRange, id);
    }
    for (final p in pieces) {
      final keptRow = s.rows.idAt(p.top);
      final keptCol = s.columns.idAt(p.left);
      final kept = b.currentCell(s.id, keptRow, keptCol);
      final keptFormat = <String, Object?>{
        for (final a in FormatAttr.values)
          if (!FormatAttr.borders.contains(a) && a != FormatAttr.linkUrl)
            a.column: kept?[a.column],
      };
      for (var r = p.top; r <= p.bottom; r++) {
        for (var c = p.left; c <= p.right; c++) {
          if (r == p.top && c == p.left) continue;
          final writes = <String, Object?>{...keptFormat};
          final rowId = s.rows.idAt(r);
          final colId = s.columns.idAt(c);
          final cur = b.currentCell(s.id, rowId, colId);
          if (cur?[CellCols.content] != null) writes[CellCols.content] = null;
          if (cur == null && keptFormat.values.every((v) => v == null)) {
            continue;
          }
          b.writeCell(s.id, rowId, colId, writes);
        }
      }
      final id = b.ctx.ids.newId();
      b.insert(SheetsTables.mergedRange, id, {
        Cols.sheetId: s.id,
        Cols.rangeJson: s.gridRange(p).encode(),
      });
    }
  }
  return b.build(
    'Merge cells',
    kinds: [ChangeKinds.format, ChangeKinds.structure],
  );
}

/// [UnmergeCells].
MutationPlan planUnmerge(PlanBuilder b, UnmergeCells op) {
  for (final range in op.ranges) {
    final s = b.sheetOf(range.sheetId);
    b.addResolvedRange(range);
    for (final (id, _) in s.mergesIntersecting(range.rect)) {
      b.delete(SheetsTables.mergedRange, id);
    }
  }
  return b.build(
    'Unmerge cells',
    kinds: [ChangeKinds.format, ChangeKinds.structure],
  );
}

/// The merge records of a sheet keyed by id (convenience for tests/UI).
Map<String, MergedRangeRecord> mergesOf(SheetModel s) => s.merges;

/// Rich-run helper re-exported for handlers.
GridRange? parseRange(String? json) => GridRange.tryParse(json);
