import 'dart:ui';

import 'package:wonky_sheets_core/formula.dart' show GridRect;

import '../../grid/paint/grid_layer.dart';
import '../presence/remote_presence_layer.dart' show CollabPaintColors;
import 'commit_hints.dart';

/// `pending` commit hints (Sheets 10 §2.2): a subtle tint in the sender's
/// presence color over a range that is about to change, until the synced
/// change arrives or 5 s pass (static, so it respects *Reduce motion*).
class PendingHintLayer extends GridLayer {
  PendingHintLayer(this.hints, this.colors, this.colorOf);

  final CommitHints hints;
  final CollabPaintColors colors;

  /// Presence color index of a session (null when it left).
  final int? Function(String sessionId) colorOf;

  @override
  int get zOrder => GridZ.decorations + 2;

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    if (hints.pending.isEmpty) return;
    final sheet = ctx.sheet;
    for (final p in hints.pending) {
      if (p.sheetId != ctx.sheetId) continue;
      final a = sheet.rows.indexOf(p.range.r1);
      final b = sheet.rows.indexOf(p.range.r2);
      final c = sheet.columns.indexOf(p.range.c1);
      final d = sheet.columns.indexOf(p.range.c2);
      if (a < 0 || b < 0 || c < 0 || d < 0) continue;
      final rect = GridRect.normalized(a, c, b, d);
      final index = colorOf(p.sessionId);
      if (index == null) continue;
      final color = colors.presence(index).withValues(alpha: 0.12);
      ctx.forEachPane(canvas, (pane) {
        if (pane.isEmpty) return;
        canvas.drawRect(pane.rangeRect(rect), Paint()..color = color);
      });
    }
  }
}
