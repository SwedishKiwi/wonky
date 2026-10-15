import 'dart:math' as math;

import 'code_columns.dart';
import 'mono_font_metrics.dart';

/// Options of a [CodeLayout] (Slides 07 §3.3).
final class CodeLayoutOptions {
  /// Creates options.
  const CodeLayoutOptions({
    this.fontSize = 16,
    this.lineHeight = 1.5,
    this.tabSize = 4,
    this.wrapColumns,
    this.metrics = MonoFontMetrics.jetBrainsMono,
  });

  /// Font size (su).
  final double fontSize;

  /// Line height as a multiple of [fontSize].
  final double lineHeight;

  /// Display width of `\t` (2, 4 or 8).
  final int tabSize;

  /// Soft wrap at this many columns; null = no wrap.
  final int? wrapColumns;

  /// Font metrics of the grid.
  final MonoFontMetrics metrics;

  /// Width of one column (su).
  double get columnWidth => metrics.columnWidth(fontSize);

  /// Height of one row (su).
  double get rowHeight => fontSize * lineHeight;

  /// A copy with the given fields replaced (`wrapColumns: null` keeps it;
  /// use [unwrapped] to turn wrapping off).
  CodeLayoutOptions copyWith({
    double? fontSize,
    double? lineHeight,
    int? tabSize,
    int? wrapColumns,
    MonoFontMetrics? metrics,
  }) => CodeLayoutOptions(
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    tabSize: tabSize ?? this.tabSize,
    wrapColumns: wrapColumns ?? this.wrapColumns,
    metrics: metrics ?? this.metrics,
  );

  /// These options without wrapping.
  CodeLayoutOptions get unwrapped => CodeLayoutOptions(
    fontSize: fontSize,
    lineHeight: lineHeight,
    tabSize: tabSize,
    metrics: metrics,
  );
}

/// A cell position on the grid: visual [row] (0-based; wrapped lines take
/// several rows) and [column] (0-based).
final class GridPos {
  /// Creates a position.
  const GridPos(this.row, this.column);

  final int row;
  final int column;

  @override
  bool operator ==(Object other) =>
      other is GridPos && other.row == row && other.column == column;

  @override
  int get hashCode => Object.hash(row, column);

  @override
  String toString() => 'GridPos($row, $column)';
}

/// A rectangle in slide units, relative to the top-left of the code area.
final class CodeRect {
  /// Creates a rectangle.
  const CodeRect(this.left, this.top, this.width, this.height);

  /// An empty rectangle at the origin.
  static const zero = CodeRect(0, 0, 0, 0);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  /// The smallest rectangle containing this and [other].
  CodeRect union(CodeRect other) {
    final l = math.min(left, other.left), t = math.min(top, other.top);
    return CodeRect(
      l,
      t,
      math.max(right, other.right) - l,
      math.max(bottom, other.bottom) - t,
    );
  }

  /// Linear interpolation (morphing highlight bars).
  static CodeRect lerp(CodeRect a, CodeRect b, double t) => CodeRect(
    a.left + (b.left - a.left) * t,
    a.top + (b.top - a.top) * t,
    a.width + (b.width - a.width) * t,
    a.height + (b.height - a.height) * t,
  );

  @override
  bool operator ==(Object other) =>
      other is CodeRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'CodeRect($left, $top, $width × $height)';
}

/// One visual row of a [CodeLayout]: a physical line or the wrapped part of
/// one.
final class CodeRow {
  /// Creates a row.
  const CodeRow({
    required this.line,
    required this.start,
    required this.end,
    required this.columns,
    required this.continuation,
    required this.boundaries,
    required this.boundaryColumns,
  });

  /// 0-based physical line.
  final int line;

  /// UTF-16 offset of the row's first character in the code.
  final int start;

  /// UTF-16 offset after the row's last character (before the line break or
  /// at the wrap point).
  final int end;

  /// Width in columns.
  final int columns;

  /// Whether this row continues a wrapped line (drawn with the ↪ marker).
  final bool continuation;

  /// Grapheme boundaries in `[start, end]` (offsets into the code).
  final List<int> boundaries;

  /// Column of each boundary (parallel to [boundaries]).
  final List<int> boundaryColumns;

