import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:wonky_slides_core/motion.dart';

import '../motion/render/motion_masks.dart';
import 'gpu/gpu_transitions.dart';

/// Paints a snapshot transition frame (06 §7.2, §12.2): the outgoing and
/// incoming slides' snapshots as [TransitionQuad]s back to front — slide-
/// space transforms (3D types carry the perspective entry; the canvas
/// does the projective divide), regions (doorway halves), wipe/iris clips,
/// dissolves, shading toward black and opacity — over the *fade through*
/// backdrop. The canvas is in logical pixels; the slide is at [origin]
/// scaled by [scale] (px per su). Content may leave the slide rect (3D
/// types): the letterbox behind shows where nothing is drawn.
class TransitionPainter extends CustomPainter {
  TransitionPainter({
    required this.frame,
    required this.outgoing,
    required this.incoming,
    required this.slideWidth,
    required this.slideHeight,
    required this.origin,
    required this.scale,
    this.gpu = false,
    this.pixelRatio = 1,
  });

  final TransitionFrame frame;

  /// Draw with the GPU renderer when it is ready (3D types, 06 §12.3).
  final bool gpu;
  final double pixelRatio;
  final ui.Image? outgoing, incoming;
  final double slideWidth, slideHeight;
  final Offset origin;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (gpu &&
        GpuTransitions.instance.paint(
          canvas,
          size,
          frame: frame,
          outgoing: outgoing,
          incoming: incoming,
          slideWidth: slideWidth,
          slideHeight: slideHeight,
          origin: origin,
          scale: scale,
          pixelRatio: pixelRatio,
        )) {
      return;
    }
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    final slide = Rect.fromLTWH(0, 0, slideWidth, slideHeight);
    final backdrop = frame.backdrop;
    if (backdrop != null) {
      canvas.drawRect(slide, Paint()..color = Color(backdrop));
    }
    for (final q in frame.quads) {
      if (!q.visible || q.opacity <= 0) continue;
      final image = q.layer == TransitionLayer.outgoing ? outgoing : incoming;
      if (image == null) continue;
      paintQuad(canvas, image, q, slide);
    }
    canvas.restore();
  }

  /// Paints [image] (the whole slide) as quad [q] in slide units.
  static void paintQuad(
    Canvas canvas,
    ui.Image image,
    TransitionQuad q,
    Rect slide,
  ) {
    final r = q.region;
    final region = r == null
        ? slide
        : Rect.fromLTWH(r.x, r.y, r.width, r.height);
    final mask = MotionMask.of(region, clip: q.clip, dissolve: q.dissolve);
    if (mask != null && mask.hidesAll) return;
    canvas.save();
    canvas.transform(q.transform.storage);
    final kx = image.width / slide.width, ky = image.height / slide.height;
    final src = Rect.fromLTRB(
      region.left * kx,
      region.top * ky,
      region.right * kx,
      region.bottom * ky,
    );
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true
      ..color = Color.fromRGBO(0, 0, 0, q.opacity.clamp(0.0, 1.0));
    if (q.shade > 0) {
      paint.colorFilter = ColorFilter.mode(
        Color.fromRGBO(0, 0, 0, q.shade.clamp(0.0, 1.0)),
        BlendMode.srcATop,
      );
    }
    if (mask != null) {
      mask.clip(canvas);
      if (mask.needsLayer) canvas.saveLayer(mask.layerBounds, Paint());
    }
    canvas.drawImageRect(image, src, region, paint);
    if (mask != null && mask.needsLayer) {
      mask.paintMask(canvas);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(TransitionPainter old) =>
      !identical(old.frame, frame) ||
      !identical(old.outgoing, outgoing) ||
      !identical(old.incoming, incoming) ||
      old.origin != origin ||
      old.scale != scale;
}

/// The degraded crossfade of two snapshots (06 §14).
class CrossfadePainter extends CustomPainter {
  CrossfadePainter({
    required this.from,
    required this.to,
    required this.mix,
    required this.slideWidth,
    required this.slideHeight,
    required this.origin,
    required this.scale,
  });

  final ui.Image? from, to;
  final double mix;
  final double slideWidth, slideHeight;
  final Offset origin;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      slideWidth * scale,
      slideHeight * scale,
    );
    void draw(ui.Image? i, double a) {
      if (i == null || a <= 0) return;
      canvas.drawImageRect(
        i,
        Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble()),
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0)),
      );
    }

    draw(from, 1);
    draw(to, mix);
  }

  @override
  bool shouldRepaint(CrossfadePainter old) =>
      old.mix != mix ||
      !identical(old.from, from) ||
      !identical(old.to, to) ||
      old.origin != origin ||
      old.scale != scale;
}
