/// The laid-out content of a code element in one state and highlight step
/// (07, `CodeElementModel.build(state, step, size)`, 12 §5.6).
///
/// The contract stub of SL-3, filled by SL-26 (`core/code/`): everything is
/// in slide units relative to the element frame, on the monospace grid of
/// `wonky_code`'s `CodeLayout`. The base fields (lines of colored runs,
/// baselines below [CodeScene.chromeHeight], line numbers right-aligned at
/// [CodeScene.numbersRight]) are what the M9 painters draw; the SL-26
/// additions (grid columns, per-line opacity/blur, highlight bars, caret,
/// callouts, morph glyphs, crossfade underlay, chrome geometry) are for the
/// code element painter of SL-31 and the PDF builds of SL-33.
library;

import '../../theme/model/common.dart';

/// One colored token run of a code line.
final class CodeRun {
  /// Creates a run.
  const CodeRun(
    this.text, {
    required this.color,
    this.bold = false,
    this.italic = false,
    this.column = 0,
    this.opacity = 1,
  });

  /// The text, tabs expanded to spaces.
  final String text;

  /// ARGB.
  final int color;
  final bool bold;
  final bool italic;

  /// Grid column of the run's first cell (SL-26; glyphs are placed on the
  /// grid: x = `codeLeft + column × columnWidth`).
  final int column;

  /// 0..1: a paste fading in while typing (SL-26).
  final double opacity;
}

/// One laid-out code row (a physical line, or the wrapped part of one).
final class CodeLine {
  /// Creates a line.
  const CodeLine({
    required this.number,
    required this.runs,
    required this.y,
    this.dimmed = false,
    this.highlighted = false,
    this.index = 0,
    this.row = 0,
    this.continuation = false,
    this.opacity = 1,
    this.blurSigma = 0,
  });

  /// 1-based line number (display).
  final int number;
  final List<CodeRun> runs;

  /// Baseline offset from the content top (su) — the content top is
  /// [CodeScene.chromeHeight] below the frame top.
  final double y;

  /// Dimmed by a highlight step (07 §4.2).
  final bool dimmed;

  /// Highlighted by a highlight step.
  final bool highlighted;

  /// 0-based physical line (SL-26).
  final int index;

  /// 0-based visual row (SL-26).
  final int row;

  /// A wrapped continuation row: no number, the ↪ marker in the gutter
  /// (SL-26).
  final bool continuation;

  /// Line opacity from the highlight style (1 = normal; SL-26).
  final double opacity;

  /// Gaussian blur of the line from the highlight style (su; SL-26).
  final double blurSigma;
}

/// Kind of a [CodeBar].
enum CodeBarKind {
  /// Highlight band behind highlighted lines (`bar` style).
  bar,

  /// Rounded outline around a highlighted range (`box` style).
  box,

  /// Selection of the type-in animation.
  selection,

  /// The 3 su gutter marker next to highlighted lines.
  gutterMarker,
}

/// A rectangle drawn with the code: highlight bars and boxes, selections,
/// gutter markers (SL-26).
final class CodeBar {
  /// Creates a bar.
  const CodeBar({
    required this.kind,
    required this.rect,
    required this.color,
    this.opacity = 1,
    this.radius = 4,
    this.strokeWidth = 0,
  });

  final CodeBarKind kind;

  /// Element-local rectangle (su).
  final SuRect rect;

  /// ARGB.
  final int color;
  final double opacity;

  /// Corner radius (su).
  final double radius;

  /// Outline width (su); 0 = filled.
  final double strokeWidth;
}

/// The caret of a type-in animation (SL-26).
final class CodeCaret {
  /// Creates a caret.
  const CodeCaret({
    required this.rect,
    required this.color,
    this.opacity = 1,
    this.style = 'bar',
  });

  /// Element-local rectangle (su): a 2 su bar, a cell (block) or an
  /// underline.
  final SuRect rect;

  /// ARGB.
  final int color;
  final double opacity;

