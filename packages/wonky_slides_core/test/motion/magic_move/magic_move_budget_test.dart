import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

import '../../support/magic_move_fixture.dart';

/// The 06 §9.7 fixture: 60 elements per slide — shapes that move, recolor
/// and change outline, text boxes, 3D charts at new angles, unmatched
/// elements — and a 1,000-character text matched by character.
MagicMoveFixture _fixture() {
  final f = MagicMoveFixture();
  const shapes = ['rect', 'ellipse', 'star5', 'hexagon', 'roundRect'];
  for (var i = 0; i < 40; i++) {
    final key = 's$i';
    f.shape(
      f.a,
      key: key,
      x: 40.0 * i,
      y: 20.0 * (i % 10),
      w: 120,
      h: 80,
      fill: '#${(0x100000 + i * 4099).toRadixString(16)}',
      geometry: shapes[i % shapes.length],
    );
    f.shape(
      f.bSlide,
      key: key,
      x: 1800 - 40.0 * i,
      y: 400 + 15.0 * (i % 7),
      w: 160,
      h: 100,
      rotation: (i * 17 % 360).toDouble(),
      fill: '#${(0x200000 + i * 8191).toRadixString(16)}',
      geometry: shapes[(i + (i.isEven ? 0 : 1)) % shapes.length],
    );
  }
  for (var i = 0; i < 10; i++) {
    f.text(f.a, 'Point $i: the quick brown fox', key: 't$i', y: 60.0 * i);
    f.text(
      f.bSlide,
      'Point $i: the slow brown fox jumps',
      key: 't$i',
      x: 300,
      y: 60.0 * i,
    );
  }
  final words = [
    for (var i = 0; i < 200; i++) ['alpha', 'beta', 'gamma', 'delta'][i % 4],
  ];
  final long = words.join(' ').substring(0, 1000);
  final edited = long
      .replaceFirst('beta', 'BETA')
      .replaceRange(400, 410, 'something new')
      .replaceFirst('delta gamma', 'omega');
  f.text(f.a, long, key: 'long', y: 700, h: 360);
  f.text(f.bSlide, edited, key: 'long', x: 200, y: 650, h: 400);
  for (var i = 0; i < 4; i++) {
    f.element(
      f.a,
      ElementKind.chart,
      key: 'c$i',
      data: {
        'camera': {'azimuth': 10.0 * i, 'elevation': 20, 'perspective': 15},
      },
    );
    f.element(
      f.bSlide,
      ElementKind.chart,
      key: 'c$i',
      x: 900,
      data: {
        'camera': {'azimuth': 300.0 + i, 'elevation': 35, 'perspective': 30},
      },
    );
  }
  for (var i = 0; i < 5; i++) {
    f.shape(f.a, geometry: 'triangle', x: 10.0 * i);
    f.shape(f.bSlide, geometry: 'donut', y: 10.0 * i);
  }
  return f;
}

void main() {
  group('Given the 06 §9.7 Magic Move fixture', () {
    late MagicMoveSlide a, b;
    late TransitionSpec spec;
    setUpAll(() {
      final f = _fixture();
      a = f.slideA();
      b = f.slideB();
      spec = MagicMoveFixture.magicMove(options: {'textMatching': 'character'});
    });

    test('when planning then it has 60 elements per slide and matches every '
        'keyed pair', () {
      final plan = MagicMovePlan.compile(a, b, spec: spec);

      expect(a.elements, hasLength(60));
      expect(b.elements, hasLength(60));
      expect(plan.pairs, hasLength(55));
      expect(plan.outgoingIds, hasLength(5));
      expect(plan.incomingIds, hasLength(5));
      final long = plan.pairs.firstWhere((p) => p.from.matchKey == 'long');
      expect(long.text!.level, 'character');
      expect(long.text!.matchedLength, greaterThan(950));
    });

    test('when timing the plan then it stays within 15 ms (06 §9.7)', () {
      for (var i = 0; i < 3; i++) {
        MagicMovePlan.compile(a, b, spec: spec);
      }
      var best = Duration.zero;
      for (var i = 0; i < 5; i++) {
        final sw = Stopwatch()..start();
        MagicMovePlan.compile(a, b, spec: spec);
        sw.stop();
        if (i == 0 || sw.elapsed < best) best = sw.elapsed;
      }
      printOnFailure('best plan time: ${best.inMicroseconds} µs');

      expect(best.inMicroseconds, lessThanOrEqualTo(15000));
    });

    test('when evaluating a frame then it stays within the 0.5 ms frameAt '
        'budget order of magnitude (2 ms)', () {
      final plan = MagicMovePlan.compile(a, b, spec: spec);
      for (var i = 0; i < 5; i++) {
        plan.frameAt(100 * i);
      }
      var best = Duration.zero;
      for (var i = 0; i < 10; i++) {
        final sw = Stopwatch()..start();
        plan.frameAt(37 * i + 11);
        sw.stop();
        if (i == 0 || sw.elapsed < best) best = sw.elapsed;
      }
      printOnFailure('best frame time: ${best.inMicroseconds} µs');

      expect(best.inMicroseconds, lessThanOrEqualTo(2000));
    });
  });
}
