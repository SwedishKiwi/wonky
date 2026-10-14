import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';
import 'package:xml/xml.dart';

import 'support/ods_fixtures.dart';

final _modified = DateTime.utc(2026, 10, 14, 9, 30);

String _part(Uint8List bytes, String name) {
  final a = ZipDecoder().decodeBytes(bytes);
  return utf8.decode(a.findFile(name)!.content);
}

void main() {
  group('Given an exported ODS package', () {
    late Uint8List bytes;
    setUp(
      () => bytes = OdsExporter.export(
        OdsDocs.full(),
        OdsExportOptions(modified: _modified),
      ),
    );

    test('when reading the zip then mimetype is the first, stored entry', () {
      // Local file header: name at offset 30, no extra field, then the data.
      expect(utf8.decode(bytes.sublist(30, 38)), 'mimetype');
      expect(bytes[8] | (bytes[9] << 8), 0, reason: 'compression method');
      expect(bytes[28] | (bytes[29] << 8), 0, reason: 'extra field length');
      expect(
        utf8.decode(bytes.sublist(38, 38 + 46)),
        'application/vnd.oasis.opendocument.spreadsheet',
      );
    });

    test('when reading the manifest then every part is listed', () {
      final manifest = XmlDocument.parse(_part(bytes, 'META-INF/manifest.xml'));
      final paths = [
        for (final e in manifest.findAllElements('manifest:file-entry'))
          e.getAttribute('manifest:full-path'),
      ];
      expect(paths, [
        '/',
        'content.xml',
        'styles.xml',
        'meta.xml',
        'settings.xml',
      ]);
    });

    test('when parsing every XML part then it is well-formed ODF 1.2', () {
      for (final name in [
        'content.xml',
        'styles.xml',
        'meta.xml',
        'settings.xml',
      ]) {
        final root = XmlDocument.parse(_part(bytes, name)).rootElement;
        expect(root.getAttribute('office:version'), '1.2', reason: name);
      }
    });

    test('when reading content.xml then formulas use OpenFormula syntax', () {
      final content = _part(bytes, 'content.xml');
      expect(content, contains('table:formula="of:=SUM([.B2:.B3])"'));
      expect(content, contains("of:=[\$'Q3 plan'.A1]&amp;&quot;x&quot;"));
      expect(
        content,
        contains(
          'table:number-matrix-columns-spanned="1" '
          'table:number-matrix-rows-spanned="2" table:formula="of:=[.B2:.B3]*10"',
        ),
      );
      expect(
        content,
        contains(
          '<table:named-range table:name="Total" '
          'table:base-cell-address="\$Data.\$A\$1" '
          'table:cell-range-address="\$Data.\$B\$2:.\$B\$3"/>',
        ),
      );
    });

    test('when reading meta.xml then the injected time is used', () {
      expect(
        _part(bytes, 'meta.xml'),
        contains(
          '<meta:creation-date>2026-10-14T09:30:00Z</meta:creation-date>',
        ),
      );
    });

    test(
      'when exporting twice with the same time then the bytes are identical',
      () {
        final again = OdsExporter.export(
          OdsDocs.full(),
          OdsExportOptions(modified: _modified),
        );
        expect(again, equals(bytes));
      },
    );
  });

  group('Given a sparse sheet with far-apart cells', () {
    late String content;
    setUp(() {
      final d = WorkbookDocument();
      final s = IrSheet('Sparse');
      s.cells
        ..set(0, 0, const IrCell(value: IrNumber(1)))
        ..set(999, 25, const IrCell(value: IrNumber(2)));
      d.sheets.add(s);
      content = _part(
        OdsExporter.export(d, OdsExportOptions(modified: _modified)),
        'content.xml',
      );
    });

    test(
      'when exporting then empty rows and cells are repeated, not listed',
      () {
        expect(content, contains('table:number-rows-repeated="998"'));
        expect(content, contains('table:number-columns-repeated="25"'));
        expect(content.length, lessThan(6000));
      },
    );

    test('when importing it again then both cells are at their positions', () {
      final back = OdsImporter.import(
        OdsExporter.export(
          (WorkbookDocument()
            ..sheets.add(
              IrSheet('Sparse')
                ..cells.set(0, 0, const IrCell(value: IrNumber(1)))
                ..cells.set(999, 25, const IrCell(value: IrNumber(2))),
            )),
          OdsExportOptions(modified: _modified),
        ),
      );
      final s = back.sheets.single;
      expect(s.cells.length, 2);
      expect(s.cells.get(999, 25)!.value, const IrNumber(2));
    });
  });

  group('Given features ODS export does not carry', () {
    test('when exporting then the report lists them', () {
      final d = WorkbookDocument();
      final s = IrSheet('S')
        ..autoFilter = IrFilter(range: IrRange(0, 0, 3, 1))
        ..print = {'paper': 'a4'};
      s.cells.set(0, 0, const IrCell(value: IrNumber(1)));
      s.rows[1] = const IrDim(outlineLevel: 1);
      s.validations.add(
        IrDataValidation(
          ranges: [IrRange(0, 0, 0, 0)],
          criteria: {'type': 'checkbox'},
        ),
      );
      d.sheets.add(s);
      final report = ImportWarnings();
      OdsExporter.export(d, OdsExportOptions(modified: _modified), report);
      expect(
        [for (final w in report) w.code],
        containsAll([
          'dataValidation',
          'filter',
          'outlineGroup',
          'printSettings',
        ]),
      );
    });

    test(
      'when sheet names hold characters ODF forbids then they are renamed',
      () {
        final d = WorkbookDocument()
          ..sheets.addAll([
            IrSheet('A/B')..cells.set(0, 0, const IrCell(value: IrNumber(1))),
            IrSheet('a_b'),
          ]);
        final report = ImportWarnings();
        final back = OdsImporter.import(
          OdsExporter.export(d, OdsExportOptions(modified: _modified), report),
        );
        expect([for (final s in back.sheets) s.name], ['A_B', 'a_b (2)']);
        expect(report.withCode('sheetRenamed'), hasLength(2));
      },
    );
  });

  group('Given an export without Wonky extensions', () {
    late WorkbookDocument back;
    late IrSheet s;
    setUpAll(() {
      final bytes = OdsExporter.export(
        OdsDocs.full(),
        OdsExportOptions(modified: _modified, wonkyExtensions: false),
      );
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains('wonky:')),
      );
      back = OdsImporter.import(bytes);
      s = back.sheets.first;
    });
    IrFormat fmtAt(int r, int c) => back.formatOf(s.cells.get(r, c)!);

    test(
      'when importing then values, formulas and merges come from ODF alone',
      () {
        expect(s.cells.get(3, 1)!.formulaA1, 'SUM(B2:B3)');
        expect(s.cells.get(3, 1)!.value, const IrNumber(7));
        expect(s.cells.get(4, 1)!.value, const IrError(CellErrorKind.div0));
        expect(s.cells.get(5, 0)!.arrayRef, const GridRect(5, 0, 6, 0));
        expect(s.merges, [const GridRect(10, 0, 11, 2)]);
        expect(s.cells.get(7, 1)!.link, "#'Q3 plan'!A1");
        expect(s.cells.get(8, 0)!.note, 'A note\nwith two lines');
      },
    );

    test('when importing then standard properties restore the formats', () {
      final styled = fmtAt(0, 2);
      expect(styled[FormatAttr.italic], isTrue);
      expect(styled[FormatAttr.underline], isTrue);
      expect(styled[FormatAttr.strikethrough], isTrue);
      expect(styled[FormatAttr.fontFamily], 'Georgia');
      expect(styled[FormatAttr.fontSize], 14);
      expect(styled[FormatAttr.textColor], '#FF0000');
      expect(styled[FormatAttr.hAlign], HorizontalAlign.center);
      expect(styled[FormatAttr.vAlign], VerticalAlign.middle);
      expect(styled[FormatAttr.wrap], WrapStrategy.wrap);
      expect(styled[FormatAttr.borderTop], 'thin|#000000');
      expect(styled[FormatAttr.borderBottom], 'double|#000000');
      expect(styled[FormatAttr.borderLeft], 'dashed|#00FF00');
      expect(styled[FormatAttr.borderRight], 'thick|#123456');
      expect(fmtAt(3, 0)[FormatAttr.rotation], -30);
      expect(fmtAt(6, 1)[FormatAttr.rotation], 255);
      expect(fmtAt(6, 2)[FormatAttr.fillColor], '#4285F4');
    });

    test('when importing then sizes, frozen panes and sheet flags survive', () {
      expect(s.rows[2]!.size, 40);
      expect(s.rows[3]!.hidden, isTrue);
      expect(s.columns[1]!.size, 150);
      expect(s.columns[3]!.hidden, isTrue);
      expect(back.formats[s.columns[3]!.format][FormatAttr.italic], isTrue);
      expect((s.frozenRows, s.frozenColumns), (1, 2));
      expect(s.defaultColumnWidth, 100);
      final plan = back.sheets[1];
      expect((plan.hidden, plan.rtl, plan.showGridlines), (true, true, false));
    });
  });

  group('Given number formats exported without Wonky extensions', () {
    const patterns = [
      '#,##0.00',
      '0.0%',
      'yyyy-mm-dd',
      'h:mm:ss',
      '[h]:mm',
      r'"$"#,##0.00',
      '0.00E+00',
      '@',
    ];
    for (final p in patterns) {
      test('when round-tripping "$p" then the pattern is unchanged', () {
        final d = WorkbookDocument();
        final f = d.formats.intern(
          IrFormat(CellFormat({FormatAttr.numberFormat: p})),
        );
        d.sheets.add(
          IrSheet('S')
            ..cells.set(0, 0, IrCell(value: const IrNumber(1.5), format: f)),
        );
        final back = OdsImporter.import(
          OdsExporter.export(
            d,
            OdsExportOptions(modified: _modified, wonkyExtensions: false),
          ),
        );
        final c = back.sheets.single.cells.get(0, 0)!;
        expect(back.formatOf(c)[FormatAttr.numberFormat], p);
        expect(c.value, const IrNumber(1.5));
      });
    }
  });
}
