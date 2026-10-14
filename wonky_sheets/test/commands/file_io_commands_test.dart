import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets/features/export/sheets_downloads.dart';
import 'package:wonky_sheets/features/import/import_pipeline.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/sheets_harness.dart';

Map<String, Object?> _csv(String text, String location, {String? cell}) => {
  'fileName': 'orders.csv',
  'text': text,
  'options': {'location': location, 'cell': ?cell},
};

void main() {
  late SheetsHarness s;

  setUp(() => s = SheetsHarness.open());
  tearDown(() => s.dispose());

  group('Given a CSV file imported into the open spreadsheet', () {
    test('when inserting new sheets then a sheet named after the file has '
        'the converted values and one undo removes it', () async {
      final r = await s.run(
        'sheets.file.import',
        _csv('Order;Amount\n1001;12.5\n1002;=B2*2\n', 'insertSheets'),
      );

      expect(r.isOk, isTrue, reason: r.message);
      final names = [for (final sh in s.model.sheets) sh.name];
      expect(names, ['Sheet1', 'orders']);
      expect(s.editor.activeSheet!.name, 'orders');
      expect(s.text('A1'), 'Order');
      expect(s.text('B2'), '12.5');
      expect(s.content('B3'), startsWith('='));
      expect(lastImportReport.value?.cellCount, 6);

      await s.undo();
      expect([for (final sh in s.model.sheets) sh.name], ['Sheet1']);
    });

    test('when replacing data at a cell then values start there and undo '
        'restores the old values', () async {
      await s.type('C3', 'old');

      await s.run(
        'sheets.file.import',
        _csv('a,b\nx,y\n', 'replaceAtCell', cell: 'C3'),
      );

      expect(s.text('C3'), 'a');
      expect(s.text('D4'), 'y');
      await s.undo();
      expect(s.text('C3'), 'old');
      expect(s.text('D4'), '');
    });

    test(
      'when appending then rows go after the last row with content',
      () async {
        await s.type('A1', 'head');
        await s.type('A2', 'one');

        await s.run('sheets.file.import', _csv('two\nthree\n', 'append'));

        expect(s.text('A3'), 'two');
        expect(s.text('A4'), 'three');
      },
    );

    test(
      'when replacing the current sheet then old cells are cleared',
      () async {
        await s.type('E9', 'gone');

        await s.run('sheets.file.import', _csv('n\n1\n', 'replaceSheet'));

        expect(s.text('A2'), '1');
        expect(s.text('E9'), '');
      },
    );

    test('when conversion is off then numbers stay text', () async {
      await s.run('sheets.file.import', {
        'fileName': 'raw.csv',
        'text': '007,=1+1\n',
        'options': {
          'location': 'replaceAtCell',
          'cell': 'A1',
          'convert': false,
        },
      });

      expect(s.text('A1'), '007');
      expect(s.text('B1'), '=1+1');
    });
  });

  group('Given an XLSX file', () {
    test('when importing it twice then the sheet names get "(2)"', () async {
      final doc = CsvImporter.importText(
        'x,y\n1,2\n',
        const CsvImportOptions(sheetName: 'Data'),
      );
      final bytes = XlsxExporter.export(doc);
      final args = {
        'fileName': 'data.xlsx',
        'contentBase64': base64Encode(bytes),
        'options': {'location': 'insertSheets'},
      };

      await s.run('sheets.file.import', args);
      await s.run('sheets.file.import', args);

      expect(
        [for (final sh in s.model.sheets) sh.name],
        ['Sheet1', 'Data', 'Data (2)'],
      );
    });

    test('when the file is a legacy .xls then the import fails', () async {
      final r = await s.run('sheets.file.import', {
        'fileName': 'old.xls',
        'contentBase64': base64Encode([0xd0, 0xcf, 0x11, 0xe0]),
        'options': {'location': 'insertSheets'},
      });

      expect(r.status, CommandStatus.failed);
      expect(s.model.sheets, hasLength(1));
    });
  });

  group('Given a viewer', () {
    late SheetsHarness v;
    setUp(() => v = SheetsHarness.open(role: Role.viewer));
    tearDown(() => v.dispose());

    test('when importing into the spreadsheet then it is refused', () async {
      final r = await v.run('sheets.file.import', _csv('a\n', 'insertSheets'));

      expect(r.status, isNot(CommandStatus.ok));
      expect(v.model.sheets, hasLength(1));
    });
  });

  group('Given values to download', () {
    setUp(() async {
      await s.type('A1', 'Item');
      await s.type('B1', 'Price');
      await s.type('A2', 'Tea');
      await s.type('B2', '2.5');
      await s.type('B3', '=B2*2');
    });

    test('when downloading CSV then the active sheet comes out as displayed '
        'with a file name of title and sheet', () async {
      final a = await buildDownload(s.editor, SheetsExportFormat.csv);

      expect(a.fileName, 'Budget - Sheet1.csv');
      expect(utf8.decode(a.bytes), 'Item,Price\r\nTea,2.5\r\n,5\r\n');
    });

    test('when downloading XLSX then re-importing it gives the same values '
        'and formula', () async {
      final a = await buildDownload(s.editor, SheetsExportFormat.xlsx);

      expect(a.fileName, 'Budget.xlsx');
      final doc = XlsxImporter.import(a.bytes);
      final cell = doc.sheets.single.cells.get(2, 1)!;
      expect(cell.formulaA1, 'B2*2');
      expect((cell.value! as IrNumber).number, 5);
    });

    test('when downloading ODS and HTML then files are produced', () async {
      final ods = await buildDownload(s.editor, SheetsExportFormat.ods);
      final html = await buildDownload(s.editor, SheetsExportFormat.html);

      expect(ods.fileName, 'Budget.ods');
      expect(html.fileName, 'Budget.zip');
      expect(html.bytes.take(2), [0x50, 0x4b]);
    });
  });
}
