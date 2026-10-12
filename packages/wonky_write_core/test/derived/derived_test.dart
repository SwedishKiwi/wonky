import 'package:test/test.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

Delta d(List<Map<String, dynamic>> json) => Delta.fromJson(json);

void main() {
  group('Given a document with nested headings', () {
    final doc = d([
      {'insert': 'Intro'},
      {
        'insert': '\n',
        'attributes': {'header': 1},
      },
      {'insert': 'text\nPlan'},
      {
        'insert': '\n',
        'attributes': {'header': 2},
      },
      {'insert': 'more\nIntro'},
      {
        'insert': '\n',
        'attributes': {'header': 1},
      },
      {'insert': 'end\n'},
    ]);

    test(
      'when extracting the outline then sections end at the next same-or-higher heading',
      () {
        final outline = const OutlineExtractor().outline(doc);

        expect(
          outline.map(
            (e) => (e.level, e.text, e.sectionStart, e.sectionLength),
          ),
          [(1, 'Intro', 0, 21), (2, 'Plan', 11, 10), (1, 'Intro', 21, 10)],
        );
      },
    );

    test(
      'when extracting the outline then duplicate headings get unique anchors',
      () {
        final outline = const OutlineExtractor().outline(doc);

        expect(outline.map((e) => e.anchorId), [
          'h-intro-1',
          'h-plan-1',
          'h-intro-2',
        ]);
      },
    );
  });

  group('Given a mixed document', () {
    final doc = d([
      {'insert': 'Hello wonderful world'},
      {
        'insert': '\n',
        'attributes': {'header': 1},
      },
      {'insert': "It's a test, isn't it?\n"},
      {'insert': '中文字'},
      {
        'insert': '\n',
        'attributes': {'list': 'bullet'},
      },
      {
        'insert': {
          'image': {'id': 'i', 'src': 'https://x/y.png', 'alt': ''},
        },
      },
      {'insert': '\nline1'},
      {
        'insert': '\n',
        'attributes': {'code-block': 'dart'},
      },
      {'insert': 'line2'},
      {
        'insert': '\n',
        'attributes': {'code-block': 'dart'},
      },
      {'insert': '\n'},
    ]);

    test(
      'when computing stats then words, characters and blocks are counted',
      () {
        final s = const DocumentStatsCalculator().stats(doc);

        expect(
          (
            s.words,
            s.headings,
            s.listItems,
            s.images,
            s.codeBlocks,
            s.paragraphs,
          ),
          (3 + 5 + 3 + 2, 1, 1, 1, 1, 4),
        );
        expect(s.characters, 21 + 22 + 3 + 5 + 5);
        expect(s.charactersNoSpaces, 19 + 18 + 3 + 10);
        expect(s.readingTimeMinutes, 1);
      },
    );

    test('when computing stats of a range then only that range is counted', () {
      final s = const DocumentStatsCalculator().stats(doc, start: 6, length: 9);

      expect((s.words, s.characters), (1, 9));
    });
  });
}
