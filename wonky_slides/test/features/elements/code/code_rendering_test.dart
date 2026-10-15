import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart' show CodeGutterMark;
import 'package:wonky_slides/features/elements/code/code_canvas_mode.dart';
import 'package:wonky_slides/features/elements/code/code_frames.dart';
import 'package:wonky_slides/features/elements/code/code_scene_painter.dart';
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/testing.dart';

/// A deck with one code block: two states, steps on the first, a callout.
(DeckModel, ResolvedSlide, ResolvedElement) _deck({
  Map<String, Object?> data = const {},
}) {
  final b = DeckBuilder();
  final slide = b.slide(layoutKey: 'blank');
  final (code, _) = b.codeBlock(
    slide,
    states: [
      'void main() {\n  print(1);\n}',
      'void main() {\n  final x = 2;\n  print(x);\n}',
    ],
    highlights: ['2|1-3'],
    annotations: [
      jsonEncode({
        'v': 1,
        'steps': {
          '1': {
            'text': '**Null-safe** `print`',
            'anchor': {'side': 'right'},
          },
        },
      }),
    ],
    data: {'v': 1, 'language': 'dart', 'title': 'lib/main.dart', ...data},
  );
  final m = b.build();
  final s = SlideResolver(m).resolve(slide)!;
  final e = s.elements.firstWhere((x) => x.id == code);
  return (m, s, e);
}

/// Paints [s] into a picture (throws on painter errors).
void _paint(CodeScene s) {
  final rec = ui.PictureRecorder();
  CodeScenePainter.paint(ui.Canvas(rec), s, SuRect(0, 0, s.width, s.height));
  rec.endRecording().dispose();
}

