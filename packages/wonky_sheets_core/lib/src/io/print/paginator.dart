import 'dart:math' as math;

import '../../addressing/grid_geometry.dart';
import '../../engine_bridge/model_cell_source.dart';
import '../../formula/model/workbook_view.dart';
import '../../model/axis_index.dart';
import '../../model/events.dart';
import '../../model/grid_range.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../../model/workbook_model.dart';
import 'cell_display.dart';
import 'cell_text_layout.dart';
import 'paper_size.dart';
import 'print_settings.dart';

/// What to print (11 §7.2 *Print scope*).
enum PrintScope { currentSheet, workbook, selection, namedRange }

/// A print/PDF job.
final class PrintJob {
  /// Creates a job.
  const PrintJob({
    this.scope = PrintScope.currentSheet,
    this.sheetId,
    this.selection,
    this.namedRange,
    this.settingsBySheet = const {},
    this.settingsOverride,
  });

  final PrintScope scope;

  /// Current sheet ([PrintScope.currentSheet]; default: first visible sheet).
  final String? sheetId;

  /// Selected cells ([PrintScope.selection]).
  final ResolvedRange? selection;

  /// Named range name ([PrintScope.namedRange]).
  final String? namedRange;

  /// Per-sheet settings (e.g. local viewer overrides); missing sheets use
  /// their stored `printSettingsJson`.
  final Map<String, PrintSettings> settingsBySheet;

  /// Settings applied to every sheet (*Apply to all sheets*).
  final PrintSettings? settingsOverride;

  /// Settings used for [sheet].
  PrintSettings settingsFor(SheetModel sheet, String locale) =>
      settingsOverride ??
      settingsBySheet[sheet.id] ??
      PrintSettings.parse(sheet.record?.printSettingsJson, locale: locale);
}

/// Kind of page.
enum PageKind { cells, chart, notes, blank }

/// Layout constants shared by the paginator and the renderers.
abstract final class PrintMetrics {
  /// Header/footer band height when it has content (0.3 in).
  static const double headerFooterHeightPt = 21.6;

  /// Header/footer font size.
  static const double headerFooterFontPt = 9;

  /// Column-heading band height and row-heading width (px at 100 %).
  static const double headingHeightPx = 20;
  static const double headingWidthPx = 46;

  /// Notes pages: heading and entry line heights, font sizes (pt).
  static const double notesHeadingPt = 20;
  static const double notesLinePt = 13;
  static const double notesFontPt = 10;
  static const double notesHeadingFontPt = 12;

  /// Maximum pages per job and the preview warning threshold (11 §7.3).
  static const int maxPages = 1000;
  static const int warnPages = 200;
}

/// One line of a notes page.
final class NoteLine {
  /// Creates a line.
  const NoteLine(this.text, {this.heading = false, this.continuation = false});

  final String text;

  /// The `Notes · <sheet>` title line.
  final bool heading;

  /// A wrapped continuation of the previous entry (indented).
  final bool continuation;

  @override
  String toString() => heading ? '# $text' : text;
}

/// One printed page (11 §7.3 step 8). Sizes are points unless named `Px`
/// (grid px at 100 % zoom; 1 px = 0.75 pt × [scale]).
final class PageSpec {
  /// Creates a page.
  const PageSpec({
    required this.kind,
    required this.sheetId,
    required this.sheetName,
    required this.pageNumber,
    required this.totalPages,
    required this.pageInSheet,
    required this.settings,
    required this.pageWidth,
    required this.pageHeight,
    required this.scale,
    required this.originX,
    required this.originY,
    required this.contentWidth,
    required this.contentHeight,
    required this.printableLeft,
    required this.printableTop,
    required this.printableWidth,
    required this.printableHeight,
    this.headerHeight = 0,
    this.footerHeight = 0,
    this.rows = const [],
    this.rowHeightsPx = const [],
    this.cols = const [],
    this.colWidthsPx = const [],
    this.repeatRows = const [],
    this.repeatRowHeightsPx = const [],
    this.repeatCols = const [],
    this.repeatColWidthsPx = const [],
    this.rowIds = const [],
    this.colIds = const [],
    this.headings = false,
    this.objectId,
    this.noteLines = const [],
  });

