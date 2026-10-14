import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../grid/paint/grid_layer.dart';
import 'sheets_comments.dart';

/// Comment indicators (Sheets 10 §3.3, 03 §14.6): a 6 px `commentHighlight`
/// triangle in the top-right corner of the anchor's top-right cell (above
/// the note triangle: the comment wins); the active range thread is
/// outlined.
class CommentIndicatorLayer extends GridLayer {
  CommentIndicatorLayer(this.comments);

  final SheetsComments comments;

  @override
  int get zOrder => GridZ.decorations + 1;

  @override
  Listenable? get repaint => comments.repaint;

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    if (!comments.indicatorsOn || !comments.visible) return;
    final list = comments.bySheet[ctx.sheetId];
    if (list == null || list.isEmpty) return;
    final color = ctx.tokens.commentHighlight;
    final active = comments.controller?.activeThreadUuid;
    final s = 6 * ctx.zoom;
    final fill = Paint()..color = color;
    ctx.forEachPane(canvas, (pane) {
      if (pane.isEmpty) return;
      for (final p in list) {
        final (row, col) = p.indicator;
        if (row < pane.rowStart - 1 ||
            row > pane.rowEnd + 1 ||
            col < pane.colStart - 1 ||
            col > pane.colEnd + 1) {
          if (!(p.thread.uuid.uuid == active && !p.rect.isSingleCell)) {
            continue;
          }
        }
        if (p.thread.uuid.uuid == active && !p.rect.isSingleCell) {
          canvas.drawRect(
            pane.rangeRect(p.rect).deflate(0.75),
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
        if (!pane.showsRow(row) || !pane.showsCol(col)) continue;
        if (ctx.sheet.rows.sizeAt(row) <= 0 ||
            ctx.sheet.columns.sizeAt(col) <= 0) {
          continue;
        }
        final corner = pane.cellRect(row, col).topRight;
        canvas.drawPath(
          Path()
            ..moveTo(corner.dx - s, corner.dy)
            ..lineTo(corner.dx, corner.dy)
            ..lineTo(corner.dx, corner.dy + s)
            ..close(),
          fill,
        );
      }
    });
  }
}
