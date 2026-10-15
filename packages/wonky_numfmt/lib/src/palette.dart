/// Colors of number-format sections (06 §5.5): the eight named colors and the
/// Excel default 56-color palette used by `[Color1]`…`[Color56]`.
abstract final class NumberFormatPalette {
  /// Named colors (lower-case name → opaque ARGB).
  static const Map<String, int> named = {
    'black': 0xFF000000,
    'blue': 0xFF0000FF,
    'cyan': 0xFF00FFFF,
    'green': 0xFF00FF00,
    'magenta': 0xFFFF00FF,
    'red': 0xFFFF0000,
    'white': 0xFFFFFFFF,
    'yellow': 0xFFFFFF00,
  };

  /// Excel default palette; index 0 is `[Color1]`.
  static const List<int> indexed = [
    0xFF000000,
    0xFFFFFFFF,
    0xFFFF0000,
    0xFF00FF00,
    0xFF0000FF,
    0xFFFFFF00,
    0xFFFF00FF, //
    0xFF00FFFF,
    0xFF800000,
    0xFF008000,
    0xFF000080,
    0xFF808000,
    0xFF800080,
    0xFF008080, //
    0xFFC0C0C0,
    0xFF808080,
    0xFF9999FF,
    0xFF993366,
    0xFFFFFFCC,
    0xFFCCFFFF,
    0xFF660066, //
    0xFFFF8080,
    0xFF0066CC,
    0xFFCCCCFF,
    0xFF000080,
    0xFFFF00FF,
    0xFFFFFF00,
    0xFF00FFFF, //
    0xFF800080,
    0xFF800000,
    0xFF008080,
    0xFF0000FF,
    0xFF00CCFF,
    0xFFCCFFFF,
    0xFFCCFFCC, //
    0xFFFFFF99,
    0xFF99CCFF,
    0xFFFF99CC,
    0xFFCC99FF,
    0xFFFFCC99,
    0xFF3366FF,
    0xFF33CCCC, //
    0xFF99CC00,
    0xFFFFCC00,
    0xFFFF9900,
    0xFFFF6600,
    0xFF666699,
    0xFF969696,
    0xFF003366, //
    0xFF339966,
    0xFF003300,
    0xFF333300,
    0xFF993300,
    0xFF993366,
    0xFF333399,
    0xFF333333, //
  ];

  /// ARGB of `[ColorN]` (1-based), or null when out of range.
  static int? colorAt(int n) =>
      n >= 1 && n <= indexed.length ? indexed[n - 1] : null;

  /// ARGB of a bracket color name (`Red`, `color10`; case-insensitive), or null.
  static int? lookup(String name) {
    final lower = name.toLowerCase();
    final named = NumberFormatPalette.named[lower];
    if (named != null) return named;
    if (lower.startsWith('color')) {
      final n = int.tryParse(lower.substring(5));
      if (n != null && lower.length <= 7) return colorAt(n);
    }
    return null;
  }
}
