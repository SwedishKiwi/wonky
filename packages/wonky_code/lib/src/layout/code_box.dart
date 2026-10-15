import 'dart:math' as math;

import 'code_layout.dart';
import 'mono_font_metrics.dart';

/// The chrome of a code box (Slides 07 §3.4).
enum CodeChrome {
  /// No title area.
  none,

  /// A rounded tab at the top-left with the title.
  tab,

  /// A macOS-style title bar (three dots, centered title).
  window,

  /// A small label above the box.
  caption;

  /// Parses a `dataJson.chrome` value (unknown → null).
  static CodeChrome? fromName(String? name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// What the box geometry depends on besides the font size (Slides 07 §3.1,
/// §3.3).
final class CodeBoxOptions {
  /// Creates options.
  const CodeBoxOptions({
    this.chrome = CodeChrome.tab,
    this.hasTitle = false,
    this.padding = 32,
    this.lineNumbers = true,
    this.lastLineNumber = 1,
    this.lineHeight = 1.5,
    this.tabSize = 2,
    this.wrap = false,
    this.metrics = MonoFontMetrics.jetBrainsMono,
    this.fontSizeMin = 14,
    this.fontSizeMax = 40,
  });

  final CodeChrome chrome;

  /// Whether a title text is shown (tab and caption chrome only draw their
  /// area with a title; the window bar is always drawn).
  final bool hasTitle;

  /// Inner padding of the box (su).
  final double padding;

  /// Whether the line-number gutter is shown.
  final bool lineNumbers;

  /// The largest displayed line number (gutter width = its digits + 2
  /// columns at 0.85 × the font size).
  final int lastLineNumber;

  /// Line height (× font size).
  final double lineHeight;

  /// Tab display width.
  final int tabSize;

  /// Soft wrap at the code area width.
  final bool wrap;

  /// Mono font metrics.
  final MonoFontMetrics metrics;

  /// Auto-fit bounds (su).
  final double fontSizeMin;
  final double fontSizeMax;

  /// Height of the title area inside the box at [fontSize] (tab/window).
  double titleHeight(double fontSize) => switch (chrome) {
    CodeChrome.window => fontSize * 2.2,
    CodeChrome.tab when hasTitle => fontSize * 2.2,
    _ => 0,
  };

  /// Height of the caption above the box at [fontSize].
  double captionHeight(double fontSize) =>
      chrome == CodeChrome.caption && hasTitle ? fontSize * 1.6 : 0;

  /// Digits of the largest line number.
  int get digits => '${math.max(1, lastLineNumber)}'.length;
}

/// The geometry of a code box at one font size (Slides 07 §3.3), in slide
/// units relative to the element frame's top-left.
final class CodeBoxGeometry {
  CodeBoxGeometry._({
    required this.fontSize,
    required this.width,
    required this.height,
    required this.box,
    required this.captionHeight,
    required this.titleHeight,
    required this.codeArea,
    required this.gutterFontSize,
    required this.numbersRight,
    required this.options,
  });

  /// The geometry of a [width] × [height] frame at [fontSize].
  static CodeBoxGeometry compute(
    double width,
    double height,
    double fontSize,
    CodeBoxOptions options,
  ) {
    final caption = options.captionHeight(fontSize);
    final title = options.titleHeight(fontSize);
    final box = CodeRect(0, caption, width, math.max(0, height - caption));
    final pad = options.padding;
    final gutterFont = fontSize * 0.85;
    final gutterCol = options.metrics.columnWidth(gutterFont);
    final gutterWidth = options.lineNumbers
        ? (options.digits + 2) * gutterCol
        : 0.0;
    final left = box.left + pad + gutterWidth;
    final top = box.top + title + pad;
    return CodeBoxGeometry._(
      fontSize: fontSize,
      width: width,
      height: height,
      box: box,
      captionHeight: caption,
      titleHeight: title,
      codeArea: CodeRect(
        left,
        top,
        math.max(0, box.right - pad - left),
        math.max(0, box.bottom - pad - top),
      ),
      gutterFontSize: gutterFont,
      numbersRight: options.lineNumbers
          ? box.left + pad + (options.digits + 1) * gutterCol
          : null,
      options: options,
    );
  }

  /// Font size (su).
  final double fontSize;

  /// Frame size (su).
  final double width;
  final double height;

  /// The code box (below a caption).
  final CodeRect box;

  /// Height of the caption above [box].
  final double captionHeight;

  /// Height of the tab/window title area at the top of [box].
  final double titleHeight;

  /// Where the grid lies: its origin is the top-left of this rectangle.
  final CodeRect codeArea;

  /// Font size of the line numbers (0.85 × [fontSize]).
  final double gutterFontSize;

  /// Right edge of the right-aligned line numbers, or null without them.
  final double? numbersRight;

  final CodeBoxOptions options;

  /// Columns that fit the code area (for wrapping).
  int get wrapColumns => math.max(
    1,
    (codeArea.width / options.metrics.columnWidth(fontSize) + 1e-6).floor(),
  );

  /// Layout options of the grid at this size.
  CodeLayoutOptions layoutOptions() => CodeLayoutOptions(
    fontSize: fontSize,
    lineHeight: options.lineHeight,
    tabSize: options.tabSize,
    wrapColumns: options.wrap ? wrapColumns : null,
    metrics: options.metrics,
  );

  /// Rows that fit the code area.
  int get visibleRows =>
      (codeArea.height / (fontSize * options.lineHeight) + 1e-6).floor();
}

/// The result of [CodeAutoFit.fit].
final class CodeFit {
  const CodeFit({
    required this.fontSize,
    required this.fits,
    required this.rows,
    required this.columns,
  });

  /// The chosen font size (su).
  final double fontSize;

  /// Whether the fitting text fits; false = it overflows at the minimum.
  final bool fits;

  /// Rows of the fitting text at [fontSize] (the maximum over the texts).
  final int rows;

  /// Columns of the widest row at [fontSize].
  final int columns;
}

/// Auto size (Slides 07 §3.3): the largest font size `s ∈ [min, max]` (step
/// 0.5) at which every text of the fitting set fits the code area — the
/// widest line and the line count, or with wrapping only the row count
/// after wrapping at the area width.
abstract final class CodeAutoFit {
  /// Fits [texts] (the current state, or every state with
  /// `fitAcrossStates`) into a [width] × [height] frame. [options]'
  /// `lastLineNumber` must cover the longest text.
  static CodeFit fit(
    List<String> texts,
    double width,
    double height,
    CodeBoxOptions options,
  ) {
    final min = math.min(options.fontSizeMin, options.fontSizeMax);
    final max = math.max(options.fontSizeMin, options.fontSizeMax);
    final steps = ((max - min) / 0.5).floor();
    // Unwrapped extents don't depend on the size: compute them once.
    final unwrapped = options.wrap
        ? null
        : [
            for (final t in texts)
              CodeLayout.layout(
                t,
                CodeLayoutOptions(
                  tabSize: options.tabSize,
                  metrics: options.metrics,
                ),
              ),
          ];
    (bool, int, int) check(double s) {
      final g = CodeBoxGeometry.compute(width, height, s, options);
      var rows = 0, cols = 0;
      if (unwrapped != null) {
        for (final l in unwrapped) {
          rows = math.max(rows, l.rowCount);
          cols = math.max(cols, l.maxColumns);
        }
      } else {
        final lo = g.layoutOptions();
        for (final t in texts) {
          final l = CodeLayout.layout(t, lo);
          rows = math.max(rows, l.rowCount);
          cols = math.max(cols, l.maxColumns);
        }
      }
      final colW = options.metrics.columnWidth(s);
      final ok =
          (options.wrap || cols * colW <= g.codeArea.width + 1e-6) &&
          rows * s * options.lineHeight <= g.codeArea.height + 1e-6;
      return (ok, rows, cols);
    }

    // Monotonic: a larger size never fits better. Binary search the steps.
    var lo = 0, hi = steps; // find the largest step index that fits
    final (minFits, minRows, minCols) = check(min);
    if (!minFits) {
      return CodeFit(
        fontSize: min,
        fits: false,
        rows: minRows,
        columns: minCols,
      );
    }
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (check(min + mid * 0.5).$1) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final s = min + lo * 0.5;
    final (_, rows, cols) = check(s);
    return CodeFit(fontSize: s, fits: true, rows: rows, columns: cols);
  }
}
