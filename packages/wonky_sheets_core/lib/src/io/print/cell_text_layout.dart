import 'dart:math' as math;

import '../../model/schema.dart';

/// Font of a piece of cell text (family as stored, size in the layout's unit
/// system — points for PDF, logical px for the grid).
final class CellTextStyle {
  /// Creates a style.
  const CellTextStyle({
    required this.family,
    required this.size,
    this.bold = false,
    this.italic = false,
  });

  /// Font family name (substitution is the measurer's job).
  final String family;

  /// Font size.
  final double size;
  final bool bold;
  final bool italic;

  /// A copy with changes.
  CellTextStyle copyWith({String? family, double? size, bool? bold, bool? italic}) =>
      CellTextStyle(
        family: family ?? this.family,
        size: size ?? this.size,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
      );

  @override
  bool operator ==(Object other) =>
      other is CellTextStyle &&
      other.family == family &&
      other.size == size &&
      other.bold == bold &&
      other.italic == italic;

  @override
  int get hashCode => Object.hash(family, size, bold, italic);

  @override
  String toString() => 'CellTextStyle($family ${size}pt${bold ? ' b' : ''}${italic ? ' i' : ''})';
}

/// Font metrics used by [CellTextLayout] (03 §2.6). Implemented over `pdf`
/// font metrics for print/PDF and over `TextPainter` in the Flutter app.
abstract interface class CellTextMeasurer {
  /// Advance width of [text] in [style] (no line breaks).
  double width(String text, CellTextStyle style);

  /// Distance from the top of a line box to the baseline.
  double ascent(CellTextStyle style);

  /// Distance from the baseline to the bottom of a line box.
  double descent(CellTextStyle style);

  /// Height of one line.
  double lineHeight(CellTextStyle style);
}

/// A simple, deterministic measurer (average glyph widths): wide East Asian
/// glyphs are 1 em, digits 0.556 em, spaces 0.278 em, others 0.5–0.6 em. Used
/// when no real font metrics are available (row auto-fit estimates, tests).
final class ApproximateTextMeasurer implements CellTextMeasurer {
  /// Creates the measurer.
  const ApproximateTextMeasurer();

  @override
  double width(String text, CellTextStyle style) {
    var em = 0.0;
    for (final r in text.runes) {
      em += _glyphEm(r, style.bold);
    }
    return em * style.size;
  }

  static double _glyphEm(int r, bool bold) {
    if (r == 0x20) return 0.278;
    if (r >= 0x30 && r <= 0x39) return 0.556;
    if (r >= 0x1100 && _isWide(r)) return 1.0;
    if (r == 0x69 || r == 0x6c || r == 0x2e || r == 0x2c || r == 0x27) return 0.25;
    if (r == 0x6d || r == 0x77 || r == 0x4d || r == 0x57) return 0.85;
    if (r >= 0x41 && r <= 0x5a) return bold ? 0.72 : 0.67;
    return bold ? 0.6 : 0.55;
  }

  static bool _isWide(int r) =>
      (r >= 0x1100 && r <= 0x115f) ||
      (r >= 0x2e80 && r <= 0xa4cf) ||
      (r >= 0xac00 && r <= 0xd7a3) ||
      (r >= 0xf900 && r <= 0xfaff) ||
      (r >= 0xfe30 && r <= 0xfe4f) ||
      (r >= 0xff00 && r <= 0xff60) ||
      (r >= 0xffe0 && r <= 0xffe6) ||
      (r >= 0x1f300 && r <= 0x1faff) ||
      (r >= 0x20000 && r <= 0x3fffd);

  @override
  double ascent(CellTextStyle style) => style.size * 0.93;

  @override
  double descent(CellTextStyle style) => style.size * 0.24;

  @override
  double lineHeight(CellTextStyle style) => style.size * 1.2;
}

/// A style applying to `[start, end)` of the cell text (rich text runs).
final class StyledSpan {
  /// Creates a span.
  const StyledSpan(this.start, this.end, this.style);

  final int start;
  final int end;
  final CellTextStyle style;
}

