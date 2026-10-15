import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/themes.dart';

/// A simple static rendering of a resolved slide: background (solid or
/// gradient), element frames and their plain text in the theme's paragraph
/// style. It stands in for SL-10's `SlideStage` on the canvas placeholder
/// and the navigator shell until the real stage (SL-10) and canvas (SL-12)
/// replace it; it never edits.
class SlidePreview extends StatelessWidget {
  const SlidePreview({
    super.key,
    required this.slide,
    this.showPrompts = false,
    this.semanticLabel,
  });

  final ResolvedSlide slide;

  /// Draw the prompts of empty placeholders ("Click to add title").
  final bool showPrompts;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final b = slide.bounds;
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      child: AspectRatio(
        aspectRatio: b.width / b.height,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: SlidePreviewPainter(slide, showPrompts: showPrompts),
          ),
        ),
      ),
    );
  }
}

/// Paints a [ResolvedSlide] (see [SlidePreview]).
class SlidePreviewPainter extends CustomPainter {
  SlidePreviewPainter(this.slide, {this.showPrompts = false});

  final ResolvedSlide slide;
  final bool showPrompts;

  @override
  void paint(Canvas canvas, Size size) {
    final b = slide.bounds;
    final area = Offset.zero & Size(b.width, b.height);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / b.width, size.height / b.height);
    _paintFill(canvas, area, slide.background.fill, fallback: 0xffffffff);
    final overlay = slide.background.overlay;
    if (overlay != null) _paintFill(canvas, area, overlay);
    final ink = Color(
      slide.theme.textStyles['body']?.color ?? 0xff1f2937,
    ).withValues(alpha: 0.28);
    for (final e in slide.painted) {
      if (e.hidden) continue;
      _paintElement(canvas, e, ink);
    }
    canvas.restore();
  }

  void _paintFill(Canvas canvas, Rect r, ResolvedFill fill, {int? fallback}) {
    final paint = Paint();
    switch (fill) {
      case ResolvedSolidFill(:final color):
        paint.color = Color(color);
      case ResolvedGradientFill(:final angle, :final stops)
          when stops.length > 1:
        final rad = angle * math.pi / 180;
        final c = r.center;
        final d = Offset(math.cos(rad), math.sin(rad)) * (r.longestSide / 2);
        paint.shader = ui.Gradient.linear(
          c - d,
          c + d,
          [for (final s in stops) Color(s.$2)],
          [for (final s in stops) s.$1.clamp(0.0, 1.0)],
        );
      default:
        final c = fill.representativeColor ?? fallback;
        if (c == null) return;
        paint.color = Color(c);
    }
    canvas.drawRect(r, paint);
  }

  void _paintElement(Canvas canvas, ResolvedElement e, Color ink) {
    final f = e.frame;
    final rect = Rect.fromLTWH(f.x, f.y, f.width, f.height);
    canvas.save();
    if (e.rotation != 0) {
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(e.rotation * math.pi / 180);
      canvas.translate(-rect.center.dx, -rect.center.dy);
    }
    final text = e.fieldText ?? SlidesText.plainText(e.text);
    final styles = e.textStyles;
    final style = styles?.styles[e.styleKey ?? styles.defaultStyle];
    if (text.trim().isNotEmpty && style != null) {
      _paintText(canvas, rect, text, style, opacity: e.opacity);
    } else if (showPrompts && e.prompt != null && style != null) {
      _paintText(canvas, rect, e.prompt!, style, opacity: 0.45 * e.opacity);
      _outline(canvas, rect, ink, dashed: true);
    } else if (e.record.kind != ElementKind.text &&
        e.record.kind != ElementKind.group &&
        e.placeholderType == null) {
      // Shapes, images, tables, charts, code and icons: their frame until
      // the stage renders them (SL-10).
      _outline(canvas, rect, ink);
    }
    canvas.restore();
  }

  void _outline(Canvas canvas, Rect r, Color ink, {bool dashed = false}) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = ink;
    if (!dashed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(8)),
        paint,
      );
      return;
    }
    const dash = 18.0, gap = 12.0;
    for (final (a, b) in [
      (r.topLeft, r.topRight),
      (r.topRight, r.bottomRight),
      (r.bottomRight, r.bottomLeft),
      (r.bottomLeft, r.topLeft),
    ]) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var t = 0.0; t < len; t += dash + gap) {
        canvas.drawLine(a + dir * t, a + dir * math.min(t + dash, len), paint);
      }
    }
  }

  void _paintText(
    Canvas canvas,
    Rect r,
    String text,
    ResolvedTextStyle s, {
    double opacity = 1,
  }) {
    final pad = math.min(24.0, r.width / 10);
    final width = math.max(1.0, r.width - pad * 2);
    final tp = TextPainter(
      text: TextSpan(
        text: s.caps == 'all' ? text.toUpperCase() : text,
        style: TextStyle(
          fontFamily: s.font.family,
          fontWeight:
              FontWeight.values[((s.font.face.weight ~/ 100) - 1).clamp(0, 8)],
          fontStyle: s.font.face.italic ? FontStyle.italic : FontStyle.normal,
          fontSize: s.size,
          height: s.lineHeight,
          letterSpacing: s.letterSpacing * s.size,
          color: Color(s.color).withValues(alpha: opacity),
        ),
      ),
      textAlign: switch (s.align) {
        'center' => TextAlign.center,
        'right' || 'end' => TextAlign.right,
        'justify' => TextAlign.justify,
        _ => TextAlign.left,
      },
      textDirection: TextDirection.ltr,
      ellipsis: '…',
      maxLines: math.max(1, (r.height / (s.size * s.lineHeight)).floor()),
    )..layout(maxWidth: width);
    final dy = math.max(0.0, (r.height - tp.height) / 2);
    tp.paint(canvas, Offset(r.left + pad, r.top + dy));
    tp.dispose();
  }

  @override
  bool shouldRepaint(SlidePreviewPainter old) =>
      !identical(old.slide, slide) || old.showPrompts != showPrompts;
}
