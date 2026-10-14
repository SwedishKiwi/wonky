import 'package:flutter/foundation.dart' show Listenable;
import 'package:flutter/painting.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart' show PivotFill;

import '../grid/paint/grid_layer.dart';
import 'pivot_controller.dart';

/// Pivot output chrome below the cell content (07 §7.5): the theme-adaptive
/// `pivotHeaderFill` / `pivotTotalFill` (explicit cell fills paint over
/// them) and the muted message of an empty pivot.
class PivotLayer extends GridLayer {
  PivotLayer();

  /// Below the cell layer (fills, text), above gridlines.
  @override
  int get zOrder => GridZ.cells - 10;

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    final pivots = PivotController.maybeOf(ctx.controller);
    if (pivots == null) return;
    final outputs = pivots.service.outputsOf(ctx.sheetId).toList();
    if (outputs.isEmpty) return;
    final header = Paint()..color = ctx.tokens.pivotHeaderFill;
    final total = Paint()..color = ctx.tokens.pivotTotalFill;
    final rows = ctx.sheet.rows;
    final cols = ctx.sheet.columns;
    ctx.forEachPane(canvas, (pane) {
      if (pane.isEmpty) return;
      final window = GridRect(
        pane.rowStart,
        pane.colStart,
        pane.rowEnd,
        pane.colEnd,
      );
      for (final o in outputs) {
        final message = o.message;
        if (message != null) {
          if (window.contains(o.anchorRow, o.anchorCol)) {
            _message(
              ctx,
              canvas,
              pane.cellRect(o.anchorRow, o.anchorCol),
              message,
            );
          }
          continue;
        }
        if (!o.hasOutput) continue;
        final i = o.rect.intersection(window);
        if (i == null) continue;
        for (var r = i.top; r <= i.bottom; r++) {
          if (rows.sizeAt(r) <= 0) continue;
          for (var c = i.left; c <= i.right; c++) {
            if (cols.sizeAt(c) <= 0) continue;
            final fill = o.cellAt(r, c)?.fill ?? PivotFill.none;
            if (fill == PivotFill.none) continue;
            canvas.drawRect(
              pane.cellRect(r, c),
              fill == PivotFill.header ? header : total,
            );
          }
        }
      }
    });
  }

  void _message(GridPaintContext ctx, Canvas canvas, Rect cell, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: ctx.tokens.headerFg,
          fontStyle: FontStyle.italic,
          fontSize: 12 * ctx.zoom,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(
      canvas,
      Offset(cell.left + 4 * ctx.zoom, cell.center.dy - tp.height / 2),
    );
    tp.dispose();
  }
}

/// Stale styling of pivots recomputing in the background (07 §7.10): the
/// previous output stays, dimmed, with an "Updating…" pill at its top-right
/// corner until the new result replaces it.
class PivotStaleLayer extends GridLayer {
  PivotStaleLayer(this.pivots, this.label);

  final PivotController pivots;

  /// The pill's text (localized).
  final String Function() label;

  @override
  int get zOrder => GridZ.decorations + 20;

  @override
  Listenable? get repaint => pivots.service.running;

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    final service = pivots.service;
    if (service.running.value == 0) return;
    final outputs = [
      for (final o in service.outputsOf(ctx.sheetId))
        if (service.isComputing(o.id)) o,
    ];
    if (outputs.isEmpty) return;
    final tokens = ctx.tokens;
    final dim = Paint()..color = tokens.sheetBackground.withValues(alpha: 0.45);
    ctx.forEachPane(canvas, (pane) {
      if (pane.isEmpty) return;
      for (final o in outputs) {
        final rect = pane.rangeRect(o.rect);
        if (rect.isEmpty) continue;
        if (o.hasOutput) canvas.drawRect(rect, dim);
        final tp = TextPainter(
          text: TextSpan(
            text: label(),
            style: TextStyle(
              color: tokens.headerFg,
              fontSize: 11 * ctx.zoom,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final pad = 6 * ctx.zoom;
        final w = tp.width + pad * 2;
        final h = tp.height + pad;
        final pill = RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.right - w - 2, rect.top + 2, w, h),
          Radius.circular(h / 2),
        );
        canvas
          ..drawRRect(pill, Paint()..color = tokens.headerBg)
          ..drawRRect(
            pill,
            Paint()
              ..color = tokens.headerBorder
              ..style = PaintingStyle.stroke,
          );
        tp.paint(canvas, Offset(pill.left + pad, pill.top + pad / 2));
        tp.dispose();
      }
    });
  }
}