  final PageKind kind;
  final String sheetId;
  final String sheetName;

  /// Page number in the job (1-based) and job page count (`{page}`/`{pages}`).
  final int pageNumber;
  final int totalPages;

  /// 0-based page index within the sheet.
  final int pageInSheet;
  final PrintSettings settings;

  /// Paper size, orientation applied.
  final double pageWidth;
  final double pageHeight;

  /// Content scale (1 = 100 %).
  final double scale;

  /// Top-left of the content (headings + repeated + body cells) from the
  /// page's top-left, and its scaled size.
  final double originX;
  final double originY;
  final double contentWidth;
  final double contentHeight;

  /// Printable area (inside margins and header/footer bands).
  final double printableLeft;
  final double printableTop;
  final double printableWidth;
  final double printableHeight;
  final double headerHeight;
  final double footerHeight;

  /// Body rows / columns (visible indices, in order) and their sizes.
  final List<int> rows;
  final List<double> rowHeightsPx;
  final List<int> cols;
  final List<double> colWidthsPx;

  /// Rows / columns repeated at the top / left of the page.
  final List<int> repeatRows;
  final List<double> repeatRowHeightsPx;
  final List<int> repeatCols;
  final List<double> repeatColWidthsPx;

  /// Ids of [rows] / [cols].
  final List<String> rowIds;
  final List<String> colIds;

  /// Whether row/column headings are printed.
  final bool headings;

  /// Chart object of a [PageKind.chart] page.
  final String? objectId;

  /// Lines of a [PageKind.notes] page.
  final List<NoteLine> noteLines;

  /// First / last body row index (−1 when none).
  int get rowStart => rows.isEmpty ? -1 : rows.first;
  int get rowEnd => rows.isEmpty ? -1 : rows.last;
  int get colStart => cols.isEmpty ? -1 : cols.first;
  int get colEnd => cols.isEmpty ? -1 : cols.last;

  /// Ids of the first / last body row and column.
  String? get rowStartId => rowIds.isEmpty ? null : rowIds.first;
  String? get rowEndId => rowIds.isEmpty ? null : rowIds.last;
  String? get colStartId => colIds.isEmpty ? null : colIds.first;
  String? get colEndId => colIds.isEmpty ? null : colIds.last;

  /// Compact description for tests and logs, e.g.
  /// `Sheet1 1/2 cells r0-9 c0-4 rr[0] rc[] s1.00`.
  String describe() {
    String span(List<int> l) => l.isEmpty ? '-' : '${l.first}-${l.last}';
    final base = '$sheetName $pageNumber/$totalPages ${kind.name}';
    return switch (kind) {
      PageKind.cells =>
        '$base r${span(rows)} c${span(cols)} rr[${repeatRows.join(',')}] '
            'rc[${repeatCols.join(',')}] s${scale.toStringAsFixed(2)}',
      PageKind.chart => '$base $objectId',
      PageKind.notes => '$base ${noteLines.length} lines',
      PageKind.blank => base,
    };
  }

  /// Copy with page numbers.
  PageSpec _numbered(int number, int total) => PageSpec(
    kind: kind,
    sheetId: sheetId,
    sheetName: sheetName,
    pageNumber: number,
    totalPages: total,
    pageInSheet: pageInSheet,
    settings: settings,
    pageWidth: pageWidth,
    pageHeight: pageHeight,
    scale: scale,
    originX: originX,
    originY: originY,
    contentWidth: contentWidth,
    contentHeight: contentHeight,
    printableLeft: printableLeft,
    printableTop: printableTop,
    printableWidth: printableWidth,
    printableHeight: printableHeight,
    headerHeight: headerHeight,
    footerHeight: footerHeight,
    rows: rows,
    rowHeightsPx: rowHeightsPx,
    cols: cols,
    colWidthsPx: colWidthsPx,
    repeatRows: repeatRows,
    repeatRowHeightsPx: repeatRowHeightsPx,
    repeatCols: repeatCols,
    repeatColWidthsPx: repeatColWidthsPx,
    rowIds: rowIds,
    colIds: colIds,
    headings: headings,
    objectId: objectId,
    noteLines: noteLines,
  );

