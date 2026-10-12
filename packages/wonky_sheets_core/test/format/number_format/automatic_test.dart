import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/format/number_format/number_format.dart';

void main() {
  group('Given Automatic display', () {
    final cases = <(double, String)>[
      (0, '0'),
      (123456789012, '123456789012'),
      (-42, '-42'),
      (1 / 3, '0.3333333333'),
      (math.pi, '3.141592654'),
      (0.1 + 0.2, '0.3'),
      (1234.5, '1234.5'),
      (123456789012.5, '123456789013'),
      (1e15, '1E+15'),
      (1.23456789e18, '1.23457E+18'),
      (1e-10, '1E-10'),
      (0.000000001234, '0.000000001234'),
      (-2.5e-12, '-2.5E-12'),
      (2.675, '2.675'),
      (double.infinity, '#NUM!'),
    ];
    for (final (value, expected) in cases) {
      test('when showing $value then it is "$expected"', () {
        expect(AutomaticFormatter.format(value), equals(expected));
      });
    }

    test('when showing 1.5 in de_DE then the decimal comma is used', () {
      expect(AutomaticFormatter.format(1.5, locale: 'de_DE'), equals('1,5'));
    });

    final decimals = <(double, int)>[(1, 0), (1.25, 2), (1 / 3, 10), (1.5e20, 1)];
    for (final (value, d) in decimals) {
      test('when counting displayed decimals of $value then it is $d', () {
        expect(AutomaticFormatter.displayedDecimals(value), equals(d));
      });
    }
  });

  group('Given fitting into a column width (1 px per character)', () {
    double measure(String s) => s.length.toDouble();
    final cases = <(double, double, String)>[
      (1 / 3, 20, '0.3333333333'),
      (1 / 3, 6, '0.3333'),
      (1 / 3, 1, '#'),
      (123.456, 5, '123.5'),
      (123.456, 3, '123'),
      (123456789012, 9, '1.235E+11'),
      (123456789012, 4, '####'),
      (1e-12, 5, '1E-12'),
    ];
    for (final (value, width, expected) in cases) {
      test('when fitting $value into $width px then it shows "$expected"', () {
        expect(AutomaticFormatter.fit(value, width, measure), equals(expected));
      });
    }
  });
}
