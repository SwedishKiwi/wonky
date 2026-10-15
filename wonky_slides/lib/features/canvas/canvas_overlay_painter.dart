import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/snapping.dart';

import '../selection/transform_session.dart';
import '../stage/scene_painter.dart';
import 'canvas_interactions.dart';
import 'canvas_tokens.dart';
import 'canvas_tools.dart' show paintToolPreview;
import 'slide_canvas_controller.dart';

/// Strings the overlay draws (badges), resolved by the canvas.
class CanvasOverlayLabels {
  const CanvasOverlayLabels({
    required this.position,
    required this.dimensions,
    required this.angle,
  });

  final String Function(int x, int y) position;
  final String Function(int w, int h) dimensions;
  final String Function(int degrees) angle;

  static final fallback = CanvasOverlayLabels(
    position: (x, y) => '$x, $y',
    dimensions: (w, h) => '$w × $h',
    angle: (d) => '$d°',
  );
}

/// Paints the canvas overlay layer (03 §2.4, §3.1, §5.2) in viewport px,
/// above the slide and without touching its content: user guides, the
/// entered group's dashed outline, selection outlines and the selection
/// box with its handles (resize, rotation, adjust, line endpoints), the
/// lock badge, smart guides with × markers, equal-spacing bars with their
/// distance, equal-size markers, the marquee, live adjust/line previews
/// and the position/size/angle badge of a drag. Repaints with the
/// [SlideCanvasController] (selection, gestures, viewport).
class CanvasOverlayPainter extends CustomPainter {
  CanvasOverlayPainter(
    this.c, {
    required this.tokens,
    required this.showGuides,
    required this.guides,
    this.labels,
  }) : super(repaint: c);

  final SlideCanvasController c;
  final CanvasTokens tokens;
  final bool showGuides;
  final List<UserGuide> guides;
  final CanvasOverlayLabels? labels;

