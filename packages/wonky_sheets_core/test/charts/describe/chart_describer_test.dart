import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/charts/charts.dart';

import '../support/chart_test_support.dart';

void main() {
  group('Given the monthly revenue table', () {
    final model = monthlyRevenue();

    test(
      'when describing a titled column chart then type, title, series and X axis are named',
      () {
        final spec = specFor(
          model,
          'A1:D13',
        ).copyWith(title: const ChartTitle(text: 'Revenue'));

        expect(
          ChartDescriber.describe(spec, resolveChart(spec, model)),
          'Column chart: Revenue. 3 series: North, South, East. '
          'X axis: Month, Jan to Dec.',
        );
      },
    );

    test(
      'when the chart has no title then the type ends the first sentence',
      () {
        final spec = specFor(model, 'A1:D13', type: ChartType.line);

        expect(
          ChartDescriber.describe(spec, resolveChart(spec, model)),
          startsWith('Line chart. 3 series'),
        );
      },
    );

    test('when describing a doughnut then only the drawn series is listed', () {
      final spec = specFor(
        model,
        'A1:D13',
        type: ChartType.pie,
        typeOptions: {'pieHole': 0.5},
      );

      expect(
        ChartDescriber.describe(spec, resolveChart(spec, model)),
        'Doughnut chart. 1 series: North. X axis: Month, Jan to Dec.',
      );
    });

    test('when describing a table then its size is given', () {
      final spec = specFor(model, 'A1:D13', type: ChartType.table);

      expect(
        ChartDescriber.describe(spec, resolveChart(spec, model)),
        'Table chart. 12 rows, 4 columns.',
      );
    });
  });

  group('Given data without a header', () {
    test('when the domain has no header then its column letter names it', () {
      final (_, model) = buildTable([
        ['a', 1],
        ['b', 2],
      ]);
      final spec = specFor(model, 'A1:B2', headerCount: 0);

      expect(
        ChartDescriber.describe(spec, resolveChart(spec, model)),
        'Column chart. 1 series: Column B. X axis: Column A, a to b.',
      );
    });
  });
}
