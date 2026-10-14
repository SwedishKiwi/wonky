import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import 'support/ods_fixtures.dart';

void main() {
  group('Given a LibreOffice-style spreadsheet', () {
    late WorkbookDocument doc;
    late IrSheet s;
    setUpAll(() {
      doc = OdsImporter.import(libreOfficePackage());
      s = doc.sheets.first;
    });
    IrFormat fmtAt(int r, int c) => doc.formatOf(s.cells.get(r, c)!);

    test('when importing then sheets, visibility and tab color are read', () {
      expect([for (final x in doc.sheets) x.name], ['Sheet1', 'Other']);
      expect(doc.sheets[1].hidden, isTrue);
      expect(s.tabColor, '#FF0000');
      expect(doc.defaultFontFamily, 'Liberation Sans');
      expect(doc.defaultFontSize, 10);
    });

    test('when importing then repeated rows and columns are expanded', () {
      for (var r = 1; r <= 3; r++) {
        expect(s.cells.get(r, 0)!.value, const IrNumber(1));
        expect(s.cells.get(r, 1)!.value, const IrText('rep'));
        expect(s.cells.get(r, 2)!.value, const IrText('rep'));
      }
    });

    test(
      'when importing then huge trailing repeats are capped at the used range',
      () {
        expect(s.usedRows, 8);
        expect(s.usedColumns, 5);
        expect(s.cells.length, lessThan(40));
      },
    );

    test('when importing then spanned cells become merges', () {
      expect(s.merges, [const GridRect(0, 1, 0, 2)]);
      expect(s.cells.get(0, 1)!.value, const IrText('Merged'));
    });

    test('when importing then typed values and number formats are mapped', () {
      expect(s.cells.get(4, 0)!.value, const IrNumber(46309));
      expect(fmtAt(4, 0)[FormatAttr.numberFormat], 'dd.mm.yyyy');
      expect(s.cells.get(4, 1)!.value, const IrNumber(0.125));
      expect(fmtAt(4, 1)[FormatAttr.numberFormat], '0.00%');
      expect(s.cells.get(4, 2)!.value, const IrNumber(-1234.5));
      expect(
        fmtAt(4, 2)[FormatAttr.numberFormat],
        r'"$"#,##0.00;[Red]-"$"#,##0.00',
      );
      expect(s.cells.get(4, 3)!.value, const IrBool(true));
      expect(fmtAt(4, 3)[FormatAttr.numberFormat], isNull);
      expect(
        (s.cells.get(4, 4)!.value! as IrNumber).number,
        closeTo((13 * 60 + 45) / 1440, 1e-12),
      );
      expect(fmtAt(4, 4)[FormatAttr.numberFormat], 'preset:time');
    });

    test(
      'when importing then OpenFormula formulas are translated with cached values',
      () {
        expect(s.cells.get(5, 0)!.formulaA1, 'SUM(A2:A4)');
        expect(s.cells.get(5, 0)!.value, const IrNumber(3));
        expect(s.cells.get(5, 1)!.formulaA1, 'Other!A1&"!"');
        expect(s.cells.get(5, 1)!.value, const IrText('hi!'));
        expect(s.cells.get(5, 2)!.formulaA1, '1/0');
        expect(s.cells.get(5, 2)!.value, const IrError(CellErrorKind.div0));
        expect(s.cells.get(5, 3)!.formulaA1, 'IF(A2>0,TRUE,FALSE)');
        expect(s.cells.get(5, 3)!.value, const IrBool(true));
      },
    );

    test('when importing then matrix formulas become array formulas', () {
      final c = s.cells.get(6, 2)!;
      expect(c.formulaA1, 'ARRAYFORMULA(A2:A3*10)');
      expect(c.formulaKind, IrFormulaKind.array);
      expect(c.arrayRef, const GridRect(6, 2, 7, 2));
      expect(s.cells.get(7, 2)!.value, const IrNumber(20));
    });

    test('when importing then cell styles map to format attributes', () {
      final header = fmtAt(0, 0);
      expect(header[FormatAttr.bold], isTrue);
      expect(header[FormatAttr.fillColor], '#FFFF00');
      expect(header[FormatAttr.hAlign], HorizontalAlign.center);
      expect(header[FormatAttr.fontFamily], isNull);
      final styled = fmtAt(6, 0);
      expect(styled[FormatAttr.borderBottom], 'thin|#000000');
      expect(styled[FormatAttr.borderTop], 'thick|#0000FF');
      expect(styled[FormatAttr.borderLeft], isNull);
      expect(styled[FormatAttr.wrap], WrapStrategy.wrap);
      expect(styled[FormatAttr.vAlign], VerticalAlign.top);
      expect(styled[FormatAttr.rotation], 90);
      expect(styled[FormatAttr.fontFamily], 'DejaVu Serif');
      expect(styled[FormatAttr.fontSize], 12);
      expect(styled[FormatAttr.italic], isTrue);
      expect(styled[FormatAttr.underline], isTrue);
      expect(styled[FormatAttr.textColor], '#00FF00');
      final heading = fmtAt(0, 3);
      expect(heading[FormatAttr.fontSize], 24);
      expect(heading[FormatAttr.bold], isTrue);
    });

    test(
      'when importing then paragraphs, spaces, spans, notes and links are read',
      () {
        final c = s.cells.get(6, 0)!;
        expect(
          c.value,
          IrRich(
            RichText('Two  spaces bold\nsecond line', [
              const RichRun(12, 16, {'bold': true}),
            ]),
          ),
        );
        expect(c.note, 'Check\nthis');
        expect(s.cells.get(6, 1)!.link, 'https://example.com/');
        expect(s.cells.get(6, 1)!.value, const IrText('Example'));
        expect(s.cells.get(6, 3)!.link, '#Other!A1');
      },
    );

    test('when importing then sizes, hidden rows and columns are read', () {
      expect(s.defaultColumnWidth, closeTo(85.34, 0.01));
      expect(s.defaultRowHeight, closeTo(17.09, 0.01));
      expect(s.columns[0]!.size, 144);
      expect(s.columns[4]!.hidden, isTrue);
      expect(s.rows[4]!.size, closeTo(38.4, 0.01));
      expect(s.rows[5]!.hidden, isTrue);
      expect(s.rows[1], isNull);
    });

    test(
      'when importing then frozen panes and gridlines come from settings.xml',
      () {
        expect(s.frozenRows, 1);
        expect(s.frozenColumns, 0);
        expect(s.showGridlines, isFalse);
        expect(doc.sheets[1].showGridlines, isTrue);
      },
    );

    test('when importing then named ranges and expressions are read', () {
      final names = {for (final n in doc.namedRanges) n.name: n};
      expect(names['Nums']!.sheet, 'Sheet1');
      expect(names['Nums']!.range, IrRange(1, 0, 3, 0));
      expect(names['Rate']!.formulaA1, '0.19');
    });

    test(
      'when listing sheets then names, visibility and cell counts are returned',
      () {
        final info = OdsImporter.listSheets(libreOfficePackage());
        expect([for (final i in info) i.name], ['Sheet1', 'Other']);
        expect([for (final i in info) i.hidden], [false, true]);
        expect(info.first.estimatedCells, greaterThan(15));
      },
    );
  });

  group('Given files that are not ODS spreadsheets', () {
    test(
      'when importing random bytes then an XlsxFormatException is thrown',
      () {
        expect(
          () => OdsImporter.import(Uint8List.fromList([1, 2, 3, 4, 5])),
          throwsA(isA<XlsxFormatException>()),
        );
      },
    );

    test('when importing an ODF text document then it is rejected', () {
      final bytes = odsPackage(
        content: odsContent(spreadsheet: ''),
        mimeType: 'application/vnd.oasis.opendocument.text',
      );
      expect(
        () => OdsImporter.import(bytes),
        throwsA(
          isA<XlsxFormatException>().having(
            (e) => e.message,
            'message',
            contains('not an OpenDocument spreadsheet'),
          ),
        ),
      );
    });

    test(
      'when content.xml is malformed then an XlsxFormatException is thrown',
      () {
        final bytes = odsPackage(
          content: '<office:document-content><unclosed>',
        );
        expect(
          () => OdsImporter.import(bytes),
          throwsA(isA<XlsxFormatException>()),
        );
      },
    );
  });

  group('Given formulas with functions Wonky lacks', () {
    final bytes = odsPackage(
      content: odsContent(
        spreadsheet:
            '<table:table table:name="S"><table:table-row><table:table-cell '
            'table:formula="of:=WEBSERVICE(&quot;x&quot;)" office:value-type="float" '
            'office:value="5"><text:p>5</text:p></table:table-cell></table:table-row>'
            '</table:table>',
      ),
    );

    test(
      'when importing with the value option then the cached value and a note are kept',
      () {
        final d = OdsImporter.import(bytes);
        final c = d.sheets.single.cells.get(0, 0)!;
        expect(c.formulaA1, isNull);
        expect(c.value, const IrNumber(5));
        expect(c.note, contains('WEBSERVICE'));
        expect(d.warnings.withCode('unsupportedFunction'), hasLength(1));
      },
    );

    test(
      'when importing with the text option then the formula text is kept',
      () {
        final d = OdsImporter.import(
          bytes,
          const OdsImportOptions(
            unsupportedFormulas: UnsupportedFormulaMode.text,
          ),
        );
        expect(
          d.sheets.single.cells.get(0, 0)!.value,
          const IrText('=WEBSERVICE("x")'),
        );
      },
    );
  });
}