  @override
  String toString() => 'PageSpec(${describe()})';
}

/// Kinds of pagination warnings.
enum PrintWarningKind {
  /// More than 200 pages (preview warning).
  manyPages,

  /// The job was cut at 1,000 pages.
  pageLimit,

  /// Repeated rows / columns exceed 50 % of the page; repeated on page 1 only.
  repeatRowsTooTall,
  repeatColsTooWide,

  /// A single column / row is larger than the page and is clipped.
  columnTooWide,
  rowTooTall,

  /// The named range of the job doesn't resolve.
  namedRangeNotFound,

  /// Nothing to print.
  empty,
}

/// A warning shown in the print panel.
final class PrintWarning {
  /// Creates a warning.
  const PrintWarning(this.kind, this.message, {this.sheetId, this.count});

  final PrintWarningKind kind;
  final String message;
  final String? sheetId;
  final int? count;

  @override
  String toString() => 'PrintWarning(${kind.name}: $message)';
}

/// Result of [Paginator.paginate].
final class PaginationResult {
  /// Creates a result.
  const PaginationResult(
    this.pages,
    this.warnings, {
    required this.requestedPages,
  });

  final List<PageSpec> pages;
  final List<PrintWarning> warnings;

  /// Pages before the 1,000-page cap.
  final int requestedPages;

  /// Whether the job has [kind] warnings.
  bool hasWarning(PrintWarningKind kind) => warnings.any((w) => w.kind == kind);
}

/// Deterministic pagination of print jobs (11 §7.3).
abstract final class Paginator {
  /// Paginates [job]. Row heights are the grid's natural heights (explicit or
  /// measured auto heights), [rowHeightPx] overrides them; with [source] and
  /// [measurer] rows without explicit height are auto-fitted to wrapped and
  /// multi-line text (03 §13.6).
  static PaginationResult paginate(
    WorkbookModel model,
    PrintJob job, {
    CellSource? source,
    CellTextMeasurer? measurer,
    double Function(String sheetId, int row)? rowHeightPx,
    String? locale,
  }) {
    final loc = locale ?? model.spreadsheet.locale;
    final warnings = <PrintWarning>[];
    final drafts = <PageSpec>[];
    var requested = 0;

    final targets = <(SheetModel, GridRect?)>[];
    switch (job.scope) {
      case PrintScope.selection:
        final sel = job.selection;
        final s = sel == null ? null : model.sheet(sel.sheetId);
        if (s != null && sel != null) {
          final grid = s.gridRect;
          targets.add((s, grid == null ? null : sel.rect.intersection(grid)));
        }
      case PrintScope.namedRange:
        final n = job.namedRange == null
            ? null
            : model.namedRange(job.namedRange!);
        final g = n?.rangeJson == null
            ? null
            : GridRange.tryParse(n!.rangeJson);
        final rr = g == null ? null : model.resolve(g);
        if (rr == null) {
          warnings.add(
            PrintWarning(
              PrintWarningKind.namedRangeNotFound,
              'The named range "${job.namedRange}" doesn\'t exist.',
            ),
          );
        } else {
          targets.add((model.sheet(rr.sheetId)!, rr.rect));
        }
      case PrintScope.currentSheet:
        final s = job.sheetId == null
            ? (model.visibleSheets.isEmpty ? null : model.visibleSheets.first)
            : model.sheet(job.sheetId!);
        if (s != null) targets.add((s, null));
      case PrintScope.workbook:
        for (final s in model.visibleSheets) {
          targets.add((s, null));
        }
    }

    for (final (sheet, explicitRect) in targets) {
      final settings = job.settingsFor(sheet, loc);
      final ctx = _SheetContext(
        model,
        sheet,
        settings,
        source,
        measurer,
        rowHeightPx,
        loc,
      );
      final pages = sheet.record?.kind == SheetKind.chart
          ? ctx.chartPages()
          : ctx.cellPages(
              explicitRect ?? ctx.printArea(job.scope == PrintScope.selection),
              warnings,
              onlySheet: targets.length == 1,
            );
      requested += ctx.requested;
      drafts.addAll(pages);
    }
    if (drafts.isEmpty) {
      warnings.add(
        const PrintWarning(
          PrintWarningKind.empty,
          'There is nothing to print.',
        ),
      );
    }
    if (requested > PrintMetrics.warnPages) {
      warnings.add(
        PrintWarning(
          PrintWarningKind.manyPages,
          'This will print ${_thousands(requested)} pages',
          count: requested,
        ),
      );
    }
    var pages = drafts;
    if (pages.length > PrintMetrics.maxPages) {
      pages = pages.sublist(0, PrintMetrics.maxPages);
    }
    if (requested > PrintMetrics.maxPages) {
      warnings.add(
        PrintWarning(
          PrintWarningKind.pageLimit,
          'Only the first ${_thousands(PrintMetrics.maxPages)} pages are printed.',
          count: requested,
        ),
      );
    }
    final total = pages.length;
    return PaginationResult(
      [for (var i = 0; i < total; i++) pages[i]._numbered(i + 1, total)],
      warnings,
      requestedPages: requested,
    );
  }

