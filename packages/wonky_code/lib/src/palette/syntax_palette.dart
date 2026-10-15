import 'dart:math' as math;

import '../syntax_token.dart';

/// Light or dark content colors (pure Dart; Flutter's `Brightness` is not
/// available here).
enum PaletteBrightness {
  /// Dark text on a light background.
  light,

  /// Light text on a dark background.
  dark,
}

/// How a palette draws one [SyntaxToken] (Write 06 §2.5 token style).
final class TokenStyle {
  /// Creates a style.
  const TokenStyle(this.color, {this.bold = false, this.italic = false});

  /// Parses `{"color": "#rrggbb", "fontStyle"?: "italic", "fontWeight"?: int}`.
  factory TokenStyle.fromJson(Map<String, Object?> json) {
    final weight = json['fontWeight'];
    return TokenStyle(
      SyntaxPalette.parseColor(json['color']),
      bold: weight is num && weight >= 600,
      italic: json['fontStyle'] == 'italic',
    );
  }

  /// Text color, ARGB (`0xAARRGGBB`).
  final int color;

  /// Bold (font weight 700).
  final bool bold;

  /// Italic.
  final bool italic;

  /// The JSON form ([TokenStyle.fromJson]).
  Map<String, Object?> toJson() => {
    'color': SyntaxPalette.formatColor(color),
    if (italic) 'fontStyle': 'italic',
    if (bold) 'fontWeight': 700,
  };

  @override
  bool operator ==(Object other) =>
      other is TokenStyle &&
      other.color == color &&
      other.bold == bold &&
      other.italic == italic;

  @override
  int get hashCode => Object.hash(color, bold, italic);

  @override
  String toString() =>
      'TokenStyle(${SyntaxPalette.formatColor(color)}'
      '${bold ? ', bold' : ''}${italic ? ', italic' : ''})';
}

/// A code color palette: token colors plus the chrome colors of a code view
/// (Slides 07 §2.3/§2.5). Content colors: the app theme never changes them.
///
/// JSON (colors `#rrggbb` or `#rrggbbaa`):
///
/// ```json
/// {"id": "wonky-light", "name": "Wonky Light", "brightness": "light",
///  "background": "#f6f8fa", "text": "#24292f", "lineNumber": "#…",
///  "lineNumberActive": "#…", "selection": "#8250df40", "caret": "#…",
///  "highlightBar": "#…", "dimOverlay": "#f6f8fab3",
///  "titleTabBackground": "#…", "titleTabText": "#…", "border": "#…",
///  "tokens": {"keyword": {"color": "#cf222e"},
///             "comment": {"color": "#57606a", "fontStyle": "italic"}, …}}
/// ```
///
/// `tokens` uses the Write theme `syntax` format (Write 06 §2.5); unlisted
/// tokens render in [text].
final class SyntaxPalette {
  /// Creates a palette.
  const SyntaxPalette({
    required this.id,
    required this.name,
    required this.brightness,
    required this.background,
    required this.text,
    required this.lineNumber,
    required this.lineNumberActive,
    required this.selection,
    required this.caret,
    required this.highlightBar,
    required this.dimOverlay,
    required this.titleTabBackground,
    required this.titleTabText,
    required this.border,
    required this.tokens,
  });