/// Width of the empty neighbour cell [step] cells away (1 = adjacent) in the
/// overflow direction, or null when that cell blocks overflow (has content, is
/// merged, is a widget cell, or is beyond the pane/page edge).
typedef OverflowNeighbour = double? Function(int step);

/// One laid-out line. Offsets index into [CellTextLayoutResult.text].
final class LayoutLine {
  /// Creates a line.
  const LayoutLine(this.start, this.end, this.x, this.baseline, this.width);

  /// Start offset (UTF-16) in the displayed text.
  final int start;

  /// End offset (exclusive).
  final int end;

  /// Left of the line in the text frame.
  final double x;

  /// Baseline of the line in the text frame.
  final double baseline;

  /// Advance width.
  final double width;

  @override
  String toString() => 'LayoutLine($start..$end x=$x b=$baseline w=$width)';
}

/// Result of [CellTextLayout.layout].
///
/// Lines are positioned in a *text frame*: translate to
/// (`cellLeft + frameX`, `cellTop + frameY`), rotate by [angle] degrees
/// counter-clockwise, then draw each line at (`x`, `baseline`) with y growing
/// downwards. For unrotated text the frame origin is the cell's top-left.
final class CellTextLayoutResult {
  /// Creates a result.
  const CellTextLayoutResult({
    required this.text,
    required this.lines,
    required this.lineHeight,
    required this.blockWidth,
    required this.blockHeight,
    required this.clipLeft,
    required this.clipRight,
    this.frameX = 0,
    this.frameY = 0,
    this.angle = 0,
    this.hashes = false,
    this.overflowCellsLeft = 0,
    this.overflowCellsRight = 0,
    this.requiredHeight = 0,
  });

  /// The displayed text (the input, or `####…` for numbers that don't fit).
  final String text;
  final List<LayoutLine> lines;
  final double lineHeight;

  /// Size of the unrotated text block.
  final double blockWidth;
  final double blockHeight;

  /// Horizontal clip interval relative to the cell's left edge (may extend
  /// into overflow neighbours: negative / beyond the cell width).
  final double clipLeft;
  final double clipRight;

  final double frameX;
  final double frameY;

  /// Rotation in degrees (counter-clockwise); 0 for unrotated and stacked text.
  final double angle;

  /// Whether a number didn't fit and is shown as `#` signs.
  final bool hashes;

  /// Number of neighbour cells the text paints into on each side.
  final int overflowCellsLeft;
  final int overflowCellsRight;

  /// Height the cell needs to show all lines (row auto-fit, 03 §13.6),
  /// including vertical padding.
  final double requiredHeight;

  /// Text of [line].
  String lineText(LayoutLine line) => text.substring(line.start, line.end);
}

/// Pure, measurer-based cell text layout shared by print/PDF and the grid
/// (03 §2.6, 06 §9): line breaks, wrapping, overflow into empty neighbours,
/// clipping, `####` for numbers, rotation and vertical stacking.
abstract final class CellTextLayout {
  /// Number of neighbour cells scanned for overflow (03 §2.6).
  static const int maxOverflowCells = 50;

