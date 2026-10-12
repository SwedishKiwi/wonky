import 'dart:convert';
import 'dart:math' as math;

/// Spreadsheet theme (`Spreadsheet.themeJson`, 06 §13).
final class SpreadsheetTheme {
  /// Creates a theme.
  const SpreadsheetTheme({this.name = 'Standard', this.textFont = 'Inter', this.colors = const {}});

  /// Theme name (preset name or custom).
  final String name;

  /// Default cell font (`fonts.text`).
  final String textFont;

  /// Colors: `text`, `background`, `accent1`…`accent6`, `link` (`#RRGGBB`).
  final Map<String, String> colors;

  /// Color keys in UI order.
  static const colorKeys = [
    'text',
    'background',
    'accent1',
    'accent2',
    'accent3',
    'accent4',
    'accent5',
    'accent6',
    'link',
  ];

  /// The standard theme.
  static const standard = SpreadsheetTheme(
    name: 'Standard',
    textFont: 'Inter',
    colors: {
      'text': '#000000',
      'background': '#FFFFFF',
      'accent1': '#4285F4',
      'accent2': '#EA4335',
      'accent3': '#FBBC04',
      'accent4': '#34A853',
      'accent5': '#FF6D01',
      'accent6': '#46BDC6',
      'link': '#1155CC',
    },
  );

  /// Built-in presets (06 §13.2).
  static final List<SpreadsheetTheme> presets = [
    standard,
    _preset('Simple', 'Roboto', '#3C78D8 #6AA84F #F1C232 #CC0000 #674EA7 #E69138', '#1155CC'),
    _preset('Streamline', 'Lato', '#2C3E50 #3498DB #1ABC9C #F39C12 #E74C3C #9B59B6', '#2980B9'),
    _preset(
      'Paperback',
      'Merriweather',
      '#5D4037 #8D6E63 #A1887F #BCAAA4 #D7CCC8 #6D4C41',
      '#5D4037',
    ),
    _preset(
      'Marina',
      'Source Sans 3',
      '#00796B #0097A7 #0288D1 #26A69A #80CBC4 #004D40',
      '#00796B',
    ),
    _preset('Coral', 'Nunito', '#FF7043 #FFAB91 #F4511E #FFCCBC #BF360C #FF8A65', '#D84315'),
    _preset('Forest', 'Open Sans', '#2E7D32 #66BB6A #A5D6A7 #558B2F #9CCC65 #1B5E20', '#2E7D32'),
    _preset('Mono', 'Roboto Mono', '#212121 #424242 #616161 #757575 #9E9E9E #BDBDBD', '#1A73E8'),
    _preset('Retro', 'Courier Prime', '#E76F51 #F4A261 #E9C46A #2A9D8F #264653 #8AB17D', '#264653'),
    _preset('Ocean', 'Montserrat', '#023E8A #0077B6 #0096C7 #00B4D8 #48CAE4 #90E0EF', '#0077B6'),
  ];

  static SpreadsheetTheme _preset(String name, String font, String accents, String link) {
    final a = accents.split(' ');
    return SpreadsheetTheme(
      name: name,
      textFont: font,
      colors: {
        'text': '#000000',
        'background': '#FFFFFF',
        for (var i = 0; i < 6; i++) 'accent${i + 1}': a[i],
        'link': link,
      },
    );
  }

  /// Preset by name (case-insensitive) or null.
  static SpreadsheetTheme? preset(String name) {
    final n = name.toLowerCase();
    for (final p in presets) {
      if (p.name.toLowerCase() == n) return p;
    }
    return null;
  }

  /// Parses `themeJson`; empty/invalid → [standard]. Missing colors fall back to
  /// the standard theme.
  static SpreadsheetTheme parse(String? json) {
    if (json == null || json.trim().isEmpty) return standard;
    final cached = _cache[json];
    if (cached != null) return cached;
    Object? m;
    try {
      m = jsonDecode(json);
    } on FormatException {
      return standard;
    }
    if (m is! Map) return standard;
    final fonts = m['fonts'];
    final colors = m['colors'];
    final merged = Map<String, String>.of(standard.colors);
    if (colors is Map) {
      colors.forEach((k, v) {
        if (k is String && v is String && _hex.hasMatch(v)) merged[k] = v.toUpperCase();
      });
    }
    final t = SpreadsheetTheme(
      name: m['name'] is String ? m['name'] as String : 'Custom',
      textFont: fonts is Map && fonts['text'] is String ? fonts['text'] as String : 'Inter',
      colors: merged,
    );
    if (_cache.length > 64) _cache.clear();
    _cache[json] = t;
    return t;
  }

