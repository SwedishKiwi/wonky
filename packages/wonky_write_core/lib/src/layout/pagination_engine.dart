/// The line-level pagination engine (07 §7), used by PDF, print preview and
/// server-side page counts. Measurer-agnostic: callers provide
/// [BlockMetrics].
library;

import 'dart:math' as math;

/// Insets in points.
final class EdgeInsetsPt {
  /// Creates insets.
  const EdgeInsetsPt({
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.left = 0,
  });

  /// All equal.
  const EdgeInsetsPt.all(double v) : this(top: v, right: v, bottom: v, left: v);

  /// Top.
  final double top;

  /// Right.
  final double right;

  /// Bottom.
  final double bottom;

  /// Left.
  final double left;
}

/// Geometry of one page kind (in pt).
final class PageGeometry {
  /// Creates geometry.
  const PageGeometry({
    required this.pageWidth,
    required this.pageHeight,
    required this.margins,
    this.headerHeight = 0,
    this.footerHeight = 0,
    this.headerDistance = 0,
    this.footerDistance = 0,
  });

  /// Page width.
  final double pageWidth;

  /// Page height.
  final double pageHeight;

  /// Margins.
  final EdgeInsetsPt margins;

  /// Measured header slot height (0 = no header).
  final double headerHeight;

  /// Measured footer slot height (0 = no footer).
  final double footerHeight;

  /// Header distance from the top edge.
  final double headerDistance;

  /// Footer distance from the bottom edge.
  final double footerDistance;

  /// Top of the content box.
  double get contentTop => headerHeight > 0
      ? math.max(margins.top, headerDistance + headerHeight + 6)
      : margins.top;

  /// Distance of the content box bottom from the page bottom.
  double get contentBottom => footerHeight > 0
      ? math.max(margins.bottom, footerDistance + footerHeight + 6)
      : margins.bottom;

  /// Content box height.
  double get contentHeight => pageHeight - contentTop - contentBottom;

  /// Content box width.
  double get contentWidth => pageWidth - margins.left - margins.right;
}

/// Heights of a table row: the row height plus per-cell line heights (for
/// splitting rows taller than a page).
final class RowMetrics {
  /// Creates row metrics.
  const RowMetrics(
    this.height, {
    this.cellLineHeights = const [],
    this.cellPadding = 0,
  });

  /// Full row height.
  final double height;

  /// Line heights per cell.
  final List<List<double>> cellLineHeights;

  /// Vertical padding added to a row slice (top + bottom).
  final double cellPadding;
}

/// Measured metrics of one block.
final class BlockMetrics {
  /// Creates metrics. Exactly one of [lineHeights], [fixedHeight], [rows]
  /// describes the content.
  const BlockMetrics({
    required this.blockIndex,
    this.spaceBefore = 0,
    this.spaceAfter = 0,
    this.lineHeights,
    this.fixedHeight,
    this.rows,
    this.headerRows = 1,
    this.keepWithNext = false,
    this.pageBreakBefore = false,
    this.kind = BlockMetricsKind.text,
    this.captionHeight = 0,
    this.paddingTop = 0,
    this.paddingBottom = 0,
  });

  /// Index of the block in the IR.
  final int blockIndex;

  /// Space before (theme).
  final double spaceBefore;

  /// Space after (theme).
  final double spaceAfter;

  /// Line heights of a splittable text-like block.
  final List<double>? lineHeights;

  /// Height of an unsplittable block (image incl. caption, rule).
  final double? fixedHeight;

  /// Table rows.
  final List<RowMetrics>? rows;

  /// Number of header rows (repeated on continuation pages).
  final int headerRows;

  /// Keep on the same page as the next block (headings).
  final bool keepWithNext;

  /// Start on a new page.
  final bool pageBreakBefore;

  /// Kind (affects rules at the top of a page, image scaling).
  final BlockMetricsKind kind;

  /// Caption height of images (kept when scaling).
  final double captionHeight;

  /// Box padding above the lines (code blocks, quotes); repeated per slice.
  final double paddingTop;

  /// Box padding below the lines; repeated per slice.
  final double paddingBottom;

  /// Total content height.
  double get height {
    if (fixedHeight != null) return fixedHeight!;
    if (rows != null) return rows!.fold(0.0, (s, r) => s + r.height);
    return paddingTop +
        (lineHeights ?? const [0]).fold(0.0, (s, h) => s + h) +
        paddingBottom;
  }
}

/// Block kinds relevant for pagination.
enum BlockMetricsKind {
  /// Text-like (paragraph, heading, list item, quote, code).
  text,

