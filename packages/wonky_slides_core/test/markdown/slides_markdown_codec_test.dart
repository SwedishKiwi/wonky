import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/markdown.dart';

List<Object?> _ops(String json) => jsonDecode(json) as List<Object?>;

void main() {
  group('Given Markdown bodies', () {
    test('when converting bullets, numbers and checklists then lists, '
        'indents and listStart are set', () {
      final r = SlidesMarkdownCodec.toDelta(
        '- Revenue up\n  - EMEA +25 %\n3. Third\n4. Fourth\n- [x] Done\n'
        '- [ ] Open',
      );

      expect(_ops(r.deltaJson), [
        {'insert': 'Revenue up'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'EMEA +25 %'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 1},
        },
        {'insert': 'Third'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered', 'listStart': 3},
        },
        {'insert': 'Fourth'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'Done'},
        {
          'insert': '\n',
          'attributes': {'list': 'check'},
        },
        {'insert': 'Open'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
      ]);
      expect(r.warnings, isEmpty);
    });

    test('when converting inline formatting, headings and quotes then the '
        'attributes and paragraph styles are set', () {
      final r = SlidesMarkdownCodec.toDelta(
        '# Big\n## Head\n> Wise words\n**bold** *it* ~~gone~~ `x` '
        '[site](https://example.com)',
      );

      final ops = _ops(r.deltaJson);
      Matcher op(String text, Map<String, Object?> attrs) =>
          anyElement(equals({'insert': text, 'attributes': attrs}));
      expect(ops, op('bold', {'bold': true}));
      expect(ops, op('it', {'italic': true}));
      expect(ops, op('gone', {'strike': true}));
      expect(ops, op('x', {'code': true}));
      expect(ops, op('site', {'link': 'https://example.com'}));
      expect(
        ops,
        containsAllInOrder([
          {
            'insert': '\n',
            'attributes': {'style': 'title'},
          },
          {
            'insert': '\n',
            'attributes': {'style': 'heading'},
          },
          {
            'insert': '\n',
            'attributes': {'style': 'quote'},
          },
        ]),
      );
    });

    test('when converting images, code fences and tables then they are '
        'dropped with markdown_flattened', () {
      final r = SlidesMarkdownCodec.toDelta(
        'Intro ![x](https://a.b/c.png)\n```dart\nmain();\n```\n| a | b |',
      );

      expect(SlidesMarkdownCodec.toPlain(r.deltaJson), 'Intro');
      expect(r.warnings, [SlidesMarkdownWarnings.flattened]);
    });

    test('when converting a hard break then the paragraph holds a soft '
        'break', () {
      final r = SlidesMarkdownCodec.toDelta('one\\\ntwo\nthree');

      expect(SlidesMarkdownCodec.toPlain(r.deltaJson), 'one two\nthree');
    });

    test('when converting slide links then the resolver maps them and '
        'unresolved ones are dropped with a warning', () {
      final r = SlidesMarkdownCodec.toDelta(
        '[next](slide:2) and [gone](slide:9)',
        slideLink: (t) => t == '2' ? 'slide:${'A' * 22}' : null,
      );

      final ops = _ops(r.deltaJson);
      expect(ops.first, {
        'insert': 'next',
        'attributes': {'link': 'slide:${'A' * 22}'},
      });
      expect(r.warnings, [SlidesMarkdownWarnings.slideLink]);
    });

    test('when converting notes then attributes outside the notes schema '
        'are dropped', () {
      final r = SlidesMarkdownCodec.toDelta('# Head\n- point', notes: true);

      expect(_ops(r.deltaJson), [
        {'insert': 'Head\npoint'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ]);
    });
  });

  group('Given bodies written back as Markdown', () {
    const cases = [
      '- Revenue up 18 %\n  - EMEA +25 %\n- 3 new customers',
      '# Title line\n## Heading\n### Sub\n> A quote',
      '1. one\n2. two\n   plain after',
      '**bold** and *italic* and ~~strike~~ and `code`',
      '[Wonky](https://wonky.example/a) - mail [me](mailto:a@b.co)',
      '- [x] done\n- [ ] open',
      '5. five\n6. six',
      'line one\\\nline two',
      r'Price \*not\* bold and 1\. not a list',
    ];
    for (final md in cases) {
      test('when round-tripping "${md.replaceAll('\n', r'\n')}" then the '
          'body is unchanged', () {
        final first = SlidesMarkdownCodec.toDelta(md);
        final written = SlidesMarkdownCodec.toMarkdown(first.deltaJson);
        final second = SlidesMarkdownCodec.toDelta(written);

        expect(second.deltaJson, first.deltaJson);
      });
    }

    test('when writing a slide link then the mapper names the target', () {
      final d = SlidesMarkdownCodec.toDelta(
        '[go](slide:3)',
        slideLink: (_) => 'slide:${'B' * 22}',
      );

      final md = SlidesMarkdownCodec.toMarkdown(
        d.deltaJson,
        slideLink: (b62) => b62 == 'B' * 22 ? '3' : b62,
      );

      expect(md, '[go](slide:3)');
    });

    test('when reading rich text then runs and paragraphs carry every '
        'attribute', () {
      final json = jsonEncode([
        {
          'insert': 'Hi',
          'attributes': {'color': '#ff0000', 'bold': true},
        },
        {
          'insert': '\n',
          'attributes': {'align': 'center'},
        },
      ]);

      final rich = SlidesMarkdownCodec.toRich(json);

      expect(rich['markdown'], '**Hi**');
      expect(rich['runs'], [
        {
          'start': 0,
          'length': 2,
          'attrs': {'color': '#ff0000', 'bold': true},
        },
      ]);
      expect(rich['paragraphs'], [
        {
          'index': 0,
          'attrs': {'align': 'center'},
        },
      ]);
    });
  });

  group('Given formatted text replaced by Markdown', () {
    final old = jsonEncode([
      {
        'insert': 'Old',
        'attributes': {'color': '#112233', 'size': 48},
      },
      {
        'insert': '\n',
        'attributes': {'align': 'center'},
      },
    ]);

    test('when keeping formatting then the first run\'s attributes and '
        'paragraph alignment carry over', () {
      final next = SlidesMarkdownCodec.toDelta('**New**\nSecond').deltaJson;

      final kept = SlidesMarkdownCodec.keepFormatting(old, next);

      expect(_ops(kept), [
        {
          'insert': 'New',
          'attributes': {'bold': true, 'color': '#112233', 'size': 48},
        },
        {
          'insert': '\n',
          'attributes': {'align': 'center'},
        },
        {
          'insert': 'Second',
          'attributes': {'color': '#112233', 'size': 48},
        },
        {
          'insert': '\n',
          'attributes': {'align': 'center'},
        },
      ]);
    });

    test('when appending then the new paragraphs follow the old ones', () {
      final next = SlidesMarkdownCodec.toDelta('More').deltaJson;

      final joined = SlidesMarkdownCodec.concat(old, next);

      expect(SlidesMarkdownCodec.toPlain(joined), 'Old\nMore');
    });
  });
}
