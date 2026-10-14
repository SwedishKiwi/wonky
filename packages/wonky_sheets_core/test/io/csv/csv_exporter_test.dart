import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart' show FormulaEngine;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/io_support.dart';

void main() {
  group('Given a sheet with formatted values and formulas', () {
    late WorkbookModel model;
    late FormulaEngine engine;
    late String sheetId;
    setUp(() {
      final doc = irDoc([
        irSheet('S', [
          ['Name', 'Amount', 'When', 'Ok'],
          ['a, "quoted"', 1234.5, 46115, true],
          ['line\nbreak', '=B2*2', '=SEQUENCE(2)', '=1/0'],
        ]),
      ]);
      final s = doc.sheets.single;
      s.cells
        ..set(
          1,
          1,
          IrCell(
            value: const IrNumber(1234.5),
            format: doc.formats.internAttrs(
              CellFormat({FormatAttr.numberFormat: '#,##0.00'}),
            ),
          ),
        )
        ..set(
          1,
          2,
          IrCell(
            value: const IrNumber(46115),
            format: doc.formats.internAttrs(
              CellFormat({FormatAttr.numberFormat: 'yyyy-mm-dd'}),
            ),
          ),
        );
      model = importNew(doc).model;
      engine = ModelEngineBinding.create(model).engine;
      sheetId = model.sheets.single.id;
    });

    test('when exporting as displayed then values use their formats', () {
      expect(
        CsvExporter.exportText(model, engine, sheetId: sheetId),
        'Name,Amount,When,Ok\r\n'
        '"a, ""quoted""","1,234.50",2026-04-03,TRUE\r\n'
        '"line\nbreak",2469,1,#DIV/0!\r\n'
        ',,2,\r\n',
      );
    });

    test(
      'when exporting raw values then numbers and dates are unformatted',
      () {
        final csv = CsvExporter.exportText(
          model,
          engine,
          sheetId: sheetId,
          options: const CsvExportOptions(values: CsvValueMode.raw),
        );
        expect(csv.split('\r\n')[1], '"a, ""quoted""",1234.5,2026-04-03,TRUE');
      },
    );

    test('when exporting TSV then tabs and newlines become spaces', () {
      final tsv = CsvExporter.exportText(
        model,
        engine,
        sheetId: sheetId,
        options: const CsvExportOptions.tsv(),
      );
      expect(tsv.split('\r\n')[2], 'line break\t2469\t1\t#DIV/0!');
    });

    test('when exporting a range then only it is written', () {
      expect(
        CsvExporter.exportText(
          model,
          engine,
          sheetId: sheetId,
          range: const GridRect(0, 0, 0, 1),
        ),
        'Name,Amount\r\n',
      );
    });

    test('when a BOM is requested then the bytes start with it', () {
      final bytes = CsvExporter.export(
        model,
        engine,
        sheetId: sheetId,
        options: const CsvExportOptions(includeBom: true),
      );
      expect(bytes.sublist(0, 3), [0xef, 0xbb, 0xbf]);
      expect(utf8.decode(bytes.sublist(3)), startsWith('Name,'));
    });
  });

  group('Given text that looks like a formula', () {
    test('when protecting against injection then it is prefixed', () {
      final model = importNew(
        irDoc([
          irSheet('S', [
            [const IrCell(value: IrText('=cmd')), '+x', 'ok'],
          ]),
        ]),
      ).model;
      final engine = ModelEngineBinding.create(model).engine;
      expect(
        CsvExporter.exportText(
          model,
          engine,
          sheetId: model.sheets.single.id,
          options: const CsvExportOptions(protectFormulaInjection: true),
        ),
        "'=cmd,'+x,ok\r\n",
      );
    });
  });

  group('Given rows of fields', () {
    test('when encoding then fields with delimiters, quotes and line breaks '
        'are quoted', () {
      expect(
        CsvExporter.encodeRows([
          ['a', 'b,c', 'd"e', 'f\rg', ''],
        ]),
        'a,"b,c","d""e","f\rg",\r\n',
      );
    });
  });
}
