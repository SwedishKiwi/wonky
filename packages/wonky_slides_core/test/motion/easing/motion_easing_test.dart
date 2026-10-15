import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wonky_slides_core/motion.dart';

/// RK4 integration of the spring ODE x'' = −k(x − 1) − c x' from rest.
double _numericSpring(SpringEasing s, double t) {
  final k = s.omega * s.omega;
  final c = 2 * s.zeta * s.omega;
  const dt = 1e-5;
  var x = 0.0, v = 0.0;
  final steps = (t / dt).round();
  for (var i = 0; i < steps; i++) {
    double a(double x, double v) => -k * (x - 1) - c * v;
    final k1x = v, k1v = a(x, v);
    final k2x = v + k1v * dt / 2, k2v = a(x + k1x * dt / 2, v + k1v * dt / 2);
    final k3x = v + k2v * dt / 2, k3v = a(x + k2x * dt / 2, v + k2v * dt / 2);
    final k4x = v + k3v * dt, k4v = a(x + k3x * dt, v + k3v * dt);
    x += dt / 6 * (k1x + 2 * k2x + 2 * k3x + k4x);
    v += dt / 6 * (k1v + 2 * k2v + 2 * k3v + k4v);
  }
  return x;
}

void main() {
  group('Given the easing grammar (06 §4.3)', () {
    for (final name in NamedEasing.names) {
      test('when evaluating $name then it starts at 0 and ends at 1', () {
        final e = MotionEasing.parse(name);
        expect(e.transform(0), 0);
        expect(e.transform(1), 1);
        expect(e.expression, name);
      });
    }

    for (final (expr, t, expected) in [
      ('linear', 0.25, 0.25),
      ('easeInCubic', 0.5, 0.125),
      ('easeOutCubic', 0.5, 0.875),
      ('easeInOutCubic', 0.25, 0.0625),
      ('easeOutQuint', 0.5, 0.96875),
      ('ease', 0.5, 0.8024033877399112),
      ('easeInOut', 0.5, 0.5),
      ('steps(4)', 0.6, 0.5),
      ('cubic(0,0,1,1)', 0.3, 0.3),
    ]) {
      test('when evaluating $expr at $t then it is $expected', () {
        expect(MotionEasing.parse(expr).transform(t), closeTo(expected, 1e-6));
      });
    }

    test('when evaluating easeOutBack then it overshoots above 1', () {
      final e = MotionEasing.parse('easeOutBack');

      expect(e.transform(0.7), greaterThan(1));
    });

    for (final bad in [
      'bouncy',
      'cubic(1,2)',
      'cubic(2,0,0,1)',
      'spring(0,0)',
      'spring(1,3)',
      'steps(0)',
      'cubic(a,b,c,d)',
    ]) {
      test('when parsing "$bad" then it is refused', () {
        expect(() => MotionEasing.parse(bad), throwsFormatException);
        expect(MotionEasing.tryParse(bad), isNull);
      });
    }

    test('when parsing cubic and spring then the expressions round-trip', () {
      expect(
        MotionEasing.parse('cubic(0.2, 0, 0, 1)').expression,
        'cubic(0.2,0,0,1)',
      );
      expect(
        MotionEasing.parse('spring(0.5,0.25)').expression,
        'spring(0.5,0.25)',
      );
    });
  });

  group('Given springs in closed form', () {
    for (final (d, b) in [(0.5, 0.35), (0.6, 0.0), (0.8, -0.5), (0.4, 0.8)]) {
      test('when comparing spring($d,$b) with numeric integration then they '
          'agree within 1e-6', () {
        final s = SpringEasing(d, b);
        for (final t in [0.05, 0.1, 0.25, 0.5]) {
          expect(s.valueAt(t), closeTo(_numericSpring(s, t), 1e-6));
        }
      });

      test('when it has settled then it is within 0.001 of the target with '
          'velocity below 0.01/s (or capped at 4 d)', () {
        final s = SpringEasing(d, b);
        final t = s.settleSeconds;

        expect(t, lessThanOrEqualTo(4 * d));
        expect(
          t == 4 * d ||
              (s.displacement(t).abs() < 0.0011 && s.velocity(t).abs() < 0.011),
          isTrue,
        );
      });
    }

    for (final (d, b) in [(0.8, -0.5), (0.4, 0.8)]) {
      test('when spring($d,$b) settles slower than 4 d then its length is '
          'capped at 4 d', () {
        expect(SpringEasing(d, b).settleSeconds, 4 * d);
      });
    }

    test(
      'when the bounce is positive then it overshoots and is underdamped',
      () {
        final s = SpringEasing(0.5, 0.35);
        var max = 0.0;
        for (var i = 0; i <= 100; i++) {
          max = math.max(max, s.valueAt(i * s.settleSeconds / 100));
        }

        expect(s.zeta, closeTo(0.65, 1e-12));
        expect(max, greaterThan(1.01));
      },
    );

    test('when the bounce is 0 then it is critically damped and never '
        'overshoots', () {
      final s = SpringEasing(0.6, 0);
      for (var i = 0; i <= 100; i++) {
        expect(s.valueAt(i * s.settleSeconds / 100), lessThanOrEqualTo(1));
      }
      expect(s.zeta, 1);
    });

    test('when binding a spring to a duration then the duration is the '
        'perceptual duration and the length is the settle time', () {
      final bound = MotionEasing.parse('spring(0.5,0)').bind(800);
      final spring = bound.easing as SpringEasing;

      expect(spring.d, 0.8);
      expect(bound.durationMs, (spring.settleSeconds * 1000).ceil());
      expect(bound.at(bound.durationMs), 1);
      expect(bound.at(0), 0);
    });

    test('when binding a curve then it keeps the duration', () {
      final bound = MotionEasing.parse('easeOut').bind(500);

      expect(bound.durationMs, 500);
      expect(
        bound.at(250),
        closeTo(MotionEasing.parse('easeOut').transform(0.5), 1e-12),
      );
    });
  });

  group('Given the seeded generator', () {
    test('when hashing then FNV-1a 32 values are stable', () {
      expect(stableHash(''), 0x811C9DC5);
      expect(stableHash('a'), 0xE40C292C);
      expect(stableHash('foobar'), 0xBF9CF968);
    });

    test('when multiplying 32-bit values then the low 32 bits are exact', () {
      expect(Int32Math.imul(0xFFFFFFFF, 0xFFFFFFFF), 1);
      expect(
        Int32Math.imul(0x12345678, 0x9ABCDEF0),
        (0x12345678 * 0x9ABCDEF0) & 0xFFFFFFFF,
      );
    });

    test('when drawing from the same seed then the sequence repeats and stays '
        'in [0, 1)', () {
      final a = SeededRandom(42), b = SeededRandom(42);
      final xs = [for (var i = 0; i < 50; i++) a.nextDouble()];

      expect([for (var i = 0; i < 50; i++) b.nextDouble()], xs);
      expect(xs.every((x) => x >= 0 && x < 1), isTrue);
      expect(xs.toSet().length, 50);
    });

    test('when drawing from seed 1 then the first values are the recorded '
        'Mulberry32 values', () {
      final r = SeededRandom(1);

      expect(
        [r.nextUint32(), r.nextUint32(), r.nextUint32()],
        [2693262067, 11749833, 2265367787],
      );
    });

    test('when shuffling then the result is a permutation', () {
      final list = [for (var i = 0; i < 20; i++) i];
      SeededRandom(7).shuffle(list);

      expect(list.toSet(), {for (var i = 0; i < 20; i++) i});
      expect(list, isNot([for (var i = 0; i < 20; i++) i]));
    });
  });
}
