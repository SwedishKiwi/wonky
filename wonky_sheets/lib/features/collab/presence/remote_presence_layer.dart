import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Listenable;
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;

import '../../grid/paint/grid_layer.dart';
import '../../grid/paint/layers/overlay_layers.dart' show drawDashedRect;
import 'sheets_presence_controller.dart';

/// Theme-dependent colors of the collaboration layers, refreshed by the
/// collaboration overlay widget on every build (light/dark).
class CollabPaintColors {
  /// Presence color of an index (`presence1…12`).
  Color Function(int colorIndex) presence = (_) => const Color(0xFF1A73E8);
  bool dark = false;

  /// Text on a presence-colored pill: white or black by luminance.
  static Color onColor(Color c) => c.computeLuminance() > 0.5
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);
}

/// Remote cursors and selections (Sheets 10 §1.2): range fill + 1 px border,
/// 2 px active-cell border (dashed while editing, dotted for agents), name
/// flags (3 s after moving, while editing; stacked, max 3 then "+N").
class RemotePresenceLayer extends GridLayer {
  RemotePresenceLayer(
    this.presence,
    this.colors, {
    required this.typingLabel,
    String Function(RemoteCursorView c)? nameOf,
  }) : nameOf = nameOf ?? ((c) => c.displayName);

  final SheetsPresenceController presence;
  final CollabPaintColors colors;

  /// "typing…" (localized).
  final String Function() typingLabel;

  /// The flag label of a participant ("Claude via MCP (Anna)" for agents).
  final String Function(RemoteCursorView c) nameOf;

  @override
  int get zOrder => GridZ.presence;

  @override
  Listenable? get repaint => presence.repaint;

  static GridRect _clip(GridRect r, int rows, int cols) =>
      r.intersection(GridRect(0, 0, rows - 1, cols - 1)) ?? r;

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    final sheet = ctx.sheet;
    final list = presence.cursorsOn(ctx.sheetId);
    if (list.isEmpty || sheet.rows.length == 0 || sheet.columns.length == 0) {
      return;
    }
    final now = DateTime.now();
    final fillAlpha = colors.dark ? 0.16 : 0.10;
    final actives = <(Rect, RemoteCursorView, Color)>[];
    ctx.forEachPane(canvas, (pane) {
      if (pane.isEmpty) return;
      final visible = GridRect(
        math.max(0, pane.rowStart - 1),
        math.max(0, pane.colStart - 1),
        pane.rowEnd + 1,
        pane.colEnd + 1,
      );
      for (final c in list) {
        final color = colors.presence(c.colorIndex);
        for (final r in c.cursor.ranges) {
          final rect = SheetsPresenceController.rectOf(sheet, r);
          if (rect == null) continue;
          final shown = _clip(
            rect,
            sheet.rows.length,
            sheet.columns.length,
          ).intersection(visible);
          if (shown == null) continue;
          final rr = pane.rangeRect(shown);
          canvas.drawRect(
            rr,
            Paint()..color = color.withValues(alpha: fillAlpha),
          );
          canvas.drawRect(
            rr.deflate(0.5),
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
        final a = SheetsPresenceController.activeOf(sheet, c.cursor);
        if (a == null) continue;
        final cellRect = sheet.mergeAt(a.$1, a.$2) ?? GridRect.cell(a.$1, a.$2);
        if (cellRect.intersection(visible) == null) continue;
        final rr = pane.rangeRect(cellRect).deflate(1.5);
        final flashing = c.sessionId == presence.flashSession;
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = flashing && presence.flashOn ? 4 : 2;
        if (c.cursor.editing) {
          drawDashedRect(
            canvas,
            rr,
            paint,
            dash: 5,
            gap: 3,
            phase: presence.marchPhase,
          );
          final t = presence.typingOf(c, now);
          if (t != null) {
            _typing(ctx, canvas, pane.rangeRect(cellRect), t.text, color);
          }
        } else if (c.isAgent) {
          drawDashedRect(canvas, rr, paint, dash: 2, gap: 2);
        } else {
          canvas.drawRect(rr, paint);
        }
        if (pane.showsRow(a.$1) && pane.showsCol(a.$2)) {
          actives.add((pane.rangeRect(cellRect), c, color));
        }
      }
    });
    _flags(ctx, canvas, actives, now);
  }

  /// The collaborator's in-progress text over their cell (P2 typing
  /// preview): italic, on the grid background, clipped to the cell (wider
  /// to the right while the text needs it, like the cell editor).
  void _typing(
    GridPaintContext ctx,
    Canvas canvas,
    Rect cell,
    String text,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text.replaceAll('\n', ' '),
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          height: 1.2,
          color: colors.dark
              ? const Color(0xFFE5E7EB)
              : const Color(0xFF1F2937),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(cell.width, 240) - 8);
    final w = math.max(cell.width, tp.width + 8);
    final r = Rect.fromLTWH(cell.left, cell.top, w, cell.height).deflate(2.5);
    canvas.drawRect(
      r,
      Paint()
        ..color = colors.dark
            ? const Color(0xFF111827)
            : const Color(0xFFFFFFFF),
    );
    canvas.drawRect(
      r,
      Paint()..color = color.withValues(alpha: colors.dark ? 0.16 : 0.10),
    );
    canvas.save();
    canvas.clipRect(r);
    tp.paint(canvas, Offset(r.left + 3, r.top + (r.height - tp.height) / 2));
    canvas.restore();
  }

  void _flags(
    GridPaintContext ctx,
    Canvas canvas,
    List<(Rect, RemoteCursorView, Color)> actives,
    DateTime now,
  ) {
    // Group by cell (stacked flags).
    final byCell = <Rect, List<(RemoteCursorView, Color)>>{};
    for (final (rect, c, color) in actives) {
      if (!presence.flagVisible(c, now)) continue;
      byCell.putIfAbsent(rect, () => []).add((c, color));
    }
    final cells = ctx.geometry.cellsRect;
    for (final e in byCell.entries) {
      final rect = e.key;
      final items = e.value;
      final shown = items.take(3).toList();
      var y = rect.top;
      final below = rect.top - 18 * shown.length < cells.top;
      var x = rect.left;
      for (var i = 0; i < shown.length; i++) {
        final (c, color) = shown[i];
        final more = i == shown.length - 1 && items.length > 3
            ? ' +${items.length - 3}'
            : '';
        final label =
            '${c.isAgent ? '✦ ' : ''}${nameOf(c)}'
            '${c.cursor.editing ? ' ✎ ${typingLabel()}' : ''}$more';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Geist',
              height: 1.2,
              color: CollabPaintColors.onColor(color),
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 220);
        final w = tp.width + 10;
        const h = 17.0;
        final top = below ? rect.bottom + 1 + i * (h + 1) : y - h - 1;
        if (!below) y = top;
        if (x + w > cells.right) x = math.max(cells.left, cells.right - w);
        final pill = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, top, w, h),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        );
        canvas.drawRRect(pill, Paint()..color = color);
        tp.paint(canvas, Offset(x + 5, top + (h - tp.height) / 2));
      }
    }
  }
}
