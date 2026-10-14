import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../grid/paint/grid_layer.dart';
import 'protection_controller.dart';

/// Diagonal stripes over protected cells (03 §16, View › Show › Protected
/// ranges): 45°, 1 px lines every 8 px in the `protectedStripe` token.
/// Exception ranges of sheet protections stay clear.
class ProtectedRangesLayer extends GridLayer {
  ProtectedRangesLayer(this.protection);

  final ProtectionController protection;

  /// Spacing of the stripes (px, not zoomed).
  static const spacing = 8.0;

  @override
  int get zOrder => GridZ.decorations + 10;

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    if (!protection.showStripes || ctx.sheet.protections.isEmpty) return;
    final entries = protection.entriesOf(ctx.sheetId);
    if (entries.isEmpty) return;
    final paint = Paint()
      ..color = ctx.tokens.protectedStripe
      ..strokeWidth = 1
      ..isAntiAlias = true;
    ctx.forEachPane(canvas, (pane) {
      if (pane.isEmpty) return;
      final window = GridRect(
        pane.rowStart,
        pane.colStart,
        pane.rowEnd,
        pane.colEnd,
      );
      for (final e in entries) {
        for (final r in e.rects) {
          final visible = r.intersection(window);
          if (visible == null) continue;
          var parts = [visible];
          for (final x in e.except) {
            parts = RectSet.subtractAll(parts, x);
          }
          for (final p in parts) {
            _stripes(canvas, pane.rangeRect(p), paint);
          }
        }
      }
    });
  }

  static void _stripes(Canvas canvas, Rect rect, Paint paint) {
    if (rect.width <= 0 || rect.height <= 0) return;
    canvas.save();
    canvas.clipRect(rect);
    // Lines x - y = k for k on a grid anchored at the origin, so stripes of
    // neighbouring rectangles line up.
    final start = ((rect.left - rect.bottom) / spacing).floor() * spacing;
    final end = rect.right - rect.top;
    for (var k = start; k <= end; k += spacing) {
      final y0 = rect.top;
      final y1 = rect.bottom;
      canvas.drawLine(Offset(k + y0, y0), Offset(k + y1, y1), paint);
    }
    canvas.restore();
  }

  /// Visible for tests: the number of stripes drawn over [rect].
  static int stripeCount(Rect rect) {
    final start = ((rect.left - rect.bottom) / spacing).floor() * spacing;
    final end = rect.right - rect.top;
    return math.max(0, ((end - start) / spacing).floor() + 1);
  }
}