  @override
  void paint(Canvas canvas, Size size) {
    final v = c.viewport;
    if (showGuides) _userGuides(canvas, size);
    final gp = c.guide;
    if (gp != null) _guidePreview(canvas, size, gp);
    final entered = c.selection.enteredGroupId;
    if (entered != null) {
      final f = c.frameOf(entered);
      if (f != null) {
        _frameOutline(canvas, f, tokens.selection, 1, dashed: true);
      }
    }
    final modes = CanvasInteractions.of(c);
    final chrome = !modes.any((i) => i.active && i.hidesSelectionChrome);
    final frames = chrome
        ? c.selectionFrames()
        : const <String, ElementFrame>{};
    // Text editing: a thin dashed box (03 §3.1).
    final editing = c.editor.textEditing;
    for (final MapEntry(key: id, value: f) in frames.entries) {
      // Lines and connectors: the outline follows the route (a box around
      // an elbow connector looked like a second, closed route).
      final route = c.selectedLineRoute(id);
      if (route != null) {
        canvas.drawPath(
          Path()..addPolygon([for (final p in route) v.toViewport(p)], false),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = tokens.selection,
        );
        continue;
      }
      _frameOutline(
        canvas,
        f,
        tokens.selection,
        editing ? 1 : 1.5,
        dashed: editing,
      );
    }
    final box = c.selectionBox();
    if (box != null && frames.length > 1) {
      _frameOutline(canvas, box, tokens.selection, 1);
    }
    if (box != null && c.selection.selected.any((e) => e.locked)) {
      _lockBadge(canvas, box);
    }
    _adjustPreview(canvas);
    _lineEndPreview(canvas);
    if (chrome) {
      for (final h in c.handles()) {
        _handle(canvas, h, box);
      }
    }
    final t = c.transform;
    if (t != null) {
      for (final g in t.guides) {
        _snapGuide(canvas, g);
      }
      for (final s in t.spacings) {
        _spacing(canvas, s);
      }
      for (final m in t.sizes) {
        _sizeMatch(canvas, m);
      }
      if (t.changed) _badge(canvas, t);
    }
    paintToolPreview(canvas, c, tokens);
    for (final i in modes) {
      i.paint(canvas, tokens);
    }
    final m = c.selection.marquee;
    if (m != null) {
      final r = v.rectToViewport(m);
      canvas.drawRect(r, Paint()..color = tokens.marqueeFill);
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = tokens.selection,
      );
    }
  }

  // ------------------------------------------------------------- pieces

  void _userGuides(Canvas canvas, Size size) {
    final v = c.viewport;
    final p = Paint()
      ..color = tokens.userGuide
      ..strokeWidth = 1;
    final moving = c.guide?.index;
    for (final (i, g) in guides.indexed) {
      if (i == moving) continue;
      if (g.axis == GuideAxis.vertical) {
        final x = v.toViewport(Offset(g.at, 0)).dx.roundToDouble() + 0.5;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      } else {
        final y = v.toViewport(Offset(0, g.at)).dy.roundToDouble() + 0.5;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
    }
  }

  void _guidePreview(Canvas canvas, Size size, GuidePreview g) {
    final v = c.viewport;
    final p = Paint()
      ..color = g.remove
          ? tokens.userGuide.withValues(alpha: 0.35)
          : tokens.userGuide
      ..strokeWidth = 1.5;
    if (g.axis == GuideAxis.vertical) {
      final x = v.toViewport(Offset(g.at, 0)).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      if (!g.remove) {
        _label(canvas, Offset(x, 30), _fmt(g.at), color: tokens.userGuide);
      }
    } else {
      final y = v.toViewport(Offset(0, g.at)).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      if (!g.remove) {
        _label(canvas, Offset(36, y), _fmt(g.at), color: tokens.userGuide);
      }
    }
  }

  List<Offset> _corners(ElementFrame f) {
    final v = c.viewport;
    return [
      for (final h in const [
        ResizeHandle.topLeft,
        ResizeHandle.topRight,
        ResizeHandle.bottomRight,
        ResizeHandle.bottomLeft,
      ])
        () {
          final (x, y) = FrameTransforms.handlePoint(f, h);
          return v.toViewport(Offset(x, y));
        }(),
    ];
  }

  void _frameOutline(
    Canvas canvas,
    ElementFrame f,
    Color color,
    double width, {
    bool dashed = false,
  }) {
    final pts = _corners(f);
    final path = Path()..addPolygon(pts, true);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
      }
    }
  }

  void _handle(Canvas canvas, CanvasHandle h, ElementFrame? box) {
    final fill = Paint()..color = tokens.handleFill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = tokens.selection;
    final p = h.position;
    switch (h.kind) {
      case CanvasHandleKind.resize:
        final r = Rect.fromCenter(center: p, width: 8, height: 8);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(h.rotation * math.pi / 180);
        canvas.translate(-p.dx, -p.dy);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, stroke);
        canvas.restore();
      case CanvasHandleKind.rotate:
        if (box != null) {
          final (tx, ty) = FrameTransforms.handlePoint(box, ResizeHandle.top);
          final top = c.viewport.toViewport(Offset(tx, ty));
          canvas.drawLine(top, p, stroke..strokeWidth = 1);
          stroke.strokeWidth = 1.5;
        }
        canvas.drawCircle(p, 5, fill);
        canvas.drawCircle(p, 5, stroke);
      case CanvasHandleKind.adjust:
        final d = Path()
          ..moveTo(p.dx, p.dy - 5)
          ..lineTo(p.dx + 5, p.dy)
          ..lineTo(p.dx, p.dy + 5)
          ..lineTo(p.dx - 5, p.dy)
          ..close();
        canvas.drawPath(d, Paint()..color = tokens.adjustHandle);
        canvas.drawPath(
          d,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = tokens.handleFill,
        );
      case CanvasHandleKind.lineStart || CanvasHandleKind.lineEnd:
        canvas.drawCircle(p, 5, fill);
        canvas.drawCircle(p, 5, stroke);
    }
  }

  void _lockBadge(Canvas canvas, ElementFrame box) {
    final (x, y) = FrameTransforms.handlePoint(box, ResizeHandle.topRight);
    final at = c.viewport.toViewport(Offset(x, y)) + const Offset(6, -16);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(at.dx, at.dy + 5, 10, 8),
      const Radius.circular(1.5),
    );
    final p = Paint()..color = tokens.lockBadge;
    canvas.drawRRect(body, p);
    canvas.drawArc(
      Rect.fromLTWH(at.dx + 2, at.dy, 6, 10),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = tokens.lockBadge,
    );
  }

  Paint get _guidePaint => Paint()
    ..color = tokens.guide
    ..strokeWidth = 1;

  void _snapGuide(Canvas canvas, SnapGuide g) {
    final v = c.viewport;
    Offset pt(double along) => g.axis == SnapAxis.x
        ? v.toViewport(Offset(g.at, along))
        : v.toViewport(Offset(along, g.at));
    final a = pt(g.from), b = pt(g.to);
    final paint = _guidePaint;
    if (g.dashed) {
      final len = (b - a).distance;
      if (len == 0) return;
      final dir = (b - a) / len;
      for (var d = 0.0; d < len; d += 10) {
        canvas.drawLine(a + dir * d, a + dir * math.min(d + 5, len), paint);
      }
    } else {
      canvas.drawLine(a, b, paint);
    }
    for (final m in g.marks) {
      final p = pt(m);
      canvas.drawLine(p + const Offset(-3, -3), p + const Offset(3, 3), paint);
      canvas.drawLine(p + const Offset(-3, 3), p + const Offset(3, -3), paint);
    }
  }

  void _spacing(Canvas canvas, SpacingGuide s) {
    final v = c.viewport;
    final paint = _guidePaint..strokeWidth = 1;
    for (final g in s.gaps) {
      final (a, b) = s.axis == SnapAxis.x
          ? (
              v.toViewport(Offset(g.start, g.cross)),
              v.toViewport(Offset(g.end, g.cross)),
            )
          : (
              v.toViewport(Offset(g.cross, g.start)),
              v.toViewport(Offset(g.cross, g.end)),
            );
      canvas.drawLine(a, b, paint);
      final n = s.axis == SnapAxis.x ? const Offset(0, 4) : const Offset(4, 0);
      canvas.drawLine(a - n, a + n, paint);
      canvas.drawLine(b - n, b + n, paint);
      _label(canvas, (a + b) / 2, _fmt(s.distance));
    }
  }

  void _sizeMatch(Canvas canvas, SizeMatch m) {
    final r = c.viewport.rectToViewport(m.rect);
    final paint = _guidePaint;
    if (m.axis == SnapAxis.x) {
      final y = r.bottom + 6;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), paint);
      canvas.drawLine(Offset(r.left, y - 3), Offset(r.left, y + 3), paint);
      canvas.drawLine(Offset(r.right, y - 3), Offset(r.right, y + 3), paint);
    } else {
      final x = r.right + 6;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), paint);
      canvas.drawLine(Offset(x - 3, r.top), Offset(x + 3, r.top), paint);
      canvas.drawLine(Offset(x - 3, r.bottom), Offset(x + 3, r.bottom), paint);
    }
  }

  void _adjustPreview(Canvas canvas) {
    final a = c.adjust;
    if (a == null) return;
    final e = c.elements?[a.elementId];
    if (e == null) return;
    final raw = e.data?['adjust'];
    final data = {
      ...?e.data,
      'adjust': {
        ...?(raw is Map ? raw.cast<String, Object?>() : null),
        a.key: a.value,
      },
    };
    final f = a.frame;
    final outline = ShapeLibrary.outlineOf(data, f.width, f.height);
    final path = SlideScenePainter.pathOf(outline.mainPath);
    final v = c.viewport;
    canvas.save();
    final o = v.toViewport(Offset(f.cx, f.cy));
    canvas.translate(o.dx, o.dy);
    canvas.scale(v.scale);
    canvas.rotate(f.rotation * math.pi / 180);
    canvas.scale(f.flipH ? -1 : 1, f.flipV ? -1 : 1);
    canvas.translate(-f.width / 2, -f.height / 2);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / v.scale
        ..color = tokens.adjustHandle,
    );
    canvas.restore();
  }

  void _lineEndPreview(Canvas canvas) {
    final l = c.lineEnd;
    if (l == null) return;
    final v = c.viewport;
    final a = v.toViewport(l.fixed), b = v.toViewport(l.moving);
    final paint = Paint()
      ..color = tokens.selection
      ..strokeWidth = 1.5;
    final len = (b - a).distance;
    if (len > 0) {
      final dir = (b - a) / len;
      for (var d = 0.0; d < len; d += 8) {
        canvas.drawLine(a + dir * d, a + dir * math.min(d + 4, len), paint);
      }
    }
    for (final g in l.guides) {
      _snapGuide(canvas, g);
    }
    final site = l.site;
    if (site != null) {
      final p = v.toViewport(Offset(site.x, site.y));
      canvas.drawCircle(
        p,
        7,
        Paint()..color = tokens.guide.withValues(alpha: 0.25),
      );
      canvas.drawCircle(p, 4, Paint()..color = tokens.guide);
    }
  }

  void _badge(Canvas canvas, TransformSession t) {
    final l = labels ?? CanvasOverlayLabels.fallback;
    final b = t.liveBox;
    final one = t.frames.length == 1 ? t.liveFrames.values.single : null;
    final text = switch (t.kind) {
      TransformKind.move => l.position(b.x.round(), b.y.round()),
      TransformKind.rotate => l.angle((one?.rotation ?? t.angle).round()),
      TransformKind.resize => l.dimensions(
        (one?.width ?? b.width).round(),
        (one?.height ?? b.height).round(),
      ),
    };
    final r = c.viewport.rectToViewport(b);
    _label(canvas, Offset(r.center.dx, r.bottom + 18), text, accent: false);
  }

  static String _fmt(double v) {
    final r = (v * 10).roundToDouble() / 10;
    return r == r.roundToDouble() ? '${r.toInt()}' : '$r';
  }

  void _label(
    Canvas canvas,
    Offset center,
    String text, {
    bool accent = true,
    Color? color,
  }) {
    final bg = color ?? (accent ? tokens.guide : tokens.selection);
    final pb =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(fontSize: 11, textAlign: TextAlign.center),
          )
          ..pushStyle(ui.TextStyle(color: tokens.labelText, fontSize: 11))
          ..addText(text);
    final para = pb.build()..layout(const ui.ParagraphConstraints(width: 200));
    final w = para.maxIntrinsicWidth + 8, h = para.height + 2;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: w, height: h),
      const Radius.circular(3),
    );
    canvas.drawRRect(r, Paint()..color = bg);
    canvas.drawParagraph(
      para,
      Offset(center.dx - 100, center.dy - para.height / 2),
    );
  }

  @override
  bool shouldRepaint(CanvasOverlayPainter old) =>
      !identical(old.c, c) ||
      old.tokens != tokens ||
      old.showGuides != showGuides ||
      old.guides != guides;
}