  static String _thousands(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// Whether row/column [i] is skipped when printing: user-hidden, collapsed
  /// group, basic filter or slicer (not filter views, 11 §7.3).
  static bool hiddenForPrint(AxisIndex axis, int i) =>
      axis.isUserHidden(i) ||
      axis.isHiddenBy(HiddenLayers.groups, i) ||
      axis.isHiddenBy(HiddenLayers.filter, i) ||
      axis.isHiddenBy(HiddenLayers.slicer, i);

  /// The default print range of a sheet: from A1 to the bounding box of
  /// content cells, merges and embedded objects (null when empty).
  static GridRect? usedRange(SheetModel sheet) {
    final grid = sheet.gridRect;
    if (grid == null) return null;
    var bottom = -1;
    var right = -1;
    final used = sheet.usedRect();
    if (used != null) {
      bottom = used.bottom;
      right = used.right;
    }
    for (final id in sheet.merges.keys) {
      for (final r in sheet.ruleRects(RuleKind.merge, id)) {
        bottom = math.max(bottom, r.bottom);
        right = math.max(right, r.right);
      }
    }
    for (final o in sheet.objects.values) {
      final p = PrintObjectPlacement.of(sheet, o);
      if (p == null || p.ownSheet) continue;
      final c = p.coveredCells(sheet);
      bottom = math.max(bottom, c.bottom);
      right = math.max(right, c.right);
    }
    if (bottom < 0 || right < 0) return null;
    return GridRect(
      0,
      0,
      math.min(bottom, grid.bottom),
      math.min(right, grid.right),
    );
  }
}

final class _SheetContext {
  _SheetContext(
    this.model,
    this.sheet,
    this.settings,
    this.source,
    this.measurer,
    this.rowHeightPx,
    this.locale,
  );

  final WorkbookModel model;
  final SheetModel sheet;
  final PrintSettings settings;
  final CellSource? source;
  final CellTextMeasurer? measurer;
  final double Function(String, int)? rowHeightPx;
  final String locale;
  int requested = 0;

