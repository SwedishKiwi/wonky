import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';

import '../support/scene_fixture.dart';

void main() {
  ConnectorRoute routeOf(SceneFixture f, String lineId, {DeckModel? model}) {
    final slide = f.resolve(model: model);
    final all = {for (final e in slide.painted) e.id: e};
    return ConnectorRouter.route(all[lineId]!, (id) => all[id]);
  }

  group('Given a free straight line', () {
    test('when routing then it runs between the stored endpoints', () {
      final f = SceneFixture();
      final line = f.line(100, 500, 900, 200);

      final r = routeOf(f, line);

      expect(r.points, [(x: 100.0, y: 500.0), (x: 900.0, y: 200.0)]);
      expect(r.startGlued, isFalse);
      expect(r.endGlued, isFalse);
    });

    test(
      'when the frame is flipped horizontally then the endpoints mirror',
      () {
        final f = SceneFixture();
        final line = f.line(100, 100, 300, 200);
        final m = f.model();
        final rec = m.element(line)!;
        final flipped = DeckModel.fromRows(m.deckId, [
          for (final t in m.dump().entries)
            for (final row in t.value.values)
              (t.key, row['id'] == line ? {...row, 'flipH': true} : row),
        ]);
        expect(rec.flipH, isFalse);

        final r = routeOf(f, line, model: flipped);

        expect(r.start, (x: 300.0, y: 100.0));
        expect(r.end, (x: 100.0, y: 200.0));
      },
    );
  });

  group('Given two shapes glued by a connector', () {
    late SceneFixture f;
    late String a, b;
    setUp(() {
      f = SceneFixture();
      a = f.shape(x: 100, y: 400, w: 300, h: 200);
      b = f.shape(x: 1200, y: 100, w: 300, h: 200);
    });

    test('when routing straight then the endpoints are the glued sites, not '
        'the stored points', () {
      final line = f.line(
        0,
        0,
        10,
        10,
        startGlue: (a, 'right'),
        endGlue: (b, 'left'),
      );

      final r = routeOf(f, line);

      expect(r.start, (x: 400.0, y: 500.0));
      expect(r.end, (x: 1200.0, y: 200.0));
      expect(r.startGlued && r.endGlued, isTrue);
    });

    test('when the shape moves then the derived endpoint follows without '
        'writing the line', () {
      final line = f.line(
        0,
        0,
        10,
        10,
        startGlue: (a, 'right'),
        endGlue: (b, 'left'),
      );
      final m = f.model();
      final moved = DeckModel.fromRows(m.deckId, [
        for (final t in m.dump().entries)
          for (final row in t.value.values)
            (t.key, row['id'] == a ? {...row, 'x': 500.0} : row),
      ]);

      final r = routeOf(f, line, model: moved);

      expect(r.start, (x: 800.0, y: 500.0));
      expect(moved.element(line)!.dataJson, m.element(line)!.dataJson);
    });

    test('when the glued element is gone then the stored point is used', () {
      final line = f.line(
        50,
        60,
        70,
        80,
        startGlue: ('00000000-0000-7000-8000-000000000999', 'right'),
      );

      final r = routeOf(f, line);

      expect(r.start, (x: 50.0, y: 60.0));
      expect(r.startGlued, isFalse);
    });

    test('when routing elbow then every segment is axis aligned, it leaves '
        'and enters along the sites and avoids both boxes', () {
      final line = f.line(
        0,
        0,
        10,
        10,
        routing: 'elbow',
        startGlue: (a, 'right'),
        endGlue: (b, 'left'),
      );

      final r = routeOf(f, line);

      for (var i = 1; i < r.points.length; i++) {
        final p = r.points[i - 1], q = r.points[i];
        expect(p.x == q.x || p.y == q.y, isTrue, reason: '$p → $q');
      }
      expect(r.points[1].y, r.points[0].y);
      expect(r.points[1].x, greaterThan(r.points[0].x));
      expect(r.points[r.points.length - 2].y, r.end.y);
      expect(r.points[r.points.length - 2].x, lessThan(r.end.x));
      _expectAvoids(r, const [(100, 400, 300, 200), (1200, 100, 300, 200)]);
    });

    test('when routing elbow between sites facing away then the route goes '
        'around the boxes', () {
      final line = f.line(
        0,
        0,
        10,
        10,
        routing: 'elbow',
        startGlue: (a, 'left'),
        endGlue: (b, 'right'),
      );

      final r = routeOf(f, line);

      expect(r.points.length, greaterThanOrEqualTo(4));
      expect(r.points[1].x, lessThan(100));
      expect(r.points[r.points.length - 2].x, greaterThan(1500));
      _expectAvoids(r, const [(100, 400, 300, 200), (1200, 100, 300, 200)]);
    });

    test('when routing curved then the curve leaves along the start site '
        'direction', () {
      final line = f.line(
        0,
        0,
        10,
        10,
        routing: 'curved',
        startGlue: (a, 'top'),
        endGlue: (b, 'bottom'),
      );

      final r = routeOf(f, line);

      expect(r.points, hasLength(4));
      expect(r.startDirection.x, closeTo(0, 1e-9));
      expect(r.startDirection.y, -1);
      expect(r.endDirection.y, -1);
    });

    test(
      'when a curved connector has a bend point then the curve passes '
      'through it at its middle and still leaves along the sites (SL-44)',
      () {
        final plain = routeOf(
          f,
          f.line(
            0,
            0,
            10,
            10,
            routing: 'curved',
            startGlue: (a, 'right'),
            endGlue: (b, 'left'),
          ),
        );
        final line = f.line(
          0,
          0,
          2000,
          1000,
          routing: 'curved',
          startGlue: (a, 'right'),
          endGlue: (b, 'left'),
          waypoints: const [(700, 800)],
        );

        final r = routeOf(f, line);

        final m = ConnectorRouter.curveMidpoint(r.points);
        expect(m.x, closeTo(700, 1e-6));
        expect(m.y, closeTo(800, 1e-6));
        expect(r.start, plain.start);
        expect(r.end, plain.end);
        expect(
          ConnectorRouter.curveMidpoint(plain.points),
          isNot(ConnectorRouter.curveMidpoint(r.points)),
        );
      },
    );

    test('when an elbow route\'s corners are stored as waypoints then the '
        'same route comes back, and a moved middle segment moves the route '
        '(SL-44 segment handles)', () {
      final plain = routeOf(
        f,
        f.line(
          0,
          0,
          10,
          10,
          routing: 'elbow',
          startGlue: (a, 'right'),
          endGlue: (b, 'left'),
        ),
      );
      final inner = plain.points.sublist(1, plain.points.length - 1);
      final same = routeOf(
        f,
        f.line(
          0,
          0,
          2000,
          1000,
          routing: 'elbow',
          startGlue: (a, 'right'),
          endGlue: (b, 'left'),
          waypoints: [for (final p in inner) (p.x, p.y)],
        ),
      );
      expect(same.points, plain.points);

      // The vertical middle segment moves 100 su right.
      expect(plain.points.length, 4);
      final moved = routeOf(
        f,
        f.line(
          0,
          0,
          2000,
          1000,
          routing: 'elbow',
          startGlue: (a, 'right'),
          endGlue: (b, 'left'),
          waypoints: [for (final p in inner) (p.x + 100, p.y)],
        ),
      );
      expect(moved.points.first, plain.points.first);
      expect(moved.points.last, plain.points.last);
      expect(moved.points[1].x, plain.points[1].x + 100);
      expect(moved.points[2].x, plain.points[2].x + 100);
      for (var i = 1; i < moved.points.length; i++) {
        final p = moved.points[i - 1], q = moved.points[i];
        expect(p.x == q.x || p.y == q.y, isTrue, reason: '$p → $q');
      }
    });

    test('when the glued shape is rotated then the site rotates with it', () {
      f = SceneFixture();
      final c = f.element(
        ElementKind.shape,
        x: 100,
        y: 100,
        w: 200,
        h: 100,
        rotation: 90,
      );
      final line = f.line(0, 0, 10, 10, startGlue: (c, 'right'));

      final r = routeOf(f, line);

      // Center (200, 150); the right site (300, 150) rotates to (200, 250).
      expect(r.start.x, closeTo(200, 1e-9));
      expect(r.start.y, closeTo(250, 1e-9));
    });
  });

  group('Given arrowheads', () {
    for (final style in ArrowHead.values.where((s) => s != ArrowHead.none)) {
      test(
        'when building a ${style.name} head then its tip is the endpoint',
        () {
          final (path, filled: _) = ArrowHeads.head(
            style,
            (x: 100, y: 100),
            (x: 1, y: 0),
            12,
            4,
          );
          final b = PathOps.flatBounds(path.commands)!;

          expect(b.right, closeTo(100, 0.5));
          expect(b.x, lessThan(100));
        },
      );
    }

    test('when parsing stroke values then circle maps to oval and unknown '
        'to none', () {
      expect(ArrowHeads.parse('circle'), ArrowHead.oval);
      expect(ArrowHeads.parse('triangle'), ArrowHead.triangle);
      expect(ArrowHeads.parse('weird'), ArrowHead.none);
      expect(ArrowHeads.lengthFor(4, 'l'), 18);
      expect(ArrowHeads.lengthFor(1, null), 6);
    });
  });
}

void _expectAvoids(
  ConnectorRoute r,
  List<(double, double, double, double)> boxes,
) {
  // Inner segments (not the stubs touching the glued sites) stay out of the
  // boxes.
  for (var i = 1; i < r.points.length - 2; i++) {
    final p = r.points[i], q = r.points[i + 1];
    for (final (x, y, w, h) in boxes) {
      final overlaps =
          math.max(p.x, q.x) > x &&
          math.min(p.x, q.x) < x + w &&
          math.max(p.y, q.y) > y &&
          math.min(p.y, q.y) < y + h;
      expect(overlaps, isFalse, reason: 'segment $p → $q crosses a box');
    }
  }
}
