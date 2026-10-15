/// The content of settled timeline frames for exports (06 §9.6, 10 §11.3
/// step 2; SL-33): what a frame says about content that painting alone
/// can't show — code elements at a state and highlight step (07 §4–§5)
/// and charts at a build reveal or 3D camera (08 §9–§10). Everything else
/// a frame holds (visibility, opacity, transforms, colors, text parts,
/// highlights) is applied by the painter from the frame itself.
///
/// The pure-Dart counterpart of the app's `MotionScenes` for frames at
/// the end of a step (PDF builds as pages, the final frame, notes and
/// handouts with builds): running state changes and type-in are not
/// composed (settled frames have none).
library;

import 'package:wonky_charts/wonky_charts.dart' show ChartScene;

import '../../charts/chart_motion.dart';
import '../../charts/slide_chart_layout.dart';
import '../../code/code_element_layout.dart';
import '../../model/api/deck_reader.dart';
import '../../model/api/kinds.dart';
import '../../model/api/resolved.dart';
import '../../model/resolve/slide_resolver.dart';
import '../../motion/timeline/slide_frame.dart';
import '../../scene/nodes/code_scene.dart';
import '../../scene/nodes/scene_nodes.dart';

/// Recomposes the code and chart nodes of a scene for a settled frame.
abstract final class SlideFrameScenes {
  /// [scene] (of [slide]) with the code nodes of elements whose state in
  /// [frame] names a code state or highlight step, and the chart nodes of
  /// elements with a chart reveal or camera, laid out for that frame.
  /// [charts] reveals only when it is a [SlideChartLayout]; code uses
  /// [code] (default: the core's [CodeElementLayout]). Returns [scene]
  /// itself when nothing changes.
  static SlideScene apply(
    SlideScene scene,
    SlideFrame frame, {
    required ResolvedSlide slide,
    required DeckReader deck,
    ChartSceneSource? charts,
    CodeSceneSource? code,
  }) {
    if (frame.elements.isEmpty) return scene;
    var any = false;
    for (final s in frame.elements.values) {
      if (s.code != null ||
          s.codeStateIndex != null ||
          s.codeHighlightStep != null ||
          s.chart != null) {
        any = true;
        break;
      }
    }
    if (!any) return scene;
    final background = slide.background.effectiveColor(
      slide.theme.colorOf('bg1') ?? 0xffffffff,
    );
    final codeSource = code ?? const CodeElementLayout();
    var changed = false;

    SceneNode swap(SceneNode n, String? owner) {
      switch (n) {
        case CodeNode():
          final id = n.elementId ?? owner;
          final st = id == null ? null : frame.elements[id];
          if (st == null) return n;
          final stateIndex = st.code?.stateIndex ?? st.codeStateIndex;
          final step = st.code?.highlightStep ?? st.codeHighlightStep;
          if (stateIndex == null && step == null) return n;
          final e = elementOf(slide, id!);
          if (e == null || e.record.kind != ElementKind.code) return n;
          final c = _code(
            codeSource,
            e,
            deck,
            slide,
            n,
            stateIndex ?? 0,
            step,
            background,
          );
          if (c == null) return n;
          changed = true;
          return CodeNode(elementId: n.elementId, dst: n.dst, scene: c);
        case ChartNode():
          final id = n.elementId ?? owner;
          final st = id == null ? null : frame.elements[id]?.chart;
          if (st == null || charts is! SlideChartLayout) return n;
          final e = elementOf(slide, id!);
          if (e == null) return n;
          final c = _chart(charts, e, deck, slide, n, st, background);
          if (c == null) return n;
          changed = true;
          return ChartNode(elementId: n.elementId, scene: c, dst: n.dst);
        case GroupNode():
          final before = changed;
          changed = false;
          final kids = [
            for (final k in n.children) swap(k, n.elementId ?? owner),
          ];
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

    final nodes = [for (final n in scene.nodes) swap(n, null)];
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

  static CodeScene? _code(
    CodeSceneSource source,
    ResolvedElement e,
    DeckReader deck,
    ResolvedSlide slide,
    CodeNode n,
    int stateIndex,
    int? step,
    int background,
  ) {
    if (source is CodeElementLayout) {
      // As the player draws it (the app's `CodeFrames.sceneOf` for a
      // settled view): the state with its highlight step, dimmed.
      final c = source.composer(e, deck, slide.theme, background: background);
      final count = c.model.stateCount;
      if (count <= 0) return null;
      return c.build(
        stateIndex.clamp(0, count - 1),
        step: step,
        width: n.dst.width,
        height: n.dst.height,
      );
    }
    return source.codeScene(
      e,
      deck,
      slide.theme,
      width: n.dst.width,
      height: n.dst.height,
      purpose: ScenePurpose.present,
      stateIndex: stateIndex,
      step: step,
      background: background,
    );
  }

  static ChartScene? _chart(
    SlideChartLayout source,
    ResolvedElement e,
    DeckReader deck,
    ResolvedSlide slide,
    ChartNode n,
    ChartRevealState state,
    int background,
  ) {
    final base = source.build(
      e.record,
      deck,
      slide.theme,
      width: n.dst.width,
      height: n.dst.height,
      background: background,
    );
    if (base == null) return null;
    final spec = base.look.spec;
    final reveal = SlideChartMotion.reveal(state);
    if (!spec.threeD.appliesTo(spec.type)) {
      return source
          .build(
            e.record,
            deck,
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
          deck,
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
