import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:clock/clock.dart';
import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../content/rich_text.dart';
import '../../format/attributes.dart';
import '../../format/number_format/number_formatter.dart';
import '../../format/theme.dart';
import '../formula/formula_tokens.dart';
import '../formula/open_formula_translator.dart';
import '../ir/import_warning.dart';
import '../ir/ir_range.dart';
import '../ir/workbook_document.dart';
import 'ods_charts.dart';
import 'ods_styles.dart';

/// Options of an ODS export.
final class OdsExportOptions {
  /// Creates options.
  const OdsExportOptions({
    this.locale,
    this.modified,
    this.creator = 'Wonky Sheets',
    this.wonkyExtensions = true,
  });

  /// Locale for preset number formats and displayed texts (default: the
  /// document locale).
  final String? locale;

  /// Timestamp for `meta.xml` and zip entries (default: `clock.now()`).
  final DateTime? modified;
  final String creator;

  /// Whether `wonky:*` attributes (exact formats, theme colors, default
  /// sizes) are written so that Wonky re-imports the file losslessly.
  final bool wonkyExtensions;
}

/// IR → ODS (11 §6.4): an ODF 1.2 package with `mimetype` stored first,
/// `META-INF/manifest.xml`, `content.xml`, `styles.xml`, `meta.xml` and
/// `settings.xml` (frozen panes, gridlines).
abstract final class OdsExporter {
  /// Writes [doc]. Features ODS can't hold (validation, conditional
  /// formatting, filters, groups, images, charts) are reported in [report].
  static Uint8List export(
    WorkbookDocument doc, [
    OdsExportOptions options = const OdsExportOptions(),
    ImportWarnings? report,
  ]) => _Writer(doc, options, report ?? ImportWarnings()).write();
}

/// Adjacent identical cells/rows compressed with `number-*-repeated`.
final class _RunWriter {
  _RunWriter(this.repeatAttr);

  final String repeatAttr;
  final StringBuffer out = StringBuffer();
  String? _open;
  String? _rest;
  int _count = 0;

  /// Adds [count] elements `<$open$rest` (open = tag + attributes, rest =
  /// `/>` or `>body</tag>`).
  void add(String open, String rest, [int count = 1]) {
    if (count <= 0) return;
    if (_open == open && _rest == rest) {
      _count += count;
      return;
    }
    flush();
    _open = open;
    _rest = rest;
    _count = count;
  }

  void flush() {
    final open = _open;
    if (open == null) return;
    out
      ..write(open)
      ..write(_count > 1 ? ' $repeatAttr="$_count"' : '')
      ..write(_rest);
    _open = null;
    _count = 0;
  }

  @override
  String toString() {
    flush();
    return out.toString();
  }
}

final class _Writer {
  _Writer(this.doc, this.options, this.report)
    : locale = options.locale ?? doc.locale ?? 'en_US',
      modified = options.modified ?? clock.now() {
    theme = doc.theme?.toSpreadsheetTheme() ?? SpreadsheetTheme.standard;
    defaultFont = doc.defaultFontFamily ?? doc.theme?.textFont ?? 'Arial';
    defaultSize = doc.defaultFontSize ?? 10;
    styles = OdsStyleWriter(
      theme: theme,
      defaultFont: defaultFont,
      defaultSize: defaultSize,
      locale: locale,
      wonkyExtensions: options.wonkyExtensions,
    );
  }

  final WorkbookDocument doc;
  final OdsExportOptions options;
  final ImportWarnings report;
  final String locale;
  final DateTime modified;
  late final SpreadsheetTheme theme;
  late final String defaultFont;
  late final double defaultSize;
  late final OdsStyleWriter styles;
  final OpenFormulaTranslator translator = OpenFormulaTranslator();

  /// `content.xml` of the embedded chart objects (`Object 1` …).
  final List<String> _chartObjects = [];

  /// IR sheet name → the name written in the file.
  Map<String, String> _odsNames = const {};
  final NumberFormatter formatter = NumberFormatter.instance;

  static const _xmlHeader = '<?xml version="1.0" encoding="UTF-8"?>';
  static const _version = '1.2';

