/// `DeckTheme.colorsJson` (Slides 05 §2.2): two complete color schemes and
/// up to 12 custom colors.
library;

import '../color/color_ref.dart';
import '../json/json_util.dart';
import 'common.dart';

/// One complete color scheme: the 11 keys of [themeColorKeys] as ARGB.
final class ThemeColorScheme {
  /// Creates a scheme from ARGB values keyed by [themeColorKeys].
  ThemeColorScheme(Map<String, int> colors)
    : colors = Map.unmodifiable({
        for (final k in themeColorKeys) k: colors[k]!,
      });

  /// Creates a scheme from hex strings in [themeColorKeys] order
  /// (`bg1, text1, bg2, text2, accent1…6, link`).
  factory ThemeColorScheme.fromHexList(List<String> hex) {
    assert(hex.length == themeColorKeys.length);
    return ThemeColorScheme({
      for (var i = 0; i < themeColorKeys.length; i++)
        themeColorKeys[i]: ColorRef.parseHexArgb(hex[i]),
    });
  }

  /// ARGB per key.
  final Map<String, int> colors;

  /// The ARGB value of [key] (a scheme key), or `null`.
  int? operator [](String key) => colors[key];

  /// Slide background.
  int get bg1 => colors['bg1']!;

  /// Primary text.
  int get text1 => colors['text1']!;

  /// Alternate surface.
  int get bg2 => colors['bg2']!;

  /// Secondary text.
  int get text2 => colors['text2']!;

  /// Links.
  int get link => colors['link']!;

  /// `accent1`…`accent6` (1-based [n]).
  int accent(int n) => colors['accent$n']!;

  /// JSON object `{bg1: "#…", …}`.
  JsonMap toJson() => {
    for (final k in themeColorKeys) k: ColorRef.formatHex(colors[k]!),
  };

  /// Parses a scheme; every key is required and must be a hex color.
  static ThemeColorScheme? fromJson(Object? json, String path, IssueSink sink) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: themeColorKeys.toSet(),
    );
    if (r == null) return null;
    final out = <String, int>{};
    for (final k in themeColorKeys) {
      final c = readColor(r, k, required: true, allowThemeRefs: false);
      if (c is HexColor) out[k] = c.argb;
    }
    return out.length == themeColorKeys.length ? ThemeColorScheme(out) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeColorScheme &&
      themeColorKeys.every((k) => other.colors[k] == colors[k]);

  @override
  int get hashCode =>
      Object.hashAll([for (final k in themeColorKeys) colors[k]]);
}

/// A named custom color with a light and a dark value (`theme:customN`).
final class ThemeCustomColor {
  /// Creates a custom color.
  const ThemeCustomColor({
    required this.name,
    required this.light,
    required this.dark,
  });

  /// Display name ("Brand orange").
  final String name;

  /// ARGB in the light scheme.
  final int light;

  /// ARGB in the dark scheme.
  final int dark;

  /// The value for [appearance].
  int forAppearance(SlideAppearance appearance) =>
      appearance == SlideAppearance.dark ? dark : light;

  /// JSON form.
  JsonMap toJson() => {
    'name': name,
    'light': ColorRef.formatHex(light),
    'dark': ColorRef.formatHex(dark),
  };

  @override
  bool operator ==(Object other) =>
      other is ThemeCustomColor &&
      other.name == name &&
      other.light == light &&
      other.dark == dark;

  @override
  int get hashCode => Object.hash(name, light, dark);
}

/// The `colorsJson` column.
final class ThemeColors {
  /// Creates the colors.
  const ThemeColors({
    required this.light,
    required this.dark,
    this.custom = const [],
  });

  /// The light scheme.
  final ThemeColorScheme light;

  /// The dark scheme.
  final ThemeColorScheme dark;

  /// Custom colors (≤ [maxCustomThemeColors]); `customN` is `custom[N-1]`.
  final List<ThemeCustomColor> custom;

  /// The scheme for [appearance].
  ThemeColorScheme scheme(SlideAppearance appearance) =>
      appearance == SlideAppearance.dark ? dark : light;

  /// ARGB of a theme color key (`bg1`, …, `customN`) in [appearance], or
  /// `null` when the key does not exist.
  int? colorOf(String key, SlideAppearance appearance) {
    final c = scheme(appearance)[key];
    if (c != null) return c;
    final m = RegExp(r'^custom(\d+)$').firstMatch(key);
    if (m == null) return null;
    final i = int.parse(m.group(1)!) - 1;
    if (i < 0 || i >= custom.length) return null;
    return custom[i].forAppearance(appearance);
  }

  /// The JSON column value.
  JsonMap toJson() => {
    'v': 1,
    'light': light.toJson(),
    'dark': dark.toJson(),
    if (custom.isNotEmpty) 'custom': [for (final c in custom) c.toJson()],
  };

  /// Parses the column (errors → `null`).
  static ThemeColors? fromJson(
    Object? json,
    IssueSink sink, {
    String path = 'colorsJson',
  }) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {'v', 'light', 'dark', 'custom'},
    );
    if (r == null) return null;
    r.version(required: true);
    final light = ThemeColorScheme.fromJson(
      r.map['light'],
      r.at('light'),
      sink,
    );
    final dark = ThemeColorScheme.fromJson(r.map['dark'], r.at('dark'), sink);
    final custom = <ThemeCustomColor>[];
    final list = r.list('custom') ?? const [];
    if (list.length > maxCustomThemeColors) {
      sink.error(
        r.at('custom'),
        'too_many',
        'At most $maxCustomThemeColors custom colors.',
      );
    }
    for (var i = 0; i < list.length && i < maxCustomThemeColors; i++) {
      final c = JsonReader.object(
        list[i],
        '${r.at('custom')}[$i]',
        sink,
        known: {'name', 'light', 'dark'},
      );
      if (c == null) continue;
      final name = c.string('name', required: true);
      final l = readColor(c, 'light', required: true, allowThemeRefs: false);
      final d = readColor(c, 'dark', required: true, allowThemeRefs: false);
      if (name != null && l is HexColor && d is HexColor) {
        custom.add(ThemeCustomColor(name: name, light: l.argb, dark: d.argb));
      }
    }
    if (light == null || dark == null) return null;
    return ThemeColors(
      light: light,
      dark: dark,
      custom: List.unmodifiable(custom),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeColors && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}
