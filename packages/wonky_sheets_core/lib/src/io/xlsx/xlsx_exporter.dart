import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:clock/clock.dart';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../content/rich_text.dart';
import '../../format/attributes.dart';
import '../formula/excel_formula_translator.dart';
import '../formula/formula_tokens.dart';
import '../ir/import_warning.dart';
import '../ir/ir_range.dart';
import '../ir/workbook_document.dart';
import 'ooxml.dart';
import 'xlsx_parts.dart';
import 'xlsx_print.dart';
import 'xlsx_rules.dart';
import 'xlsx_style_writer.dart';

/// Options of an XLSX export.
final class XlsxExportOptions {
  /// Creates options.
  const XlsxExportOptions({
    this.locale,
    this.modified,
    this.creator = 'Wonky Sheets',
  });

  /// Locale for preset number formats (default: the document locale).
  final String? locale;

  /// Timestamp for docProps and zip entries (default: `clock.now()`).
  final DateTime? modified;
  final String creator;
}

/// IR → XLSX (11 §6.2) with an own OOXML writer: files open in Excel and
/// LibreOffice without repair (ECMA-376 element order).
abstract final class XlsxExporter {
  /// Writes [doc]. Export issues (Google-only functions, dropped rules, …)
  /// are added to [report] when given.
  static Uint8List export(
    WorkbookDocument doc, [
    XlsxExportOptions options = const XlsxExportOptions(),
    ImportWarnings? report,
  ]) => _Writer(doc, options, report ?? ImportWarnings()).write();

  /// An Excel-valid, unique sheet name for [name].
  static String excelSheetName(String name, Set<String> taken) {
    var n = name.replaceAll(RegExp(r'[\[\]:\*\?/\\]'), '_');
    while (n.startsWith("'")) {
      n = n.substring(1);
    }
    while (n.endsWith("'")) {
      n = n.substring(0, n.length - 1);
    }
    if (n.isEmpty) n = 'Sheet';
    if (n.length > 31) n = n.substring(0, 31);
    var cand = n;
    var k = 2;
    while (taken.contains(cand.toLowerCase())) {
      final suffix = ' ($k)';
      k++;
      cand =
          (n.length + suffix.length > 31
              ? n.substring(0, 31 - suffix.length)
              : n) +
          suffix;
    }
    taken.add(cand.toLowerCase());
    return cand;
  }
}

final class _SharedStrings {
  final List<String> items = [];
  final Map<String, int> _index = {};
  int count = 0;

  int add(String key, String xml) {
    count++;
    return _index.putIfAbsent(key, () {
      items.add(xml);
      return items.length - 1;
    });
  }
}

final class _Writer {
  _Writer(this.doc, this.options, this.report)
    : locale = options.locale ?? doc.locale ?? 'en_US',
      modified = options.modified ?? clock.now();

  final WorkbookDocument doc;
  final XlsxExportOptions options;
  final ImportWarnings report;
  final String locale;
  final DateTime modified;
  final Archive archive = Archive();
  final _SharedStrings sst = _SharedStrings();
  late final XlsxStyleWriter styles = XlsxStyleWriter(
    defaultFont: doc.defaultFontFamily ?? doc.theme?.textFont ?? 'Calibri',
    defaultSize: doc.defaultFontSize ?? 11,
    locale: locale,
    warnings: report,
  );
  final List<String> overrides = [];
  final Set<String> extensions = {};
  bool usesDynamicArrays = false;
  late final Map<String, String> sheetRenames;
  late final ExcelFormulaTranslator translator;
  final Map<String, int> _googleOnly = {};

  void _add(String path, String content) {
    archive.add(ArchiveFile.bytes(path, utf8.encode(content)));
  }

  void _override(String path, String type) => overrides.add(
    '<Override PartName="/$path" ContentType="application/vnd.openxmlformats-$type"/>',
  );

