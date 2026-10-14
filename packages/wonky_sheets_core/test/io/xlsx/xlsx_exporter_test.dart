import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/io_support.dart';
import '../support/ir_corpus.dart';

final _options = XlsxExportOptions(modified: DateTime.utc(2026, 3, 4));

ZipPackage _export(WorkbookDocument doc, [ImportWarnings? report]) =>
    ZipPackage.open(XlsxExporter.export(doc, _options, report));

void main() {
  group('Given a simple document', () {
    late WorkbookDocument doc;
    setUp(() {
      doc = irDoc([
        irSheet('Data', [
          [1, 'two', true],
          ['=A1*2', null, null],
        ]),
      ]);
    });

    test('when exporting then the package has the required parts', () {
      final pkg = _export(doc);
      expect(
        pkg.names,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'xl/workbook.xml',
          'xl/_rels/workbook.xml.rels',
          'xl/styles.xml',
          'xl/sharedStrings.xml',
          'xl/theme/theme1.xml',
          'xl/worksheets/sheet1.xml',
          'docProps/core.xml',
          'docProps/app.xml',
        ]),
      );
    });

    test('when exporting then the content types part comes first', () {
      final archive = ZipDecoder().decodeBytes(
        XlsxExporter.export(doc, _options),
      );
      expect(archive.files.first.name, '[Content_Types].xml');
    });

    test('when exporting twice then the bytes are identical', () {
      expect(
        XlsxExporter.export(doc, _options),
        XlsxExporter.export(doc, _options),
      );
    });

    test('when exporting then cells are typed', () {
      final xml = _export(doc).text('xl/worksheets/sheet1.xml')!;
      expect(xml, contains('<c r="A1"><v>1</v></c>'));
      expect(xml, contains('<c r="B1" t="s"><v>0</v></c>'));
      expect(xml, contains('<c r="C1" t="b"><v>1</v></c>'));
      expect(xml, contains('<c r="A2"><f>A1*2</f></c>'));
    });
  });

  group('Given sheet names Excel does not accept', () {
    test('when exporting then names are made valid and unique', () {
      final taken = <String>{};
      expect(XlsxExporter.excelSheetName('a/b:c', taken), 'a_b_c');
      expect(XlsxExporter.excelSheetName('A_B_C', taken), 'A_B_C (2)');
      expect(XlsxExporter.excelSheetName("'${'x' * 40}'", taken), 'x' * 31);
    });

    test('when a sheet is renamed then formulas follow it', () {
      final doc = irDoc([
        irSheet('Q1/Q2', [
          [1],
        ]),
        irSheet('Other', [
          ["='Q1/Q2'!A1+1"],
        ]),
      ]);
      final report = ImportWarnings();
      final pkg = _export(doc, report);
      expect(
        pkg.text('xl/worksheets/sheet2.xml'),
        contains('<f>Q1_Q2!A1+1</f>'),
      );
      expect(report.withCode('sheetRenamed'), hasLength(1));
    });
  });

  group('Given formulas with newer and Google-only functions', () {
    late ZipPackage pkg;
    late ImportWarnings report;
    setUp(() {
      final s = IrSheet('F');
      s.cells
        ..set(0, 0, const IrCell(formulaA1: 'IFS(B1>0,1,TRUE,2)'))
        ..set(1, 0, const IrCell(formulaA1: 'FILTER(B1:B3,B1:B3>0)'))
        ..set(2, 0, const IrCell(formulaA1: 'SPLIT("a,b",",")'))
        ..set(
          3,
          0,
          const IrCell(
            formulaA1: 'ARRAYFORMULA(B1:B3*2)',
            arrayRef: GridRect(3, 0, 5, 0),
          ),
        );
      report = ImportWarnings();
      pkg = _export(irDoc([s]), report);
    });

    test('when exporting then post-2007 functions get the _xlfn prefix', () {
      final xml = pkg.text('xl/worksheets/sheet1.xml')!;
      expect(xml, contains('<f>_xlfn.IFS(B1&gt;0,1,TRUE,2)</f>'));
      expect(xml, contains('_xlfn._xlws.FILTER(B1:B3,B1:B3&gt;0)'));
    });

    test('when exporting then Google-only functions are reported', () {
      expect(
        report.withCode('googleOnlyFunction').single.message,
        contains('SPLIT'),
      );
    });

    test('when exporting ARRAYFORMULA then it is a dynamic array', () {
      final xml = pkg.text('xl/worksheets/sheet1.xml')!;
      expect(
        xml,
        contains('<c r="A4" cm="1"><f t="array" ref="A4:A6">B1:B3*2</f></c>'),
      );
      expect(pkg.has('xl/metadata.xml'), isTrue);
    });
  });

  group('Given inherited formats', () {
    test('when exporting then cell styles include column formats', () {
      final doc = irDoc([IrSheet('S')]);
      final s = doc.sheets.single;
      s.columns[0] = IrDim(
        format: doc.formats.internAttrs(CellFormat({FormatAttr.bold: true})),
      );
      s.cells.set(
        0,
        0,
        IrCell(
          value: const IrNumber(1),
          format: doc.formats.internAttrs(
            CellFormat({FormatAttr.italic: true}),
          ),
        ),
      );
      final back = XlsxImporter.import(XlsxExporter.export(doc, _options));
      final cell = back.sheets.single.cells.get(0, 0)!;
      expect(
        IrFormats.effective(back, back.sheets.single, 0, 0, cell).toMap(),
        {'bold': true, 'italic': true},
      );
    });
  });

  group('Given early dates', () {
    test(
      'when exporting then serials before 1900-03-01 use Excel numbering',
      () {
        final doc = irDoc([IrSheet('D')]);
        doc.sheets.single.cells.set(
          0,
          0,
          IrCell(
            value: const IrNumber(31),
            format: doc.formats.internAttrs(
              CellFormat({FormatAttr.numberFormat: 'yyyy-mm-dd'}),
            ),
          ),
        );
        final xml = _export(doc).text('xl/worksheets/sheet1.xml')!;
        expect(xml, contains('<v>30</v>'));
      },
    );
  });

  group('Given notes and links', () {
    late ZipPackage pkg;
    setUp(() {
      final s = IrSheet('N');
      s.cells
        ..set(0, 0, const IrCell(value: IrText('a'), note: 'Line 1\nLine 2'))
        ..set(
          1,
          0,
          const IrCell(value: IrText('w'), link: 'https://x.y/?a=1&b=2'),
        )
        ..set(2, 0, const IrCell(value: IrText('i'), link: '#N!B4'));
      pkg = _export(irDoc([s]));
    });

    test('when exporting notes then comments and VML parts are written', () {
      expect(pkg.text('xl/comments1.xml'), contains('Line 1\nLine 2'));
      expect(pkg.has('xl/drawings/vmlDrawing1.vml'), isTrue);
    });

    test('when exporting links then external ones use relationships', () {
      final xml = pkg.text('xl/worksheets/sheet1.xml')!;
      expect(xml, contains('<hyperlink ref="A2" r:id="rId1"/>'));
      expect(xml, contains('location="N!B4"'));
      expect(
        pkg.text('xl/worksheets/_rels/sheet1.xml.rels'),
        contains('Target="https://x.y/?a=1&amp;b=2" TargetMode="External"'),
      );
    });
  });

  group('Given charts', () {
    late ZipPackage pkg;
    late ImportWarnings report;
    setUp(() {
      final doc = IrCorpus.charts();
      doc.sheets.single.charts.add(
        const IrChart(
          anchor: IrAnchor(row: 0, col: 9, width: 300, height: 200),
          spec: {
            'v': 1,
            'type': 'histogram',
            'data': {
              'ranges': [r'Sales!$B$1:$B$4'],
            },
          },
        ),
      );
      report = ImportWarnings();
      pkg = _export(doc, report);
    });

    test('when exporting then each mappable chart is a chart part', () {
      expect(
        [
          for (final n in pkg.names)
            if (n.startsWith('xl/charts/')) n,
        ]..sort(),
        [
          'xl/charts/chart1.xml',
          'xl/charts/chart2.xml',
          'xl/charts/chart3.xml',
          'xl/charts/chart4.xml',
        ],
      );
      expect(pkg.text('[Content_Types].xml'), contains('drawingml.chart+xml'));
      expect(
        pkg.xml('xl/charts/chart1.xml')!.rootElement.localName,
        'chartSpace',
      );
    });

    test('when exporting a column chart then series reference the cells', () {
      final xml = pkg.text('xl/charts/chart1.xml')!;
      expect(xml, contains('<c:grouping val="stacked"/>'));
      expect(xml, contains(r'<c:f>Sales!$B$2:$B$4</c:f>'));
      expect(xml, contains(r'<c:f>Sales!$B$1</c:f>'));
      expect(xml, contains('<a:srgbClr val="FF0000"/>'));
    });

    test('when a chart type has no Excel equivalent then it is reported', () {
      expect(
        report.withCode('chartsNotExported').single.message,
        'Charts of type histogram were not exported (no Excel equivalent)',
      );
    });
  });

  group('Given a model', () {
    test('when exporting through ModelToIr then the file opens again', () {
      final r = importNew(
        irDoc([
          irSheet('S', [
            [1, 2, '=A1+B1'],
          ]),
        ]),
      );
      final back = XlsxImporter.import(
        XlsxExporter.export(irOf(r.model), _options),
      );
      final c = back.sheets.single.cells.get(0, 2)!;
      expect(c.formulaA1, 'A1+B1');
      expect(c.value, const IrNumber(3));
    });
  });
}
