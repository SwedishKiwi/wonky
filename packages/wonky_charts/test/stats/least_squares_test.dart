import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

import 'exact_ols.dart';

Float64List f64(List<double> v) => Float64List.fromList(v);

const nan = double.nan;

void main() {
  group('Given the textbook dataset x = 1..5, y = 2, 4, 5, 4, 5', () {
    late LeastSquaresFit fit;
    setUp(
      () => fit = LeastSquares.fit([
        f64([1, 2, 3, 4, 5]),
      ], f64([2, 4, 5, 4, 5]))!,
    );

    // x̄ = 3, ȳ = 4, Sxx = 10, Sxy = 6, SStot = 6, SSres = 2.4, df = 3.
    final cases = <(String, double Function(LeastSquaresFit), double)>[
      ('slope', (f) => f.coefficients[0], 0.6),
      ('intercept', (f) => f.intercept, 2.2),
      (
        'slope standard error',
        (f) => f.standardErrors![0],
        math.sqrt(0.8 / 10),
      ),
      (
        'intercept standard error',
        (f) => f.interceptStandardError!,
        math.sqrt(0.8 * 1.1),
      ),
      ('R²', (f) => f.r2, 0.6),
      ('standard error of y', (f) => f.standardErrorY, math.sqrt(0.8)),
      ('F statistic', (f) => f.fStatistic, 4.5),
      ('regression sum of squares', (f) => f.ssRegression, 3.6),
      ('residual sum of squares', (f) => f.ssResidual, 2.4),
    ];
    for (final (name, read, expected) in cases) {
      test('when fitting with stats then the $name is $expected', () {
        expect(read(fit), closeToRel(expected));
      });
    }

    test('when fitting then df, rank and observation count follow LINEST', () {
      expect(fit.degreesOfFreedom, 3);
      expect(fit.rank, 1);
      expect(fit.observationCount, 5);
    });

    test('when predicting then the line is evaluated', () {
      expect(fit.predict([10]), closeToRel(8.2));
    });
  });

  group('Given two regressors with noise', () {
    final x1 = f64([1, 2, 3, 4, 5, 6, 7, 8, 9]);
    final x2 = f64([2.5, 1, 4, 3.5, 6, 5, 8.25, 9, 7]);
    final y = f64([4.1, 4.9, 8.2, 8.8, 12.1, 12.4, 16.8, 18.1, 17.2]);

    for (final intercept in [true, false]) {
      test(
        'when fitting with intercept = $intercept then all stats match exact normal equations',
        () {
          final reference = ExactLinest.of(
            [exact(x1), exact(x2)],
            exact(y),
            intercept: intercept,
          );

          final fit = LeastSquares.fit([x1, x2], y, intercept: intercept)!;

          expect(fit.coefficients, allCloseToRel(reference.coefficients));
          expect(fit.intercept, closeToRel(reference.intercept));
          expect(fit.standardErrors, allCloseToRel(reference.standardErrors));
          expect(
            fit.interceptStandardError,
            intercept ? closeToRel(reference.interceptStandardError!) : isNull,
          );
          expect(fit.r2, closeToRel(reference.r2));
          expect(fit.standardErrorY, closeToRel(reference.standardErrorY));
          expect(fit.fStatistic, closeToRel(reference.fStatistic));
          expect(fit.degreesOfFreedom, reference.degreesOfFreedom);
          expect(fit.ssRegression, closeToRel(reference.ssRegression));
          expect(fit.ssResidual, closeToRel(reference.ssResidual));
          expect(fit.rank, 2);
        },
      );
    }
  });

  group('Given collinear regressors', () {
    final x1 = f64([1, 2, 3, 4, 5, 6]);
    final y = f64([1.1, 2.3, 2.8, 4.2, 4.9, 6.1]);

    test(
      'when x2 = 2·x1 then x2 gets coefficient 0 and is excluded from df',
      () {
        final x2 = f64([for (final v in x1) 2 * v]);
        final single = LeastSquares.fit([x1], y)!;

        final fit = LeastSquares.fit([x1, x2], y)!;

        expect(fit.rank, 1);
        expect(fit.degreesOfFreedom, 4);
        expect(fit.coefficients[1], 0);
        expect(fit.standardErrors![1], 0);
        expect(fit.coefficients[0], closeToRel(single.coefficients[0]));
        expect(fit.standardErrors![0], closeToRel(single.standardErrors![0]));
        expect(fit.fStatistic, closeToRel(single.fStatistic));
      },
    );

    test('when a column is constant then it is absorbed by the intercept', () {
      final fit = LeastSquares.fit([f64(List.filled(6, 5)), x1], y)!;

      expect(fit.rank, 1);
      expect(fit.coefficients[0], 0);
      expect(fit.degreesOfFreedom, 4);
      expect(fit.intercept, closeToRel(LeastSquares.fit([x1], y)!.intercept));
    });
  });

  group('Given rows with missing values', () {
    test('when fitting then rows with NaN in x or y are skipped', () {
      final fit = LeastSquares.fit([
        f64([1, 2, nan, 3, 4]),
      ], f64([3, 5, 100, nan, 9]))!;

      expect(fit.observationCount, 3);
      expect(fit.coefficients[0], closeToRel(2));
      expect(fit.intercept, closeToRel(1));
    });

    test('when no row is usable then the result is null', () {
      expect(
        LeastSquares.fit([
          f64([nan, 1]),
        ], f64([1, nan])),
        isNull,
      );
      expect(LeastSquares.fit([f64([])], f64([])), isNull);
    });

    test('when lengths differ then it throws', () {
      expect(
        () => LeastSquares.fit([
          f64([1, 2]),
        ], f64([1])),
        throwsArgumentError,
      );
    });
  });

  group('Given degenerate fits', () {
    test(
      'when df is 0 then standard errors are null and sey and F are NaN',
      () {
        final fit = LeastSquares.fit([
          f64([1, 2]),
        ], f64([3, 5]))!;

        expect(fit.degreesOfFreedom, 0);
        expect(fit.standardErrors, isNull);
        expect(fit.interceptStandardError, isNull);
        expect(fit.standardErrorY, isNaN);
        expect(fit.fStatistic, isNaN);
        expect(fit.r2, closeToRel(1));
      },
    );

    test(
      'when the fit is exact with df > 0 then F is infinite and sey is 0',
      () {
        final fit = LeastSquares.fit([
          f64([1, 2, 4]),
        ], f64([2, 4, 8]))!;

        expect(fit.coefficients[0], closeToRel(2));
        expect(fit.standardErrorY, closeToRel(0));
        expect(fit.fStatistic, double.infinity);
      },
    );

    test('when y is constant then R² is defined as 1', () {
      final fit = LeastSquares.fit([
        f64([1, 2, 3]),
      ], f64([0.7, 0.7, 0.7]))!;

      expect(fit.r2, 1);
      expect(fit.coefficients[0], 0);
      expect(fit.intercept, 0.7);
    });

    test('when there are no columns then the intercept is the mean', () {
      final fit = LeastSquares.fit(const [], f64([1, 2, 6]))!;

      expect(fit.intercept, closeToRel(3));
      expect(fit.rank, 0);
      expect(fit.degreesOfFreedom, 2);
      expect(fit.fStatistic, isNaN);
    });
  });
}
