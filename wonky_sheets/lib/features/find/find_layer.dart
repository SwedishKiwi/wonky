import 'package:flutter/foundation.dart' show Listenable;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show Brightness;

import '../grid/paint/grid_layer.dart';
import 'find_controller.dart';

/// Match highlights of find (07 §11.1): every match in the viewport gets the
/// `findMatch` fill, the current one `findMatchActive` (suite 02 tokens).
class FindLayer extends GridLayer {
  const FindLayer(this.find);

  final FindController find;

  @override
  int get zOrder => GridZ.find;

  @override
  Listenable? get repaint => find;

  static Color match(Brightness b) =>
      b == Brightness.dark ? const Color(0x4dfacc15) : const Color(0x66fde047);

  static Color active(Brightness b) =>
      b == Brightness.dark ? const Color(0x99f97316) : const Color(0xb3fb923c);

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    if (!find.active || !find.hasMatches(ctx.sheetId)) return;
    final b = ctx.tokens.brightness;
    final fill = Paint()..color = match(b);
    final cur = find.currentMatch;
    ctx.forEachPane(canvas, (pane) {
      if (pane.isEmpty) return;
      for (var r = pane.rowStart; r <= pane.rowEnd; r++) {
        if (ctx.sheet.rows.sizeAt(r) <= 0) continue;
        for (var c = pane.colStart; c <= pane.colEnd; c++) {
          if (!find.isMatch(ctx.sheetId, r, c)) continue;
          final rect = ctx.sheet.mergeAt(r, c) == null
              ? pane.cellRect(r, c)
              : pane.rangeRect(ctx.sheet.mergeAt(r, c)!);
          final isCur =
              cur != null &&
              cur.sheetId == ctx.sheetId &&
              cur.row == r &&
              cur.col == c;
          canvas.drawRect(rect, isCur ? (Paint()..color = active(b)) : fill);
        }
      }
    });
  }
}
