import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/pivot/pivot.dart';

import 'support/pivot_fixtures.dart';

void main() {
  group('Given a pivot of SUM of Revenue by Region × Product', () {
    late PivotResult r;
    CellValue get(String value, List<(String, Object?)> pairs) =>
        PivotDataLookup.lookup(r, value, [
          for (final (f, i) in pairs) (f, CellValue.from(i)),
        ]);

    setUp(() {
      r = const PivotEngine().compute(
        PivotSpec(
          rows: [field(region)],
          columns: [field(product)],
          values: const [
            PivotValueSpec(source: revenue),
            PivotValueSpec(
              source: revenue,
              showAs: PivotShowAs.percentOfGrandTotal,
              name: 'Share',
            ),
          ],
        ),
        salesTable(),
        PivotContext(),
      );
    });

    final cases = <(String, String, List<(String, Object?)>, Object)>[
      ('the East total', 'SUM of Revenue', [('Region', 'East')], 170),
      (
        'a case-insensitive item',
        'sum of revenue',
        [('region', 'east'), ('Product', 'BANANA')],
        70,
      ),
      ('the grand total', 'SUM of Revenue', [], 260),
      ('a column total', 'SUM of Revenue', [('Product', 'Apple')], 160),
      ('the value by its source header', 'Revenue', [('Region', 'West')], 80),
    ];
    for (final (what, value, pairs, expected) in cases) {
      test('when asking for $what then it is $expected', () {
        expect(get(value, pairs), CellValue.from(expected));
      });
    }

    test('when the value shows as a percentage then the displayed share is '
        'returned', () {
      expect(get('Share', [('Region', 'North')]), NumberValue(10 / 260));
    });

    test('when the value name is unknown then it is #REF! with a message', () {
      expect(
        get('COUNT of Revenue', []),
        isA<ErrorValue>()
            .having((e) => e.kind, 'kind', CellErrorKind.ref)
            .having(
              (e) => e.message,
              'message',
              "Field 'COUNT of Revenue' was not found in the pivot table.",
            ),
      );
    });

    test('when a field is unknown then it is #REF!', () {
      expect(
        get('SUM of Revenue', [('City', 'Paris')]),
        isA<ErrorValue>().having((e) => e.kind, 'kind', CellErrorKind.ref),
      );
    });

    test('when an item is unknown then it is #N/A', () {
      expect(
        get('SUM of Revenue', [('Region', 'South')]),
        const ErrorValue(CellErrorKind.na),
      );
    });
  });

  group('Given nested rows without outer totals', () {
    late PivotResult r;
    setUp(() {
      r = const PivotEngine().compute(
        PivotSpec(
          rows: [field(region, showTotals: false), field(product)],
          values: const [PivotValueSpec(source: units)],
        ),
        salesTable(),
        PivotContext(),
      );
    });

    test('when fixing both levels then the item is found', () {
      expect(
        PivotDataLookup.lookup(r, 'SUM of Units', const [
          ('Region', TextValue('West')),
          ('Product', TextValue('Banana')),
        ]),
        const NumberValue(3),
      );
    });

    test('when asking for a hidden subtotal then it is #N/A', () {
      expect(
        PivotDataLookup.lookup(r, 'SUM of Units', const [
          ('Region', TextValue('West')),
        ]),
        const ErrorValue(CellErrorKind.na),
      );
    });

    test('when fixing only the inner level then it is #N/A', () {
      expect(
        PivotDataLookup.lookup(r, 'SUM of Units', const [
          ('Product', TextValue('Apple')),
        ]),
        const ErrorValue(CellErrorKind.na),
      );
    });
  });

  group('Given rows by ungrouped date', () {
    late PivotResult r;
    setUp(() {
      r = const PivotEngine().compute(
        PivotSpec(
          rows: [field(date)],
          values: const [PivotValueSpec(source: units)],
        ),
        salesTable(),
        PivotContext(),
      );
    });

    test('when the item is a date serial then it matches by value', () {
      expect(
        PivotDataLookup.lookup(r, 'SUM of Units', [
          ('Date', NumberValue(day(2026, 4, 1))),
        ]),
        const NumberValue(7),
      );
    });

    test('when the item is the formatted label then it matches through the '
        'label renderer', () {
      expect(
        PivotDataLookup.lookup(
          r,
          'SUM of Units',
          const [('Date', TextValue('formatted:46113'))],
          labelText: (v, f) => 'formatted:${(v as NumberValue).number.toInt()}',
        ),
        const NumberValue(7),
      );
    });
  });
}