  Uint8List write() {
    if (doc.sheets.isEmpty) {
      throw ArgumentError('A workbook needs at least one sheet');
    }
    final names = _sheetNames();
    _odsNames = {
      for (var i = 0; i < doc.sheets.length; i++) doc.sheets[i].name: names[i],
    };
    final tables = StringBuffer();
    for (var i = 0; i < doc.sheets.length; i++) {
      tables.write(_table(doc.sheets[i], names[i]));
    }
    final named = _namedExpressions(names);
    final content =
        '$_xmlHeader<office:document-content ${OdsNs.declarations} '
        'office:version="$_version"><office:scripts/>'
        '${styles.fontFaceDeclsXml([defaultFont])}'
        '${styles.automaticStylesXml()}'
        '<office:body><office:spreadsheet>$tables$named'
        '</office:spreadsheet></office:body></office:document-content>';

    final archive = Archive();
    final mime = utf8.encode(OdsNs.mimeType);
    archive.add(ArchiveFile.noCompress('mimetype', mime.length, mime));
    void add(String path, String text) =>
        archive.add(ArchiveFile.bytes(path, utf8.encode(text)));
    add('content.xml', content);
    add('styles.xml', _stylesXml());
    add('meta.xml', _metaXml());
    add('settings.xml', _settingsXml(names));
    for (var i = 0; i < _chartObjects.length; i++) {
      add('Object ${i + 1}/content.xml', _chartObjects[i]);
    }
    add('META-INF/manifest.xml', _manifestXml());
    return ZipEncoder().encodeBytes(archive, modified: modified);
  }

