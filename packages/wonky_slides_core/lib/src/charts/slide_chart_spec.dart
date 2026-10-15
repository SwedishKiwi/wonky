import 'package:wonky_charts/wonky_charts.dart';

import '../theme/model/common.dart';
import '../theme/resolve/resolved_theme.dart';
import 'chart_element_data.dart';
import 'chart_overrides.dart';

/// What a chart element renders with (Slides 08 §3.5): the effective [spec], the [theme]
/// (colors and fonts) and the [locale] of number formats, plus [warnings] for the inspector.
final class SlideChartLook {
  /// Creates a look.
  const SlideChartLook({
    required this.spec,
    required this.theme,
    required this.locale,
    this.warnings = const [],
  });

  final ChartSpec spec;
  final ChartTheme theme;
  final String locale;

  /// English inspector messages (invalid overrides dropped, …).
  final List<String> warnings;
}

/// Computes the rendered spec of a chart element (Slides 08 §3.5,
/// `SlideChartSpec.effective(sourceSpec, dataJson, deckTheme)`).
abstract final class SlideChartSpec {
  /// Message when overrides fail validation.
  static const invalidOverrides =
      'Some style overrides are invalid and were ignored.';

  /// The look of a chart showing [snapshot] with the deck-side settings of [element] on a
  /// slide of [deckTheme]; [slideBackground] is the effective slide color behind the chart
  /// (ARGB; null = the theme's `bg1`).
  ///
  /// 1. Start from the source spec.
  /// 2. `style.useDeckTheme`: deck chart palette (+ 60 %/40 % tints), body font (title:
  ///    heading font), transparent background, deck floor color; explicit series/slice colors
  ///    and fonts of the sheet are dropped. Otherwise the sheet's palette/fonts
  ///    (`sourceTheme`) on its own background (white by default).
  /// 3. Automatic text and line colors resolve against the color behind the chart (the slide
  ///    background when the chart is transparent), so charts stay readable on dark slides.
  /// 4. `style.palette`/`style.font`, then the allowlisted `overrides`, then `camera`.
  /// 5. Validation: invalid overrides are dropped with [invalidOverrides].
  static SlideChartLook effective({
    required ChartSourceSnapshot snapshot,
    required ChartElementData element,
    required ResolvedTheme deckTheme,
    int? slideBackground,
  }) {
    final warnings = <String>[];
    final deck = element.style.useDeckTheme;
    final chartStyle = deckTheme.chartStyle;
    final bodyFamily = deckTheme.font(chartStyle.font).family;
    final headingFamily = deckTheme.font(const FontRef('@heading')).family;
    final deckSource = deckThemeSource(deckTheme);
    final ChartThemeSource source = deck
        ? deckSource
        : (snapshot.dataSnapshot.sourceTheme ?? deckSource);

    // 1–2.
    var json = snapshot.spec.toJson();
    if (deck) {
      json = _deckStyled(
        json,
        bodyFamily: bodyFamily,
        headingFamily: headingFamily,
        floor: _hex(deckTheme.color(chartStyle.floor)),
      );
    }
    // 4.
    final base = <String, Object?>{
      if (element.style.palette != null || element.style.font != null)
        'style': {
          'palette': ?element.style.palette,
          if (element.style.font != null)
            'fontFamily': deckTheme.font(FontRef(element.style.font!)).family,
        },
    };
    final overrides = ChartOverrides.filter(element.overrides);
    final camera = element.camera;
    final cameraPatch = camera == null
        ? const <String, Object?>{}
        : {
            'threeD': {
              'azimuth': camera.normalizedAzimuth,
              'elevation': camera.normalized.elevation,
              'perspective': camera.normalized.perspective,
            },
          };
    var merged = ChartOverrides.mergePatch(
      ChartOverrides.mergePatch(
        ChartOverrides.mergePatch(json, base),
        overrides,
      ),
      cameraPatch,
    );
    // 5.
    if (overrides.isNotEmpty && ChartSpecSchema.validate(merged).isNotEmpty) {
      final without = ChartOverrides.mergePatch(
        ChartOverrides.mergePatch(json, base),
        cameraPatch,
      );
      // Keep the overrides that are valid one by one.
      var acc = without;
      for (final e in overrides.entries) {
        final next = ChartOverrides.mergePatch(acc, {e.key: e.value});
        if (ChartSpecSchema.validate(next).isEmpty) acc = next;
      }
      merged = acc;
      warnings.add(invalidOverrides);
    }
    var spec = ChartSpec.fromJson(merged);

    // 3. Background and the color behind the chart.
    final slideBg = slideBackground ?? deckTheme.colorOf('bg1') ?? 0xFFFFFFFF;
    final themeForColors = ChartThemeColors(
      accentArgbs: source.accentArgbs,
      textFont: source.textFont,
    );
    int resolve(String? c) =>
        _parseHex(c) ??
        source.resolveArgb(c) ??
        themeForColors.resolveArgb(c) ??
        0;
    final int chartBg;
    final bg = element.background;
    if (bg != null) {
      chartBg = switch (bg) {
        'transparent' => 0,
        'theme' => _opaqueOr(
          deckTheme.color(chartStyle.background, fallback: 0),
          deckTheme.colorOf('bg1') ?? 0xFFFFFFFF,
        ),
        _ => _parseHex(bg) ?? 0,
      };
    } else if (spec.style.background != null) {
      chartBg = resolve(spec.style.background);
    } else {
      chartBg = deck ? 0 : 0xFFFFFFFF;
    }
    if (spec.style.background != null) {
      spec = spec.copyWith(style: _withoutBackground(spec.style));
    }
    final surface = Argb.alpha(chartBg) == 255
        ? chartBg
        : (Argb.alpha(chartBg) == 0
              ? _opaque(slideBg)
              : Argb.lerp(
                  _opaque(slideBg),
                  chartBg | 0xFF000000,
                  Argb.opacity(chartBg),
                ));
    final dark = _isDark(surface);

    final ChartTheme theme;
    if (deck) {
      final text = ChartTheme.ensureContrast(
        deckTheme.color(chartStyle.textColor),
        surface,
        min: 4.5,
      );
      final accents = deckTheme.chartPalette;
      final palette = [
        for (final c in [
          ...accents,
          for (final a in accents) Argb.lerp(a, 0xFFFFFFFF, 0.4),
          for (final a in accents) Argb.lerp(a, 0xFFFFFFFF, 0.6),
        ])
          ChartTheme.ensureContrast(c | 0xFF000000, surface),
      ];
      final grid = deckTheme.color(chartStyle.gridlines);
      theme = ChartTheme(
        background: chartBg,
        text: text,
        mutedText: Argb.lerp(text, surface, 0.3),
        axisLine: deckTheme.color(chartStyle.axis),
        gridline: grid,
        minorGridline: Argb.withOpacity(grid, Argb.opacity(grid) / 2),
        palette: palette.isEmpty
            ? ChartTheme.paletteOf(source, background: surface)
            : palette,
        source: source,
        fontFamily: bodyFamily,
        isDark: dark,
        positive: dark ? 0xFF81C995 : 0xFF188038,
        negative: dark ? 0xFFF28B82 : 0xFFD93025,
      );
    } else {
      final t = ChartTheme.from(
        source,
        dark: dark,
        tokens: ChartUiTokens(
          card: surface,
          foreground: dark ? 0xFFFAFAFA : 0xFF202124,
          border: dark ? 0xFF5F6368 : 0xFFDADCE0,
        ),
      );
      theme = ChartTheme(
        background: chartBg,
        text: t.text,
        mutedText: t.mutedText,
        axisLine: t.axisLine,
        gridline: t.gridline,
        minorGridline: t.minorGridline,
        palette: t.palette,
        source: source,
        fontFamily: source.textFont,
        isDark: dark,
        positive: t.positive,
        negative: t.negative,
      );
    }
    return SlideChartLook(
      spec: spec,
      theme: theme,
      locale: snapshot.dataSnapshot.locale,
      warnings: warnings,
    );
  }

