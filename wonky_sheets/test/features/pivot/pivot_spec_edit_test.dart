import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/pivot/pivot_formula_text.dart';
import 'package:wonky_sheets/features/pivot/pivot_spec_edit.dart';
import 'package:wonky_sheets_core/model.dart';

void main() {
  group('Given a spec with Region in Rows and two values', () {
    const spec = PivotSpec(
      rows: [PivotGroupSpec('region', sortByValueIndex: 1)],
      values: [
        PivotValueSpec(source: 'units'),
        PivotValueSpec(source: 'revenue'),
      ],
    );

    test('when Region moves to Columns then it keeps its options', () {
      final next = spec.move(PivotArea.row, 0, PivotArea.column, 0);

      expect(next.rows, isEmpty);
      expect(next.columns.single.source, 'region');
      expect(next.columns.single.sortByValueIndex, 1);
    });

    test('when Region moves to Filters then it becomes an empty filter', () {
      final next = spec.move(PivotArea.row, 0, PivotArea.filter, 0);

      expect(next.filters.single.source, 'region');
      expect(next.filters.single.criteria.isEmpty, isTrue);
    });

    test('when the first value is removed then sort-by-value follows the '
        'remaining value', () {
      final next = spec.removeAt(PivotArea.value, 0);

      expect(next.values.single.source, 'revenue');
      expect(next.rows.single.sortByValueIndex, 0);
    });

    test(
      'when the sorted value is removed then sorting falls back to labels',
      () {
        final next = spec.removeAt(PivotArea.value, 1);

        expect(next.rows.single.sortByValueIndex, isNull);
      },
    );

    test('when values are reordered then sort-by-value points at the same '
        'value', () {
      final next = spec.move(PivotArea.value, 1, PivotArea.value, 0);

      expect(next.values.first.source, 'revenue');
      expect(next.rows.single.sortByValueIndex, 0);
    });

    test('when a field is added to Values then it uses the given summary', () {
      final next = spec.addField(
        PivotArea.value,
        'region',
        summarize: PivotSummarize.counta,
      );

      expect(next.values.last.summarizeBy, PivotSummarize.counta);
    });

    test(
      'when a date grouping is set on Region then the Rows field gets it',
      () {
        final (next, found) = spec.withGrouping(
          'region',
          const PivotDateGrouping(PivotDateUnit.year),
        );

        expect(found, isTrue);
        expect(next.rows.single.group, isA<PivotDateGrouping>());
      },
    );
  });

  group('Given calculated field text with header names', () {
    final text = PivotFormulaText(
      fields: const [
        PivotSourceField('c1', 'Unit price', PivotFieldKind.number),
        PivotSourceField('c2', 'Quantity', PivotFieldKind.number),
      ],
      sheetId: 's',
    );

    test('when converted to stored form then headers become field tokens', () {
      expect(
        text.toStored("='Unit price' * Quantity"),
        '=${PivotFormula.tokenOf('c1')} * ${PivotFormula.tokenOf('c2')}',
      );
    });

    test('when converted back then the headers are shown (quoted when '
        'needed)', () {
      final stored =
          '=SUM(${PivotFormula.tokenOf('c2')})/${PivotFormula.tokenOf('c1')}';

      expect(text.toA1(stored), "=SUM(Quantity)/'Unit price'");
    });

    test('when a field no longer exists then it reads #REF!', () {
      expect(text.toA1('=${PivotFormula.tokenOf('gone')}*2'), '=#REF!*2');
    });
  });
}
