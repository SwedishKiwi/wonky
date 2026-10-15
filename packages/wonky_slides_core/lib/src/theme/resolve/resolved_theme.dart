/// `ResolvedTheme` (Slides 05 §1 P3): a theme with every reference resolved
/// for one appearance — concrete ARGB colors, bundled font faces, text
/// styles with fallbacks, fills, code and chart palettes. Consumed by the
/// canvas, thumbnails, presenting, the PDF renderer and MCP.
library;

import 'package:wonky_code/wonky_code.dart';

import '../color/color_ref.dart';
import '../color/oklch.dart';
import '../fonts/slides_fonts.dart';
import '../json/json_util.dart';
import '../model/background.dart';
import '../model/common.dart';
import '../model/deck_theme_data.dart';
import '../model/object_style_defaults.dart';
import '../model/object_styles.dart';
import '../model/paint.dart';
import '../model/text_styles.dart';

/// A text style with every property concrete.
final class ResolvedTextStyle {
  /// Creates a resolved style.
  const ResolvedTextStyle({
    required this.key,
    required this.font,
    required this.size,
    required this.lineHeight,
    required this.letterSpacing,
    required this.color,
    required this.caps,
    required this.align,
    required this.spaceBefore,
    required this.spaceAfter,
  });

  /// The theme style key.
  final String key;

  /// The bundled face (family, snapped weight, italic).
  final ResolvedFontFace font;

  /// Size (su).
  final double size;

  /// Line height multiplier.
  final double lineHeight;

  /// Letter spacing (em).
  final double letterSpacing;

  /// ARGB color.
  final int color;

  /// `all`, `small`, `title` or `null`.
  final String? caps;

  /// Paragraph alignment.
  final String align;

  /// Space before paragraphs (su).
  final double spaceBefore;

  /// Space after paragraphs (su).
  final double spaceAfter;

  @override
  String toString() =>
      'ResolvedTextStyle($key: ${font.family} ${font.weight} $size su, '
      '${ColorRef.formatHex(color)})';
}

/// A fill with concrete colors.
sealed class ResolvedFill {
  const ResolvedFill();

  /// A color standing for the fill (luminance checks, auto code palettes);
  /// `null` for no fill and images.
  int? get representativeColor;
}

/// Nothing drawn.
final class ResolvedNoFill extends ResolvedFill {
  /// The empty fill.
  const ResolvedNoFill();

  @override
  int? get representativeColor => null;
}

/// A solid color.
final class ResolvedSolidFill extends ResolvedFill {
  /// Creates a solid fill.
  const ResolvedSolidFill(this.color);

  /// ARGB.
  final int color;

  @override
  int get representativeColor => color;
}

/// A gradient with concrete stops.
final class ResolvedGradientFill extends ResolvedFill {
  /// Creates a gradient.
  const ResolvedGradientFill({
    required this.kind,
    required this.angle,
    required this.stops,
    required this.centerX,
    required this.centerY,
    required this.radius,
  });

  /// `linear` or `radial`.
  final String kind;

  /// Linear direction (degrees).
  final double angle;

  /// `(position, ARGB)` pairs.
  final List<(double, int)> stops;

  /// Radial center (fraction).
  final double centerX;

  /// Radial center (fraction).
  final double centerY;

  /// Radial radius (fraction of the diagonal).
  final double radius;

  /// The average of the stop colors (equal weights).
  @override
  int get representativeColor {
    var a = 0.0, r = 0.0, g = 0.0, b = 0.0;
    for (final (_, c) in stops) {
      a += (c >>> 24) & 0xff;
      r += (c >> 16) & 0xff;
      g += (c >> 8) & 0xff;
      b += c & 0xff;
    }
    final n = stops.length;
    return ((a / n).round() << 24) |
        ((r / n).round() << 16) |
        ((g / n).round() << 8) |
        (b / n).round();
  }
}

/// An uploaded image.
final class ResolvedImageFill extends ResolvedFill {
  /// Creates an image fill.
  const ResolvedImageFill(this.fileUuid, this.fit, this.opacity);

  /// The uploaded file.
  final String fileUuid;

  /// Fit mode.
  final String fit;

  /// Opacity.
  final double opacity;

  @override
  int? get representativeColor => null;
}

/// A background with concrete fills.
final class ResolvedBackground {
  /// Creates a resolved background.
  const ResolvedBackground(this.fill, this.overlay);

  /// The fill for the appearance.
  final ResolvedFill fill;

  /// The overlay (or `null`).
  final ResolvedFill? overlay;

  /// The effective opaque color behind slide content (fill composited over
  /// [base], then the overlay), for luminance decisions; images count as
  /// [base].
  int effectiveColor(int base) {
    var c = 0xff000000 | (base & 0xffffff);
    final f = fill.representativeColor;
    if (f != null) c = compositeOver(f, c);
    final o = overlay?.representativeColor;
    if (o != null) c = compositeOver(o, c);
    return c;
  }
}

