import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
// The pdf package's PdfString is needed to set a deterministic creation date.
// ignore: implementation_imports
import 'package:pdf/src/priv.dart' show PdfString;
// vector_math is a dependency of `pdf` and part of `PdfGraphics.setTransform`.
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../../addressing/column_letters.dart';
import '../../charts/render/pdf/pdf_chart_renderer.dart';
import '../../charts/scene/geometry.dart';
import '../../charts/scene/scene.dart';
import '../../addressing/grid_geometry.dart';
import '../../format/attributes.dart';
import '../../format/borders.dart';
import '../../format/number_format/number_formatter.dart';
import '../../formula/model/workbook_view.dart';
import '../../model/records.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../../model/workbook_model.dart';
import 'cell_display.dart';
import 'cell_text_layout.dart';
import 'header_footer.dart';
import 'paginator.dart';
import 'pdf_fonts.dart';
import 'print_settings.dart';

/// Draws a chart (vector) into a PDF page (08 §6.2 `PdfChartRenderer`).
abstract interface class ChartPdfDrawer {
  /// Draws [chart] into [bounds] (PDF points, origin bottom-left). The
  /// graphics state is clipped to the visible part of the chart.
  void drawChart(
    PdfDocument doc,
    PdfGraphics g,
    EmbeddedObjectRecord chart,
    PdfRect bounds,
  );
}

/// [ChartPdfDrawer] over chart scenes: [sceneFor] lays a chart out at the
/// given size (px = pt; `ChartLayoutEngine.layout`) and the scene is drawn with
/// [PdfChartRenderer], scaled to the bounds.
final class SceneChartPdfDrawer implements ChartPdfDrawer {
  /// Creates the drawer.
  const SceneChartPdfDrawer(
    this.sceneFor, {
    this.renderer = const PdfChartRenderer(),
  });

  /// The chart's scene for a size in points; null skips the chart.
  final ChartScene? Function(
    EmbeddedObjectRecord chart,
    double width,
    double height,
  )
  sceneFor;
  final PdfChartRenderer renderer;

  @override
  void drawChart(
    PdfDocument doc,
    PdfGraphics g,
    EmbeddedObjectRecord chart,
    PdfRect bounds,
  ) {
    final scene = sceneFor(chart, bounds.width, bounds.height);
    if (scene == null || scene.width <= 0) return;
    renderer.draw(
      scene,
      g,
      offset: ChartPoint(bounds.left, bounds.bottom + bounds.height),
      scale: bounds.width / scene.width,
    );
  }
}

/// Encoded image bytes (PNG, JPEG, GIF, WebP, BMP) of an image object.
final class PrintImage {
  /// Creates an image.
  const PrintImage(this.bytes);

  final Uint8List bytes;
}

/// Supplies image bytes for image objects (fetched from storage).
typedef PrintImageProvider = PrintImage? Function(EmbeddedObjectRecord image);

/// Renders paginated sheets to PDF with the `pdf` package (11 §7.4). Pure
/// Dart; the same output on client and server for the same fonts.
abstract final class SheetsPdfRenderer {
  /// Builds the PDF document for [pagination] and returns its bytes.
  ///
  /// [now] is the instant for `{date}`/`{time}` and the creation date
  /// (formatted in [timeZone], default the spreadsheet time zone).
  /// [compress] = false writes uncompressed streams (debugging, tests).
  static Future<Uint8List> render(
    WorkbookModel model,
    CellSource source,
    PaginationResult pagination, {
    required DateTime now,
    PdfFontProvider fonts = const BuiltInPdfFontProvider(),
    String? locale,
    String? title,
    String? author,
    String? timeZone,
    Duration Function(String? timeZone, DateTime utc)? utcOffset,
    ChartPdfDrawer? charts,
    PrintImageProvider? images,
    ConditionalOverlayProvider? conditional,
    NumberFormatter? formatter,
    bool compress = true,
  }) {
    final doc = buildDocument(
      model,
      source,
      pagination,
      now: now,
      fonts: fonts,
      locale: locale,
      title: title,
      author: author,
      timeZone: timeZone,
      utcOffset: utcOffset,
      charts: charts,
      images: images,
      conditional: conditional,
      formatter: formatter,
      compress: compress,
    );
    return doc.save();
  }

  /// Builds the [PdfDocument] (for previews that rasterize single pages).
  static PdfDocument buildDocument(
    WorkbookModel model,
    CellSource source,
    PaginationResult pagination, {
    required DateTime now,
    PdfFontProvider fonts = const BuiltInPdfFontProvider(),
    String? locale,
    String? title,
    String? author,
    String? timeZone,
    Duration Function(String? timeZone, DateTime utc)? utcOffset,
    ChartPdfDrawer? charts,
    PrintImageProvider? images,
    ConditionalOverlayProvider? conditional,
    NumberFormatter? formatter,
    bool compress = true,
  }) {
    final loc = locale ?? model.spreadsheet.locale;
    final docTitle = title ?? model.spreadsheet.title;
    final doc = PdfDocument(compress: compress);
    final info = PdfInfo(
      doc,
      title: docTitle,
      author: author,
      creator: 'Wonky Sheets',
      producer: 'Wonky Sheets',
    );
    info.params['/CreationDate'] = PdfString.fromDate(now.toUtc());
    final (date, time) = PrintDateTime.format(
      now,
      locale: loc,
      timeZone: timeZone ?? model.spreadsheet.timeZone,
      utcOffset: utcOffset,
    );
    final r = _Renderer(
      model: model,
      doc: doc,
      fonts: fonts,
      measurer: PdfFontMeasurer(fonts, doc),
      resolver: CellDisplayResolver(
        model,
        source,
        locale: loc,
        conditional: conditional,
        formatter: formatter,
      ),
      charts: charts,
      images: images,
      title: docTitle,
      date: date,
      time: time,
    );
    final pages = [
      for (final p in pagination.pages)
        PdfPage(doc, pageFormat: PdfPageFormat(p.pageWidth, p.pageHeight)),
    ];
    for (var i = 0; i < pages.length; i++) {
      doc.pdfNames.addDest('wonky-page-${i + 1}', pages[i]);
    }
    r.pages = pagination.pages;
    for (var i = 0; i < pages.length; i++) {
      r.drawPage(pages[i], pagination.pages[i]);
    }
    return doc;
  }
}