  /// Image (never split; scaled down when taller than a page).
  image,

  /// Rule (zero height at the top of a page).
  rule,

  /// Table.
  table,
}

/// A slice of a block placed on a page.
final class PlacedSlice {
  /// Creates a slice.
  const PlacedSlice({
    required this.blockIndex,
    required this.y,
    required this.height,
    this.lineFrom,
    this.lineTo,
    this.rowFrom,
    this.rowTo,
    this.repeatHeader = false,
    this.isContinuation = false,
    this.continues = false,
    this.scale = 1,
    this.rowSplit,
  });

  /// Block index.
  final int blockIndex;

  /// Top of the slice relative to the content box (pt).
  final double y;

  /// Height of the slice.
  final double height;

  /// First line (text blocks).
  final int? lineFrom;

  /// End line, exclusive (text blocks).
  final int? lineTo;

  /// First body row (tables).
  final int? rowFrom;

  /// End row, exclusive (tables).
  final int? rowTo;

  /// Whether the table header is repeated at the top of this slice.
  final bool repeatHeader;

  /// Whether this slice continues a block from a previous page.
  final bool isContinuation;

  /// Whether the block continues on the next page.
  final bool continues;

  /// Scale applied to images taller than the page.
  final double scale;

  /// For a table row split across pages: per-cell line ranges `(from, to)`.
  final List<(int, int)>? rowSplit;

  @override
  String toString() =>
      'Slice(b$blockIndex y=${y.toStringAsFixed(1)} h=${height.toStringAsFixed(1)}'
      '${lineFrom != null ? ' lines $lineFrom-$lineTo' : ''}${rowFrom != null ? ' rows $rowFrom-$rowTo' : ''})';
}

/// One laid-out page.
final class PageLayout {
  /// Creates a page.
  PageLayout(this.index);

  /// 0-based physical page index.
  final int index;

  /// Placed slices in order.
  final List<PlacedSlice> slices = [];
}

/// Result of pagination.
final class PaginationResult {
  /// Creates a result.
  const PaginationResult(this.pages);

  /// Pages.
  final List<PageLayout> pages;

  /// Page index on which block [blockIndex] starts, or -1.
  int pageOfBlock(int blockIndex) {
    for (final p in pages) {
      if (p.slices.any((s) => s.blockIndex == blockIndex)) return p.index;
    }
    return -1;
  }
}

/// Measures IR blocks for pagination (implemented by the PDF measurer and,
/// in the app, by a TextLayout-based measurer).
abstract interface class BlockMeasurer<B> {
  /// Measures [block] at [contentWidth].
  BlockMetrics measure(B block, double contentWidth);
}

/// Greedy pagination with keep-with-next, widow/orphan control (2 lines),
/// table row splitting with header repeat and image scaling (07 §7.2).
final class PaginationEngine {
  /// Creates an engine.
  const PaginationEngine({this.orphans = 2, this.widows = 2});

  /// Minimum lines at the bottom of a page.
  final int orphans;

  /// Minimum lines at the top of a page.
  final int widows;

  /// Paginates [blocks] into pages of [geometry] ([firstPage] for page 0
  /// when it differs, e.g. a different first-page header).
  PaginationResult paginate(
    List<BlockMetrics> blocks,
    PageGeometry geometry, {
    PageGeometry? firstPage,
  }) {
    final pages = <PageLayout>[];
    var page = PageLayout(0);
    pages.add(page);
    var y = 0.0;
    var prevSpaceAfter = 0.0;
    double capacity() =>
        (page.index == 0 && firstPage != null ? firstPage : geometry)
            .contentHeight;
    bool pageEmpty() => page.slices.isEmpty;

    void newPage() {
      page = PageLayout(pages.length);
      pages.add(page);
      y = 0;
      prevSpaceAfter = 0;
    }

    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b.pageBreakBefore && !pageEmpty()) newPage();
      var gap = pageEmpty() ? 0.0 : math.max(prevSpaceAfter, b.spaceBefore);

      // Keep-with-next group.
      if (b.keepWithNext) {
        var groupHeight = 0.0;
        var j = i;
        var prevAfter = 0.0;
        while (j < blocks.length && blocks[j].keepWithNext) {
          groupHeight +=
              (j == i ? 0 : math.max(prevAfter, blocks[j].spaceBefore)) +
              blocks[j].height;
          prevAfter = blocks[j].spaceAfter;
          j++;
        }
        if (j < blocks.length) {
          final next = blocks[j];
          groupHeight +=
              math.max(prevAfter, next.spaceBefore) + _minChunk(next);
        }
        final remaining = capacity() - y - gap;
        if (groupHeight > remaining &&
            !pageEmpty() &&
            groupHeight <= capacity()) {
          newPage();
          gap = 0;
        }
      }

