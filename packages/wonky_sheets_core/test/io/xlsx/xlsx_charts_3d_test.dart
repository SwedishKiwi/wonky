import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/ir_corpus.dart';

final _options = XlsxExportOptions(modified: DateTime.utc(2026, 3, 4));

/// The charts corpus with its charts replaced by [specs] (data of the corpus).
WorkbookDocument _doc(List<Map<String, Object?>> specs) {
  final doc = IrCorpus.charts();
  final sheet = doc.sheets.single;
  final data = sheet.charts.first.spec['data'];
  sheet.charts
    ..clear()
    ..addAll([
      for (var i = 0; i < specs.length; i++)
        IrChart(
          anchor: IrAnchor(row: i * 20, col: 4, width: 480, height: 300),
          spec: {'v': 1, 'data': data, ...specs[i]},
        ),
    ]);
  return doc;
}

void main() {
  group('Given 3D charts', () {
    late ZipPackage pkg;
    late WorkbookDocument back;
    setUp(() {
      final doc = _doc([
        {
          'type': 'column',
          'threeD': {
            'enabled': true,
            'azimuth': 30,
            'elevation': 25,
            'perspective': 20,
            'depth': 150,
            'gapDepth': 80,
            'shape': 'cylinder',
            'floorColor': '#AABBCC',
          },
        },
        {
          'type': 'pie',
          'threeD': {'enabled': true, 'elevation': 50},
        },
        {
          'type': 'line',
          'threeD': {'enabled': true, 'perspective': 0},
        },
        {
          'type': 'area',
          'stacking': 'normal',
          'threeD': {'enabled': true, 'wallsVisible': false},
        },
      ]);
      final bytes = XlsxExporter.export(doc, _options);
      pkg = ZipPackage.open(bytes);
      back = XlsxImporter.import(bytes);
    });

    test(
      'when exporting then Excel 3-D chart groups and view3D are written',
      () {
        final column = pkg.text('xl/charts/chart1.xml')!;
        final pie = pkg.text('xl/charts/chart2.xml')!;
        final line = pkg.text('xl/charts/chart3.xml')!;
        final area = pkg.text('xl/charts/chart4.xml')!;

        expect(column, contains('<c:bar3DChart>'));
        expect(column, contains('<c:rotX val="25"/><c:rotY val="30"/>'));
        expect(column, contains('<c:perspective val="40"/>'));
        expect(column, contains('<c:shape val="cylinder"/>'));
        expect(column, contains('<a:srgbClr val="AABBCC"/>'));
        expect(pie, contains('<c:pie3DChart>'));
        expect(line, contains('<c:line3DChart>'));
        expect(line, contains('<c:serAx>'));
        expect(line, contains('<c:rAngAx val="1"/>'));
        expect(area, contains('<c:area3DChart><c:grouping val="stacked"/>'));
        expect(area, isNot(contains('<c:serAx>')));
      },
    );

    test('when importing the file again then threeD is restored', () {
      final specs = [for (final c in back.sheets.single.charts) c.spec];

      expect(specs[0]['type'], 'column');
      expect(specs[0]['threeD'], {
        'enabled': true,
        'elevation': 25,
        'azimuth': 30,
        'depth': 150,
        'perspective': 20,
        'gapDepth': 80,
        'shape': 'cylinder',
        'floorColor': '#AABBCC',
      });
      expect(specs[1]['threeD'], {
        'enabled': true,
        'elevation': 50,
        'azimuth': 0,
      });
      expect(specs[2]['threeD'], containsPair('perspective', 0));
      expect(specs[3]['threeD'], containsPair('wallsVisible', false));
      expect(specs[3]['stacking'], 'normal');
    });

    test('when importing then the 3D sections are valid', () {
      for (final c in back.sheets.single.charts) {
        // IR data ranges are A1 text; the rest must be a valid stored spec.
        final stored = {
          ...c.spec,
          'data': {'ranges': <Object?>[]},
        };
        expect(ChartSpecSchema.validate(stored), isEmpty);
        expect(ChartSpec.fromJson(c.spec).is3D, isTrue);
      }
    });
  });
}