  Uint8List write() {
    if (doc.sheets.isEmpty) {
      throw ArgumentError('A workbook needs at least one sheet');
    }
    final taken = <String>{};
    final names = <String>[];
    final renames = <String, String>{};
    for (final s in doc.sheets) {
      final n = XlsxExporter.excelSheetName(s.name, taken);
      names.add(n);
      if (n != s.name) {
        renames[s.name] = n;
        report.add(
          'sheetRenamed',
          'Sheet "${s.name}" was renamed to "$n" for Excel',
          sheet: s.name,
        );
      }
    }
    sheetRenames = renames;
    translator = ExcelFormulaTranslator(
      sheetRenames: renames,
      knownNames: {for (final n in doc.namedRanges) n.name},
    );
    final firstVisible = doc.sheets.indexWhere((s) => !s.hidden);
    final active = firstVisible < 0 ? 0 : firstVisible;
    final sheetRels = StringBuffer();
    final sheetEls = StringBuffer();
    final definedNames = <String>[];
    for (var i = 0; i < doc.sheets.length; i++) {
      final s = doc.sheets[i];
      final path = 'xl/worksheets/sheet${i + 1}.xml';
      _add(path, _sheet(s, i, names[i], i == active, definedNames));
      _override(path, 'officedocument.spreadsheetml.worksheet+xml');
      sheetRels.write(
        '<Relationship Id="rId${i + 1}" Type="${Ooxml.relWorksheet}" Target="worksheets/sheet${i + 1}.xml"/>',
      );
      final hidden = s.hidden && (firstVisible >= 0) ? ' state="hidden"' : '';
      sheetEls.write(
        '<sheet name="${Ooxml.attr(names[i])}" sheetId="${i + 1}"$hidden r:id="rId${i + 1}"/>',
      );
    }
    for (final g in _googleOnly.entries) {
      report.add(
        'googleOnlyFunction',
        '${g.value} formulas use $g which Excel does not have',
        count: g.value,
      );
    }
    for (final n in doc.namedRanges) {
      final xml = _definedName(n);
      if (xml != null) definedNames.add(xml);
    }
    var rid = doc.sheets.length;
    final wbRels = StringBuffer(sheetRels.toString());
    wbRels.write(
      '<Relationship Id="rId${++rid}" Type="${Ooxml.relTheme}" Target="theme/theme1.xml"/>',
    );
    wbRels.write(
      '<Relationship Id="rId${++rid}" Type="${Ooxml.relStyles}" Target="styles.xml"/>',
    );
    wbRels.write(
      '<Relationship Id="rId${++rid}" Type="${Ooxml.relSharedStrings}" Target="sharedStrings.xml"/>',
    );
    if (usesDynamicArrays) {
      wbRels.write(
        '<Relationship Id="rId${++rid}" Type="${Ooxml.relSheetMetadata}" Target="metadata.xml"/>',
      );
      _add('xl/metadata.xml', XlsxParts.metadata);
      _override(
        'xl/metadata.xml',
        'officedocument.spreadsheetml.sheetMetadata+xml',
      );
    }
    _add(
      'xl/workbook.xml',
      '${XlsxParts.xmlHeader}<workbook xmlns="${Ooxml.main}" xmlns:r="${Ooxml.rel}">'
          '<workbookPr/><bookViews><workbookView activeTab="$active"/></bookViews>'
          '<sheets>$sheetEls</sheets>'
          '${definedNames.isEmpty ? '' : '<definedNames>${definedNames.join()}</definedNames>'}'
          '<calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>',
    );
    _override('xl/workbook.xml', 'officedocument.spreadsheetml.sheet.main+xml');
    _add('xl/_rels/workbook.xml.rels', _rels(wbRels.toString()));
    _add(
      'xl/theme/theme1.xml',
      XlsxParts.theme(doc.theme, textFont: styles.defaultFont),
    );
    _override('xl/theme/theme1.xml', 'officedocument.theme+xml');
    final ss = StringBuffer(
      '${XlsxParts.xmlHeader}<sst xmlns="${Ooxml.main}" count="${sst.count}" uniqueCount="${sst.items.length}">',
    );
    for (final i in sst.items) {
      ss.write(i);
    }
    ss.write('</sst>');
    _add('xl/sharedStrings.xml', ss.toString());
    _override(
      'xl/sharedStrings.xml',
      'officedocument.spreadsheetml.sharedStrings+xml',
    );
    _add('xl/styles.xml', styles.build());
    _override('xl/styles.xml', 'officedocument.spreadsheetml.styles+xml');
    _add(
      'docProps/core.xml',
      XlsxParts.core(
        title: doc.title,
        creator: options.creator,
        modified: modified,
      ),
    );
    overrides.add(
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>',
    );
    _add('docProps/app.xml', XlsxParts.app(names));
    _override('docProps/app.xml', 'officedocument.extended-properties+xml');
    _add(
      '_rels/.rels',
      _rels(
        '<Relationship Id="rId1" Type="${Ooxml.relOfficeDocument}" Target="xl/workbook.xml"/>'
        '<Relationship Id="rId2" Type="${Ooxml.relCoreProps}" Target="docProps/core.xml"/>'
        '<Relationship Id="rId3" Type="${Ooxml.relExtProps}" Target="docProps/app.xml"/>',
      ),
    );
    final defaults = StringBuffer(
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>',
    );
    for (final e in extensions) {
      final type = switch (e) {
        'vml' => 'application/vnd.openxmlformats-officedocument.vmlDrawing',
        'jpeg' || 'jpg' => 'image/jpeg',
        'gif' => 'image/gif',
        'bmp' => 'image/bmp',
        'webp' => 'image/webp',
        'svg' => 'image/svg+xml',
        _ => 'image/png',
      };
      defaults.write('<Default Extension="$e" ContentType="$type"/>');
    }
    final ct =
        '${XlsxParts.xmlHeader}<Types xmlns="${Ooxml.contentTypes}">$defaults${overrides.join()}</Types>';
    // [Content_Types].xml first, as Office writes it.
    final ordered = Archive()
      ..add(ArchiveFile.bytes('[Content_Types].xml', utf8.encode(ct)));
    for (final f in archive.files) {
      ordered.add(f);
    }
    return ZipEncoder().encodeBytes(ordered, modified: modified);
  }

