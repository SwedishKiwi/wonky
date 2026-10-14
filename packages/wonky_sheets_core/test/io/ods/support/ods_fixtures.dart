import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

/// Namespace declarations of a LibreOffice document part.
const String kOdfNamespaces =
    'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
    'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
    'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
    'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
    'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" '
    'xmlns:xlink="http://www.w3.org/1999/xlink" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/" '
    'xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" '
    'xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" '
    'xmlns:of="urn:oasis:names:tc:opendocument:xmlns:of:1.2" '
    'xmlns:config="urn:oasis:names:tc:opendocument:xmlns:config:1.0" '
    'xmlns:calcext="urn:org:documentfoundation:names:experimental:calc:xmlns:calcext:1.0" '
    'xmlns:tableooo="http://openoffice.org/2009/table"';

/// Builds an ODS package from part texts (LibreOffice-style fixtures).
Uint8List odsPackage({
  required String content,
  String? styles,
  String? settings,
  String mimeType = 'application/vnd.oasis.opendocument.spreadsheet',
}) {
  final a = Archive();
  final mime = utf8.encode(mimeType);
  a.add(ArchiveFile.noCompress('mimetype', mime.length, mime));
  void add(String path, String text) =>
      a.add(ArchiveFile.bytes(path, utf8.encode(text)));
  add('content.xml', content);
  if (styles != null) add('styles.xml', styles);
  if (settings != null) add('settings.xml', settings);
  add(
    'META-INF/manifest.xml',
    '<?xml version="1.0" encoding="UTF-8"?><manifest:manifest '
        'xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" '
        'manifest:version="1.2"><manifest:file-entry manifest:full-path="/" '
        'manifest:media-type="$mimeType"/></manifest:manifest>',
  );
  return ZipEncoder().encodeBytes(a, modified: DateTime.utc(2026, 1, 1));
}

/// A `content.xml` document around [automaticStyles] and [spreadsheet].
String odsContent({String automaticStyles = '', required String spreadsheet}) =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<office:document-content $kOdfNamespaces office:version="1.3">'
    '<office:font-face-decls><style:font-face style:name="Liberation Sans" '
    'svg:font-family="&apos;Liberation Sans&apos;"/><style:font-face '
    'style:name="DejaVu Serif" svg:font-family="&apos;DejaVu Serif&apos;"/>'
    '</office:font-face-decls>'
    '<office:automatic-styles>$automaticStyles</office:automatic-styles>'
    '<office:body><office:spreadsheet>$spreadsheet</office:spreadsheet>'
    '</office:body></office:document-content>';

/// A LibreOffice-like `styles.xml` (default font Liberation Sans 10 pt).
const String kLibreOfficeStyles =
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<office:document-styles $kOdfNamespaces office:version="1.3">'
    '<office:font-face-decls><style:font-face style:name="Liberation Sans" '
    'svg:font-family="&apos;Liberation Sans&apos;"/></office:font-face-decls>'
    '<office:styles><style:default-style style:family="table-cell">'
    '<style:paragraph-properties style:tab-stop-distance="0.5in"/>'
    '<style:text-properties style:font-name="Liberation Sans" '
    'fo:font-size="10pt" fo:language="en" fo:country="US"/>'
    '</style:default-style>'
    '<number:number-style style:name="N0"><number:number '
    'number:min-integer-digits="1"/></number:number-style>'
    '<style:style style:name="Default" style:family="table-cell"/>'
    '<style:style style:name="Heading" style:family="table-cell" '
    'style:parent-style-name="Default"><style:text-properties '
    'fo:font-size="24pt" fo:font-weight="bold"/></style:style>'
    '</office:styles></office:document-styles>';

/// IR documents for ODS round trips.
abstract final class OdsDocs {
  static int fmt(WorkbookDocument d, Map<FormatAttr, Object?> attrs) =>
      d.formats.intern(IrFormat(CellFormat(attrs)));

