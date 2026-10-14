import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

final _today = DateTime.utc(2026, 5, 1);

WorkbookDocument _text(
  String text, {
  String locale = 'en_US',
  bool convert = true,
}) => CsvImporter.importText(
  text,
  CsvImportOptions(locale: locale, today: _today, convert: convert),
);

IrCell? _cell(WorkbookDocument d, int r, int c) =>
    d.sheets.single.cells.get(r, c);

String? _format(WorkbookDocument d, int r, int c) {
  final cell = _cell(d, r, c);
  final own = cell == null
      ? null
      : d.formatOf(cell).attrs[FormatAttr.numberFormat];
  if (own != null) return own as String;
  final col = d.sheets.single.columns[c]?.format ?? 0;
  return d.formats[col].attrs[FormatAttr.numberFormat] as String?;
}

void main() {
  group('Given a de_DE file with semicolons', () {
    late CsvImportResult r;
    setUp(() {
      r = CsvImporter.import(
        latin1.encode(
          'Name;Betrag;Datum;Aktiv\n'
          'Müller;1.234,56;03.04.2026;WAHR\n'
          'Öz;-5;04.04.2026;FALSCH\n',
        ),
        CsvImportOptions(locale: 'de_DE', today: _today),
      );
    });

    test('when importing then the encoding and delimiter are detected', () {
      expect(r.encoding, TextEncoding.windows1252);
      expect(r.encodingReason, 'fallback');
      expect(r.delimiter, ';');
      expect(_cell(r.document, 1, 0)!.value, const IrText('Müller'));
    });

    test('when importing then numbers use the locale separators', () {
      expect(_cell(r.document, 1, 1)!.value, const IrNumber(1234.56));
      expect(_cell(r.document, 2, 1)!.value, const IrNumber(-5));
    });

    test('when importing then dates use the locale order', () {
      expect(_cell(r.document, 1, 2)!.value, const IrNumber(46115));
      expect(_format(r.document, 1, 2), 'preset:date');
    });

    test('when importing then boolean words of the locale are booleans', () {
      expect(_cell(r.document, 1, 3)!.value, const IrBool(true));
      expect(_cell(r.document, 2, 3)!.value, const IrBool(false));
    });

    test('when a header is the only exception then the column default is '
        'not set below 95 %', () {
      expect(r.document.sheets.single.columns[2], isNull);
      expect(_format(r.document, 1, 2), 'preset:date');
    });
  });

  group('Given a column of dates only', () {
    test('when importing then the date format is the column default', () {
      final d = _text('03.04.2026\n04.04.2026\n05.04.2026\n', locale: 'de_DE');
      final s = d.sheets.single;
      expect(
        d.formats[s.columns[0]!.format].attrs[FormatAttr.numberFormat],
        'preset:date',
      );
      expect(_cell(d, 1, 0)!.format, 0);
    });
  });

  group('Given date orders of different locales', () {
    const vectors = [('en_US', 46085.0), ('en_GB', 46115.0)];
    for (final (locale, serial) in vectors) {
      test(
        'when importing 03/04/2026 in $locale then the serial is $serial',
        () {
          expect(
            _cell(_text('03/04/2026', locale: locale), 0, 0)!.value,
            IrNumber(serial),
          );
        },
      );
    }

    test('when importing ISO dates then they are recognized in any locale', () {
      final d = _text('2026-04-03,2026-04-03T10:30', locale: 'de_DE');
      expect(_cell(d, 0, 0)!.value, const IrNumber(46115));
      expect(_cell(d, 0, 1)!.value, const IrNumber(46115.4375));
    });
  });

  group('Given values to convert', () {
    test('when a field is a percentage then it is a number with a format', () {
      final d = _text('12%,x');
      expect(_cell(d, 0, 0)!.value, const IrNumber(0.12));
      expect(_format(d, 0, 0), '0%');
    });

    test('when a number has surrounding spaces then it is trimmed', () {
      expect(_cell(_text(' 42 ,x'), 0, 0)!.value, const IrNumber(42));
    });

    test('when text has surrounding spaces then they are kept', () {
      expect(_cell(_text(' a ,x'), 0, 0)!.value, const IrText(' a '));
    });

    test('when a field starts with = then it is a canonical formula', () {
      final d = _text('"=SUM(1,5;2)";x', locale: 'de_DE');
      expect(_cell(d, 0, 0)!.formulaA1, 'SUM(1.5,2)');
    });

    test('when a formula uses external data then it is blocked', () {
      final d = _text('"=IMPORTDATA(""https://x"")",=HYPERLINK("a")');
      final c = _cell(d, 0, 0)!;
      expect(c.value, const IrError(CellErrorKind.blocked));
      expect(c.blockedFormulaA1, 'IMPORTDATA("https://x")');
      expect(_cell(d, 0, 1)!.formulaA1, 'HYPERLINK("a")');
      expect(d.warnings.withCode('blockedFormula'), hasLength(1));
    });

    test('when conversion is off then every field is text', () {
      final d = _text('1,=A1,TRUE', convert: false);
      expect(
        [for (var c = 0; c < 3; c++) _cell(d, 0, c)!.value],
        [const IrText('1'), const IrText('=A1'), const IrText('TRUE')],
      );
    });

    test('when a field is empty then there is no cell', () {
      final d = _text('a,,c\n');
      expect(_cell(d, 0, 1), isNull);
      expect(d.sheets.single.cells.length, 2);
    });
  });

  group('Given file-level features', () {
    test('when the file starts with a BOM and sep= then both are skipped', () {
      final r = CsvImporter.import([
        0xef,
        0xbb,
        0xbf,
        ...utf8.encode('sep=|\na|b\n'),
      ], CsvImportOptions(today: _today));
      expect(r.delimiter, '|');
      expect(_cell(r.document, 0, 0)!.value, const IrText('a'));
      expect(r.encodingReason, 'bom');
    });

    test('when the file is UTF-16 then it is decoded', () {
      final text = 'a\tb\n1\t2\n';
      final bytes = [
        0xff,
        0xfe,
        for (final c in text.codeUnits) ...[c & 0xff, c >> 8],
      ];
      final r = CsvImporter.import(bytes, CsvImportOptions(today: _today));
      expect((r.encoding, r.delimiter), (TextEncoding.utf16le, '\t'));
      expect(_cell(r.document, 1, 1)!.value, const IrNumber(2));
    });

    test('when a field exceeds the maximum length then it is truncated with '
        'a warning', () {
      final d = CsvImporter.importText(
        'x,${'y' * 60000}\n',
        CsvImportOptions(today: _today),
      );
      expect((_cell(d, 0, 1)!.value! as IrText).text.length, 50000);
      expect(
        d.warnings.withCode('fieldTruncated').single.message,
        contains('line 1'),
      );
    });

    test('when a quote is not closed then the warning names its line', () {
      final d = _text('a\nb,"open\n');
      expect(
        d.warnings.withCode('unterminatedQuote').single.message,
        'Unterminated quote at line 2',
      );
    });

    test('when the file name is given then it names the sheet and title', () {
      final d = CsvImporter.importText(
        'a',
        CsvImportOptions(fileName: 'reports/orders:2026.csv', today: _today),
      );
      expect(d.title, 'orders:2026');
      expect(d.sheets.single.name, 'orders 2026');
    });
  });

  group('Given streamed input', () {
    test(
      'when importing in chunks then the cells match a full import',
      () async {
        final rows = [for (var i = 0; i < 12000; i++) '$i,"text $i",${i / 4}'];
        final bytes = utf8.encode(rows.join('\n'));
        final importer = CsvStreamImporter(
          CsvImportOptions(today: _today, chunkRecords: 5000),
        );
        final chunks = await CsvImporter.stream(
          Stream.fromIterable([
            for (var i = 0; i < bytes.length; i += 7000)
              bytes.sublist(
                i,
                i + 7000 > bytes.length ? bytes.length : i + 7000,
              ),
          ]),
          importer,
        ).toList();
        expect([for (final c in chunks) c.rowCount], [5000, 5000, 2000]);
        expect(chunks.fold(0, (n, c) => n + c.cells.length), 36000);
        final full = CsvImporter.import(bytes, CsvImportOptions(today: _today));
        final last = chunks.last.cells.last;
        expect(
          last.$3.value,
          full.document.sheets.single.cells.get(last.$1, last.$2)!.value,
        );
      },
    );
  });

  group('Given the import dialog preview', () {
    test('when previewing then the first rows are raw fields', () {
      final p = CsvImporter.preview(
        [0xef, 0xbb, 0xbf, ...utf8.encode('sep=;\na;b\n1;2\n3;4\n')],
        const CsvImportOptions(),
        rows: 2,
      );
      expect(p, [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });
  });
}
