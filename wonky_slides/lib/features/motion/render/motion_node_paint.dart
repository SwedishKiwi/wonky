import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Matrix4;
import 'package:wonky_code_flutter/wonky_code_flutter.dart' show oklabLerp;
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart';

import '../../stage/scene_painter.dart';
import 'motion_masks.dart';

/// The parts of the stage painter that apply an element's animated state
/// to its nodes (06 §12.1) beyond transform, opacity and blur: wipe/iris
/// clips and dissolves of the whole element (incl. its shadow), color
/// changes of fills and strokes, line drawing (`drawProgress`,
/// `fillOpacity`), and the box opacity of text built in parts.
abstract final class MotionNodePaint {
  // ------------------------------------------------------------------
  // Element masks

  /// The wipe/iris/dissolve mask of element group [g] in [state], in the
  /// group's local space (its unrotated box), or null.
  static MotionMask? groupMask(GroupNode g, ElementVisualState state) {
    if (state.clip == null && state.dissolve == null) return null;
    return MotionMask.of(boxOf(g), clip: state.clip, dissolve: state.dissolve);
  }

  static final Expando<Rect> _boxes = Expando('elementBox');

  /// The local box of element group [g]: the union of its children's
  /// bounds, from the local origin for elements placed by their frame.
  static Rect boxOf(GroupNode g) => _boxes[g] ??= () {
    var r = childrenBounds(g.children);
    if (!_isIdentity(g.transform)) {
      r = r.expandToInclude(Rect.fromLTWH(0, 0, 0, 0));
    }
    return r;
  }();

  /// The bounds of [nodes] in their parent's space.
  static Rect childrenBounds(List<SceneNode> nodes) {
    Rect? r;
    void add(Rect b) => r = r == null ? b : r!.expandToInclude(b);
    for (final n in nodes) {
      switch (n) {
        case GroupNode():
          final b = childrenBounds(n.children);
          if (b.isEmpty && b.width == 0 && b.height == 0) continue;
          add(
            _isIdentity(n.transform)
                ? b
                : MatrixUtils.transformRect(n.transform, b),
          );
        case PathNode():
          final b = SlideScenePainter.pathOf(n.path).getBounds();
          add(b.inflate((n.stroke?.width ?? 0) / 2));
        case TextNode():
          add(
            Rect.fromLTWH(
              n.originX,
              n.originY,
              n.layout.width,
              n.layout.height,
            ),
          );
        case ImageNode(:final dst):
          add(Rect.fromLTWH(dst.x, dst.y, dst.width, dst.height));
        case ChartNode(:final dst):
          add(Rect.fromLTWH(dst.x, dst.y, dst.width, dst.height));
        case CodeNode(:final dst):
          add(Rect.fromLTWH(dst.x, dst.y, dst.width, dst.height));
        case PromptNode(:final box):
          add(Rect.fromLTWH(box.x, box.y, box.width, box.height));
      }
    }
    return r ?? Rect.zero;
  }

  // ------------------------------------------------------------------
  // Paths

  /// Whether [state] changes how a path node is painted.
  static bool handlesPath(ElementVisualState state) =>
      state.drawProgress < 1 ||
      state.fillOpacity < 1 ||
      state.colors.containsKey('fill') ||
      state.colors.containsKey('stroke') ||
      (state.parts != null && state.parts!.backgroundOpacity < 1);