  static WorkbookDocument _doc() =>
      WorkbookDocument(title: 'Round trip', locale: 'en_US')
        ..defaultFontFamily = 'Arial'
        ..defaultFontSize = 10;

  /// Values of every type, dates and times with formats.
  static WorkbookDocument values() {
    final d = _doc();
    final s = IrSheet('Values');
    final date = fmt(d, {FormatAttr.numberFormat: 'yyyy-mm-dd'});
    final dateTime = fmt(d, {FormatAttr.numberFormat: 'preset:dateTime'});
    final time = fmt(d, {FormatAttr.numberFormat: 'h:mm:ss'});
    final elapsed = fmt(d, {FormatAttr.numberFormat: '[h]:mm'});
    final percent = fmt(d, {FormatAttr.numberFormat: '0.0%'});
    final money = fmt(d, {FormatAttr.numberFormat: r'"$"#,##0.00'});
    s.cells
      ..set(0, 0, const IrCell(value: IrNumber(42)))
      ..set(0, 1, const IrCell(value: IrNumber(-3.25)))
      ..set(0, 2, const IrCell(value: IrNumber(1e-7)))
      ..set(0, 3, const IrCell(value: IrNumber(123456789012.5)))
      ..set(1, 0, const IrCell(value: IrText('Hello')))
      ..set(1, 1, const IrCell(value: IrText('  padded  ')))
      ..set(1, 2, const IrCell(value: IrText('Ünïcødé ✓ 漢字 😀')))
      ..set(1, 3, const IrCell(value: IrText('a<b>&"c" _x0041_')))
      ..set(2, 0, const IrCell(value: IrBool(true)))
      ..set(2, 1, const IrCell(value: IrBool(false)))
      ..set(2, 2, const IrCell(value: IrError(CellErrorKind.na)))
      ..set(3, 0, IrCell(value: const IrNumber(46309), format: date))
      ..set(3, 1, IrCell(value: const IrNumber(46309.75), format: dateTime))
      ..set(
        3,
        2,
        IrCell(value: const IrNumber(0.5729166666666666), format: time),
      )
      ..set(3, 3, IrCell(value: const IrNumber(1.5), format: elapsed))
      ..set(4, 0, IrCell(value: const IrNumber(0.125), format: percent))
      ..set(4, 1, IrCell(value: const IrNumber(1234.5), format: money))
      ..set(5, 0, const IrCell(value: IrText('line1\nline2\ttab')))
      ..set(5, 1, const IrCell(value: IrText('trailing ')));
    d.sheets.add(s);
    return d;
  }

