import 'package:test/test.dart';
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/pdf.dart';
import 'package:wonky_slides_core/testing.dart';

void main() {
  group('Given a deck with a group, a skipped slide and a skipped group', () {
    late DeckModel deck;
    late String intro, s1, s2, s3, s4, s5;
    setUp(() {
      final b = DeckBuilder();
      s1 = b.slide(title: 'One');
      intro = b.group('Intro');
      s2 = b.slide(title: 'Two', groupId: intro);
      s3 = b.slide(title: 'Three', groupId: intro, skipped: true);
      final hidden = b.group('Hidden', skipped: true);
      s4 = b.slide(title: 'Four', groupId: hidden);
      s5 = b.slide(title: 'Five');
      deck = b.build();
    });

    List<String> ids(SlidesPdfSelection s) => [
      for (final x in s.slides) x.slideId,
    ];

    test('when selecting all then skipped slides and groups are left out', () {
      final s = SlidesPdfPlanner.select(deck, const SlidesPdfOptions());

      expect(ids(s), [s1, s2, s5]);
      expect(s.warnings, isEmpty);
    });

    test('when including skipped slides then every slide is in deck order', () {
      final s = SlidesPdfPlanner.select(
        deck,
        const SlidesPdfOptions(includeSkipped: true),
      );

      expect(ids(s), [s1, s2, s3, s4, s5]);
    });

    test(
      'when selecting positions "2-3,5" then those slides minus skipped',
      () {
        final s = SlidesPdfPlanner.select(
          deck,
          const SlidesPdfOptions(range: '2-3,5'),
        );

        expect(ids(s), [s2, s5]);
      },
    );

    test('when selecting a group then only its slides', () {
      final s = SlidesPdfPlanner.select(
        deck,
        SlidesPdfOptions(groupIds: [intro], includeSkipped: true),
      );

      expect(ids(s), [s2, s3]);
    });

    test('when selecting explicit slide ids then skipped ones are kept', () {
      final s = SlidesPdfPlanner.select(
        deck,
        SlidesPdfOptions(slideIds: [s5, s3]),
      );

      expect(ids(s), [s3, s5]);
    });

    test('when the range is "current" without slide ids then every slide is '
        'exported with a warning', () {
      final s = SlidesPdfPlanner.select(
        deck,
        const SlidesPdfOptions(range: 'current'),
      );

      expect(ids(s), [s1, s2, s5]);
      expect(s.warnings, ['range_unresolved']);
    });

    test(
      'when printing each build stage then a slide gets one page per step',
      () {
        final s = SlidesPdfPlanner.select(
          deck,
          const SlidesPdfOptions(includeBuilds: true),
          stepCounts: (id) => id == s2 ? 2 : 0,
        );

        expect(
          [for (final x in s.slides) x.steps],
          [
            [0],
            [0, 1, 2],
            [0],
          ],
        );
      },
    );

    test('when nothing matches then the selection is empty with a warning', () {
      final s = SlidesPdfPlanner.select(
        deck,
        const SlidesPdfOptions(groupIds: ['nope']),
      );

      expect(s.slides, isEmpty);
      expect(s.warnings, ['empty_selection']);
    });
  });

  group('Given a 16:9 deck of 1920 × 1080 su', () {
    SlidesPdfGeometry geo(SlidesPdfOptions o) =>
        SlidesPdfGeometry(o, slideWidth: 1920, slideHeight: 1080);

    test('when the page is the slide size then it is 960 × 540 pt with the '
        'slide filling it', () {
      final g = geo(const SlidesPdfOptions());

      expect((g.pageWidth, g.pageHeight), (960, 540));
      expect(g.slideBox, const SlidesPdfRect(0, 0, 960, 540));
    });

    test('when printing on Letter then the page is landscape and the slide '
        'is centered inside the margins', () {
      final g = geo(
        const SlidesPdfOptions(
          pageSize: SlidesPdfPageSize.letter,
          margins: SlidesPdfMargins.normal,
        ),
      );

      expect((g.pageWidth, g.pageHeight), (792, 612));
      final box = g.slideBox;
      expect(box.width, closeTo(720, 1e-6));
      expect(box.height, closeTo(405, 1e-6));
      expect(box.x, closeTo(36, 1e-6));
      expect(box.y, closeTo((612 - 405) / 2, 1e-6));
    });

    test('when printing notes then the page is portrait with the slide at 80 % '
        'of the content width', () {
      final g = geo(
        const SlidesPdfOptions().withLayout(
          SlidesPdfLayout.notes,
          locale: 'de',
        ),
      );

      expect((g.pageWidth, g.pageHeight), (595.28, 841.89));
      final s = g.notesSlideBox;
      expect(s.width, closeTo((595.28 - 72) * 0.8, 1e-6));
      final text = g.notesTextArea(continuation: false);
      expect(text.y, greaterThan(s.bottom));
      expect(text.bottom, lessThanOrEqualTo(g.body.bottom + 1e-6));
    });

    for (final (n, cells) in [(1, 1), (2, 2), (3, 3), (4, 4), (6, 6), (9, 9)]) {
      test('when printing $n handouts per page then there are $cells '
          'non-overlapping cells inside the body', () {
        final g = geo(
          SlidesPdfOptions(
            handoutsPerPage: n,
          ).withLayout(SlidesPdfLayout.handouts),
        );
        final boxes = [for (final (s, _) in g.handoutCells()) s];

        expect(boxes, hasLength(cells));
        for (final b in boxes) {
          expect(b.x, greaterThanOrEqualTo(g.body.x - 1e-6));
          expect(b.right, lessThanOrEqualTo(g.body.right + 1e-6));
          expect(b.bottom, lessThanOrEqualTo(g.body.bottom + 1e-6));
          expect(b.width / b.height, closeTo(16 / 9, 1e-6));
        }
        for (var i = 0; i < boxes.length; i++) {
          for (var j = i + 1; j < boxes.length; j++) {
            final a = boxes[i], b = boxes[j];
            final overlap =
                a.x < b.right &&
                b.x < a.right &&
                a.y < b.bottom &&
                b.y < a.bottom;
            expect(overlap, isFalse, reason: 'cells $i and $j overlap');
          }
        }
      });
    }

    test('when ordering 6 handouts vertically then the second slide is below '
        'the first', () {
      final h = geo(
        const SlidesPdfOptions(
          handoutsPerPage: 6,
        ).withLayout(SlidesPdfLayout.handouts),
      ).handoutCells();
      final v = geo(
        const SlidesPdfOptions(
          handoutsPerPage: 6,
          handoutOrderVertical: true,
        ).withLayout(SlidesPdfLayout.handouts),
      ).handoutCells();

      expect(h[1].$1.y, closeTo(h[0].$1.y, 1e-6));
      expect(h[1].$1.x, greaterThan(h[0].$1.x));
      expect(v[1].$1.x, closeTo(v[0].$1.x, 1e-6));
      expect(v[1].$1.y, greaterThan(v[0].$1.y));
    });

    test('when printing 3 handouts per page then ruled lines are right of '
        'each slide', () {
      final cells = geo(
        const SlidesPdfOptions(
          handoutsPerPage: 3,
        ).withLayout(SlidesPdfLayout.handouts),
      ).handoutCells();

      for (final (slide, lines) in cells) {
        expect(lines, isNotNull);
        expect(lines!.x, greaterThan(slide.right));
      }
    });
  });

  group('Given a 4:3 deck', () {
    test('when the page is the slide size then it keeps the aspect', () {
      final g = SlidesPdfGeometry(
        const SlidesPdfOptions(),
        slideWidth: 1440,
        slideHeight: 1080,
      );

      expect((g.pageWidth, g.pageHeight), (720, 540));
    });

    test('when printing on A4 with auto orientation then it is landscape', () {
      final g = SlidesPdfGeometry(
        const SlidesPdfOptions(pageSize: SlidesPdfPageSize.a4),
        slideWidth: 1440,
        slideHeight: 1080,
      );

      expect(g.pageWidth, greaterThan(g.pageHeight));
    });
  });
}