/// Visual constants of print (light paper).
abstract final class _Ink {
  static const black = PdfColor(0, 0, 0);
  static const gridline = PdfColor(0xD0 / 255, 0xD0 / 255, 0xD0 / 255);
  static const headingFill = PdfColor(0xF8 / 255, 0xF9 / 255, 0xFA / 255);
  static const headingLine = PdfColor(0xC0 / 255, 0xC0 / 255, 0xC0 / 255);
  static const headingText = PdfColor(0x5F / 255, 0x63 / 255, 0x68 / 255);
  static const checkbox = PdfColor(0x1A / 255, 0x73 / 255, 0xE8 / 255);
  static const checkboxOutline = PdfColor(0x5F / 255, 0x63 / 255, 0x68 / 255);
  static const chipFill = PdfColor(0xE8 / 255, 0xEA / 255, 0xED / 255);
  static const chipText = PdfColor(0x20 / 255, 0x21 / 255, 0x24 / 255);
  static const white = PdfColor(1, 1, 1);

  static PdfColor hex(String hex) {
    final v = int.parse(hex.substring(1), radix: 16);
    return PdfColor(
      ((v >> 16) & 0xff) / 255,
      ((v >> 8) & 0xff) / 255,
      (v & 0xff) / 255,
    );
  }
}

/// One row or column slot on a page.
final class _Slot {
  _Slot(this.index, this.pos, this.size, this.region);

  /// Sheet index.
  final int index;

  /// Offset from the content origin (px).
  final double pos;
  final double size;

  /// 0 = repeated, 1 = body.
  final int region;
}

final class _Renderer {
  _Renderer({
    required this.model,
    required this.doc,
    required this.fonts,
    required this.measurer,
    required this.resolver,
    required this.charts,
    required this.images,
    required this.title,
    required this.date,
    required this.time,
  });

  final WorkbookModel model;
  final PdfDocument doc;
  final PdfFontProvider fonts;
  final PdfFontMeasurer measurer;
  final CellDisplayResolver resolver;
  final ChartPdfDrawer? charts;
  final PrintImageProvider? images;
  final String title;
  final String date;
  final String time;
  List<PageSpec> pages = const [];

  final Map<String, PdfImage?> _imageCache = {};
  final Map<String, Float64List> _prefixCache = {};

  // Page state.
  late PdfGraphics g;
  late PdfPage page;
  late PageSpec spec;
  late double k; // pt per px
  late double ox; // content origin, pt from left
  late double oy; // content origin, pt from top

  double get pageH => spec.pageHeight;

  // px (content coordinates, y down) → pdf points.
  double px(double x) => ox + x * k;
  double py(double y) => pageH - (oy + y * k);

  void rectPx(double x, double y, double w, double h) =>
      g.drawRect(px(x), py(y + h), w * k, h * k);