  /// Formats, structure, formulas, names, notes, links and rich text.
  static WorkbookDocument full() {
    final d = _doc();
    final s = IrSheet('Data')
      ..frozenRows = 1
      ..frozenColumns = 2
      ..tabColor = '#FF6D01'
      ..defaultRowHeight = 21
      ..defaultColumnWidth = 100;
    final bold = fmt(d, {
      FormatAttr.bold: true,
      FormatAttr.fillColor: '#FCE8B2',
    });
    final styled = fmt(d, {
      FormatAttr.italic: true,
      FormatAttr.underline: true,
      FormatAttr.strikethrough: true,
      FormatAttr.fontFamily: 'Georgia',
      FormatAttr.fontSize: 14.0,
      FormatAttr.textColor: '#FF0000',
      FormatAttr.hAlign: HorizontalAlign.center,
      FormatAttr.vAlign: VerticalAlign.middle,
      FormatAttr.wrap: WrapStrategy.wrap,
      FormatAttr.borderTop: 'thin|#000000',
      FormatAttr.borderBottom: 'double|#000000',
      FormatAttr.borderLeft: 'dashed|#00FF00',
      FormatAttr.borderRight: 'thick|#123456',
    });
    final rotated = fmt(d, {FormatAttr.rotation: -30});
    final stacked = fmt(d, {FormatAttr.rotation: 255});
    final theme = fmt(d, {
      FormatAttr.fillColor: 'theme:accent1',
      FormatAttr.wrap: WrapStrategy.clip,
      FormatAttr.borderTop: 'medium|auto',
    });
    final colFormat = fmt(d, {FormatAttr.italic: true});
    s.cells
      ..set(0, 0, IrCell(value: const IrText('Item'), format: bold))
      ..set(0, 1, IrCell(value: const IrText('Qty'), format: bold))
      ..set(0, 2, IrCell(value: const IrText('Styled'), format: styled))
      ..set(1, 0, const IrCell(value: IrText('Apples')))
      ..set(1, 1, const IrCell(value: IrNumber(3)))
      ..set(2, 0, const IrCell(value: IrText('Pears')))
      ..set(2, 1, const IrCell(value: IrNumber(4)))
      ..set(3, 0, IrCell(value: const IrText('Total'), format: rotated))
      ..set(3, 1, const IrCell(formulaA1: 'SUM(B2:B3)', value: IrNumber(7)))
      ..set(
        3,
        2,
        const IrCell(formulaA1: "'Q3 plan'!A1&\"x\"", value: IrText('hix')),
      )
      ..set(
        4,
        0,
        const IrCell(formulaA1: 'IF(B2>2,TRUE,FALSE)', value: IrBool(true)),
      )
      ..set(
        4,
        1,
        const IrCell(formulaA1: '1/0', value: IrError(CellErrorKind.div0)),
      )
      ..set(
        5,
        0,
        const IrCell(
          formulaA1: 'ARRAYFORMULA(B2:B3*10)',
          formulaKind: IrFormulaKind.array,
          arrayRef: GridRect(5, 0, 6, 0),
          value: IrNumber(30),
        ),
      )
      ..set(
        5,
        1,
        const IrCell(formulaA1: 'SUM(Total)*Rate', value: IrNumber(1.33)),
      )
      ..set(6, 1, IrCell(value: const IrText('vertical'), format: stacked))
      ..set(6, 2, IrCell(value: const IrText('theme'), format: theme))
      ..set(
        7,
        0,
        const IrCell(
          value: IrText('Wonky'),
          link: 'https://example.com/a?b=1&c=2',
        ),
      )
      ..set(7, 1, const IrCell(value: IrText('Go'), link: "#'Q3 plan'!A1"))
      ..set(
        8,
        0,
        const IrCell(value: IrNumber(1), note: 'A note\nwith two lines'),
      )
      ..set(
        9,
        0,
        IrCell(
          value: IrRich(
            RichText('Total revenue\nnext', [
              const RichRun(0, 5, {'bold': true}),
              const RichRun(6, 18, {'textColor': '#D93025', 'italic': true}),
            ]),
          ),
        ),
      )
      ..set(10, 0, const IrCell(value: IrText('Merged')));
    s.merges.add(const GridRect(10, 0, 11, 2));
    s.rows[2] = const IrDim(size: 40);
    s.rows[3] = const IrDim(hidden: true);
    s.columns[1] = const IrDim(size: 150);
    s.columns[3] = IrDim(hidden: true, format: colFormat);
    final plan = IrSheet('Q3 plan')
      ..hidden = true
      ..showGridlines = false
      ..rtl = true;
    plan.cells.set(0, 0, const IrCell(value: IrText('hi')));
    d.sheets.addAll([s, plan]);
    d.namedRanges
      ..add(
        IrNamedRange(name: 'Total', sheet: 'Data', range: IrRange(1, 1, 2, 1)),
      )
      ..add(
        IrNamedRange(
          name: 'Plan',
          sheet: 'Q3 plan',
          range: IrRange.columns(0, 1),
        ),
      )
      ..add(const IrNamedRange(name: 'Rate', formulaA1: '0.19'));
    return d;
  }
}