  static final Map<String, SpreadsheetTheme> _cache = {};
  static final RegExp _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// `themeJson` encoding.
  String toJson() => jsonEncode({
    'v': 1,
    'name': name,
    'fonts': {'text': textFont},
    'colors': colors,
  });

  /// Copy with changes.
  SpreadsheetTheme copyWith({String? name, String? textFont, Map<String, String>? colors}) =>
      SpreadsheetTheme(
        name: name ?? this.name,
        textFont: textFont ?? this.textFont,
        colors: colors ?? this.colors,
      );

  /// Resolves a color string: `#RRGGBB` (normalized upper case), `theme:<key>`
  /// → the theme color; `auto`/null/invalid → null.
  String? resolveColor(String? color) {
    if (color == null) return null;
    if (color.startsWith('theme:')) {
      return colors[color.substring(6)] ?? standard.colors[color.substring(6)];
    }
    if (_hex.hasMatch(color)) return color.toUpperCase();
    if (color.length == 4 && color.startsWith('#')) {
      final s = color.substring(1);
      final expanded = '#${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
      if (_hex.hasMatch(expanded)) return expanded.toUpperCase();
    }
    return null;
  }

  /// [resolveColor] as opaque ARGB.
  int? resolveArgb(String? color) {
    final hex = resolveColor(color);
    if (hex == null) return null;
    return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
  }

  /// Accent colors 1–6.
  List<String> get accents => [for (var i = 1; i <= 6; i++) colors['accent$i'] ?? '#000000'];

  @override
  bool operator ==(Object other) =>
      other is SpreadsheetTheme &&
      other.name == name &&
      other.textFont == textFont &&
      _mapEq(other.colors, colors);

  static bool _mapEq(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    name,
    textFont,
    Object.hashAllUnordered(colors.entries.map((e) => '${e.key}=${e.value}')),
  );
}

/// Color helpers.
abstract final class ColorUtil {
  /// `#RRGGBB` → (r, g, b).
  static (int, int, int) rgb(String hex) {
    final v = int.parse(hex.substring(1), radix: 16);
    return ((v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff);
  }

  /// (r, g, b) → `#RRGGBB`.
  static String hex(int r, int g, int b) => '#${_h(r)}${_h(g)}${_h(b)}';

  static String _h(int c) => c.clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();

  /// Component-wise sRGB linear interpolation (06 §15.5).
  static String lerp(String a, String b, double t) {
    final (ar, ag, ab) = rgb(a);
    final (br, bg, bb) = rgb(b);
    final tt = t.clamp(0.0, 1.0);
    return hex(
      (ar + (br - ar) * tt).round(),
      (ag + (bg - ag) * tt).round(),
      (ab + (bb - ab) * tt).round(),
    );
  }

  /// Mixes [hex] towards white by [amount] (0..1).
  static String lighten(String hexColor, double amount) => lerp(hexColor, '#FFFFFF', amount);

  /// Mixes [hex] towards black by [amount] (0..1).
  static String darken(String hexColor, double amount) => lerp(hexColor, '#000000', amount);

  /// WCAG relative luminance.
  static double luminance(String hexColor) {
    final (r, g, b) = rgb(hexColor);
    double ch(int c) {
      final s = c / 255;
      return s <= 0.03928 ? s / 12.92 : _pow((s + 0.055) / 1.055, 2.4);
    }

    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b);
  }

  /// WCAG contrast ratio.
  static double contrast(String a, String b) {
    final la = luminance(a);
    final lb = luminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  static double _pow(double x, double y) => math.pow(x, y).toDouble();
}
