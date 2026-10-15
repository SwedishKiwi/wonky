import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/history.dart';
import 'package:wonky_slides_core/testing.dart';

String _summary({
  List<String> kinds = const [],
  List<String> slides = const [],
  List<String> elements = const [],
  Map<String, List<String>> deleted = const {},
  Map<String, List<String>> revived = const {},
  bool overflow = false,
}) => jsonEncode({
  'v': 1,
  'kinds': kinds,
  'slides': slides,
  'elements': elements,
  'deleted': deleted,
  'revived': revived,
  if (overflow) 'slidesOverflow': true,
});

void main() {
  group('Given change-log rows of Anna (1) and Bo (2)', () {
    late SlidesVersionChangesBuilder b;
    setUp(() => b = SlidesVersionChangesBuilder());

    test('when both edit a slide then the later author is its latest', () {
      b
        ..add(_summary(slides: ['s1'], elements: ['e1']), 1)
        ..add(_summary(slides: ['s1']), 2);

      final c = b.build();

      expect(c.slides['s1'], [1, 2]);
      expect(c.latestOfSlide('s1'), 2);
      expect(c.latestOfElement('e1'), 1);
    });

    test('when Anna edits again then she moves to the end', () {
      b
        ..add(_summary(slides: ['s1']), 1)
        ..add(_summary(slides: ['s1']), 2)
        ..add(_summary(slides: ['s1']), 1);

      expect(b.build().slides['s1'], [2, 1]);
    });

    test('when rows delete and revive ids then those are attributed too', () {
      b
        ..add(
          _summary(
            deleted: {
              'slides': ['s9'],
              'groups': ['g1'],
            },
          ),
          1,
        )
        ..add(
          _summary(
            revived: {
              'elements': ['e7'],
            },
          ),
          2,
        );

      final c = b.build();

      expect(c.slides['s9'], [1]);
      expect(c.groups['g1'], [1]);
      expect(c.elements['e7'], [2]);
    });

    test('when a row changes the theme and the deck then their authors are '
        'listed', () {
      b.add(_summary(kinds: ['theme', 'deck']), 2);

      final c = b.build();

      expect(c.theme, [2]);
      expect(c.deck, [2]);
      expect(c.authors, {2});
    });

    test(
      'when Anna edits through MCP then she is listed as an agent author',
      () {
        b
          ..add(_summary(slides: ['s1']), 1, actorKind: 'mcp')
          ..add(_summary(slides: ['s2']), 2);

        expect(b.build().agents, {
          1: {'mcp'},
        });
      },
    );

    test('when a summary overflowed or is malformed then the result is '
        'approximate', () {
      b.add(_summary(overflow: true), 1);
      expect(b.build().approx, isTrue);

      final c = SlidesVersionChangesBuilder()..add('{nope', 1);
      expect(c.build().approx, isTrue);
    });

    test('when encoded and parsed then the changes are the same', () {
      b
        ..add(_summary(slides: ['s1'], elements: ['e1'], kinds: ['theme']), 1)
        ..add(_summary(slides: ['s1']), 2, actorKind: 'ai');

      final c = SlidesVersionChanges.parse(b.build().encode());

      expect(c.slides, {
        's1': [1, 2],
      });
      expect(c.elements, {
        'e1': [1],
      });
      expect(c.theme, [1]);
      expect(c.agents, {
        2: {'ai'},
      });
    });
  });

  group('Given malformed changes JSON', () {
    for (final json in [null, '', 'x', '[1]', '{"slides": 3}']) {
      test('when parsing "$json" then the changes are empty', () {
        final c = SlidesVersionChanges.parse(json);
        expect(c.slides, isEmpty);
        expect(c.authors, isEmpty);
      });
    }
  });

  group('Given a deck with a group', () {
    test('when listing its slides then each has its title, group and skip', () {
      final b = DeckBuilder();
      final g = b.group('Intro');
      final s1 = b.slide(groupId: g, title: 'Welcome\nsecond line');
      final s2 = b.slide(title: 'Agenda', skipped: true);

      final list = SnapshotSlideEntry.listOf(b.build());

      expect([for (final s in list) s.id], [s1, s2]);
      expect(list.first.title, 'Welcome');
      expect(list.first.groupId, g);
      expect(list.first.groupTitle, 'Intro');
      expect(list.last.skipped, isTrue);
      expect(
        jsonDecode(SnapshotSlideEntry.encodeList(b.build())),
        hasLength(2),
      );
    });
  });
}
