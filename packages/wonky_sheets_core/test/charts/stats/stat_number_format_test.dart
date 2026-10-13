import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/charts/stats/stats.dart';

void main() {
  group('Given 4 significant digits', () {
    final cases = <(double, String)>[
      (0, '0'),
      (3, '3'),
      (0.5, '0.5'),
      (-1.2, '-1.2'),
      (1.23456, '1.235'),
      (1234.5678, '1235'),
      (0.1 + 0.2, '0.3'),
      (123456, '123500'),
      (99999.5, '100000'),
      (999999, '1E+06'),
      (1234567, '1.235E+06'),
      (-1234567, '-1.235E+06'),
      (0.0001234, '0.0001234'),
      (0.00001234, '1.234E-05'),
      (1.2e-7, '1.2E-07'),
      (1e100, '1E+100'),
      (double.nan, 'NaN'),
      (double.infinity, 'Infinity'),
    ];
    for (final (value, expected) in cases) {
      test('when formatting $value then the text is "$expected"', () {
        expect(StatNumberFormat.format(value), expected);
      });
    }
  });

  group('Given other digit counts', () {
    final cases = <(double, int, String)>[
      (1.23456, 1, '1'),
      (1.23456, 2, '1.2'),
      (1.23456, 6, '1.23456'),
      (0.000123456, 2, '0.00012'),
    ];
    for (final (value, digits, expected) in cases) {
      test(
        'when formatting $value with $digits digits then the text is "$expected"',
        () {
          expect(
            StatNumberFormat.format(value, significantDigits: digits),
            expected,
          );
        },
      );
    }

    test('when the digit count is out of range then it throws', () {
      expect(
        () => StatNumberFormat.format(1, significantDigits: 0),
        throwsRangeError,
      );
    });
  });
}
