/// Theme palette keys and the `ColorRef` value type (06 §2.1, §2.2).
library;

import 'json_util.dart';

/// Role of a palette key for dark-palette derivation (06 §4).
enum PaletteRole {
  /// Backgrounds (`page`, `codeBg`, …).
  surface,

  /// Text colors (`text`, `muted`, …).
  foreground,

  /// Accent colors (`accent`, `link`, `custom*`, …).
  accent,

  /// Lines drawn on surfaces (`border`, `quoteBar`).
  line,
}

/// The fixed keys of a theme palette (06 §2.2).
enum PaletteKey implements JsonEnum {
  /// Body text.
  text(PaletteRole.foreground),

  /// Heading text.
  heading(PaletteRole.foreground),

  /// Secondary text: captions, header/footer.
  muted(PaletteRole.foreground),

  /// Accent color.
  accent(PaletteRole.accent),

  /// Link text.
  link(PaletteRole.accent),

  /// Link text while hovered.
  linkHover(PaletteRole.accent),

  /// Page / paper surface.
  page(PaletteRole.surface),

  /// Area around pages.
  canvas(PaletteRole.surface),

  /// Borders and rules.
  border(PaletteRole.line),

  /// Code text.
  codeText(PaletteRole.foreground),

  /// Code background.
  codeBg(PaletteRole.surface),

  /// Blockquote text.
  quoteText(PaletteRole.foreground),

  /// Blockquote bar.
  quoteBar(PaletteRole.line),

  /// Blockquote background.
  quoteBg(PaletteRole.surface),

  /// Table header background.
  tableHeaderBg(PaletteRole.surface),

  /// Zebra stripe background.
  tableStripe(PaletteRole.surface),

  /// Mention chip background.
  mentionBg(PaletteRole.surface),

  /// Mention chip text.
  mentionText(PaletteRole.foreground),

  /// Text highlight.
  highlight(PaletteRole.surface),

  /// Free user color 1.
  custom1(PaletteRole.accent),

  /// Free user color 2.
  custom2(PaletteRole.accent),

  /// Free user color 3.
  custom3(PaletteRole.accent),

  /// Free user color 4.
  custom4(PaletteRole.accent),

  /// Free user color 5.
  custom5(PaletteRole.accent),

  /// Free user color 6.
  custom6(PaletteRole.accent);

  const PaletteKey(this.role);

  /// Derivation role of this key.
  final PaletteRole role;

  @override
  String get json => name;

  /// Whether the key is one of the optional `custom1…custom6` colors.
  bool get isCustom => name.startsWith('custom');

  /// The key for JSON name [name], or `null`.
  static PaletteKey? fromJsonName(String name) =>
      enumFromJson(PaletteKey.values, name);
}

/// Kind of a [ColorRef].
enum ColorRefKind {
  /// A literal sRGB color with alpha.
  rgb,

  /// A reference to a palette entry (`"@accent"`).
  palette,

  /// Fully transparent (`"transparent"`).
  transparent,
}

/// A theme color reference: `"#RRGGBB"`, `"#RRGGBBAA"`, `"@<paletteKey>"` or
/// `"transparent"` (06 §2.1). `null` (no `ColorRef`) means *inherit*.
final class ColorRef {
  /// A literal color given as 32-bit ARGB (`0xAARRGGBB`).
  const ColorRef.argb(int argb)
    : kind = ColorRefKind.rgb,
      _argb = argb,
      paletteKey = null;

  /// A reference to the palette entry [key].
  const ColorRef.palette(PaletteKey key)
    : kind = ColorRefKind.palette,
      _argb = null,
      paletteKey = key;

  /// Fully transparent.
  static const transparent = ColorRef._transparent();

  const ColorRef._transparent()
    : kind = ColorRefKind.transparent,
      _argb = 0,
      paletteKey = null;

  /// What this reference is.
  final ColorRefKind kind;

  final int? _argb;

  /// The referenced palette key for [ColorRefKind.palette], else `null`.
  final PaletteKey? paletteKey;

  /// The literal ARGB value for [ColorRefKind.rgb] (0 for transparent), else
  /// `null`.
  int? get argb => _argb;

  static final _hex = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

  /// Parses a color reference. Throws a [FormatException] for invalid input
  /// (including unknown palette keys).
  static ColorRef parse(String text) {
    final c = tryParse(text);
    if (c == null) throw FormatException('Invalid color', text);
    return c;
  }

  /// Like [parse] but returns `null` for invalid input.
  static ColorRef? tryParse(String text) {
    if (text == 'transparent') return transparent;
    if (text.startsWith('@')) {
      final key = PaletteKey.fromJsonName(text.substring(1));
      return key == null ? null : ColorRef.palette(key);
    }
    if (!_hex.hasMatch(text)) return null;
    return ColorRef.argb(parseHexColor(text)!);
  }

  /// Parses `#RRGGBB` / `#RRGGBBAA` to ARGB, or returns `null`.
  static int? parseHexColor(String text) {
    if (!_hex.hasMatch(text)) return null;
    final rgb = int.parse(text.substring(1, 7), radix: 16);
    final a = text.length == 9 ? int.parse(text.substring(7), radix: 16) : 255;
    return (a << 24) | rgb;
  }

  /// The JSON form: lower-case `#rrggbb` (opaque) or `#rrggbbaa`,
  /// `@key` or `transparent`.
  String toJson() => switch (kind) {
    ColorRefKind.transparent => 'transparent',
    ColorRefKind.palette => '@${paletteKey!.name}',
    ColorRefKind.rgb => argbToHex(_argb!, withAlpha: (_argb >>> 24) != 255),
  };

  @override
  bool operator ==(Object other) =>
      other is ColorRef &&
      other.kind == kind &&
      other._argb == _argb &&
      other.paletteKey == paletteKey;

  @override
  int get hashCode => Object.hash(kind, _argb, paletteKey);

  @override
  String toString() => toJson();
}

/// Formats ARGB [argb] as lower-case `#rrggbb`, or `#rrggbbaa` when
/// [withAlpha] is true.
String argbToHex(int argb, {bool withAlpha = false}) {
  final rgb = (argb & 0xffffff).toRadixString(16).padLeft(6, '0');
  if (!withAlpha) return '#$rgb';
  final a = ((argb >>> 24) & 0xff).toRadixString(16).padLeft(2, '0');
  return '#$rgb$a';
}
