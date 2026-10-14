import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/src/charts/charts.dart';

void main() {
  group('Given the nice-tick algorithm', () {
    for (final (lo, hi, target, ticks) in [
      (0.0, 97.0, 6, [0.0, 20, 40, 60, 80, 100]),
      (3.0, 47.0, 6, [0.0, 10, 20, 30, 40, 50]),
      (0.0, 1.0, 5, [0.0, 0.25, 0.5, 0.75, 1]),
      (-12.0, 37.0, 6, [-20.0, -10, 0, 10, 20, 30, 40]),
      (0.001, 0.0093, 5, [0.0, 0.0025, 0.005, 0.0075, 0.01]),
    ]) {
      test(
        'when covering $lo..$hi with about $target ticks then they are $ticks',
        () {
          final r = NiceTicks.compute(lo, hi, target: target);

          expect(r.ticks, ticks);
          expect(r.min, ticks.first);
          expect(r.max, ticks.last);
        },
      );
    }

    test('when the range is a single value then it is widened', () {
      final r = NiceTicks.compute(5, 5);

      expect(r.min, lessThan(5));
      expect(r.max, greaterThan(5));
    });

    test('when min and max are fixed then the ends stay there', () {
      final r = NiceTicks.compute(3, 47, fixedMin: 5, fixedMax: 45, target: 5);

      expect(r.min, 5);
      expect(r.max, 45);
      expect(r.ticks.first, greaterThanOrEqualTo(5));
      expect(r.ticks.last, lessThanOrEqualTo(45));
    });

    test('when a spacing is given then it is the step', () {
      final r = NiceTicks.compute(0, 100, spacing: 25);

      expect(r.step, 25);
      expect(r.ticks, [0, 25, 50, 75, 100]);
    });

    test('when a count is given then about that many ticks are made', () {
      final r = NiceTicks.compute(0, 100, count: 3);

      expect(r.ticks, [0, 50, 100]);
    });

    for (final (step, decimals) in [(1.0, 0), (0.5, 1), (0.25, 2), (20.0, 0)]) {
      test('when the step is $step then labels need $decimals decimals', () {
        expect(NiceTicks.decimalsFor(step), decimals);
      });
    }

    test(
      'when computing log ticks over 3..50 then decades and 2/5 steps are used',
      () {
        final r = NiceTicks.log(3, 50);

        expect(r.min, 1);
        expect(r.max, 100);
        expect(r.ticks, [1, 2, 5, 10, 20, 50, 100]);
      },
    );

    test(
      'when computing log ticks over 3 decades or more then only decades are used',
      () {
        expect(NiceTicks.log(3, 500).ticks, [1, 10, 100, 1000]);
      },
    );
  });

  group('Given scales', () {
    test('when mapping a linear scale then values interpolate and invert', () {
      final s = LinearScale(0, 100, 300, 0);

      expect(s.map(25), 225);
      expect(s.invert(225), 25);
    });

    test('when asking for minor ticks then they lie between majors', () {
      final s = LinearScale(
        0,
        10,
        0,
        100,
        ticks: NiceTicks.compute(0, 10, spacing: 5).ticks,
      );

      expect(s.minorTicks(1), [2.5, 7.5]);
    });

    test('when mapping a log scale then decades are evenly spaced', () {
      final s = LogScale(1, 100, 0, 200);

      expect(s.map(10), closeTo(100, 1e-9));
      expect(s.map(0), isNaN);
      expect(s.invert(100), closeTo(10, 1e-9));
    });

    test('when using a band scale then centers and indices match', () {
      const s = BandScale(4, 0, 400);

      expect(s.bandWidth, 100);
      expect(s.center(1), 150);
      expect(s.indexAt(399), 3);
      expect(s.indexAt(400), -1);
    });

    test('when a band scale is reversed then the first band is at the end', () {
      const s = BandScale(4, 400, 0);

      expect(s.center(0), 350);
      expect(s.start(0), 300);
    });
  });

  group('Given date axes', () {
    double serial(int y, int m, int d) =>
        DateSerial.fromYmd(y, m, d).toDouble();

    test('when spanning ten days then ticks are days', () {
      final (ticks, pattern) = TimeTicks.compute(
        serial(2024, 1, 1),
        serial(2024, 1, 10),
        10,
      );

      expect(ticks.first, serial(2024, 1, 1));
      expect(ticks[1] - ticks[0], 1);
      expect(pattern, 'mmm d');
    });

    test('when spanning two years then ticks are quarters', () {
      final (ticks, pattern) = TimeTicks.compute(
        serial(2023, 1, 1),
        serial(2024, 12, 31),
        8,
      );

      expect(ticks.first, serial(2023, 1, 1));
      expect(ticks[1], serial(2023, 4, 1));
      expect(pattern, 'mmm yyyy');
    });

    test('when spanning decades then ticks are whole years', () {
      final (ticks, pattern) = TimeTicks.compute(
        serial(1990, 6, 1),
        serial(2030, 1, 1),
        6,
      );

      expect(pattern, 'yyyy');
      expect(ticks.first, serial(2000, 1, 1));
      expect(ticks[1], serial(2010, 1, 1));
    });

    test('when spanning hours then times are labelled', () {
      final (_, pattern) = TimeTicks.compute(45000, 45000.25, 6);

      expect(pattern, 'h:mm');
    });
  });
}
