import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/format/number_format/number_format.dart';

void main() {
  group('Given font size steps', () {
    final next = <(double, double)>[
      (10, 11),
      (12, 14),
      (36, 48),
      (96, 96),
      (200, 200),
      (4, 6),
      (10.5, 11),
    ];
    for (final (size, expected) in next) {
      test('when increasing $size then it becomes $expected', () {
        expect(FontSizeSteps.next(size), equals(expected));
      });
    }
    final prev = <(double, double)>[
      (11, 10),
      (14, 12),
      (6, 6),
      (4, 4),
      (200, 96),
      (10.5, 10),
    ];
    for (final (size, expected) in prev) {
      test('when decreasing $size then it becomes $expected', () {
        expect(FontSizeSteps.previous(size), equals(expected));
      });
    }

    test(
      'when clamping a typed size then it is within 1–400 with one decimal',
      () {
        expect([
          FontSizeSteps.clampTyped(0),
          FontSizeSteps.clampTyped(12.34),
          FontSizeSteps.clampTyped(999),
        ], equals([1, 12.3, 400]));
      },
    );
  });

  group('Given decimal digits', () {
    final rounding = <(double, int, double)>[
      (2.675, 2, 2.68),
      (1.005, 2, 1.01),
      (-2.5, 0, -3),
      (0.125, 2, 0.13),
      (9.995, 2, 10),
      (1234.5, -2, 1200),
    ];
    for (final (x, d, expected) in rounding) {
      test('when rounding $x to $d decimals then it is $expected', () {
        expect(roundHalfAwayFromZero(x, d), equals(expected));
      });
    }

    test('when removing float noise then 0.1 + 0.2 is 0.3', () {
      expect(roundToSignificantDigits(0.1 + 0.2), equals(0.3));
    });

    test(
      'when parsing a decimal string then digits and point are normalized',
      () {
        expect(
          DecimalDigits.parse('001.2300'),
          equals(const DecimalDigits([1, 2, 3], 1)),
        );
      },
    );
  });

  group('Given the serial calendar', () {
    final dates = <(int, int, int, int)>[
      (1899, 12, 30, 0),
      (1899, 12, 31, 1),
      (1900, 3, 1, 61),
      (2026, 10, 12, 46307),
      (9999, 12, 31, 2958465),
      (1, 1, 1, -693593),
    ];
    for (final (y, m, d, serial) in dates) {
      test('when converting $y-$m-$d then the serial is $serial and back', () {
        expect(SerialCalendar.serialOf(y, m, d), equals(serial));
        expect(
          SerialCalendar.dateOf(serial),
          equals((year: y, month: m, day: d)),
        );
      });
    }

    test('when 46307 is a Monday then weekdayOf returns 1', () {
      expect(SerialCalendar.weekdayOf(46307), equals(1));
    });

    test('when adding a month to January 31 then the day is clamped', () {
      final s = SerialCalendar.addMonths(
        SerialCalendar.serialOf(2026, 1, 31),
        1,
      );
      expect(SerialCalendar.dateOf(s), equals((year: 2026, month: 2, day: 28)));
    });
  });

  group('Given the palette', () {
    test(
      'when looking up named and indexed colors then ARGB values match 06 §5.5',
      () {
        expect([
          NumberFormatPalette.lookup('Red'),
          NumberFormatPalette.lookup('color16'),
          NumberFormatPalette.lookup('Color0'),
          NumberFormatPalette.lookup('pink'),
        ], equals([0xFFFF0000, 0xFF808080, null, null]));
      },
    );
  });
}
