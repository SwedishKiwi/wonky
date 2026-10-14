import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/data_tools/filter/filter_criteria.dart';
import 'package:wonky_sheets_core/src/formula/recalc/engine_types.dart';
import 'package:wonky_sheets_core/src/pivot/pivot.dart';

import 'support/pivot_fixtures.dart';

const sumRevenue = PivotValueSpec(source: revenue);

List<List<CellValue>> layout(PivotResult r) => PivotLayout.build(r).toValues();

/// The sales table with fill colors per Region cell (East rows red).
SourceTable coloredSales() {
  final base = salesTable();
  final fills = [
    for (var i = 0; i < base.rowCount; i++)
      base.column(region)!.displayText(i).toLowerCase() == 'east'
          ? '#FF0000'
          : null,
  ];
  return SourceTable(
    sheetId: base.sheetId,
    range: base.range,
    display: base.display,
    columns: [
      for (final c in base.columns)
        SourceColumn(
          colId: c.colId,
          header: c.header,
          values: c.values,
          formats: c.formats,
          display: base.display,
          sheetCol: c.sheetCol,
          fillColors: c.colId == region ? fills : null,
        ),
    ],
  );
}

void main() {
  group('Given the sales table', () {
    test('when computing time-sliced then the result equals the synchronous '
        'one', () async {
      final spec = PivotSpec(
        rows: [field(region)],
        columns: [field(product)],
        values: const [sumRevenue],
      );
      final sync = const PivotEngine().compute(
        spec,
        salesTable(),
        PivotContext(),
      );
      final sliced = await const PivotEngine().computeSliced(
        spec,
        salesTable(),
        PivotContext(),
        slice: Duration.zero,
      );
      expect(layout(sliced), layout(sync));
    });

    test('when the token is cancelled before a sliced run then the result '
        'is cancelled', () async {
      final token = CancellationToken()..cancel();
      final r = await const PivotEngine().computeSliced(
        PivotSpec(rows: [field(region)], values: const [sumRevenue]),
        salesTable(),
        PivotContext(),
        cancel: token,
      );
      expect(r.cancelled, isTrue);
    });

    test('when showEmptyGroups is on then every product shows under every '
        'region, also without data', () {
      PivotSpec spec(bool empty) => PivotSpec(
        rows: [field(region, showTotals: false), field(product)],
        values: const [sumRevenue],
        showEmptyGroups: empty,
      );
      final off = layout(
        const PivotEngine().compute(spec(false), salesTable(), PivotContext()),
      );
      final on = layout(
        const PivotEngine().compute(spec(true), salesTable(), PivotContext()),
      );
      // North has only Apple; with empty groups it also lists Banana.
      expect(off.length, lessThan(on.length));
      final north = on.indexWhere((r) => r.first == const TextValue('North'));
      expect(on[north + 1][1], const TextValue('Banana'));
      expect(on[north + 1][2], CellValue.empty);
    });

    test('when a pivot filter keeps a fill color then only those rows are '
        'aggregated', () {
      final r = const PivotEngine().compute(
        PivotSpec(
          rows: [field(region)],
          values: const [sumRevenue],
          filters: [
            PivotFilterSpec(
              region,
              ColumnCriteria(visibleBackgroundColor: '#FF0000'),
            ),
          ],
        ),
        coloredSales(),
        PivotContext(),
      );
      expect(layout(r), [
        [const TextValue('Region'), const TextValue('SUM of Revenue')],
        [const TextValue('East'), const NumberValue(170)],
        [const TextValue('Grand Total'), const NumberValue(170)],
      ]);
    });
  });
}
