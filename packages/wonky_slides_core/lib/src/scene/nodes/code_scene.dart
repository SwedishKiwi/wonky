/// The laid-out content of a code element in one state and highlight step
/// (07, `CodeElementModel.build(state, step, size)`, 12 §5.6).
///
/// Contract stub (SL-3); SL-26 fills it from `wonky_code` (tokens, palette,
/// monospace grid, chrome) and may add fields.
library;

/// One colored token run of a code line.
final class CodeRun {
  /// Creates a run.
  const CodeRun(
    this.text, {
    required this.color,
    this.bold = false,
    this.italic = false,
  });

  final String text;

  /// ARGB.
  final int color;
  final bool bold;
  final bool italic;
}

/// One laid-out code line.
final class CodeLine {
  /// Creates a line.
  const CodeLine({
    required this.number,
    required this.runs,
    required this.y,
    this.dimmed = false,
    this.highlighted = false,
  });

  /// 1-based line number (display).
  final int number;
  final List<CodeRun> runs;

  /// Baseline offset from the content top (su).
  final double y;

  /// Dimmed by a highlight step (07 §4.2).
  final bool dimmed;

  /// Highlighted by a highlight step.
  final bool highlighted;
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
  /// baselines are relative to the content top below it.
  final double chromeHeight;

  /// ARGB of the title (SL-10).
  final int titleColor;

  /// Corner radius of the background (su; SL-10).
  final double cornerRadius;
}
