import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../addressing/grid_geometry.dart';
import '../../format/number_format/number_formatter.dart';
import '../../formula/model/workbook_view.dart';
import '../../model/records.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../../model/workbook_model.dart';
import '../print/cell_display.dart';
import '../print/paginator.dart';
import 'cell_css.dart';
import 'html_escape.dart';

/// Renders a chart as an SVG document of [width] × [height] px
/// (`SvgChartRenderer`, 08 §6.2); null skips the chart.
typedef ChartSvgProvider =
    String? Function(EmbeddedObjectRecord chart, double width, double height);

/// Image bytes of an image object; null skips the image.
typedef HtmlImageProvider = HtmlImage? Function(EmbeddedObjectRecord image);

/// Encoded image for the HTML export.
final class HtmlImage {
  /// Creates an image.
  const HtmlImage(this.bytes, this.mimeType);

  final Uint8List bytes;

  /// `image/png`, `image/jpeg`, `image/gif`, `image/webp`, `image/svg+xml`.
  final String mimeType;

  /// File extension for [mimeType].
  String get extension => switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/svg+xml' => 'svg',
    'image/bmp' => 'bmp',
    _ => 'png',
  };
}

/// HTML export (11 §6.6): a zip with `index.html` (sheet links), one page per
/// visible sheet and `resources/` with images and charts as SVG. Always the
/// light theme.
abstract final class HtmlExporter {
  /// Gridline color when the sheet shows gridlines.
  static const String gridlineColor = '#e0e0e0';

  /// Exports [model] (values from [source]). [includeHidden] also exports
  /// hidden sheets, rows and columns. [modified] sets the zip entry times
  /// (deterministic output).
  static Uint8List export(
    WorkbookModel model,
    CellSource source, {
    String? locale,
    ChartSvgProvider? charts,
    HtmlImageProvider? images,
    ConditionalOverlayProvider? conditional,
    bool includeHidden = false,
    DateTime? modified,
    NumberFormatter? formatter,
  }) {
    final files = exportFiles(
      model,
      source,
      locale: locale,
      charts: charts,
      images: images,
      conditional: conditional,
      includeHidden: includeHidden,
      formatter: formatter,
    );
    final archive = Archive();
    final time = modified ?? DateTime.utc(2000);
    for (final e in files.entries) {
      final f = ArchiveFile.bytes(e.key, e.value)
        ..lastModTime = time.millisecondsSinceEpoch ~/ 1000;
      archive.addFile(f);
    }
    return ZipEncoder().encodeBytes(archive, modified: time);
  }

  /// The exported files by path (`index.html`, `<sheet>.html`, `resources/…`).
  static Map<String, Uint8List> exportFiles(
    WorkbookModel model,
    CellSource source, {
    String? locale,
    ChartSvgProvider? charts,
    HtmlImageProvider? images,
    ConditionalOverlayProvider? conditional,
    bool includeHidden = false,
    NumberFormatter? formatter,
  }) {
    final sheets = includeHidden ? model.sheets : model.visibleSheets;
    final names = <String, String>{};
    final used = <String>{'index.html'};
    for (var i = 0; i < sheets.length; i++) {
      names[sheets[i].id] = _fileName(sheets[i].name, i, used);
    }
    final resolver = CellDisplayResolver(
      model,
      source,
      locale: locale,
      conditional: conditional,
      formatter: formatter,
    );
    final out = <String, Uint8List>{};
    final title = model.spreadsheet.title.isEmpty
        ? 'Spreadsheet'
        : model.spreadsheet.title;
    out['index.html'] = _utf8(_index(title, sheets, names));
    for (final s in sheets) {
      final page = _SheetPage(
        model: model,
        sheet: s,
        resolver: resolver,
        includeHidden: includeHidden,
        fileNames: names,
        title: title,
        charts: charts,
        images: images,
        resources: out,
      );
      out[names[s.id]!] = _utf8(page.render(sheets));
    }
    return out;
  }

  static Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

  static String _fileName(String name, int index, Set<String> used) {
    var base = name
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    if (base.length > 80) base = base.substring(0, 80);
    if (base.isEmpty) base = 'sheet-${index + 1}';
    var candidate = '$base.html';
    var n = 2;
    while (used.contains(candidate.toLowerCase())) {
      candidate = '$base-${n++}.html';
    }
    used.add(candidate.toLowerCase());
    return candidate;
  }

  static const String _css =
      'body{margin:0;background:#ffffff;color:#000000;font-family:Inter,Arial,sans-serif}'
      'nav{padding:8px 12px;border-bottom:1px solid #e0e0e0;font-size:13px}'
      'nav a{margin-right:12px;color:#1155cc;text-decoration:none}'
      'nav a.current{font-weight:bold;color:#000000}'
      '.sheet{position:relative;display:inline-block;margin:12px}'
      'table.grid{border-collapse:collapse;table-layout:fixed;background:#ffffff}'
      'table.grid td{box-sizing:border-box}'
      '.obj{position:absolute;display:block}'
      'ul.sheets{font-size:15px;line-height:1.8}';

