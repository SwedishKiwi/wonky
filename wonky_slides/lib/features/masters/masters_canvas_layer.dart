import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/model.dart';

import '../../config/menus/slides_menu_spec.dart' show placeholderTypeLabel;
import '../../l10n/slides_l10n.dart';
import '../canvas/canvas_interactions.dart';
import '../canvas/canvas_tokens.dart';
import '../canvas/slide_canvas_controller.dart';
import '../selection/slide_elements.dart';

/// Master mode chrome on the canvas (Slides 05 §8.1; SL-28): every
/// placeholder of the edited layout or master gets a dashed outline and a
/// small type label ("Title", "Picture", "Slide number"), so empty and
/// non-text placeholders stay visible and recognizable. Drawn above the
/// stage, never hit-tested (the canvas selects and edits the placeholders
/// like any element).
class MastersCanvasLayer extends CanvasInteraction {
  MastersCanvasLayer(super.c);

  @override
  List<Widget> overlays(BuildContext context) {
    if (!c.editor.editsMasters) return const [];
    final slide = c.slide;
    if (slide == null || !slide.isSurface) return const [];
    final l = slidesL10n(context);
    final tokens = CanvasTokens.of(context);
    final items = <(ElementFrame, String)>[];
    for (final e in slide.elements) {
      final type = e.placeholderType;
      if (type == null || e.hidden) continue;
      items.add((
        c.frameOf(e.id) ?? SlideElements.frameOf(e),
        placeholderTypeLabel(l, type),
      ));
    }
    if (items.isEmpty) return const [];
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: const ValueKey<String>('slides.masters.placeholderChrome'),
            painter: _PlaceholderChromePainter(
              c,
              items,
              border: tokens.selection.withValues(alpha: 0.55),
              labelFill: tokens.selection,
              labelText: tokens.labelText,
              textDirection: Directionality.of(context),
            ),
          ),
        ),
      ),
    ];
  }
}

class _PlaceholderChromePainter extends CustomPainter {
  _PlaceholderChromePainter(
    this.c,
    this.items, {
    required this.border,
    required this.labelFill,
    required this.labelText,
    required this.textDirection,
  });

  final SlideCanvasController c;
  final List<(ElementFrame, String)> items;
  final Color border;
  final Color labelFill;
  final Color labelText;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final v = c.viewport;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = border;
    for (final (f, label) in items) {
      final corners = [
        for (final (x, y) in [
          (0.0, 0.0),
          (f.width, 0.0),
          (f.width, f.height),
          (0.0, f.height),
        ])
          v.toViewport(SlideCanvasController.localToSlide(f, x, y)),
      ];
      for (var i = 0; i < 4; i++) {
        _dashed(canvas, corners[i], corners[(i + 1) % 4], stroke);
      }
      // The label above the top-left corner, clear of the content (inside
      // when there is no room above; rotated frames: at the corner,
      // unrotated).
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: labelText,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        textDirection: textDirection,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(24, (corners[1] - corners[0]).distance));
      final above = corners[0] - Offset(0, tp.height + 6);
      final at = above.dy >= 0 ? above : corners[0] + const Offset(1, 1);
      final box = Rect.fromLTWH(at.dx, at.dy, tp.width + 8, tp.height + 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(3)),
        Paint()..color = labelFill.withValues(alpha: 0.85),
      );
      tp.paint(canvas, at + const Offset(4, 2));
    }
  }

  static void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
    const dash = 5.0, gap = 4.0;
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    final u = d / len;
    for (var t = 0.0; t < len; t += dash + gap) {
      canvas.drawLine(a + u * t, a + u * math.min(len, t + dash), p);
    }
  }

  @override
  bool shouldRepaint(_PlaceholderChromePainter old) => true;
}
