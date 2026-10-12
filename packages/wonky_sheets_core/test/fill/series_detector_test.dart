import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/fill/fill.dart';
import 'package:wonky_sheets_core/src/format/number_format/serial_calendar.dart';

FillSource _n(double v, [String? fmt]) => FillSource(NumberContent(v), numberFormat: fmt);
FillSource _t(String s) => FillSource(TextContent(s));

List<Object?> _values(List<FillItem> items) => [
  for (final i in items)
    switch (i.content) {
      NumberContent(:final number) => number,
      TextContent(:final text) => text,
      final c => c,
    },
];

double _d(int y, int m, int d) => SerialCalendar.serialOf(y, m, d).toDouble();

void main() {
  const detector = SeriesDetector();

  group('Given the 03 §10.2 acceptance criteria', () {
    test('when filling Mon down 8 cells then weekdays continue cyclically', () {
      final items = detector.fill([_t('Mon')], 8);

      expect(_values(items), equals(['Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue']));
    });

    test('when filling 1, 3 then the series is 5, 7, 9', () {
      final items = detector.fill([_n(1), _n(3)], 3);

      expect(_values(items), equals([5, 7, 9]));
    });

    test('when filling a formula then the source formula is returned for translation', () {
      final items = detector.fill([const FillSource(FormulaContent('=A1*2'))], 3);

      expect(
        items,
        equals([
          for (var i = 0; i < 3; i++) const FillItem(0, FormulaContent('=A1*2'), isFormula: true),
        ]),
      );
    });
  });

  group('Given numbers', () {
    final cases = <(String, List<FillSource>, FillMode, FillDirection, int, List<Object?>)>[
      (
        'a single number in auto mode copies',
        [_n(5)],
        FillMode.auto,
        FillDirection.forward,
        3,
        [5, 5, 5],
      ),
      (
        'a single number in copy (Alt) mode steps +1',
        [_n(5)],
        FillMode.copy,
        FillDirection.forward,
        3,
        [6, 7, 8],
      ),
      (
        'a single number backwards in Alt mode steps -1',
        [_n(5)],
        FillMode.copy,
        FillDirection.backward,
        2,
        [4, 3],
      ),
      (
        'a non-arithmetic series uses least squares',
        [_n(1), _n(2), _n(4)],
        FillMode.auto,
        FillDirection.forward,
        2,
        [5.33333333333333, 6.83333333333333],
      ),
      (
        'decimal steps avoid floating noise',
        [_n(0.1), _n(0.2)],
        FillMode.auto,
        FillDirection.forward,
        2,
        [0.3, 0.4],
      ),
      (
        'two numbers in Alt mode copy cyclically',
        [_n(1), _n(3)],
        FillMode.copy,
        FillDirection.forward,
        3,
        [1, 3, 1],
      ),
      (
        'a series filled backwards extends backwards',
        [_n(10), _n(20)],
        FillMode.auto,
        FillDirection.backward,
        3,
        [0, -10, -20],
      ),
    ];
    for (final (name, sources, mode, dir, n, expected) in cases) {
      test('when $name then the values are $expected', () {
        final items = detector.fill(sources, n, mode: mode, direction: dir);
        final values = _values(items);
        expect(values.length, equals(expected.length));
        for (var i = 0; i < expected.length; i++) {
          expect(values[i], closeTo(expected[i]! as num, 1e-9));
        }
      });
    }
  });

  group('Given dates and times', () {
    test('when filling a single date then it steps one day', () {
      final items = detector.fill([_n(_d(2026, 10, 12), 'preset:date')], 2);
      expect(_values(items), equals([_d(2026, 10, 13), _d(2026, 10, 14)]));
    });

    test('when filling a single date in Alt mode then it copies', () {
      final items = detector.fill([_n(_d(2026, 10, 12), 'yyyy-mm-dd')], 2, mode: FillMode.copy);
      expect(_values(items), equals([_d(2026, 10, 12), _d(2026, 10, 12)]));
    });

    test('when dates share the day of month then months step with end-of-month clamping', () {
      final items = detector.fill([
        _n(_d(2026, 1, 31), 'preset:date'),
        _n(_d(2026, 3, 31), 'preset:date'),
      ], 3);
      expect(_values(items), equals([_d(2026, 5, 31), _d(2026, 7, 31), _d(2026, 9, 30)]));
    });

    test('when month-end dates are filled then month ends continue', () {
      final items = detector.fill([
        _n(_d(2026, 1, 31), 'preset:date'),
        _n(_d(2026, 2, 28), 'preset:date'),
      ], 2);
      expect(_values(items), equals([_d(2026, 3, 31), _d(2026, 4, 30)]));
    });

    test('when dates step by a year then years continue (leap day clamped)', () {
      final items = detector.fill([
        _n(_d(2024, 2, 29), 'preset:date'),
        _n(_d(2025, 2, 28), 'preset:date'),
      ], 1);
      expect(_values(items), equals([_d(2026, 2, 28)]));
    });

    test('when dates differ by days then the day step continues', () {
      final items = detector.fill([
        _n(_d(2026, 10, 1), 'preset:date'),
        _n(_d(2026, 10, 8), 'preset:date'),
      ], 2);
      expect(_values(items), equals([_d(2026, 10, 15), _d(2026, 10, 22)]));
    });

    test('when filling a single time then it steps one hour', () {
      final items = detector.fill([_n(0.375, 'h:mm')], 2);
      expect(_values(items), equals([0.416666666666667, 0.458333333333333]));
    });

    test('when filling two times then the first step continues', () {
      final items = detector.fill([_n(0.375, 'h:mm'), _n(0.3854166666666667, 'h:mm')], 1);
      expect((_values(items).single! as double), closeTo(0.3958333333, 1e-9));
    });
  });

  group('Given text', () {
    final cases = <(String, List<FillSource>, int, List<Object?>)>[
      ('zero padding is preserved', [_t('A009')], 2, ['A010', 'A011']),
      ('a trailing number increments', [_t('Item 1')], 2, ['Item 2', 'Item 3']),
      ('the number nearest the end increments', [_t('Q1-2026')], 1, ['Q1-2027']),
      ('a leading number increments', [_t('1st')], 1, ['2st']),
      ('two samples give the step', [_t('Item 1'), _t('Item 3')], 2, ['Item 5', 'Item 7']),
      ('quarters cycle', [_t('Q3')], 3, ['Q4', 'Q1', 'Q2']),
      ('long month names continue', [_t('October')], 3, ['November', 'December', 'January']),
      ('upper case is preserved', [_t('JAN')], 2, ['FEB', 'MAR']),
      ('a two-sample list step is used', [_t('Mon'), _t('Wed')], 2, ['Fri', 'Sun']),
      ('plain text copies cyclically', [_t('a'), _t('b')], 3, ['a', 'b', 'a']),
      ('mixed sources extend each run', [_n(1), _t('a'), _n(3)], 3, [1, 'a', 3]),
      ('mixed runs keep their trends', [_n(1), _n(2), _t('a')], 6, [3, 4, 'a', 5, 6, 'a']),
    ];
    for (final (name, sources, n, expected) in cases) {
      test('when $name then the values are $expected', () {
        expect(_values(detector.fill(sources, n)), equals(expected));
      });
    }

    test('when filling a localized weekday then the locale list continues', () {
      expect(
        _values(detector.fill([_t('Montag')], 2, locale: 'de_DE')),
        equals(['Dienstag', 'Mittwoch']),
      );
    });

    test('when filling a custom list item then the custom list continues', () {
      final items = detector.fill(
        [_t('low')],
        3,
        customLists: [
          ['low', 'medium', 'high'],
        ],
      );
      expect(_values(items), equals(['medium', 'high', 'low']));
    });

    test('when filling text with a number in Alt mode then it copies', () {
      expect(
        _values(detector.fill([_t('Item 1')], 2, mode: FillMode.copy)),
        equals(['Item 1', 'Item 1']),
      );
    });

    test('when filling weekdays backwards then the list runs backwards', () {
      expect(
        _values(detector.fill([_t('Mon')], 2, direction: FillDirection.backward)),
        equals(['Sun', 'Sat']),
      );
    });

    test('when filling backwards then source indexes cycle from the end', () {
      final items = detector.fill(
        [_t('a'), _t('b'), _t('c')],
        4,
        direction: FillDirection.backward,
      );
      expect([for (final i in items) i.sourceIndex], equals([2, 1, 0, 2]));
    });
  });

  group('Given other values', () {
    test('when filling booleans, errors and empty cells then they copy cyclically', () {
      final items = detector.fill([
        const FillSource(BoolContent(true)),
        const FillSource(null),
        const FillSource(ErrorContent(CellErrorKind.na)),
      ], 4);
      expect(
        [for (final i in items) i.content],
        equals([
          const BoolContent(true),
          null,
          const ErrorContent(CellErrorKind.na),
          const BoolContent(true),
        ]),
      );
    });

    test('when there are no sources then nothing is filled', () {
      expect(detector.fill(const [], 3), isEmpty);
    });
  });
}
