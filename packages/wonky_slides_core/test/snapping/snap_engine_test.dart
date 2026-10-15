import 'package:test/test.dart';
import 'package:wonky_slides_core/snapping.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

void main() {
  const slide = SuRect(0, 0, 1920, 1080);

  group('Given an empty slide', () {
    final t = SnapTargets(slide: slide);

    test('when a box moves near the left edge then it snaps to it', () {
      final r = SnapEngine.snapMove(const SuRect(4, 300, 200, 100), t, 6);

      expect(r.dx, -4);
      expect(r.snappedX, isTrue);
      expect(r.snappedY, isFalse);
    });

    test('when a box is centered within the threshold then it snaps to the '
        'slide center and shows a dashed center guide', () {
      // Center 963 → 960.
      final r = SnapEngine.snapMove(const SuRect(863, 300, 200, 100), t, 6);

      expect(r.dx, -3);
      final g = r.guides.singleWhere((g) => g.axis == SnapAxis.x);
      expect(g.at, 960);
      expect(g.dashed, isTrue);
      expect((g.from, g.to), (0, 1080));
    });

    test('when a box is farther than the threshold then nothing snaps', () {
      final r = SnapEngine.snapMove(const SuRect(500, 500, 100, 100), t, 6);

      expect((r.dx, r.dy), (0, 0));
      expect(r.guides, isEmpty);
      expect(r.spacings, isEmpty);
    });

    test('when the x axis is locked then only y snaps', () {
      final r = SnapEngine.snapMove(
        const SuRect(3, 2, 100, 100),
        t,
        6,
        lockX: true,
      );

      expect((r.dx, r.dy), (0, -2));
    });
  });

  group('Given another element', () {
    final t = SnapTargets(
      slide: slide,
      boxes: const [SnapBox('a', SuRect(300, 100, 200, 100))],
    );

    test('when a box moves with its left edge near the element\'s right edge '
        'then it snaps and the guide spans both boxes with markers', () {
      final r = SnapEngine.snapMove(const SuRect(503, 400, 100, 50), t, 6);

      expect(r.dx, -3);
      final g = r.guides.singleWhere((g) => g.axis == SnapAxis.x);
      expect((g.at, g.from, g.to), (500, 100, 450));
      expect(g.marks, containsAll([100.0, 200.0, 400.0, 450.0]));
    });

    test('when the nearest line is an element center then it wins over a '
        'farther edge', () {
      // Box center 402 vs element center 400 (d = -2); left 352 vs nothing.
      final r = SnapEngine.snapMove(const SuRect(352, 400, 100, 50), t, 6);

      expect(r.dx, -2);
    });

    test('when objects are off then neither the element nor the slide '
        'snaps', () {
      final off = SnapTargets(
        slide: slide,
        boxes: const [SnapBox('a', SuRect(300, 100, 200, 100))],
        objects: false,
      );

      final r = SnapEngine.snapMove(const SuRect(503, 2, 100, 50), off, 6);

      expect((r.dx, r.dy), (0, 0));
    });
  });

  group('Given user guides', () {
    const guides = [
      UserGuide(GuideAxis.vertical, 700),
      UserGuide(GuideAxis.horizontal, 333),
    ];

    test('when a box moves near them then it snaps to both', () {
      final t = SnapTargets(slide: slide, guides: guides);

      final r = SnapEngine.snapMove(const SuRect(697, 336, 100, 100), t, 6);

      expect((r.dx, r.dy), (3, -3));
    });

    test('when snapping to guides is off then they are ignored', () {
      final t = SnapTargets(slide: slide, guides: guides, guidesOn: false);

      final r = SnapEngine.snapMove(const SuRect(697, 336, 100, 100), t, 6);

      expect((r.dx, r.dy), (0, 0));
    });

    test('when a guide and an element line are equally near then the guide '
        'wins (priority order)', () {
      final t = SnapTargets(
        slide: slide,
        guides: const [UserGuide(GuideAxis.vertical, 704)],
        boxes: const [SnapBox('a', SuRect(696, 800, 100, 100))],
      );

      final r = SnapEngine.snapMove(const SuRect(700, 300, 50, 50), t, 6);

      expect(r.dx, 4);
    });
  });

  group('Given two elements in a row with a 100 su gap', () {
    final t = SnapTargets(
      slide: slide,
      boxes: const [
        SnapBox('a', SuRect(100, 500, 200, 100)),
        SnapBox('b', SuRect(400, 500, 200, 100)),
      ],
    );

    test('when a third box moves to about 100 su right of the second then it '
        'snaps to the equal gap and shows both gaps', () {
      final r = SnapEngine.snapMove(const SuRect(704, 520, 150, 60), t, 6);

      expect(r.dx, -4);
      final s = r.spacings.singleWhere((s) => s.axis == SnapAxis.x);
      expect(s.distance, 100);
      expect(
        s.gaps.map((g) => (g.start, g.end)),
        unorderedEquals([(300.0, 400.0), (600.0, 700.0)]),
      );
    });

    test('when a box moves between two neighbors then it snaps to the '
        'centered position (equal gaps on both sides)', () {
      final wide = SnapTargets(
        slide: slide,
        boxes: const [
          SnapBox('a', SuRect(100, 500, 200, 100)),
          SnapBox('b', SuRect(900, 500, 200, 100)),
        ],
      );

      // Centered: x = (300 + 900 - 200) / 2 = 500.
      final r = SnapEngine.snapMove(const SuRect(504, 480, 200, 100), wide, 6);

      expect(r.dx, -4);
      expect(r.spacings.single.distance, 200);
    });

    test('when the box is in another row then equal spacing does not '
        'apply', () {
      final r = SnapEngine.snapMove(const SuRect(704, 800, 150, 60), t, 6);

      expect(r.dx, 0);
      expect(r.spacings, isEmpty);
    });
  });

  group('Given a resize', () {
    final t = SnapTargets(
      slide: slide,
      boxes: const [SnapBox('a', SuRect(1000, 100, 300, 120))],
    );

    test('when the right edge nears another element\'s left edge then it '
        'snaps', () {
      final r = SnapEngine.snapResize(
        const SuRect(500, 600, 497, 100),
        t,
        6,
        right: true,
      );

      expect(r.rect.right, 1000);
      expect(r.rect.x, 500);
      expect(r.snappedX, isTrue);
    });

    test('when the width nears another element\'s width then it snaps to the '
        'equal size and reports the match', () {
      final r = SnapEngine.snapResize(
        const SuRect(200, 600, 303, 100),
        t,
        6,
        right: true,
      );

      expect(r.rect.width, 300);
      expect(r.sizes.map((s) => s.axis), everyElement(SnapAxis.x));
      expect(r.sizes, hasLength(2));
    });

    test('when the left edge is dragged then only the left edge moves', () {
      final r = SnapEngine.snapResize(
        const SuRect(3, 600, 290, 100),
        t,
        6,
        left: true,
      );

      expect((r.rect.x, r.rect.right), (0, 293));
    });
  });

  group('Given connection sites', () {
    final t = SnapTargets(
      slide: slide,
      sites: const [SnapSite('s', 'right', 500, 300)],
    );

    test('when an endpoint comes within the threshold then it glues to the '
        'site', () {
      final r = SnapEngine.snapPoint(503, 297, t, 6);

      expect((r.x, r.y), (500, 300));
      expect(r.site?.site, 'right');
    });

    test('when gluing is off then the point snaps to lines only', () {
      final r = SnapEngine.snapPoint(3, 297, t, 6, glue: false);

      expect((r.x, r.y), (0, 297));
      expect(r.site, isNull);
    });
  });

  group('Given rotation snapping', () {
    final cases = [
      (44.0, false, false, 44.0),
      (88.0, false, false, 90.0),
      (-2.0, false, false, 0.0),
      (88.0, false, true, 88.0),
      (37.0, true, false, 30.0),
      (38.0, true, false, 45.0),
      (359.0, true, false, 0.0),
    ];
    for (final (deg, shift, free, expected) in cases) {
      test('when rotating to $deg° (shift: $shift, free: $free) then the '
          'angle is $expected°', () {
        expect(SnapEngine.snapAngle(deg, shift: shift, free: free), expected);
      });
    }
  });

  group('Given 500 elements', () {
    final boxes = [
      for (var i = 0; i < 500; i++)
        SnapBox(
          'e$i',
          SuRect((i * 37) % 1800, (i * 53) % 1000, 40 + i % 60, 30 + i % 40),
        ),
    ];

    test('when snapping a move then one query takes well under 2 ms', () {
      final t = SnapTargets(slide: slide, boxes: boxes);
      final sw = Stopwatch()..start();
      const n = 200;
      for (var i = 0; i < n; i++) {
        SnapEngine.snapMove(
          SuRect(100.0 + i * 7, 200.0 + i * 3, 120, 80),
          t,
          6,
        );
      }
      sw.stop();

      expect(sw.elapsedMicroseconds / n, lessThan(2000));
    });
  });

  group('Given scale-dependent thresholds', () {
    test('when zoomed to 50 % then 6 px are 12 su', () {
      expect(SnapEngine.thresholdFor(0.5), 12);
    });
  });
}
