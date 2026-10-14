import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/pivot/pivot.dart';

import 'support/pivot_fixtures.dart';

PivotGrid layout(PivotSpec spec, {SourceTable? source, PivotContext? ctx}) {
  final result = const PivotEngine().compute(
    spec,
    source ?? salesTable(),
    ctx ?? PivotContext(),
  );
  return PivotLayout.build(result);
}

const sumRevenue = PivotValueSpec(source: revenue);

void main() {
  group('Given the sales table', () {
    test('when the spec is empty then the grid shows the editor hint', () {
      final grid = layout(const PivotSpec());

      expect(grid.isEmpty, isTrue);
      expect(grid.message, PivotGrid.emptyMessage);
    });

    test('when grouping rows by Region with SUM of Revenue then text groups '
        'are case-insensitive and totals are added', () {
      final grid = layout(
        PivotSpec(rows: [field(region)], values: const [sumRevenue]),
      );

      expect(
        grid.toValues(),
        table([
          ['Region', 'SUM of Revenue'],
          ['East', 170],
          ['North', 10],
          ['West', 80],
          ['Grand Total', 260],
        ]),
      );
      expect((grid.headerRows, grid.labelColumns), (1, 1));
    });

    test('when adding Product as columns then the header block has a field '
        'row and an item row', () {
      final grid = layout(
        PivotSpec(
          rows: [field(region)],
          columns: [field(product)],
          values: const [sumRevenue],
        ),
      );

      expect(
        grid.toValues(),
        table([
          ['SUM of Revenue', 'Product', null, null],
          ['Region', 'Apple', 'Banana', 'Grand Total'],
          ['East', 100, 70, 170],
          ['North', 10, null, 10],
          ['West', 50, 30, 80],
          ['Grand Total', 160, 100, 260],
        ]),
      );
      expect(grid.headerRows, 2);
    });

    test('when two values are laid out as columns then a value-name row is '
        'added', () {
      final grid = layout(
        PivotSpec(
          rows: [field(region)],
          values: const [
            sumRevenue,
            PivotValueSpec(source: units, summarizeBy: PivotSummarize.counta),
          ],
        ),
      );

      expect(
        grid.toValues(),
        table([
          ['Region', 'SUM of Revenue', 'COUNTA of Units'],
          ['East', 170, 2],
          ['North', 10, 1],
          ['West', 80, 2],
          ['Grand Total', 260, 5],
        ]),
      );
    });

    test('when two values are laid out as rows then a Values column is the '
        'innermost row level', () {
      final grid = layout(
        PivotSpec(
          rows: [field(region)],
          values: const [
            sumRevenue,
            PivotValueSpec(source: units, summarizeBy: PivotSummarize.max),
          ],
          valueLayout: PivotValueLayout.rows,
        ),
      );

      expect(
        grid.toValues(),
        table([
          ['Region', 'Values', null],
          ['East', 'SUM of Revenue', 170],
          [null, 'MAX of Units', 10],
          ['North', 'SUM of Revenue', 10],
          [null, 'MAX of Units', 1],
          ['West', 'SUM of Revenue', 80],
          [null, 'MAX of Units', 5],
          ['Grand Total', 'SUM of Revenue', 260],
          [null, 'MAX of Units', 10],
        ]),
      );
    });

    test('when nesting Region and Product then subtotal rows follow each '
        'region', () {
      final grid = layout(
        PivotSpec(
          rows: [field(region), field(product)],
          values: const [sumRevenue],
        ),
      );

      expect(
        grid.toValues(),
        table([
          ['Region', 'Product', 'SUM of Revenue'],
          ['East', 'Apple', 100],
          [null, 'Banana', 70],
          ['East Total', null, 170],
          ['North', 'Apple', 10],
          ['North Total', null, 10],
          ['West', 'Apple', 50],
          [null, 'Banana', 30],
          ['West Total', null, 80],
          ['Grand Total', null, 260],
        ]),
      );
    });

    test('when the outer group hides totals and repeats labels then no '
        'subtotal or grand total rows appear', () {
      final grid = layout(
        PivotSpec(
          rows: [
            field(region, showTotals: false, repeatLabels: true),
            field(product),
          ],
          values: const [sumRevenue],
        ),
      );

      expect(
        grid.toValues(),
        table([
          ['Region', 'Product', 'SUM of Revenue'],
          ['East', 'Apple', 100],
          ['East', 'Banana', 70],
          ['North', 'Apple', 10],
          ['West', 'Apple', 50],
          ['West', 'Banana', 30],
        ]),
      );
    });

    test('when nesting column groups then subtotal columns follow each '
        'outer item', () {
      final grid = layout(
        PivotSpec(
          columns: [field(region), field(product)],
          values: const [sumRevenue],
        ),
      );

      expect(
        grid.toValues(),
        table([
          [
            'SUM of Revenue',
            'Region',
            'Product',
            null,
            null,
            null,
            null,
            null,
            null,
            null,
          ],
          [
            null,
            'East',
            null,
            'East Total',
            'North',
            'North Total',
            'West',
            null,
            'West Total',
            'Grand Total',
          ],
          [
            null,
            'Apple',
            'Banana',
            null,
            'Apple',
            null,
            'Apple',
            'Banana',
            null,
            null,
          ],
          [null, 100, 70, 170, 10, 10, 50, 30, 80, 260],
        ]),
      );
    });

    test('when grouping columns by year then date groups label the columns '
        'and empty combinations stay blank', () {
      final grid = layout(
        PivotSpec(
          rows: [field(region)],
          columns: [
            field(date, grouping: const PivotDateGrouping(PivotDateUnit.year)),
          ],
          values: const [PivotValueSpec(source: units)],
        ),
      );

      expect(
        grid.toValues(),
        table([
          ['SUM of Units', 'Date', null, null],
          ['Region', '2025', '2026', 'Grand Total'],
          ['East', null, 17, 17],
          ['North', null, 1, 1],
          ['West', 3, 5, 8],
          ['Grand Total', 3, 23, 26],
        ]),
      );
    });

    test('when only values are set then one header row and one value row '
        'are shown', () {
      final grid = layout(
        const PivotSpec(
          values: [
            sumRevenue,
            PivotValueSpec(
              source: revenue,
              summarizeBy: PivotSummarize.average,
            ),
          ],
        ),
      );

      expect(
        grid.toValues(),
        table([
          ['SUM of Revenue', 'AVERAGE of Revenue'],
          [260, 52],
        ]),
      );
    });

    test('when only rows are set then the distinct items are listed', () {
      final grid = layout(PivotSpec(rows: [field(product)]));

      expect(
        grid.toValues(),
        table([
          ['Product'],
          ['Apple'],
          ['Banana'],
          ['Grand Total'],
        ]),
      );
    });

    test('when reading roles then headers and totals are bold with their '
        'fills', () {
      final grid = layout(
        PivotSpec(
          rows: [field(region), field(product)],
          values: const [sumRevenue],
        ),
      );

      expect(grid.cellAt(0, 2)!.role, PivotCellRole.header);
      expect(grid.cellAt(0, 2)!.fill, PivotFill.header);
      expect(grid.cellAt(1, 0)!.role, PivotCellRole.rowLabel);
      expect(grid.cellAt(1, 0)!.bold, isFalse);
      expect(grid.cellAt(1, 2)!.role, PivotCellRole.value);
      expect(grid.cellAt(3, 0)!.role, PivotCellRole.subtotal);
      expect(grid.cellAt(3, 2)!.bold, isTrue);
      expect(grid.cellAt(3, 2)!.fill, PivotFill.total);
      expect(grid.cellAt(9, 1)!.role, PivotCellRole.grandTotal);
      expect(grid.cellAt(1, 2)!.isValue, isTrue);
      expect(grid.cellAt(1, 0)!.isValue, isFalse);
    });

    test('when values sum a currency column then they inherit its format, '
        'counts stay Automatic and overrides win', () {
      final grid = layout(
        PivotSpec(
          rows: [field(region)],
          values: const [
            sumRevenue,
            PivotValueSpec(source: revenue, summarizeBy: PivotSummarize.count),
            PivotValueSpec(source: revenue, numberFormat: '0.0'),
            PivotValueSpec(
              source: revenue,
              showAs: PivotShowAs.percentOfGrandTotal,
            ),
          ],
        ),
        source: salesTable(revenueFormat: r'"$"#,##0'),
      );

      expect(grid.cellAt(1, 1)!.numberFormat, r'"$"#,##0');
      expect(grid.cellAt(1, 2)!.numberFormat, isNull);
      expect(grid.cellAt(1, 3)!.numberFormat, '0.0');
      expect(grid.cellAt(1, 4)!.numberFormat, '0.00%');
    });

    test('when an ungrouped date field is a row then its labels keep the '
        'date format', () {
      final grid = layout(
        PivotSpec(rows: [field(date)], values: const [sumRevenue]),
      );

      expect(grid.valueAt(1, 0), CellValue.from(day(2025, 12, 31)));
      expect(grid.cellAt(1, 0)!.numberFormat, 'yyyy-mm-dd');
    });

    test('when a label renderer is given then total labels use the formatted '
        'label', () {
      final result = const PivotEngine().compute(
        PivotSpec(
          rows: [field(units), field(product)],
          values: const [sumRevenue],
        ),
        salesTable(),
        PivotContext(),
      );

      final grid = PivotLayout.build(
        result,
        labelText: (v, f) => '#${v is NumberValue ? v.number.toInt() : v}',
      );

      expect(grid.valueAt(2, 0), const TextValue('#1 Total'));
    });

    test('when the output exceeds the cell limit then the grid is a #REF! '
        'error', () {
      final grid = layout(
        PivotSpec(rows: [field(region)], values: const [sumRevenue]),
        ctx: PivotContext(maxOutputCells: 9),
      );

      expect(grid.isEmpty, isTrue);
      expect(grid.error?.kind, CellErrorKind.ref);
      expect(grid.error?.message, PivotGrid.tooLargeMessage);
    });
  });
}