  /// Lays out [text] in a cell of [cellWidth] × [cellHeight].
  ///
  /// [align] is the *resolved* horizontal alignment (general alignment
  /// already applied, 06 §9.1). [spans] style parts of the text (rich runs);
  /// text outside spans uses [style]. [numberLike] marks numbers/dates that
  /// render `#` signs instead of overflowing.
  static CellTextLayoutResult layout({
    required String text,
    required CellTextStyle style,
    required CellTextMeasurer measurer,
    required double cellWidth,
    required double cellHeight,
    List<StyledSpan> spans = const [],
    WrapStrategy wrap = WrapStrategy.overflow,
    HorizontalAlign align = HorizontalAlign.left,
    VerticalAlign vAlign = VerticalAlign.bottom,
    int rotation = 0,
    bool numberLike = false,
    double paddingX = 3,
    double paddingY = 2,
    OverflowNeighbour? leftNeighbour,
    OverflowNeighbour? rightNeighbour,
  }) {
    final styles = _StyleMap(text, style, spans);
    final lineH = styles.maxLineHeight(measurer);
    final ascent = styles.maxAscent(measurer);
    final descent = styles.maxDescent(measurer);
    final baselineOffset = ascent + (lineH - ascent - descent) / 2;
    final avail = math.max(0.0, cellWidth - 2 * paddingX);

    if (rotation == 255) {
      return _stacked(
        text,
        styles,
        measurer,
        cellWidth,
        cellHeight,
        align,
        vAlign,
        paddingX,
        paddingY,
        lineH,
        baselineOffset,
      );
    }

    final prefix = styles.prefixWidths(measurer);
    double widthOf(int s, int e) => prefix[e] - prefix[s];

    // Paragraphs (explicit line breaks always break, 03 §2.6).
    final paragraphs = <(int, int)>[];
    var ps = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x0a) {
        var pe = i;
        if (pe > ps && text.codeUnitAt(pe - 1) == 0x0d) pe--;
        paragraphs.add((ps, pe));
        ps = i + 1;
      }
    }
    paragraphs.add((ps, text.length));

    final angle = rotation.clamp(-90, 90).toDouble();
    final rotated = angle != 0;

    // Numbers that don't fit → hashes (unrotated only).
    if (numberLike && !rotated && paragraphs.length == 1) {
      final w = widthOf(0, text.length);
      if (w > avail + 1e-9) {
        final hashW = measurer.width('#', style);
        final n = hashW <= 0 ? 1 : math.max(1, (avail / hashW).floor());
        final hashes = '#' * n;
        final hw = measurer.width(hashes, style);
        final x = _alignX(align, cellWidth, paddingX, hw);
        final top = _blockTop(vAlign, cellHeight, paddingY, lineH);
        return CellTextLayoutResult(
          text: hashes,
          lines: [LayoutLine(0, hashes.length, x, top + baselineOffset, hw)],
          lineHeight: lineH,
          blockWidth: hw,
          blockHeight: lineH,
          clipLeft: 0,
          clipRight: cellWidth,
          hashes: true,
          requiredHeight: lineH + 2 * paddingY,
        );
      }
    }

    // Break into lines.
    final ranges = <(int, int)>[];
    final doWrap = wrap == WrapStrategy.wrap && !rotated;
    for (final (s, e) in paragraphs) {
      if (doWrap) {
        ranges.addAll(_wrap(text, s, e, avail, widthOf));
      } else {
        ranges.add((s, e));
      }
    }
    var blockW = 0.0;
    final widths = <double>[];
    for (final (s, e) in ranges) {
      final w = widthOf(s, _trimEnd(text, s, e));
      widths.add(w);
      if (w > blockW) blockW = w;
    }
    final blockH = ranges.length * lineH;

    if (rotated) {
      final rad = angle * math.pi / 180;
      final cos = math.cos(rad).abs();
      final sin = math.sin(rad).abs();
      final bw = blockW * cos + blockH * sin;
      final bh = blockW * sin + blockH * cos;
      final left = switch (align) {
        HorizontalAlign.left => paddingX,
        HorizontalAlign.right => cellWidth - paddingX - bw,
        HorizontalAlign.center => (cellWidth - bw) / 2,
      };
      final top = _blockTop(vAlign, cellHeight, paddingY, bh);
      final lines = <LayoutLine>[];
      for (var i = 0; i < ranges.length; i++) {
        final w = widths[i];
        final lx = switch (align) {
          HorizontalAlign.left => -blockW / 2,
          HorizontalAlign.right => blockW / 2 - w,
          HorizontalAlign.center => -w / 2,
        };
        lines.add(
          LayoutLine(ranges[i].$1, ranges[i].$2, lx, -blockH / 2 + i * lineH + baselineOffset, w),
        );
      }
      return CellTextLayoutResult(
        text: text,
        lines: lines,
        lineHeight: lineH,
        blockWidth: blockW,
        blockHeight: blockH,
        clipLeft: 0,
        clipRight: cellWidth,
        frameX: left + bw / 2,
        frameY: top + bh / 2,
        angle: angle,
        requiredHeight: bh + 2 * paddingY,
      );
    }

    // Overflow (overflow strategy, non-numbers).
    var clipLeft = 0.0;
    var clipRight = cellWidth;
    var cellsLeft = 0;
    var cellsRight = 0;
    final needed = blockW - avail;
    if (wrap == WrapStrategy.overflow && !numberLike && needed > 1e-9) {
      (double, int) extend(OverflowNeighbour? n, double need) {
        if (n == null) return (0, 0);
        var ext = 0.0;
        var k = 0;
        while (ext < need && k < maxOverflowCells) {
          final w = n(k + 1);
          if (w == null) break;
          ext += w;
          k++;
        }
        return (ext, k);
      }

      switch (align) {
        case HorizontalAlign.left:
          final (ext, k) = extend(rightNeighbour, needed);
          clipRight = cellWidth + ext;
          cellsRight = k;
        case HorizontalAlign.right:
          final (ext, k) = extend(leftNeighbour, needed);
          clipLeft = -ext;
          cellsLeft = k;
        case HorizontalAlign.center:
          final (el, kl) = extend(leftNeighbour, needed / 2);
          final (er, kr) = extend(rightNeighbour, needed / 2);
          clipLeft = -el;
          clipRight = cellWidth + er;
          cellsLeft = kl;
          cellsRight = kr;
      }
    }

    final top = _blockTop(vAlign, cellHeight, paddingY, blockH);
    final lines = <LayoutLine>[
      for (var i = 0; i < ranges.length; i++)
        LayoutLine(
          ranges[i].$1,
          ranges[i].$2,
          _alignX(align, cellWidth, paddingX, widths[i]),
          top + i * lineH + baselineOffset,
          widths[i],
        ),
    ];
    return CellTextLayoutResult(
      text: text,
      lines: lines,
      lineHeight: lineH,
      blockWidth: blockW,
      blockHeight: blockH,
      clipLeft: clipLeft,
      clipRight: clipRight,
      overflowCellsLeft: cellsLeft,
      overflowCellsRight: cellsRight,
      requiredHeight: blockH + 2 * paddingY,
    );
  }

  static double _alignX(HorizontalAlign a, double cellWidth, double pad, double w) =>
      switch (a) {
        HorizontalAlign.left => pad,
        HorizontalAlign.right => cellWidth - pad - w,
        HorizontalAlign.center => (cellWidth - w) / 2,
      };

  static double _blockTop(VerticalAlign v, double cellHeight, double pad, double h) =>
      switch (v) {
        VerticalAlign.top => pad,
        VerticalAlign.middle => (cellHeight - h) / 2,
        VerticalAlign.bottom => cellHeight - pad - h,
      };

  static int _trimEnd(String t, int s, int e) {
    var i = e;
    while (i > s && t.codeUnitAt(i - 1) == 0x20) {
      i--;
    }
    return i;
  }

  static bool _isHigh(int c) => c >= 0xd800 && c <= 0xdbff;

  /// Greedy word wrap of `[s, e)` at [maxWidth]; words longer than a line are
  /// broken by character (surrogate pairs kept together).
  static List<(int, int)> _wrap(
    String t,
    int s,
    int e,
    double maxWidth,
    double Function(int, int) widthOf,
  ) {
    final out = <(int, int)>[];
    if (s >= e) return [(s, e)];
    var lineStart = s;
    var lastBreak = -1; // offset after a space where a line may end
    var i = s;
    while (i < e) {
      final c = t.codeUnitAt(i);
      final next = (_isHigh(c) && i + 1 < e) ? i + 2 : i + 1;
      if (c == 0x20) {
        lastBreak = next;
        i = next;
        continue;
      }
      final lineEndTrim = _trimEnd(t, lineStart, next);
      if (widthOf(lineStart, lineEndTrim) > maxWidth + 1e-9 && next - lineStart > 1) {
        if (lastBreak > lineStart) {
          out.add((lineStart, lastBreak));
          lineStart = lastBreak;
          lastBreak = -1;
          continue; // re-measure current char on the new line
        }
        if (i > lineStart) {
          out.add((lineStart, i));
          lineStart = i;
          lastBreak = -1;
          continue;
        }
      }
      i = next;
    }
    out.add((lineStart, e));
    // Lines produced by a wrap don't start with spaces.
    for (var k = 1; k < out.length; k++) {
      var (a, b) = out[k];
      while (a < b && t.codeUnitAt(a) == 0x20) {
        a++;
      }
      out[k] = (a, b);
    }
    return out;
  }

  static CellTextLayoutResult _stacked(
    String text,
    _StyleMap styles,
    CellTextMeasurer m,
    double cellWidth,
    double cellHeight,
    HorizontalAlign align,
    VerticalAlign vAlign,
    double padX,
    double padY,
    double lineH,
    double baselineOffset,
  ) {
    final glyphs = <(int, int)>[];
    var i = 0;
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      final next = (_isHigh(c) && i + 1 < text.length) ? i + 2 : i + 1;
      if (c != 0x0a && c != 0x0d) glyphs.add((i, next));
      i = next;
    }
    var maxW = 0.0;
    final widths = <double>[];
    for (final (s, e) in glyphs) {
      final w = m.width(text.substring(s, e), styles.styleAt(s));
      widths.add(w);
      if (w > maxW) maxW = w;
    }
    final blockH = glyphs.length * lineH;
    final colCenter = switch (align) {
      HorizontalAlign.left => padX + maxW / 2,
      HorizontalAlign.right => cellWidth - padX - maxW / 2,
      HorizontalAlign.center => cellWidth / 2,
    };
    final top = _blockTop(vAlign, cellHeight, padY, blockH);
    return CellTextLayoutResult(
      text: text,
      lines: [
        for (var k = 0; k < glyphs.length; k++)
          LayoutLine(
            glyphs[k].$1,
            glyphs[k].$2,
            colCenter - widths[k] / 2,
            top + k * lineH + baselineOffset,
            widths[k],
          ),
      ],
      lineHeight: lineH,
      blockWidth: maxW,
      blockHeight: blockH,
      clipLeft: 0,
      clipRight: cellWidth,
      requiredHeight: blockH + 2 * padY,
    );
  }
}