  late final double pageW = settings.pageWidthPt;
  late final double pageH = settings.pageHeightPt;
  late final double headerH = _bandHeight(
    settings.headerFooter.effectiveHeader,
  );
  late final double footerH = _bandHeight(
    settings.headerFooter.effectiveFooter,
  );
  late final double left = settings.margins.leftPt;
  late final double top = settings.margins.topPt + headerH;
  late final double availW = math.max(
    1,
    pageW - settings.margins.leftPt - settings.margins.rightPt,
  );
  late final double availH = math.max(
    1,
    pageH -
        settings.margins.topPt -
        settings.margins.bottomPt -
        headerH -
        footerH,
  );

  static double _bandHeight(HeaderFooterSections s) =>
      s.isEmpty ? 0 : PrintMetrics.headerFooterHeightPt;

  GridRect? printArea(bool selectionScope) {
    final area = settings.printArea;
    if (!selectionScope && area != null && area.sheetId == sheet.id) {
      final rr = sheet.resolve(area);
      if (rr != null) return rr.rect;
    }
    return Paginator.usedRange(sheet);
  }

  PageSpec _page({
    required PageKind kind,
    required int index,
    double scale = 1,
    double contentW = 0,
    double contentH = 0,
    List<int> rows = const [],
    List<double> rowH = const [],
    List<int> cols = const [],
    List<double> colW = const [],
    List<int> rRows = const [],
    List<double> rRowH = const [],
    List<int> rCols = const [],
    List<double> rColW = const [],
    String? objectId,
    List<NoteLine> notes = const [],
  }) {
    final dx = switch (settings.hAlign) {
      PrintHAlign.left => 0.0,
      PrintHAlign.center => (availW - contentW) / 2,
      PrintHAlign.right => availW - contentW,
    };
    final dy = switch (settings.vAlign) {
      PrintVAlign.top => 0.0,
      PrintVAlign.middle => (availH - contentH) / 2,
      PrintVAlign.bottom => availH - contentH,
    };
    return PageSpec(
      kind: kind,
      sheetId: sheet.id,
      sheetName: sheet.name,
      pageNumber: 0,
      totalPages: 0,
      pageInSheet: index,
      settings: settings,
      pageWidth: pageW,
      pageHeight: pageH,
      scale: scale,
      originX: left + math.max(0, dx),
      originY: top + math.max(0, dy),
      contentWidth: contentW,
      contentHeight: contentH,
      printableLeft: left,
      printableTop: top,
      printableWidth: availW,
      printableHeight: availH,
      headerHeight: headerH,
      footerHeight: footerH,
      rows: rows,
      rowHeightsPx: rowH,
      cols: cols,
      colWidthsPx: colW,
      repeatRows: rRows,
      repeatRowHeightsPx: rRowH,
      repeatCols: rCols,
      repeatColWidthsPx: rColW,
      rowIds: [for (final r in rows) sheet.rows.idAt(r)],
      colIds: [for (final c in cols) sheet.columns.idAt(c)],
      headings: settings.headings && kind == PageKind.cells,
      objectId: objectId,
      noteLines: notes,
    );
  }

  List<PageSpec> chartPages() {
    final objs = sheet.objects.values.toList()
      ..sort((a, b) {
        final z = a.zIndex.compareTo(b.zIndex);
        return z != 0 ? z : a.id.compareTo(b.id);
      });
    final out = <PageSpec>[];
    for (final o in objs) {
      out.add(
        _page(
          kind: PageKind.chart,
          index: out.length,
          contentW: availW,
          contentH: availH,
          objectId: o.id,
        ),
      );
    }
    requested += out.length;
    return out;
  }

  double _rowHeight(int r, GridRect range) {
    final o = rowHeightPx?.call(sheet.id, r);
    if (o != null) return o;
    final natural = sheet.rows.naturalSizeAt(r);
    if (source == null ||
        measurer == null ||
        sheet.rows.explicitSizeAt(r) != null) {
      return natural;
    }
    return math.max(natural, _autoFit(r, range));
  }

  CellDisplayResolver? _resolver;