/// Automatic styles of [kLibreOfficeSheet] (as LibreOffice 7 writes them).
const String kLibreOfficeAutoStyles = '''
<style:style style:name="co1" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="0.889in"/></style:style>
<style:style style:name="co2" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="1.5in"/></style:style>
<style:style style:name="ro1" style:family="table-row"><style:table-row-properties style:row-height="0.178in" fo:break-before="auto" style:use-optimal-row-height="true"/></style:style>
<style:style style:name="ro2" style:family="table-row"><style:table-row-properties style:row-height="0.4in" fo:break-before="auto" style:use-optimal-row-height="false"/></style:style>
<style:style style:name="ta1" style:family="table" style:master-page-name="Default"><style:table-properties table:display="true" style:writing-mode="lr-tb" tableooo:tab-color="#ff0000"/></style:style>
<style:style style:name="ta2" style:family="table" style:master-page-name="Default"><style:table-properties table:display="false" style:writing-mode="lr-tb"/></style:style>
<number:date-style style:name="N36" number:automatic-order="true"><number:day number:style="long"/><number:text>.</number:text><number:month number:style="long"/><number:text>.</number:text><number:year number:style="long"/></number:date-style>
<number:percentage-style style:name="N11"><number:number number:decimal-places="2" number:min-decimal-places="2" number:min-integer-digits="1"/><number:text>%</number:text></number:percentage-style>
<number:currency-style style:name="N122P0" style:volatile="true"><number:currency-symbol number:language="en" number:country="US">\$</number:currency-symbol><number:number number:decimal-places="2" number:min-decimal-places="2" number:min-integer-digits="1" number:grouping="true"/></number:currency-style>
<number:currency-style style:name="N122"><style:text-properties fo:color="#ff0000"/><number:text>-</number:text><number:currency-symbol number:language="en" number:country="US">\$</number:currency-symbol><number:number number:decimal-places="2" number:min-decimal-places="2" number:min-integer-digits="1" number:grouping="true"/><style:map style:condition="value()&gt;=0" style:apply-style-name="N122P0"/></number:currency-style>
<number:boolean-style style:name="N99"><number:boolean/></number:boolean-style>
<style:style style:name="ce1" style:family="table-cell" style:parent-style-name="Default"><style:table-cell-properties fo:background-color="#ffff00" style:text-align-source="fix" style:repeat-content="false"/><style:paragraph-properties fo:text-align="center" fo:margin-left="0in"/><style:text-properties fo:font-weight="bold" style:font-weight-asian="bold" style:font-weight-complex="bold"/></style:style>
<style:style style:name="ce2" style:family="table-cell" style:parent-style-name="Default" style:data-style-name="N36"/>
<style:style style:name="ce3" style:family="table-cell" style:parent-style-name="Default" style:data-style-name="N11"/>
<style:style style:name="ce4" style:family="table-cell" style:parent-style-name="Default" style:data-style-name="N122"/>
<style:style style:name="ce5" style:family="table-cell" style:parent-style-name="Default"><style:table-cell-properties fo:border-bottom="0.74pt solid #000000" fo:border-left="none" fo:border-right="none" fo:border-top="2.49pt solid #0000ff" fo:wrap-option="wrap" style:vertical-align="top" style:rotation-angle="90"/><style:text-properties style:font-name="DejaVu Serif" fo:font-size="12pt" fo:font-style="italic" style:text-underline-style="solid" style:text-underline-width="auto" style:text-underline-color="font-color" fo:color="#00ff00"/></style:style>
<style:style style:name="ce6" style:family="table-cell" style:parent-style-name="Default" style:data-style-name="N99"/>
<style:style style:name="ce7" style:family="table-cell" style:parent-style-name="Heading"/>
<style:style style:name="T1" style:family="text"><style:text-properties fo:font-weight="bold"/></style:style>
''';

