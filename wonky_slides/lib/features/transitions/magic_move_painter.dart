import 'package:flutter/rendering.dart';
import 'package:wonky_charts/wonky_charts.dart'
    show ChartScene, ChartSceneMorph;
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';

import '../motion/player/motion_budget.dart';
import '../stage/scene_painter.dart';
import '../stage/slide_image_cache.dart';

/// Paints a Magic Move frame live (06 §8, §12.2; SL-25's frame contract):
/// both slides' scenes with their frame states in the frame's layer order
/// — backgrounds (the incoming one crossfading), layout/master
/// decorations, then every element at its paint rank — clipped to the
/// slide. Pair refinements the states can't express are applied to the
/// incoming scene first ([MagicMoveScenes.refine]: morphed outlines, image
/// crops). Element opacity products are clamped by the stage painter.
class MagicMovePainter extends CustomPainter {
  MagicMovePainter({
    required this.frame,
    required this.from,
    required this.to,
    required this.origin,
    required this.scale,
    this.images,
    this.devicePixelRatio = 1,
  });

  final MagicMoveFrame frame;

  /// The outgoing and incoming slides' scenes (code/chart nodes already
  /// recomposed for their frames).
  final SlideScene from, to;
  final Offset origin;
  final double scale;
  final SlideImageCache? images;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    final slide = Rect.fromLTWH(0, 0, to.width, to.height);
    canvas.clipRect(slide);
    final outOptions = ScenePaintOptions(
      frame: frame.outgoing,
      images: images,
      devicePixelRatio: devicePixelRatio,
    );
    final inOptions = ScenePaintOptions(
      frame: frame.incoming,
      images: images,
      devicePixelRatio: devicePixelRatio,
    );
    final fromNodes = _byId(from);
    final toNodes = _byId(to);
    for (final layer in frame.layers) {
      final out = layer.side == MagicMoveSide.from;
      final scene = out ? from : to;
      final options = out ? outOptions : inOptions;
      final id = layer.elementId;
      if (id == null) {
        final opacity = out ? 1.0 : frame.incoming.background.opacity;
        _background(canvas, scene, slide, options, opacity);
        // Decorations without an element id belong to the background.
        for (final n in scene.nodes) {
          if (n.elementId == null) {
            _withOpacity(canvas, slide, opacity, () {
              SlideScenePainter.paintNode(canvas, n, options);
            });
          }
        }
        continue;
      }
      final node = (out ? fromNodes : toNodes)[id];
      if (node == null) continue;
      SlideScenePainter.paintNode(canvas, node, options);
    }
    canvas.restore();
  }

  static final Expando<Map<String, SceneNode>> _index = Expando('mmNodes');

  static Map<String, SceneNode> _byId(SlideScene scene) => _index[scene] ??= {
    for (final n in scene.nodes)
      if (n.elementId != null) n.elementId!: n,
  };

  static void _background(
    Canvas canvas,
    SlideScene scene,
    Rect slide,
    ScenePaintOptions options,
    double opacity,
  ) {
    if (opacity <= 0) return;
    _withOpacity(canvas, slide, opacity, () {
      SlideScenePainter.paintBackground(
        canvas,
        scene.background,
        slide,
        options,
      );
    });
  }

  static void _withOpacity(
    Canvas canvas,
    Rect bounds,
    double opacity,
    void Function() draw,
  ) {
    if (opacity <= 0) return;
    if (opacity >= 1) {
      draw();
      return;
    }
    canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    draw();
    canvas.restore();
  }

  @override
  bool shouldRepaint(MagicMovePainter old) =>
      !identical(old.frame, frame) ||
      !identical(old.from, from) ||
      !identical(old.to, to) ||
      old.origin != origin ||
      old.scale != scale;
}

/// Pair refinements of a Magic Move frame on the incoming scene (06 §8.4):
/// a `path` pair draws its morphed outline instead of the incoming
/// element's body; an image pair with the same file shows the interpolated
/// crop. (Code token glyphs across two elements and chart scene morphs
/// crossfade — the frame states already say so.)
abstract final class MagicMoveScenes {
  static SlideScene refine(SlideScene to, MagicMoveFrame frame) {
    if (frame.pairs.isEmpty) return to;
    var changed = false;
    SceneNode swap(SceneNode n, MorphPairState? pair) {
      switch (n) {
        case GroupNode():
          final id = n.elementId;
          final p = id == null ? pair : (frame.pairs[id] ?? pair);
          if (p == null || (p.path == null && p.crop == null)) {
            if (id != null && frame.pairs[id] == null && pair == null) {
              // Nested matched children are refined on their own.
              final kids = [for (final k in n.children) swap(k, null)];
              if (!_same(kids, n.children)) {
                changed = true;
                return _group(n, kids);
              }
            }
            return n;
          }
          var pathDone = false;
          final kids = <SceneNode>[];
          for (final k in n.children) {
            if (!pathDone && p.path != null && k is PathNode) {
              pathDone = true;
              kids.add(
                PathNode(
                  elementId: k.elementId,
                  path: p.path!,
                  fill: k.fill,
                  stroke: k.stroke,
                  effects: k.effects,
                ),
              );
            } else if (p.crop != null && k is ImageNode) {
              kids.add(_cropped(k, p.crop!));
            } else {
              kids.add(swap(k, p));
            }
          }
          changed = true;
          return _group(n, kids);
        case ImageNode() when pair?.crop != null:
          changed = true;
          return _cropped(n, pair!.crop!);
        default:
          return n;
      }
    }

    final nodes = [for (final n in to.nodes) swap(n, null)];
    if (!changed) return to;
    return SlideScene(
      slideId: to.slideId,
      width: to.width,
      height: to.height,
      background: to.background,
      nodes: nodes,
      frames: to.frames,
      routes: to.routes,
    );
  }

