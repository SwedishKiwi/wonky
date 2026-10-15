import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart';
import 'package:wonky_core/diff.dart' show DiffOp, LineDiff;
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../../../l10n/slides_l10n.dart';
import '../../canvas/canvas_interactions.dart';
import '../../canvas/slide_canvas_controller.dart';
import '../../editor_screen/deck_editor_controller.dart';
import 'code_blocks.dart';
import 'code_frames.dart';

/// Widget keys of the code canvas mode.
abstract final class CodeCanvasKeys {
  static const field = ValueKey<String>('slides.code.field');
  static const overflow = ValueKey<String>('slides.code.overflowBadge');
  static const previewBar = ValueKey<String>('slides.code.previewBar');
}

/// The canvas side of code elements (Slides 07 §3.3, §3.5, §7):
///
/// - **edit mode** — a [CodeEditorField] over the element's code area with
///   the element's computed font size × zoom, line height, gutter and
///   palette (the stage draws the box and chrome, the field the text), so
///   entering and leaving edit mode doesn't move the code; a press outside
///   ends it, `Esc` too;
/// - the **transition preview** (▶ in the state strip): the element plays
///   the type-in / morph / crossfade into a state with the composer's frames
///   (`CodeFrames`), then settles;
/// - the **overflow badge** of a selected element whose code doesn't fit.
class CodeCanvasMode extends CanvasInteraction {
  CodeCanvasMode(super.c) {
    _view = CodeBlockView.of(c.editor)..addListener(_onView);
    _ticker = Ticker(_tick, debugLabel: 'slides.code.preview');
  }

  /// The code mode of [ed]'s canvas, or null without a canvas.
  static CodeCanvasMode? of(DeckEditorController ed) {
    final canvas = SlideCanvasController.of(ed);
    return canvas == null
        ? null
        : CanvasInteractions.find<CodeCanvasMode>(canvas);
  }

  late final CodeBlockView _view;
  late final Ticker _ticker;
  CodePreviewRequest? _playing;
  Duration _elapsed = Duration.zero;
  final _fieldFocus = FocusNode(debugLabel: 'slides.code.field');

  /// Elapsed time of the running preview (tests).
  Duration get previewElapsed => _elapsed;

  CodeEditSession? get _editing {
    final e = _view.editing;
    if (e == null) return null;
    final els = c.elements;
    return els != null && els[e.elementId] != null ? e : null;
  }

  @override
  bool get modal => _editing != null;

  @override
  bool get active => _editing != null || _playing != null;

  @override
  bool get hidesSelectionChrome => _editing != null;

  @override
  bool down(CanvasPointer p) {
    if (_editing == null) return false;
    // A press outside the field ends editing; the press goes on as usual.
    _view.endEdit();
    return false;
  }

