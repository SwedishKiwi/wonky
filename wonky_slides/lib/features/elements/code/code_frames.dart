import 'package:wonky_code_flutter/wonky_code_flutter.dart'
    show CodeTransitionMode;
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';

/// Code scenes of timeline frames (Slides 07 §5.8, 06 §9.2) — the hook the
/// motion player (SL-29) uses to draw code builds, and the editor's
/// transition preview (SL-31).
///
/// A slide's static scene carries each code element in its edit/present
/// state; a [SlideFrame] says what a code element shows at a moment
/// (`ElementVisualState.code`: a state, a running state change with its
/// progress, a highlight step change, the `codeType` progress).
/// [sceneOf] composes that moment with the element's
/// `CodeSceneComposer` ([composerOf]); [applyFrame] swaps the code nodes of
/// a whole scene. Everything is deterministic (07 §1): the same view state
/// gives the same scene on every surface.
abstract final class CodeFrames {
  static const _layout = CodeElementLayout();

  /// The composer of code element [element] on [slide] (cached per
  /// element revision and theme by `CodeElementLayout`).
  static CodeSceneComposer composerOf(
    ResolvedSlide slide,
    ResolvedElement element,
    DeckReader deck,
  ) => _layout.composer(
    element,
    deck,
    slide.theme,
    background: slide.background.effectiveColor(
      slide.theme.colorOf('bg1') ?? 0xffffffff,
    ),
  );

  /// Delay of a step's callout after the highlight starts (07 §4.4), as a
  /// fraction of the step mix.
  static const calloutDelay = 0.4;

  /// The scene of [view] in a [width] × [height] su frame.
  ///
  /// A running state change (`fromStateIndex` set, `mix` < 1) is the
  /// transition frame `mix` × its duration into the change (07 §5.1:
  /// type, morph, instant; `crossfade` = reduced motion); `typing` < 1 is
  /// the `codeType` in-build typing state 1 from empty; otherwise the
  /// static scene of the state with its highlight step (animated from
  /// `fromHighlightStep` by `highlightMix`, the callout following).
  static CodeScene sceneOf(
    CodeSceneComposer c,
    CodeViewState view, {
    required double width,
    required double height,
    bool reducedMotion = false,
  }) {
    final model = c.model;
    final to = view.stateIndex.clamp(0, model.stateCount - 1);
    final typing = view.typing;
    if (typing != null && typing < 1) {
      final ms = typing * model.typeInDurationMs(reducedMotion: reducedMotion);
      return c.buildTransition(
        from: -1,
        to: 0,
        ms: ms,
        width: width,
        height: height,
        reducedMotion: reducedMotion,
      );
    }
    final from = view.fromStateIndex;
    if (from != null && view.mix < 1 && from != to) {
      final reduced = reducedMotion || view.mode == 'crossfade';
      final mode = switch (view.mode) {
        'type' => CodeTransitionMode.type,
        'morph' => CodeTransitionMode.morph,
        'instant' => CodeTransitionMode.instant,
        _ => null,
      };
      final duration = model.transitionDurationMs(
        from,
        to,
        override: mode,
        reducedMotion: reduced,
      );
      return c.buildTransition(
        from: from,
        to: to,
        ms: view.mix.clamp(0.0, 1.0) * duration,
        width: width,
        height: height,
        mode: mode,
        reducedMotion: reduced,
        arrivalStep: view.highlightStep,
      );
    }
    final mix = view.highlightMix.clamp(0.0, 1.0);
    final changing = view.fromHighlightStep != view.highlightStep && mix < 1;
    return c.build(
      to,
      step: view.highlightStep,
      // −1 = "no highlight" (the composer animates from it).
      fromStep: changing ? (view.fromHighlightStep ?? -1) : null,
      stepMix: changing ? mix : 1,
      calloutProgress: changing
          ? ((mix - calloutDelay) / (1 - calloutDelay)).clamp(0.0, 1.0)
          : 1,
      width: width,
      height: height,
    );
  }

  /// [scene] with the code nodes of elements whose state in [frame] has a
  /// code view (or a code state/step) recomposed for that moment;
  /// [composerOf] gives the element's composer (null = keep the node).
  /// Returns [scene] itself when nothing changes.
  static SlideScene applyFrame(
    SlideScene scene,
    SlideFrame frame,
    CodeSceneComposer? Function(String elementId) composerOf, {
    bool reducedMotion = false,
  }) {
    CodeViewState? viewOf(String id) {
      final st = frame.elements[id];
      if (st == null) return null;
      if (st.code != null) return st.code;
      if (st.codeStateIndex == null && st.codeHighlightStep == null) {
        return null;
      }
      return CodeViewState(
        stateIndex: st.codeStateIndex ?? 0,
        highlightStep: st.codeHighlightStep,
      );
    }

    var changed = false;
    SceneNode swap(SceneNode n, String? owner) {
      switch (n) {
        case CodeNode():
          final id = n.elementId ?? owner;
          if (id == null) return n;
          final view = viewOf(id);
          if (view == null) return n;
          final c = composerOf(id);
          if (c == null) return n;
          changed = true;
          return CodeNode(
            elementId: n.elementId,
            dst: n.dst,
            scene: sceneOf(
              c,
              view,
              width: n.dst.width,
              height: n.dst.height,
              reducedMotion: reducedMotion,
            ),
          );
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

  /// [scene] with element [elementId]'s code node replaced by [code]
  /// (the editor's live previews).
  static SlideScene replace(
    SlideScene scene,
    String elementId,
    CodeScene code,
  ) {
    var changed = false;
    SceneNode swap(SceneNode n, String? owner) {
      switch (n) {
        case CodeNode() when (n.elementId ?? owner) == elementId:
          changed = true;
          return CodeNode(elementId: n.elementId, dst: n.dst, scene: code);
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
}
