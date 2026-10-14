@Tags(['property'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/chart_test_support.dart';

Object? randomCell(math.Random r) => switch (r.nextInt(10)) {
  0 => null,
  1 => 'label${r.nextInt(5)}',
  2 => CellErrorKind.values[r.nextInt(CellErrorKind.values.length)],
  3 => r.nextBool(),
  4 => -r.nextDouble() * 100,
  5 => 0,
  _ => r.nextDouble() * 1000,
};

ChartSpec randomSpec(math.Random r, WorkbookModel model, String a1) {
  final types = [for (final t in ChartType.values) t];
  final type = types[r.nextInt(types.length)];
  final base = specFor(
    model,
    a1,
    type: type,
    switched: r.nextInt(5) == 0,
    headerCount: r.nextBool() ? null : r.nextInt(3),
    aggregate: r.nextInt(4) == 0
        ? ChartAggregate.values[r.nextInt(ChartAggregate.values.length)]
        : null,
  );
  final key = model.sheets.first.columns.idAt(1);
  return base.copyWith(
    stacking: ChartStacking.values[r.nextInt(3)],
    title: ChartTitle(text: r.nextBool() ? 'Title' : ''),
    style: ChartStyle(smooth: r.nextBool(), maximize: r.nextInt(4) == 0),
    legend: ChartLegend(
      position: LegendPosition.values[r.nextInt(LegendPosition.values.length)],
    ),
    axes: ChartAxes(
      v: ChartAxis(logScale: r.nextInt(5) == 0, reverse: r.nextInt(6) == 0),
      h: ChartAxis(
        labels: AxisLabels(
          slant: LabelSlant.values[r.nextInt(LabelSlant.values.length)],
          angle: r.nextDouble() * 180 - 90,
        ),
      ),
    ),
    series: {
      key: SeriesStyle(
        axis: r.nextBool() ? SeriesAxis.right : SeriesAxis.left,
        dataLabels: DataLabelsSpec(
          show: r.nextBool(),
          position: DataLabelPosition
              .values[r.nextInt(DataLabelPosition.values.length)],
        ),
        trendline: r.nextBool()
            ? TrendlineSpec(
                type: TrendlineType
                    .values[r.nextInt(TrendlineType.values.length)],
                degree: 2 + r.nextInt(4),
                period: 2 + r.nextInt(3),
                label: TrendlineLabel.values[r.nextInt(3)],
              )
            : null,
      ),
    },
    typeOptions: {
      'pieHole': r.nextBool() ? 0.5 : 0,
      'firstValueIsSubtotal': r.nextBool(),
      'pageSize': r.nextInt(4),
      'sortColumn': r.nextInt(3),
      'showItemDividers': r.nextBool(),
    },
  );
}

void main() {
  for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
    test(
      'when laying out and rendering random charts (seed $seed) then nothing throws',
      () {
        final r = math.Random(seed);
        for (var k = 0; k < 25; k++) {
          final rows = 1 + r.nextInt(15);
          final cols = 1 + r.nextInt(5);
          final model = buildTable([
            for (var i = 0; i < rows; i++)
              [for (var c = 0; c < cols; c++) randomCell(r)],
          ]).$2;
          final a1 = 'A1:${String.fromCharCode(0x41 + cols - 1)}$rows';
          final spec = randomSpec(r, model, a1);
          final size = [
            testChartSize,
            const ChartSize(120, 80),
            const ChartSize(30, 20),
            const ChartSize(0, 0),
          ][r.nextInt(4)];

          final data = resolveChart(spec, model);
          final layout = layoutChart(spec, data, size: size);

          expect(layout.scene.width, size.width);
          const SvgChartRenderer().render(layout.scene);
          if (size.width > 0) {
            const RasterChartRenderer().renderImage(layout.scene, scale: 0.5);
          }
          expect(
            layout.scene.flattened.whereType<SText>().every(
              (t) => t.at.x.isFinite && t.at.y.isFinite,
            ),
            isTrue,
            reason: 'type ${spec.type.id}',
          );
        }
      },
    );
  }
}