  /// `bar`, `block` or `underline`.
  final String style;
}

/// A per-step callout (07 §4.4), placed by its anchor; the bubble's text
/// layout (inline Markdown, body font at [fontSize]) is the painter's
/// (SL-26).
final class CodeCalloutPlacement {
  /// Creates a placement.
  const CodeCalloutPlacement({
    required this.step,
    required this.text,
    required this.style,
    required this.side,
    required this.anchorX,
    required this.anchorY,
    required this.anchorLine,
    required this.maxWidth,
    required this.fontSize,
    this.dx = 0,
    this.dy = 0,
    this.opacity = 1,
    this.rise = 0,
    this.color = 0xff2563eb,
    this.textColor = 0xffffffff,
    this.fontFamily = '',
  });

  /// 0-based step index.
  final int step;

  /// Inline Markdown (≤ 280 chars).
  final String text;

  /// `bubble`, `label` or `pill`.
  final String style;

  /// Resolved side: `right`, `left`, `above` or `below`.
  final String side;

  /// The anchor point (element-local su): the end of the anchor line for
  /// `right`, its start for `left`, the top/bottom of the range for
  /// `above`/`below`.
  final double anchorX;
  final double anchorY;

  /// 1-based anchor line.
  final int anchorLine;

  /// Maximum bubble width (su).
  final double maxWidth;

  /// Font size of the callout text (0.9 × code size).
  final double fontSize;

  /// Nudge set by dragging (su).
  final double dx;
  final double dy;

  /// 0..1 (fades in with its step).
  final double opacity;

  /// Remaining rise of the entrance animation (su, 12 → 0).
  final double rise;

  /// Bubble / pill fill and label leader color (ARGB; the deck theme's
  /// accent, SL-31).
  final int color;

  /// Text color on [color] (ARGB; labels use [color] for their text).
  final int textColor;

  /// Font family of the text (the deck's body font; '' = the code font).
  final String fontFamily;
}

/// A freely placed run of a morph frame (07 §5.6; SL-26).
final class CodePlacedRun {
  /// Creates a run.
  const CodePlacedRun({
    required this.text,
    required this.x,
    required this.baseline,
    required this.color,
    required this.fontSize,
    this.opacity = 1,
    this.bold = false,
    this.italic = false,
  });

  final String text;

  /// Element-local left edge and baseline (su).
  final double x;
  final double baseline;

  /// ARGB.
  final int color;

  /// Font size (su).
  final double fontSize;
  final double opacity;
  final bool bold;
  final bool italic;
}

/// A line number drawn by itself (morph frames; SL-26).
final class CodeGutterLabel {
  /// Creates a label.
  const CodeGutterLabel({
    required this.text,
    required this.baseline,
    required this.color,
    this.opacity = 1,
  });

  /// The number (or `↪` for a continuation row).
  final String text;

  /// Baseline (element-local su); right-aligned at
  /// [CodeScene.numbersRight].
  final double baseline;

  /// ARGB.
  final int color;
  final double opacity;
}

/// A code element's content in one state/step.
final class CodeScene {
  /// Creates a scene.
  const CodeScene({
    required this.width,
    required this.height,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.background,
    this.lines = const [],
    this.title,
    this.codeLeft = 0,
    this.numbersRight,
    this.lineNumberColor = 0,
    this.chromeHeight = 0,
    this.titleColor = 0,
    this.cornerRadius = 0,
    this.chrome = 'none',
    this.box,
    this.captionHeight = 0,
    this.titleHeight = 0,
    this.titleBackground = 0,
    this.language,
    this.codeArea,
    this.columnWidth = 0,
    this.gutterFontSize = 0,
    this.lineNumberActiveColor = 0,
    this.textColor = 0,
    this.border,
    this.borderWidth = 0,
    this.shadow = 'soft',
    this.scrollX = 0,
    this.scrollY = 0,
    this.hiddenRows = 0,
    this.bars = const [],
    this.caret,
    this.callouts = const [],
    this.glyphs = const [],
    this.gutter = const [],
    this.opacity = 1,
    this.underlay,
    this.underlayOpacity = 0,
    this.ligatures = false,
    this.paletteId,
    this.darkPalette = false,
    this.stateIndex = 0,
    this.step,
    this.semanticsLabel = '',
  });