  /// Unique, ODF-valid sheet names (`[]*?:/\` are not allowed).
  List<String> _sheetNames() {
    final taken = <String>{};
    final out = <String>[];
    for (final s in doc.sheets) {
      var n = s.name.replaceAll(RegExp(r'[\[\]\*\?:/\\]'), '_').trim();
      if (n.startsWith("'")) n = '_${n.substring(1)}';
      if (n.isEmpty) n = 'Sheet${out.length + 1}';
      var cand = n;
      var k = 2;
      while (taken.contains(cand.toLowerCase())) {
        cand = '$n ($k)';
        k++;
      }
      taken.add(cand.toLowerCase());
      if (cand != s.name) {
        report.add(
          'sheetRenamed',
          'Sheet "${s.name}" was renamed to "$cand"',
          sheet: s.name,
        );
      }
      out.add(cand);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Tables.

  String _table(IrSheet s, String name) {
    _reportUnsupported(s);
    final b = StringBuffer(
      '<table:table table:name="${OdsXml.attr(name)}" '
      'table:style-name="${styles.tableStyle(hidden: s.hidden, rtl: s.rtl, tabColor: s.tabColor, defaultRowHeight: s.defaultRowHeight, defaultColumnWidth: s.defaultColumnWidth)}">',
    );
    b.write(_shapes(s));
    final nRows = s.usedRows < 1 ? 1 : s.usedRows;
    final nCols = s.usedColumns < 1 ? 1 : s.usedColumns;
    final defaultWidth = s.defaultColumnWidth ?? 100;
    final defaultHeight = s.defaultRowHeight ?? 21;

    // Columns.
    final cols = _RunWriter('table:number-columns-repeated');
    for (var c = 0; c < nCols; c++) {
      final d = s.columns[c] ?? const IrDim();
      final style = styles.columnStyle(d.size ?? defaultWidth);
      final cellStyle = styles.cellStyle(doc.formats[d.format]);
      cols.add(
        '<table:table-column table:style-name="$style"'
            '${d.hidden ? ' table:visibility="collapse"' : ''}'
            ' table:default-cell-style-name="${cellStyle ?? 'Default'}"',
        '/>',
      );
    }
    b.write(cols);

    // Merges: anchors and covered intervals per row.
    final anchors = <(int, int), GridRect>{};
    final covered = <int, List<(int, int)>>{};
    for (final m in s.merges) {
      if (m.isSingleCell) continue;
      anchors[(m.top, m.left)] = m;
      for (var r = m.top; r <= m.bottom; r++) {
        final from = r == m.top ? m.left + 1 : m.left;
        if (from <= m.right) {
          (covered[r] ??= []).add((from, m.right));
        }
      }
    }

    final rows = _RunWriter('table:number-rows-repeated');
    for (var r = 0; r < nRows; r++) {
      final d = s.rows[r] ?? const IrDim();
      final style = styles.rowStyle(
        d.size ?? defaultHeight,
        optimal: d.size == null,
      );
      final cellStyle = d.format == 0
          ? null
          : styles.cellStyle(doc.formats[d.format]);
      final open =
          '<table:table-row table:style-name="$style"'
          '${d.hidden ? ' table:visibility="collapse"' : ''}'
          '${cellStyle == null ? '' : ' table:default-cell-style-name="$cellStyle"'}';
      rows.add(
        open,
        '>${_rowCells(s, r, nCols, anchors, covered[r])}</table:table-row>',
      );
    }
    b
      ..write(rows)
      ..write('</table:table>');
    return b.toString();
  }

  /// Charts as embedded ODF chart objects (08 §23, 11 §6.4); charts that
  /// can't be written are reported.
  String _shapes(IrSheet s) {
    if (s.charts.isEmpty) return '';
    final b = StringBuffer();
    var skipped = 0;
    for (final chart in s.charts) {
      final content = OdsCharts.objectContent(
        chart,
        doc,
        odsSheet: (n) => _odsNames[n] ?? n,
      );
      if (content == null) {
        skipped++;
        continue;
      }
      _chartObjects.add(content);
      final n = _chartObjects.length;
      b.write(OdsCharts.frame(chart, s, './Object $n', n));
    }
    if (skipped > 0) {
      report.add(
        'chart',
        '$skipped chart(s) of types ODS can\'t hold were not exported to ODS',
        sheet: s.name,
      );
    }
    return b.isEmpty ? '' : '<table:shapes>$b</table:shapes>';
  }

  void _reportUnsupported(IrSheet s) {
    void warn(bool present, String code, String what) {
      if (present) {
        report.add(code, '$what were not exported to ODS', sheet: s.name);
      }
    }

    warn(s.validations.isNotEmpty, 'dataValidation', 'Data validation rules');
    warn(
      s.conditionalFormats.isNotEmpty,
      'conditionalFormat',
      'Conditional formatting rules',
    );
    warn(s.autoFilter != null, 'filter', 'Filters');
    warn(s.images.isNotEmpty, 'image', 'Images');
    warn(
      s.rows.entries.any((e) => e.value.outlineLevel > 0) ||
          s.columns.entries.any((e) => e.value.outlineLevel > 0),
      'outlineGroup',
      'Row and column groups',
    );
    warn(s.print != null, 'printSettings', 'Print settings');
  }

  String _rowCells(
    IrSheet s,
    int r,
    int nCols,
    Map<(int, int), GridRect> anchors,
    List<(int, int)>? coveredRanges,
  ) {
    final w = _RunWriter('table:number-columns-repeated');
    final coveredCols = <int>{};
    if (coveredRanges != null) {
      for (final (a, b) in coveredRanges) {
        for (var c = a; c <= b; c++) {
          coveredCols.add(c);
        }
      }
    }
    final positions = <int>{
      for (final (c, _) in s.cells.rowEntries(r)) c,
      ...coveredCols,
    }.toList()..sort();
    var cursor = 0;
    for (final c in positions) {
      if (c >= nCols) break;
      if (c > cursor) w.add('<table:table-cell', '/>', c - cursor);
      final cell = s.cells.get(r, c);
      final (open, rest) = _cell(
        s,
        r,
        c,
        cell,
        covered: coveredCols.contains(c),
        merge: anchors[(r, c)],
      );
      w.add(open, rest);
      cursor = c + 1;
    }
    if (cursor < nCols) w.add('<table:table-cell', '/>', nCols - cursor);
    return w.toString();
  }

  (String, String) _cell(
    IrSheet s,
    int r,
    int c,
    IrCell? cell, {
    required bool covered,
    GridRect? merge,
  }) {
    final tag = covered ? 'table:covered-table-cell' : 'table:table-cell';
    final open = StringBuffer('<$tag');
    if (cell == null) {
      return ('$open', '/>');
    }
    final format = doc.formats[cell.format];
    final styleName = styles.cellStyle(format);
    if (styleName != null) open.write(' table:style-name="$styleName"');
    if (merge != null) {
      if (merge.colCount > 1) {
        open.write(' table:number-columns-spanned="${merge.colCount}"');
      }
      if (merge.rowCount > 1) {
        open.write(' table:number-rows-spanned="${merge.rowCount}"');
      }
    }
    final formula = cell.formulaA1;
    if (formula != null) {
      var f = formula;
      final ref = cell.arrayRef;
      if (cell.formulaKind != IrFormulaKind.normal) {
        final inner = cell.formulaKind == IrFormulaKind.array
            ? _unwrapArrayFormula(f)
            : f;
        if (inner != null && ref != null) {
          f = inner;
          open
            ..write(' table:number-matrix-columns-spanned="${ref.colCount}"')
            ..write(' table:number-matrix-rows-spanned="${ref.rowCount}"');
        }
      }
      open.write(
        ' table:formula="${OdsXml.attr(translator.exportFormula(f))}"',
      );
    }
    final pattern = format[FormatAttr.numberFormat] as String?;
    final value = cell.value;
    String? display;
    switch (value) {
      case null:
        if (formula != null) {
          open.write(' office:value-type="string" calcext:value-type="string"');
        }
      case IrNumber(:final number):
        final info = NumberFormatInfo.of(pattern, locale: locale);
        if (info.isDateLike || info.isTimeLike) {
          open.write(
            info.isDateLike
                ? ' office:value-type="date" office:date-value="${_isoDate(number)}"'
                      ' calcext:value-type="date"'
                : ' office:value-type="time" office:time-value="${_isoDuration(number)}"'
                      ' calcext:value-type="time"',
          );
          if (options.wonkyExtensions) {
            // ISO dates/durations keep milliseconds; the exact serial too.
            open.write(' wonky:value="${CellContent.formatNumber(number)}"');
          }
        } else {
          final type = info.isPercent
              ? 'percentage'
              : info.isCurrency
              ? 'currency'
              : 'float';
          open.write(
            ' office:value-type="$type" office:value="${CellContent.formatNumber(number)}"'
            ' calcext:value-type="$type"',
          );
        }
        display = formatter
            .format(NumberValue(number), pattern, locale: locale)
            .plainText;
      case IrBool(:final value):
        open.write(
          ' office:value-type="boolean" office:boolean-value="$value"'
          ' calcext:value-type="boolean"',
        );
        display = value ? 'TRUE' : 'FALSE';
      case IrError(:final kind):
        open.write(
          formula != null
              ? ' office:value-type="float" office:value="0" calcext:value-type="error"'
              : ' office:value-type="string" calcext:value-type="error"',
        );
        display = kind.literal;
      case IrText() || IrRich():
        open.write(' office:value-type="string" calcext:value-type="string"');
    }
    final body = StringBuffer();
    final note = cell.note;
    if (note != null && note.isNotEmpty) {
      body.write('<office:annotation>');
      for (final line in note.replaceAll('\r\n', '\n').split('\n')) {
        body.write('<text:p>${_inline(line)}</text:p>');
      }
      body.write('</office:annotation>');
    }
    final para = switch (value) {
      IrRich(:final rich) => _richParagraph(rich, cell.link),
      IrText(:final text) => _paragraph(text, cell.link),
      null => null,
      _ => _paragraph(display ?? '', cell.link),
    };
    if (para != null) body.write(para);
    if (body.isEmpty) return ('$open', '/>');
    return ('$open', '>$body</$tag>');
  }

  static String? _unwrapArrayFormula(String f) {
    final t = f.trim();
    if (!t.toUpperCase().startsWith('ARRAYFORMULA(') || !t.endsWith(')')) {
      return null;
    }
    final inner = t.substring(13, t.length - 1);
    var depth = 0;
    for (final tok in FormulaTokenizer.tokenize(inner)) {
      if (tok.kind == FTok.open) depth++;
      if (tok.kind == FTok.close) {
        depth--;
        if (depth < 0) return null;
      }
    }
    return depth == 0 ? inner : null;
  }

  /// `2026-10-14` / `2026-10-14T13:45:00` of a serial.
  static String _isoDate(double serial) {
    final ymd = DateSerial.toYmd(serial);
    String two(int v) => v.toString().padLeft(2, '0');
    final y = ymd.year < 0
        ? '-${(-ymd.year).toString().padLeft(4, '0')}'
        : ymd.year.toString().padLeft(4, '0');
    final date = '$y-${two(ymd.month)}-${two(ymd.day)}';
    final frac = serial - serial.floorToDouble();
    final ms = (frac * 86400000).round();
    if (ms == 0 || ms >= 86400000) return date;
    final h = ms ~/ 3600000;
    final m = (ms ~/ 60000) % 60;
    final s = (ms ~/ 1000) % 60;
    final rest = ms % 1000;
    return '${date}T${two(h)}:${two(m)}:${two(s)}'
        '${rest == 0 ? '' : '.${rest.toString().padLeft(3, '0')}'}';
  }

  /// `PT13H45M00S` (elapsed hours may exceed 24) of a day fraction.
  static String _isoDuration(double days) {
    final neg = days < 0;
    final ms = (days.abs() * 86400000).round();
    final h = ms ~/ 3600000;
    final m = (ms ~/ 60000) % 60;
    final s = (ms ~/ 1000) % 60;
    final rest = ms % 1000;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${neg ? '-' : ''}PT${two(h)}H${two(m)}M${two(s)}'
        '${rest == 0 ? '' : '.${rest.toString().padLeft(3, '0')}'}S';
  }

  // ---------------------------------------------------------------------------
  // Text.

  /// Paragraph text: spaces after a space, at the start or at the end become
  /// `text:s`, tabs `text:tab`, line breaks `text:line-break`.
  static String _inline(String text) {
    final b = StringBuffer();
    final plain = StringBuffer();
    void flush() {
      if (plain.isNotEmpty) b.write(OdsXml.esc(plain.toString()));
      plain.clear();
    }

    var i = 0;
    var prevSpace = true; // paragraph start counts as a space
    while (i < text.length) {
      final ch = text.codeUnitAt(i);
      if (ch == 0x20) {
        var j = i;
        while (j < text.length && text.codeUnitAt(j) == 0x20) {
          j++;
        }
        final n = j - i;
        final atEnd = j >= text.length || _isBreak(text.codeUnitAt(j));
        var literal = 0;
        if (!prevSpace && !atEnd) literal = 1;
        if (literal == 1) plain.write(' ');
        final rest = n - literal;
        if (rest > 0) {
          flush();
          b.write(rest == 1 ? '<text:s/>' : '<text:s text:c="$rest"/>');
        }
        prevSpace = true;
        i = j;
        continue;
      }
      if (ch == 0x09) {
        flush();
        b.write('<text:tab/>');
        prevSpace = false;
      } else if (ch == 0x0a || ch == 0x0d) {
        flush();
        b.write('<text:line-break/>');
        if (ch == 0x0d &&
            i + 1 < text.length &&
            text.codeUnitAt(i + 1) == 0x0a) {
          i++;
        }
        prevSpace = true;
      } else {
        plain.writeCharCode(ch);
        prevSpace = false;
      }
      i++;
    }
    flush();
    return b.toString();
  }

  static bool _isBreak(int c) => c == 0x0a || c == 0x0d;

  String? _href(String? link) {
    if (link == null) return null;
    if (!link.startsWith('#')) return link;
    final ref = link.substring(1);
    final odf = translator.exportFormula(ref);
    final m = RegExp(r'^of:=\[\$?(.*)\]$').firstMatch(odf);
    return m == null ? link : '#${m.group(1)}';
  }

  String _paragraph(String text, String? link) {
    final inner = _inline(text);
    final href = _href(link);
    if (href == null) return '<text:p>$inner</text:p>';
    return '<text:p><text:a xlink:href="${OdsXml.attr(href)}" '
        'xlink:type="simple">$inner</text:a></text:p>';
  }

  String _richParagraph(RichText rich, String? link) {
    final text = rich.text;
    final b = StringBuffer();
    var pos = 0;
    void plain(int end) {
      if (end > pos) b.write(_inline(text.substring(pos, end)));
    }

    for (final run in rich.runs) {
      final s = run.start.clamp(pos, text.length);
      final e = run.end.clamp(s, text.length);
      plain(s);
      pos = s;
      if (e <= s) continue;
      var seg = _inline(text.substring(s, e));
      final style = styles.textStyle(run.format);
      if (style != null) {
        seg = '<text:span text:style-name="$style">$seg</text:span>';
      }
      final href = _href(run.link);
      if (href != null) {
        seg =
            '<text:a xlink:href="${OdsXml.attr(href)}" xlink:type="simple">$seg</text:a>';
      }
      b.write(seg);
      pos = e;
    }
    plain(text.length);
    final href = _href(link);
    if (href == null) return '<text:p>$b</text:p>';
    return '<text:p><text:a xlink:href="${OdsXml.attr(href)}" '
        'xlink:type="simple">$b</text:a></text:p>';
  }

  // ---------------------------------------------------------------------------
  // Names.

  String _namedExpressions(List<String> sheetNames) {
    if (doc.namedRanges.isEmpty) return '';
    String sheetOf(String? name) {
      if (name == null) return sheetNames.first;
      for (var i = 0; i < doc.sheets.length; i++) {
        if (doc.sheets[i].name.toLowerCase() == name.toLowerCase()) {
          return sheetNames[i];
        }
      }
      return name;
    }

    String address(String sheet, IrRange range) {
      final rect = range.toRect(1048576, 16384);
      final a1 = IrRange.rect(rect).toA1(sheet: sheet, absolute: true);
      final odf = translator.exportFormula(a1);
      final m = RegExp(r'^of:=\[(.*)\]$').firstMatch(odf);
      return m?.group(1) ?? a1;
    }

    final b = StringBuffer('<table:named-expressions>');
    for (final n in doc.namedRanges) {
      final sheet = sheetOf(n.sheet);
      final base = address(sheet, IrRange.cell(0, 0));
      final range = n.range;
      if (range != null) {
        b.write(
          '<table:named-range table:name="${OdsXml.attr(n.name)}" '
          'table:base-cell-address="${OdsXml.attr(base)}" '
          'table:cell-range-address="${OdsXml.attr(address(sheet, range))}"/>',
        );
      } else if (n.formulaA1 != null) {
        b.write(
          '<table:named-expression table:name="${OdsXml.attr(n.name)}" '
          'table:base-cell-address="${OdsXml.attr(base)}" '
          'table:expression="${OdsXml.attr(translator.exportFormula(n.formulaA1!))}"/>',
        );
      }
    }
    b.write('</table:named-expressions>');
    return b.toString();
  }

  // ---------------------------------------------------------------------------
  // Other parts.

  String _stylesXml() {
    final text = StringBuffer(
      ' style:font-name="${OdsXml.attr(defaultFont)}" '
      'fo:font-size="${OdsUnits.pt(defaultSize)}"',
    );
    final lang = _language();
    if (lang != null) {
      text.write(' fo:language="${lang.$1}"');
      if (lang.$2 != null) text.write(' fo:country="${lang.$2}"');
    }
    final faces = OdsStyleWriter(
      theme: theme,
      defaultFont: defaultFont,
      defaultSize: defaultSize,
      locale: locale,
    ).fontFaceDeclsXml([defaultFont]);
    return '$_xmlHeader<office:document-styles ${OdsNs.declarations} '
        'office:version="$_version">$faces<office:styles>'
        '<style:default-style style:family="table-cell">'
        '<style:paragraph-properties style:tab-stop-distance="0.5in"/>'
        '<style:text-properties$text/></style:default-style>'
        '<number:number-style style:name="N0"><number:number '
        'number:min-integer-digits="1"/></number:number-style>'
        '<style:style style:name="Default" style:family="table-cell"/>'
        '</office:styles><office:automatic-styles>'
        '<style:page-layout style:name="pm1"><style:page-layout-properties '
        'style:writing-mode="lr-tb"/></style:page-layout>'
        '</office:automatic-styles><office:master-styles>'
        '<style:master-page style:name="Default" style:page-layout-name="pm1"/>'
        '</office:master-styles></office:document-styles>';
  }

  (String, String?)? _language() {
    final parts = locale.split(RegExp('[_-]'));
    if (parts.isEmpty || !RegExp(r'^[a-zA-Z]{2,3}$').hasMatch(parts.first)) {
      return null;
    }
    final country =
        parts.length > 1 && RegExp(r'^[a-zA-Z]{2}$').hasMatch(parts[1])
        ? parts[1].toUpperCase()
        : null;
    return (parts.first.toLowerCase(), country);
  }

  String _metaXml() {
    final t = modified.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final iso =
        '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
        'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}Z';
    final lang = _language();
    final title = doc.title;
    return '$_xmlHeader<office:document-meta ${OdsNs.declarations} '
        'office:version="$_version"><office:meta>'
        '<meta:generator>Wonky Sheets</meta:generator>'
        '${title == null || title.isEmpty ? '' : '<dc:title>${OdsXml.esc(title)}</dc:title>'}'
        '<meta:initial-creator>${OdsXml.esc(options.creator)}</meta:initial-creator>'
        '<meta:creation-date>$iso</meta:creation-date><dc:date>$iso</dc:date>'
        '${lang == null ? '' : '<dc:language>${lang.$1}${lang.$2 == null ? '' : '-${lang.$2}'}</dc:language>'}'
        '</office:meta></office:document-meta>';
  }

  String _settingsXml(List<String> names) {
    String item(String name, String type, Object value) =>
        '<config:config-item config:name="$name" config:type="$type">'
        '$value</config:config-item>';
    final tables = StringBuffer();
    for (var i = 0; i < doc.sheets.length; i++) {
      final s = doc.sheets[i];
      tables.write(
        '<config:config-item-map-entry config:name="${OdsXml.attr(names[i])}">',
      );
      final fc = s.frozenColumns;
      final fr = s.frozenRows;
      tables
        ..write(item('HorizontalSplitMode', 'short', fc > 0 ? 2 : 0))
        ..write(item('VerticalSplitMode', 'short', fr > 0 ? 2 : 0))
        ..write(item('HorizontalSplitPosition', 'int', fc))
        ..write(item('VerticalSplitPosition', 'int', fr))
        ..write(
          item('ActiveSplitRange', 'short', fr > 0 ? 2 : (fc > 0 ? 3 : 2)),
        )
        ..write(item('PositionLeft', 'int', 0))
        ..write(item('PositionRight', 'int', fc))
        ..write(item('PositionTop', 'int', 0))
        ..write(item('PositionBottom', 'int', fr))
        ..write(item('ShowGrid', 'boolean', s.showGridlines))
        ..write('</config:config-item-map-entry>');
    }
    final firstVisible = doc.sheets.indexWhere((s) => !s.hidden);
    final active = names[firstVisible < 0 ? 0 : firstVisible];
    final config = 'xmlns:config="${OdsNs.config}"';
    return '$_xmlHeader<office:document-settings ${OdsNs.declarations} $config '
        'office:version="$_version"><office:settings>'
        '<config:config-item-set config:name="ooo:view-settings">'
        '<config:config-item-map-indexed config:name="Views">'
        '<config:config-item-map-entry>'
        '${item('ViewId', 'string', 'view1')}'
        '<config:config-item-map-named config:name="Tables">$tables'
        '</config:config-item-map-named>'
        '${item('ActiveTable', 'string', OdsXml.esc(active))}'
        '${item('ShowGrid', 'boolean', true)}'
        '</config:config-item-map-entry></config:config-item-map-indexed>'
        '</config:config-item-set></office:settings></office:document-settings>';
  }

  String _manifestXml() {
    String entry(String path, String type) =>
        '<manifest:file-entry manifest:full-path="$path" '
        'manifest:media-type="$type"/>';
    return '$_xmlHeader<manifest:manifest xmlns:manifest="${OdsNs.manifest}" '
        'manifest:version="$_version">'
        '<manifest:file-entry manifest:full-path="/" '
        'manifest:version="$_version" manifest:media-type="${OdsNs.mimeType}"/>'
        '${entry('content.xml', 'text/xml')}'
        '${entry('styles.xml', 'text/xml')}'
        '${entry('meta.xml', 'text/xml')}'
        '${entry('settings.xml', 'text/xml')}'
        '${[for (var i = 1; i <= _chartObjects.length; i++) '${entry('Object $i/', OdsCharts.mediaType)}${entry('Object $i/content.xml', 'text/xml')}'].join()}'
        '</manifest:manifest>';
  }
}
