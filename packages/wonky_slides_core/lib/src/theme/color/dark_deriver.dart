/// *Derive dark colors* of the theme editor (Slides 05 §2.2, §8.4): the
/// Write 06 §4 OKLCH algorithm on the 11 Slides scheme keys, run once to
/// write explicit dark values.
library;

import 'dart:math' as math;

import '../model/theme_colors.dart';
import 'color_ref.dart';
import '../resolve/contrast.dart';
import 'oklch.dart';

/// The role of a scheme key in the derivation.
enum ThemeColorRole {
  /// `bg1`, `bg2`: very light → dark surfaces.
  surface,

  /// `text1`, `text2`: dark → light foregrounds.
  foreground,

  /// `accent1`–`accent6`, `link`, custom colors: kept vivid, lifted.
  accent,
}

/// Derives a dark scheme from a light one (05 §2.2 *Derive dark colors*).
///
/// 1. Each color is converted to OKLCH (alpha kept).
/// 2. Surfaces: `L' = 0.16 + (1 − L) × 0.14`, chroma × 0.6; `bg2` is kept
///    at least 0.04 lighter than `bg1` so cards stay visible.
/// 3. Foregrounds: `L' = clamp(1 − L × 0.85, 0.55, 0.96)`, chroma × 0.8.
/// 4. Accents and links: `L' = max(L, 0.72)`, chroma × 0.85.
/// 5. Contrast repair against `bg1` (the 05 §11 pairs: text1 ≥ 7,
///    text2 ≥ 4.5, accent1 ≥ 3, link ≥ 4.5): the foreground's lightness
///    rises in 0.02 steps until it passes or `L = 0.98`.
final class ThemeDarkDeriver {
  /// Creates a deriver.
  const ThemeDarkDeriver();

  /// The role of scheme key [key].
  static ThemeColorRole roleOf(String key) => switch (key) {
    'bg1' || 'bg2' => ThemeColorRole.surface,
    'text1' || 'text2' => ThemeColorRole.foreground,
    _ => ThemeColorRole.accent,
  };

  /// Transforms one light color of [role] (alpha kept).
  int transform(int argb, ThemeColorRole role) {
    final c = Oklch.fromArgb(argb);
    final out = switch (role) {
      ThemeColorRole.surface => c.copyWith(
        l: 0.16 + (1 - c.l) * 0.14,
        c: c.c * 0.6,
      ),
      ThemeColorRole.foreground => c.copyWith(
        l: (1 - c.l * 0.85).clamp(0.55, 0.96),
        c: c.c * 0.8,
      ),
      ThemeColorRole.accent => c.copyWith(
        l: math.max(c.l, 0.72),
        c: c.c * 0.85,
      ),
    };
    return (out.toArgb() & 0xffffff) | (argb & 0xff000000);
  }

  /// The dark scheme derived from [light].
  ThemeColorScheme derive(ThemeColorScheme light) {
    final out = <String, int>{
      for (final k in themeColorKeys) k: transform(light[k]!, roleOf(k)),
    };
    // Keep the alternate surface distinguishable from the background.
    final bg1 = Oklch.fromArgb(out['bg1']!);
    final bg2 = Oklch.fromArgb(out['bg2']!);
    if (bg2.l < bg1.l + 0.04) {
      out['bg2'] =
          (bg2.copyWith(l: math.min(1, bg1.l + 0.04)).toArgb() & 0xffffff) |
          (out['bg2']! & 0xff000000);
    }
    final base = compositeOver(out['bg1']!, 0xff000000);
    for (final p in ThemeContrast.requiredPairs) {
      if (p.background != 'bg1') continue;
      out[p.foreground] = raiseUntilContrast(
        out[p.foreground]!,
        base,
        p.required,
      );
    }
    return ThemeColorScheme(out);
  }

  /// A dark value for a custom color (accent rule, repaired to 3:1 on the
  /// dark [bg1]).
  int deriveCustom(int light, int bg1) => raiseUntilContrast(
    transform(light, ThemeColorRole.accent),
    compositeOver(bg1, 0xff000000),
    3,
  );

  /// [colors] with the dark scheme (and the custom colors' dark values)
  /// derived from the light ones.
  ThemeColors deriveColors(ThemeColors colors) {
    final dark = derive(colors.light);
    return ThemeColors(
      light: colors.light,
      dark: dark,
      custom: [
        for (final c in colors.custom)
          ThemeCustomColor(
            name: c.name,
            light: c.light,
            dark: deriveCustom(c.light, dark.bg1),
          ),
      ],
    );
  }

  /// Raises the OKLCH lightness of [foreground] in steps of 0.02 until its
  /// contrast against the opaque [background] reaches [ratio] or
  /// `L = 0.98`.
  static int raiseUntilContrast(int foreground, int background, double ratio) {
    var fg = foreground;
    var c = Oklch.fromArgb(fg);
    while (contrastRatio(compositeOver(fg, background), background) < ratio &&
        c.l < 0.98) {
      c = c.copyWith(l: math.min(0.98, c.l + 0.02));
      fg = (c.toArgb() & 0xffffff) | (foreground & 0xff000000);
    }
    return fg;
  }
}