  static String _index(
    String title,
    List<SheetModel> sheets,
    Map<String, String> names,
  ) {
    final b = StringBuffer()
      ..write('<!DOCTYPE html><html><head><meta charset="utf-8">')
      ..write('<meta name="generator" content="Wonky Sheets">')
      ..write(
        '<title>${HtmlText.escape(title)}</title><style>$_css</style></head><body>',
      )
      ..write(
        '<nav><strong>${HtmlText.escape(title)}</strong></nav><ul class="sheets">',
      );
    for (final s in sheets) {
      b.write(
        '<li><a href="${HtmlText.attr(names[s.id]!)}">${HtmlText.escape(s.name)}</a></li>',
      );
    }
    b.write('</ul></body></html>');
    return b.toString();
  }
}

final class _SheetPage {
  _SheetPage({
    required this.model,
    required this.sheet,
    required this.resolver,
    required this.includeHidden,
    required this.fileNames,
    required this.title,
    required this.charts,
    required this.images,
    required this.resources,
  });

  final WorkbookModel model;
  final SheetModel sheet;
  final CellDisplayResolver resolver;
  final bool includeHidden;
  final Map<String, String> fileNames;
  final String title;
  final ChartSvgProvider? charts;
  final HtmlImageProvider? images;
  final Map<String, Uint8List> resources;

  bool _hiddenRow(int r) =>
      !includeHidden && Paginator.hiddenForPrint(sheet.rows, r);
  bool _hiddenCol(int c) =>
      !includeHidden && Paginator.hiddenForPrint(sheet.columns, c);

  String? _href(String url) {
    final m = RegExp(r'^#sheet=([^&]+)').firstMatch(url.trim());
    if (m != null) {
      final f = fileNames[m.group(1)!];
      return f;
    }
    return HtmlText.safeUrl(url);
  }

  String render(List<SheetModel> all) {
    final b = StringBuffer()
      ..write('<!DOCTYPE html><html><head><meta charset="utf-8">')
      ..write('<meta name="generator" content="Wonky Sheets">')
      ..write('<title>${HtmlText.escape('${sheet.name} – $title')}</title>')
      ..write('<style>${HtmlExporter._css}</style></head><body><nav>')
      ..write('<a href="index.html">${HtmlText.escape(title)}</a>');
    for (final s in all) {
      final cls = s.id == sheet.id ? ' class="current"' : '';
      b.write(
        '<a$cls href="${HtmlText.attr(fileNames[s.id]!)}">${HtmlText.escape(s.name)}</a>',
      );
    }
    b.write('</nav><div class="sheet">');
    if (sheet.record?.kind == SheetKind.chart) {
      _objects(b, const [], const [], chartSheet: true);
    } else {
      _table(b);
    }
    b.write('</div></body></html>');
    return b.toString();
  }

