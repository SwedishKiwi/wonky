import 'package:test/test.dart';
import 'package:wonky_slides_core/markdown.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/testing.dart';

const _outline = '''
<!-- deck: title="Q3 Review" -->
<!-- group: Intro color=blue -->
# Q3 Review
Subtitle line
---
<!-- layout: titleBody -->
## Highlights
- Revenue up 18 %
  - EMEA +25 %
- 3 new customers
Notes:
Mention the EMEA team.
---
<!-- group: Demo -->
<!-- skip -->
<!-- transition: fade -->
## The new API
```dart
final user = await client.users.get(id);
// --- not a separator
```
---
<!-- group: none -->
## Compare
- Left
|||
- Right
---
## By the numbers
| Region | Growth |
| --- | --- |
| EMEA | 25 % |
---
## Photo
![A cat](wonky-file://0192a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b)
---
## Big
4,200
???
Open with the number.
''';

void main() {
  group('Given an outline with directives, notes, code, tables and images', () {
    final outline = DeckOutlineCodec.parse(_outline);

    test('when parsing then every slide and the deck title are read', () {
      expect(outline.title, 'Q3 Review');
      expect(outline.slides, hasLength(7));
    });

    test('when parsing the first slide then the group starts and the body '
        'line is kept', () {
      final s = outline.slides[0];
      expect(s.groupTitle, 'Intro');
      expect(s.groupColor, 'blue');
      expect(s.title, 'Q3 Review');
      expect(s.titleLevel, 1);
      expect(s.body(), 'Subtitle line');
      expect(s.inferLayout(first: true), 'titleBody');
    });

    test('when parsing notes then they end the slide body', () {
      final s = outline.slides[1];
      expect(s.layout, 'titleBody');
      expect(s.body(), '- Revenue up 18 %\n  - EMEA +25 %\n- 3 new customers');
      expect(s.notes, 'Mention the EMEA team.');
    });

    test('when parsing a fenced block then it is code and a --- inside '
        'does not split the slide', () {
      final s = outline.slides[2];
      expect(s.groupTitle, 'Demo');
      expect(s.skipped, isTrue);
      expect(s.transition, 'fade');
      expect(s.code.single.language, 'dart');
      expect(s.code.single.code, contains('--- not a separator'));
      expect(s.inferLayout(), 'code');
    });

    test('when parsing ||| then the body has two columns', () {
      final s = outline.slides[3];
      expect(s.groupNone, isTrue);
      expect(s.columns, hasLength(2));
      expect(s.body(1), '- Right');
      expect(s.inferLayout(), 'twoColumns');
    });

    test('when parsing a table, an image and a big number then each is '
        'recognized', () {
      expect(outline.slides[4].tables.single, [
        ['Region', 'Growth'],
        ['EMEA', '25 %'],
      ]);
      expect(outline.slides[5].images.single.alt, 'A cat');
      expect(outline.slides[5].inferLayout(), 'imageRight');
      expect(outline.slides[6].inferLayout(), 'bigNumber');
      expect(outline.slides[6].notes, 'Open with the number.');
    });

    test('when a slide has only a title then title or section is chosen', () {
      final o = DeckOutlineCodec.parse('# Hello\n---\n## Part 2');
      expect(o.slides[0].inferLayout(first: true), 'title');
      expect(o.slides[1].inferLayout(), 'section');
    });
  });

  group('Given a deck model', () {
    test('when writing the outline then titles, bodies, groups, layouts, '
        'skip and notes are written and parse back', () {
      final b = DeckBuilder();
      final g = b.group('Intro', color: 'blue');
      b.slide(layoutKey: 'title', title: 'Kickoff', groupId: g);
      b.slide(title: 'Agenda', body: 'Goals', notes: 'Say hi', skipped: true);
      final model = b.build();

      final md = DeckOutlineCodec.write(model);
      final back = DeckOutlineCodec.parse(md);

      expect(md, contains('<!-- group: Intro color=blue -->'));
      expect(md, contains('<!-- layout: title -->'));
      expect(md, contains('# Kickoff'));
      expect(md, contains('<!-- group: none -->'));
      expect(back.slides, hasLength(2));
      expect(back.slides[1].title, 'Agenda');
      expect(back.slides[1].body(), 'Goals');
      expect(back.slides[1].notes, 'Say hi');
      expect(back.slides[1].skipped, isTrue);
      expect(back.slides[1].layout, 'titleBody');
      expect(model.slides, hasLength(2));
    });

    test('when a slide has a code element then it is written as a fence', () {
      final b = DeckBuilder();
      final s = b.slide(layoutKey: 'titleOnly', title: 'Code');
      b.codeBlock(s, states: ['print(1);']);

      final md = DeckOutlineCodec.write(b.build());

      expect(md, contains('```dart\nprint(1);\n```'));
      expect(ElementKind.code.name, 'code');
    });
  });
}