      switch (b.kind) {
        case BlockMetricsKind.rule:
          if (pageEmpty()) {
            // A rule at the top of a page is dropped visually.
            page.slices.add(
              PlacedSlice(blockIndex: b.blockIndex, y: 0, height: 0),
            );
          } else {
            final h = b.height;
            if (gap + h > capacity() - y) {
              newPage();
              page.slices.add(
                PlacedSlice(blockIndex: b.blockIndex, y: 0, height: 0),
              );
            } else {
              page.slices.add(
                PlacedSlice(blockIndex: b.blockIndex, y: y + gap, height: h),
              );
              y += gap + h;
            }
          }
        case BlockMetricsKind.image:
          var h = b.height;
          var scale = 1.0;
          if (h > capacity()) {
            final imageH = h - b.captionHeight;
            final target = capacity() - b.captionHeight;
            scale = target > 0 && imageH > 0 ? target / imageH : 1;
            h = capacity();
          }
          if (gap + h > capacity() - y && !pageEmpty()) {
            newPage();
            gap = 0;
          }
          page.slices.add(
            PlacedSlice(
              blockIndex: b.blockIndex,
              y: y + gap,
              height: h,
              scale: scale,
            ),
          );
          y += gap + h;
        case BlockMetricsKind.table:
          _placeTable(
            b,
            gap,
            () => y,
            (v) => y = v,
            () => page,
            newPage,
            capacity,
            pageEmpty,
          );
        case BlockMetricsKind.text:
          _placeText(
            b,
            gap,
            () => y,
            (v) => y = v,
            () => page,
            newPage,
            capacity,
            pageEmpty,
          );
      }
      prevSpaceAfter = b.spaceAfter;
    }
    // Never produce trailing empty pages.
    while (pages.length > 1 && pages.last.slices.isEmpty) {
      pages.removeLast();
    }
    return PaginationResult(pages);
  }

  double _minChunk(BlockMetrics b) {
    if (b.rows != null && b.rows!.isNotEmpty) {
      final header = b.rows!
          .take(b.headerRows)
          .fold(0.0, (s, r) => s + r.height);
      final first = b.rows!.length > b.headerRows
          ? b.rows![b.headerRows].height
          : 0.0;
      return header + first;
    }
    final lines = b.lineHeights;
    if (lines == null || lines.length < 4) return b.height;
    return b.paddingTop + lines.take(orphans).fold(0.0, (s, h) => s + h);
  }

  void _placeText(
    BlockMetrics b,
    double gap,
    double Function() getY,
    void Function(double) setY,
    PageLayout Function() page,
    void Function() newPage,
    double Function() capacity,
    bool Function() pageEmpty,
  ) {
    final lines = b.lineHeights ?? [b.height];
    final n = lines.length;
    if (gap + b.height <= capacity() - getY()) {
      page().slices.add(
        PlacedSlice(
          blockIndex: b.blockIndex,
          y: getY() + gap,
          height: b.height,
          lineFrom: 0,
          lineTo: n,
        ),
      );
      setY(getY() + gap + b.height);
      return;
    }
    var from = 0;
    var continuation = false;
    var g = gap;
    while (from < n) {
      final remaining = capacity() - getY() - g;
      final pad = b.paddingTop + b.paddingBottom;
      // How many lines fit?
      var k = 0;
      var h = pad;
      while (from + k < n && h + lines[from + k] <= remaining) {
        h += lines[from + k];
        k++;
      }
      final left = n - from;
      if (k == left) {
        page().slices.add(
          PlacedSlice(
            blockIndex: b.blockIndex,
            y: getY() + g,
            height: h,
            lineFrom: from,
            lineTo: n,
            isContinuation: continuation,
          ),
        );
        setY(getY() + g + h);
        return;
      }
      // Widow/orphan control.
      if (!pageEmpty()) {
        if (left < orphans + widows || k < orphans) {
          newPage();
          g = 0;
          continue;
        }
        k = math.min(k, left - widows);
      } else {
        // On an empty page place at least one line (lines taller than a
        // page cannot be helped); keep widows if possible.
        if (k == 0) k = 1;
        if (left - k < widows && left > widows && k > left - widows) {
          k = left - widows;
        }
        if (k < 1) k = 1;
      }
      final sliceH =
          pad + lines.sublist(from, from + k).fold(0.0, (s, x) => s + x);
      page().slices.add(
        PlacedSlice(
          blockIndex: b.blockIndex,
          y: getY() + g,
          height: sliceH,
          lineFrom: from,
          lineTo: from + k,
          isContinuation: continuation,
          continues: true,
        ),
      );
      from += k;
      continuation = true;
      newPage();
      g = 0;
    }
  }

  void _placeTable(
    BlockMetrics b,
    double gap,
    double Function() getY,
    void Function(double) setY,
    PageLayout Function() page,
    void Function() newPage,
    double Function() capacity,
    bool Function() pageEmpty,
  ) {
    final rows = b.rows ?? const <RowMetrics>[];
    final headerCount = math.min(b.headerRows, rows.length);
    final headerH = rows.take(headerCount).fold(0.0, (s, r) => s + r.height);
    if (gap + b.height <= capacity() - getY()) {
      page().slices.add(
        PlacedSlice(
          blockIndex: b.blockIndex,
          y: getY() + gap,
          height: b.height,
          rowFrom: 0,
          rowTo: rows.length,
        ),
      );
      setY(getY() + gap + b.height);
      return;
    }
    // Header + first body row must fit, else start on a new page.
    final firstBody = rows.length > headerCount
        ? rows[headerCount].height
        : 0.0;
    if (!pageEmpty() &&
        gap + headerH + math.min(firstBody, capacity() - headerH) >
            capacity() - getY()) {
      newPage();
      gap = 0;
    }
    var r = headerCount;
    var continuation = false;
    var g = gap;
    List<(int, int)>? pendingSplit; // remaining cell lines of a split row
    while (r < rows.length || pendingSplit != null) {
      final available = capacity() - getY() - g - headerH;
      var h = 0.0;
      final start = r;
      List<(int, int)>? splitHere;
      // Continuation of a split row.
      if (pendingSplit != null) {
        final row = rows[r];
        final (sliceH, ranges, done) = _splitRow(row, pendingSplit, available);
        h += sliceH;
        if (done) {
          pendingSplit = null;
          r++;
        } else {
          pendingSplit = _rest(row, ranges);
        }
        splitHere = ranges;
      }
      while (pendingSplit == null &&
          r < rows.length &&
          h + rows[r].height <= available) {
        h += rows[r].height;
        r++;
      }
      if (pendingSplit == null &&
          r < rows.length &&
          r == start &&
          splitHere == null) {
        // A row taller than the remaining space.
        final row = rows[r];
        if (row.height > capacity() - headerH || pageEmpty()) {
          final initial = [for (final c in row.cellLineHeights) (0, c.length)];
          final (sliceH, ranges, done) = _splitRow(row, initial, available);
          h += sliceH;
          splitHere = ranges;
          if (done) {
            r++;
          } else {
            pendingSplit = _rest(row, ranges);
          }
        } else {
          newPage();
          g = 0;
          continuation = true;
          continue;
        }
      }
      final more = r < rows.length || pendingSplit != null;
      page().slices.add(
        PlacedSlice(
          blockIndex: b.blockIndex,
          y: getY() + g,
          height: headerH + h,
          rowFrom: start,
          rowTo: pendingSplit != null ? r + 1 : r,
          repeatHeader: true,
          isContinuation: continuation,
          continues: more,
          rowSplit: splitHere,
        ),
      );
      setY(getY() + g + headerH + h);
      if (!more) return;
      newPage();
      g = 0;
      continuation = true;
    }
  }

  /// Splits a row at line boundaries per cell. [ranges] are the remaining
  /// `(from, to)` lines per cell. Returns (height, placed ranges, done).
  (double, List<(int, int)>, bool) _splitRow(
    RowMetrics row,
    List<(int, int)> ranges,
    double available,
  ) {
    final placed = <(int, int)>[];
    var maxH = 0.0;
    var done = true;
    for (var c = 0; c < ranges.length; c++) {
      final (from, to) = ranges[c];
      final lines = c < row.cellLineHeights.length
          ? row.cellLineHeights[c]
          : const <double>[];
      var h = row.cellPadding;
      var k = from;
      while (k < to && h + lines[k] <= available) {
        h += lines[k];
        k++;
      }
      if (k == from && k < to) {
        h += lines[k];
        k++;
      }
      if (k < to) done = false;
      placed.add((from, k));
      maxH = math.max(maxH, h);
    }
    return (maxH, placed, done);
  }

  List<(int, int)> _rest(RowMetrics row, List<(int, int)> placed) => [
    for (var c = 0; c < placed.length; c++)
      (
        placed[c].$2,
        c < row.cellLineHeights.length
            ? row.cellLineHeights[c].length
            : placed[c].$2,
      ),
  ];
}
