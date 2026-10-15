import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';

import '../../elements/code/code_frames.dart';
import '../../stage/slide_renderer.dart';

/// Builds a slide scene for one timeline frame (06 §9.2, §12.1): what a
/// frame says about content that the static scene can't show by painting
/// alone — code elements at a state/step/typing moment (SL-31's
/// [CodeFrames]) and charts at a reveal/highlight/camera moment
/// ([SlideChartLayout.build] with `SlideChartMotion.reveal/view/fitViews`,
/// SL-27; drawn when the renderer's chart source is a [SlideChartLayout],
/// as SL-32 wires it). Everything else (transforms, opacity, clips, parts,
/// colors) is applied by the stage painter from the frame itself.
class MotionScenes {
  MotionScenes(this.renderer);

  final SlideRenderer renderer;

  DeckModel get _deck => renderer.model;

  /// [scene] with the code and chart nodes of [frame] recomposed; [scene]
  /// itself when the frame changes neither.
  SlideScene apply(
    SlideScene scene,
    SlideFrame frame, {
    bool reducedMotion = false,
  }) {
    if (frame.elements.isEmpty) return scene;
    var hasCode = false, hasChart = false;
    for (final s in frame.elements.values) {
      if (s.code != null ||
          s.codeStateIndex != null ||
          s.codeHighlightStep != null) {
        hasCode = true;
      }
      if (s.chart != null) hasChart = true;
    }
    if (!hasCode && !hasChart) return scene;
    final slide = renderer.resolver.resolve(scene.slideId);
    if (slide == null) return scene;
    var out = scene;
    if (hasCode) {
      out = CodeFrames.applyFrame(out, frame, (id) {
        final e = elementOf(slide, id);
        if (e == null || e.record.kind != ElementKind.code) return null;
        return CodeFrames.composerOf(slide, e, _deck);
      }, reducedMotion: reducedMotion);
    }
    if (hasChart) out = _charts(out, frame, slide);
    return out;
  }

  /// The resolved element [id] of [slide] (nested in groups too).
  static ResolvedElement? elementOf(ResolvedSlide slide, String id) {
    ResolvedElement? walk(List<ResolvedElement> list) {
      for (final e in list) {
        if (e.id == id) return e;
        final c = walk(e.children);
        if (c != null) return c;
      }
      return null;
    }

    return walk(slide.elements);
  }

  SlideScene _charts(SlideScene scene, SlideFrame frame, ResolvedSlide slide) {
    final source = renderer.charts;
    if (source is! SlideChartLayout) return scene;
    final background = slide.background.effectiveColor(
      slide.theme.colorOf('bg1') ?? 0xffffffff,
    );
    var changed = false;
    SceneNode swap(SceneNode n) {
      switch (n) {
        case ChartNode():
          final id = n.elementId;
          final state = id == null ? null : frame.elements[id]?.chart;
          if (state == null) return n;
          final e = elementOf(slide, id!);
          if (e == null) return n;
          final scene = _chartScene(source, e, slide, n, state, background);
          if (scene == null) return n;
          changed = true;
          return ChartNode(elementId: n.elementId, scene: scene, dst: n.dst);
        case GroupNode():
          final before = changed;
          changed = false;
          final kids = [for (final k in n.children) swap(k)];
          final mine = changed;
          changed = before || mine;
          if (!mine) return n;
          return GroupNode(
            elementId: n.elementId,
            transform: n.transform,
            opacity: n.opacity,
            clip: n.clip,
            effects: n.effects,
            children: kids,
          );
        default:
          return n;
      }
    }

    final nodes = [for (final n in scene.nodes) swap(n)];
    if (!changed) return scene;
    return SlideScene(
      slideId: scene.slideId,
      width: scene.width,
      height: scene.height,
      background: scene.background,
      nodes: nodes,
      frames: scene.frames,
      routes: scene.routes,
    );
  }

  ChartScene? _chartScene(
    SlideChartLayout source,
    ResolvedElement e,
    ResolvedSlide slide,
    ChartNode n,
    ChartRevealState state,
    int background,
  ) {
    final base = source.build(
      e.record,
      _deck,
      slide.theme,
      width: n.dst.width,
      height: n.dst.height,
      background: background,
    );
    if (base == null) return null;
    final spec = base.look.spec;
    final is3D = spec.threeD.appliesTo(spec.type);
    final reveal = SlideChartMotion.reveal(state);
    if (!is3D) {
      return source
          .build(
            e.record,
            _deck,
            slide.theme,
            width: n.dst.width,
            height: n.dst.height,
            background: background,
            reveal: reveal,
          )
          ?.scene;
    }
    final view0 = SlideChartMotion.baseView(base.data, spec);
    return source
        .build(
          e.record,
          _deck,
          slide.theme,
          width: n.dst.width,
          height: n.dst.height,
          background: background,
          reveal: reveal,
          view: SlideChartMotion.view(state, view0, type: spec.type),
          fitViews: SlideChartMotion.fitViews(state, view0, type: spec.type),
        )
        ?.scene;
  }
}
