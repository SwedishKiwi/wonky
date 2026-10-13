import '../color/excel_colors.dart';
import '../ir/workbook_document.dart';
import 'ooxml.dart';

/// Static OOXML parts of the XLSX writer.
abstract final class XlsxParts {
  static const xmlHeader =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

  /// `xl/theme/theme1.xml` with the workbook's theme colors and fonts.
  static String theme(IrTheme? theme, {String textFont = 'Calibri'}) {
    final colors = Map.of(ExcelColors.officeTheme);
    if (theme != null) {
      theme.colors.forEach((k, v) {
        final slot = ExcelColors.slotOfWonkyKey(k);
        if (slot != null) colors[slot] = v.toUpperCase();
      });
    }
    String clr(String slot) {
      final hex = colors[slot]!.substring(1);
      if (slot == 'dk1') {
        return '<a:$slot><a:sysClr val="windowText" lastClr="$hex"/></a:$slot>';
      }
      if (slot == 'lt1') {
        return '<a:$slot><a:sysClr val="window" lastClr="$hex"/></a:$slot>';
      }
      return '<a:$slot><a:srgbClr val="$hex"/></a:$slot>';
    }

    final minor = Ooxml.attr(theme?.textFont ?? textFont);
    final major = Ooxml.attr(theme?.headingFont ?? theme?.textFont ?? textFont);
    final name = Ooxml.attr(theme?.name ?? 'Office Theme');
    const solid = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>';
    const line =
        '<a:ln w="6350" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln>';
    return '$xmlHeader<a:theme xmlns:a="${Ooxml.drawingMl}" name="$name"><a:themeElements>'
        '<a:clrScheme name="$name">${ExcelColors.schemeOrder.map(clr).join()}</a:clrScheme>'
        '<a:fontScheme name="$name"><a:majorFont><a:latin typeface="$major"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
        '<a:minorFont><a:latin typeface="$minor"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>'
        '<a:fmtScheme name="$name"><a:fillStyleLst>$solid$solid$solid</a:fillStyleLst>'
        '<a:lnStyleLst>$line$line$line</a:lnStyleLst>'
        '<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>'
        '<a:bgFillStyleLst>$solid$solid$solid</a:bgFillStyleLst></a:fmtScheme>'
        '</a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>';
  }

  /// `xl/metadata.xml` declaring the dynamic-array cell metadata (`cm="1"`).
  static const metadata =
      '$xmlHeader<metadata xmlns="${Ooxml.main}" '
      'xmlns:xda="http://schemas.microsoft.com/office/spreadsheetml/2017/dynamicarray">'
      '<metadataTypes count="1"><metadataType name="XLDAPR" minSupportedVersion="120000" copy="1" pasteAll="1" '
      'pasteValues="1" merge="1" splitFirst="1" rowColShift="1" clearFormats="1" clearComments="1" assign="1" '
      'coerce="1" cellMeta="1"/></metadataTypes><futureMetadata name="XLDAPR" count="1"><bk><extLst>'
      '<ext uri="{bdbb8cdc-fa1e-496e-a857-3c3f30c029c3}"><xda:dynamicArrayProperties fDynamic="1" fCollapsed="0"/>'
      '</ext></extLst></bk></futureMetadata><cellMetadata count="1"><bk><rc t="1" v="0"/></bk></cellMetadata></metadata>';

  /// `docProps/core.xml`.
  static String core({
    String? title,
    String creator = 'Wonky Sheets',
    required DateTime modified,
  }) {
    final ts = '${modified.toUtc().toIso8601String().split('.').first}Z';
    return '$xmlHeader<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '${title == null ? '' : '<dc:title>${Ooxml.esc(title)}</dc:title>'}<dc:creator>${Ooxml.esc(creator)}</dc:creator>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$ts</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">$ts</dcterms:modified></cp:coreProperties>';
  }

  /// `docProps/app.xml`.
  static String app(List<String> sheetNames) =>
      '$xmlHeader<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
      'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Wonky Sheets</Application>'
      '<DocSecurity>0</DocSecurity><ScaleCrop>false</ScaleCrop><HeadingPairs><vt:vector size="2" baseType="variant">'
      '<vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant><vt:variant><vt:i4>${sheetNames.length}</vt:i4></vt:variant>'
      '</vt:vector></HeadingPairs><TitlesOfParts><vt:vector size="${sheetNames.length}" baseType="lpstr">'
      '${sheetNames.map((n) => '<vt:lpstr>${Ooxml.esc(n)}</vt:lpstr>').join()}</vt:vector></TitlesOfParts>'
      '<AppVersion>16.0300</AppVersion></Properties>';

  /// A legacy VML drawing holding note shapes for [cells] (`(row, col)`).
  static String vml(int sheetNumber, List<(int, int)> cells) {
    final b = StringBuffer(
      '<xml xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" '
      'xmlns:x="urn:schemas-microsoft-com:office:excel"><o:shapelayout v:ext="edit"><o:idmap v:ext="edit" data="$sheetNumber"/>'
      '</o:shapelayout><v:shapetype id="_x0000_t202" coordsize="21600,21600" o:spt="202" path="m,l,21600r21600,l21600,xe">'
      '<v:stroke joinstyle="miter"/><v:path gradientshapeok="t" o:connecttype="rect"/></v:shapetype>',
    );
    var id = sheetNumber * 1024 + 1;
    for (final (r, c) in cells) {
      b.write(
        '<v:shape id="_x0000_s${id++}" type="#_x0000_t202" style="position:absolute;margin-left:59.25pt;'
        'margin-top:1.5pt;width:108pt;height:59.25pt;z-index:1;visibility:hidden" fillcolor="#ffffe1" o:insetmode="auto">'
        '<v:fill color2="#ffffe1"/><v:shadow on="t" color="black" obscured="t"/><v:path o:connecttype="none"/>'
        '<v:textbox style="mso-direction-alt:auto"><div style="text-align:left"></div></v:textbox>'
        '<x:ClientData ObjectType="Note"><x:MoveWithCells/><x:SizeWithCells/>'
        '<x:Anchor>${c + 1}, 15, ${r > 0 ? r - 1 : 0}, 2, ${c + 3}, 15, ${r + 3}, 16</x:Anchor><x:AutoFill>False</x:AutoFill>'
        '<x:Row>$r</x:Row><x:Column>$c</x:Column></x:ClientData></v:shape>',
      );
    }
    b.write('</xml>');
    return b.toString();
  }
}
