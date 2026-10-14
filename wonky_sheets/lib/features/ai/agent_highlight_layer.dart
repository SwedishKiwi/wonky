import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;

import '../grid/paint/grid_layer.dart';

/// One flashed range: an agent (MCP client, the assistant) works there, or
/// *Show* of an assistant tool chip.
@immutable
class AgentHighlight {
  const AgentHighlight({
    required this.sheetId,
    required this.rect,
    required this.label,
    required this.color,
  });

  final String sheetId;
  final GridRect rect;

  /// Shown in a tag above the range ("Claude Code (MCP)", "AI").
  final String label;
  final Color color;
}

/// The agent presence highlight of the grid (Sheets 12 §1.4, §5
/// `ui.sheets.highlight_range`): outlined, lightly filled ranges with a name
/// tag that disappear after their duration. Painted in the overlay pass
/// at the presence z order.
class AgentHighlightLayer extends GridLayer {
  AgentHighlightLayer();

  /// The agent color (violet; readable on light and dark sheets).
  static const agentColor = Color(0xff8b5cf6);

  final _signal = _Signal();
  final List<(AgentHighlight, Timer)> _items = [];

  @override
  int get zOrder => GridZ.presence;

  @override
  Listenable get repaint => _signal;

  /// The highlights shown now (tests, `ui.sheets.get_selection`).
  List<AgentHighlight> get active => [for (final (h, _) in _items) h];

  /// Shows [h] for [duration] (replacing a highlight of the same range).
  void flash(
    AgentHighlight h, {
    Duration duration = const Duration(seconds: 5),
  }) {
    _items.removeWhere((e) {
      final same = e.$1.sheetId == h.sheetId && e.$1.rect == h.rect;
      if (same) e.$2.cancel();
      return same;
    });
    late final (AgentHighlight, Timer) entry;
    entry = (
      h,
      Timer(duration, () {
        _items.remove(entry);
        _signal.fire();
      }),
    );
    _items.add(entry);
    _signal.fire();
  }

  /// Removes every highlight.
  void clear() {
    for (final (_, t) in _items) {
      t.cancel();
    }
    _items.clear();
    _signal.fire();
  }

  void dispose() {
    for (final (_, t) in _items) {
      t.cancel();
    }
    _items.clear();
    _signal.dispose();
  }

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    if (_items.isEmpty) return;
    final sheet = ctx.sheet;
    final rowsN = sheet.rows.length;
    final colsN = sheet.columns.length;
    if (rowsN == 0 || colsN == 0) return;
    final bounds = GridRect(0, 0, rowsN - 1, colsN - 1);
    for (final (h, _) in _items) {
      if (h.sheetId != sheet.id) continue;
      final rect = h.rect.intersection(bounds);
      if (rect == null) continue;
      Rect? tagAnchor;
      ctx.forEachPane(canvas, (pane) {
        final r = pane.rangeRect(rect);
        if (!r.overlaps(pane.rect)) return;
        canvas.drawRect(r, Paint()..color = h.color.withValues(alpha: 0.08));
        canvas.drawRect(
          r.deflate(1),
          Paint()
            ..color = h.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        if (tagAnchor == null && pane.rect.contains(r.topLeft + Offset(1, 1))) {
          tagAnchor = r;
        }
      });
      final anchor = tagAnchor;
      if (anchor != null) _paintTag(ctx, canvas, anchor, h);
    }
  }

  void _paintTag(
    GridPaintContext ctx,
    Canvas canvas,
    Rect range,
    AgentHighlight h,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: h.label,
        style: const TextStyle(
          color: Color(0xffffffff),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 220);
    final w = tp.width + 10;
    final hgt = tp.height + 4;
    final cells = ctx.geometry.cellsRect;
    // Above the range; inside it when the range touches the top.
    var top = range.top - hgt;
    if (top < cells.top) top = range.top;
    final left = math.max(cells.left, range.left);
    final tag = Rect.fromLTWH(left, top, w, hgt);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        tag,
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      ),
      Paint()..color = h.color,
    );
    tp.paint(canvas, Offset(tag.left + 5, tag.top + 2));
    tp.dispose();
  }
}

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}
