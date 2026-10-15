import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:xml/xml.dart';

import 'support/chart_test_support.dart';

void main() {
  late WorkbookModel model;
  late ChartSpec spec;
  setUp(() {
    model = monthlyRevenue();
    spec = specFor(
      model,
      'A1:D13',
    ).copyWith(title: const ChartTitle(text: 'Revenue by month'));
  });

  group('Given the monthly revenue column chart', () {
    test(
      'when building it then data, scene and warnings come back together',
      () {
        final built = SheetsChartPipeline.build(
          spec: spec,
          model: model,
          values: ModelCellSource(model),
          size: testChartSize,
          theme: SheetsChartPipeline.exportTheme(model),
          measurer: const ApproxTextMeasurer(),
        );

        expect(built.data.series, hasLength(3));
        expect(built.scene.width, 600);
        expect(built.warnings, isEmpty);
        expect(
          primitivesOf<SRect>(built.scene, SceneRole.point),
          hasLength(36),
        );
      },
    );

    test('when resolving then the spreadsheet locale formats the labels', () {
      final data = SheetsChartPipeline.resolve(
        spec,
        model,
        ModelCellSource(model),
      );

      expect(data.domain.labels.first, 'Jan');
    });

    test(
      'when exporting SVG then it is a well-formed document with every column',
      () {
        final svg = SheetsChartPipeline.exportSvg(
          spec: spec,
          model: model,
          values: ModelCellSource(model),
          size: testChartSize,
        );

        final doc = XmlDocument.parse(svg);
        expect(doc.rootElement.getAttribute('width'), '600');
        final plot = doc
            .findAllElements('g')
            .singleWhere((g) => g.getAttribute('clip-path') != null);
        expect(plot.findElements('rect'), hasLength(36));
        expect(
          doc.findAllElements('text').map((t) => t.innerText),
          containsAll(['Revenue by month', 'North', 'Jan', 'Dec']),
        );
      },
    );

    test('when exporting SVG then the output matches the golden', () {
      final svg = SheetsChartPipeline.exportSvg(
        spec: spec,
        model: model,
        values: ModelCellSource(model),
        size: testChartSize,
      );

      expectGoldenText('column_monthly.svg', svg);
    });

    test('when exporting PDF then a PDF document is made', () async {
      final bytes = await SheetsChartPipeline.exportPdf(
        spec: spec,
        model: model,
        values: ModelCellSource(model),
        size: testChartSize,
      );

      final head = latin1.decode(bytes.sublist(0, 8));
      expect(head, startsWith('%PDF-'));
      expect(latin1.decode(bytes.sublist(bytes.length - 7)), contains('%%EOF'));
    });

    test('when exporting PNG at 2× then the image is twice the chart size', () {
      final bytes = SheetsChartPipeline.exportPng(
        spec: spec,
        model: model,
        values: ModelCellSource(model),
        size: testChartSize,
        scale: 2,
      );

      final image = img.decodePng(bytes)!;
      expect(image.width, 1200);
      expect(image.height, 742);
      // The automatic export background is white.
      final corner = image.getPixel(1, 1);
      expect([corner.r, corner.g, corner.b], [255, 255, 255]);
    });

    test(
      'when printing then chart objects get a scene of the printed size',
      () {
        final sceneFor = SheetsChartPipeline.printSceneFor(
          model,
          ModelCellSource(model),
        );
        EmbeddedObjectRecord object(EmbeddedObjectKind kind) =>
            EmbeddedObjectRecord(
              id: 'o1',
              sheetId: model.sheets.first.id,
              kind: kind,
              anchorJson: '{}',
              specJson: spec.encode(),
            );

        final scene = sceneFor(object(EmbeddedObjectKind.chart), 300, 200)!;

        expect(scene.width, 300);
        expect(primitivesOf<SRect>(scene, SceneRole.point), hasLength(36));
        expect(sceneFor(object(EmbeddedObjectKind.image), 300, 200), isNull);
      },
    );

    test(
      'when exporting PNG with the dark theme then the background is dark',
      () {
        final bytes = SheetsChartPipeline.exportPng(
          spec: spec,
          model: model,
          values: ModelCellSource(model),
          size: testChartSize,
          dark: true,
        );

        final corner = img.decodePng(bytes)!.getPixel(1, 1);
        expect(corner.r, lessThan(64));
      },
    );
  });
}
