/// Contrast checks of theme color schemes (Slides 05 §11.1, theme editor
/// badges 05 §8.4).
library;

import '../color/color_ref.dart';
import '../color/oklch.dart';
import '../model/common.dart';
import '../model/theme_colors.dart';

/// One required pair: [foreground] key on [background] key ≥ [required].
final class ThemeContrastPair {
  /// Creates a pair.
  const ThemeContrastPair(this.foreground, this.background, this.required);

  /// Foreground color key.
  final String foreground;

  /// Background color key.
  final String background;

  /// Minimum WCAG ratio.
  final double required;

  /// `text1/bg1`.
  String get id => '$foreground/$background';
}

/// The result of one checked pair.
final class ThemeContrastResult {
  /// Creates a result.
  const ThemeContrastResult(this.pair, this.appearance, this.ratio);

  /// The pair.
  final ThemeContrastPair pair;

  /// The scheme checked.
  final SlideAppearance appearance;

  /// WCAG ratio 1–21.
  final double ratio;

  /// Whether [ratio] meets [ThemeContrastPair.required].
  bool get passes => ratio + 1e-9 >= pair.required;

  /// MCP / badge form.
  Map<String, Object?> toJson() => {
    'pair': pair.id,
    'appearance': appearance.name,
    'ratio': double.parse(ratio.toStringAsFixed(2)),
    'required': pair.required,
  };

  @override
  String toString() =>
      '${pair.id} (${appearance.name}): ${ratio.toStringAsFixed(2)} / ${pair.required}';
}

/// WCAG checks of theme schemes (05 §11.1).
abstract final class ThemeContrast {
  /// The required pairs: text1/bg1 ≥ 7, text2/bg1 ≥ 4.5, accent1/bg1 ≥ 3,
  /// link/bg1 ≥ 4.5.
  static const List<ThemeContrastPair> requiredPairs = [
    ThemeContrastPair('text1', 'bg1', 7),
    ThemeContrastPair('text2', 'bg1', 4.5),
    ThemeContrastPair('accent1', 'bg1', 3),
    ThemeContrastPair('link', 'bg1', 4.5),
  ];

  /// The contrast of two ARGB colors: [foreground] composited over
  /// [background], which is composited over white (light) or black (dark)
  /// when translucent.
  static double ratio(int foreground, int background, {bool darkBase = false}) {
    final base = darkBase ? 0xff000000 : 0xffffffff;
    final bg = compositeOver(background, base);
    return contrastRatio(compositeOver(foreground, bg), bg);
  }

  /// Checks [pairs] in the [appearance] scheme of [colors].
  static List<ThemeContrastResult> check(
    ThemeColors colors,
    SlideAppearance appearance, {
    List<ThemeContrastPair> pairs = requiredPairs,
  }) {
    final scheme = colors.scheme(appearance);
    return [
      for (final p in pairs)
        ThemeContrastResult(
          p,
          appearance,
          ratio(
            scheme[p.foreground]!,
            scheme[p.background]!,
            darkBase: appearance == SlideAppearance.dark,
          ),
        ),
    ];
  }

  /// The failing results of both schemes.
  static List<ThemeContrastResult> failures(ThemeColors colors) => [
    for (final a in SlideAppearance.values)
      ...check(colors, a).where((r) => !r.passes),
  ];

  /// The contrast of [foreground] on [background] as hex strings (theme
  /// editor previews).
  static double ofHex(String foreground, String background) => ratio(
    ColorRef.parseHexArgb(foreground),
    ColorRef.parseHexArgb(background),
  );
}