  void drawPage(PdfPage pdfPage, PageSpec s) {
    page = pdfPage;
    spec = s;
    g = pdfPage.getGraphics();
    k = 0.75 * s.scale;
    ox = s.originX;
    oy = s.originY;
    _headerFooter();
    switch (s.kind) {
      case PageKind.cells:
        _cellsPage();
      case PageKind.chart:
        _chartPage();
      case PageKind.notes:
        _notesPage();
      case PageKind.blank:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Header and footer.

  String get _defaultFamily {
    final t = model.theme.textFont;
    return t.isNotEmpty ? t : model.spreadsheet.defaultFontFamily;
  }

  void _headerFooter() {
    final hf = spec.settings.headerFooter;
    final ctx = HeaderFooterContext(
      page: spec.pageNumber,
      pages: spec.totalPages,
      title: title,
      sheet: spec.sheetName,
      date: date,
      time: time,
    );
    const size = PrintMetrics.headerFooterFontPt;
    final style = CellTextStyle(family: _defaultFamily, size: size);
    final left = spec.settings.margins.leftPt;
    final right = spec.pageWidth - spec.settings.margins.rightPt;
    void band(HeaderFooterSections sec, double topPt, double height) {
      if (sec.isEmpty || height <= 0) return;
      final baseline =
          topPt +
          height / 2 +
          (measurer.ascent(style) - measurer.descent(style)) / 2;
      final y = pageH - baseline;
      final l = HeaderFooterTokens.render(sec.left, ctx);
      final c = HeaderFooterTokens.render(sec.center, ctx);
      final r = HeaderFooterTokens.render(sec.right, ctx);
      if (l.isNotEmpty) _drawPlain(l, style, left, y, _Ink.black);
      if (c.isNotEmpty) {
        _drawPlain(
          c,
          style,
          (left + right) / 2 - measurer.width(c, style) / 2,
          y,
          _Ink.black,
        );
      }
      if (r.isNotEmpty) {
        _drawPlain(r, style, right - measurer.width(r, style), y, _Ink.black);
      }
    }

    band(hf.effectiveHeader, spec.settings.margins.topPt, spec.headerHeight);
    band(
      hf.effectiveFooter,
      spec.pageHeight - spec.settings.margins.bottomPt - spec.footerHeight,
      spec.footerHeight,
    );
  }

  /// Draws [text] (size in points) at pdf coordinates with glyph fallback.
  void _drawPlain(
    String text,
    CellTextStyle style,
    double x,
    double y,
    PdfColor color,
  ) {
    g.setFillColor(color);
    var cx = x;
    for (final run in measurer.runs(text, style)) {
      g.drawString(run.font, style.size, run.text, cx, y);
      cx += run.font.stringMetrics(run.text).advanceWidth * style.size;
    }
  }

  // ---------------------------------------------------------------------------
  // Cells.

  void _cellsPage() {
    final sheet = model.sheet(spec.sheetId);
    if (sheet == null) return;
    final headW = spec.headings ? PrintMetrics.headingWidthPx : 0.0;
    final headH = spec.headings ? PrintMetrics.headingHeightPx : 0.0;
    final cols = <_Slot>[];
    var x = headW;
    for (var i = 0; i < spec.repeatCols.length; i++) {
      cols.add(_Slot(spec.repeatCols[i], x, spec.repeatColWidthsPx[i], 0));
      x += spec.repeatColWidthsPx[i];
    }
    for (var i = 0; i < spec.cols.length; i++) {
      cols.add(_Slot(spec.cols[i], x, spec.colWidthsPx[i], 1));
      x += spec.colWidthsPx[i];
    }
    final rows = <_Slot>[];
    var y = headH;
    for (var i = 0; i < spec.repeatRows.length; i++) {
      rows.add(_Slot(spec.repeatRows[i], y, spec.repeatRowHeightsPx[i], 0));
      y += spec.repeatRowHeightsPx[i];
    }
    for (var i = 0; i < spec.rows.length; i++) {
      rows.add(_Slot(spec.rows[i], y, spec.rowHeightsPx[i], 1));
      y += spec.rowHeightsPx[i];
    }
    final totalW = x;
    final totalH = y;

    // Clip everything to the printable area.
    g.saveContext();
    g.drawRect(
      spec.printableLeft,
      pageH - spec.printableTop - spec.printableHeight,
      spec.printableWidth,
      spec.printableHeight,
    );
    g.clipPath();

    final colPos = {for (var i = 0; i < cols.length; i++) cols[i].index: i};
    final rowPos = {for (var i = 0; i < rows.length; i++) rows[i].index: i};

    // Logical cells: merges (visible part) and plain cells.
    final cells = <_Logical>[];
    final covered = <(int, int)>{};
    if (rows.isNotEmpty && cols.isNotEmpty) {
      final minR = rows.map((r) => r.index).reduce(math.min);
      final maxR = rows.map((r) => r.index).reduce(math.max);
      final minC = cols.map((c) => c.index).reduce(math.min);
      final maxC = cols.map((c) => c.index).reduce(math.max);
      final seen = <String>{};
      for (final (id, m) in sheet.mergesIntersecting(
        GridRect(minR, minC, maxR, maxC),
      )) {
        if (!seen.add(id) || m.isSingleCell) continue;
        // Page positions inside the merge, per region (merges don't cross
        // the frozen boundary; take the region with the most cells).
        final pr = [
          for (var i = 0; i < rows.length; i++)
            if (rows[i].index >= m.top && rows[i].index <= m.bottom) i,
        ];
        final pc = [
          for (var i = 0; i < cols.length; i++)
            if (cols[i].index >= m.left && cols[i].index <= m.right) i,
        ];
        if (pr.isEmpty || pc.isEmpty) continue;
        final firstRow = _firstPrinted(sheet, true, m.top, m.bottom);
        final firstCol = _firstPrinted(sheet, false, m.left, m.right);
        final showContent =
            rowPos[firstRow] != null && colPos[firstCol] != null;
        for (final i in pr) {
          for (final j in pc) {
            covered.add((i, j));
          }
        }
        cells.add(
          _Logical(
            pr.first,
            pc.first,
            pr.last,
            pc.last,
            m.top,
            m.left,
            merge: m,
            showContent: showContent,
          ),
        );
      }
    }
    for (var i = 0; i < rows.length; i++) {
      for (var j = 0; j < cols.length; j++) {
        if (covered.contains((i, j))) continue;
        cells.add(_Logical(i, j, i, j, rows[i].index, cols[j].index));
      }
    }
    final displays = <_Logical, CellDisplay>{};
    for (final c in cells) {
      displays[c] = resolver.display(sheet.id, c.row, c.col);
    }
    final mergedPos = <(int, int)>{
      for (final c in cells)
        if (c.merge != null)
          for (var i = c.r0; i <= c.r1; i++)
            for (var j = c.c0; j <= c.c1; j++) (i, j),
    };

    _Rect rectOf(_Logical c) => _Rect(
      cols[c.c0].pos,
      rows[c.r0].pos,
      cols[c.c1].pos + cols[c.c1].size - cols[c.c0].pos,
      rows[c.r1].pos + rows[c.r1].size - rows[c.r0].pos,
    );

    // 1. Fills, data bars.
    for (final c in cells) {
      final d = displays[c]!;
      final r = rectOf(c);
      if (d.fillColor != null) {
        g.setFillColor(_Ink.hex(d.fillColor!));
        rectPx(r.x, r.y, r.w, r.h);
        g.fillPath();
      }
      final bar = d.conditional?.dataBarFraction;
      if (bar != null && bar > 0) {
        final color =
            model.theme.resolveColor(d.conditional!.dataBarColor) ?? '#638EC6';
        g.setFillColor(_Ink.hex(color));
        final start = d.conditional!.dataBarStart.clamp(0.0, 1.0);
        final innerW = r.w - 2;
        rectPx(
          r.x + 1 + innerW * start,
          r.y + 2,
          innerW * bar.clamp(0.0, 1.0 - start),
          r.h - 4,
        );
        g.fillPath();
      }
    }

    // 2. Gridlines (under borders, never across merges).
    if (spec.settings.gridlines) {
      g.setStrokeColor(_Ink.gridline);
      g.setLineWidth(0.5);
      for (final c in cells) {
        final r = rectOf(c);
        rectPx(r.x, r.y, r.w, r.h);
        g.strokePath();
      }
    }

    // 3. Borders.
    for (final c in cells) {
      final r = rectOf(c);
      final e = resolver.edges(
        sheet.id,
        c.row,
        c.col,
        bottomRow: c.merge?.bottom,
        rightCol: c.merge?.right,
      );
      if (c.merge != null) {
        // Per-segment edges of merged areas (06 §8.5).
        for (var j = c.c0; j <= c.c1; j++) {
          final col = cols[j].index;
          final top = c.merge!.top == rows[c.r0].index
              ? _edgeTop(sheet.id, c.merge!.top, col)
              : null;
          final bottom = c.merge!.bottom == rows[c.r1].index
              ? _edgeBelow(sheet.id, c.merge!.bottom, col)
              : null;
          if (top != null) {
            _hLine(top, cols[j].pos, cols[j].pos + cols[j].size, r.y);
          }
          if (bottom != null) {
            _hLine(bottom, cols[j].pos, cols[j].pos + cols[j].size, r.y + r.h);
          }
        }
        for (var i = c.r0; i <= c.r1; i++) {
          final row = rows[i].index;
          final left = c.merge!.left == cols[c.c0].index
              ? _edgeLeft(sheet.id, row, c.merge!.left)
              : null;
          final right = c.merge!.right == cols[c.c1].index
              ? _edgeRight(sheet.id, row, c.merge!.right)
              : null;
          if (left != null) {
            _vLine(left, r.x, rows[i].pos, rows[i].pos + rows[i].size);
          }
          if (right != null) {
            _vLine(right, r.x + r.w, rows[i].pos, rows[i].pos + rows[i].size);
          }
        }
        continue;
      }
      final prevRowAdj =
          c.r0 > 0 &&
          rows[c.r0 - 1].index == c.row - 1 &&
          !mergedPos.contains((c.r0 - 1, c.c0));
      final prevColAdj =
          c.c0 > 0 &&
          cols[c.c0 - 1].index == c.col - 1 &&
          !mergedPos.contains((c.r0, c.c0 - 1));
      if (!prevRowAdj && e.top != null) _hLine(e.top!, r.x, r.x + r.w, r.y);
      if (!prevColAdj && e.left != null) _vLine(e.left!, r.x, r.y, r.y + r.h);
      if (e.bottom != null) _hLine(e.bottom!, r.x, r.x + r.w, r.y + r.h);
      if (e.right != null) _vLine(e.right!, r.x + r.w, r.y, r.y + r.h);
    }

    // 4. Text and widgets.
    for (final c in cells) {
      final d = displays[c]!;
      if (!c.showContent) continue;
      if (d.widget.kind == CellWidgetKind.none && d.text.isEmpty) continue;
      final r = rectOf(c);
      double? neighbour(int dir, int step) {
        final j = c.c0 + dir * step;
        if (dir > 0 && c.c1 + step >= cols.length) return null;
        final jj = dir > 0 ? c.c1 + step : j;
        if (jj < 0 || jj >= cols.length) return null;
        if (cols[jj].region != cols[c.c0].region) return null;
        if (c.r0 != c.r1) return null;
        if (mergedPos.contains((c.r0, jj))) return null;
        if (resolver.hasContent(sheet.id, c.row, cols[jj].index)) return null;
        return cols[jj].size;
      }

      _drawCell(sheet, d, r, (s) => neighbour(-1, s), (s) => neighbour(1, s));
    }

    // 5. Headings.
    if (spec.headings) _headings(rows, cols, headW, headH, totalW, totalH);

    // 6. Objects.
    _objects(sheet, rows, cols);
    g.restoreContext();
  }

  int _firstPrinted(SheetModel s, bool rows, int a, int b) {
    final axis = rows ? s.rows : s.columns;
    for (var i = a; i <= b; i++) {
      if (!Paginator.hiddenForPrint(axis, i)) return i;
    }
    return a;
  }

  BorderSpec? _vis(BorderSpec? s) => s == null || s.isNone ? null : s;

  BorderSpec? _edgeTop(String sheetId, int row, int col) => _vis(
    row > 0
        ? resolver.formats.edgeBelow(sheetId, row - 1, col)
        : resolver.formats.outerEdge(sheetId, row, col, FormatAttr.borderTop),
  );

  BorderSpec? _edgeBelow(String sheetId, int row, int col) =>
      _vis(resolver.formats.edgeBelow(sheetId, row, col));

  BorderSpec? _edgeLeft(String sheetId, int row, int col) => _vis(
    col > 0
        ? resolver.formats.edgeRight(sheetId, row, col - 1)
        : resolver.formats.outerEdge(sheetId, row, col, FormatAttr.borderLeft),
  );

  BorderSpec? _edgeRight(String sheetId, int row, int col) =>
      _vis(resolver.formats.edgeRight(sheetId, row, col));

  void _strokeStyle(BorderSpec b) {
    final color = model.theme.resolveColor(b.color);
    g.setStrokeColor(color == null ? _Ink.black : _Ink.hex(color));
    g.setLineCap(PdfLineCap.butt);
    switch (b.style!) {
      case BorderStyle.dashed:
        g.setLineDashPattern([3 * k / 0.75, 2 * k / 0.75]);
      case BorderStyle.dotted:
        g.setLineDashPattern([1 * k / 0.75, 1 * k / 0.75]);
      default:
        g.setLineDashPattern();
    }
  }

  double _widthPx(BorderStyle s) => switch (s) {
    BorderStyle.thin || BorderStyle.dashed || BorderStyle.dotted => 1,
    BorderStyle.medium => 2,
    BorderStyle.thick => 3,
    BorderStyle.double => 3,
  };

  void _hLine(BorderSpec b, double x0, double x1, double y) {
    _strokeStyle(b);
    if (b.style == BorderStyle.double) {
      g.setLineWidth(k * 2 / 3);
      for (final dy in const [-1.0, 1.0]) {
        g.moveTo(px(x0), py(y + dy));
        g.lineTo(px(x1), py(y + dy));
        g.strokePath();
      }
    } else {
      g.setLineWidth(_widthPx(b.style!) * k);
      g.moveTo(px(x0), py(y));
      g.lineTo(px(x1), py(y));
      g.strokePath();
    }
    g.setLineDashPattern();
  }

  void _vLine(BorderSpec b, double x, double y0, double y1) {
    _strokeStyle(b);
    if (b.style == BorderStyle.double) {
      g.setLineWidth(k * 2 / 3);
      for (final dx in const [-1.0, 1.0]) {
        g.moveTo(px(x + dx), py(y0));
        g.lineTo(px(x + dx), py(y1));
        g.strokePath();
      }
    } else {
      g.setLineWidth(_widthPx(b.style!) * k);
      g.moveTo(px(x), py(y0));
      g.lineTo(px(x), py(y1));
      g.strokePath();
    }
    g.setLineDashPattern();
  }

  PdfColor _textColor(CellDisplay d) {
    final c =
        d.textColor ?? model.theme.resolveColor('theme:text') ?? '#000000';
    return _Ink.hex(c);
  }

  CellTextStyle _style(CellDisplay d) => CellTextStyle(
    family: d.format.fontFamily,
    size: d.format.fontSize * 4 / 3,
    bold: d.format.bold,
    italic: d.format.italic,
  );

  void _drawCell(
    SheetModel sheet,
    CellDisplay d,
    _Rect r,
    OverflowNeighbour left,
    OverflowNeighbour right,
  ) {
    switch (d.widget.kind) {
      case CellWidgetKind.checkbox:
        _checkbox(d, r);
        return;
      case CellWidgetKind.dropdownChip:
        if (d.text.isNotEmpty) _chip(d, r);
        return;
      case CellWidgetKind.dropdownArrow:
      case CellWidgetKind.none:
        break;
    }
    final base = _style(d);
    final spans = _spans(d, base);
    final arrow = d.widget.kind == CellWidgetKind.dropdownArrow;
    final layout = CellTextLayout.layout(
      text: d.text,
      style: base,
      spans: spans.map((s) => StyledSpan(s.start, s.end, s.style)).toList(),
      measurer: measurer,
      cellWidth: arrow ? math.max(0, r.w - 12) : r.w,
      cellHeight: r.h,
      wrap: d.format.wrap,
      align: d.hAlign,
      vAlign: d.format.vAlign,
      rotation: d.format.rotation,
      numberLike: d.numberLike,
      leftNeighbour: left,
      rightNeighbour: right,
    );
    g.saveContext();
    final clipL = layout.angle == 0 ? layout.clipLeft : 0.0;
    final clipR = layout.angle == 0 ? layout.clipRight : r.w;
    rectPx(r.x + clipL, r.y, clipR - clipL, r.h);
    g.clipPath();
    final color = _textColor(d);
    final rotated = layout.angle != 0;
    if (rotated) {
      final t = Matrix4.translationValues(
        px(r.x + layout.frameX),
        py(r.y + layout.frameY),
        0,
      )..rotateZ(layout.angle * math.pi / 180);
      g.setTransform(t);
    }
    final cf = d.conditional?.format;
    for (final line in layout.lines) {
      var x = line.x;
      for (final seg in _segments(
        layout.text,
        line.start,
        line.end,
        spans,
        base,
        layout.hashes,
      )) {
        final runFmt = seg.format;
        var segColor = color;
        final runColor = runFmt['textColor'];
        if (runColor is String && cf?[FormatAttr.textColor] == null) {
          final hex = model.theme.resolveColor(runColor);
          if (hex != null) segColor = _Ink.hex(hex);
        }
        final link = runFmt['link'] as String?;
        if (link != null && runColor == null) {
          final lc = model.theme.resolveColor('theme:link');
          if (lc != null) segColor = _Ink.hex(lc);
        }
        final w = measurer.width(seg.text, seg.style);
        final sizePt = seg.style.size * k;
        final (bx, by) = rotated
            ? (x * k, -line.baseline * k)
            : (px(r.x + x), py(r.y + line.baseline));
        g.setFillColor(segColor);
        var cx = bx;
        for (final run in measurer.runs(seg.text, seg.style)) {
          g.drawString(run.font, sizePt, run.text, cx, by);
          cx += run.font.stringMetrics(run.text).advanceWidth * sizePt;
        }
        final underline =
            runFmt['underline'] as bool? ?? (d.underline || link != null);
        final strike =
            runFmt['strikethrough'] as bool? ?? d.format.strikethrough;
        if (underline || strike) {
          g.setStrokeColor(segColor);
          g.setLineWidth(math.max(0.4, sizePt * 0.06));
          if (underline) {
            g.moveTo(bx, by - sizePt * 0.12);
            g.lineTo(bx + w * k, by - sizePt * 0.12);
            g.strokePath();
          }
          if (strike) {
            g.moveTo(bx, by + sizePt * 0.28);
            g.lineTo(bx + w * k, by + sizePt * 0.28);
            g.strokePath();
          }
        }
        if (!rotated) {
          final url = link ?? d.linkUrl;
          if (url != null) {
            _link(
              url,
              PdfRect(bx, by - sizePt * 0.25, w * k, sizePt * 1.1),
              sheet,
            );
          }
        }
        x += w;
      }
    }
    g.restoreContext();
    if (arrow) _triangle(r.x + r.w - 9, r.y + r.h / 2, _textColor(d));
  }

  List<_Span> _spans(CellDisplay d, CellTextStyle base) {
    final rich = d.rich;
    if (rich == null || rich.text != d.text) return const [];
    final cf = d.conditional?.format;
    return [
      for (final run in rich.runs)
        _Span(
          run.start,
          run.end,
          base.copyWith(
            family: run.format['fontFamily'] as String?,
            size: run.format['fontSize'] is num
                ? (run.format['fontSize'] as num).toDouble() * 4 / 3
                : null,
            bold: cf?[FormatAttr.bold] as bool? ?? run.format['bold'] as bool?,
            italic:
                cf?[FormatAttr.italic] as bool? ??
                run.format['italic'] as bool?,
          ),
          run.format,
        ),
    ];
  }

  Iterable<_Seg> _segments(
    String text,
    int start,
    int end,
    List<_Span> spans,
    CellTextStyle base,
    bool hashes,
  ) sync* {
    var end2 = end;
    while (end2 > start && text.codeUnitAt(end2 - 1) == 0x20) {
      end2--;
    }
    if (hashes || spans.isEmpty) {
      if (end2 > start) yield _Seg(text.substring(start, end2), base, const {});
      return;
    }
    var pos = start;
    for (final s in spans) {
      if (s.end <= pos) continue;
      if (s.start >= end2) break;
      if (s.start > pos) {
        yield _Seg(text.substring(pos, s.start), base, const {});
        pos = s.start;
      }
      final e = math.min(s.end, end2);
      if (e > pos) yield _Seg(text.substring(pos, e), s.style, s.format);
      pos = e;
    }
    if (pos < end2) yield _Seg(text.substring(pos, end2), base, const {});
  }

  void _link(String url, PdfRect rect, SheetModel sheet) {
    final u = url.trim();
    final lower = u.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('mailto:')) {
      PdfAnnot(page, PdfAnnotUrlLink(rect: rect, url: u));
      return;
    }
    if (lower.startsWith('www.')) {
      PdfAnnot(page, PdfAnnotUrlLink(rect: rect, url: 'https://$u'));
      return;
    }
    final m = RegExp(
      r'^#sheet=([^&]+)(?:&range=([A-Za-z$0-9:]+))?',
    ).firstMatch(u);
    if (m == null) return;
    final target = model.sheet(m.group(1)!);
    if (target == null) return;
    var row = -1;
    var col = -1;
    final a1 = m.group(2);
    if (a1 != null) {
      final area = _parseCell(a1);
      if (area != null) (row, col) = area;
    }
    for (final p in pages) {
      if (p.sheetId != target.id || p.kind != PageKind.cells) continue;
      if (row < 0 ||
          ((p.rows.contains(row) || p.repeatRows.contains(row)) &&
              (p.cols.contains(col) || p.repeatCols.contains(col)))) {
        PdfAnnot(
          page,
          PdfAnnotNamedLink(rect: rect, dest: 'wonky-page-${p.pageNumber}'),
        );
        return;
      }
    }
  }

  static (int, int)? _parseCell(String a1) {
    final m = RegExp(r'^\$?([A-Za-z]{1,3})\$?(\d+)').firstMatch(a1);
    if (m == null) return null;
    return (int.parse(m.group(2)!) - 1, ColumnLetters.toIndex(m.group(1)!));
  }

  void _checkbox(CellDisplay d, _Rect r) {
    const size = 14.0;
    final x = switch (d.hAlign) {
      HorizontalAlign.left => r.x + 3,
      HorizontalAlign.right => r.x + r.w - 3 - size,
      HorizontalAlign.center => r.x + (r.w - size) / 2,
    };
    final y = switch (d.format.vAlign) {
      VerticalAlign.top => r.y + 2,
      VerticalAlign.middle => r.y + (r.h - size) / 2,
      VerticalAlign.bottom => r.y + r.h - 2 - size,
    };
    final radius = 2 * k;
    if (d.widget.checked) {
      g.setFillColor(
        d.textColor == null ? _Ink.checkbox : _Ink.hex(d.textColor!),
      );
      g.drawRRect(px(x), py(y + size), size * k, size * k, radius, radius);
      g.fillPath();
      g.setStrokeColor(_Ink.white);
      g.setLineWidth(1.8 * k);
      g.setLineCap(PdfLineCap.round);
      g.setLineJoin(PdfLineJoin.round);
      g.moveTo(px(x + 3.5), py(y + 7.5));
      g.lineTo(px(x + 6), py(y + 10));
      g.lineTo(px(x + 10.5), py(y + 4.5));
      g.strokePath();
      g.setLineCap(PdfLineCap.butt);
      g.setLineJoin(PdfLineJoin.miter);
    } else {
      g.setStrokeColor(_Ink.checkboxOutline);
      g.setLineWidth(1.5 * k);
      g.drawRRect(
        px(x + 0.75),
        py(y + size - 0.75),
        (size - 1.5) * k,
        (size - 1.5) * k,
        radius,
        radius,
      );
      g.strokePath();
    }
  }

  void _chip(CellDisplay d, _Rect r) {
    final style = _style(d);
    final h = math.min(r.h - 4, style.size * 1.5);
    if (h <= 4) return;
    final maxW = r.w - 6;
    const pad = 6.0;
    const chevron = 10.0;
    var text = d.text;
    var tw = measurer.width(text, style);
    final avail = maxW - 2 * pad - chevron;
    if (tw > avail) {
      while (text.isNotEmpty && measurer.width('$text…', style) > avail) {
        text = text.substring(0, text.length - 1);
      }
      text = '$text…';
      tw = measurer.width(text, style);
    }
    final w = math.min(maxW, tw + 2 * pad + chevron);
    final x = r.x + 3;
    final y = switch (d.format.vAlign) {
      VerticalAlign.top => r.y + 2,
      VerticalAlign.middle => r.y + (r.h - h) / 2,
      VerticalAlign.bottom => r.y + r.h - 2 - h,
    };
    final fill = d.widget.chipFill == null
        ? _Ink.chipFill
        : _Ink.hex(d.widget.chipFill!);
    final fg = d.widget.chipText == null
        ? _Ink.chipText
        : _Ink.hex(d.widget.chipText!);
    g.setFillColor(fill);
    g.drawRRect(px(x), py(y + h), w * k, h * k, h * k / 2, h * k / 2);
    g.fillPath();
    g.saveContext();
    rectPx(x, y, w, h);
    g.clipPath();
    final baseline =
        y + h / 2 + (measurer.ascent(style) - measurer.descent(style)) / 2;
    final sizePt = style.size * k;
    g.setFillColor(fg);
    var cx = px(x + pad);
    for (final run in measurer.runs(text, style)) {
      g.drawString(run.font, sizePt, run.text, cx, py(baseline));
      cx += run.font.stringMetrics(run.text).advanceWidth * sizePt;
    }
    g.restoreContext();
    _triangle(x + w - pad - chevron / 2 + 2, y + h / 2, fg);
  }

  void _triangle(double cx, double cy, PdfColor color) {
    g.setFillColor(color);
    g.moveTo(px(cx - 3.5), py(cy - 1.75));
    g.lineTo(px(cx + 3.5), py(cy - 1.75));
    g.lineTo(px(cx), py(cy + 2));
    g.closePath();
    g.fillPath();
  }

  void _headings(
    List<_Slot> rows,
    List<_Slot> cols,
    double headW,
    double headH,
    double totalW,
    double totalH,
  ) {
    g.setFillColor(_Ink.headingFill);
    rectPx(0, 0, totalW, headH);
    g.fillPath();
    rectPx(0, 0, headW, totalH);
    g.fillPath();
    g.setStrokeColor(_Ink.headingLine);
    g.setLineWidth(0.5);
    final style = CellTextStyle(family: _defaultFamily, size: 8 * 4 / 3);
    final asc = measurer.ascent(style);
    final desc = measurer.descent(style);
    void label(String text, double x, double y, double w, double h) {
      rectPx(x, y, w, h);
      g.strokePath();
      final tw = measurer.width(text, style);
      final baseline = y + h / 2 + (asc - desc) / 2;
      g.setFillColor(_Ink.headingText);
      var cx = px(x + (w - tw) / 2);
      final sizePt = style.size * k;
      for (final run in measurer.runs(text, style)) {
        g.drawString(run.font, sizePt, run.text, cx, py(baseline));
        cx += run.font.stringMetrics(run.text).advanceWidth * sizePt;
      }
    }

    rectPx(0, 0, headW, headH);
    g.strokePath();
    for (final c in cols) {
      label(ColumnLetters.fromIndex(c.index), c.pos, 0, c.size, headH);
    }
    for (final r in rows) {
      label('${r.index + 1}', 0, r.pos, headW, r.size);
    }
  }

  // ---------------------------------------------------------------------------
  // Objects.

  /// Sheet-coordinate offset (px over printed rows/columns) of index [i].
  double _offset(SheetModel s, bool rows, int i) {
    final key = '${s.id}|$rows';
    final axis = rows ? s.rows : s.columns;
    var prefix = _prefixCache[key];
    if (prefix == null || prefix.length <= i + 1) {
      final n = math.max(
        i + 1,
        math.min(axis.length, (prefix?.length ?? 0) * 2),
      );
      final p = Float64List(n + 1);
      for (var j = 0; j < n; j++) {
        final size = j >= axis.length || Paginator.hiddenForPrint(axis, j)
            ? 0.0
            : (rows ? _rowSize(j) : axis.naturalSizeAt(j));
        p[j + 1] = p[j] + size;
      }
      prefix = p;
      _prefixCache[key] = p;
    }
    return prefix[i.clamp(0, prefix.length - 1)];
  }

  double _rowSize(int row) {
    // Rows on this page use the paginator's heights (incl. auto-fit).
    final i = spec.rows.indexOf(row);
    if (i >= 0) return spec.rowHeightsPx[i];
    final j = spec.repeatRows.indexOf(row);
    if (j >= 0) return spec.repeatRowHeightsPx[j];
    return model.sheet(spec.sheetId)!.rows.naturalSizeAt(row);
  }

  void _objects(SheetModel sheet, List<_Slot> rows, List<_Slot> cols) {
    if (sheet.objects.isEmpty || rows.isEmpty || cols.isEmpty) return;
    _prefixCache.remove('${sheet.id}|true');
    final objs = sheet.objects.values.toList()
      ..sort((a, b) {
        final z = a.zIndex.compareTo(b.zIndex);
        return z != 0 ? z : a.id.compareTo(b.id);
      });
    // Windows: (region rows) × (region cols).
    List<(double pagePos, double sheetStart, double size)> windows(
      List<_Slot> slots,
      bool isRow,
    ) {
      final out = <(double, double, double)>[];
      for (final region in const [0, 1]) {
        final s = slots.where((x) => x.region == region).toList();
        if (s.isEmpty) continue;
        final size = s.last.pos + s.last.size - s.first.pos;
        out.add((s.first.pos, _offset(sheet, isRow, s.first.index), size));
      }
      return out;
    }

    final rowWins = windows(rows, true);
    final colWins = windows(cols, false);
    for (final o in objs) {
      if (o.kind != EmbeddedObjectKind.image &&
          o.kind != EmbeddedObjectKind.chart) {
        continue;
      }
      final p = PrintObjectPlacement.of(sheet, o);
      if (p == null || p.ownSheet) continue;
      final sx =
          _offset(sheet, false, p.col) +
          (Paginator.hiddenForPrint(sheet.columns, p.col) ? 0 : p.dx);
      final sy =
          _offset(sheet, true, p.row) +
          (Paginator.hiddenForPrint(sheet.rows, p.row) ? 0 : p.dy);
      for (final (rp, rs, rsize) in rowWins) {
        for (final (cp, cs, csize) in colWins) {
          final x = cp + (sx - cs);
          final y = rp + (sy - rs);
          if (x >= cp + csize ||
              x + p.width <= cp ||
              y >= rp + rsize ||
              y + p.height <= rp) {
            continue;
          }
          g.saveContext();
          rectPx(cp, rp, csize, rsize);
          g.clipPath();
          final bounds = PdfRect(
            px(x),
            py(y + p.height),
            p.width * k,
            p.height * k,
          );
          if (o.kind == EmbeddedObjectKind.image) {
            _image(o, bounds);
          } else {
            charts?.drawChart(doc, g, o, bounds);
          }
          g.restoreContext();
        }
      }
    }
  }

  void _image(EmbeddedObjectRecord o, PdfRect bounds) {
    final img = _imageCache.putIfAbsent(o.id, () {
      final data = images?.call(o);
      if (data == null) return null;
      try {
        return PdfImage.file(doc, bytes: data.bytes);
      } on Object {
        return null;
      }
    });
    if (img == null) return;
    var fit = 'stretch';
    try {
      final spec = jsonDecode(o.specJson);
      if (spec is Map && spec['fit'] is String) fit = spec['fit'] as String;
    } on FormatException {
      // Keep the default.
    }
    var w = bounds.width;
    var h = bounds.height;
    var x = bounds.left;
    var y = bounds.bottom;
    if (fit != 'stretch' && img.width > 0 && img.height > 0) {
      final sx = bounds.width / img.width;
      final sy = bounds.height / img.height;
      final s = fit == 'cover' ? math.max(sx, sy) : math.min(sx, sy);
      w = img.width * s;
      h = img.height * s;
      x = bounds.left + (bounds.width - w) / 2;
      y = bounds.bottom + (bounds.height - h) / 2;
      g.drawRect(bounds.left, bounds.bottom, bounds.width, bounds.height);
      g.clipPath();
    }
    g.drawImage(img, x, y, w, h);
  }

  void _chartPage() {
    final sheet = model.sheet(spec.sheetId);
    final o = sheet?.objects[spec.objectId];
    if (sheet == null || o == null) return;
    final p = PrintObjectPlacement.of(sheet, o);
    var w = spec.printableWidth;
    var h = spec.printableHeight;
    if (p != null && p.lockAspect && p.width > 0 && p.height > 0) {
      final s = math.min(w / p.width, h / p.height);
      w = p.width * s;
      h = p.height * s;
    }
    final x = spec.printableLeft + (spec.printableWidth - w) / 2;
    final top = spec.printableTop + (spec.printableHeight - h) / 2;
    final bounds = PdfRect(x, pageH - top - h, w, h);
    g.saveContext();
    g.drawRect(bounds.left, bounds.bottom, bounds.width, bounds.height);
    g.clipPath();
    if (o.kind == EmbeddedObjectKind.image) {
      _image(o, bounds);
    } else {
      charts?.drawChart(doc, g, o, bounds);
    }
    g.restoreContext();
  }

  void _notesPage() {
    var y = spec.printableTop;
    for (final line in spec.noteLines) {
      final style = CellTextStyle(
        family: _defaultFamily,
        size: line.heading
            ? PrintMetrics.notesHeadingFontPt
            : PrintMetrics.notesFontPt,
        bold: line.heading,
      );
      final lh = line.heading
          ? PrintMetrics.notesHeadingPt
          : PrintMetrics.notesLinePt;
      final baseline =
          y + lh / 2 + (measurer.ascent(style) - measurer.descent(style)) / 2;
      _drawPlain(
        line.text,
        style,
        spec.printableLeft + (line.continuation ? 12 : 0),
        pageH - baseline,
        _Ink.black,
      );
      y += lh;
    }
  }
}

final class _Rect {
  const _Rect(this.x, this.y, this.w, this.h);
  final double x;
  final double y;
  final double w;
  final double h;
}

final class _Logical {
  _Logical(
    this.r0,
    this.c0,
    this.r1,
    this.c1,
    this.row,
    this.col, {
    this.merge,
    this.showContent = true,
  });

  /// Page slot positions.
  final int r0;
  final int c0;
  final int r1;
  final int c1;

  /// Sheet indices of the cell whose content/format is shown.
  final int row;
  final int col;
  final GridRect? merge;
  final bool showContent;
}

final class _Span {
  _Span(this.start, this.end, this.style, this.format);
  final int start;
  final int end;
  final CellTextStyle style;
  final Map<String, Object?> format;
}

final class _Seg {
  _Seg(this.text, this.style, this.format);
  final String text;
  final CellTextStyle style;
  final Map<String, Object?> format;
}
