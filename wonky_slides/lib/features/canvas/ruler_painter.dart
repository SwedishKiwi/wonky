import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

import 'canvas_controller.dart';

/// A canvas ruler (03 §5.6, P1): a 20 px strip with slide-unit ticks and
/// labels, the slide's extent from 0, and the selection's [extent]
/// highlighted. Tick spacing adapts to the zoom (labels ≥ 60 px apart).
class RulerPainter extends CustomPainter {
  RulerPainter({
    required this.axis,
    required this.viewport,
    required this.background,
    required this.ink,
    required this.border,
    required this.highlight,
    this.extent,
  }) : super(repaint: viewport);

  final Axis axis;
  final CanvasController viewport;
  final Color background;
  final Color ink;
  final Color border;
  final Color highlight;

  /// The selection bounds (su), highlighted on the ruler.
  final SuRect? extent;

  static const _steps = <double>[5, 10, 20, 50, 100, 200, 500, 1000, 2000];

  /// The labeled step (su) for [scale] px per su.
  static double stepFor(double scale) {
    for (final s in _steps) {
      if (s * scale >= 60) return s;
    }
    return _steps.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final horizontal = axis == Axis.horizontal;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final edge = Paint()
      ..color = border
      ..strokeWidth = 1;
    if (horizontal) {
      canvas.drawLine(
        Offset(0, size.height - 0.5),
        Offset(size.width, size.height - 0.5),
        edge,
      );
    } else {
      canvas.drawLine(
        Offset(size.width - 0.5, 0),
        Offset(size.width - 0.5, size.height),
        edge,
      );
    }
    final s = viewport.scale;
    final o = horizontal ? viewport.origin.dx : viewport.origin.dy;
    final length = horizontal ? size.width : size.height;
    final cross = horizontal ? size.height : size.width;
    final e = extent;
    if (e != null) {
      final a = o + (horizontal ? e.x : e.y) * s;
      final b = o + (horizontal ? e.right : e.bottom) * s;
      canvas.drawRect(
        horizontal
            ? Rect.fromLTRB(a, 0, b, cross)
            : Rect.fromLTRB(0, a, cross, b),
        Paint()..color = highlight,
      );
    }
    final step = stepFor(s);
    final minor = step / 5;
    final tick = Paint()
      ..color = ink.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = ((-o / s) / minor).floor(); o + i * minor * s <= length; i++) {
      final v = i * minor;
      final p = (o + v * s).roundToDouble() + 0.5;
      final major = i % 5 == 0;
      final len = major ? cross * 0.6 : cross * 0.25;
      if (horizontal) {
        canvas.drawLine(Offset(p, cross - len), Offset(p, cross), tick);
      } else {
        canvas.drawLine(Offset(cross - len, p), Offset(cross, p), tick);
      }
      if (major) _number(canvas, v, p, horizontal);
    }
  }

  void _number(Canvas canvas, double v, double p, bool horizontal) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 9))
      ..pushStyle(ui.TextStyle(color: ink, fontSize: 9))
      ..addText('${v.round()}');
    final para = pb.build()..layout(const ui.ParagraphConstraints(width: 60));
    if (horizontal) {
      canvas.drawParagraph(para, Offset(p + 3, 1));
    } else {
      canvas.save();
      canvas.translate(1, p - 3);
      canvas.rotate(-1.5707963267948966);
      canvas.drawParagraph(para, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(RulerPainter old) =>
      old.axis != axis ||
      old.background != background ||
      old.ink != ink ||
      old.extent != extent ||
      !identical(old.viewport, viewport);
}
