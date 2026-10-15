import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/find.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';

/// A deck: slide 1 (title "Plan the plan", a text box "plan B" and a
/// grouped shape "Planet"), slide 2 (skipped, table cells "plan" / "x",
/// notes "Plan notes").
({DeckModel model, String s1, String s2, String box, String shape}) _fixture() {
  final b = DeckBuilder();
  final s1 = b.slide(layoutKey: 'title', title: 'Plan the plan');
  // Explicit z-order after the placeholders (their own key space).
  final box = b.element(
    s1,
    ElementKind.text,
    columns: {SlidesCols.text: deltaOf('plan B'), ElementCols.zKey: 'a5'},
  );
  final g = b.ids.newId();
  final shape = b.shape(s1, text: 'Planet', parentId: g);
  b.element(s1, ElementKind.group, id: g, columns: {ElementCols.zKey: 'a6'});
  final s2 = b.slide(layoutKey: 'blank', notes: 'Plan notes', skipped: true);
  final (t, rows, cols) = b.table(s2);
  b.cell(t, rows[0], cols[0], 'plan');
  b.cell(t, rows[1], cols[1], 'x');
  return (model: b.build(), s1: s1, s2: s2, box: box, shape: shape);
}

void main() {
  group(
    'Given a deck with text in titles, boxes, groups, tables and notes',
    () {
      final f = _fixture();

      test('when searching "plan" then every body is found in presentation '
          'order, notes after the slide\'s elements', () {
        final m = DeckFind.search(f.model, 'plan', const DeckFindOptions());
        expect(
          [for (final x in m) (x.slideId == f.s1 ? 1 : 2, x.text)],
          [
            (1, 'Plan'),
            (1, 'plan'),
            (1, 'plan'),
            (1, 'Plan'),
            (2, 'plan'),
            (2, 'Plan'),
          ],
        );
        expect(m[2].target, isA<ElementText>());
        expect((m[2].target as ElementText).elementId, f.box);
        expect((m[3].target as ElementText).elementId, f.shape);
        expect(m[4].target, isA<CellText>());
        expect(m[5].target, isA<NotesText>());
      });

      test('when matching case then only exact case matches', () {
        final m = DeckFind.search(
          f.model,
          'Plan',
          const DeckFindOptions(matchCase: true),
        );
        expect([for (final x in m) x.text], ['Plan', 'Plan', 'Plan']);
      });

      test('when matching whole words then "Planet" is not a match', () {
        final m = DeckFind.search(
          f.model,
          'plan',
          const DeckFindOptions(wholeWords: true),
        );
        expect(m.length, 5);
        expect(m.any((x) => x.elementId == f.shape), isFalse);
      });

      test('when notes and skipped slides are excluded then they are not '
          'searched', () {
        expect(
          DeckFind.search(
            f.model,
            'plan',
            const DeckFindOptions(includeNotes: false),
          ).any((m) => m.inNotes),
          isFalse,
        );
        expect(
          DeckFind.search(
            f.model,
            'plan',
            const DeckFindOptions(includeSkipped: false),
          ).any((m) => m.slideId == f.s2),
          isFalse,
        );
      });

      test('when the scope is the current slide then only it is searched', () {
        final m = DeckFind.search(
          f.model,
          'plan',
          DeckFindOptions(scope: FindScope.currentSlide, slideIds: [f.s2]),
        );
        expect(m.every((x) => x.slideId == f.s2), isTrue);
        expect(m.length, 2);
      });

      test('when using a regular expression then groups match', () {
        final m = DeckFind.search(
          f.model,
          r'pla(n)\s(\w)',
          const DeckFindOptions(useRegex: true),
        );
        expect([for (final x in m) x.text], ['Plan t', 'plan B', 'Plan n']);
        final re = DeckFind.pattern(
          r'pla(n)\s(\w)',
          const DeckFindOptions(useRegex: true),
        )!;
        expect(
          DeckFind.expand('plan B', r'[$2$1$$]', re, useRegex: true),
          r'[Bn$]',
        );
      });

      test('when the regular expression is invalid then pattern throws', () {
        expect(
          () => DeckFind.pattern('(', const DeckFindOptions(useRegex: true)),
          throwsFormatException,
        );
      });
    },
  );

  group('Given a formatted body', () {
    final json = jsonEncode([
      {'insert': 'Hello '},
      {
        'insert': 'big',
        'attributes': {'bold': true},
      },
      {'insert': ' world'},
      {
        'insert': '\n',
        'attributes': {'list': 'bullet'},
      },
      {'insert': 'big again\n'},
    ]);

    test('when replacing ranges then the replacement keeps the first '
        'character\'s inline attributes and paragraph attributes stay', () {
      final out = DeckFind.replaceRanges(json, [
        (6, 3, 'small'),
        (16, 3, 'tiny'),
      ]);
      expect(jsonDecode(out), [
        {'insert': 'Hello '},
        {
          'insert': 'small',
          'attributes': {'bold': true},
        },
        {'insert': ' world'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'tiny again\n'},
      ]);
    });

    test('when replacing with an empty text then the range is deleted', () {
      final out = DeckFind.replaceRanges(json, [(5, 4, '')]);
      expect(DeckFind.plainOf(out), 'Hello world\nbig again');
    });
  });
}