  void _onView() {
    final req = _view.preview;
    if (req != _playing) {
      _playing = req;
      _elapsed = Duration.zero;
      if (req == null) {
        if (_ticker.isActive) _ticker.stop();
      } else {
        if (_ticker.isActive) _ticker.stop();
        _ticker.start();
      }
    }
    final e = _view.editing;
    if (e != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_view.editing == e && !_fieldFocus.hasFocus) {
          _fieldFocus.requestFocus();
        }
      });
    }
    c.refresh();
  }

  void _tick(Duration elapsed) {
    final req = _playing;
    if (req == null) return;
    _elapsed = elapsed;
    final comp = _composer(req.elementId);
    if (comp == null) {
      _view.stopPreview();
      return;
    }
    final total = _durationOf(comp, req);
    if (elapsed.inMilliseconds >= total + 400) {
      _view.stopPreview();
      return;
    }
    c.refresh();
  }

  static int _durationOf(CodeSceneComposer comp, CodePreviewRequest req) =>
      req.from < 0
      ? comp.model.typeInDurationMs()
      : comp.model.transitionDurationMs(req.from, req.to);

  CodeSceneComposer? _composer(String elementId) {
    final slide = c.slide;
    final e = c.elements?[elementId];
    if (slide == null || e == null || e.record.kind != ElementKind.code) {
      return null;
    }
    return CodeFrames.composerOf(slide, e, c.editor.model);
  }

  /// The code scene of [elementId] in the canvas scene (edit state).
  CodeScene? sceneOf(String elementId) {
    final s = c.scene;
    if (s == null) return null;
    for (final n in s.nodesOf(elementId)) {
      if (n is CodeNode) return n.scene;
      if (n is GroupNode) {
        for (final k in n.children) {
          if (k is CodeNode) return k.scene;
        }
      }
    }
    return null;
  }

  @override
  SlideScene sceneFor(SlideScene scene) {
    final req = _playing;
    if (req != null) {
      final comp = _composer(req.elementId);
      final code = sceneOf(req.elementId);
      if (comp != null && code != null) {
        final frame = comp.buildTransition(
          from: req.from,
          to: req.to,
          ms: _elapsed.inMilliseconds,
          width: code.width,
          height: code.height,
          arrivalStep: comp.model.arrivalStep(req.to),
        );
        return CodeFrames.replace(scene, req.elementId, frame);
      }
    }
    final e = _editing;
    if (e != null) {
      final code = sceneOf(e.elementId);
      if (code != null) {
        return CodeFrames.replace(scene, e.elementId, withoutText(code));
      }
    }
    return scene;
  }

  /// [s] without its text, numbers and highlight (the edit field draws
  /// them).
  static CodeScene withoutText(CodeScene s) => CodeScene(
    width: s.width,
    height: s.height,
    fontFamily: s.fontFamily,
    fontSize: s.fontSize,
    lineHeight: s.lineHeight,
    background: s.background,
    title: s.title,
    codeLeft: s.codeLeft,
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
    ligatures: s.ligatures,
    paletteId: s.paletteId,
    darkPalette: s.darkPalette,
    stateIndex: s.stateIndex,
    semanticsLabel: s.semanticsLabel,
  );

  @override
  List<Widget> overlays(BuildContext context) {
    final e = _editing;
    if (e != null) return [?_field(context, e)];
    final sel = c.editor.selectedElementIds;
    if (sel.length == 1 && _playing == null) {
      final badge = _overflowBadge(context, sel.single);
      if (badge != null) return [badge];
    }
    return const [];
  }

  Widget? _field(BuildContext context, CodeEditSession e) {
    final f = c.frameOf(e.elementId);
    final s = sceneOf(e.elementId);
    final comp = _composer(e.elementId);
    if (f == null || s == null || comp == null) return null;
    final zoom = c.viewport.scale;
    final box = s.box ?? SuRect(0, 0, s.width, s.height);
    final area = s.codeArea ?? box;
    final topLeft = c.viewport.toViewport(Offset(f.x, f.y));
    final state = comp.model.state(_view.stateIndexOf(e.elementId));
    final metrics = MonoFontMetrics.forFamily(s.fontFamily);
    final fontSize = s.fontSize * zoom;
    final factor = s.fontSize <= 0 ? 1.5 : s.lineHeight / s.fontSize;
    final index = _view.stateIndexOf(e.elementId);
    final diff = _view.diffGutter && index > 0
        ? codeDiffMarks(comp.model.state(index - 1).code, e.text)
        : null;
    final gutter = CodeEditorGutter(
      width: (area.x - box.x) * zoom,
      numbersRight: s.numbersRight == null
          ? null
          : (s.numbersRight! - box.x) * zoom,
      fontSize: (s.gutterFontSize > 0 ? s.gutterFontSize : s.fontSize) * zoom,
      startLine: comp.data.startLine,
      color: Color(s.lineNumberColor),
      activeColor: Color(s.lineNumberActiveColor),
      marks: diff?.marks ?? const {},
      removedBefore: diff?.removedBefore ?? const {},
    );
    final l = slidesL10n(context);
    Widget field = ListenableBuilder(
      listenable: e,
      builder: (context, _) => CodeEditorField(
        key: CodeCanvasKeys.field,
        text: e.text,
        palette: comp.style.palette,
        language: state.language,
        fontFamily: s.fontFamily,
        fontSize: fontSize,
        lineHeight: factor,
        tabSize: comp.data.tabSize,
        wrap: comp.data.wrap,
        gutter: gutter,
        padding: EdgeInsets.only(right: (box.right - area.right) * zoom),
        baselineInRow: metrics.baselineInRow(fontSize, factor),
        focusNode: _fieldFocus,
        readOnly: !c.editor.canEdit,
        onChanged: e.edit,
        onExit: () {
          _view.endEdit();
          c.editor.selectElements([e.elementId]);
          c.editor.canvasFocus.requestFocus();
        },
        semanticsLabel: l.codeEditorSemantics(
          state.language.isEmpty
              ? l.codePlainText
              : CodeLanguages.displayName(state.language),
        ),
      ),
    );
    field = SizedBox(
      width: box.width * zoom,
      height: math.max(area.height, 1) * zoom,
      child: field,
    );
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: f.width * zoom,
      height: f.height * zoom,
      child: Transform.rotate(
        angle: f.rotation * math.pi / 180,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: box.x * zoom,
              top: area.y * zoom,
              child: CanvasChrome(child: field),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _overflowBadge(BuildContext context, String id) {
    final s = sceneOf(id);
    if (s == null || s.hiddenRows <= 0) return null;
    final f = c.frameOf(id);
    if (f == null) return null;
    final r = c.viewport.rectToViewport(f.bounds);
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    return Positioned(
      left: r.left + 8,
      top: r.bottom + 6,
      child: CanvasChrome(
        child: ShadTooltip(
          builder: (_) => Text(l.codeOverflowHint),
          child: Container(
            key: CodeCanvasKeys.overflow,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.popover,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: theme.colorScheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.foldVertical,
                  size: 13,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 4),
                Text(
                  l.codeLinesHidden(s.hiddenRows),
                  style: theme.textTheme.small.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _view.removeListener(_onView);
    _ticker.dispose();
    _fieldFocus.dispose();
  }
}

/// The diff gutter of [current] against [previous] (07 §7 *Show
/// changes*): changed lines (a deleted line paired with an inserted one),
/// added lines, and where lines were removed.
({Map<int, CodeGutterMark> marks, Set<int> removedBefore}) codeDiffMarks(
  String previous,
  String current,
) {
  final diff = LineDiff.diff(previous, current);
  final marks = <int, CodeGutterMark>{};
  final removed = <int>{};
  var i = 0;
  while (i < diff.length) {
    if (diff[i].op == DiffOp.equal) {
      i++;
      continue;
    }
    var dels = 0;
    final ins = <int>[];
    while (i < diff.length && diff[i].op != DiffOp.equal) {
      final d = diff[i];
      if (d.op == DiffOp.delete) dels++;
      if (d.op == DiffOp.insert) ins.add(d.newLine! - 1);
      i++;
    }
    for (final (k, line) in ins.indexed) {
      marks[line] = k < dels ? CodeGutterMark.changed : CodeGutterMark.added;
    }
    if (dels > ins.length) {
      // Removed lines sit before the next line of the new text.
      final next = i < diff.length ? diff[i].newLine! - 1 : null;
      removed.add(
        next ?? (ins.isEmpty ? LineDiff.lines(current).length : ins.last + 1),
      );
    }
  }
  return (marks: marks, removedBefore: removed);
}