  static String _rels(String body) =>
      '${XlsxParts.xmlHeader}<Relationships xmlns="${Ooxml.pkgRel}">$body</Relationships>';

  String? _definedName(IrNamedRange n) {
    if (!RegExp(r'^[A-Za-z_\\][A-Za-z0-9_.\\?]*$').hasMatch(n.name)) {
      report.add(
        'nameSkipped',
        'Named range "${n.name}" is not a valid Excel name',
      );
      return null;
    }
    String? value;
    if (n.range != null) {
      final sheet = n.sheet == null
          ? null
          : (sheetRenames[n.sheet!] ?? n.sheet);
      value = _absRef(n.range!, sheet);
    } else if (n.formulaA1 != null) {
      value = translator.exportFormula(n.formulaA1!).formula;
    }
    if (value == null) return null;
    final attrs = StringBuffer('name="${Ooxml.attr(n.name)}"');
    if (n.comment != null && n.comment!.isNotEmpty) {
      attrs.write(' comment="${Ooxml.attr(n.comment!)}"');
    }
    if (n.hidden) attrs.write(' hidden="1"');
    return '<definedName $attrs>${Ooxml.esc(value)}</definedName>';
  }

  static String _absRef(IrRange r, String? sheet) {
    final b = r.isBounded || r.wholeColumns || r.wholeRows
        ? r
        : IrRange(
            r.r1 ?? 0,
            r.c1 ?? 0,
            r.r2 ?? Ooxml.maxRows - 1,
            r.c2 ?? Ooxml.maxCols - 1,
          );
    return b.toA1(sheet: sheet, absolute: true);
  }

  String _cellRef(int r, int c) => CellPos(r, c).a1;

