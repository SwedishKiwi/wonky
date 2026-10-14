import 'package:flutter/rendering.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect, SpillArea;
import 'package:wonky_sheets_core/model.dart';

import '../grid/paint/grid_layer.dart';
import '../grid/paint/layers/overlay_layers.dart' show drawDashedRect;
import '../sheet_editor/sheet_editor_controller.dart';

/// The cells blocking the `#SPILL!` dynamic array anchored at ([row], [col])
/// of [sheetId] (03 §14.8): cells with content in the wanted area (the
/// anchor aside) and cells of other overlays (spilled arrays, pivot output)
/// there. Empty when the cell isn't a blocked array. At most [limit].
List<GridRect> spillBlockers(
  SheetEditorController editor,
  String sheetId,
  int row,
  int col, {
  int limit = 500,
}) {
  final sheet = editor.model.sheet(sheetId);
  if (sheet == null) return const [];
  SpillArea? area;
  for (final a in editor.engine.spillAreas(sheetId)) {
    if (a.blocked && a.row == row && a.col == col) {
      area = a;
      break;
    }
  }
  if (area == null) return const [];
  final out = <GridRect>[];
  final seen = <int>{};
  void add(int r, int c) {
    if (out.length >= limit || (r == row && c == col)) return;
    if (seen.add(r * 0x100000 + c)) out.add(GridRect.cell(r, c));
  }

  for (final (r, c, _) in sheet.cellsIn(area.rect, contentOnly: true)) {
    add(r, c);
  }
  // Other dynamic arrays and computed overlays (pivot output).
  for (final other in editor.engine.spillAreas(sheetId)) {
    if (other.blocked || (other.row == row && other.col == col)) continue;
    final i = other.rect.intersection(area.rect);
    if (i == null) continue;
    for (var r = i.top; r <= i.bottom; r++) {
      for (var c = i.left; c <= i.right; c++) {
        add(r, c);
      }
    }
  }
  final overlays = editor.session.engine.view.overlays;
  if (overlays != null) {
    for (final rect in overlays.rectsOf(sheetId)) {
      final i = rect.intersection(area.rect);
      if (i == null) continue;
      for (var r = i.top; r <= i.bottom; r++) {
        for (var c = i.left; c <= i.right; c++) {
          if (overlays.inputAt(sheetId, r, c) != null) add(r, c);
        }
      }
    }
  }
  return out;
}

/// Dashed `spillFrame` outlines around the cells blocking the `#SPILL!`
/// array of the active cell (03 §14.8), while that anchor is selected.
class SpillBlockersLayer extends GridLayer {
  const SpillBlockersLayer();

  @override
  int get zOrder => GridZ.presence + 10;

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    final sel = ctx.selection;
    if (sel.sheetId != ctx.sheetId) return;
    final ed = ctx.controller;
    final v = ed.engine
        .peekValueAt(ctx.sheetId, sel.activeRow, sel.activeCol)
        ?.value
        .toCellValue();
    if (v is! ErrorValue || v.kind != CellErrorKind.spill) return;
    final blockers = spillBlockers(
      ed,
      ctx.sheetId,
      sel.activeRow,
      sel.activeCol,
    );
    if (blockers.isEmpty) return;
    final paint = Paint()
      ..color = ctx.tokens.spillFrame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    ctx.forEachPane(canvas, (pane) {
      if (pane.isEmpty) return;
      for (final b in blockers) {
        final r = pane.rangeRect(b);
        if (r.isEmpty) continue;
        drawDashedRect(canvas, r.deflate(1.5), paint, dash: 4, gap: 3);
      }
    });
  }
}
