import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:xml/xml.dart';

import '../support/ir_corpus.dart';

void main() {
  group('Given 2D and 3D charts exported to ODS (08 §23, 11 §6.4)', () {
    late ZipPackage pkg;
    late ImportWarnings report;
    setUp(() {
      final doc = IrCorpus.charts();
      final sheet = doc.sheets.single;
      final data = sheet.charts.first.spec['data'];
      IrChart chart(int i, Map<String, Object?> spec) => IrChart(
        anchor: IrAnchor(row: i * 20, col: 4, width: 480, height: 300),
        spec: {'v': 1, 'data': data, ...spec},
      );
      sheet.charts
        ..clear()
        ..addAll([
          chart(0, {
            'type': 'column',
            'title': {'text': 'Revenue'},
            'threeD': {
              'enabled': true,
              'azimuth': 30,
              'elevation': 25,
              'shape': 'cylinder',
            },
          }),
          chart(1, {
            'type': 'line',
            'threeD': {'enabled': true},
          }),
          chart(2, {'type': 'pie'}),
          chart(3, {'type': 'surface'}),
          chart(4, {'type': 'scorecard'}),
        ]);
      report = ImportWarnings();
      pkg = ZipPackage.open(
        OdsExporter.export(
          doc,
          OdsExportOptions(modified: DateTime.utc(2026, 3, 4)),
          report,
        ),
      );
    });

    test('when exporting then each supported chart is an embedded chart '
        'object shown by a frame on its sheet', () {
      final content = pkg.text('content.xml')!;
      XmlDocument.parse(content);
      expect(content, contains('<table:shapes>'));
      expect('xlink:href="./Object '.allMatches(content), hasLength(4));
      final manifest = pkg.text('META-INF/manifest.xml')!;
      expect(
        manifest,
        contains(
          'manifest:full-path="Object 1/" '
          'manifest:media-type="application/vnd.oasis.opendocument.chart"',
        ),
      );
      for (var i = 1; i <= 4; i++) {
        XmlDocument.parse(pkg.text('Object $i/content.xml')!);
      }
      expect(report.withCode('chart'), hasLength(1), reason: 'scorecard');
    });

    test('when a chart is 3D then the object is three-dimensional with its '
        'shape, depth and view', () {
      final column = pkg.text('Object 1/content.xml')!;
      expect(column, contains('chart:class="chart:bar"'));
      expect(column, contains('chart:three-dimensional="true"'));
      expect(column, contains('chart:solid-type="cylinder"'));
      expect(column, contains('dr3d:transform="rotatey('));
      expect(column, contains('<text:p>Revenue</text:p>'));
      expect(column, contains('chart:values-cell-range-address="'));
      final line = pkg.text('Object 2/content.xml')!;
      expect(line, contains('chart:deep="true"'));
      expect(line, contains('chart:dimension="z"'));
      final pie = pkg.text('Object 3/content.xml')!;
      expect(pie, contains('chart:class="chart:circle"'));
      expect(pie, isNot(contains('three-dimensional')));
      final surface = pkg.text('Object 4/content.xml')!;
      expect(surface, contains('chart:class="chart:surface"'));
      expect(surface, contains('chart:three-dimensional="true"'));
    });
  });
}