  double _autoFit(int r, GridRect range) {
    var best = 0.0;
    final cells = sheet.cellsIn(
      GridRect(r, range.left, r, range.right),
      contentOnly: true,
    );
    for (final (row, col, cell) in cells) {
      final content = cell.decoded;
      if (content == null) continue;
      final text = content.plainText;
      if ((text == null || !text.contains('\n')) && !_mayNeedHeight(row, col)) {
        continue;
      }
      if (sheet.mergeAt(row, col) != null) continue;
      _resolver ??= CellDisplayResolver(model, source!, locale: locale);
      final d = _resolver!.display(sheet.id, row, col);
      if (d.text.isEmpty) continue;
      final f = d.format;
      final layout = CellTextLayout.layout(
        text: d.text,
        style: CellTextStyle(
          family: f.fontFamily,
          size: f.fontSize * 4 / 3,
          bold: f.bold,
          italic: f.italic,
        ),
        measurer: measurer!,
        cellWidth: sheet.columns.naturalSizeAt(col),
        cellHeight: 0,
        wrap: f.wrap,
        align: d.hAlign,
        rotation: f.rotation,
        numberLike: d.numberLike,
      );
      best = math.max(best, layout.requiredHeight);
    }
    return best;
  }

  bool _mayNeedHeight(int row, int col) {
    final f = model.explicitFormatChain(sheet.id, row, col).toMap();
    return f['wrap'] == 'wrap' ||
        (f['rotation'] is int && f['rotation'] != 0) ||
        (f['fontSize'] is double && (f['fontSize'] as double) > 12);
  }

