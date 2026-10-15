import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/testing.dart';

import '../../support/scene_fixture.dart';

// Code builds take their durations from the element's model (07 §5.3,
// §5.6) and keep empty "show all" highlight steps (07 §4.1) — SL-31.
void main() {
  group('Given highlight step expressions', () {
    for (final (input, count) in [
      (null, 0),
      ('', 0),
      ('1-3 | 5 | 7-9', 3),
      ('1-3|5|', 3),
      ('| 2,4 | *', 3),
    ]) {
      test('when counting "$input" then there are $count steps', () {
        expect(MotionCodeState.stepsOf(input), count);
      });
    }
  });

  group('Given a code block with two states and code builds', () {
    late DeckBuilder b;
    late String slide, code;

    setUp(() {
      b = DeckBuilder();
      slide = b.slide(layoutKey: 'blank');
      (code, _) = b.codeBlock(
        slide,
        states: [
          'void main() {\n  print(1);\n}',
          'void main() {\n  final x = 2;\n  print(x);\n}',
        ],
        highlights: ['1|2|'],
        transitions: [
          null,
          jsonEncode({'mode': 'type', 'cps': 40}),
        ],
      );
    });

    CodeElementModel model(DeckModel m) => CodeElementModel.fromDeck(
      m,
      code,
      jsonDecode(m.element(code)!.dataJson!) as Map<String, Object?>,
    );

    test('when compiled then the type-in and the typed change last as long '
        'as their typing scripts', () {
      b
        ..build_(slide, code, effect: 'codeType')
        ..build_(
          slide,
          code,
          kind: SlideBuildKind.emphasis,
          effect: 'codeState',
          durationMs: 500,
        );
      final m = b.build();
      final t = SlideTimelineCompiler.compile(
        SlideMotionInput.fromDeck(m, slide),
      );

      final cm = model(m);
      expect(t.steps[1].durationMs, cm.typeInDurationMs());
      expect(t.steps[2].durationMs, cm.transitionDurationMs(0, 1));
      expect(t.steps[2].durationMs, isNot(500));
    });

    test('when the state change is a morph then it lasts the state\'s morph '
        'duration', () {
      b.build_(
        slide,
        code,
        kind: SlideBuildKind.emphasis,
        effect: 'codeState',
        optionsJson: jsonEncode({
          'v': 1,
          'params': {'mode': 'morph'},
        }),
      );
      final m = b.build();
      final t = SlideTimelineCompiler.compile(
        SlideMotionInput.fromDeck(m, slide),
      );

      expect(t.steps[1].durationMs, 800);
    });

    test('when the first state has a trailing empty step then three '
        'highlight builds are valid', () {
      for (var i = 1; i <= 3; i++) {
        b.build_(
          slide,
          code,
          kind: SlideBuildKind.emphasis,
          effect: 'codeHighlight',
          optionsJson: jsonEncode({
            'v': 1,
            'params': {'step': i},
          }),
        );
      }
      final t = SlideTimelineCompiler.compile(
        SlideMotionInput.fromDeck(b.build(), slide),
      );

      expect(t.stepCount, 3);
      expect(t.warnings, isEmpty);
    });
  });

  group('Given the edit frame of a code block', () {
    test('when the inspector previews a highlight step then the scene shows '
        'that step', () {
      final f = SceneFixture();
      final (code, _) = f.b.codeBlock(
        f.slideId,
        states: ['a\nb\nc'],
        highlights: ['2'],
      );
      final m = f.model();
      final slide = f.resolve(model: m);
      CodeScene sceneWith(Map<String, int> steps) {
        final s = f.builder.build(
          slide,
          SceneContext(
            theme: slide.theme,
            textLayout: f.engine,
            deck: m,
            codeSteps: steps,
          ),
        );
        return s
            .nodesOf(code)
            .expand(SceneFixture.descendants)
            .whereType<CodeNode>()
            .first
            .scene;
      }

      final plain = sceneWith(const {});
      final stepped = sceneWith({code: 0});

      expect(plain.step, isNull);
      expect(stepped.step, 0);
      expect(
        [for (final l in stepped.lines) l.highlighted],
        [false, true, false],
      );
    });
  });
}