  /// The deck theme as a chart theme source: accents 1–6, the chart font, and every scheme
  /// color for `theme:<key>`.
  static ChartThemeColors deckThemeSource(ResolvedTheme t) => ChartThemeColors(
    accentArgbs: [
      for (var i = 1; i <= 6; i++)
        (t.colorOf('accent$i') ?? 0xFF4285F4) | 0xFF000000,
    ],
    textFont: t.font(t.chartStyle.font).family,
    colors: {for (final e in t.scheme.entries) e.key: e.value | 0xFF000000},
  );

  static Map<String, Object?> _deckStyled(
    Map<String, Object?> json, {
    required String bodyFamily,
    required String headingFamily,
    required String floor,
  }) {
    Object? strip(Object? v, List<String> path) {
      if (v is Map) {
        final out = <String, Object?>{};
        for (final e in v.entries) {
          final k = '${e.key}';
          final p = [...path, k];
          // Fonts: the deck's families.
          if (k == 'family' && path.isNotEmpty && path.last == 'font') continue;
          if (k == 'fontFamily' && path.length == 1 && path[0] == 'style') {
            continue;
          }
          // Colors: palette positions instead of the sheet's explicit colors.
          if (path.length == 1 &&
              path[0] == 'style' &&
              (k == 'palette' || k == 'background')) {
            continue;
          }
          if (path.length == 2 && path[0] == 'series' && k == 'color') continue;
          if (path.length == 4 &&
              path[0] == 'series' &&
              path[2] == 'points' &&
              k == 'color') {
            continue;
          }
          if (path.length == 3 &&
              path[0] == 'typeOptions' &&
              path[1] == 'slices' &&
              k == 'color') {
            continue;
          }
          out[k] = strip(e.value, p);
        }
        return out;
      }
      if (v is List) return [for (final x in v) strip(x, path)];
      return v;
    }

    final out = (strip(json, const []) as Map).cast<String, Object?>();
    return ChartOverrides.mergePatch(out, {
      'style': {'fontFamily': bodyFamily},
      'title': {
        'font': {'family': headingFamily},
      },
      if (out['threeD'] is Map) 'threeD': {'floorColor': floor},
    });
  }

  static ChartStyle _withoutBackground(ChartStyle s) {
    final json = s.toJson()..remove('background');
    return ChartStyle.fromJson(json);
  }

  static int _opaque(int c) => c | 0xFF000000;

  static int _opaqueOr(int c, int fallback) =>
      Argb.alpha(c) == 0 ? fallback : _opaque(c);

  static bool _isDark(int c) =>
      ChartTheme.contrast(c, 0xFFFFFFFF) > ChartTheme.contrast(c, 0xFF000000);

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static int? _parseHex(String? c) {
    if (c == null || !c.startsWith('#')) return null;
    var h = c.substring(1);
    if (h.length == 3) h = h.split('').map((x) => '$x$x').join();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    return int.tryParse(h, radix: 16);
  }
}