  void _table(StringBuffer b) {
    final range = Paginator.usedRange(sheet);
    if (range == null) {
      b.write('<p>This sheet is empty.</p>');
      return;
    }
    final rows = [
      for (var r = range.top; r <= range.bottom; r++)
        if (!_hiddenRow(r)) r,
    ];
    final cols = [
      for (var c = range.left; c <= range.right; c++)
        if (!_hiddenCol(c)) c,
    ];
    if (rows.isEmpty || cols.isEmpty) {
      b.write('<p>This sheet is empty.</p>');
      return;
    }
    final rowPos = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    final colPos = {for (var i = 0; i < cols.length; i++) cols[i]: i};
    final covered = <(int, int)>{};
    final spans = <(int, int), (int, int, GridRect)>{};
    for (final (_, m) in sheet.mergesIntersecting(range)) {
      final pr = [
        for (var i = 0; i < rows.length; i++)
          if (rows[i] >= m.top && rows[i] <= m.bottom) i,
      ];
      final pc = [
        for (var i = 0; i < cols.length; i++)
          if (cols[i] >= m.left && cols[i] <= m.right) i,
      ];
      if (pr.isEmpty || pc.isEmpty || (pr.length == 1 && pc.length == 1)) {
        continue;
      }
      if (spans.containsKey((pr.first, pc.first)) ||
          covered.contains((pr.first, pc.first))) {
        continue;
      }
      spans[(pr.first, pc.first)] = (pr.length, pc.length, m);
      for (final i in pr) {
        for (final j in pc) {
          if (i != pr.first || j != pc.first) covered.add((i, j));
        }
      }
    }
    final theme = model.theme;
    final ss = model.spreadsheet;
    final defaultFont = theme.textFont.isNotEmpty
        ? theme.textFont
        : ss.defaultFontFamily;
    final defaultSize = ss.defaultFontSize;
    final gridline = sheet.record?.showGridlines ?? true
        ? HtmlExporter.gridlineColor
        : null;
    var width = 0.0;
    for (final c in cols) {
      width += sheet.columns.naturalSizeAt(c);
    }
    b
      ..write('<table class="grid" cellspacing="0" cellpadding="0" ')
      ..write('dir="${sheet.record?.rightToLeft == true ? 'rtl' : 'ltr'}" ')
      ..write('style="width:${HtmlText.num(width)}px;font-family:')
      ..write('${HtmlText.attr(HtmlText.cssFontFamily(defaultFont))};')
      ..write('font-size:${HtmlText.num(defaultSize)}pt"><colgroup>');
    for (final c in cols) {
      b.write(
        '<col style="width:${HtmlText.num(sheet.columns.naturalSizeAt(c))}px">',
      );
    }
    b.write('</colgroup><tbody>');
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      b.write(
        '<tr style="height:${HtmlText.num(sheet.rows.naturalSizeAt(r))}px">',
      );
      for (var j = 0; j < cols.length; j++) {
        if (covered.contains((i, j))) continue;
        final c = cols[j];
        final span = spans[(i, j)];
        final m = span?.$3;
        final row = m?.top ?? r;
        final col = m?.left ?? c;
        final d = resolver.display(sheet.id, row, col);
        final edges = resolver.edges(
          sheet.id,
          row,
          col,
          bottomRow: m?.bottom,
          rightCol: m?.right,
        );
        var overflow = false;
        if (m == null &&
            d.format.wrap == WrapStrategy.overflow &&
            d.text.isNotEmpty &&
            !d.numberLike) {
          bool empty(int jj) =>
              jj >= 0 &&
              jj < cols.length &&
              !covered.contains((i, jj)) &&
              !spans.containsKey((i, jj)) &&
              !resolver.hasContent(sheet.id, r, cols[jj]);
          overflow = switch (d.hAlign) {
            HorizontalAlign.left => empty(j + 1),
            HorizontalAlign.right => empty(j - 1),
            HorizontalAlign.center => empty(j - 1) && empty(j + 1),
          };
        }
        final style = CellCss.style(
          d,
          theme: theme,
          defaultFont: defaultFont,
          defaultSize: defaultSize,
          edges: edges,
          gridline: gridline,
          overflowVisible: overflow,
        );
        b.write('<td');
        if (span != null) {
          if (span.$2 > 1) b.write(' colspan="${span.$2}"');
          if (span.$1 > 1) b.write(' rowspan="${span.$1}"');
        }
        b.write(' style="${HtmlText.attr(style)}">');
        if (d.widget.kind == CellWidgetKind.checkbox) {
          b.write(d.widget.checked ? '&#9745;' : '&#9744;');
        } else {
          b.write(CellCss.body(d, theme, href: _href));
        }
        b.write('</td>');
      }
      b.write('</tr>');
    }
    b.write('</tbody></table>');
    _objects(b, rows, cols, rowPos: rowPos, colPos: colPos);
  }

  double _offset(List<int> visible, int index, bool isRow) {
    var acc = 0.0;
    for (final v in visible) {
      if (v >= index) break;
      acc += isRow
          ? sheet.rows.naturalSizeAt(v)
          : sheet.columns.naturalSizeAt(v);
    }
    return acc;
  }

  void _objects(
    StringBuffer b,
    List<int> rows,
    List<int> cols, {
    Map<int, int>? rowPos,
    Map<int, int>? colPos,
    bool chartSheet = false,
  }) {
    final objs = sheet.objects.values.toList()
      ..sort((a, c) {
        final z = a.zIndex.compareTo(c.zIndex);
        return z != 0 ? z : a.id.compareTo(c.id);
      });
    for (final o in objs) {
      final p = PrintObjectPlacement.of(sheet, o);
      if (p == null) continue;
      final String style;
      if (chartSheet || p.ownSheet) {
        style =
            'position:relative;width:${HtmlText.num(p.width)}px;height:${HtmlText.num(p.height)}px';
      } else {
        final x = _offset(cols, p.col, false) + (_hiddenCol(p.col) ? 0 : p.dx);
        final y = _offset(rows, p.row, true) + (_hiddenRow(p.row) ? 0 : p.dy);
        style =
            'left:${HtmlText.num(x)}px;top:${HtmlText.num(y)}px;'
            'width:${HtmlText.num(p.width)}px;height:${HtmlText.num(p.height)}px';
      }
      String? path;
      if (o.kind == EmbeddedObjectKind.chart) {
        final svg = charts?.call(o, p.width, p.height);
        if (svg != null) {
          path = 'resources/${_safeId(o.id)}.svg';
          resources[path] = Uint8List.fromList(utf8.encode(svg));
        }
      } else if (o.kind == EmbeddedObjectKind.image) {
        final img = images?.call(o);
        if (img != null) {
          path = 'resources/${_safeId(o.id)}.${img.extension}';
          resources[path] = img.bytes;
        }
      }
      if (path == null) continue;
      final alt = o.altText ?? o.title ?? '';
      b.write(
        '<img class="obj" src="${HtmlText.attr(path)}" alt="${HtmlText.attr(alt)}" '
        'style="${HtmlText.attr(style)}">',
      );
    }
  }

  static String _safeId(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}