void main() {
  group('Given cached code paragraphs (SL-36 regression)', () {
    testWidgets('when the engine\'s fonts change (a bundled family finished '
        'loading) then code is laid out again instead of keeping the '
        'fallback font', (tester) async {
      final before = CodeScenePainter.debugParagraph(
        'final x = 1;',
        family: 'SL36 Mono',
      );
      expect(
        CodeScenePainter.debugParagraph('final x = 1;', family: 'SL36 Mono'),
        same(before),
      );

      await tester.binding.handleSystemMessage(<String, Object?>{
        'type': 'fontsChange',
      });

      expect(
        CodeScenePainter.debugParagraph('final x = 1;', family: 'SL36 Mono'),
        isNot(same(before)),
      );
    });
  });

  group('Given a code block composer', () {
    for (final chrome in ['window', 'tab', 'caption', 'none']) {
      test('when its $chrome scene with a step, bars and a callout is painted '
          'then nothing throws', () {
        final (m, s, e) = _deck(
          data: {
            'chrome': chrome,
            'showLanguage': true,
            'highlightStyle': {'style': 'box'},
            'box': {'border': '#ff0000'},
          },
        );
        final c = CodeFrames.composerOf(s, e, m);
        final scene = c.build(0, step: 0, width: 1600, height: 800);

        expect(scene.bars, isNotEmpty);
        expect(scene.callouts.single.text, '**Null-safe** `print`');
        _paint(scene);
      });
    }

    test('when the type-in is half done then the frame has a caret and part '
        'of the code', () {
      final (m, s, e) = _deck();
      final c = CodeFrames.composerOf(s, e, m);
      final total = c.model.typeInDurationMs();
      final scene = CodeFrames.sceneOf(
        c,
        const CodeViewState(stateIndex: 0, typing: 0.5),
        width: 1600,
        height: 800,
      );
      final shown = [
        for (final l in scene.lines) l.runs.map((r) => r.text).join(),
      ].join('\n');

      expect(total, greaterThan(500));
      expect(scene.caret, isNotNull);
      expect(shown.trim().length, lessThan(c.model.state(0).code.length));
      _paint(scene);
    });

    test('when state 2 morphs in then the frame places glyphs and gutter '
        'labels', () {
      final (m, s, e) = _deck();
      final c = CodeFrames.composerOf(s, e, m);
      final scene = CodeFrames.sceneOf(
        c,
        const CodeViewState(
          stateIndex: 1,
          fromStateIndex: 0,
          mix: 0.5,
          mode: 'morph',
        ),
        width: 1600,
        height: 800,
      );

      expect(scene.glyphs, isNotEmpty);
      expect(scene.gutter, isNotEmpty);
      _paint(scene);
    });

    test('when the change is instant then the frame crossfades over an '
        'underlay', () {
      final (m, s, e) = _deck();
      final c = CodeFrames.composerOf(s, e, m);
      final scene = CodeFrames.sceneOf(
        c,
        const CodeViewState(
          stateIndex: 1,
          fromStateIndex: 0,
          mix: 0.1,
          mode: 'instant',
        ),
        width: 1600,
        height: 800,
      );

      expect(scene.underlay, isNotNull);
      expect(scene.opacity, lessThan(1));
      _paint(scene);
    });

    test('when a step changes halfway then lines interpolate and the '
        'callout waits', () {
      final (m, s, e) = _deck(
        data: {
          'highlightStyle': {'style': 'dim'},
        },
      );
      final c = CodeFrames.composerOf(s, e, m);
      final scene = CodeFrames.sceneOf(
        c,
        const CodeViewState(
          stateIndex: 0,
          highlightStep: 0,
          fromHighlightStep: null,
          highlightMix: 0.3,
        ),
        width: 1600,
        height: 800,
      );
      final dimmed = scene.lines.where((l) => l.index != 1);

      expect(dimmed.every((l) => l.opacity < 1 && l.opacity > 0.3), isTrue);
      expect(scene.callouts, isEmpty);
    });
  });

  group('Given a slide scene and a frame', () {
    test('when the frame shows code state 2 then only the code node is '
        'recomposed', () {
      final (m, s, e) = _deck();
      final scene = SlideSceneBuilder().build(
        s,
        SceneContext(
          theme: s.theme,
          textLayout: SlideTextLayout(),
          deck: m,
          code: const CodeElementLayout(),
        ),
      );
      final frame = SlideFrame({e.id: ElementVisualState(codeStateIndex: 1)});
      final out = CodeFrames.applyFrame(
        scene,
        frame,
        (_) => CodeFrames.composerOf(s, e, m),
      );
      CodeScene codeOf(SlideScene x) => x
          .nodesOf(e.id)
          .whereType<GroupNode>()
          .expand((g) => g.children)
          .whereType<CodeNode>()
          .first
          .scene;

      expect(codeOf(scene).stateIndex, 0);
      expect(codeOf(out).stateIndex, 1);
      expect(
        identical(
          CodeFrames.applyFrame(scene, SlideFrame.edit, (_) => null),
          scene,
        ),
        isTrue,
      );
    });
  });

  group('Given callout text', () {
    test('when parsing inline Markdown then bold, italic and code are '
        'segments', () {
      final segs = CodeScenePainter.inlineMarkdown('a **b** *c* `d`');
      expect([for (final s in segs) s.$1], ['a ', 'b', ' ', 'c', ' ', 'd']);
      expect(segs[1].bold, isTrue);
      expect(segs[3].italic, isTrue);
      expect(segs[5].code, isTrue);
    });
  });

  group('Given two states for the diff gutter', () {
    test('when a line changed, one was added and one removed then the marks '
        'say so', () {
      final r = codeDiffMarks('a\nb\nc\nd', 'a\nB\nc\nnew');
      expect(r.marks, {1: CodeGutterMark.changed, 3: CodeGutterMark.changed});
      final r2 = codeDiffMarks('a\nb\nc', 'a\nc\nx');
      expect(r2.marks, {2: CodeGutterMark.added});
      expect(r2.removedBefore, {1});
    });
  });
}
