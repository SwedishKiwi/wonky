import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/data_tools/filter/filter_criteria.dart';
import 'package:wonky_sheets_core/src/formula/recalc/engine_types.dart';
import 'package:wonky_sheets_core/src/pivot/pivot.dart';
import 'package:wonky_sheets_core/src/rules/conditions/condition.dart';

import 'support/pivot_fixtures.dart';

PivotResult compute(
  PivotSpec spec, {
  SourceTable? source,
  PivotFormulaEvaluator? formulas,
  CancellationToken? cancel,
}) => const PivotEngine().compute(
  spec,
  source ?? salesTable(),
  PivotContext(formulas: formulas),
  cancel: cancel,
);

List<List<CellValue>> grid(PivotSpec spec, {SourceTable? source}) =>
    PivotLayout.build(compute(spec, source: source)).toValues();

const sumRevenue = PivotValueSpec(source: revenue);

/// Revenue / Units per row, or SUM(Revenue) / SUM(Units) per group.
final class _PricePerUnit implements PivotFormulaEvaluator {
  int rowCalls = 0;
  int groupCalls = 0;

  static double _n(CellValue v) => v is NumberValue ? v.number : 0;

  @override
  CellValue evaluateRow(
    String formula,
    CellValue Function(String colId) field,
  ) {
    rowCalls++;
    expect(PivotFormula.fieldIds(formula), [revenue, units]);
    return NumberValue(_n(field(revenue)) / _n(field(units)));
  }

  @override
  CellValue evaluateGroup(
    String formula,
    List<CellValue> Function(String colId) field,
  ) {
    groupCalls++;
    double sum(String id) => field(id).fold(0.0, (a, v) => a + _n(v));
    return NumberValue(sum(revenue) / sum(units));
  }
}

final _priceFormula =
    '=${PivotFormula.tokenOf(revenue)}/${PivotFormula.tokenOf(units)}';

