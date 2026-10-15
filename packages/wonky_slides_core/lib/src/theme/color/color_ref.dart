/// `ColorRef` values (Slides 02 §2.2): hex colors, theme color references
/// with OKLCH lightness and alpha modifiers, and `transparent`.
library;

import 'oklch.dart';

/// The 11 color keys every theme color scheme defines (05 §2.2), in display
/// order.
const List<String> themeColorKeys = [
  'bg1',
  'text1',
  'bg2',
  'text2',
  'accent1',
  'accent2',
  'accent3',
  'accent4',
  'accent5',
  'accent6',
  'link',
];

/// Maximum number of custom theme colors (`custom1`…`custom12`).
const int maxCustomThemeColors = 12;

/// Whether [key] names a scheme color or a custom color slot.
bool isThemeColorKey(String key) {
  if (themeColorKeys.contains(key)) return true;
  final m = RegExp(r'^custom([1-9]|1[0-2])$').firstMatch(key);
  return m != null;
}

/// Thrown by [ColorRef.parse] for malformed values.
final class ColorRefFormatException extends FormatException {
  /// Creates the exception.
  const ColorRefFormatException(super.message, [super.source]);
}

/// A modifier of a theme color reference.
sealed class ColorModifier {
  const ColorModifier();

  /// Applies the modifier to an ARGB color.
  int apply(int argb);
}

/// `lum:±x` (−1…+1): lightens (towards white) or darkens (towards black) in
/// OKLCH lightness, keeping hue and chroma (gamut-mapped).
final class LumModifier extends ColorModifier {
  /// Creates the modifier.
  const LumModifier(this.amount);

  /// −1…+1.
  final double amount;

  @override
  int apply(int argb) {
    final c = Oklch.fromArgb(argb);
    final l = amount >= 0 ? c.l + (1 - c.l) * amount : c.l * (1 + amount);
    return c.copyWith(l: l.clamp(0.0, 1.0)).toArgb();
  }

  @override
  bool operator ==(Object other) =>
      other is LumModifier && other.amount == amount;

  @override
  int get hashCode => amount.hashCode;

  @override
  String toString() => 'lum:${amount >= 0 ? '+' : ''}${_fmt(amount)}';
}

/// `alpha:x` (0…1): multiplies the color's alpha.
final class AlphaModifier extends ColorModifier {
  /// Creates the modifier.
  const AlphaModifier(this.alpha);

  /// 0…1.
  final double alpha;

  @override
  int apply(int argb) => withOpacity(argb, alpha);

  @override
  bool operator ==(Object other) =>
      other is AlphaModifier && other.alpha == alpha;

  @override
  int get hashCode => alpha.hashCode;

  @override
  String toString() => 'alpha:${_fmt(alpha)}';
}

String _fmt(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toString();
}

/// A color value as stored in slide and theme JSON.
sealed class ColorRef {
  const ColorRef();

  /// Parses `#RRGGBB`, `#RRGGBBAA`, `theme:<key>[/lum:±x][/alpha:x]` or
  /// `transparent`. Throws [ColorRefFormatException].
  factory ColorRef.parse(String value) {
    final v = value.trim();
    if (v == 'transparent') return const TransparentColor();
    if (v.startsWith('#')) return HexColor(parseHexArgb(v));
    if (v.startsWith('theme:')) {
      final parts = v.substring(6).split('/');
      final key = parts.first;
      if (!isThemeColorKey(key)) {
        throw ColorRefFormatException('Unknown theme color "$key".', value);
      }
      final modifiers = <ColorModifier>[];
      for (final p in parts.skip(1)) {
        final i = p.indexOf(':');
        final name = i < 0 ? p : p.substring(0, i);
        final amount = i < 0 ? null : double.tryParse(p.substring(i + 1));
        switch (name) {
          case 'lum' when amount != null && amount >= -1 && amount <= 1:
            modifiers.add(LumModifier(amount));
          case 'alpha' when amount != null && amount >= 0 && amount <= 1:
            modifiers.add(AlphaModifier(amount));
          default:
            throw ColorRefFormatException('Bad color modifier "$p".', value);
        }
      }
      return ThemeColor(key, modifiers);
    }
    throw ColorRefFormatException('Not a color: "$value".', value);
  }

  /// [ColorRef.parse] that returns `null` instead of throwing.
  static ColorRef? tryParse(Object? value) {
    if (value is! String) return null;
    try {
      return ColorRef.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// Parses `#RRGGBB` / `#RRGGBBAA` to ARGB. Throws
  /// [ColorRefFormatException].
  static int parseHexArgb(String hex) {
    final h = hex.startsWith('#') ? hex.substring(1) : hex;
    if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(h)) {
      throw ColorRefFormatException('Not a hex color: "$hex".', hex);
    }
    final rgb = int.parse(h.substring(0, 6), radix: 16);
    final a = h.length == 8 ? int.parse(h.substring(6), radix: 16) : 0xff;
    return (a << 24) | rgb;
  }

  /// Formats ARGB as `#RRGGBB` (opaque) or `#RRGGBBAA`.
  static String formatHex(int argb) {
    final rgb = (argb & 0xffffff).toRadixString(16).padLeft(6, '0');
    final a = (argb >>> 24) & 0xff;
    final out = a == 0xff
        ? '#$rgb'
        : '#$rgb${a.toRadixString(16).padLeft(2, '0')}';
    return out.toUpperCase();
  }

  /// The JSON string form.
  String get json;

  /// Resolves to ARGB using [themeColor] for theme keys (`null` when the key
  /// is unknown in the theme, e.g. a missing custom color → `null`).
  int? resolve(int? Function(String key) themeColor);

  @override
  String toString() => json;
}

/// An explicit `#RRGGBB[AA]` color.
final class HexColor extends ColorRef {
  /// Creates a hex color from ARGB.
  const HexColor(this.argb);

  /// ARGB value.
  final int argb;

  @override
  String get json => ColorRef.formatHex(argb);

  @override
  int resolve(int? Function(String key) themeColor) => argb;

  @override
  bool operator ==(Object other) => other is HexColor && other.argb == argb;

  @override
  int get hashCode => argb.hashCode;
}

/// A theme color reference with optional modifiers.
final class ThemeColor extends ColorRef {
  /// Creates a reference to [key].
  const ThemeColor(this.key, [this.modifiers = const []]);

  /// `bg1`, `text1`, …, `customN`.
  final String key;

  /// Modifiers applied in order.
  final List<ColorModifier> modifiers;

  @override
  String get json => 'theme:$key${[for (final m in modifiers) '/$m'].join()}';

  @override
  int? resolve(int? Function(String key) themeColor) {
    var c = themeColor(key);
    if (c == null) return null;
    for (final m in modifiers) {
      c = m.apply(c!);
    }
    return c;
  }

  @override
  bool operator ==(Object other) => other is ThemeColor && other.json == json;

  @override
  int get hashCode => json.hashCode;
}

/// `transparent`.
final class TransparentColor extends ColorRef {
  /// The transparent color.
  const TransparentColor();

  @override
  String get json => 'transparent';

  @override
  int resolve(int? Function(String key) themeColor) => 0x00000000;

  @override
  bool operator ==(Object other) => other is TransparentColor;

  @override
  int get hashCode => 0;
}