  /// Parses the JSON form (see the class documentation). Missing chrome
  /// colors fall back to [text]/[background]-derived values; unknown token
  /// keys are ignored. Throws [FormatException] for a missing or malformed
  /// `background` or `text`.
  factory SyntaxPalette.fromJson(Map<String, Object?> json) {
    final background = parseColor(json['background']);
    final text = parseColor(json['text']);
    int color(String key, int fallback) {
      final value = json[key];
      return value == null ? fallback : parseColor(value);
    }

    final tokens = <SyntaxToken, TokenStyle>{};
    final rawTokens = json['tokens'];
    if (rawTokens is Map) {
      for (final MapEntry(:key, :value) in rawTokens.entries) {
        final token = SyntaxToken.fromJsonName('$key');
        if (token == null || value is! Map) continue;
        tokens[token] = TokenStyle.fromJson(value.cast<String, Object?>());
      }
    }
    return SyntaxPalette(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? json['id'] ?? ''}',
      brightness: json['brightness'] == 'dark'
          ? PaletteBrightness.dark
          : PaletteBrightness.light,
      background: background,
      text: text,
      lineNumber: color('lineNumber', text),
      lineNumberActive: color('lineNumberActive', text),
      selection: color('selection', (text & 0x00ffffff) | 0x40000000),
      caret: color('caret', text),
      highlightBar: color('highlightBar', text),
      dimOverlay: color('dimOverlay', (background & 0x00ffffff) | 0xb3000000),
      titleTabBackground: color('titleTabBackground', background),
      titleTabText: color('titleTabText', text),
      border: color('border', text),
      tokens: Map.unmodifiable(tokens),
    );
  }

  /// Stable id (`wonky-light`, `github-dark`, …).
  final String id;

  /// Display name.
  final String name;

  /// Whether the palette is for light or dark backgrounds.
  final PaletteBrightness brightness;

  /// Code background, ARGB.
  final int background;

  /// Plain text (tokens without a style), ARGB.
  final int text;

  /// Line numbers.
  final int lineNumber;

  /// Line numbers of highlighted (or the caret's) lines.
  final int lineNumberActive;

  /// Selection fill (translucent).
  final int selection;

  /// Caret.
  final int caret;

  /// Marker bar of highlighted lines.
  final int highlightBar;

  /// Overlay over dimmed (not highlighted) lines (translucent background).
  final int dimOverlay;

  /// Background of a title tab / window bar.
  final int titleTabBackground;

  /// Text of a title tab / window bar.
  final int titleTabText;

  /// Box border.
  final int border;

  /// Token styles; unlisted tokens render in [text].
  final Map<SyntaxToken, TokenStyle> tokens;

  /// The style of [token] (`null` → plain [text]).
  TokenStyle styleOf(SyntaxToken? token) =>
      (token == null ? null : tokens[token]) ?? TokenStyle(text);

  /// The JSON form ([SyntaxPalette.fromJson]).
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'brightness': brightness.name,
    'background': formatColor(background),
    'text': formatColor(text),
    'lineNumber': formatColor(lineNumber),
    'lineNumberActive': formatColor(lineNumberActive),
    'selection': formatColor(selection),
    'caret': formatColor(caret),
    'highlightBar': formatColor(highlightBar),
    'dimOverlay': formatColor(dimOverlay),
    'titleTabBackground': formatColor(titleTabBackground),
    'titleTabText': formatColor(titleTabText),
    'border': formatColor(border),
    'tokens': {
      for (final token in SyntaxToken.values)
        if (tokens[token] case final style?) token.jsonName: style.toJson(),
    },
  };

  @override
  String toString() => 'SyntaxPalette($id)';

  /// Parses `#rgb`, `#rrggbb` or `#rrggbbaa` into ARGB. Throws
  /// [FormatException] otherwise.
  static int parseColor(Object? value) {
    if (value is! String || !value.startsWith('#')) {
      throw FormatException('Expected a color "#rrggbb"', value);
    }
    var hex = value.substring(1);
    if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null || (hex.length != 6 && hex.length != 8)) {
      throw FormatException('Expected a color "#rrggbb"', value);
    }
    if (hex.length == 6) return 0xff000000 | parsed;
    return ((parsed & 0xff) << 24) | (parsed >> 8);
  }

  /// Formats ARGB as `#rrggbb` (opaque) or `#rrggbbaa`.
  static String formatColor(int argb) {
    final rgb = (argb & 0xffffff).toRadixString(16).padLeft(6, '0');
    final alpha = (argb >> 24) & 0xff;
    return alpha == 0xff
        ? '#$rgb'
        : '#$rgb${alpha.toRadixString(16).padLeft(2, '0')}';
  }

  /// WCAG relative luminance of an ARGB color (alpha ignored), 0…1.
  static double relativeLuminance(int argb) {
    double channel(int shift) {
      final c = ((argb >> shift) & 0xff) / 255;
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
  }

  /// WCAG contrast ratio of two ARGB colors (alpha ignored), 1…21.
  static double contrastRatio(int a, int b) {
    final la = relativeLuminance(a), lb = relativeLuminance(b);
    final hi = math.max(la, lb), lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }
}
