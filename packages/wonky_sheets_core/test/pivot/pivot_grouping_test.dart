import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/pivot/pivot.dart';

import 'support/pivot_fixtures.dart';

void main() {
  group('Given 2026-10-12 14:05:09 (a Monday)', () {
    final serial = day(2026, 10, 12) + (14 * 3600 + 5 * 60 + 9) / 86400;
    final column = SourceColumn(
      colId: 'd',
      header: 'When',
      values: [NumberValue(serial)],
      formats: const [null],
      display: plainDisplay,
    );
    final cases = <(PivotDateUnit, String)>[
      (PivotDateUnit.second, '9'),
      (PivotDateUnit.minute, '5'),
      (PivotDateUnit.hour, '14'),
      (PivotDateUnit.hourMinute, '14:05'),
      (PivotDateUnit.hourMinuteAmPm, '2:05 PM'),
      (PivotDateUnit.dayOfWeek, 'Mon'),
      (PivotDateUnit.dayOfYear, '285'),
      (PivotDateUnit.dayOfMonth, '12'),
      (PivotDateUnit.dayMonth, '12-Oct'),
      (PivotDateUnit.month, 'Oct'),
      (PivotDateUnit.quarter, 'Q4'),
      (PivotDateUnit.year, '2026'),
      (PivotDateUnit.yearMonth, '2026-Oct'),
      (PivotDateUnit.yearQuarter, '2026-Q4'),
      (PivotDateUnit.yearMonthDay, '2026-10-12'),
    ];
    for (final (unit, label) in cases) {
      test('when grouping by ${unit.name} then the label is "$label"', () {
        final g = PivotGrouper(
          PivotGroupSpec('d', group: PivotDateGrouping(unit)),
          column,
        );

        expect(g.keyOfRow(0).labelText, label);
      });
    }

    test('when the locale is German then month labels are localized', () {
      final g = PivotGrouper(
        const PivotGroupSpec(
          'd',
          group: PivotDateGrouping(PivotDateUnit.month),
        ),
        column,
        locale: 'de_DE',
      );

      expect(g.keyOfRow(0).labelText, isNot('Oct'));
    });
  });

  group('Given plain keys', () {
    final column = SourceColumn(
      colId: 't',
      header: 'T',
      values: const [
        TextValue('Apple'),
        TextValue('APPLE'),
        EmptyValue(),
        TextValue(''),
      ],
      formats: const [null, null, null, null],
      display: plainDisplay,
    );
    final g = PivotGrouper(const PivotGroupSpec('t'), column);

    test('when text differs only by case then the first-seen casing labels '
        'the group', () {
      expect(identical(g.keyOfRow(0), g.keyOfRow(1)), isTrue);
      expect(g.keyOfRow(1).labelText, 'Apple');
    });

    test('when values are blank or empty strings then they share the blank '
        'group sorted last', () {
      expect(identical(g.keyOfRow(2), g.keyOfRow(3)), isTrue);
      expect(PivotKey.compare(g.keyOfRow(2), g.keyOfRow(0)), 1);
      expect(
        PivotKey.compare(g.keyOfRow(2), g.keyOfRow(0), ascending: false),
        1,
      );
    });
  });
}
