import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

Uint8List _bytes(Object json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

void main() {
  group('Given a workbook document exported as JSON', () {
    test('when exporting then values are unformatted and formulas and '
        'number formats are listed', () {
      final doc = WorkbookDocument(title: 'Budget', locale: 'en_US');
      final s = IrSheet('Data');
      final pct = doc.formats.internAttrs(
        CellFormat({FormatAttr.numberFormat: '0.00%'}),
      );
      s.cells.set(0, 0, const IrCell(value: IrText('Item')));
      s.cells.set(1, 0, const IrCell(value: IrNumber(1.5)));
      s.cells.set(1, 1, IrCell(value: const IrNumber(0.25), format: pct));
      s.cells.set(2, 0, const IrCell(value: IrNumber(3), formulaA1: 'A2*2'));
      s.cells.set(2, 1, const IrCell(value: IrBool(true)));
      doc.sheets.add(s);

      final json = JsonWorkbook.toJson(doc);

      expect(json['title'], 'Budget');
      final sheet = (json['sheets']! as List).single as Map;
      expect(sheet['name'], 'Data');
      expect(sheet['values'], [
        ['Item', null],
        [1.5, 0.25],
        [3, true],
      ]);
      expect((sheet['formulas'] as List)[2], ['=A2*2', null]);
      expect((sheet['numberFormats'] as List)[1], [null, '0.00%']);
    });

    test('when importing the export then the document round-trips', () {
      final doc = CsvImporter.importText(
        'a,b\n1,=A2+1\nx,#N/A\n',
        const CsvImportOptions(sheetName: 'S'),
      );

      final back = JsonWorkbook.import(JsonWorkbook.export(doc));

      final s = back.sheets.single;
      expect(s.name, 'S');
      expect(s.cells.get(1, 0)?.value, const IrNumber(1));
      expect(s.cells.get(1, 1)?.formulaA1, 'A2+1');
      expect(s.cells.get(2, 1)?.value, isA<IrError>());
    });
  });

  group('Given developer JSON shapes', () {
    test('when importing an array of objects then the keys are the header '
        'row', () {
      final doc = JsonWorkbook.import(
        _bytes([
          {'name': 'Ann', 'age': 31},
          {'name': 'Bo', 'city': 'Oslo'},
        ]),
        fileName: 'people.json',
      );

      final s = doc.sheets.single;
      expect(s.name, 'people');
      expect(s.cells.get(0, 2)?.value, const IrText('city'));
      expect(s.cells.get(1, 1)?.value, const IrNumber(31));
      expect(s.cells.get(2, 2)?.value, const IrText('Oslo'));
      expect(s.cells.get(2, 1), isNull);
    });

    test('when importing a bare 2D array then it is one sheet', () {
      final doc = JsonWorkbook.import(
        _bytes([
          [1, 2],
          [3],
        ]),
      );

      expect(doc.sheets.single.cells.get(1, 0)?.value, const IrNumber(3));
    });

    test('when the JSON is not a workbook then the import fails', () {
      expect(
        () => JsonWorkbook.import(_bytes({'x': 1})),
        throwsA(isA<JsonWorkbookException>()),
      );
      expect(
        () => SheetsFileImporter.parse(
          Uint8List.fromList(utf8.encode('{nope')),
          fileName: 'x.json',
        ),
        throwsA(isA<ImportFileException>()),
      );
    });

    test('when a .json file is parsed then the importer detects it', () {
      final parsed = SheetsFileImporter.parse(
        _bytes({
          'sheets': [
            {
              'name': 'One',
              'values': [
                ['a'],
              ],
            },
            {
              'name': 'Two',
              'values': [
                ['b'],
              ],
            },
          ],
        }),
        fileName: 'wb.json',
      );

      expect(parsed.format, SheetsFileFormat.json);
      expect([for (final s in parsed.document.sheets) s.name], ['One', 'Two']);
      expect(
        SheetsFileImporter.listSheets(
          _bytes({
            'sheets': [
              {'name': 'One', 'values': <Object?>[]},
            ],
          }),
          SheetsFileFormat.json,
        ).single.name,
        'One',
      );
    });
  });
}