  String _sheet(
    IrSheet s,
    int index,
    String name,
    bool active,
    List<String> definedNames,
  ) {
    final rels = <String>[];
    String rel(String type, String target, {bool external = false}) {
      final id = 'rId${rels.length + 1}';
      rels.add(
        '<Relationship Id="$id" Type="$type" Target="${Ooxml.attr(target)}"${external ? ' TargetMode="External"' : ''}/>',
      );
      return id;
    }

    final print = XlsxPrint.write(s.print);
    final b = StringBuffer(
      '${XlsxParts.xmlHeader}<worksheet xmlns="${Ooxml.main}" xmlns:r="${Ooxml.rel}">',
    );
    // sheetPr
    final pr = StringBuffer();
    if (s.tabColor != null) {
      pr.write('<tabColor ${XlsxStyleWriter.colorAttrs(s.tabColor)}/>');
    }
    if (print.fitToPage) pr.write('<pageSetUpPr fitToPage="1"/>');
    b.write(pr.isEmpty ? '<sheetPr/>' : '<sheetPr>$pr</sheetPr>');
    final maxRow = s.cells.maxRow, maxCol = s.cells.maxCol;
    b.write(
      '<dimension ref="${maxRow < 0 ? 'A1' : 'A1:${_cellRef(maxRow, maxCol < 0 ? 0 : maxCol)}'}"/>',
    );
    // sheetViews
    final view = StringBuffer('<sheetView');
    if (!s.showGridlines) view.write(' showGridLines="0"');
    if (s.rtl) view.write(' rightToLeft="1"');
    if (active) view.write(' tabSelected="1"');
    view.write(' workbookViewId="0"');
    if (s.frozenRows > 0 || s.frozenColumns > 0) {
      final pane = s.frozenRows > 0 && s.frozenColumns > 0
          ? 'bottomRight'
          : (s.frozenRows > 0 ? 'bottomLeft' : 'topRight');
      view.write('><pane');
      if (s.frozenColumns > 0) view.write(' xSplit="${s.frozenColumns}"');
      if (s.frozenRows > 0) view.write(' ySplit="${s.frozenRows}"');
      view.write(
        ' topLeftCell="${_cellRef(s.frozenRows, s.frozenColumns)}" activePane="$pane" state="frozen"/>'
        '<selection pane="$pane"/></sheetView>',
      );
    } else {
      view.write('/>');
    }
    b.write('<sheetViews>$view</sheetViews>');
    // sheetFormatPr
    final defRow = s.defaultRowHeight ?? 20;
    final defCol = s.defaultColumnWidth ?? 64;
    var maxRowOutline = 0, maxColOutline = 0;
    for (final e in s.rows.entries) {
      if (e.value.outlineLevel > maxRowOutline) {
        maxRowOutline = e.value.outlineLevel;
      }
    }
    for (final e in s.columns.entries) {
      if (e.value.outlineLevel > maxColOutline) {
        maxColOutline = e.value.outlineLevel;
      }
    }
    b.write(
      '<sheetFormatPr defaultColWidth="${_n(Ooxml.pxToWidth(defCol))}" defaultRowHeight="${_n(Ooxml.pxToPt(defRow))}"'
      '${defRow != 20 ? ' customHeight="1"' : ''}'
      '${maxRowOutline > 0 ? ' outlineLevelRow="${maxRowOutline.clamp(0, 7)}"' : ''}'
      '${maxColOutline > 0 ? ' outlineLevelCol="${maxColOutline.clamp(0, 7)}"' : ''}/>',
    );
    // cols (runs of identical properties)
    if (!s.columns.isEmpty) {
      b.write('<cols>');
      int? runStart;
      int? runEnd;
      IrDim? run;
      void flush() {
        if (run == null) return;
        final d = run;
        final x = StringBuffer(
          '<col min="${runStart! + 1}" max="${runEnd! + 1}"',
        );
        x.write(' width="${_n(Ooxml.pxToWidth(d.size ?? defCol))}"');
        if (d.format != 0) {
          x.write(' style="${styles.xf(doc.formats[d.format])}"');
        }
        if (d.hidden) x.write(' hidden="1"');
        if (d.size != null) x.write(' customWidth="1"');
        if (d.outlineLevel > 0) {
          x.write(' outlineLevel="${d.outlineLevel.clamp(0, 7)}"');
        }
        if (d.collapsed) x.write(' collapsed="1"');
        x.write('/>');
        b.write(x);
      }

      for (final e in s.columns.entries) {
        if (e.key >= Ooxml.maxCols) break;
        if (run != null && e.value == run && e.key == runEnd! + 1) {
          runEnd = e.key;
          continue;
        }
        flush();
        run = e.value;
        runStart = e.key;
        runEnd = e.key;
      }
      flush();
      b.write('</cols>');
    }
    // filter-hidden rows (values criteria) are written hidden
    final filterHidden = _filterHiddenRows(s);
    // sheetData
    b.write('<sheetData>');
    final rowIdx = <int>{
      ...s.cells.rowIndices,
      for (final e in s.rows.entries) e.key,
      ...filterHidden,
    }.toList()..sort();
    final notes = <(int, int, String)>[];
    final links = <(int, int, String)>[];
    for (final r in rowIdx) {
      if (r >= Ooxml.maxRows) break;
      final d = s.rows[r];
      final x = StringBuffer('<row r="${r + 1}"');
      if (d != null && d.format != 0) {
        x.write(' s="${styles.xf(doc.formats[d.format])}" customFormat="1"');
      }
      if (d?.size != null) {
        x.write(' ht="${_n(Ooxml.pxToPt(d!.size!))}" customHeight="1"');
      }
      if ((d?.hidden ?? false) || filterHidden.contains(r)) {
        x.write(' hidden="1"');
      }
      if (d != null && d.outlineLevel > 0) {
        x.write(' outlineLevel="${d.outlineLevel.clamp(0, 7)}"');
      }
      if (d != null && d.collapsed) x.write(' collapsed="1"');
      final len = s.cells.rowLength(r);
      if (len == 0) {
        x.write('/>');
        b.write(x);
        continue;
      }
      x.write('>');
      b.write(x);
      for (final (c, cell) in s.cells.rowEntries(r)) {
        if (c >= Ooxml.maxCols) break;
        b.write(_cell(r, c, cell, s.name));
        if (cell.note != null && cell.note!.isNotEmpty) {
          notes.add((r, c, cell.note!));
        }
        if (cell.link != null) links.add((r, c, cell.link!));
      }
      b.write('</row>');
    }
    b.write('</sheetData>');
    final rules = XlsxRules(translator, report, sheet: s.name);
    if (s.autoFilter != null) {
      b.write(
        rules.exportFilter(
          s.autoFilter!,
          (r, c) => irDisplayText(doc, s.cells.get(r, c), locale: locale),
          lastRow: maxRow < 0 ? 0 : maxRow,
        ),
      );
      final f = s.autoFilter!.range;
      final ref = f.isBounded
          ? f
          : IrRange(
              f.r1 ?? 0,
              f.c1 ?? 0,
              f.r2 ?? (maxRow < 0 ? 0 : maxRow),
              f.c2 ?? f.c1 ?? 0,
            );
      definedNames.add(
        '<definedName name="_xlnm._FilterDatabase" localSheetId="$index" hidden="1">'
        '${Ooxml.esc(ref.toA1(sheet: name, absolute: true))}</definedName>',
      );
    }
    if (s.merges.isNotEmpty) {
      b.write('<mergeCells count="${s.merges.length}">');
      for (final m in s.merges) {
        b.write('<mergeCell ref="${m.a1}"/>');
      }
      b.write('</mergeCells>');
    }
    var priority = 1;
    for (final cf in s.conditionalFormats) {
      if (!cf.enabled) continue;
      final xml = rules.exportConditionalFormat(cf, priority, styles.dxf);
      if (xml == null) continue;
      priority++;
      b.write(
        '<conditionalFormatting sqref="${formatSqref(cf.ranges)}">$xml</conditionalFormatting>',
      );
    }
    final dvs = [for (final v in s.validations) ?rules.exportValidation(v)];
    if (dvs.isNotEmpty) {
      b.write(
        '<dataValidations count="${dvs.length}">${dvs.join()}</dataValidations>',
      );
    }
    if (links.isNotEmpty) {
      b.write('<hyperlinks>');
      for (final (r, c, link) in links) {
        if (link.startsWith('#')) {
          final loc = FormulaRewriter.renameSheets(
            link.substring(1),
            sheetRenames,
          );
          b.write(
            '<hyperlink ref="${_cellRef(r, c)}" location="${Ooxml.attr(loc)}" display="${Ooxml.attr(loc)}"/>',
          );
        } else {
          final id = rel(Ooxml.relHyperlink, link, external: true);
          b.write('<hyperlink ref="${_cellRef(r, c)}" r:id="$id"/>');
        }
      }
      b.write('</hyperlinks>');
    }
    b
      ..write(print.printOptions)
      ..write(print.margins)
      ..write(print.pageSetup)
      ..write(print.headerFooter)
      ..write(print.breaks);
    final printArea = s.print?['printArea'];
    if (printArea is String) {
      final r = IrRange.parseA1(printArea)?.$2;
      if (r != null) {
        definedNames.add(
          '<definedName name="_xlnm.Print_Area" localSheetId="$index">${Ooxml.esc(_absRef(r, name))}</definedName>',
        );
      }
    }
    final rr = s.print?['repeatRows'], rc = s.print?['repeatCols'];
    final titles = <String>[
      if (rc is Map && rc['start'] is num)
        IrRange.columns(
          (rc['start'] as num).toInt(),
          ((rc['end'] ?? rc['start']) as num).toInt(),
        ).toA1(sheet: name, absolute: true),
      if (rr is Map && rr['start'] is num)
        IrRange.rows(
          (rr['start'] as num).toInt(),
          ((rr['end'] ?? rr['start']) as num).toInt(),
        ).toA1(sheet: name, absolute: true),
    ];
    if (titles.isNotEmpty) {
      definedNames.add(
        '<definedName name="_xlnm.Print_Titles" localSheetId="$index">${Ooxml.esc(titles.join(','))}</definedName>',
      );
    }
    // images
    final images = [
      for (final i in s.images)
        if (i.bytes != null) i,
    ];
    if (images.length < s.images.length) {
      report.add(
        'imageSkipped',
        'Images without data were not exported',
        sheet: s.name,
        count: s.images.length - images.length,
      );
    }
    if (s.charts.isNotEmpty) {
      report.add(
        'chartsNotExported',
        'Charts were not exported',
        sheet: s.name,
        count: s.charts.length,
      );
    }
    if (images.isNotEmpty) {
      final dpath = 'xl/drawings/drawing${index + 1}.xml';
      final drels = <String>[];
      final dx = StringBuffer(
        '${XlsxParts.xmlHeader}<xdr:wsDr xmlns:xdr="${Ooxml.xdr}" xmlns:a="${Ooxml.drawingMl}" xmlns:r="${Ooxml.rel}">',
      );
      for (var k = 0; k < images.length; k++) {
        final img = images[k];
        final ext = switch (img.mimeType) {
          'image/jpeg' => 'jpeg',
          'image/gif' => 'gif',
          'image/bmp' => 'bmp',
          'image/webp' => 'webp',
          'image/svg+xml' => 'svg',
          _ => 'png',
        };
        extensions.add(ext);
        final media = 'xl/media/image${index + 1}_${k + 1}.$ext';
        archive.add(ArchiveFile.bytes(media, img.bytes!));
        drels.add(
          '<Relationship Id="rId${k + 1}" Type="${Ooxml.relImage}" Target="../media/image${index + 1}_${k + 1}.$ext"/>',
        );
        final a = img.anchor;
        int emu(double px) => (px * Ooxml.emuPerPx).round();
        dx.write(
          '<xdr:oneCellAnchor><xdr:from><xdr:col>${a.col}</xdr:col><xdr:colOff>${emu(a.dx)}</xdr:colOff>'
          '<xdr:row>${a.row}</xdr:row><xdr:rowOff>${emu(a.dy)}</xdr:rowOff></xdr:from>'
          '<xdr:ext cx="${emu(a.width)}" cy="${emu(a.height)}"/><xdr:pic><xdr:nvPicPr>'
          '<xdr:cNvPr id="${k + 2}" name="${Ooxml.attr(img.title ?? 'Picture ${k + 1}')}"'
          '${img.altText != null ? ' descr="${Ooxml.attr(img.altText!)}"' : ''}'
          '${img.title != null ? ' title="${Ooxml.attr(img.title!)}"' : ''}/>'
          '<xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr>'
          '<xdr:blipFill><a:blip r:embed="rId${k + 1}"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill>'
          '<xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="${emu(a.width)}" cy="${emu(a.height)}"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic><xdr:clientData/></xdr:oneCellAnchor>',
        );
      }
      dx.write('</xdr:wsDr>');
      _add(dpath, dx.toString());
      _override(dpath, 'officedocument.drawing+xml');
      _add(Ooxml.relsPathOf(dpath), _rels(drels.join()));
      b.write(
        '<drawing r:id="${rel(Ooxml.relDrawing, '../drawings/drawing${index + 1}.xml')}"/>',
      );
    }
    if (notes.isNotEmpty) {
      final cpath = 'xl/comments${index + 1}.xml';
      final cx = StringBuffer(
        '${XlsxParts.xmlHeader}<comments xmlns="${Ooxml.main}"><authors><author></author></authors><commentList>',
      );
      for (final (r, c, text) in notes) {
        cx.write(
          '<comment ref="${_cellRef(r, c)}" authorId="0"><text><t xml:space="preserve">${Ooxml.esc(text)}</t></text></comment>',
        );
      }
      cx.write('</commentList></comments>');
      _add(cpath, cx.toString());
      _override(cpath, 'officedocument.spreadsheetml.comments+xml');
      final vpath = 'xl/drawings/vmlDrawing${index + 1}.vml';
      _add(
        vpath,
        XlsxParts.vml(index + 1, [for (final (r, c, _) in notes) (r, c)]),
      );
      extensions.add('vml');
      rel(Ooxml.relComments, '../comments${index + 1}.xml');
      b.write(
        '<legacyDrawing r:id="${rel(Ooxml.relVml, '../drawings/vmlDrawing${index + 1}.vml')}"/>',
      );
    }
    b.write('</worksheet>');
    if (rels.isNotEmpty) {
      _add(
        Ooxml.relsPathOf('xl/worksheets/sheet${index + 1}.xml'),
        _rels(rels.join()),
      );
    }
    return b.toString();
  }

