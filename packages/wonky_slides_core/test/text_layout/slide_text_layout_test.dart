import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  final theme = DeckThemeResolver().resolve(
    BuiltInThemes.package(BuiltInThemes.defaultKey)!.theme,
    SlideAppearance.light,
  );
  ResolvedTextStyles stylesFor({String style = 'body', BoxTextStyle? box}) =>
      TextStyleResolver().resolve(theme, box: box, defaultStyle: style);

  final engine = SlideTextLayout();

  group('Given the shared paragraph model', () {
    test('when splitting a body then paragraphs carry offsets and run '
        'styles', () {
      final body = TextBody([
        {'insert': 'Hello '},
        {
          'insert': 'world',
          'attributes': {'bold': true},
        },
        {'insert': '\nNext\n'},
      ]);

      final paras = TextParagraphs.build(body, stylesFor());

      expect(paras, hasLength(2));
      expect(paras[0].text, 'Hello world');
      expect(paras[0].runs[1].fontWeight, greaterThanOrEqualTo(600));
      expect(paras[0].end, 11);
      expect(paras[1].start, 12);
      expect(paras[1].text, 'Next');
    });

    test('when numbering an ordered list then counters follow levels and '
        'listStart', () {
      Map<String, Object?> li(int indent, {int? start}) => {
        'list': 'ordered',
        'indent': indent,
        'listStart': ?start,
      };
      final body = TextBody([
        {'insert': 'a'},
        {'insert': '\n', 'attributes': li(0)},
        {'insert': 'b'},
        {'insert': '\n', 'attributes': li(1)},
        {'insert': 'c'},
        {'insert': '\n', 'attributes': li(1)},
        {'insert': 'd'},
        {'insert': '\n', 'attributes': li(0)},
        {'insert': 'e'},
        {'insert': '\n', 'attributes': li(0, start: 7)},
      ]);

      final markers = TextParagraphs.build(
        body,
        stylesFor(),
      ).map((p) => p.marker?.text);

      expect(markers, ['1.', 'a.', 'b.', '2.', '7.']);
    });

    test('when bulleting then the theme glyph per level is used and text is '
        'indented', () {
      final body = TextBody([
        {'insert': 'x'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'y'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 1},
        },
      ]);

      final p = TextParagraphs.build(body, stylesFor());

      expect(p[0].marker!.text, '•');
      expect(p[1].marker!.text, '–');
      expect(p[1].textIndent, greaterThan(p[0].textIndent));
      expect(p[1].runs.single.fontSize, lessThan(p[0].runs.single.fontSize));
    });

    test('when formatting list numbers then alpha and roman styles are '
        'correct', () {
      expect(TextParagraphs.formatListNumber(28, 'lowerAlpha'), 'ab');
      expect(TextParagraphs.formatListNumber(14, 'upperRoman'), 'XIV');
      expect(TextParagraphs.formatListNumber(3, 'decimal'), '3');
    });

    test(
      'when caps and scripts apply then the display text and size change',
      () {
        final body = TextBody([
          {
            'insert': 'loud',
            'attributes': {'caps': 'all'},
          },
          {
            'insert': '2',
            'attributes': {'script': 'super'},
          },
          {'insert': '\n'},
        ]);

        final runs = TextParagraphs.build(body, stylesFor()).single.runs;

        expect(runs[0].text, 'LOUD');
        expect(runs[1].baselineShift, greaterThan(0));
        expect(runs[1].fontSize, lessThan(runs[0].fontSize));
      },
    );

    test('when scaling then sizes and spacing scale', () {
      final body = TextBody.plain('Scaled');

      final a = TextParagraphs.build(body, stylesFor()).single;
      final b = TextParagraphs.build(body, stylesFor(), scale: 0.5).single;

      expect(b.runs.single.fontSize, a.runs.single.fontSize / 2);
      expect(b.spaceAfter, a.spaceAfter / 2);
    });
  });

  group('Given the core layout engine', () {
    test('when the text fits then it is one line', () {
      final r = engine.layout(
        TextBody.plain('Short'),
        stylesFor(),
        width: 1000,
      );

      expect(r.lines, hasLength(1));
      expect(r.lines.single.start, 0);
      expect(r.lines.single.end, 5);
      expect(r.height, greaterThan(0));
    });

    test('when the text is wider than the box then it wraps at spaces and '
        'line breaks cover the text', () {
      final r = engine.layout(
        TextBody.plain('one two three four five six seven eight nine ten'),
        stylesFor(),
        width: 300,
      );

      expect(r.lines.length, greaterThan(1));
      for (final l in r.lines) {
        expect(l.width, lessThanOrEqualTo(300.5));
      }
      expect(r.lineBreaks.last, 48);
      expect(r.lines[1].top, greaterThan(r.lines[0].top));
    });

    test(
      'when a word is wider than the box then it breaks inside the word',
      () {
        final r = engine.layout(
          TextBody.plain('Supercalifragilisticexpialidocious'),
          stylesFor(),
          width: 120,
        );

        expect(r.lines.length, greaterThan(2));
        expect(
          r.lines.map((l) => l.runs.map((x) => x.text).join()).join(),
          'Supercalifragilisticexpialidocious',
        );
      },
    );

    test('when centering then the line is offset by half the free space', () {
      final body = TextBody([
        {'insert': 'Hi'},
        {
          'insert': '\n',
          'attributes': {'align': 'center'},
        },
      ]);

      final r = engine.layout(body, stylesFor(), width: 1000);
      final l = r.lines.single;

      expect(l.left, closeTo((1000 - l.width) / 2, 1e-6));
    });

    test('when a soft break is present then the line breaks there', () {
      final r = engine.layout(TextBody.plain('a b'), stylesFor(), width: 1000);

      expect(r.lines, hasLength(2));
    });

    test('when laying out at a smaller scale then the text is shorter', () {
      final body = TextBody.plain('one two three four five six seven eight');

      final full = engine.layout(body, stylesFor(), width: 400);
      final half = engine.layout(body, stylesFor(), width: 400, scale: 0.5);

      expect(half.height, lessThan(full.height));
      expect(half.fitScale, 0.5);
    });

    test('when laying out the same input twice then the cached result is '
        'returned', () {
      final body = TextBody.plain('cache me');

      expect(
        identical(
          engine.layout(body, stylesFor(), width: 500),
          engine.layout(TextBody.plain('cache me'), stylesFor(), width: 500),
        ),
        isTrue,
      );
    });

    test('when a bullet list is laid out then the first line carries the '
        'marker left of the text', () {
      final body = TextBody([
        {'insert': 'item'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ]);

      final l = engine.layout(body, stylesFor(), width: 800).lines.single;

      expect(l.bullet!.text, '•');
      expect(l.left + l.bullet!.x, lessThan(l.left));
    });
  });

  group('Given auto-fit', () {
    final body = TextBody.plain(
      'A long body of text that needs several lines in a narrow box to fit',
    );
    TextLayoutResult at(double s) =>
        engine.layout(body, stylesFor(), width: 300, scale: s);

    test('when shrinking then the scale is a 2.5 % step and the text fits', () {
      final full = at(1);
      final fit = AutoFit.fit(
        layoutAt: at,
        mode: AutoFitMode.shrink,
        available: full.height / 2,
        insetsY: 0,
      );

      expect(fit.scale, lessThan(1));
      expect((fit.scale * 1000).round() % 25, 0);
      expect(fit.contentHeight, lessThanOrEqualTo(full.height / 2 + 0.5));
      expect(fit.layout.overflows, isFalse);
      // The next bigger step would not fit.
      expect(at(fit.scale + 0.025).height, greaterThan(full.height / 2));
    });

    test('when nothing fits then the minimum scale is used and the text '
        'overflows', () {
      final fit = AutoFit.fit(
        layoutAt: at,
        mode: AutoFitMode.shrink,
        available: 1,
        insetsY: 0,
      );

      expect(fit.scale, AutoFit.minScale);
      expect(fit.layout.overflows, isTrue);
    });

    test('when resizing then the box grows to the content', () {
      final full = at(1);
      final fit = AutoFit.fit(
        layoutAt: at,
        mode: AutoFitMode.resize,
        available: 10,
        insetsY: 20,
      );

      expect(fit.boxHeight, full.height + 20);
      expect(fit.scale, 1);
    });

    test('when not fitting then overflow is flagged', () {
      final fit = AutoFit.fit(
        layoutAt: at,
        mode: AutoFitMode.none,
        available: 10,
        insetsY: 0,
      );

      expect(fit.layout.overflows, isTrue);
      expect(fit.boxHeight, 10);
    });

    test('when parsing modes then unknown names use the fallback', () {
      expect(AutoFitMode.fromName('shrink'), AutoFitMode.shrink);
      expect(
        AutoFitMode.fromName(null, fallback: AutoFitMode.resize),
        AutoFitMode.resize,
      );
    });
  });
}
