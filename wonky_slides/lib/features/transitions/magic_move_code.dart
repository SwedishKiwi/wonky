import 'package:wonky_code_flutter/wonky_code_flutter.dart'
    show CodeColumns, MorphGlyph, oklabLerp;
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';

import '../elements/code/code_frames.dart';
import '../motion/player/motion_budget.dart';
import '../motion/render/motion_scenes.dart';

/// Code pairs of a Magic Move (06 §8.4, 07 §5.6; 06 AC 6): two code
/// elements matched across slides morph token by token. The incoming
/// element's code node draws the pair's `TokenMorphPlan` glyphs at
/// `codeProgress` (unchanged lexemes glide, colors blend in OKLab, removed
/// ones fade out, added ones fade in) inside its own box and chrome, at
/// full opacity; the outgoing element is hidden.
abstract final class MagicMoveCodeMorphs {
  /// [frame] and the incoming scene [to] with the code morphs applied.
  static (MagicMoveFrame, SlideScene) apply(
    MagicMovePlan plan,
    MagicMoveFrame frame,
    SlideScene to,
    DeckModel deck,
    ResolvedSlide? toSlide,
  ) {
    if (toSlide == null) return (frame, to);
    final pairs = [
      for (final p in plan.pairs)
        if (p.code != null && p.mode == MorphMode.crossfade) p,
    ];
    if (pairs.isEmpty) return (frame, to);
    final outStates = Map.of(frame.outgoing.elements);
    final inStates = Map.of(frame.incoming.elements);
    final swaps = <String, CodeScene Function(CodeScene)>{};
    for (final p in pairs) {
      final st = frame.pairs[p.to.id];
      final e = MotionScenes.elementOf(toSlide, p.to.id);
      final code = p.to.code;
      if (st == null || e == null || code == null) continue;
      final composer = CodeFrames.composerOf(toSlide, e, deck);
      final morph = p.code!;
      final ms = (st.codeProgress ?? st.progress) * morph.totalDurationMs;
      swaps[p.to.id] = (base) =>
          _glyphScene(base, composer, morph.frameAt(ms), code);
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
        case CodeNode():
          final id = n.elementId ?? owner;
          final f = id == null ? null : swaps[id];
          return f == null
              ? n
              : CodeNode(elementId: n.elementId, scene: f(n.scene), dst: n.dst);
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

    return (
      MagicMoveFrame(
        progress: frame.progress,
        outgoing: SlideFrame(outStates, frame.outgoing.background),
        incoming: SlideFrame(inStates, frame.incoming.background),
        layers: frame.layers,
        pairs: frame.pairs,
      ),
      SlideScene(
        slideId: to.slideId,
        width: to.width,
        height: to.height,
        background: to.background,
        nodes: [
          for (final n in to.nodes)
            swaps.containsKey(n.elementId) ? swap(n, null) : n,
        ],
        frames: to.frames,
        routes: to.routes,
      ),
    );
  }

  static CodeScene _glyphScene(
    CodeScene s,
    CodeSceneComposer c,
    List<MorphGlyph> glyphs,
    MagicMoveCode code,
  ) {
    final palette = c.style.palette;
    final metrics = c.style.metrics;
    final area = s.codeArea;
    final left = area?.x ?? code.originX;
    final top = area?.y ?? code.originY;
    final runs = <CodePlacedRun>[
      for (final m in glyphs)
        () {
          final c0 = palette.styleOf(m.lexeme.fromToken ?? m.lexeme.toToken);
          final c1 = palette.styleOf(m.lexeme.toToken ?? m.lexeme.fromToken);
          final st = m.colorMix < 0.5 ? c0 : c1;
          return CodePlacedRun(
            text: CodeColumns.expandTabs(
              m.lexeme.text,
              tabSize: c.data.tabSize,
            ),
            x: left + m.x,
            baseline:
                top +
                m.y +
                metrics.baselineInRow(m.fontSize, c.data.lineHeight),
            color: oklabLerp(c0.color, c1.color, m.colorMix),
            fontSize: m.fontSize,
            opacity: m.opacity,
            bold: st.bold,
            italic: st.italic,
          );
        }(),
    ];
    return CodeScene(
      width: s.width,
      height: s.height,
      fontFamily: s.fontFamily,
      fontSize: s.fontSize,
      lineHeight: s.lineHeight,
      background: s.background,
      title: s.title,
      codeLeft: s.codeLeft,
      numbersRight: s.numbersRight,
      lineNumberColor: s.lineNumberColor,
      chromeHeight: s.chromeHeight,
      titleColor: s.titleColor,
      cornerRadius: s.cornerRadius,
      chrome: s.chrome,
      box: s.box,
      captionHeight: s.captionHeight,
      titleHeight: s.titleHeight,
      titleBackground: s.titleBackground,
      language: s.language,
      codeArea: s.codeArea,
      columnWidth: s.columnWidth,
      gutterFontSize: s.gutterFontSize,
      lineNumberActiveColor: s.lineNumberActiveColor,
      textColor: s.textColor,
      border: s.border,
      borderWidth: s.borderWidth,
      shadow: s.shadow,
      glyphs: runs,
      ligatures: s.ligatures,
      paletteId: s.paletteId,
      darkPalette: s.darkPalette,
      stateIndex: s.stateIndex,
      semanticsLabel: s.semanticsLabel,
    );
  }
}
