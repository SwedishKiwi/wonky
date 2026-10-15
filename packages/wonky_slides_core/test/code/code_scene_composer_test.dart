import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/scene.dart';

CodeSceneComposer _composer(
  List<String> codes, {
  Map<String, Object?> data = const {},
  List<String?> highlights = const [],
  List<Map<String, Object?>?> annotations = const [],
  String language = 'dart',
  SyntaxPalette? palette,
}) {
  final d = CodeElementData.fromJson({'v': 1, 'language': language, ...data});
  final model = CodeElementModel(
    elementId: 'el',
    data: d,
    states: [
      for (var i = 0; i < codes.length; i++)
        CodeStateModel(
          id: 's$i',
          code: codes[i],
          language: d.language,
          title: d.title,
          highlight: i < highlights.length ? highlights[i] : null,
          arrival: d.typing,
          annotations: i < annotations.length
              ? CodeAnnotations.fromJson(annotations[i])
              : CodeAnnotations.empty,
        ),
    ],
  );
  return CodeSceneComposer(
    model,
    CodeRenderStyle(palette: palette ?? BuiltInPalettes.wonkyLight),
  );
}

String _lines(int n, [int width = 20]) =>
    List.generate(n, (i) => 'x' * width).join('\n');

void main() {
  group('Given auto size across states (07 AC-3)', () {
    test('when 30 lines × 80 columns are shown in 1600 × 900 then the size '
        'is at least 16 su', () {
      final c = _composer([_lines(30, 80)], data: {'title': 'a.dart'});

      final scene = c.build(0, width: 1600, height: 900);

      expect(scene.fontSize, greaterThanOrEqualTo(16));
      expect(scene.hiddenRows, 0);
      expect(scene.lines, hasLength(30));
    });

    test('when a longer second state is added then state 1 shrinks to the '
        'shared size, and both states have the same size', () {
      final alone = _composer([
        _lines(10, 40),
      ]).build(0, width: 1600, height: 900);
      final c = _composer([_lines(10, 40), _lines(30, 80)]);

      final s1 = c.build(0, width: 1600, height: 900);
      final s2 = c.build(1, width: 1600, height: 900);

      expect(s1.fontSize, lessThan(alone.fontSize));
      expect(s1.fontSize, s2.fontSize);
    });

    test('when fitAcrossStates is off then each state fits itself', () {
      final c = _composer(
        [_lines(10, 40), _lines(30, 80)],
        data: {'fitAcrossStates': false},
      );

      expect(
        c.build(0, width: 1600, height: 900).fontSize,
        greaterThan(c.build(1, width: 1600, height: 900).fontSize),
      );
    });

    test('when the code is too long then it overflows at the minimum size', () {
      final c = _composer([_lines(80)]);

      final scene = c.build(0, width: 800, height: 400);

      expect(scene.fontSize, 14);
      expect(scene.hiddenRows, greaterThan(0));
    });

    test('when a fixed size is set then it is used', () {
      final c = _composer(['a'], data: {'fontSize': 22});

      expect(c.build(0, width: 800, height: 400).fontSize, 22);
    });
  });

  group('Given Dart code', () {
    final c = _composer(['final total = items.length; // n']);

    test('when built then runs are colored tokens placed on the grid', () {
      final scene = c.build(0, width: 1200, height: 400);
      final runs = scene.lines.single.runs;

      expect(runs.map((r) => r.color).toSet().length, greaterThan(1));
      expect(
        runs.map((r) => r.text).join(),
        'final total = items.length; // n',
      );
      final total = runs.firstWhere((r) => r.text.contains('total'));
      expect(
        total.column,
        'final '.length - (total.text.length - total.text.trimLeft().length),
      );
    });

    test('when built then the code area, gutter and chrome are laid out', () {
      final scene = c.build(0, width: 1200, height: 400);

      expect(scene.chrome, 'window');
      expect(scene.titleHeight, closeTo(scene.fontSize * 2.2, 1e-9));
      expect(scene.numbersRight, isNotNull);
      expect(scene.codeLeft, greaterThan(scene.numbersRight!));
      expect(scene.columnWidth, closeTo(scene.fontSize * 0.6, 1e-9));
      expect(scene.fontFamily, 'JetBrains Mono');
      expect(scene.semanticsLabel, 'Code block, Dart, 1 line');
    });
  });

  group('Given tabs and wide characters', () {
    test('when built then a run after a tab starts at the tab stop', () {
      final c = _composer(['\tx'], language: '', data: {'tabSize': 4});

      final runs = c.build(0, width: 800, height: 300).lines.single.runs;

      expect(runs.single.text, '    x');
      expect(runs.single.column, 0);
    });
  });

  group('Given highlight steps "1-2 | 4"', () {
    final code = 'a\nb\nc\nd';

    test('when step 1 is shown with the dim style then other lines are '
        'dimmed to 0.3', () {
      final c = _composer([code], highlights: ['1-2 | 4'], language: '');

      final lines = c.build(0, step: 0, width: 800, height: 400).lines;

      expect(lines.map((l) => l.opacity), [1, 1, 0.3, 0.3]);
      expect(lines.map((l) => l.highlighted), [true, true, false, false]);
    });

    test('when no step is shown then every line is normal', () {
      final c = _composer([code], highlights: ['1-2 | 4'], language: '');

      final lines = c.build(0, width: 800, height: 400).lines;

      expect(lines.every((l) => l.opacity == 1), isTrue);
    });

    test('when the blur style is exported to PDF then blur becomes dim '
        '0.45', () {
      final c = _composer(
        [code],
        highlights: ['4'],
        language: '',
        data: {
          'highlightStyle': {'style': 'blur'},
        },
      );

      final screen = c.build(0, step: 0, width: 800, height: 400).lines.first;
      final pdf = c
          .build(0, step: 0, width: 800, height: 400, vectorOnly: true)
          .lines
          .first;

      expect((screen.opacity, screen.blurSigma), (0.6, 2.5));
      expect((pdf.opacity, pdf.blurSigma), (0.45, 0));
    });

    test('when the bar style is used then each block gets a band and a '
        'gutter marker', () {
      final c = _composer(
        [code],
        highlights: ['1-2,4'],
        language: '',
        data: {
          'highlightStyle': {'style': 'bar'},
        },
      );

      final scene = c.build(0, step: 0, width: 800, height: 400);

      expect(scene.bars.where((b) => b.kind == CodeBarKind.bar), hasLength(2));
      expect(
        scene.bars.where((b) => b.kind == CodeBarKind.gutterMarker),
        hasLength(2),
      );
      expect(scene.lines.every((l) => l.opacity == 1), isTrue);
    });

    test('when the box style is used then contiguous ranges get an '
        'outline', () {
      final c = _composer(
        [code],
        highlights: ['1-2'],
        language: '',
        data: {
          'highlightStyle': {'style': 'box', 'gutterMarker': false},
        },
      );

      final bars = c.build(0, step: 0, width: 800, height: 400).bars;

      expect(bars.single.kind, CodeBarKind.box);
      expect(bars.single.strokeWidth, 2);
    });

    test('when changing from step 1 to step 2 halfway then line opacities '
        'are in between', () {
      final c = _composer([code], highlights: ['1-2 | 4'], language: '');

      final lines = c
          .build(0, step: 1, fromStep: 0, stepMix: 0.5, width: 800, height: 400)
          .lines;

      expect(lines.first.opacity, closeTo(0.65, 1e-9));
      expect(lines.last.opacity, closeTo(0.65, 1e-9));
    });

    test('when printing (no dimming) then the step is ignored', () {
      final c = _composer([code], highlights: ['1'], language: '');

      final lines = c
          .build(0, step: 0, width: 800, height: 400, dimming: false)
          .lines;

      expect(lines.every((l) => l.opacity == 1), isTrue);
    });
  });

  group('Given overflowing code and a step at its end', () {
    test('when the focus is scroll then the step\'s lines are scrolled into '
        'view', () {
      final c = _composer(
        [_lines(60, 10)],
        highlights: ['55-56'],
        language: '',
      );

      final scene = c.build(0, step: 0, width: 600, height: 300);

      expect(scene.scrollY, greaterThan(0));
      expect(scene.lines.any((l) => l.index == 54), isTrue);
      expect(scene.lines.any((l) => l.index == 0), isFalse);
    });

    test('when the focus is none then the top stays', () {
      final c = _composer(
        [_lines(60, 10)],
        highlights: ['55'],
        language: '',
        data: {
          'highlightStyle': {'focus': 'none'},
        },
      );

      expect(c.build(0, step: 0, width: 600, height: 300).scrollY, 0);
    });

    test('when the focus is zoom then a short range is enlarged', () {
      final c = _composer(
        [_lines(60, 10)],
        highlights: ['55'],
        language: '',
        data: {
          'highlightStyle': {'focus': 'zoom'},
        },
      );

      final plain = c.build(0, width: 600, height: 300);
      final zoomed = c.build(0, step: 0, width: 600, height: 300);

      expect(zoomed.fontSize, greaterThan(plain.fontSize));
    });
  });

  group('Given a callout on step 1', () {
    test('when there is room to the right then it is placed right of the '
        'anchor line', () {
      final c = _composer(
        ['short\nline'],
        highlights: ['2'],
        language: '',
        data: {'fontSize': 20},
        annotations: [
          {
            'steps': {
              '1': {'text': '**Look** here'},
            },
          },
        ],
      );

      final callout = c
          .build(0, step: 0, width: 1400, height: 400)
          .callouts
          .single;

      expect(callout.side, 'right');
      expect(callout.anchorLine, 2);
      expect(callout.text, '**Look** here');
      expect(callout.fontSize, closeTo(18, 1e-9));
    });

    test('when the line fills the box then it goes below the range', () {
      final c = _composer(
        ['${'y' * 60}\nz\nz\nz'],
        highlights: ['1'],
        language: '',
        annotations: [
          {
            'steps': {
              '1': {'text': 'Wide'},
            },
          },
        ],
      );

      final callout = c
          .build(0, step: 0, width: 800, height: 400)
          .callouts
          .single;

      expect(callout.side, 'below');
    });

    test('when entering then it fades and rises in', () {
      final c = _composer(
        ['a'],
        highlights: ['1'],
        language: '',
        annotations: [
          {
            'steps': {
              '1': {'text': 'Hi'},
            },
          },
        ],
      );

      final callout = c
          .build(0, step: 0, width: 800, height: 400, calloutProgress: 0.5)
          .callouts
          .single;

      expect((callout.opacity, callout.rise), (0.5, 6));
    });
  });

  group('Given a typing transition', () {
    final c = _composer(['int a = 1;', 'int count = 1;\nprint(count);']);

    test('when it runs then the frame shows the current text with a caret', () {
      final script = c.model.typingScript(0, 1);
      final mid = script.events
          .firstWhere((e) => e.kind == TypingEventKind.insert)
          .atMs;

      final scene = c.buildTransition(
        from: 0,
        to: 1,
        ms: mid,
        width: 800,
        height: 400,
      );

      expect(scene.caret, isNotNull);
      expect(scene.caret!.rect.width, 2);
      expect(
        scene.lines.first.runs.map((r) => r.text).join(),
        isNot('int a = 1;'),
      );
    });

    test('when it ends then the frame equals the static target state', () {
      final script = c.model.typingScript(0, 1);

      final end = c.buildTransition(
        from: 0,
        to: 1,
        ms: script.durationMs,
        width: 800,
        height: 400,
      );
      final target = c.build(1, width: 800, height: 400);

      expect(end.caret, isNull);
      expect(
        end.lines.map((l) => l.runs.map((r) => r.text).join()),
        target.lines.map((l) => l.runs.map((r) => r.text).join()),
      );
      expect(end.fontSize, target.fontSize);
    });

    test('when a long deletion is selected then the selection is drawn', () {
      final c2 = _composer([
        'keep();\nremove_this_whole_line_now();\nkeep();',
        'keep();\nkeep();',
      ]);
      final script = c2.model.typingScript(0, 1);
      final select = script.events.firstWhere(
        (e) => e.kind == TypingEventKind.select,
      );

      final scene = c2.buildTyping(
        from: 0,
        to: 1,
        ms: select.atMs + select.durationMs,
        width: 800,
        height: 400,
      );

      expect(
        scene.bars.where((b) => b.kind == CodeBarKind.selection),
        isNotEmpty,
      );
    });
  });

  group('Given a morph transition', () {
    final c = _composer(
      ['final a = 1;\nfinal b = 2;', 'final b = 2;\nfinal a = 1;'],
      data: {
        'typing': {'mode': 'morph'},
      },
    );

    test('when halfway then lexemes are placed freely and numbers '
        'crossfade', () {
      final scene = c.buildTransition(
        from: 0,
        to: 1,
        ms: 400,
        width: 800,
        height: 400,
      );

      expect(scene.glyphs, isNotEmpty);
      expect(scene.lines, isEmpty);
      expect(scene.gutter, isNotEmpty);
    });

    test('when a lexeme moves then it is between its rows halfway', () {
      final start = c.buildTransition(
        from: 0,
        to: 1,
        ms: 0,
        width: 800,
        height: 400,
      );
      final mid = c.buildTransition(
        from: 0,
        to: 1,
        ms: 400,
        width: 800,
        height: 400,
      );
      double yOf(CodeScene s) =>
          s.glyphs.firstWhere((g) => g.text == 'b').baseline;

      expect(yOf(mid), lessThan(yOf(start)));
    });
  });

  group('Given an instant transition', () {
    test('when halfway then the target crossfades over the source', () {
      final c = _composer(
        ['a', 'b'],
        data: {
          'typing': {'mode': 'instant'},
        },
      );

      final scene = c.buildTransition(
        from: 0,
        to: 1,
        ms: 100,
        width: 800,
        height: 400,
      );

      expect(scene.opacity, closeTo(0.5, 1e-9));
      expect(scene.underlay, isNotNull);
      expect(scene.underlay!.stateIndex, 0);
    });
  });
}
