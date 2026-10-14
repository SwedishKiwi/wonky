import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' hide BorderStyle;
import 'package:wonky_sheets_core/formula.dart'
    show CellSource, ColumnLetters, GridRect;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model.dart' as core show RichText;

import '../charts/render/chart_painter.dart' show ChartScenePainter;
import 'print_fonts.dart';

/// Inputs shared by every page painter of one preview (11 §7.5).
class PrintPaintContext {
  PrintPaintContext({
    required this.model,
    required this.source,
    required this.resolver,
    required this.measurer,
    required this.title,
    required this.date,
    required this.time,
    this.chartScene,
    this.images = const {},
  });

  final WorkbookModel model;
  final CellSource source;
  final CellDisplayResolver resolver;

  /// The PDF font metrics: line breaking, overflow and alignment match the
  /// PDF exactly ([CellTextLayout] is shared with `SheetsPdfRenderer`).
  final CellTextMeasurer measurer;
  final String title;
  final String date;
  final String time;

  /// Chart scenes at a printed size (`ChartPipeline.printSceneFor`).
  final ChartScene? Function(EmbeddedObjectRecord, double, double)? chartScene;

  /// Decoded images by file UUID (missing ones paint a placeholder).
  final Map<String, ui.Image> images;

  String get defaultFamily {
    final t = model.theme.textFont;
    return t.isNotEmpty ? t : model.spreadsheet.defaultFontFamily;
  }
}

/// Paints one [PageSpec] like `SheetsPdfRenderer` draws it into the PDF
/// (fills, data bars, gridlines, borders, text with overflow/wrap/rotation,
/// checkboxes and chips, headings, objects, header/footer, notes), at
/// [pixelsPerPoint]. Pages are always light paper (11 §7.1).
class PrintPagePainter extends CustomPainter {
  PrintPagePainter(this.ctx, this.spec, {this.pixelsPerPoint = 4 / 3});

  final PrintPaintContext ctx;
  final PageSpec spec;
  final double pixelsPerPoint;

  static const _black = Color(0xff000000);
  static const _gridline = Color(0xffd0d0d0);
  static const _headingFill = Color(0xfff8f9fa);
  static const _headingLine = Color(0xffc0c0c0);
  static const _headingText = Color(0xff5f6368);
  static const _checkbox = Color(0xff1a73e8);
  static const _checkboxOutline = Color(0xff5f6368);
  static const _chipFill = Color(0xffe8eaed);
  static const _chipText = Color(0xff202124);

  late Canvas _c;
  late double _k; // pt per grid px

  WorkbookModel get model => ctx.model;

