import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

import 'support/sample_data.dart';

void main() {
  const size = ChartSize(600, 371);
  const spec = ChartSpec(type: ChartType.column);

  group('Given resolved ChartData without any spreadsheet', () {
    test(
      'when laying out then the scene has the chart size and series texts',
      () {
        final layout = ChartPipeline.layout(
          spec,
          sampleData(),
          size: size,
          theme: sampleTheme,
          measurer: const ApproxTextMeasurer(),
        );
        expect(layout.scene.width, 600);
        expect(layout.scene.height, 371);
        final texts = jsonEncode(layout.scene.toJson());
        expect(texts, contains('North'));
        expect(texts, contains('Jan'));
      },
    );

    test('when building then data and layout warnings are combined', () {
      final data = sampleData();
      final build = ChartPipeline.build(
        spec,
        data,
        size: size,
        theme: sampleTheme,
        measurer: const ApproxTextMeasurer(),
      );
      expect(build.data, same(data));
      expect(build.warnings, [...data.warnings, ...build.layoutWarnings]);
    });

    test(
      'when exporting SVG, PDF and PNG then each format is produced',
      () async {
        final svg = ChartPipeline.exportSvg(
          spec,
          sampleData(),
          size: size,
          theme: sampleTheme,
        );
        expect(svg, contains('<svg'));
        final pdf = await ChartPipeline.exportPdf(
          spec,
          sampleData(),
          size: size,
          theme: sampleTheme,
        );
        expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
        final png = ChartPipeline.exportPng(
          spec,
          sampleData(),
          size: size,
          theme: sampleTheme,
        );
        expect(png.sublist(1, 4), ascii.encode('PNG'));
      },
    );

    test('when a locale is given then labels use its number symbols', () {
      final svg = ChartPipeline.exportSvg(
        ChartSpec.fromJson({
          'v': 1,
          'type': 'column',
          'data': {'ranges': <Object?>[]},
          'series': {
            'south': {
              'dataLabels': {'show': true},
            },
          },
        }),
        sampleData(),
        size: size,
        theme: sampleTheme,
        locale: 'de_DE',
      );
      expect(svg, contains('28,5'));
    });
  });
}
