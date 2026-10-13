import 'dart:math' as math;

import '../../format/theme.dart';
import '../scene/scene.dart';

/// App design tokens the editor theme follows (08 §6.4): `card`, `foreground`, `border`.
final class ChartUiTokens {
  /// Creates tokens (ARGB).
  const ChartUiTokens({
    required this.card,
    required this.foreground,
    required this.border,
  });

  /// Light defaults (wonky_ui light palette).
  static const light = ChartUiTokens(
    card: 0xFFFFFFFF,
    foreground: 0xFF0A0A0A,
    border: 0xFFE4E4E7,
  );

  /// Dark defaults (wonky_ui dark palette).
  static const dark = ChartUiTokens(
    card: 0xFF18181B,
    foreground: 0xFFFAFAFA,
    border: 0xFF3F3F46,
  );

  final int card;
  final int foreground;
  final int border;
}

/// Resolved chart colors and fonts (08 §6.4). All colors are ARGB ints.
final class ChartTheme {
  /// Creates a theme.
  const ChartTheme({
    required this.background,
    required this.text,
    required this.mutedText,
    required this.axisLine,
    required this.gridline,
    required this.minorGridline,
    required this.palette,
    required this.spreadsheetTheme,
    this.fontFamily,
    this.isDark = false,
    this.isExport = false,
    this.positive = 0xFF188038,
    this.negative = 0xFFD93025,
  });

  /// Derives the theme from the spreadsheet theme (08 §6.4 table): editor light/dark follow
  /// the app tokens; exports use white/`#202124`/`#9AA0A6`/`#E0E0E0` unless [dark].
  factory ChartTheme.from(
    SpreadsheetTheme theme, {
    bool dark = false,
    bool export = false,
    ChartUiTokens? tokens,
  }) {
    if (export && !dark) {
      final palette = paletteOf(theme, background: 0xFFFFFFFF);
      return ChartTheme(
        background: 0xFFFFFFFF,
        text: 0xFF202124,
        mutedText: 0xFF5F6368,
        axisLine: 0xFF9AA0A6,
        gridline: 0xFFE0E0E0,
        minorGridline: 0xFFF1F3F4,
        palette: palette,
        spreadsheetTheme: theme,
        fontFamily: theme.textFont,
        isExport: true,
      );
    }
    final t = tokens ?? (dark ? ChartUiTokens.dark : ChartUiTokens.light);
    final palette = paletteOf(theme, background: t.card);
    return ChartTheme(
      background: t.card,
      text: t.foreground,
      mutedText: Argb.lerp(t.foreground, t.card, 0.35),
      axisLine: t.border,
      gridline: Argb.lerp(t.card, t.border, 0.6),
      minorGridline: Argb.lerp(t.card, t.border, 0.3),
      palette: palette,
      spreadsheetTheme: theme,
      fontFamily: theme.textFont,
      isDark: dark,
      isExport: export,
      positive: dark ? 0xFF81C995 : 0xFF188038,
      negative: dark ? 0xFFF28B82 : 0xFFD93025,
    );
  }

  /// Minimum contrast of palette colors against the chart background (08 §6.4).
  static const minContrast = 3.0;

  /// Series palette: accents 1–6, then the same six at 60 % and at 40 % strength (tints mixed
  /// with white), 18 colors; series cycle through it by position. With a [background], colors
  /// below [minContrast] against it are darkened (light backgrounds) or lightened (dark ones)
  /// until they reach it.
  static List<int> paletteOf(SpreadsheetTheme theme, {int? background}) {
    final accents = [
      for (final a in theme.accents) theme.resolveArgb(a) ?? 0xFF4285F4,
    ];
    final raw = [
      ...accents,
      for (final a in accents) Argb.lerp(a, 0xFFFFFFFF, 0.4),
      for (final a in accents) Argb.lerp(a, 0xFFFFFFFF, 0.6),
    ];
    if (background == null) return raw;
    return [for (final c in raw) ensureContrast(c, background)];
  }

  /// [color] mixed towards black or white (away from [background]) until its contrast reaches
  /// [min].
  static int ensureContrast(
    int color,
    int background, {
    double min = minContrast,
  }) {
    if (contrast(color, background) >= min) return color;
    final target = _luminance(background) > 0.4 ? 0xFF000000 : 0xFFFFFFFF;
    for (var t = 0.05; t <= 1.0001; t += 0.05) {
      final c = Argb.lerp(color, target, t);
      if (contrast(c, background) >= min) return c;
    }
    return target;
  }

  final int background;
  final int text;

  /// Axis labels and secondary text.
  final int mutedText;
  final int axisLine;
  final int gridline;
  final int minorGridline;

  /// Series palette (18 colors).
  final List<int> palette;
  final SpreadsheetTheme spreadsheetTheme;

  /// Default chart font (spreadsheet theme font).
  final String? fontFamily;
  final bool isDark;
  final bool isExport;

  /// Scorecard/waterfall positive and negative defaults.
  final int positive;
  final int negative;

  /// Palette color of series position [i].
  int seriesColor(int i) => palette[i % palette.length];

  /// Resolves a WonkyColor string (`#RGB`, `#RRGGBB`, `#AARRGGBB`, `theme:<key>`); null or
  /// invalid → [fallback].
  int color(String? c, int fallback) {
    if (c == null || c.isEmpty || c == 'auto') return fallback;
    if (c.length == 9 && c.startsWith('#')) {
      final v = int.tryParse(c.substring(1), radix: 16);
      if (v != null) return v & 0xFFFFFFFF;
    }
    return spreadsheetTheme.resolveArgb(c) ?? fallback;
  }

  /// A readable text color on [fill].
  int onColor(int fill) {
    final l = _luminance(fill);
    return l > 0.45 ? 0xFF202124 : 0xFFFFFFFF;
  }

  static double _luminance(int c) {
    double ch(int v) {
      final s = v / 255;
      return s <= 0.03928
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * ch(Argb.red(c)) +
        0.7152 * ch(Argb.green(c)) +
        0.0722 * ch(Argb.blue(c));
  }

  /// WCAG contrast of two ARGB colors.
  static double contrast(int a, int b) {
    final la = _luminance(a), lb = _luminance(b);
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}
