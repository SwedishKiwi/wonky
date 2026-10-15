import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

import 'exact_ols.dart';

Float64List f64(List<double> v) => Float64List.fromList(v);

Float64List range(int from, int to) =>
    Float64List.fromList([for (var i = from; i <= to; i++) i.toDouble()]);

Float64List mapped(Float64List x, double Function(double) f) =>
    Float64List.fromList([for (final v in x) f(v)]);

const nan = double.nan;

void main() {
  group('Given exact model data on x = 1..8', () {
    final x = range(1, 8);
    final cases =
        <(String, RegressionKind, int, double Function(double), List<double>)>[
          (
            'linear y = 2x + 3',
            RegressionKind.linear,
            1,
            (v) => 2 * v + 3,
            [3, 2],
          ),
          (
            'exponential y = 1.5e^(0.3x)',
            RegressionKind.exponential,
            1,
            (v) => 1.5 * math.exp(0.3 * v),
            [1.5, 0.3],
          ),
          (
            'logarithmic y = 3ln(x) + 2',
            RegressionKind.logarithmic,
            1,
            (v) => 3 * math.log(v) + 2,
            [3, 2],
          ),
          (
            'power y = 2x^1.5',
            RegressionKind.power,
            1,
            (v) => 2 * math.pow(v, 1.5).toDouble(),
            [2, 1.5],
          ),
          (
            'polynomial y = 0.5x² − 1.2x + 3',
            RegressionKind.polynomial,
            2,
            (v) => 0.5 * v * v - 1.2 * v + 3,
            [3, -1.2, 0.5],
          ),
          (
            'polynomial y = x³ − 4x',
            RegressionKind.polynomial,
            3,
            (v) => v * v * v - 4 * v,
            [0, -4, 0, 1],
          ),
        ];
    for (final (name, kind, degree, f, expected) in cases) {
      test(
        'when fitting $name then the coefficients are recovered and R² is 1',
        () {
          final y = mapped(x, f);

          final r = Regression.fit(kind, x, y, degree: degree)!;

          expect(r.kind, kind);
          expect(r.coefficients, allCloseToRel(expected));
          expect(r.r2, closeToRel(1));
          expect(r.pointCount, 8);
          expect(r.skippedCount, 0);
          expect(r.degree, degree);
          expect(r.predict(4.5), closeToRel(f(4.5)));
        },
      );
    }
  });

  group(
    'Given the Wampler-1 dataset (y = 1 + x + x² + x³ + x⁴ + x⁵, x = 0..20)',
    () {
      final x = range(0, 20);
      final y = mapped(
        x,
        (v) => 1 + v + v * v + v * v * v + v * v * v * v + v * v * v * v * v,
      );

      test(
        'when fitting a degree-5 polynomial then all coefficients are 1 and R² is 1',
        () {
          final r = Regression.polynomial(x, y, 5)!;

          expect(r.degree, 5);
          expect(r.coefficients, allCloseToRel([1, 1, 1, 1, 1, 1]));
          expect(r.r2, closeToRel(1));
          expect(r.predict(13), closeToRel(y[13]));
        },
      );
    },
  );

  group('Given exact degree-10 polynomial data on x = 1..15', () {
    final x = range(1, 15);
    double f(double v) {
      var s = 0.0;
      for (var i = 10; i >= 0; i--) {
        s = s * v + 1;
      }
      return s;
    }

    final y = mapped(x, f);

    test(
      'when fitting degree 10 then predictions reproduce the data to the data scale',
      () {
        final r = Regression.polynomial(x, y, 10)!;
        final scale = y.reduce(math.max);

        expect(r.degree, 10);
        expect(
          [for (final v in x) r.predict(v)],
          pairwiseCompare<double, double>(
            y,
            (e, a) => (a - e).abs() <= 1e-12 * scale,
            'within 1e-12 · max|y| of',
          ),
        );
        expect(r.r2, closeToRel(1));
      },
    );
  });

  group('Given a noisy dataset', () {
    final x = f64([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    final y = f64([2.3, 4.1, 6.2, 7.9, 9.6, 12.5, 13.1, 16.2, 17.8, 20.4]);

    for (final degree in [1, 2, 3]) {
      test(
        'when fitting polynomial degree $degree then it matches exact normal equations',
        () {
          final columns = [
            for (var k = 1; k <= degree; k++)
              exact([for (final v in x) math.pow(v, k).toDouble()]),
          ];
          final reference = ExactLinest.of(columns, exact(y));

          final r = Regression.polynomial(x, y, degree)!;

          expect(
            r.coefficients,
            allCloseToRel([reference.intercept, ...reference.coefficients]),
          );
          expect(r.r2, closeToRel(reference.r2));
        },
      );
    }

    test('when fitting linear then it matches exact normal equations', () {
      final reference = ExactLinest.of([exact(x)], exact(y));

      final r = Regression.linear(x, y)!;

      expect(
        r.coefficients,
        allCloseToRel([reference.intercept, reference.coefficients[0]]),
      );
      expect(r.r2, closeToRel(reference.r2));
    });

    test(
      'when fitting exponential then it is OLS on ln y with R² on that scale',
      () {
        final lnY = mapped(y, math.log);
        final reference = ExactLinest.of([exact(x)], exact(lnY));

        final r = Regression.exponential(x, y)!;

        expect(
          r.coefficients,
          allCloseToRel([
            math.exp(reference.intercept),
            reference.coefficients[0],
          ]),
        );
        expect(r.r2, closeToRel(reference.r2));
      },
    );

    test('when fitting logarithmic then it is OLS on ln x', () {
      final reference = ExactLinest.of([exact(mapped(x, math.log))], exact(y));

      final r = Regression.logarithmic(x, y)!;

      expect(
        r.coefficients,
        allCloseToRel([reference.coefficients[0], reference.intercept]),
      );
      expect(r.r2, closeToRel(reference.r2));
    });

    test('when fitting power then it is OLS on ln x and ln y', () {
      final reference = ExactLinest.of([
        exact(mapped(x, math.log)),
      ], exact(mapped(y, math.log)));

      final r = Regression.power(x, y)!;

      expect(
        r.coefficients,
        allCloseToRel([
          math.exp(reference.intercept),
          reference.coefficients[0],
        ]),
      );
      expect(r.r2, closeToRel(reference.r2));
    });
  });

  group('Given data with large x offsets (years)', () {
    final x = range(2001, 2012);
    final y = mapped(
      x,
      (v) => 0.25 * (v - 2000) * (v - 2000) - 3 * (v - 2000) + 7,
    );

    test('when fitting a quadratic then predictions stay accurate', () {
      final r = Regression.polynomial(x, y, 2)!;

      expect([for (final v in x) r.predict(v)], allCloseToRel(y.toList()));
      expect(r.coefficients[2], closeToRel(0.25));
    });
  });

  group('Given series with missing and invalid values', () {
    final x = f64([1, 2, nan, 4, 5, 6, -1, 0]);
    final y = f64([2, 0, 3, -4, nan, 8, 1, 5]);
    final cases = <(RegressionKind, int, int, List<int>)>[
      // kind, valid points, skipped, indices kept
      (RegressionKind.linear, 6, 2, [0, 1, 3, 5, 6, 7]),
      (RegressionKind.exponential, 4, 4, [0, 5, 6, 7]),
      (RegressionKind.logarithmic, 4, 4, [0, 1, 3, 5]),
      (RegressionKind.power, 2, 6, [0, 5]),
      (RegressionKind.polynomial, 6, 2, [0, 1, 3, 5, 6, 7]),
    ];
    for (final (kind, valid, skipped, kept) in cases) {
      test('when fitting ${kind.name} then $skipped points are skipped', () {
        final r = Regression.fit(kind, x, y)!;
        final reference = Regression.fit(
          kind,
          f64([for (final i in kept) x[i]]),
          f64([for (final i in kept) y[i]]),
        )!;

        expect(r.pointCount, valid);
        expect(r.skippedCount, skipped);
        expect(r.coefficients, allCloseToRel(reference.coefficients.toList()));
      });
    }
  });

  group('Given too few or degenerate points', () {
    final cases = <(String, RegressionKind, List<double>, List<double>)>[
      ('no points', RegressionKind.linear, [], []),
      ('one point', RegressionKind.linear, [1], [2]),
      ('one valid point', RegressionKind.linear, [1, nan], [2, 3]),
      ('constant x', RegressionKind.linear, [2, 2, 2], [1, 2, 3]),
      ('constant x', RegressionKind.polynomial, [2, 2, 2], [1, 2, 3]),
      ('constant x', RegressionKind.exponential, [2, 2], [1, 2]),
      ('one positive y', RegressionKind.exponential, [1, 2, 3], [1, 0, -1]),
      ('one positive x', RegressionKind.logarithmic, [1, 0, -2], [1, 2, 3]),
      ('one positive point', RegressionKind.power, [1, 2, -3], [1, -2, 3]),
    ];
    for (final (name, kind, x, y) in cases) {
      test('when fitting ${kind.name} on $name then the result is null', () {
        expect(Regression.fit(kind, f64(x), f64(y)), isNull);
      });
    }

    test('when the polynomial degree exceeds n − 1 then it is reduced', () {
      final r = Regression.polynomial(f64([0, 1, 2]), f64([1, 2, 5]), 6)!;

      expect(r.degree, 2);
      expect(r.coefficients, allCloseToRel([1, 0, 1]));
    });

    test(
      'when x has repeated values then the degree is limited by distinct x',
      () {
        final r = Regression.polynomial(
          f64([0, 0, 1, 1, 2, 2]),
          f64([1, 1, 2, 2, 5, 5]),
          4,
        )!;

        expect(r.degree, 2);
        expect(r.pointCount, 6);
      },
    );

    test('when the polynomial degree is above 10 then 10 is used', () {
      final x = range(0, 20);

      final r = Regression.polynomial(x, mapped(x, (v) => v), 15)!;

      expect(r.degree, 10);
    });

    test('when the degree is below 1 then it throws', () {
      expect(
        () => Regression.polynomial(f64([1, 2]), f64([1, 2]), 0),
        throwsRangeError,
      );
    });

    test('when x and y lengths differ then it throws', () {
      expect(
        () => Regression.linear(f64([1, 2]), f64([1])),
        throwsArgumentError,
      );
    });
  });

  group('Given constant y', () {
    final x = f64([1, 2, 3, 4]);
    final y = f64([0.1, 0.1, 0.1, 0.1]);

    test('when fitting linear then the slope is 0 and R² is defined as 1', () {
      final r = Regression.linear(x, y)!;

      expect(r.coefficients, equals([0.1, 0]));
      expect(r.r2, 1);
    });

    test('when fitting polynomial then R² is defined as 1', () {
      expect(Regression.polynomial(x, y, 2)!.r2, 1);
    });
  });

  group('Given a series for a moving average', () {
    final cases = <(String, List<double>, int, List<double>)>[
      ('period 2', [1, 2, 3, 4, 5], 2, [nan, 1.5, 2.5, 3.5, 4.5]),
      ('period 3', [3, 6, 9, 12, 0, 3], 3, [nan, nan, 6, 9, 7, 5]),
      ('period 1', [1, -2, 3], 1, [1, -2, 3]),
      ('a period longer than the series', [1, 2], 3, [nan, nan]),
      ('a NaN inside', [1, 2, nan, 4, 5, 6], 2, [nan, 1.5, nan, nan, 4.5, 5.5]),
      ('an empty series', [], 2, []),
    ];
    for (final (name, y, period, expected) in cases) {
      test(
        'when averaging with $name then the trailing means are returned',
        () {
          final out = Regression.movingAverage(f64(y), period);

          expect(out.map((v) => v.isNaN ? 'NaN' : v), [
            for (final v in expected) v.isNaN ? 'NaN' : closeToRel(v),
          ]);
        },
      );
    }

    test(
      'when averaging a long series then every window equals the direct mean',
      () {
        final y = Float64List.fromList([
          for (var i = 0; i < 1000; i++) math.sin(i) * 1e6 + i,
        ]);

        final out = Regression.movingAverage(y, 7);
        final direct = [
          for (var i = 6; i < 1000; i++)
            [for (var j = i - 6; j <= i; j++) y[j]].reduce((a, b) => a + b) / 7,
        ];

        expect(out.sublist(6), allCloseToRel(direct));
      },
    );

    test('when the period is below 1 then it throws', () {
      expect(() => Regression.movingAverage(f64([1]), 0), throwsRangeError);
    });

    test(
      'when dispatching movingAverage through fit then null is returned',
      () {
        expect(
          Regression.fit(
            RegressionKind.movingAverage,
            f64([1, 2]),
            f64([1, 2]),
          ),
          isNull,
        );
      },
    );
  });

  group('Given a categorical domain', () {
    test('when building x for 4 categories then it is 1..4', () {
      expect(Regression.categoricalX(4), [1, 2, 3, 4]);
    });

    test('when building x for 0 categories then it is empty', () {
      expect(Regression.categoricalX(0), isEmpty);
    });
  });

  group('Given regression results', () {
    final cases = <(RegressionKind, List<double>, String)>[
      (RegressionKind.linear, [5.678, 1.234], 'y = 1.234x + 5.678'),
      (RegressionKind.linear, [-5.678, -1.234], 'y = -1.234x - 5.678'),
      (RegressionKind.linear, [0, 1], 'y = x'),
      (RegressionKind.linear, [2, -1], 'y = -x + 2'),
      (RegressionKind.linear, [-1, 1], 'y = x - 1'),
      (RegressionKind.linear, [3, 0], 'y = 3'),
      (RegressionKind.linear, [0, 0], 'y = 0'),
      (RegressionKind.linear, [1e-15, 2], 'y = 2x'),
      (RegressionKind.linear, [123456, 0.00001234], 'y = 1.234E-05x + 123500'),
      (RegressionKind.linear, [1.23456, 1234567], 'y = 1.235E+06x + 1.235'),
      (RegressionKind.polynomial, [3, -1.2, 0.5], 'y = 0.5x^2 - 1.2x + 3'),
      (RegressionKind.polynomial, [0, 0, 1], 'y = x^2'),
      (RegressionKind.polynomial, [-2, 0, 0, -1], 'y = -x^3 - 2'),
      (RegressionKind.exponential, [1.2, 0.5], 'y = 1.2e^(0.5x)'),
      (RegressionKind.exponential, [1, -1], 'y = e^(-x)'),
      (RegressionKind.exponential, [2, 0], 'y = 2'),
      (RegressionKind.logarithmic, [1.2, 3], 'y = 1.2ln(x) + 3'),
      (RegressionKind.logarithmic, [-1, -3], 'y = -ln(x) - 3'),
      (RegressionKind.power, [1.2, 0.5], 'y = 1.2x^0.5'),
      (RegressionKind.power, [2, 1], 'y = 2x'),
      (RegressionKind.power, [1, -2], 'y = x^-2'),
      (RegressionKind.power, [1.5, 0], 'y = 1.5'),
    ];
    for (final (kind, coefficients, expected) in cases) {
      test(
        'when labelling ${kind.name} $coefficients then the equation is "$expected"',
        () {
          final r = RegressionResult(
            kind: kind,
            coefficients: f64(coefficients),
            pointCount: 2,
          );

          expect(r.equation(), expected);
        },
      );
    }

    test(
      'when labelling with 2 significant digits then numbers are rounded to 2',
      () {
        final r = RegressionResult(
          kind: RegressionKind.linear,
          coefficients: f64([5.678, 1.234]),
          pointCount: 2,
        );

        expect(r.equation(significantDigits: 2), 'y = 1.2x + 5.7');
      },
    );

    final r2Cases = <(double?, String?)>[
      (0.98765, 'R² = 0.9877'),
      (1, 'R² = 1'),
      (0, 'R² = 0'),
      (null, null),
    ];
    for (final (r2, expected) in r2Cases) {
      test('when labelling R² $r2 then the label is $expected', () {
        final r = RegressionResult(
          kind: RegressionKind.linear,
          coefficients: f64([0, 1]),
          r2: r2,
          pointCount: 2,
        );

        expect(r.r2Label(), expected);
      });
    }

    test(
      'when fitting exact linear data then the label has no noise terms',
      () {
        final x = f64([0.1, 0.2, 0.3, 0.7]);

        final r = Regression.linear(x, mapped(x, (v) => 3 * v))!;

        expect(r.equation(), 'y = 3x');
      },
    );

    test(
      'when predicting a logarithmic model at x ≤ 0 then NaN is returned',
      () {
        final r = RegressionResult(
          kind: RegressionKind.logarithmic,
          coefficients: f64([1, 0]),
          pointCount: 2,
        );

        expect(r.predict(0), isNaN);
      },
    );

    test(
      'when creating a result with the wrong coefficient count then it throws',
      () {
        expect(
          () => RegressionResult(
            kind: RegressionKind.exponential,
            coefficients: f64([1]),
            pointCount: 2,
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
