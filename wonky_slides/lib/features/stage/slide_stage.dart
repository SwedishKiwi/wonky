import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart'
    show Chart3DBackends;
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart';

import '../motion/render/frame_diff.dart';
import 'scene_painter.dart';
import 'slide_image_cache.dart';

/// Renders one slide scene at a target size with a [SlideFrame] (06
/// §12.1): shared by the editor canvas, thumbnails (via pictures),
/// presenting and previews.
///
/// The background is one layer; every top-level scene node (an element, a
/// master/layout decoration) gets its own `RepaintBoundary`, so a change to
/// one element — or an animating element — repaints only that layer.
/// Element visual states of [frame] (visibility, opacity, transform, blur)
/// are applied per element. The slide renders as designed in the deck's
/// appearance, independent of the app theme (03 §2.1).
class SlideStage extends StatelessWidget {
  const SlideStage({
    super.key,
    required this.scene,
    this.frame = SlideFrame.edit,
    this.images,
    this.scale,
    this.clipToSlide = true,
    this.offSlideOpacity,
    this.drawPrompts = false,
    this.placeholderBorder = const Color(0x8094a3b8),
    this.semanticLabel,
  });

  /// The scene to draw.
  final SlideScene scene;

  /// Element visual states (the edit frame by default; the timeline's
  /// frames when presenting, 06 §9).
  final SlideFrame frame;

  /// Decoded images (null = images are not drawn).
  final SlideImageCache? images;

  /// Logical pixels per su; null fits the slide into the constraints.
  final double? scale;

  /// Whether content is clipped to the slide (presenting, thumbnails).
  final bool clipToSlide;

  /// When not clipping: the opacity of content outside the slide (the
  /// editor's pasteboard draws it at 40 %, 03 §2.1); null = full.
  final double? offSlideOpacity;

  /// Whether prompts of empty placeholders are drawn (editor only).
  final bool drawPrompts;

  /// Dashed outline color of empty placeholders.
  final Color placeholderBorder;

  /// Semantics label of the slide image.
  final String? semanticLabel;

  /// The scale that fits [scene] into [size].
  static double fitScale(SlideScene scene, Size size) {
    if (scene.width <= 0 || scene.height <= 0) return 1;
    final s = size.width / scene.width;
    final t = size.height / scene.height;
    if (!s.isFinite && !t.isFinite) return 1;
    if (!s.isFinite) return t;
    if (!t.isFinite) return s;
    return s < t ? s : t;
  }

  @override
  Widget build(BuildContext context) {
    if (scale != null) return _stage(context, scale!);
    return LayoutBuilder(
      builder: (context, c) =>
          _stage(context, fitScale(scene, Size(c.maxWidth, c.maxHeight))),
    );
  }

  Widget _stage(BuildContext context, double s) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final options = ScenePaintOptions(
      frame: frame,
      images: images,
      drawPrompts: drawPrompts,
      placeholderBorder: placeholderBorder,
      devicePixelRatio: dpr,
      gpuCharts: true,
      chartGpu: Chart3DBackends.active,
    );
    final size = Size(scene.width * s, scene.height * s);
    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _BackgroundPainter(scene.background, s, options),
            ),
          ),
        ),
        for (final (i, node) in scene.nodes.indexed)
          Positioned.fill(
            key: ValueKey(node.elementId ?? 'decoration:$i'),
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _NodePainter(
                  node,
                  s,
                  options,
                  slide: Rect.fromLTWH(0, 0, scene.width, scene.height),
                  offSlideOpacity: clipToSlide ? null : offSlideOpacity,
                ),
              ),
            ),
          ),
      ],
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox.fromSize(
        size: size,
        child: clipToSlide ? ClipRect(child: stack) : stack,
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.background, this.scale, this.options)
    : super(repaint: options.images);

  final ResolvedBackground background;
  final double scale;
  final ScenePaintOptions options;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    SlideScenePainter.paintBackground(
      canvas,
      background,
      Rect.fromLTWH(0, 0, size.width / scale, size.height / scale),
      options,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      !identical(old.background, background) || old.scale != scale;
}

class _NodePainter extends CustomPainter {
  _NodePainter(
    this.node,
    this.scale,
    this.options, {
    required this.slide,
    this.offSlideOpacity,
  }) : super(repaint: options.images);

  final SceneNode node;
  final double scale;
  final ScenePaintOptions options;
  final Rect slide;
  final double? offSlideOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    final off = offSlideOpacity;
    if (off != null && off < 1) {
      // Outside the slide at reduced opacity, inside at full.
      final outside = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(slide.inflate(1e5))
        ..addRect(slide);
      canvas.save();
      canvas.clipPath(outside);
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, off));
      SlideScenePainter.paintNode(canvas, node, options);
      canvas.restore();
      canvas.restore();
      canvas.save();
      canvas.clipRect(slide);
      SlideScenePainter.paintNode(canvas, node, options);
      canvas.restore();
    } else {
      SlideScenePainter.paintNode(canvas, node, options);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NodePainter old) =>
      !identical(old.node, node) ||
      old.scale != scale ||
      // Only elements whose frame state changed repaint (06 §12.1).
      !FrameDiff.sameFor(node, old.options.frame, options.frame) ||
      old.options.drawPrompts != options.drawPrompts ||
      !identical(old.options.chartGpu, options.chartGpu) ||
      old.options.placeholderBorder != options.placeholderBorder ||
      !identical(old.options.images, options.images) ||
      old.offSlideOpacity != offSlideOpacity;

  @override
  bool? hitTest(Offset position) => false;
}

/// Records [scene] into a picture at [scale] (thumbnails, snapshot
/// transitions, PNG export).
ui.Picture recordScene(
  SlideScene scene, {
  required double scale,
  SlideImageCache? images,
  SlideFrame frame = SlideFrame.edit,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  SlideScenePainter.paintScene(
    canvas,
    scene,
    scale: scale,
    options: ScenePaintOptions(frame: frame, images: images),
  );
  return recorder.endRecording();
}