  /// Paints path node [n] with [state]; [fillPath] fills a path with a
  /// resolved fill (the stage's fill painter).
  static void paintPath(
    Canvas canvas,
    PathNode n,
    ElementVisualState state, {
    required void Function(Canvas, Path, ResolvedFill, Rect) fillPath,
    required Path Function(PathNode) strokePath,
  }) {
    final path = SlideScenePainter.pathOf(n.path);
    final bg = state.parts?.backgroundOpacity ?? 1;
    if (bg <= 0) return;
    final layered = bg < 1;
    final bounds = path.getBounds().inflate((n.stroke?.width ?? 0) + 2);
    if (layered) {
      canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, bg));
    }
    final fill = n.fill;
    final fillOpacity = state.fillOpacity.clamp(0.0, 1.0);
    if (fill != null && fillOpacity > 0) {
      final o = state.colors['fill'];
      final f = o == null ? fill : recolorFill(fill, o);
      if (fillOpacity < 1) {
        canvas.saveLayer(
          bounds,
          Paint()..color = Color.fromRGBO(0, 0, 0, fillOpacity),
        );
        fillPath(canvas, path, f, path.getBounds());
        canvas.restore();
      } else {
        fillPath(canvas, path, f, path.getBounds());
      }
    }
    var s = n.stroke;
    final draw = state.drawProgress.clamp(0.0, 1.0);
    if (s == null && draw < 1 && fill != null) {
      // Line drawing of a shape without an outline: draw it with the fill
      // color while the fill fades in.
      final c = switch (fill) {
        ResolvedSolidFill(:final color) => color,
        ResolvedGradientFill(:final stops) =>
          stops.isEmpty ? 0xff000000 : stops.first.$2,
        _ => 0xff000000,
      };
      s = NodeStroke(width: 3, color: c);
    }
    if (s != null && s.width > 0 && (s.color >>> 24) != 0) {
      final so = state.colors['stroke'];
      final paint = SlideScenePainter.strokePaint(s);
      if (so != null) paint.color = Color(blend(s.color, so));
      if (draw <= 0) {
        // Nothing drawn yet.
      } else if (draw < 1) {
        canvas.drawPath(
          partialPath(path, draw, reverse: state.drawReverse),
          paint,
        );
      } else {
        canvas.drawPath(strokePath(n), paint);
      }
    }
    if (layered) canvas.restore();
  }

  /// The first [fraction] of [path]'s length (from its end when
  /// [reverse]).
  static Path partialPath(Path path, double fraction, {bool reverse = false}) {
    final out = Path();
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    var left = total * fraction;
    final ordered = reverse ? metrics.reversed : metrics;
    for (final m in ordered) {
      if (left <= 0) break;
      final len = math.min(m.length, left);
      out.addPath(
        reverse
            ? m.extractPath(m.length - len, m.length)
            : m.extractPath(0, len),
        Offset.zero,
      );
      left -= len;
    }
    return out;
  }

  /// [authored] blended toward the override (OKLab).
  static int blend(int authored, ColorOverride o) =>
      oklabLerp(o.from ?? authored, o.to, o.mix.clamp(0.0, 1.0));

  /// [fill] recolored by [o]: solid fills blend; gradient stops blend
  /// toward the target.
  static ResolvedFill recolorFill(ResolvedFill fill, ColorOverride o) =>
      switch (fill) {
        ResolvedSolidFill(:final color) => ResolvedSolidFill(blend(color, o)),
        ResolvedGradientFill() => ResolvedGradientFill(
          kind: fill.kind,
          angle: fill.angle,
          centerX: fill.centerX,
          centerY: fill.centerY,
          radius: fill.radius,
          stops: [for (final (p, c) in fill.stops) (p, blend(c, o))],
        ),
        _ => fill,
      };

  // ------------------------------------------------------------------
  // Helpers

  static bool _isIdentity(Matrix4 m) {
    final s = m.storage;
    for (var i = 0; i < 16; i++) {
      if (s[i] != (i % 5 == 0 ? 1.0 : 0.0)) return false;
    }
    return true;
  }

  /// A blur image filter for [sigma] su (capped at 40 su, 06 §14).
  static ui.ImageFilter? blurFilter(double sigma) {
    if (sigma <= 0) return null;
    final s = math.min(sigma, 40.0);
    return ui.ImageFilter.blur(sigmaX: s, sigmaY: s);
  }
}