  Set<int> _filterHiddenRows(IrSheet s) {
    final f = s.autoFilter;
    if (f == null || f.criteria.isEmpty) return const {};
    final top = f.range.top + 1;
    final bottom = f.range.r2 ?? s.cells.maxRow;
    final out = <int>{};
    for (final e in f.criteria.entries) {
      final hidden = ((e.value['hiddenValues'] as List?) ?? const [])
          .map((x) => '$x')
          .toSet();
      if (hidden.isEmpty) continue;
      for (var r = top; r <= bottom; r++) {
        if (hidden.contains(
          irDisplayText(
            doc,
            s.cells.get(r, f.range.left + e.key),
            locale: locale,
          ),
        )) {
          out.add(r);
        }
      }
    }
    return out;
  }

  String _cell(int r, int c, IrCell cell, String sheetName) {
    final ref = _cellRef(r, c);
    final format = doc.formats[cell.format];
    final xf = styles.xf(format);
    final sAttr = xf == 0 ? '' : ' s="$xf"';
    final v = cell.value;
    var formula = cell.formulaA1;
    if (formula != null) {
      var kind = cell.formulaKind;
      var body = formula;
      final wrapped = _unwrapArrayFormula(body);
      if (wrapped != null &&
          (kind == IrFormulaKind.array || kind == IrFormulaKind.normal)) {
        body = wrapped;
        kind = IrFormulaKind.array;
      }
      final tr = translator.exportFormula(body);
      for (final g in tr.unsupported) {
        _googleOnly[g] = (_googleOnly[g] ?? 0) + 1;
      }
      final fAttrs = switch (kind) {
        IrFormulaKind.normal => '',
        _ => ' t="array" ref="${(cell.arrayRef ?? GridRect.cell(r, c)).a1}"',
      };
      final cm = kind == IrFormulaKind.dynamicArray ? ' cm="1"' : '';
      if (kind == IrFormulaKind.dynamicArray) usesDynamicArrays = true;
      final (t, val) = switch (v) {
        null => ('', null),
        IrNumber(:final number) => ('', _number(number, xf)),
        IrText(:final text) => (' t="str"', Ooxml.esc(text)),
        IrRich(:final rich) => (' t="str"', Ooxml.esc(rich.text)),
        IrBool(:final value) => (' t="b"', value ? '1' : '0'),
        IrError(:final kind) => (' t="e"', _excelError(kind)),
      };
      return '<c r="$ref"$sAttr$t$cm><f$fAttrs>${Ooxml.esc(tr.formula)}</f>${val == null ? '' : '<v>$val</v>'}</c>';
    }
    switch (v) {
      case null:
        return '<c r="$ref"$sAttr/>';
      case IrNumber(:final number):
        return '<c r="$ref"$sAttr><v>${_number(number, xf)}</v></c>';
      case IrText(:final text):
        final i = sst.add(
          's:$text',
          '<si><t xml:space="preserve">${Ooxml.esc(text)}</t></si>',
        );
        return '<c r="$ref"$sAttr t="s"><v>$i</v></c>';
      case IrRich(:final rich):
        final i = sst.add(
          'r:${jsonEncode(rich.toJson())}',
          _richXml(rich, format),
        );
        return '<c r="$ref"$sAttr t="s"><v>$i</v></c>';
      case IrBool(:final value):
        return '<c r="$ref"$sAttr t="b"><v>${value ? 1 : 0}</v></c>';
      case IrError(:final kind):
        return '<c r="$ref"$sAttr t="e"><v>${_excelError(kind)}</v></c>';
    }
  }