  /// Content size (su).
  final double width;

  /// Content size (su).
  final double height;
  final String fontFamily;

  /// Font size (su).
  final double fontSize;

  /// Line advance (su).
  final double lineHeight;

  /// ARGB (0 = transparent).
  final int background;
  final List<CodeLine> lines;

  /// Filename tab / caption, or null.
  final String? title;

  /// Left edge of the code text (su; SL-10).
  final double codeLeft;

  /// Right edge of the line numbers (su), or null when hidden (SL-10).
  final double? numbersRight;

  /// ARGB of line numbers (SL-10).
  final int lineNumberColor;

  /// Height of the title bar above the code (su; 0 = none, SL-10). Line
  /// baselines are relative to the content top below it. With a caption
  /// (SL-26) it is caption + title height.
  final double chromeHeight;

  /// ARGB of the title (SL-10).
  final int titleColor;

  /// Corner radius of the background (su; SL-10).
  final double cornerRadius;

  // ----- SL-26 -----

  /// `none`, `tab`, `window` or `caption` (07 §3.4).
  final String chrome;

  /// The code box (element-local; below a caption). Null = the whole frame.
  final SuRect? box;

  /// Height of the caption above [box].
  final double captionHeight;

  /// Height of the tab/window title bar at the top of [box].
  final double titleHeight;

  /// ARGB of the tab / title bar background.
  final int titleBackground;

  /// Language badge text ("Dart") when `showLanguage`, else null.
  final String? language;

  /// The area the grid is drawn in (element-local; code is clipped to it).
  final SuRect? codeArea;

  /// Width of one grid column (su).
  final double columnWidth;

  /// Font size of the line numbers (0.85 × [fontSize]).
  final double gutterFontSize;

  /// ARGB of highlighted lines' numbers.
  final int lineNumberActiveColor;

  /// ARGB of plain text.
  final int textColor;

  /// Border color (ARGB) or null.
  final int? border;

  /// Border width (su).
  final double borderWidth;

  /// `none`, `soft` or `strong`.
  final String shadow;

  /// Viewport scroll inside [codeArea] (su; already applied to line
  /// baselines, runs and bars).
  final double scrollX;
  final double scrollY;

  /// Rows that don't fit (07 §3.3 overflow badge); 0 = everything fits.
  final int hiddenRows;

  /// Highlight bars/boxes, selections, gutter markers (drawn under the
  /// text, markers in the gutter).
  final List<CodeBar> bars;

  /// The type-in caret, or null.
  final CodeCaret? caret;

  /// Callouts of the current step.
  final List<CodeCalloutPlacement> callouts;

  /// A morph frame's freely placed runs: when non-empty, they replace the
  /// runs of [lines] (which then carry no runs).
  final List<CodePlacedRun> glyphs;

  /// Line numbers drawn by themselves (morph frames).
  final List<CodeGutterLabel> gutter;

  /// Opacity of this scene (crossfades).
  final double opacity;

  /// A scene drawn beneath with [underlayOpacity] (instant mode crossfade,
  /// reduced motion).
  final CodeScene? underlay;
  final double underlayOpacity;

  /// Whether ligatures are on (07 §3.3; off = `calt`/`liga` disabled).
  final bool ligatures;

  /// Id of the syntax palette used.
  final String? paletteId;

  /// Whether the palette is dark.
  final bool darkPalette;

  /// 0-based state shown.
  final int stateIndex;

  /// 0-based highlight step shown, or null.
  final int? step;

  /// "Code block, Dart, 24 lines, title lib/main.dart" (07 §13).
  final String semanticsLabel;
}