/// Style lookup over spans.
final class _StyleMap {
  _StyleMap(this.text, this.base, List<StyledSpan> spans)
    : spans = [
        for (final s in spans)
          if (s.end > s.start) s,
      ]..sort((a, b) => a.start.compareTo(b.start));

  final String text;
  final CellTextStyle base;
  final List<StyledSpan> spans;

  CellTextStyle styleAt(int offset) {
    for (final s in spans) {
      if (offset >= s.start && offset < s.end) return s.style;
      if (s.start > offset) break;
    }
    return base;
  }

  Iterable<CellTextStyle> get allStyles sync* {
    yield base;
    for (final s in spans) {
      yield s.style;
    }
  }

  double maxLineHeight(CellTextMeasurer m) => allStyles.map(m.lineHeight).reduce(math.max);
  double maxAscent(CellTextMeasurer m) => allStyles.map(m.ascent).reduce(math.max);
  double maxDescent(CellTextMeasurer m) => allStyles.map(m.descent).reduce(math.max);

  /// Prefix advance widths per UTF-16 offset (surrogate pairs measured as one
  /// glyph and attributed to the high surrogate).
  List<double> prefixWidths(CellTextMeasurer m) {
    final out = List<double>.filled(text.length + 1, 0);
    final cache = <(String, CellTextStyle), double>{};
    var acc = 0.0;
    var i = 0;
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      final pair = c >= 0xd800 && c <= 0xdbff && i + 1 < text.length;
      final next = pair ? i + 2 : i + 1;
      if (c != 0x0a && c != 0x0d) {
        final ch = text.substring(i, next);
        final st = styleAt(i);
        acc += cache.putIfAbsent((ch, st), () => m.width(ch, st));
      }
      out[i + 1] = acc;
      if (pair) out[i + 2] = acc;
      i = next;
    }
    return out;
  }
}