/// Sheets of a LibreOffice-style `content.xml`: repeated rows and columns,
/// spanned cells, typed values, formulas, rich text, notes and names.
const String kLibreOfficeSheet = '''
<table:calculation-settings table:automatic-find-labels="false" table:use-regular-expressions="false"/>
<table:table table:name="Sheet1" table:style-name="ta1">
<table:table-column table:style-name="co2" table:default-cell-style-name="Default"/>
<table:table-column table:style-name="co1" table:number-columns-repeated="3" table:default-cell-style-name="Default"/>
<table:table-column table:style-name="co1" table:visibility="collapse" table:default-cell-style-name="Default"/>
<table:table-column table:style-name="co1" table:number-columns-repeated="16379" table:default-cell-style-name="Default"/>
<table:table-row table:style-name="ro1">
<table:table-cell table:style-name="ce1" office:value-type="string" calcext:value-type="string"><text:p>Header</text:p></table:table-cell>
<table:table-cell table:style-name="ce1" table:number-columns-spanned="2" table:number-rows-spanned="1" office:value-type="string" calcext:value-type="string"><text:p>Merged</text:p></table:table-cell>
<table:covered-table-cell table:style-name="ce1"/>
<table:table-cell table:style-name="ce7" office:value-type="string" calcext:value-type="string"><text:p>Big</text:p></table:table-cell>
<table:table-cell table:number-columns-repeated="16380"/>
</table:table-row>
<table:table-row table:style-name="ro1" table:number-rows-repeated="3">
<table:table-cell office:value-type="float" office:value="1" calcext:value-type="float"><text:p>1</text:p></table:table-cell>
<table:table-cell table:number-columns-repeated="2" office:value-type="string" calcext:value-type="string"><text:p>rep</text:p></table:table-cell>
<table:table-cell table:number-columns-repeated="16381"/>
</table:table-row>
<table:table-row table:style-name="ro2">
<table:table-cell table:style-name="ce2" office:value-type="date" office:date-value="2026-10-14" calcext:value-type="date"><text:p>14.10.2026</text:p></table:table-cell>
<table:table-cell table:style-name="ce3" office:value-type="percentage" office:value="0.125" calcext:value-type="percentage"><text:p>12.50%</text:p></table:table-cell>
<table:table-cell table:style-name="ce4" office:value-type="currency" office:currency="USD" office:value="-1234.5" calcext:value-type="currency"><text:p>-\$1,234.50</text:p></table:table-cell>
<table:table-cell table:style-name="ce6" office:value-type="boolean" office:boolean-value="true" calcext:value-type="boolean"><text:p>TRUE</text:p></table:table-cell>
<table:table-cell office:value-type="time" office:time-value="PT13H45M00S" calcext:value-type="time"><text:p>01:45:00 PM</text:p></table:table-cell>
<table:table-cell table:number-columns-repeated="16379"/>
</table:table-row>
<table:table-row table:style-name="ro1" table:visibility="collapse">
<table:table-cell table:formula="of:=SUM([.A2:.A4])" office:value-type="float" office:value="3" calcext:value-type="float"><text:p>3</text:p></table:table-cell>
<table:table-cell table:formula="of:=[\$Other.A1]&amp;&quot;!&quot;" office:value-type="string" office:string-value="hi!" calcext:value-type="string"><text:p>hi!</text:p></table:table-cell>
<table:table-cell table:formula="of:=1/0" office:value-type="float" office:value="0" calcext:value-type="error"><text:p>#DIV/0!</text:p></table:table-cell>
<table:table-cell table:formula="of:=IF([.A2]&gt;0;TRUE();FALSE())" office:value-type="boolean" office:boolean-value="true" calcext:value-type="boolean"><text:p>TRUE</text:p></table:table-cell>
<table:table-cell table:number-columns-repeated="16380"/>
</table:table-row>
<table:table-row table:style-name="ro1">
<table:table-cell table:style-name="ce5" office:value-type="string" calcext:value-type="string"><office:annotation><dc:creator>Ann</dc:creator><dc:date>2026-10-01T00:00:00</dc:date><text:p>Check</text:p><text:p>this</text:p></office:annotation><text:p>Two<text:s/> spaces <text:span text:style-name="T1">bold</text:span></text:p><text:p>second line</text:p></table:table-cell>
<table:table-cell office:value-type="string" calcext:value-type="string"><text:p><text:a xlink:href="https://example.com/" xlink:type="simple">Example</text:a></text:p></table:table-cell>
<table:table-cell table:formula="of:=[.A2:.A3]*10" table:number-matrix-columns-spanned="1" table:number-matrix-rows-spanned="2" office:value-type="float" office:value="10" calcext:value-type="float"><text:p>10</text:p></table:table-cell>
<table:table-cell office:value-type="string" calcext:value-type="string"><text:p><text:a xlink:href="#Other.A1" xlink:type="simple">Jump</text:a></text:p></table:table-cell>
<table:table-cell table:number-columns-repeated="16380"/>
</table:table-row>
<table:table-row table:style-name="ro1">
<table:table-cell table:number-columns-repeated="2"/>
<table:table-cell office:value-type="float" office:value="20" calcext:value-type="float"><text:p>20</text:p></table:table-cell>
<table:table-cell table:number-columns-repeated="16381"/>
</table:table-row>
<table:table-row table:style-name="ro1" table:number-rows-repeated="1048567">
<table:table-cell table:style-name="ce1" table:number-columns-repeated="16384"/>
</table:table-row>
</table:table>
<table:table table:name="Other" table:style-name="ta2">
<table:table-column table:style-name="co1" table:default-cell-style-name="Default"/>
<table:table-row table:style-name="ro1"><table:table-cell office:value-type="string" calcext:value-type="string"><text:p>hi</text:p></table:table-cell></table:table-row>
</table:table>
<table:named-expressions>
<table:named-range table:name="Nums" table:base-cell-address="\$Sheet1.\$A\$2" table:cell-range-address="\$Sheet1.\$A\$2:.\$A\$4"/>
<table:named-expression table:name="Rate" table:base-cell-address="\$Sheet1.\$A\$1" table:expression="of:=0.19"/>
</table:named-expressions>
''';

