import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart';

CodeStateRec _rec(
  String id,
  String code, {
  String? language,
  String? title,
  String? highlight,
  Map<String, Object?>? transition,
  Map<String, Object?>? annotations,
}) => CodeStateRec({
  SlidesCols.id: id,
  SlidesCols.elementId: 'el',
  SlidesCols.sortKey: id,
  SlidesCols.title: title,
  CodeStateCols.code: code,
  CodeStateCols.language: language,
  CodeStateCols.highlight: highlight,
  SlidesCols.transitionJson: transition == null ? null : jsonEncode(transition),
  CodeStateCols.annotationsJson: annotations == null
      ? null
      : jsonEncode(annotations),
});

void main() {
  group('Given an element with three states', () {
    late CodeElementModel model;
    setUp(
      () => model = CodeElementModel.fromRecords(
        'el',
        {
          'v': 1,
          'language': 'dart',
          'title': 'main.dart',
          'typing': {'cps': 40},
        },
        [
          _rec('s1', 'void main() {}', highlight: '1'),
          _rec(
            's2',
            'void main() {\n  print(1);\n}',
            transition: {'mode': 'morph'},
            highlight: '2 | 1-3',
          ),
          _rec('s3', r'$ dart run', language: 'bash', title: 'Terminal'),
        ],
      ),
    );

    test('when reading the states then overrides and inherited values are '
        'resolved', () {
      expect(model.stateCount, 3);
      expect(model.state(0).language, 'dart');
      expect(model.state(2).language, 'bash');
      expect(model.state(0).title, 'main.dart');
      expect(model.state(2).title, 'Terminal');
      expect(model.state(1).stepCount, 2);
      expect(model.state(0).arrival.cps, 40);
    });

    test('when asking for a transition mode then the target state decides', () {
      expect(model.modeOf(0, 1), CodeTransitionMode.morph);
      expect(model.modeOf(1, 2), CodeTransitionMode.type);
    });

    test('when jumping backwards then the change is instant unless a mode is '
        'given', () {
      expect(model.modeOf(2, 0), CodeTransitionMode.instant);
      expect(
        model.modeOf(2, 0, override: CodeTransitionMode.type),
        CodeTransitionMode.type,
      );
    });

    test('when motion is reduced then every change is instant', () {
      expect(
        model.modeOf(0, 1, reducedMotion: true),
        CodeTransitionMode.instant,
      );
      expect(model.transitionDurationMs(1, 2, reducedMotion: true), 200);
    });

    test('when typing into a state then the duration is derived from the '
        'typing script', () {
      final script = model.typingScript(1, 2);

      expect(model.transitionDurationMs(1, 2), script.durationMs);
      expect(script.textAt(script.durationMs), r'$ dart run');
    });

    test('when building the same typing script twice then it is cached', () {
      expect(
        identical(model.typingScript(1, 2), model.typingScript(1, 2)),
        isTrue,
      );
    });

    test('when the script is seeded then it uses the element and target state '
        'ids', () {
      final again = TypingScript.build(
        model.state(1).code,
        model.state(2).code,
        settings: model.state(2).arrival,
        seed: typingSeed('el', 's3'),
      );

      expect(model.typingScript(1, 2).events, again.events);
    });

    test('when morphing then the duration is the morph duration', () {
      expect(model.transitionDurationMs(0, 1), 800);
    });

    test('when typing in the first state from empty then it ends on it', () {
      final s = model.typingScript(-1, 0);

      expect(s.textAt(0), '');
      expect(s.textAt(s.durationMs), 'void main() {}');
      expect(model.typeInDurationMs(), s.durationMs);
    });

    test('when a state arrives then its first step is applied', () {
      expect(model.arrivalStep(1), 0);
      expect(model.arrivalStep(2), isNull);
    });

    test('when comparing a state with the previous one then the line counts '
        'are reported', () {
      final stats = model.diffStats(1)!;

      expect((stats.added, stats.removed, stats.changed), (2, 0, 1));
      expect(model.diffStats(0), isNull);
    });

    test('when describing a state then the label follows 07 §13', () {
      expect(
        model.semanticsLabel(1),
        'Code block, Dart, 3 lines, title main.dart',
      );
      expect(
        model.semanticsLabel(2),
        'Code block, Bash, 1 line, title Terminal',
      );
    });
  });

  group('Given an element without states', () {
    test('when modelled then it has one empty state', () {
      final model = CodeElementModel.fromRecords('el', null, const []);

      expect(model.stateCount, 1);
      expect(model.state(0).code, '');
    });
  });

  group('Given CRLF line breaks', () {
    test('when modelled then they are normalized', () {
      final s = CodeStateModel(id: 'a', code: 'a\r\nb', language: '');

      expect(s.code, 'a\nb');
      expect(s.lineCount, 2);
    });
  });

  group('Given callouts', () {
    test('when a state has annotations then they are parsed per step', () {
      final model = CodeElementModel.fromRecords('el', null, [
        _rec(
          's1',
          'a\nb',
          highlight: '1|2',
          annotations: {
            'steps': {
              '2': {'text': 'Second'},
            },
          },
        ),
      ]);

      expect(model.state(0).annotations[1]!.text, 'Second');
    });
  });
}