  List<PageSpec> cellPages(
    GridRect? range,
    List<PrintWarning> warnings, {
    required bool onlySheet,
  }) {
    final grid = sheet.gridRect;
    final rect = range == null || grid == null
        ? null
        : range.intersection(grid);
    final visRows = rect == null
        ? const <int>[]
        : [
            for (var r = rect.top; r <= rect.bottom; r++)
              if (!Paginator.hiddenForPrint(sheet.rows, r)) r,
          ];
    final visCols = rect == null
        ? const <int>[]
        : [
            for (var c = rect.left; c <= rect.right; c++)
              if (!Paginator.hiddenForPrint(sheet.columns, c)) c,
          ];
    if (visRows.isEmpty || visCols.isEmpty) {
      if (onlySheet) {
        requested += 1;
        return [_page(kind: PageKind.blank, index: 0)];
      }
      return const [];
    }

    // Repeated rows / columns.
    List<int> repeatOf(IdSpan? span, int frozen, AxisIndex axis) {
      if (span != null) {
        final a = axis.indexOf(span.start);
        final b = axis.indexOf(span.end);
        if (a >= 0 && b >= 0) {
          return [
            for (var i = math.min(a, b); i <= math.max(a, b); i++)
              if (!Paginator.hiddenForPrint(axis, i)) i,
          ];
        }
        return const [];
      }
      if (!settings.repeatFrozen || frozen <= 0) return const [];
      return [
        for (var i = 0; i < frozen && i < axis.length; i++)
          if (!Paginator.hiddenForPrint(axis, i)) i,
      ];
    }

    var rRows = repeatOf(
      settings.repeatRows,
      sheet.record?.frozenRows ?? 0,
      sheet.rows,
    );
    var rCols = repeatOf(
      settings.repeatCols,
      sheet.record?.frozenColumns ?? 0,
      sheet.columns,
    );
    var bodyRows = [
      for (final r in visRows)
        if (!rRows.contains(r)) r,
    ];
    var bodyCols = [
      for (final c in visCols)
        if (!rCols.contains(c)) c,
    ];
    if (bodyRows.isEmpty) {
      rRows = const [];
      bodyRows = visRows;
    }
    if (bodyCols.isEmpty) {
      rCols = const [];
      bodyCols = visCols;
    }

    final rh = <int, double>{};
    double h(int r) => rh.putIfAbsent(r, () => _rowHeight(r, rect!));
    double w(int c) => sheet.columns.naturalSizeAt(c);
    double sum(Iterable<double> l) => l.fold(0.0, (a, b) => a + b);

    final headW = settings.headings ? PrintMetrics.headingWidthPx : 0.0;
    final headH = settings.headings ? PrintMetrics.headingHeightPx : 0.0;
    final totalW = headW + sum(rCols.map(w)) + sum(bodyCols.map(w));
    final totalH = headH + sum(rRows.map(h)) + sum(bodyRows.map(h));
    const k = PrintUnits.pointsPerPx;
    var scale = switch (settings.scaleMode) {
      PrintScaleMode.normal => 1.0,
      PrintScaleMode.custom => settings.scalePercent / 100,
      PrintScaleMode.fitWidth => availW / (totalW * k),
      PrintScaleMode.fitHeight => availH / (totalH * k),
      PrintScaleMode.fitPage => math.min(
        availW / (totalW * k),
        availH / (totalH * k),
      ),
    };
    if (settings.scaleMode != PrintScaleMode.custom) {
      scale = math.min(1.0, scale);
    }
    scale = scale.clamp(0.1, 4.0).toDouble();

    final pageWPx = availW / (k * scale);
    final pageHPx = availH / (k * scale);
    var repeatW = sum(rCols.map(w));
    var repeatH = sum(rRows.map(h));
    if (rRows.isNotEmpty && repeatH > 0.5 * (pageHPx - headH)) {
      warnings.add(
        PrintWarning(
          PrintWarningKind.repeatRowsTooTall,
          'Frozen rows are too tall to repeat on every page of "${sheet.name}".',
          sheetId: sheet.id,
        ),
      );
      bodyRows = visRows;
      rRows = const [];
      repeatH = 0;
    }
    if (rCols.isNotEmpty && repeatW > 0.5 * (pageWPx - headW)) {
      warnings.add(
        PrintWarning(
          PrintWarningKind.repeatColsTooWide,
          'Frozen columns are too wide to repeat on every page of "${sheet.name}".',
          sheetId: sheet.id,
        ),
      );
      bodyCols = visCols;
      rCols = const [];
      repeatW = 0;
    }

    Set<int> breaks(List<String> ids, AxisIndex axis) => {
      for (final id in ids)
        if (axis.indexOf(id) case final int i when i >= 0) i,
    };

    final rowChunks = _chunks(
      bodyRows,
      h,
      pageHPx - headH - repeatH,
      breaks(settings.rowBreaks, sheet.rows),
      () => warnings.add(
        PrintWarning(
          PrintWarningKind.rowTooTall,
          'A row of "${sheet.name}" is taller than the page and is cut off.',
          sheetId: sheet.id,
        ),
      ),
    );
    final colChunks = _chunks(
      bodyCols,
      w,
      pageWPx - headW - repeatW,
      breaks(settings.colBreaks, sheet.columns),
      () => warnings.add(
        PrintWarning(
          PrintWarningKind.columnTooWide,
          'A column of "${sheet.name}" is wider than the page and is cut off.',
          sheetId: sheet.id,
        ),
      ),
    );
    final order = <(List<int>, List<int>)>[];
    if (settings.pageOrder == PageOrder.downThenOver) {
      for (final cc in colChunks) {
        for (final rc in rowChunks) {
          order.add((rc, cc));
        }
      }
    } else {
      for (final rc in rowChunks) {
        for (final cc in colChunks) {
          order.add((rc, cc));
        }
      }
    }
    requested += order.length;
    final out = <PageSpec>[];
    final rRowH = [for (final r in rRows) h(r)];
    final rColW = [for (final c in rCols) w(c)];
    for (final (rc, cc) in order) {
      if (out.length >= PrintMetrics.maxPages) break;
      final rowH = [for (final r in rc) h(r)];
      final colW = [for (final c in cc) w(c)];
      final cw = (headW + repeatW + sum(colW)) * k * scale;
      final ch = (headH + repeatH + sum(rowH)) * k * scale;
      out.add(
        _page(
          kind: PageKind.cells,
          index: out.length,
          scale: scale,
          contentW: math.min(cw, availW),
          contentH: math.min(ch, availH),
          rows: rc,
          rowH: rowH,
          cols: cc,
          colW: colW,
          rRows: rRows,
          rRowH: rRowH,
          rCols: rCols,
          rColW: rColW,
        ),
      );
    }
    if (settings.notes) out.addAll(_notesPages(visRows, visCols, out.length));
    return out;
  }