/// A LibreOffice `settings.xml` freezing the first row of `Sheet1` and
/// hiding its gridlines.
const String kLibreOfficeSettings =
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<office:document-settings $kOdfNamespaces office:version="1.3">'
    '<office:settings><config:config-item-set config:name="ooo:view-settings">'
    '<config:config-item-map-indexed config:name="Views"><config:config-item-map-entry>'
    '<config:config-item config:name="ViewId" config:type="string">view1</config:config-item>'
    '<config:config-item-map-named config:name="Tables">'
    '<config:config-item-map-entry config:name="Sheet1">'
    '<config:config-item config:name="HorizontalSplitMode" config:type="short">0</config:config-item>'
    '<config:config-item config:name="VerticalSplitMode" config:type="short">2</config:config-item>'
    '<config:config-item config:name="HorizontalSplitPosition" config:type="int">0</config:config-item>'
    '<config:config-item config:name="VerticalSplitPosition" config:type="int">1</config:config-item>'
    '<config:config-item config:name="ShowGrid" config:type="boolean">false</config:config-item>'
    '</config:config-item-map-entry></config:config-item-map-named>'
    '<config:config-item config:name="ShowGrid" config:type="boolean">true</config:config-item>'
    '</config:config-item-map-entry></config:config-item-map-indexed>'
    '</config:config-item-set></office:settings></office:document-settings>';

/// The LibreOffice-style package.
Uint8List libreOfficePackage() => odsPackage(
  content: odsContent(
    automaticStyles: kLibreOfficeAutoStyles,
    spreadsheet: kLibreOfficeSheet,
  ),
  styles: kLibreOfficeStyles,
  settings: kLibreOfficeSettings,
);