  static Color hex(String? h, [Color fallback = _black]) {
    if (h == null) return fallback;
    var s = h.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
    if (s.length == 6) s = 'ff$s';
    if (s.length == 8 && h.startsWith('#') && h.length == 9) {
      // #rrggbbaa → aarrggbb
      s = s.substring(6) + s.substring(0, 6);
    }
    final v = int.tryParse(s, radix: 16);
    return v == null ? fallback : Color(v);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _c = canvas;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xffffffff),
    );
    canvas.scale(pixelsPerPoint);
    _k = 0.75 * spec.scale;
    _headerFooter();
    switch (spec.kind) {
      case PageKind.cells:
        _cellsPage();
      case PageKind.chart:
        _chartPage();
      case PageKind.notes:
        _notesPage();
      case PageKind.blank:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PrintPagePainter old) =>
      old.spec != spec ||
      old.ctx != ctx ||
      old.pixelsPerPoint != pixelsPerPoint;

  // ---------------------------------------------------------------- text

  TextPainter _painter(
    String text,
    CellTextStyle style,
    Color color, {
    double scale = 1,
    bool underline = false,
    bool strike = false,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: SheetsPdfFonts.screenFamily(style.family),
        fontSize: style.size * scale,
        fontWeight: style.bold ? FontWeight.w700 : FontWeight.w400,
        fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
        color: color,
        height: 1,
        decoration: TextDecoration.combine([
          if (underline) TextDecoration.underline,
          if (strike) TextDecoration.lineThrough,
        ]),
        decorationColor: color,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  /// Draws [text] with its left edge at [x] and baseline at [baseline]
  /// (current canvas units); the painted width is fitted to the PDF metric
  /// width [width] when given.
  void _text(
    String text,
    CellTextStyle style,
    double x,
    double baseline,
    Color color, {
    double? width,
    double scale = 1,
    bool underline = false,
    bool strike = false,
  }) {
    if (text.isEmpty) return;
    final tp = _painter(
      text,
      style,
      color,
      scale: scale,
      underline: underline,
      strike: strike,
    );
    final asc = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final target = width == null ? null : width * scale;
    if (target != null && tp.width > 0) {
      final f = target / tp.width;
      if ((f - 1).abs() > 0.01 && f > 0.5 && f < 2) {
        _c.save();
        _c.translate(x, baseline - asc);
        _c.scale(f, 1);
        tp.paint(_c, Offset.zero);
        _c.restore();
        tp.dispose();
        return;
      }
    }
    tp.paint(_c, Offset(x, baseline - asc));
    tp.dispose();
  }

  // -------------------------------------------------------- header/footer

  void _headerFooter() {
    final hf = spec.settings.headerFooter;
    final hctx = HeaderFooterContext(
      page: spec.pageNumber,
      pages: spec.totalPages,
      title: ctx.title,
      sheet: spec.sheetName,
      date: ctx.date,
      time: ctx.time,
    );
    final style = CellTextStyle(
      family: ctx.defaultFamily,
      size: PrintMetrics.headerFooterFontPt,
    );
    final m = ctx.measurer;
    final left = spec.settings.margins.leftPt;
    final right = spec.pageWidth - spec.settings.margins.rightPt;
    void band(HeaderFooterSections sec, double top, double height) {
      if (sec.isEmpty || height <= 0) return;
      final baseline =
          top + height / 2 + (m.ascent(style) - m.descent(style)) / 2;
      final l = HeaderFooterTokens.render(sec.left, hctx);
      final c = HeaderFooterTokens.render(sec.center, hctx);
      final r = HeaderFooterTokens.render(sec.right, hctx);
      if (l.isNotEmpty) {
        _text(l, style, left, baseline, _black, width: m.width(l, style));
      }
      if (c.isNotEmpty) {
        final w = m.width(c, style);
        _text(c, style, (left + right) / 2 - w / 2, baseline, _black, width: w);
      }
      if (r.isNotEmpty) {
        final w = m.width(r, style);
        _text(r, style, right - w, baseline, _black, width: w);
      }
    }

    band(hf.effectiveHeader, spec.settings.margins.topPt, spec.headerHeight);
    band(
      hf.effectiveFooter,
      spec.pageHeight - spec.settings.margins.bottomPt - spec.footerHeight,
      spec.footerHeight,
    );
  }

  // ---------------------------------------------------------------- cells

  /// Grid px (content coordinates) → page points.
  Offset _p(double x, double y) =>
      Offset(spec.originX + x * _k, spec.originY + y * _k);

  Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(
    spec.originX + x * _k,
    spec.originY + y * _k,
    w * _k,
    h * _k,
  );

  void _cellsPage() {
    final sheet = model.sheet(spec.sheetId);
    if (sheet == null) return;
    final resolver = ctx.resolver;
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

    _c.save();
    _c.clipRect(
      Rect.fromLTWH(
        spec.printableLeft,
        spec.printableTop,
        spec.printableWidth,
        spec.printableHeight,
      ),
    );

    final colPos = {for (var i = 0; i < cols.length; i++) cols[i].index: i};
    final rowPos = {for (var i = 0; i < rows.length; i++) rows[i].index: i};
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
            showContent: rowPos[firstRow] != null && colPos[firstCol] != null,
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
    final displays = <_Logical, CellDisplay>{
      for (final c in cells) c: resolver.display(sheet.id, c.row, c.col),
    };
    final mergedPos = <(int, int)>{
      for (final c in cells)
        if (c.merge != null)
          for (var i = c.r0; i <= c.r1; i++)
            for (var j = c.c0; j <= c.c1; j++) (i, j),
    };
    Rect rectOf(_Logical c) => Rect.fromLTWH(
      cols[c.c0].pos,
      rows[c.r0].pos,
      cols[c.c1].pos + cols[c.c1].size - cols[c.c0].pos,
      rows[c.r1].pos + rows[c.r1].size - rows[c.r0].pos,
    );

    // 1. Fills and data bars.
    final fill = Paint();
    for (final c in cells) {
      final d = displays[c]!;
      final r = rectOf(c);
      if (d.fillColor != null) {
        fill.color = hex(d.fillColor);
        _c.drawRect(_r(r.left, r.top, r.width, r.height), fill);
      }
      final bar = d.conditional?.dataBarFraction;
      if (bar != null && bar > 0) {
        fill.color = hex(
          model.theme.resolveColor(d.conditional!.dataBarColor) ?? '#638EC6',
        );
        final start = d.conditional!.dataBarStart.clamp(0.0, 1.0);
        final innerW = r.width - 2;
        _c.drawRect(
          _r(
            r.left + 1 + innerW * start,
            r.top + 2,
            innerW * bar.clamp(0.0, 1.0 - start),
            r.height - 4,
          ),
          fill,
        );
      }
    }

    // 2. Gridlines.
    if (spec.settings.gridlines) {
      final p = Paint()
        ..color = _gridline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      for (final c in cells) {
        final r = rectOf(c);
        _c.drawRect(_r(r.left, r.top, r.width, r.height), p);
      }
    }

    // 3. Borders.
    for (final c in cells) {
      final r = rectOf(c);
      if (c.merge != null) {
        for (var j = c.c0; j <= c.c1; j++) {
          final col = cols[j].index;
          final top = c.merge!.top == rows[c.r0].index
              ? _edgeTop(sheet.id, c.merge!.top, col)
              : null;
          final bottom = c.merge!.bottom == rows[c.r1].index
              ? _edgeBelow(sheet.id, c.merge!.bottom, col)
              : null;
          if (top != null) {
            _hLine(top, cols[j].pos, cols[j].pos + cols[j].size, r.top);
          }
          if (bottom != null) {
            _hLine(bottom, cols[j].pos, cols[j].pos + cols[j].size, r.bottom);
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
            _vLine(left, r.left, rows[i].pos, rows[i].pos + rows[i].size);
          }
          if (right != null) {
            _vLine(right, r.right, rows[i].pos, rows[i].pos + rows[i].size);
          }
        }
        continue;
      }
      final e = resolver.edges(sheet.id, c.row, c.col);
      final prevRowAdj =
          c.r0 > 0 &&
          rows[c.r0 - 1].index == c.row - 1 &&
          !mergedPos.contains((c.r0 - 1, c.c0));
      final prevColAdj =
          c.c0 > 0 &&
          cols[c.c0 - 1].index == c.col - 1 &&
          !mergedPos.contains((c.r0, c.c0 - 1));
      if (!prevRowAdj && e.top != null) {
        _hLine(e.top!, r.left, r.right, r.top);
      }
      if (!prevColAdj && e.left != null) {
        _vLine(e.left!, r.left, r.top, r.bottom);
      }
      if (e.bottom != null) _hLine(e.bottom!, r.left, r.right, r.bottom);
      if (e.right != null) _vLine(e.right!, r.right, r.top, r.bottom);
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

      _drawCell(d, r, (s) => neighbour(-1, s), (s) => neighbour(1, s));
    }

    // 5. Headings.
    if (spec.headings) _headings(rows, cols, headW, headH, totalW, totalH);

    // 6. Objects.
    _objects(sheet, rows, cols);
    _c.restore();
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
        ? ctx.resolver.formats.edgeBelow(sheetId, row - 1, col)
        : ctx.resolver.formats.outerEdge(
            sheetId,
            row,
            col,
            FormatAttr.borderTop,
          ),
  );

  BorderSpec? _edgeBelow(String sheetId, int row, int col) =>
      _vis(ctx.resolver.formats.edgeBelow(sheetId, row, col));

  BorderSpec? _edgeLeft(String sheetId, int row, int col) => _vis(
    col > 0
        ? ctx.resolver.formats.edgeRight(sheetId, row, col - 1)
        : ctx.resolver.formats.outerEdge(
            sheetId,
            row,
            col,
            FormatAttr.borderLeft,
          ),
  );

  BorderSpec? _edgeRight(String sheetId, int row, int col) =>
      _vis(ctx.resolver.formats.edgeRight(sheetId, row, col));

  double _widthPx(BorderStyle s) => switch (s) {
    BorderStyle.thin || BorderStyle.dashed || BorderStyle.dotted => 1,
    BorderStyle.medium => 2,
    BorderStyle.thick => 3,
    BorderStyle.double => 3,
  };

  Paint _borderPaint(BorderSpec b, double width) => Paint()
    ..color = hex(model.theme.resolveColor(b.color))
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeWidth = width;

  void _line(BorderSpec b, Offset a, Offset z, double width) {
    final paint = _borderPaint(b, width);
    final dash = switch (b.style) {
      BorderStyle.dashed => (3.0 * _k / 0.75, 2.0 * _k / 0.75),
      BorderStyle.dotted => (1.0 * _k / 0.75, 1.0 * _k / 0.75),
      _ => null,
    };
    if (dash == null) {
      _c.drawLine(a, z, paint);
      return;
    }
    final len = (z - a).distance;
    if (len <= 0) return;
    final dir = (z - a) / len;
    var t = 0.0;
    while (t < len) {
      final e = math.min(len, t + dash.$1);
      _c.drawLine(a + dir * t, a + dir * e, paint);
      t = e + dash.$2;
    }
  }

  void _hLine(BorderSpec b, double x0, double x1, double y) {
    if (b.style == BorderStyle.double) {
      for (final dy in const [-1.0, 1.0]) {
        _line(b, _p(x0, y + dy), _p(x1, y + dy), _k * 2 / 3);
      }
    } else {
      _line(b, _p(x0, y), _p(x1, y), _widthPx(b.style!) * _k);
    }
  }

  void _vLine(BorderSpec b, double x, double y0, double y1) {
    if (b.style == BorderStyle.double) {
      for (final dx in const [-1.0, 1.0]) {
        _line(b, _p(x + dx, y0), _p(x + dx, y1), _k * 2 / 3);
      }
    } else {
      _line(b, _p(x, y0), _p(x, y1), _widthPx(b.style!) * _k);
    }
  }

  Color _textColor(CellDisplay d) =>
      hex(d.textColor ?? model.theme.resolveColor('theme:text') ?? '#000000');

  CellTextStyle _style(CellDisplay d) => CellTextStyle(
    family: d.format.fontFamily,
    size: d.format.fontSize * 4 / 3,
    bold: d.format.bold,
    italic: d.format.italic,
  );

  List<_Span> _spans(CellDisplay d, CellTextStyle base) {
    final core.RichText? rich = d.rich;
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

  void _drawCell(
    CellDisplay d,
    Rect r,
    OverflowNeighbour left,
    OverflowNeighbour right,
  ) {
    switch (d.widget.kind) {
      case CellWidgetKind.checkbox:
        _checkboxWidget(d, r);
        return;
      case CellWidgetKind.dropdownChip:
        if (d.text.isNotEmpty) _chip(d, r);
        return;
      case CellWidgetKind.dropdownArrow:
      case CellWidgetKind.none:
        break;
    }
    final m = ctx.measurer;
    final base = _style(d);
    final spans = _spans(d, base);
    final arrow = d.widget.kind == CellWidgetKind.dropdownArrow;
    final layout = CellTextLayout.layout(
      text: d.text,
      style: base,
      spans: [for (final s in spans) StyledSpan(s.start, s.end, s.style)],
      measurer: m,
      cellWidth: arrow ? math.max(0, r.width - 12) : r.width,
      cellHeight: r.height,
      wrap: d.format.wrap,
      align: d.hAlign,
      vAlign: d.format.vAlign,
      rotation: d.format.rotation,
      numberLike: d.numberLike,
      leftNeighbour: left,
      rightNeighbour: right,
    );
    _c.save();
    final rotated = layout.angle != 0;
    final clipL = rotated ? 0.0 : layout.clipLeft;
    final clipR = rotated ? r.width : layout.clipRight;
    _c.clipRect(_r(r.left + clipL, r.top, clipR - clipL, r.height));
    // Draw in grid px.
    if (rotated) {
      final o = _p(r.left + layout.frameX, r.top + layout.frameY);
      _c.translate(o.dx, o.dy);
      _c.scale(_k);
      _c.rotate(-layout.angle * math.pi / 180);
    } else {
      final o = _p(r.left, r.top);
      _c.translate(o.dx, o.dy);
      _c.scale(_k);
    }
    final color = _textColor(d);
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
          final h = model.theme.resolveColor(runColor);
          if (h != null) segColor = hex(h);
        }
        final link = runFmt['link'] as String?;
        if (link != null && runColor == null) {
          final lc = model.theme.resolveColor('theme:link');
          if (lc != null) segColor = hex(lc);
        }
        final w = m.width(seg.text, seg.style);
        final underline =
            runFmt['underline'] as bool? ?? (d.underline || link != null);
        final strike =
            runFmt['strikethrough'] as bool? ?? d.format.strikethrough;
        _text(
          seg.text,
          seg.style,
          x,
          line.baseline,
          segColor,
          width: w,
          underline: underline,
          strike: strike,
        );
        x += w;
      }
    }
    _c.restore();
    if (arrow) _triangle(r.right - 9, r.top + r.height / 2, _textColor(d));
  }

  void _checkboxWidget(CellDisplay d, Rect r) {
    const size = 14.0;
    final x = switch (d.hAlign) {
      HorizontalAlign.left => r.left + 3,
      HorizontalAlign.right => r.right - 3 - size,
      HorizontalAlign.center => r.left + (r.width - size) / 2,
    };
    final y = switch (d.format.vAlign) {
      VerticalAlign.top => r.top + 2,
      VerticalAlign.middle => r.top + (r.height - size) / 2,
      VerticalAlign.bottom => r.bottom - 2 - size,
    };
    final radius = Radius.circular(2 * _k);
    if (d.widget.checked) {
      _c.drawRRect(
        RRect.fromRectAndRadius(_r(x, y, size, size), radius),
        Paint()..color = d.textColor == null ? _checkbox : hex(d.textColor),
      );
      final path = Path()
        ..moveTo(_p(x + 3.5, y + 7.5).dx, _p(x + 3.5, y + 7.5).dy)
        ..lineTo(_p(x + 6, y + 10).dx, _p(x + 6, y + 10).dy)
        ..lineTo(_p(x + 10.5, y + 4.5).dx, _p(x + 10.5, y + 4.5).dy);
      _c.drawPath(
        path,
        Paint()
          ..color = const Color(0xffffffff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * _k
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      _c.drawRRect(
        RRect.fromRectAndRadius(
          _r(x + 0.75, y + 0.75, size - 1.5, size - 1.5),
          radius,
        ),
        Paint()
          ..color = _checkboxOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * _k,
      );
    }
  }

  void _chip(CellDisplay d, Rect r) {
    final m = ctx.measurer;
    final style = _style(d);
    final h = math.min(r.height - 4, style.size * 1.5);
    if (h <= 4) return;
    final maxW = r.width - 6;
    const pad = 6.0;
    const chevron = 10.0;
    var text = d.text;
    var tw = m.width(text, style);
    final avail = maxW - 2 * pad - chevron;
    if (tw > avail) {
      while (text.isNotEmpty && m.width('$text…', style) > avail) {
        text = text.substring(0, text.length - 1);
      }
      text = '$text…';
      tw = m.width(text, style);
    }
    final w = math.min(maxW, tw + 2 * pad + chevron);
    final x = r.left + 3;
    final y = switch (d.format.vAlign) {
      VerticalAlign.top => r.top + 2,
      VerticalAlign.middle => r.top + (r.height - h) / 2,
      VerticalAlign.bottom => r.bottom - 2 - h,
    };
    final fg = d.widget.chipText == null ? _chipText : hex(d.widget.chipText);
    _c.drawRRect(
      RRect.fromRectAndRadius(_r(x, y, w, h), Radius.circular(h * _k / 2)),
      Paint()
        ..color = d.widget.chipFill == null
            ? _chipFill
            : hex(d.widget.chipFill),
    );
    _c.save();
    _c.clipRect(_r(x, y, w, h));
    final o = _p(x + pad, y);
    _c.translate(o.dx, o.dy);
    _c.scale(_k);
    final baseline = h / 2 + (m.ascent(style) - m.descent(style)) / 2;
    _text(text, style, 0, baseline, fg, width: m.width(text, style));
    _c.restore();
    _triangle(x + w - pad - chevron / 2 + 2, y + h / 2, fg);
  }

  void _triangle(double cx, double cy, Color color) {
    final a = _p(cx - 3.5, cy - 1.75);
    final b = _p(cx + 3.5, cy - 1.75);
    final c = _p(cx, cy + 2);
    _c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..close(),
      Paint()..color = color,
    );
  }

  void _headings(
    List<_Slot> rows,
    List<_Slot> cols,
    double headW,
    double headH,
    double totalW,
    double totalH,
  ) {
    final fill = Paint()..color = _headingFill;
    _c.drawRect(_r(0, 0, totalW, headH), fill);
    _c.drawRect(_r(0, 0, headW, totalH), fill);
    final line = Paint()
      ..color = _headingLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final m = ctx.measurer;
    final style = CellTextStyle(family: ctx.defaultFamily, size: 8 * 4 / 3);
    final asc = m.ascent(style);
    final desc = m.descent(style);
    void label(String text, double x, double y, double w, double h) {
      _c.drawRect(_r(x, y, w, h), line);
      final tw = m.width(text, style);
      _c.save();
      final o = _p(x + (w - tw) / 2, y);
      _c.translate(o.dx, o.dy);
      _c.scale(_k);
      _text(text, style, 0, h / 2 + (asc - desc) / 2, _headingText, width: tw);
      _c.restore();
    }

    _c.drawRect(_r(0, 0, headW, headH), line);
    for (final c in cols) {
      label(ColumnLetters.fromIndex(c.index), c.pos, 0, c.size, headH);
    }
    for (final r in rows) {
      label('${r.index + 1}', 0, r.pos, headW, r.size);
    }
  }

  // -------------------------------------------------------------- objects

  double _offset(SheetModel s, bool rows, int i) {
    final axis = rows ? s.rows : s.columns;
    var sum = 0.0;
    for (var j = 0; j < i && j < axis.length; j++) {
      if (Paginator.hiddenForPrint(axis, j)) continue;
      sum += rows ? _rowSize(j) : axis.naturalSizeAt(j);
    }
    return sum;
  }

  double _rowSize(int row) {
    final i = spec.rows.indexOf(row);
    if (i >= 0) return spec.rowHeightsPx[i];
    final j = spec.repeatRows.indexOf(row);
    if (j >= 0) return spec.repeatRowHeightsPx[j];
    return model.sheet(spec.sheetId)!.rows.naturalSizeAt(row);
  }

  void _objects(SheetModel sheet, List<_Slot> rows, List<_Slot> cols) {
    if (sheet.objects.isEmpty || rows.isEmpty || cols.isEmpty) return;
    final objs = sheet.objects.values.toList()
      ..sort((a, b) {
        final z = a.zIndex.compareTo(b.zIndex);
        return z != 0 ? z : a.id.compareTo(b.id);
      });
    List<(double, double, double)> windows(List<_Slot> slots, bool isRow) {
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
          _c.save();
          _c.clipRect(_r(cp, rp, csize, rsize));
          _object(o, _r(x, y, p.width, p.height));
          _c.restore();
        }
      }
    }
  }

  void _object(EmbeddedObjectRecord o, Rect bounds) {
    if (o.kind == EmbeddedObjectKind.image) {
      final spec = ImageSpec.fromJson(o.specJson);
      final img = ctx.images[spec.fileUuid];
      if (img == null) {
        _c.drawRect(bounds, Paint()..color = const Color(0xffeeeeee));
        return;
      }
      var fit = 'stretch';
      try {
        final m = jsonDecode(o.specJson);
        if (m is Map && m['fit'] is String) fit = m['fit'] as String;
      } on FormatException {
        // default
      }
      paintImage(
        canvas: _c,
        rect: bounds,
        image: img,
        fit: switch (fit) {
          'cover' => BoxFit.cover,
          'contain' => BoxFit.contain,
          _ => BoxFit.fill,
        },
        filterQuality: FilterQuality.medium,
      );
      return;
    }
    final scene = ctx.chartScene?.call(o, bounds.width, bounds.height);
    if (scene == null || scene.width <= 0) return;
    _c.save();
    _c.translate(bounds.left, bounds.top);
    ChartScenePainter(
      scene,
      scale: bounds.width / scene.width,
    ).paint(_c, bounds.size);
    _c.restore();
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
    _c.save();
    final bounds = Rect.fromLTWH(x, top, w, h);
    _c.clipRect(bounds);
    _object(o, bounds);
    _c.restore();
  }

  void _notesPage() {
    final m = ctx.measurer;
    var y = spec.printableTop;
    for (final line in spec.noteLines) {
      final style = CellTextStyle(
        family: ctx.defaultFamily,
        size: line.heading
            ? PrintMetrics.notesHeadingFontPt
            : PrintMetrics.notesFontPt,
        bold: line.heading,
      );
      final lh = line.heading
          ? PrintMetrics.notesHeadingPt
          : PrintMetrics.notesLinePt;
      final baseline = y + lh / 2 + (m.ascent(style) - m.descent(style)) / 2;
      _text(
        line.text,
        style,
        spec.printableLeft + (line.continuation ? 12 : 0),
        baseline,
        _black,
        width: m.width(line.text, style),
      );
      y += lh;
    }
  }
}

final class _Slot {
  const _Slot(this.index, this.pos, this.size, this.region);
  final int index;
  final double pos;
  final double size;
  final int region;
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
  final int r0;
  final int c0;
  final int r1;
  final int c1;
  final int row;
  final int col;
  final GridRect? merge;
  final bool showContent;
}

final class _Span {
  const _Span(this.start, this.end, this.style, this.format);
  final int start;
  final int end;
  final CellTextStyle style;
  final Map<String, Object?> format;
}

final class _Seg {
  const _Seg(this.text, this.style, this.format);
  final String text;
  final CellTextStyle style;
  final Map<String, Object?> format;
}