  static String _excelError(CellErrorKind k) => switch (k) {
    CellErrorKind.parse ||
    CellErrorKind.loading ||
    CellErrorKind.blocked => '#VALUE!',
    CellErrorKind.calc => '#CALC!',
    _ => k.literal,
  };

  String _number(double n, int xf) {
    var d = n;
    // Wonky serials 1–60 (before 1900-03-01) are one more than Excel's.
    if (styles.isDateXf(xf) && d >= 1 && d < 61) d -= 1;
    return CellContent.formatNumber(d);
  }

  static String? _unwrapArrayFormula(String f) {
    final t = f.trim();
    if (!t.toUpperCase().startsWith('ARRAYFORMULA(') || !t.endsWith(')')) {
      return null;
    }
    final inner = t.substring(13, t.length - 1);
    // The outer parentheses must match each other.
    final tokens = FormulaTokenizer.tokenize(inner);
    var depth = 0;
    for (final tok in tokens) {
      if (tok.kind == FTok.open) depth++;
      if (tok.kind == FTok.close) {
        depth--;
        if (depth < 0) return null;
      }
    }
    return depth == 0 ? inner : null;
  }

  String _richXml(RichText rich, IrFormat cellFormat) {
    final b = StringBuffer('<si>');
    var pos = 0;
    void run(int start, int end, Map<String, Object?> f) {
      if (end <= start) return;
      final text = rich.text.substring(start, end);
      final p = StringBuffer();
      final font =
          f[RichRunKeys.fontFamily] ??
          cellFormat[FormatAttr.fontFamily] ??
          styles.defaultFont;
      p.write('<rFont val="${Ooxml.attr('$font')}"/>');
      if ((f[RichRunKeys.bold] ?? cellFormat[FormatAttr.bold]) == true) {
        p.write('<b/>');
      }
      if ((f[RichRunKeys.italic] ?? cellFormat[FormatAttr.italic]) == true) {
        p.write('<i/>');
      }
      if ((f[RichRunKeys.strikethrough] ??
              cellFormat[FormatAttr.strikethrough]) ==
          true) {
        p.write('<strike/>');
      }
      final color =
          f[RichRunKeys.textColor] ?? cellFormat[FormatAttr.textColor];
      if (color is String) {
        p.write('<color ${XlsxStyleWriter.colorAttrs(color)}/>');
      }
      final size =
          f[RichRunKeys.fontSize] ??
          cellFormat[FormatAttr.fontSize] ??
          styles.defaultSize;
      p.write('<sz val="${_n((size as num).toDouble())}"/>');
      if ((f[RichRunKeys.underline] ?? cellFormat[FormatAttr.underline]) ==
          true) {
        p.write('<u/>');
      }
      b.write(
        '<r><rPr>$p</rPr><t xml:space="preserve">${Ooxml.esc(text)}</t></r>',
      );
    }

    for (final r in rich.runs) {
      if (r.start > pos) run(pos, r.start, const {});
      run(r.start, r.end, r.format);
      pos = r.end;
    }
    if (pos < rich.text.length) run(pos, rich.text.length, const {});
    b.write('</si>');
    return b.toString();
  }

  static String _n(double d) {
    if (d == d.truncateToDouble()) return d.toInt().toString();
    var s = d.toStringAsFixed(8);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }
}