  /// Greedy chunks of [items] with sizes [size] into pages of [limit]; a new
  /// chunk also starts before custom [breaks] (indices; deleted ids are
  /// absent, breaks on hidden entries apply before the next visible one).
  static List<List<int>> _chunks(
    List<int> items,
    double Function(int) size,
    double limit,
    Set<int> breaks,
    void Function() tooLarge,
  ) {
    final out = <List<int>>[];
    var cur = <int>[];
    var acc = 0.0;
    var warned = false;
    int? prev;
    for (final i in items) {
      final s = size(i);
      final forced =
          cur.isNotEmpty && breaks.any((b) => b > (prev ?? -1) && b <= i);
      if (forced || (cur.isNotEmpty && acc + s > limit + 1e-6)) {
        out.add(cur);
        cur = <int>[];
        acc = 0;
      }
      if (s > limit + 1e-6 && !warned) {
        warned = true;
        tooLarge();
      }
      cur.add(i);
      acc += s;
      prev = i;
    }
    if (cur.isNotEmpty) out.add(cur);
    return out;
  }

  List<PageSpec> _notesPages(List<int> rows, List<int> cols, int startIndex) {
    final rowSet = rows.toSet();
    final colSet = cols.toSet();
    final entries = <(int, int, String)>[];
    for (final c in sheet.cells.all) {
      final note = c.note;
      if (note == null || note.isEmpty) continue;
      final r = sheet.rows.indexOf(c.rowId);
      final col = sheet.columns.indexOf(c.columnId);
      if (!rowSet.contains(r) || !colSet.contains(col)) continue;
      entries.add((r, col, note));
    }
    if (entries.isEmpty) return const [];
    entries.sort(
      (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
    );
    final m = measurer ?? const ApproximateTextMeasurer();
    const style = CellTextStyle(
      family: 'Helvetica',
      size: PrintMetrics.notesFontPt,
    );
    final lines = <NoteLine>[NoteLine('Notes · ${sheet.name}', heading: true)];
    for (final (r, c, note) in entries) {
      final text = '${CellPos(r, c).a1}: ${note.replaceAll('\r\n', '\n')}';
      final layout = CellTextLayout.layout(
        text: text,
        style: style,
        measurer: m,
        cellWidth: availW,
        cellHeight: 0,
        wrap: WrapStrategy.wrap,
        paddingX: 0,
        paddingY: 0,
      );
      for (var i = 0; i < layout.lines.length; i++) {
        lines.add(
          NoteLine(layout.lineText(layout.lines[i]), continuation: i > 0),
        );
      }
    }
    final pages = <List<NoteLine>>[];
    var cur = <NoteLine>[];
    var used = 0.0;
    for (final l in lines) {
      final lh = l.heading
          ? PrintMetrics.notesHeadingPt
          : PrintMetrics.notesLinePt;
      if (cur.isNotEmpty && used + lh > availH) {
        pages.add(cur);
        cur = <NoteLine>[];
        used = 0;
      }
      cur.add(l);
      used += lh;
    }
    if (cur.isNotEmpty) pages.add(cur);
    requested += pages.length;
    return [
      for (var i = 0; i < pages.length; i++)
        _page(
          kind: PageKind.notes,
          index: startIndex + i,
          contentW: availW,
          contentH: availH,
          notes: pages[i],
        ),
    ];
  }
}