  static bool _same(List<SceneNode> a, List<SceneNode> b) {
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  static GroupNode _group(GroupNode n, List<SceneNode> kids) => GroupNode(
    elementId: n.elementId,
    transform: n.transform,
    opacity: n.opacity,
    clip: n.clip,
    effects: n.effects,
    children: kids,
  );

  static ImageNode _cropped(ImageNode n, Map<String, double> crop) {
    final iw = (n.image.naturalWidth ?? 1).toDouble();
    final ih = (n.image.naturalHeight ?? 1).toDouble();
    double v(String k, double d) => crop[k] ?? d;
    return ImageNode(
      elementId: n.elementId,
      image: n.image,
      src: SuRect(
        v('x', 0) * iw,
        v('y', 0) * ih,
        (v('w', 1) * iw).clamp(1e-6, double.infinity),
        (v('h', 1) * ih).clamp(1e-6, double.infinity),
      ),
      dst: n.dst,
      colorMatrix: n.colorMatrix,
      mask: n.mask,
      blurSigma: n.blurSigma,
    );
  }
}

/// Chart pairs of a Magic Move with the same source and different data
/// (`MorphPair.chartMorph`, 06 §8.4, 08 §9.4): instead of crossfading the
/// two chart drawings, the incoming chart node shows the
/// [ChartSceneMorph] of both scenes at the pair's progress at full
/// opacity, and the outgoing chart is hidden.
abstract final class MagicMoveCharts {
  static final Expando<Map<String, ChartSceneMorph>> _morphs = Expando(
    'chartMorphs',
  );

  /// [frame] and the incoming scene [to] with chart morphs applied (the
  /// same objects when no pair morphs a chart).
  static (MagicMoveFrame, SlideScene) apply(
    MagicMovePlan plan,
    MagicMoveFrame frame,
    SlideScene from,
    SlideScene to,
  ) {
    final pairs = [
      for (final p in plan.pairs)
        if (p.chartMorph) p,
    ];
    if (pairs.isEmpty) return (frame, to);
    final cache = _morphs[plan] ??= {};
    final outStates = Map.of(frame.outgoing.elements);
    final inStates = Map.of(frame.incoming.elements);
    final swaps = <String, ChartScene>{};
    for (final p in pairs) {
      final a = _chartOf(from, p.from.id), b = _chartOf(to, p.to.id);
      final st = frame.pairs[p.to.id];
      if (a == null || b == null || st == null) continue;
      final m = cache[p.to.id] ??= ChartSceneMorph(a.scene, b.scene);
      swaps[p.to.id] = m.at(st.progress);
      outStates[p.from.id] = ElementVisualState(visible: false);
      final s = inStates[p.to.id];
      if (s != null) {
        final aOp = p.from.opacity, bOp = p.to.opacity;
        final op = bOp <= 0 ? 1.0 : (aOp + (bOp - aOp) * st.progress) / bOp;
        inStates[p.to.id] = MotionBudget.withOpacity(s, op);
      }
    }
    if (swaps.isEmpty) return (frame, to);
    SceneNode swap(SceneNode n, String? owner) {
      switch (n) {
        case ChartNode():
          final id = n.elementId ?? owner;
          final s = id == null ? null : swaps[id];
          return s == null
              ? n
              : ChartNode(elementId: n.elementId, scene: s, dst: n.dst);
        case GroupNode():
          final id = n.elementId ?? owner;
          return GroupNode(
            elementId: n.elementId,
            transform: n.transform,
            opacity: n.opacity,
            clip: n.clip,
            effects: n.effects,
            children: [for (final k in n.children) swap(k, id)],
          );
        default:
          return n;
      }
    }

    final scene = SlideScene(
      slideId: to.slideId,
      width: to.width,
      height: to.height,
      background: to.background,
      nodes: [
        for (final n in to.nodes)
          swaps.keys.contains(n.elementId) ? swap(n, null) : n,
      ],
      frames: to.frames,
      routes: to.routes,
    );
    return (
      MagicMoveFrame(
        progress: frame.progress,
        outgoing: SlideFrame(outStates, frame.outgoing.background),
        incoming: SlideFrame(inStates, frame.incoming.background),
        layers: frame.layers,
        pairs: frame.pairs,
      ),
      scene,
    );
  }

  static ChartNode? _chartOf(SlideScene scene, String id) {
    for (final n in scene.nodesOf(id)) {
      if (n is ChartNode) return n;
      if (n is GroupNode) {
        for (final c in n.children) {
          if (c is ChartNode) return c;
        }
      }
    }
    return null;
  }
}