  /// Column of [offset] (snapped to the grapheme starting at or before it).
  int columnOf(int offset) {
    if (offset <= start) return 0;
    if (offset >= end) return columns;
    var lo = 0, hi = boundaries.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (boundaries[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return boundaryColumns[lo];
  }

  /// The offset of the boundary nearest to [column] (a click on the right
  /// half of a cell goes after it).
  int offsetAtColumn(int column) {
    if (column <= 0) return start;
    for (var i = 0; i < boundaries.length - 1; i++) {
      final c0 = boundaryColumns[i], c1 = boundaryColumns[i + 1];
      if (column < c1) {
        return column - c0 < c1 - column ? boundaries[i] : boundaries[i + 1];
      }
    }
    return end;
  }
}

/// One physical line of a [CodeLayout].
final class CodeLayoutLine {
  /// Creates a line.
  const CodeLayoutLine({
    required this.index,
    required this.start,
    required this.end,
    required this.firstRow,
    required this.rowCount,
    required this.columns,
  });

  /// 0-based line index.
  final int index;

  /// UTF-16 offset of the first character.
  final int start;

  /// UTF-16 offset after the last character (before `\n`).
  final int end;

  /// First visual row.
  final int firstRow;

  /// Number of visual rows (1 without wrapping).
  final int rowCount;

  /// Width of the unwrapped line in columns.
  final int columns;

  /// Last visual row.
  int get lastRow => firstRow + rowCount - 1;
}

/// Code laid out on the monospace grid (Slides 07 §1.2, §3.3): lines,
/// visual rows (soft wrap), columns, and conversions between UTF-16
/// offsets, grid positions and rectangles in slide units (relative to the
/// code area's top-left). Type-in, morph, highlighting, callout anchors and
/// PDF output use the same grid.
final class CodeLayout {
  CodeLayout._(this.code, this.options, this.lines, this.rows, this.maxColumns);

  /// Lays out [code] (`\n` line breaks; a `\r` before `\n` is part of the
  /// line break).
  static CodeLayout layout(
    String code, [
    CodeLayoutOptions options = const CodeLayoutOptions(),
  ]) {
    final lines = <CodeLayoutLine>[];
    final rows = <CodeRow>[];
    var maxColumns = 0;
    final wrap = options.wrapColumns;
    var lineStart = 0;
    while (true) {
      var lineEnd = code.indexOf('\n', lineStart);
      final last = lineEnd < 0;
      if (last) lineEnd = code.length;
      var contentEnd = lineEnd;
      if (contentEnd > lineStart && code.codeUnitAt(contentEnd - 1) == 0x0D) {
        contentEnd--;
      }
      final firstRow = rows.length;
      final b = CodeColumns.boundaries(code, lineStart, contentEnd);
      // Columns per boundary along the whole line (unwrapped).
      final cols = List<int>.filled(b.length, 0);
      for (var i = 1; i < b.length; i++) {
        cols[i] = CodeColumns.advance(
          code,
          b[i - 1],
          b[i],
          cols[i - 1],
          options.tabSize,
        );
      }
      final lineColumns = cols.last;
      if (wrap == null || wrap < 1 || lineColumns <= wrap) {
        rows.add(
          CodeRow(
            line: lines.length,
            start: lineStart,
            end: contentEnd,
            columns: lineColumns,
            continuation: false,
            boundaries: b,
            boundaryColumns: cols,
          ),
        );
        maxColumns = math.max(maxColumns, lineColumns);
      } else {
        _wrapLine(code, b, options.tabSize, wrap, lines.length, rows);
        for (var r = firstRow; r < rows.length; r++) {
          maxColumns = math.max(maxColumns, rows[r].columns);
        }
      }
      lines.add(
        CodeLayoutLine(
          index: lines.length,
          start: lineStart,
          end: contentEnd,
          firstRow: firstRow,
          rowCount: rows.length - firstRow,
          columns: lineColumns,
        ),
      );
      if (last) break;
      lineStart = lineEnd + 1;
    }
    return CodeLayout._(code, options, lines, rows, maxColumns);
  }

  /// Breaks one line into rows of at most [wrap] columns, after the last
  /// whitespace of a row when there is one (else inside the word).
  static void _wrapLine(
    String code,
    List<int> b,
    int tabSize,
    int wrap,
    int line,
    List<CodeRow> rows,
  ) {
    var i = 0; // boundary index of the row start
    var continuation = false;
    while (true) {
      // Lay out from b[i] with column 0.
      final rb = <int>[b[i]];
      final rc = <int>[0];
      var j = i;
      var lastBreak = -1; // boundary index after a whitespace
      while (j < b.length - 1) {
        final next = CodeColumns.advance(
          code,
          b[j],
          b[j + 1],
          rc.last,
          tabSize,
        );
        if (next > wrap && j > i) break;
        rb.add(b[j + 1]);
        rc.add(next);
        final c = code.codeUnitAt(b[j]);
        if (c == 0x20 || c == 0x09) lastBreak = j + 1;
        j++;
      }
      if (j < b.length - 1 && lastBreak > i && lastBreak < j) {
        // Break after the last whitespace of the row.
        final keep = lastBreak - i;
        rb.removeRange(keep + 1, rb.length);
        rc.removeRange(keep + 1, rc.length);
        j = lastBreak;
      }
      rows.add(
        CodeRow(
          line: line,
          start: b[i],
          end: b[j],
          columns: rc.last,
          continuation: continuation,
          boundaries: rb,
          boundaryColumns: rc,
        ),
      );
      if (j >= b.length - 1) break;
      i = j;
      continuation = true;
    }
  }

  /// The laid-out text.
  final String code;

  /// The options used.
  final CodeLayoutOptions options;

  /// Physical lines.
  final List<CodeLayoutLine> lines;

  /// Visual rows.
  final List<CodeRow> rows;

  /// Width of the widest row in columns.
  final int maxColumns;

  /// Number of physical lines (an empty text has one).
  int get lineCount => lines.length;

  /// Number of visual rows.
  int get rowCount => rows.length;

  /// Width of one column (su).
  double get columnWidth => options.columnWidth;

  /// Height of one row (su).
  double get rowHeight => options.rowHeight;

  /// Width of the widest row (su).
  double get width => maxColumns * columnWidth;

  /// Height of all rows (su).
  double get height => rowCount * rowHeight;

  /// Left edge of [column] (su).
  double xOf(num column) => column * columnWidth;

  /// Top edge of [row] (su).
  double yOf(num row) => row * rowHeight;

  /// Baseline of [row] (su).
  double baselineOf(num row) =>
      yOf(row) +
      options.metrics.baselineInRow(options.fontSize, options.lineHeight);

  /// The physical line containing [offset] (a line break belongs to the
  /// line it ends).
  int lineOf(int offset) {
    var lo = 0, hi = lines.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (lines[mid].start <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The visual row containing [offset]: at a wrap point the offset starts
  /// the next row.
  int rowOf(int offset) {
    final line = lines[lineOf(offset)];
    for (var r = line.lastRow; r > line.firstRow; r--) {
      if (rows[r].start <= offset) return r;
    }
    return line.firstRow;
  }

  /// Grid position of [offset] (clamped to the text; snapped to the
  /// grapheme starting at or before it).
  GridPos posOf(int offset) {
    final o = offset.clamp(0, code.length);
    final r = rowOf(o);
    return GridPos(r, rows[r].columnOf(o));
  }

  /// The offset at [p] (clamped to the grid; nearest grapheme boundary).
  int offsetAt(GridPos p) {
    final r = p.row.clamp(0, rows.length - 1);
    return rows[r].offsetAtColumn(p.column);
  }

  /// One rectangle per row covered by `[start, end)` (su). An empty range
  /// gives a zero-width rectangle at its position (a caret).
  List<CodeRect> rectsOfRange(int start, int end) {
    final s = math.min(start, end).clamp(0, code.length);
    final e = math.max(start, end).clamp(0, code.length);
    final p0 = posOf(s);
    if (e == s) {
      return [CodeRect(xOf(p0.column), yOf(p0.row), 0, rowHeight)];
    }
    final p1 = posOf(e);
    final out = <CodeRect>[];
    for (var r = p0.row; r <= p1.row; r++) {
      final c0 = r == p0.row ? p0.column : 0;
      // A selection running past a row end covers the line break (one
      // column), as editors draw it.
      final c1 = r == p1.row
          ? p1.column
          : rows[r].columns + (rows[r + 1].continuation ? 0 : 1);
      if (r == p1.row && c1 == 0 && r > p0.row) break;
      out.add(CodeRect(xOf(c0), yOf(r), xOf(math.max(c1 - c0, 0)), rowHeight));
    }
    return out;
  }

  /// The bounding rectangle of `[start, end)` (su).
  CodeRect rectOfRange(int start, int end) =>
      rectsOfRange(start, end).reduce((a, b) => a.union(b));

  /// The rectangle of the physical lines [first]..[last] (0-based,
  /// inclusive) over the full code width (highlight bars, callout anchors).
  CodeRect rectOfLines(int first, int last, {double? width}) {
    final a = lines[first.clamp(0, lines.length - 1)];
    final b = lines[last.clamp(0, lines.length - 1)];
    return CodeRect(
      0,
      yOf(a.firstRow),
      width ?? this.width,
      yOf(b.lastRow + 1) - yOf(a.firstRow),
    );
  }
}
