/// Derives a dark palette from a light palette in OKLCH (06 §4).
library;

import 'dart:math' as math;

import '../model/color_ref.dart';
import '../model/write_theme_data.dart';
import 'oklch.dart';

/// A foreground/background pair checked during contrast repair.
typedef PalettePair = (PaletteKey foreground, PaletteKey background);

/// Resolves palette references of [palette] to ARGB. Keys whose chain ends
/// at an unset key fall back to [fallback] (if given) or are omitted.
/// Transparent entries resolve to `0x00000000`.
Map<PaletteKey, int> resolvePaletteColors(
  ThemePalette palette, {
  Map<PaletteKey, int>? fallback,
}) {
  final out = <PaletteKey, int>{};
  int? resolve(PaletteKey key, Set<PaletteKey> seen) {
    if (out.containsKey(key)) return out[key];
    final ref = palette[key];
    if (ref == null) return fallback?[key];
    switch (ref.kind) {
      case ColorRefKind.rgb:
      case ColorRefKind.transparent:
        return ref.argb;
      case ColorRefKind.palette:
        if (!seen.add(ref.paletteKey!)) return null;
        return resolve(ref.paletteKey!, seen);
    }
  }

  for (final k in PaletteKey.values) {
    final v = resolve(k, {k});
    if (v != null) out[k] = v;
  }
  return out;
}

/// The dark-palette derivation of 06 §4.
///
/// 1. Each literal palette color is converted to OKLCH.
/// 2. Surfaces: `L' = 0.16 + (1 − L) × 0.14`, chroma × 0.6, hue kept;
///    `canvas` is 0.03 darker than `page`.
/// 3. Foregrounds: `L' = clamp(1 − L × 0.85, 0.55, 0.96)`, chroma × 0.8.
/// 4. Accents: `L' = max(L, 0.72)`; `border`/`quoteBar`: `L' = 0.38`;
///    chroma × 0.85.
/// 5. Contrast repair of the [repairPairs]: raise the foreground lightness
///    in steps of 0.02 until the WCAG ratio reaches 4.5 or `L = 0.98`.
///
/// Palette references (`"@accent"`) are kept as references and resolve
/// against the derived dark palette; transparency (alpha) is preserved.
final class DarkPaletteDeriver {
  /// Creates a deriver.
  const DarkPaletteDeriver();

  /// Required contrast during repair.
  static const double requiredRatio = 4.5;

  /// Foreground/background pairs repaired after derivation (06 §10.6).
  static const List<PalettePair> repairPairs = [
    (PaletteKey.text, PaletteKey.page),
    (PaletteKey.heading, PaletteKey.page),
    (PaletteKey.muted, PaletteKey.page),
    (PaletteKey.link, PaletteKey.page),
    (PaletteKey.linkHover, PaletteKey.page),
    (PaletteKey.accent, PaletteKey.page),
    (PaletteKey.codeText, PaletteKey.codeBg),
    (PaletteKey.quoteText, PaletteKey.quoteBg),
    (PaletteKey.quoteText, PaletteKey.page),
    (PaletteKey.mentionText, PaletteKey.mentionBg),
    (PaletteKey.text, PaletteKey.tableStripe),
    (PaletteKey.text, PaletteKey.tableHeaderBg),
    (PaletteKey.heading, PaletteKey.tableHeaderBg),
    (PaletteKey.text, PaletteKey.highlight),
  ];

  /// Transforms one light color of [role] (alpha kept).
  int transform(int argb, PaletteRole role) {
    final c = Oklch.fromArgb(argb);
    final out = switch (role) {
      PaletteRole.surface => c.copyWith(
        l: 0.16 + (1 - c.l) * 0.14,
        c: c.c * 0.6,
      ),
      PaletteRole.foreground => c.copyWith(
        l: (1 - c.l * 0.85).clamp(0.55, 0.96),
        c: c.c * 0.8,
      ),
      PaletteRole.accent => c.copyWith(l: math.max(c.l, 0.72), c: c.c * 0.85),
      PaletteRole.line => c.copyWith(l: 0.38, c: c.c * 0.85),
    };
    return (out.toArgb() & 0xffffff) | (argb & 0xff000000);
  }

  /// Derives the dark palette (ARGB) from the [light] palette. Unset custom
  /// keys stay unset.
  Map<PaletteKey, int> derive(ThemePalette light) {
    final lightColors = resolvePaletteColors(light);
    final dark = <PaletteKey, int>{};
    for (final k in PaletteKey.values) {
      final ref = light[k];
      if (ref == null || ref.kind == ColorRefKind.palette) continue;
      final argb = lightColors[k];
      if (argb == null) continue;
      dark[k] = ref.kind == ColorRefKind.transparent
          ? 0
          : transform(argb, k.role);
    }
    final page = dark[PaletteKey.page];
    final canvasRef = light[PaletteKey.canvas];
    if (page != null &&
        canvasRef != null &&
        canvasRef.kind == ColorRefKind.rgb) {
      final pageL = Oklch.fromArgb(page).l;
      final canvas = Oklch.fromArgb(dark[PaletteKey.canvas]!);
      dark[PaletteKey.canvas] =
          (canvas.copyWith(l: math.max(0, pageL - 0.03)).toArgb() & 0xffffff) |
          (dark[PaletteKey.canvas]! & 0xff000000);
    }
    // References keep pointing at the (now dark) referenced key.
    final withRefs = <PaletteKey, ColorRef>{
      for (final e in dark.entries) e.key: ColorRef.argb(e.value),
      for (final k in PaletteKey.values)
        if (light[k]?.kind == ColorRefKind.palette) k: light[k]!,
    };
    final resolved = resolvePaletteColors(ThemePalette(withRefs));
    return repair(resolved, refs: light);
  }

  /// Contrast repair (step 5) of [palette]; keys that are references in
  /// [refs] are repaired through their referenced key only.
  Map<PaletteKey, int> repair(
    Map<PaletteKey, int> palette, {
    ThemePalette? refs,
  }) {
    final out = Map<PaletteKey, int>.of(palette);
    for (final (fg, bg) in repairPairs) {
      final fgColor = out[fg];
      final bgColor = out[bg];
      final page = out[PaletteKey.page];
      if (fgColor == null || bgColor == null) continue;
      final bgOpaque = compositeOver(bgColor, page ?? 0xff000000);
      if (refs?[fg]?.kind == ColorRefKind.palette) continue;
      out[fg] = raiseUntilContrast(fgColor, bgOpaque, requiredRatio);
    }
    // Re-resolve references after repair.
    if (refs != null) {
      for (final k in PaletteKey.values) {
        var ref = refs[k];
        final seen = <PaletteKey>{k};
        while (ref != null && ref.kind == ColorRefKind.palette) {
          final target = ref.paletteKey!;
          if (!seen.add(target)) break;
          final next = refs[target];
          if (next == null || next.kind != ColorRefKind.palette) {
            if (out[target] != null) out[k] = out[target]!;
            break;
          }
          ref = next;
        }
      }
    }
    return out;
  }

  /// Raises the OKLCH lightness of [foreground] in steps of 0.02 until its
  /// contrast against the opaque [background] reaches [ratio] or `L = 0.98`.
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

  /// Derives a dark syntax color from a light literal (accent rule, then
  /// contrast repair against the dark [codeBg]) (06 §4 step 6).
  int deriveSyntaxColor(int light, int codeBg) => raiseUntilContrast(
    transform(light, PaletteRole.accent),
    codeBg,
    requiredRatio,
  );
}