void main() {
  group('Given the sales table and show-as percentages', () {
    final spec = PivotSpec(
      rows: [field(region)],
      columns: [field(product)],
      values: const [
        PivotValueSpec(source: revenue, showAs: PivotShowAs.percentOfRowTotal),
        PivotValueSpec(
          source: revenue,
          showAs: PivotShowAs.percentOfColumnTotal,
        ),
        PivotValueSpec(
          source: revenue,
          showAs: PivotShowAs.percentOfGrandTotal,
        ),
      ],
    );
    late PivotResult r;
    late PivotAxisNode east;
    late PivotAxisNode apple;
    setUp(() {
      r = compute(spec);
      east = r.rowRoot.children.first;
      apple = r.columnRoot.children.first;
    });

    test('when showing % of row total then East/Apple is 100 of 170', () {
      expect(r.value(east, apple, 0), NumberValue(100 / 170));
      expect(r.value(east, r.columnRoot, 0), const NumberValue(1));
    });

    test('when showing % of column total then East/Apple is 100 of 160', () {
      expect(r.value(east, apple, 1), NumberValue(100 / 160));
      expect(r.value(r.rowRoot, apple, 1), const NumberValue(1));
    });

    test('when showing % of grand total then East/Apple is 100 of 260', () {
      expect(r.value(east, apple, 2), NumberValue(100 / 260));
      expect(r.value(r.rowRoot, r.columnRoot, 2), const NumberValue(1));
    });

    test('when a pair has no rows then the value stays empty', () {
      final north = r.rowRoot.children[1];
      final banana = r.columnRoot.children[1];

      expect(r.value(north, banana, 0), CellValue.empty);
      expect(r.rawValue(north, banana, 0), CellValue.empty);
    });
  });

  group('Given sorting options', () {
    test('when sorting descending then labels reverse but blanks stay '
        'last', () {
      final values = grid(
        PivotSpec(
          rows: [field(region, ascending: false)],
          values: const [sumRevenue],
        ),
        source: salesTable(
          extraRows: [
            [null, 'Apple', day(2026, 5, 1), 4, 40],
          ],
        ),
      );

      expect(values.map((r) => r.first), [
        const TextValue('Region'),
        const TextValue('West'),
        const TextValue('North'),
        const TextValue('East'),
        CellValue.empty,
        const TextValue('Grand Total'),
      ]);
      expect(values[4][1], const NumberValue(40));
    });

    test('when sorting by a value total descending then the largest group '
        'comes first', () {
      final values = grid(
        PivotSpec(
          rows: [field(region, ascending: false, sortByValue: 0)],
          values: const [sumRevenue],
        ),
      );

      expect(
        values,
        table([
          ['Region', 'SUM of Revenue'],
          ['East', 170],
          ['West', 80],
          ['North', 10],
          ['Grand Total', 260],
        ]),
      );
    });

    test('when sorting columns by a value then the column order follows the '
        'column totals', () {
      final values = grid(
        PivotSpec(
          columns: [field(region, sortByValue: 0)],
          values: const [sumRevenue],
        ),
      );

      expect(values[1].sublist(1), [
        const TextValue('North'),
        const TextValue('West'),
        const TextValue('East'),
        const TextValue('Grand Total'),
      ]);
    });

    test('when numbers, text and booleans mix then numbers come first', () {
      final source = SourceTable.fromRows(
        colIds: const ['k', 'v'],
        headers: const ['Key', 'Val'],
        rows: [
          for (final k in <Object>['b', 2, true, 'A', 1])
            [CellValue.from(k), const NumberValue(1)],
        ],
        display: plainDisplay,
      );

      final values = grid(
        PivotSpec(
          rows: [field('k')],
          values: const [PivotValueSpec(source: 'v')],
        ),
        source: source,
      );

      expect(values.map((r) => r.first).skip(1).take(5), [
        const NumberValue(1),
        const NumberValue(2),
        const TextValue('A'),
        const TextValue('b'),
        const BoolValue(true),
      ]);
    });
  });

  group('Given pivot filters', () {
    test('when hiding North by value then it is excluded from groups and '
        'totals', () {
      final values = grid(
        PivotSpec(
          rows: [field(region)],
          values: const [sumRevenue],
          filters: [
            PivotFilterSpec(region, ColumnCriteria(hiddenValues: ['North'])),
          ],
        ),
      );

      expect(
        values,
        table([
          ['Region', 'SUM of Revenue'],
          ['East', 170],
          ['West', 80],
          ['Grand Total', 250],
        ]),
      );
    });

    test('when filtering Units > 4 by condition then only matching rows '
        'count', () {
      final values = grid(
        PivotSpec(
          rows: [field(region)],
          values: const [sumRevenue],
          filters: [
            PivotFilterSpec(
              units,
              ColumnCriteria(
                condition: Condition.of(ConditionType.numberGreater, [
                  const ConditionLiteral('4'),
                ]),
              ),
            ),
          ],
        ),
      );

      expect(
        values,
        table([
          ['Region', 'SUM of Revenue'],
          ['East', 170],
          ['West', 50],
          ['Grand Total', 220],
        ]),
      );
    });

    test('when a slicer mask excludes rows then they are ignored', () {
      final source = SourceTable.fromRows(
        colIds: const [region, revenue],
        headers: const ['Region', 'Revenue'],
        rows: [
          [const TextValue('East'), const NumberValue(1)],
          [const TextValue('East'), const NumberValue(2)],
        ],
        display: plainDisplay,
        rowMask: Uint8List.fromList([0, 1]),
      );

      final r = compute(
        PivotSpec(rows: [field(region)], values: const [sumRevenue]),
        source: source,
      );

      expect(r.rawValue(r.rowRoot, r.columnRoot, 0), const NumberValue(1));
    });
  });

  group('Given grouping rules', () {
    test('when bucketing Units by 5 from 0 to 10 then values above max get '
        'their own bucket', () {
      final values = grid(
        PivotSpec(
          rows: [
            field(
              units,
              grouping: const PivotHistogramGrouping(5, min: 0, max: 9),
            ),
          ],
          values: const [
            PivotValueSpec(source: region, summarizeBy: PivotSummarize.counta),
          ],
        ),
      );

      expect(
        values,
        table([
          ['Units', 'COUNTA of Region'],
          ['0–5', 2],
          ['5–10', 2],
          ['> 9', 1],
          ['Grand Total', 5],
        ]),
      );
    });

    test('when histogram bounds are omitted then the data range is used', () {
      final values = grid(
        PivotSpec(
          rows: [field(units, grouping: const PivotHistogramGrouping(4))],
          values: const [
            PivotValueSpec(source: units, summarizeBy: PivotSummarize.count),
          ],
        ),
      );

      expect(values.map((r) => r.first).toList().sublist(1, 4), [
        const TextValue('1–5'),
        const TextValue('5–9'),
        const TextValue('9–13'),
      ]);
    });

    test('when manual groups name items then the rest goes to the ungrouped '
        'group', () {
      final values = grid(
        PivotSpec(
          rows: [
            field(
              region,
              grouping: const PivotManualGrouping([
                PivotManualGroup('Coast', ['east', 'WEST']),
              ], ungrouped: 'Other'),
            ),
          ],
          values: const [sumRevenue],
        ),
      );

      expect(
        values,
        table([
          ['Region', 'SUM of Revenue'],
          ['Coast', 250],
          ['Other', 10],
          ['Grand Total', 260],
        ]),
      );
    });

    test('when date grouping by year-quarter meets text then it forms a '
        '(non-date) group', () {
      final values = grid(
        PivotSpec(
          rows: [
            field(
              date,
              grouping: const PivotDateGrouping(PivotDateUnit.yearQuarter),
            ),
          ],
          values: const [PivotValueSpec(source: units)],
        ),
        source: salesTable(
          extraRows: [
            ['East', 'Apple', 'soon', 2, 20],
          ],
        ),
      );

      expect(
        values,
        table([
          ['Date', 'SUM of Units'],
          ['2025-Q4', 3],
          ['2026-Q1', 16],
          ['2026-Q2', 7],
          ['(non-date)', 2],
          ['Grand Total', 28],
        ]),
      );
    });
  });

  group('Given calculated fields', () {
    test('when summarized by SUM then the formula is evaluated per row and '
        'summed', () {
      final f = _PricePerUnit();
      final r = compute(
        PivotSpec(
          rows: [field(region)],
          values: [PivotValueSpec(formula: _priceFormula)],
        ),
        formulas: f,
      );

      expect(r.valueFields.single.name, 'Calculated Field 1');
      expect(f.rowCalls, 5);
      expect(
        PivotLayout.build(r).toValues(),
        table([
          ['Region', 'Calculated Field 1'],
          ['East', 20],
          ['North', 10],
          ['West', 20],
          ['Grand Total', 50],
        ]),
      );
    });

    test('when summarized by Custom then the formula gets the group values '
        'as arrays', () {
      final f = _PricePerUnit();
      final r = compute(
        PivotSpec(
          rows: [field(region)],
          values: [
            PivotValueSpec(
              formula: _priceFormula,
              summarizeBy: PivotSummarize.custom,
              name: 'Price',
            ),
          ],
        ),
        formulas: f,
      );

      expect(
        PivotLayout.build(r).toValues(),
        table([
          ['Region', 'Price'],
          ['East', 10],
          ['North', 10],
          ['West', 10],
          ['Grand Total', 10],
        ]),
      );
      expect(f.groupCalls, 4);
    });

    test('when no evaluator is available then calculated values are '
        '#NAME?', () {
      final r = compute(
        PivotSpec(values: [PivotValueSpec(formula: _priceFormula)]),
      );

      expect(
        r.rawValue(r.rowRoot, r.columnRoot, 0),
        isA<ErrorValue>().having((e) => e.kind, 'kind', CellErrorKind.name),
      );
    });
  });

  group('Given unusual source data', () {
    test('when a summed column holds an error then the group shows it', () {
      final r = compute(
        PivotSpec(rows: [field(region)], values: const [sumRevenue]),
        source: salesTable(
          extraRows: [
            ['North', 'Apple', day(2026, 1, 1), 1, CellErrorKind.div0],
          ],
        ),
      );
      final north = r.rowRoot.children[1];

      expect(
        r.rawValue(north, r.columnRoot, 0),
        const ErrorValue(CellErrorKind.div0),
      );
      expect(
        r.rawValue(r.rowRoot.children.first, r.columnRoot, 0),
        const NumberValue(170),
      );
    });

    test('when fields reference missing columns then they are ignored', () {
      final r = compute(
        PivotSpec(
          rows: const [PivotGroupSpec('gone')],
          values: const [
            PivotValueSpec(source: 'gone'),
            PivotValueSpec(source: revenue, summarizeBy: PivotSummarize.min),
          ],
          filters: [PivotFilterSpec('gone', _hideAll)],
        ),
      );

      expect(r.rowFields, isEmpty);
      expect(r.valueFields.single.specIndex, 1);
      expect(r.valueIndexOfSpec(0), -1);
      expect(r.rawValue(r.rowRoot, r.columnRoot, 0), const NumberValue(10));
    });

    test('when the computation is cancelled then the result is empty', () {
      final token = CancellationToken()..cancel();

      final r = compute(
        PivotSpec(rows: [field(region)], values: const [sumRevenue]),
        cancel: token,
      );

      expect(r.cancelled, isTrue);
      expect(r.rowRoot.children, isEmpty);
    });
  });

  group('Given a pivot by Region and Product', () {
    late PivotResult r;
    setUp(() {
      r = compute(
        PivotSpec(
          rows: [field(region)],
          columns: [field(product)],
          values: const [sumRevenue],
        ),
      );
    });

    test('when drilling into East × Apple then the contributing source row '
        'is returned', () {
      final east = r.rowRoot.children.first;
      final apple = r.columnRoot.children.first;

      expect(r.drillDownRows(east, apple), [0]);
      expect(r.drillDownRows(east, r.columnRoot), [0, 2]);
      expect(r.drillDownRows(r.rowRoot, r.columnRoot), [0, 1, 2, 3, 4]);
    });

    test('when building the drill-down table then the header row comes '
        'first', () {
      final table = r.drillDownTable(
        r.rowRoot.children.last,
        r.columnRoot.children.last,
      );

      expect(table.first.first, const TextValue('Region'));
      expect(table.skip(1).map((row) => row[4]), [const NumberValue(30)]);
    });

    test('when reading node paths then keys run outermost first', () {
      final east = r.rowRoot.children.first;

      expect(east.path.single.labelText, 'East');
      expect(r.rowRoot.isRoot, isTrue);
      expect(
        r.rowRoot.childWhere((k) => k.labelText == 'West')?.key?.labelText,
        'West',
      );
    });
  });
}

final _hideAll = ColumnCriteria(hiddenValues: const ['x']);
