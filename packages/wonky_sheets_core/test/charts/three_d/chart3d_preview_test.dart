@Tags(['slow'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/chart_test_support.dart';

void main() {
  final dir = Platform.environment['CHART3D_PREVIEW'];
  test('preview', () {
    if (dir == null) return;
    final m = monthlyRevenue();
    void png(String name, ChartSpec spec, {bool dark = false}) {
      final theme = ChartTheme.from(
        SpreadsheetTheme.standard,
        dark: dark,
        export: true,
      );
      final scene = sceneOf(spec, m, theme: theme);
      final bytes = const RasterChartRenderer().render(scene, scale: 2);
      File('$dir/$name.png').writeAsBytesSync(bytes);
      File(
        '$dir/$name.svg',
      ).writeAsStringSync(const SvgChartRenderer().render(scene));
    }

    ChartSpec s(
      ChartType t, {
      ChartStacking st = ChartStacking.none,
      Map<String, Object?> td = const {},
      String range = 'A1:D7',
      Map<String, Object?> typeOptions = const {},
    }) => specFor(m, range, type: t, typeOptions: typeOptions).copyWith(
      stacking: st,
      threeD: ChartThreeD.fromJson({'enabled': true, ...td}),
    );
    png('column', s(ChartType.column));
    png('column_dark', s(ChartType.column), dark: true);
    png('stacked', s(ChartType.column, st: ChartStacking.normal));
    png('bar', s(ChartType.bar));
    png('line', s(ChartType.line, range: 'A1:D13'));
    png('area', s(ChartType.area, range: 'A1:D13'));
    png('pie', s(ChartType.pie, range: 'A1:B7', td: {'explode': 0.1}));
    png(
      'donut',
      s(ChartType.pie, range: 'A1:B7', typeOptions: {'pieHole': 0.5}),
    );
    png('cyl', s(ChartType.column, td: {'shape': 'cylinder', 'azimuth': 330}));
  });
}
