import 'dart:math' as math;

/// Excel/OOXML color resolution (11 §5.2): indexed palette, theme colors and
/// the tint algorithm.
abstract final class ExcelColors {
  /// The default indexed palette (`indexed="0"`…`63`), `#RRGGBB`.
  static const List<String> indexedPalette = [
    '#000000', '#FFFFFF', '#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF', '#00FFFF', //
    '#000000', '#FFFFFF', '#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF', '#00FFFF', //
    '#800000', '#008000', '#000080', '#808000', '#800080', '#008080', '#C0C0C0', '#808080', //
    '#9999FF', '#993366', '#FFFFCC', '#CCFFFF', '#660066', '#FF8080', '#0066CC', '#CCCCFF', //
    '#000080', '#FF00FF', '#FFFF00', '#00FFFF', '#800080', '#800000', '#008080', '#0000FF', //
    '#00CCFF', '#CCFFFF', '#CCFFCC', '#FFFF99', '#99CCFF', '#FF99CC', '#CC99FF', '#FFCC99', //
    '#3366FF', '#33CCCC', '#99CC00', '#FFCC00', '#FF9900', '#FF6600', '#666699', '#969696', //
    '#003366', '#339966', '#003300', '#333300', '#993300', '#993366', '#333399', '#333333', //
  ];

  /// Theme color names in `clrScheme` document order.
  static const List<String> schemeOrder = [
    'dk1',
    'lt1',
    'dk2',
    'lt2',
    'accent1',
    'accent2',
    'accent3',
    'accent4',
    'accent5',
    'accent6',
    'hlink',
    'folHlink',
  ];

  /// The scheme color addressed by `theme="i"`: indices 0–3 are swapped
  /// pairwise relative to the document order (0 = lt1, 1 = dk1, 2 = lt2,
  /// 3 = dk2).
  static String? themeSlot(int index) => switch (index) {
    0 => 'lt1',
    1 => 'dk1',
    2 => 'lt2',
    3 => 'dk2',
    >= 4 && < 12 => schemeOrder[index],
    _ => null,
  };

  /// The `theme` index for a scheme slot (inverse of [themeSlot]).
  static int? themeIndexOf(String slot) {
    for (var i = 0; i < 12; i++) {
      if (themeSlot(i) == slot) return i;
    }
    return null;
  }

  /// Wonky theme key for a scheme slot (`dk1` → `text`, `lt1` →
  /// `background`, `accentN`, `hlink` → `link`), or null.
  static String? wonkyKeyOf(String slot) => switch (slot) {
    'dk1' => 'text',
    'lt1' => 'background',
    'hlink' => 'link',
    final s when s.startsWith('accent') => s,
    _ => null,
  };

  /// Scheme slot of a Wonky theme key (inverse of [wonkyKeyOf]).
  static String? slotOfWonkyKey(String key) => switch (key) {
    'text' => 'dk1',
    'background' => 'lt1',
    'link' => 'hlink',
    final k when k.startsWith('accent') => k,
    _ => null,
  };

  /// Default Office 2013+ theme colors.
  static const Map<String, String> officeTheme = {
    'dk1': '#000000',
    'lt1': '#FFFFFF',
    'dk2': '#44546A',
    'lt2': '#E7E6E6',
    'accent1': '#4472C4',
    'accent2': '#ED7D31',
    'accent3': '#A5A5A5',
    'accent4': '#FFC000',
    'accent5': '#5B9BD5',
    'accent6': '#70AD47',
    'hlink': '#0563C1',
    'folHlink': '#954F72',
  };

