/// Text layout contract (02 §11, 03 §6.3, 12 §5.4): one `TextLayoutEngine`
/// gives static rendering, the editing overlay, thumbnails and the PDF the
/// same line breaks. Implementations: `FlutterTextLayoutEngine` (app,
/// `dart:ui` paragraphs, SL-10) and `SlideTextLayout` (core, `pdf` font
/// metrics; server/headless, SL-10).
library;

import 'dart:convert';

import '../../theme/model/box_text_style.dart';
import '../../theme/resolve/resolved_theme.dart';

/// A rich text body (02 §4.1): Quill Delta inserts ending with `"\n"`.
final class TextBody {
  /// Creates a body from Delta [ops].
  const TextBody(this.ops);

  /// Parses a Delta JSON column (`SlideElement.text`, cell text, notes);
  /// null or malformed JSON = an empty body.
  factory TextBody.fromJson(String? json) {
    if (json == null || json.isEmpty) return empty;
    try {
      final raw = jsonDecode(json);
      if (raw is List) {
        return TextBody([
          for (final op in raw)
            if (op is Map) op.cast<String, Object?>(),
        ]);
      }
      if (raw is Map && raw['ops'] is List) {
        return TextBody([
          for (final op in raw['ops'] as List)
            if (op is Map) op.cast<String, Object?>(),
        ]);
      }
    } on FormatException {
      // Fall through: malformed bodies render empty.
    }
    return empty;
  }

  /// A body with plain [text] (one `"\n"` appended).
  factory TextBody.plain(String text) => TextBody([
    {'insert': text.endsWith('\n') ? text : '$text\n'},
  ]);

  /// The empty body (`[{"insert":"\n"}]`).
  static const empty = TextBody([
    {'insert': '\n'},
  ]);

  /// Delta operations (`{"insert": String, "attributes": {…}}`).
  final List<Map<String, Object?>> ops;

  /// The plain text (with the final `"\n"`).
  String get plainText =>
      ops.map((o) => o['insert'] is String ? o['insert'] : '').join();

  /// Whether the body holds no visible text.
  bool get isBlank => plainText.trim().isEmpty;

  /// Delta JSON.
  String toJson() => jsonEncode(ops);
}

/// The styles a text body is laid out with (02 §4.2): theme text styles
/// resolved for the deck appearance, the box's default style key and the
/// box-level properties after the placeholder chain. Produced by the
/// `TextStyleResolver` (SL-7).
final class ResolvedTextStyles {
  /// Creates the styles.
  const ResolvedTextStyles({
    required this.styles,
    required this.defaultStyle,
    this.box,
    this.theme,
  });

  /// Theme text styles by key (`title`, `body`, …).
  final Map<String, ResolvedTextStyle> styles;

  /// The box's default paragraph style key (placeholder type or `body`).
  final String defaultStyle;

  /// Box-level text properties (insets, anchor, auto-fit, columns, …).
  final BoxTextStyle? box;

  /// The theme the styles were resolved from (run fonts, colors, list
  /// markers and links of the layout engines, SL-10); null = the engines
  /// fall back to the paragraph styles only.
  final ResolvedTheme? theme;

  /// A copy with [box] replaced (the scene builder merges the theme's
  /// default object style underneath, 05 §2.7).
  ResolvedTextStyles withBox(BoxTextStyle? box) => ResolvedTextStyles(
    styles: styles,
    defaultStyle: defaultStyle,
    box: box,
    theme: theme,
  );

  /// The style of a paragraph with `style` attribute [key] (null = the
  /// default), falling back to `body`.
  ResolvedTextStyle styleFor(String? key) =>
      styles[key ?? defaultStyle] ?? styles[defaultStyle] ?? styles['body']!;
}

/// One positioned run of text with uniform style.
final class TextRunBox {
  /// Creates a run.
  const TextRunBox({
    required this.text,
    required this.start,
    required this.x,
    required this.width,
    required this.fontFamily,
    required this.fontSize,
    required this.color,
    this.fontWeight = 400,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.highlight,
    this.letterSpacing = 0,
    this.baselineShift = 0,
    this.link,
  });

  /// The run's characters (display transform applied).
  final String text;

  /// Offset of the run's first character in the body's plain text.
  final int start;

  /// Left edge relative to the line (su).
  final double x;

  /// Advance width (su).
  final double width;
  final String fontFamily;

  /// Size (su).
  final double fontSize;
  final int fontWeight;
  final bool italic;
  final bool underline;
  final bool strike;

  /// ARGB.
  final int color;

  /// ARGB text background, or null.
  final int? highlight;

  /// su.
  final double letterSpacing;

  /// Superscript (> 0) / subscript (< 0) shift (su).
  final double baselineShift;

  /// Link target, or null.
  final String? link;
}

/// One laid-out line.
final class TextLineBox {
  /// Creates a line.
  const TextLineBox({
    required this.top,
    required this.baseline,
    required this.height,
    required this.left,
    required this.width,
    required this.start,
    required this.end,
    required this.runs,
    this.paragraph = 0,
    this.bullet,
  });

  /// Top relative to the text box content (su).
  final double top;

  /// Baseline relative to the text box content (su).
  final double baseline;

  /// Line height (su).
  final double height;

  /// Left edge after alignment and indent (su).
  final double left;

  /// Width of the laid-out glyphs (su).
  final double width;

  /// Character range `[start, end)` in the body's plain text.
  final int start;

  /// See [start].
  final int end;

  final List<TextRunBox> runs;

  /// Index of the paragraph the line belongs to.
  final int paragraph;

  /// The list marker of the paragraph's first line, or null.
  final TextRunBox? bullet;
}

/// The result of laying out a body in a box width.
final class TextLayoutResult {
  /// Creates a result.
  const TextLayoutResult({
    required this.width,
    required this.height,
    required this.lines,
    this.fitScale = 1,
    this.overflows = false,
  });

  /// An empty layout.
  static const empty = TextLayoutResult(width: 0, height: 0, lines: []);

  /// Layout width (the box width minus insets, su).
  final double width;

  /// Content height (su).
  final double height;
  final List<TextLineBox> lines;

  /// Auto-fit font scale applied (`shrink`, 03 §6.2); 1 = none.
  final double fitScale;

  /// Whether the text overflows the box height (no auto-fit room left).
  final bool overflows;

  /// Line breaks as character offsets (the `LineBreakHints` the client
  /// passes to the PDF writer, 10 §11.3).
  List<int> get lineBreaks => [for (final l in lines) l.end];
}

/// Lays out rich text bodies.
abstract interface class TextLayoutEngine {
  /// Lays out [body] with [styles] in [width] su at [scale] (font size
  /// multiplier, auto-fit).
  TextLayoutResult layout(
    TextBody body,
    ResolvedTextStyles styles, {
    required double width,
    double scale = 1,
  });
}