/// A theme resolved for one appearance (05 §1 P3).
final class ResolvedTheme {
  /// Creates a resolved theme; use [DeckThemeResolver] instead.
  ResolvedTheme.internal({
    required this.theme,
    required this.appearance,
    required this.contentHash,
    required this.fonts,
    required this.textStyles,
    required this.warnings,
  }) : shapeStyles = theme.shapeStyles ?? defaultShapeStyles,
       tableStyle = theme.tableStyle ?? defaultTableStyle,
       codeStyle = theme.codeStyle ?? defaultCodeStyle,
       chartStyle = theme.chartStyle ?? defaultChartStyle;

  /// The source theme.
  final DeckThemeData theme;

  /// The appearance resolved for.
  final SlideAppearance appearance;

  /// [DeckThemeData.contentHash] of [theme].
  final String contentHash;

  /// The faces of the three font roles (weights as in `fontsJson`).
  final Map<ThemeFontRole, ResolvedFontFace> fonts;

  /// Every theme text style, resolved.
  final Map<String, ResolvedTextStyle> textStyles;

  /// Problems found while resolving (font fallbacks, missing custom colors).
  final List<ThemeIssue> warnings;

  /// Effective default object styles.
  final ThemeShapeStyles shapeStyles;

  /// Effective table style.
  final ThemeTableStyle tableStyle;

  /// Effective code style.
  final ThemeCodeStyle codeStyle;

  /// Effective chart style.
  final ThemeChartStyle chartStyle;

  /// The color scheme in use.
  Map<String, int> get scheme => theme.colors.scheme(appearance).colors;

  /// ARGB of a theme color key (`bg1`…`link`, `customN`), or `null`.
  int? colorOf(String key) => theme.colors.colorOf(key, appearance);

  /// Resolves a [ColorRef]; unknown theme keys give [fallback] (default:
  /// `text1`).
  int color(ColorRef ref, {int? fallback}) =>
      ref.resolve(colorOf) ?? fallback ?? colorOf('text1')!;

  /// Resolves a color string (`null`/invalid → [fallback] or `text1`).
  int colorString(String? value, {int? fallback}) {
    final ref = ColorRef.tryParse(value);
    return ref == null
        ? (fallback ?? colorOf('text1')!)
        : color(ref, fallback: fallback);
  }

  /// The family drawn for [ref] (role refs use the theme fonts).
  ResolvedFontFace font(FontRef ref, {int? weight, bool italic = false}) {
    final role = ref.role;
    if (role != null) {
      final themeFont = theme.fonts.of(role);
      return SlidesFonts.resolve(
        themeFont.family,
        weight: weight ?? themeFont.weight,
        italic: italic,
        defaultCategory: SlidesFonts.categoryOfRole(role),
      );
    }
    return SlidesFonts.resolve(
      ref.value,
      weight: weight ?? 400,
      italic: italic,
    );
  }

  /// The resolved style [key] (unknown keys → `body`).
  ResolvedTextStyle textStyle(String key) =>
      textStyles[key] ?? textStyles['body']!;

  /// List marker styling (05 §2.5).
  ThemeListStyles get lists => theme.textStyles.lists;

  /// Bullet and number color.
  int get bulletColor => color(lists.bulletColor);

  /// Link color.
  int get linkColor => color(theme.textStyles.links.color);

  /// Whether links are underlined.
  bool get linkUnderline => theme.textStyles.links.underline;

  /// Inline code background.
  int get inlineCodeBackground => color(theme.textStyles.inlineCode.background);

  /// Resolves a fill for this appearance.
  ResolvedFill fill(SlideFill fill) => switch (fill) {
    NoFill() => const ResolvedNoFill(),
    SolidFill(:final color) => ResolvedSolidFill(this.color(color)),
    GradientFill() => ResolvedGradientFill(
      kind: fill.kind,
      angle: fill.angle,
      stops: [for (final s in fill.stops) (s.at, color(s.color))],
      centerX: fill.centerX ?? 0.5,
      centerY: fill.centerY ?? 0.5,
      radius: fill.radius ?? 0.5,
    ),
    ImageFill() => ResolvedImageFill(fill.fileUuid, fill.fit, fill.opacity),
  };

  /// Resolves [background] (a theme, master, layout or slide background).
  ResolvedBackground background(SlideBackground background) =>
      ResolvedBackground(
        fill(background.fillFor(appearance)),
        background.overlay == null ? null : fill(background.overlay!),
      );

  /// The theme's own background.
  ResolvedBackground get themeBackground => background(theme.background);

  /// The code palette for light backgrounds.
  SyntaxPalette get codeLight => codeStyle.light;

  /// The code palette for dark backgrounds.
  SyntaxPalette get codeDark => codeStyle.dark;

  /// The palette matching the appearance.
  SyntaxPalette get codePalette =>
      appearance == SlideAppearance.dark ? codeDark : codeLight;

  /// The palette for `palette: "auto"` code elements on an effective
  /// [background] (07 §2.5): dark palette when the background is dark.
  SyntaxPalette codePaletteForBackground(int background) =>
      isDarkColor(background) ? codeDark : codeLight;

  /// The chart series colors.
  List<int> get chartPalette => [for (final c in chartStyle.palette) color(c)];
}

/// Whether [argb] is dark: white text has more contrast on it than black
/// text (WCAG relative luminance below ≈ 0.179).
bool isDarkColor(int argb) =>
    contrastRatio(0xffffffff, argb | 0xff000000) >
    contrastRatio(0xff000000, argb | 0xff000000);
