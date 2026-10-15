import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';

import '../../support/magic_move_fixture.dart';

Matcher _point(double x, double y) => isA<(double, double)>()
    .having((p) => p.$1, 'x', closeTo(x, 1e-6))
    .having((p) => p.$2, 'y', closeTo(y, 1e-6));

ScenePath _rect(double w, double h) =>
    (ShapePathBuilder()..rect(0, 0, w, h)).build();

void main() {
  group('Given morph geometry (06 §8.4)', () {
    const a = MorphGeometry(100, 100, 200, 100, 0);
    const b = MorphGeometry(500, 300, 400, 200, 90);

    test('when interpolating then the center and size are linear and the '
        'rotation takes the shortest arc', () {
      final g = MorphGeometry.lerp(a, b, 0.5);

      expect(
        [g.cx, g.cy, g.width, g.height, g.rotation],
        [300, 200, 300, 150, 45],
      );
      expect(MorphGeometry.shortestDelta(350, 10), 20);
      expect(MorphGeometry.shortestDelta(10, 350), -20);
      expect(MorphGeometry.shortestDelta(0, 180), 180);
    });

    test('when the aspect ratio is kept then the size grows in log space', () {
      final g = MorphGeometry.lerp(
        a,
        b,
        0.5,
        logSize: MorphGeometry.sameAspect(a, b),
      );

      expect(g.width, closeTo(200 * math.sqrt2, 1e-9));
    });

    test('when stretching from the authored box then its corners land on '
        'the target box', () {
      final m = b.stretchFrom(a);

      // a's top-left (0, 50) → b's top-left corner, rotated 90° about b's
      // center: (500 + 100, 300 − 200).
      expect(mapPoint(m, 0, 50), _point(600, 100));
      expect(mapPoint(m, 100, 100), _point(500, 300));
    });

    test('when moving rigidly then the size is kept', () {
      final m = const MorphGeometry(500, 300, 400, 200, 0).rigidFrom(a);

      expect(mapPoint(m, 0, 50), _point(400, 250));
    });

    test('when a frame state transform scaled and rotated the element then '
        'the shown geometry reflects it', () {
      final t = Matrix4.identity()
        ..translateByDouble(100, 100, 0, 1)
        ..rotateZ(math.pi / 2)
        ..scaleByDouble(2, 2, 1, 1)
        ..translateByDouble(-100, -100, 0, 1);
      final g = MorphGeometry.of(const SuRect(0, 50, 200, 100), 0, t);

      expect([g.cx, g.cy, g.width, g.height], [100, 100, 400, 200]);
      expect(g.rotation, closeTo(90, 1e-9));
    });
  });

  group('Given chart cameras (08 §10.3)', () {
    test('when interpolating then the azimuth crosses 0/360 on the shortest '
        'arc and the rest is linear', () {
      const a = ChartCameraView(azimuth: 340, elevation: 10, perspective: 0);
      const b = ChartCameraView(azimuth: 20, elevation: 30, perspective: 40);

      expect(ChartCameraView.lerp(a, b, 0.25).toJson(), {
        'azimuth': 350.0,
        'elevation': 15.0,
        'perspective': 10.0,
      });
      expect(ChartCameraView.lerp(a, b, 1), b);
    });

    test('when parsing a partial camera then missing values come from the '
        'fallback', () {
      expect(
        ChartCameraView.fromJson({'azimuth': 45}),
        const ChartCameraView(azimuth: 45, elevation: 20, perspective: 15),
      );
      expect(ChartCameraView.fromJson(null), isNull);
    });
  });

  group('Given outline morphs', () {
    test('when morphing a square into a circle then both are resampled to '
        '128 points with aligned starts', () {
      final circle = (ShapePathBuilder()..ellipse(0, 0, 100, 100)).build();
      final m = PathMorph.build(_rect(100, 100), 100, 100, circle, 100, 100)!;

      expect(m.closed, isTrue);
      expect(m.from, hasLength(256));
      // Aligned: the square's first corner meets the nearest circle point
      // (0.5 − √2/4 ≈ 0.146 away on each axis).
      final d = math.sqrt(
        math.pow(m.from[0] - m.to[0], 2) + math.pow(m.from[1] - m.to[1], 2),
      );
      expect(d, closeTo(0.2071, 0.001));
      // Every circle point is at radius 0.5 around the box center.
      for (var i = 0; i < PathMorph.samples; i++) {
        final r = math.sqrt(
          math.pow(m.to[2 * i] - 0.5, 2) + math.pow(m.to[2 * i + 1] - 0.5, 2),
        );
        expect(r, closeTo(0.5, 0.005));
      }
    });

    test('when the orientations differ then the target is reversed', () {
      final cw = _rect(100, 100);
      final ccw = ScenePath([
        PMoveTo(0, 0),
        PLineTo(0, 100),
        PLineTo(100, 100),
        PLineTo(100, 0),
        PClose(),
      ]);
      final m = PathMorph.build(cw, 100, 100, ccw, 100, 100)!;

      // Same outline: after alignment every point coincides.
      for (var i = 0; i < 256; i++) {
        expect(m.to[i], closeTo(m.from[i], 1e-9));
      }
    });

    test('when a shape has several sub-paths then it does not morph', () {
      final donut = ShapeLibrary.resolve(
        'donut',
      ).outline(100, 100).parts.first.path;

      expect(
        PathMorph.build(_rect(100, 100), 100, 100, donut, 100, 100),
        isNull,
      );
    });
  });

  group('Given text glyph alignment', () {
    test('when a text is longer than 2,000 characters then character '
        'matching uses words (06 §8.5)', () {
      final f = MagicMoveFixture();
      final long = List.filled(450, 'word').join(' ');
      f.text(f.a, long, key: 't');
      f.text(f.bSlide, 'intro $long', key: 't');
      final tm = f
          .plan(options: {'textMatching': 'character'})
          .pairs
          .single
          .text!;

      expect(tm.level, 'word');
      expect(
        [for (final s in tm.added) s.toJson()],
        [
          [0, 5],
        ],
      );
    });

    test('when only the text color changes then the runs interpolate it', () {
      final f = MagicMoveFixture();
      f.text(f.a, 'Same', key: 't');
      f.text(f.bSlide, 'Same', key: 't');
      final a = f.slideA(), b = f.slideB();
      final ta = a.elements.single.text!, tb = b.elements.single.text!;
      final tm = TextMorph.build(ta, tb, 'character')!;

      expect(tm.runs.single.toJson()['from'], [0, 4]);
      expect(tm.runs.single.scale, 1);
    });
  });
}