  /// Parses an OOXML `rgb` attribute (`FFRRGGBB` or `RRGGBB`) to `#RRGGBB`.
  static String? parseRgb(String? argb) {
    if (argb == null) return null;
    var s = argb.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 8) s = s.substring(2);
    if (s.length != 6 || int.tryParse(s, radix: 16) == null) return null;
    return '#${s.toUpperCase()}';
  }

  /// `#RRGGBB` → `FFRRGGBB`.
  static String toArgb(String hex) => 'FF${hex.substring(1).toUpperCase()}';

  /// Resolves an indexed color (custom [palette] overrides the default).
  /// 64 (system foreground) → null (automatic), 65 (system background) →
  /// white.
  static String? indexed(int index, {List<String>? palette}) {
    final p = palette ?? indexedPalette;
    if (index >= 0 && index < p.length) return p[index];
    if (index == 65) return '#FFFFFF';
    return null;
  }

  /// Applies an Excel tint (−1…1) to `#RRGGBB` (HLS with HLSMAX = 255, as
  /// Excel does).
  static String applyTint(String hex, double tint) {
    if (tint == 0) return hex.toUpperCase();
    final v = int.parse(hex.substring(1), radix: 16);
    final (h, l, s) = _rgbToHls((v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff);
    double nl;
    if (tint < 0) {
      nl = l * (1 + tint);
    } else {
      nl = l * (1 - tint) + (_hlsMax - _hlsMax * (1 - tint));
    }
    final (r, g, b) = _hlsToRgb(h, nl.clamp(0, _hlsMax).toDouble(), s);
    String c(int x) => x.clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${c(r)}${c(g)}${c(b)}';
  }

  static const double _hlsMax = 255;

  static (double, double, double) _rgbToHls(int r, int g, int b) {
    final rf = r / 255, gf = g / 255, bf = b / 255;
    final mx = math.max(rf, math.max(gf, bf));
    final mn = math.min(rf, math.min(gf, bf));
    final l = (mx + mn) / 2;
    double h = 0, s = 0;
    if (mx != mn) {
      final d = mx - mn;
      s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
      if (mx == rf) {
        h = (gf - bf) / d + (gf < bf ? 6 : 0);
      } else if (mx == gf) {
        h = (bf - rf) / d + 2;
      } else {
        h = (rf - gf) / d + 4;
      }
      h /= 6;
    }
    return (h * _hlsMax, l * _hlsMax, s * _hlsMax);
  }

  static (int, int, int) _hlsToRgb(double h, double l, double s) {
    final hh = h / _hlsMax, ll = l / _hlsMax, ss = s / _hlsMax;
    if (ss == 0) {
      final v = (ll * 255).round();
      return (v, v, v);
    }
    double hue(double p, double q, double t) {
      var tt = t;
      if (tt < 0) tt += 1;
      if (tt > 1) tt -= 1;
      if (tt < 1 / 6) return p + (q - p) * 6 * tt;
      if (tt < 1 / 2) return q;
      if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
      return p;
    }

    final q = ll < 0.5 ? ll * (1 + ss) : ll + ss - ll * ss;
    final p = 2 * ll - q;
    return (
      (hue(p, q, hh + 1 / 3) * 255).round(),
      (hue(p, q, hh) * 255).round(),
      (hue(p, q, hh - 1 / 3) * 255).round(),
    );
  }
}

/// Resolves `<color rgb|theme|indexed|auto tint>` elements of one workbook.
final class ColorResolver {
  /// Creates a resolver for a workbook's theme (scheme slot → `#RRGGBB`) and
  /// optional custom indexed palette. With [themeReferences], untinted theme
  /// colors that map to a Wonky theme key resolve to `theme:<key>`.
  ColorResolver({Map<String, String>? theme, this.palette, this.themeReferences = true})
    : theme = theme ?? ExcelColors.officeTheme;

  /// Scheme slot → `#RRGGBB`.
  final Map<String, String> theme;

  /// Custom indexed palette (`<colors><indexedColors>`).
  final List<String>? palette;

  /// Whether untinted theme colors become `theme:<key>` references.
  final bool themeReferences;

  /// Resolves a color from its attributes. Returns `#RRGGBB`,
  /// `theme:<key>`, or null for automatic/missing colors.
  String? resolve({String? rgb, String? theme, String? indexed, String? auto, String? tint}) {
    if (auto == '1' || auto == 'true') return null;
    final t = double.tryParse(tint ?? '') ?? 0;
    String? base;
    if (rgb != null) {
      base = ExcelColors.parseRgb(rgb);
    } else if (theme != null) {
      final slot = ExcelColors.themeSlot(int.tryParse(theme) ?? -1);
      if (slot == null) return null;
      if (t == 0 && themeReferences) {
        final key = ExcelColors.wonkyKeyOf(slot);
        if (key != null) return 'theme:$key';
      }
      base = this.theme[slot] ?? ExcelColors.officeTheme[slot];
    } else if (indexed != null) {
      base = ExcelColors.indexed(int.tryParse(indexed) ?? -1, palette: palette);
    }
    if (base == null) return null;
    return t == 0 ? base : ExcelColors.applyTint(base, t);
  }
}
