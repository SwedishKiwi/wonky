import 'package:flutter/rendering.dart';
import 'package:wonky_sheets_core/model.dart';

import '../grid/paint/grid_layer.dart';
import 'dv_controller.dart';

/// Invalid-data markers (07 §6.5, 03 §14.2): an `invalidTriangle` in the
/// top-right corner of every visible cell whose value violates its data
/// validation rule. Computed lazily for the painted window only.
class InvalidMarkerLayer extends GridLayer {
  InvalidMarkerLayer(this.dv);

  final DataValidationController dv;

  /// Triangle size at 100 % zoom.
  static const size = 6.0;

  @override
  int get zOrder => GridZ.decorations + 5;

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    final sheet = ctx.sheet;
    final draft = dv.draft;
    final drafted = draft != null && draft.sheetId == sheet.id;
    if (sheet.dvRules.isEmpty && !drafted) return;
    final sid = sheet.id;
    final paint = Paint()..color = ctx.tokens.invalidTriangle;
    final s = size * ctx.zoom;
    ctx.forEachPane(canvas, (pane) {
      if (pane.isEmpty) return;
      for (final r in pane.rows) {
        if (sheet.rows.sizeAt(r) <= 0) continue;
        for (var c = pane.colStart; c <= pane.colEnd; c++) {
          if (sheet.columns.sizeAt(c) <= 0) continue;
          if (sheet.rulesAt(RuleKind.dataValidation, r, c).isEmpty &&
              !(drafted && draft.covers(r, c))) {
            continue;
          }
          if (!dv.isInvalid(sid, r, c)) continue;
          final m = sheet.mergeAt(r, c);
          final rect = m == null ? pane.cellRect(r, c) : pane.rangeRect(m);
          if (m != null && (m.top != r || m.left != c)) continue;
          final corner = rect.topRight;
          canvas.drawPath(
            Path()
              ..moveTo(corner.dx - s, corner.dy)
              ..lineTo(corner.dx, corner.dy)
              ..lineTo(corner.dx, corner.dy + s)
              ..close(),
            paint,
          );
        }
      }
    });
  }
}
