/// The document theme a chart takes its palette, font and `theme:<key>` colors from
/// (Slides 08 §2.6): the spreadsheet theme in Wonky Sheets, the deck theme in Wonky Slides.
abstract interface class ChartThemeSource {
  /// Accent colors 1–6 as opaque ARGB; the series palette is derived from them.
  List<int> get accentArgbs;

  /// Default chart font family.
  String get textFont;

  /// Resolves a color string of the chart spec (`#RRGGBB`, `#RGB`, `theme:<key>`) to opaque
  /// ARGB; `auto`, null and unknown values give null.
  int? resolveArgb(String? color);
}

/// A [ChartThemeSource] from plain values: [accentArgbs] plus named [colors] for
/// `theme:<key>` references (`accent1`…`accent6` resolve to the accents).
final class ChartThemeColors implements ChartThemeSource {
  /// Creates a source.
  const ChartThemeColors({
    required this.accentArgbs,
    this.textFont = 'Arial',
    this.colors = const {},
  });

  @override
  final List<int> accentArgbs;

  @override
  final String textFont;

  /// Named theme colors (opaque ARGB) for `theme:<key>`.
  final Map<String, int> colors;

  static final RegExp _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  @override
  int? resolveArgb(String? color) {
    if (color == null) return null;
    if (color.startsWith('theme:')) {
      final key = color.substring(6);
      final named = colors[key];
      if (named != null) return named;
      final m = RegExp(r'^accent([1-6])$').firstMatch(key);
      if (m == null) return null;
      final i = int.parse(m.group(1)!) - 1;
      return i < accentArgbs.length ? accentArgbs[i] : null;
    }
    var hex = color;
    if (hex.length == 4 && hex.startsWith('#')) {
      hex = '#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}';
    }
    if (!_hex.hasMatch(hex)) return null;
    return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
  }
}
