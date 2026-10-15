import 'dart:math' as math;
import 'dart:typed_data';

import '../data/chart_data.dart';
import '../data/data_algorithms.dart';
import '../data/value_formatter.dart';
import '../scene/geometry.dart';
import '../scene/path.dart';
import '../scene/scene.dart';
import '../spec/chart_spec.dart';
import '../spec/chart_spec_parts.dart';
import '../spec/chart_type.dart';
import '../spec/error_bars.dart';
import '../spec/series_style.dart';
import '../spec/three_d_options.dart';
import '../spec/type_options.dart';
import '../stats/regression.dart';
import '../three_d/chart3d_model.dart';
import '../three_d/chart3d_scene.dart';
import '../three_d/chart3d_view.dart';
import '../three_d/vec3.dart';
import 'chart_theme.dart';
import 'scales.dart';
import 'text_measurer.dart';

part 'layout_3d.dart';
part 'layout_cartesian.dart';
part 'layout_pie.dart';
part 'layout_radial.dart';
part 'layout_tabular.dart';

/// Interaction-dependent layout options (editor only).
final class ChartLayoutOptions {
  /// Creates options.
  const ChartLayoutOptions({
    this.highlightSeriesKey,
    this.tablePage = 0,
    this.distinguishByPattern = false,
    this.azimuth3D,
    this.elevation3D,
    this.transitionFrom3D,
    this.transition3D = 1,
    this.hover3D,
    this.perspective3D,
    this.transform3D,
    this.fitViews3D,
  });

  /// 3D field of view in degrees while a camera animates (null = the spec's; Slides 08
  /// §10.3).
  final double? perspective3D;

  /// Applied to the laid-out 3D model before it is fitted and meshed (chart builds:
  /// `ChartReveal.applyTo3D`, Slides 08 §9.1).
  final Chart3DModel Function(Chart3DModel model)? transform3D;

  /// Views the 3D camera fit must also hold (Slides 08 §10.3): the scale is the smallest of
  /// the current view's and these views' fits, so a camera animation between them doesn't
  /// zoom in and out. Null = fit the current view only.
  final List<Chart3DView>? fitViews3D;

  /// The 3D data item under the pointer (lighter in both backends).
  final SceneTag? hover3D;

  /// Series highlighted from the legend (others dim to 30 %, 08 §6.5).
  final String? highlightSeriesKey;

  /// Page of a paged table chart (0-based).
  final int tablePage;

  /// Accessibility: series also differ by dash pattern / point shape (08 §14).
  final bool distinguishByPattern;

  /// 3D view angles while the user orbits the chart (degrees; null = the spec's).
  final double? azimuth3D;
  final double? elevation3D;

  /// 3D model the chart animates from (data changes, 08 §23.6), at [transition3D] (0..1).
  final Chart3DModel? transitionFrom3D;
  final double transition3D;
}

/// Result of [ChartLayoutEngine.layoutDetailed].
final class ChartLayout {
  /// Creates a layout result.
  const ChartLayout(this.scene, this.warnings);

  final ChartScene scene;

  /// Layout warnings (log values skipped, too many categories, trendline points ignored, …).
  final List<ChartWarning> warnings;
}

/// Lays out a chart into a renderer-independent [ChartScene] (08 §6.2). Pure and
/// deterministic: the same inputs give the same scene (scene goldens rely on it).
abstract final class ChartLayoutEngine {
  /// Lays out [spec] with [data] (from `ChartDataResolver`) at [size] logical px. Colors come
  /// from [theme] (automatic colors, palette), text sizes from [measurer], axis and data
  /// labels are formatted with [fmt] (the spreadsheet locale's number formats).
  ///
  /// Specs from a newer app version, unimplemented (P2) types, missing data and data that
  /// doesn't fit the type give a scene with an explanatory `SceneRole.emptyState` text.
  static ChartScene layout(
    ChartSpec spec,
    ChartData data,
    ChartSize size,
    ChartTheme theme,
    TextMeasurer measurer, {
    ChartValueFormatter fmt = const DefaultChartValueFormatter(),
    ChartLayoutOptions options = const ChartLayoutOptions(),
  }) => layoutDetailed(
    spec,
    data,
    size,
    theme,
    measurer,
    fmt: fmt,
    options: options,
  ).scene;

  /// [layout] plus warnings.
  static ChartLayout layoutDetailed(
    ChartSpec spec,
    ChartData data,
    ChartSize size,
    ChartTheme theme,
    TextMeasurer measurer, {
    ChartValueFormatter fmt = const DefaultChartValueFormatter(),
    ChartLayoutOptions options = const ChartLayoutOptions(),
  }) {
    final ctx = _Ctx(spec, data, size, theme, measurer, fmt, options);
    ctx.run();
    return ChartLayout(
      ChartScene(
        width: size.width,
        height: size.height,
        background: ctx.background,
        primitives: List.unmodifiable(ctx.out),
        plotArea: ctx.plotArea,
        threeD: ctx.threeD,
      ),
      List.unmodifiable(ctx.warnings),
    );
  }
}

/// How a series is drawn.
enum _Mark { column, line, area, scatter }

/// A resolved series for drawing.
final class _SeriesInfo {
  _SeriesInfo(
    this.position,
    this.series,
    this.style,
    this.color,
    this.mark,
    this.rightAxis,
  );

  /// Position in `data.series` (palette index).
  final int position;
  final ChartSeries series;
  final SeriesStyle style;
  final int color;
  final _Mark mark;
  final bool rightAxis;

  String get key => series.key;
}

/// A legend entry.
final class _LegendEntry {
  _LegendEntry(
    this.label,
    this.color,
    this.kind, {
    this.seriesKey,
    this.dash,
    this.shape,
  });

  final String label;
  final int color;

  /// 'box', 'line', 'marker', 'lineMarker'.
  final String kind;
  final String? seriesKey;
  final List<double>? dash;
  final MarkerShape? shape;
}

final class _Ctx {
  _Ctx(
    this.spec,
    this.data,
    this.size,
    this.theme,
    this.measurer,
    this.fmt,
    this.options,
  );

  final ChartSpec spec;
  final ChartData data;
  final ChartSize size;
  final ChartTheme theme;
  final TextMeasurer measurer;
  final ChartValueFormatter fmt;
  final ChartLayoutOptions options;

  final List<ScenePrimitive> out = [];
  final List<ChartWarning> warnings = [];
  ChartRect? plotArea;
  Chart3DScene? threeD;
  late final int background = spec.style.background == null
      ? theme.background
      : theme.color(spec.style.background, theme.background);

  bool get maximize => spec.style.maximize;
  double get pad => maximize ? 6 : 16;
  String? get family => spec.style.fontFamily ?? theme.fontFamily;

  // ---------------------------------------------------------------------------
  // Text helpers.

  TextStyleSpec font(
    ChartFont f, {
    double size = 12,
    bool bold = false,
    int? color,
  }) => TextStyleSpec(
    family: f.family ?? family,
    size: f.size ?? size,
    bold: f.bold || bold,
    italic: f.italic,
    color: theme.color(f.color, color ?? theme.text),
  );

  TextMetrics measure(String text, TextStyleSpec style) =>
      measurer.measure(text, style);

  SText text(
    String s,
    double x,
    double y,
    TextStyleSpec style, {
    TextAnchor anchor = TextAnchor.baselineLeft,
    double angle = 0,
    SceneTag? tag,
  }) {
    final m = measurer.measure(s, style);
    return SText(
      s,
      ChartPoint(x, y),
      style,
      anchor: anchor,
      angle: angle,
      width: m.width,
      height: m.height,
      ascent: m.ascent,
      tag: tag,
    );
  }

  String formatValue(double v, String? pattern) {
    if (v.isNaN) return '';
    return fmt.format(v, pattern);
  }

  // ---------------------------------------------------------------------------
  // Series.

  late final List<_SeriesInfo> seriesInfos = _buildSeriesInfos();

  List<_SeriesInfo> _buildSeriesInfos() {
    final out = <_SeriesInfo>[];
    for (var i = 0; i < data.series.length; i++) {
      final s = data.series[i];
      final st = spec.seriesStyle(s.key);
      final mark = switch (spec.type) {
        ChartType.column ||
        ChartType.bar ||
        ChartType.histogram => _Mark.column,
        ChartType.line || ChartType.radar => _Mark.line,
        ChartType.area => _Mark.area,
        ChartType.scatter || ChartType.bubble => _Mark.scatter,
        ChartType.combo => switch (st.type) {
          SeriesChartType.column => _Mark.column,
          SeriesChartType.line => _Mark.line,
          SeriesChartType.area => _Mark.area,
          null => i == 0 ? _Mark.column : _Mark.line,
        },
        _ => _Mark.column,
      };
      final right =
          st.axis == SeriesAxis.right &&
          (spec.type == ChartType.combo ||
              spec.type == ChartType.line ||
              spec.type == ChartType.column ||
              spec.type == ChartType.area ||
              spec.type == ChartType.scatter);
      out.add(_SeriesInfo(i, s, st, seriesColor(i, st), mark, right));
    }
    return out;
  }

  int seriesColor(int i, SeriesStyle st) {
    final pal = spec.style.palette;
    final base = pal != null && pal.isNotEmpty
        ? theme.color(pal[i % pal.length], theme.seriesColor(i))
        : theme.seriesColor(i);
    return theme.color(st.color, base);
  }

  /// Dash used for series [i] (explicit dash, or a pattern for accessibility).
  List<double>? seriesDash(_SeriesInfo s, double width) {
    if (s.style.lineDash != LineDash.solid) {
      return dashPattern(s.style.lineDash, width);
    }
    if (!options.distinguishByPattern) return null;
    const cycle = [
      LineDash.solid,
      LineDash.dash,
      LineDash.dot,
      LineDash.dashDot,
      LineDash.longDash,
    ];
    return dashPattern(cycle[s.position % cycle.length], width);
  }

  MarkerShape seriesShape(_SeriesInfo s) {
    final explicit = MarkerShape.values[s.style.pointShape.index];
    if (!options.distinguishByPattern ||
        s.style.pointShape != PointShape.circle) {
      return explicit;
    }
    return MarkerShape.values[s.position % MarkerShape.values.length];
  }

  /// Opacity of a series group (legend highlight).
  double seriesOpacity(String key) {
    final h = options.highlightSeriesKey;
    return h == null || h == key ? 1 : 0.3;
  }

  /// Wraps [children] in a dimmed group when another series is highlighted.
  void addSeriesGroup(
    String key,
    List<ScenePrimitive> children,
    List<ScenePrimitive> into,
  ) {
    if (children.isEmpty) return;
    final o = seriesOpacity(key);
    if (o == 1) {
      into.addAll(children);
    } else {
      into.add(SGroup(children, opacity: o));
    }
  }

  // ---------------------------------------------------------------------------
  // Frame.

  void run() {
    final full = ChartRect(0, 0, size.width, size.height);
    out.add(
      SRect(full, fill: background, tag: const SceneTag(SceneRole.background)),
    );
    if (spec.style.border != null) {
      out.add(
        SRect(
          full.inflate(-0.5),
          stroke: SStroke(theme.color(spec.style.border, theme.axisLine)),
        ),
      );
    }
    if (spec.isFromNewerVersion) {
      emptyState(
        full,
        'This chart was created with a newer version of Wonky Sheets',
      );
      return;
    }
    if (!spec.hasKnownType || !spec.type.isImplemented) {
      emptyState(full, 'Unsupported chart type');
      return;
    }
    if (size.width < 8 || size.height < 8) return;
    if (data.isEmpty) {
      var content = full.deflate(left: pad, top: pad, right: pad, bottom: pad);
      content = drawTitles(content);
      emptyState(content, 'No data');
      return;
    }
    var content = full.deflate(left: pad, top: pad, right: pad, bottom: pad);
    if (!maximize) content = drawTitles(content);
    final shapeProblem = dataShapeProblem();
    if (shapeProblem != null) {
      emptyState(content, shapeProblem);
      return;
    }
    final legendEntries = buildLegend();
    final pos = legendPosition(legendEntries);
    final legendPrims = <ScenePrimitive>[];
    ChartRect? insideLegendBox;
    if (legendEntries.isNotEmpty && pos != LegendPosition.none) {
      if (pos == LegendPosition.inside) {
        insideLegendBox = ChartRect.zero; // placed after the plot area is known
      } else {
        content = placeLegend(legendEntries, pos, content, legendPrims);
      }
    }
    switch (spec.type) {
      case _ when spec.is3D:
        _layout3D(this, content);
      case ChartType.pie:
        _layoutPie(this, content);
      case ChartType.radar:
        _layoutRadar(this, content);
      case ChartType.scorecard:
        _layoutScorecard(this, content);
      case ChartType.table:
        _layoutTable(this, content);
      default:
        _layoutCartesian(this, content);
    }
    if (insideLegendBox != null) {
      final p = plotArea ?? content;
      placeLegend(
        legendEntries,
        LegendPosition.inside,
        p.deflate(left: 8, top: 8, right: 8, bottom: 8),
        legendPrims,
      );
    }
    out.addAll(legendPrims);
    if (maximize) {
      drawTitles(plotArea?.deflate(left: 6, top: 4) ?? content, overlay: true);
    }
  }

  /// Why the data can't be drawn as this chart type (shown instead of the chart), or null.
  String? dataShapeProblem() => switch (spec.type) {
    ChartType.candlestick when data.series.length < 4 =>
      'Candlestick charts need low, open, close and high columns',
    ChartType.bubble when data.series.length < 2 =>
      'Bubble charts need X and Y columns',
    _ => null,
  };

  void emptyState(ChartRect r, String message) {
    final style = TextStyleSpec(
      family: family,
      size: 14,
      color: theme.mutedText,
    );
    final m = measure(message, style);
    final shown = m.width > r.width
        ? measurer.ellipsize(message, style, r.width)
        : message;
    out.add(
      text(
        shown,
        r.centerX,
        r.centerY,
        style,
        anchor: TextAnchor.center,
        tag: const SceneTag(SceneRole.emptyState),
      ),
    );
  }

  /// Draws title and subtitle at the top of [r]; returns the remaining rect.
  ChartRect drawTitles(ChartRect r, {bool overlay = false}) {
    var top = r.top;
    for (final (t, role, sz) in [
      (spec.title, SceneRole.title, 16.0),
      (spec.subtitle, SceneRole.subtitle, 13.0),
    ]) {
      if (!t.hasText) continue;
      final style = font(
        t.font,
        size: sz,
        bold: role == SceneRole.title,
        color: role == SceneRole.subtitle ? theme.mutedText : theme.text,
      );
      final s = measurer.ellipsize(t.text, style, r.width);
      final m = measure(s, style);
      final (x, anchor) = switch (t.align) {
        TitleAlign.center => (r.centerX, TextAnchor.topCenter),
        TitleAlign.right => (r.right, TextAnchor.topRight),
        _ => (r.left, TextAnchor.topLeft),
      };
      out.add(text(s, x, top, style, anchor: anchor, tag: SceneTag(role)));
      top += m.height + (role == SceneRole.title ? 4 : 2);
    }
    if (overlay || top == r.top) return r;
    return r.deflate(top: top - r.top + 8);
  }

  // ---------------------------------------------------------------------------
  // Legend.

  List<_LegendEntry> buildLegend() {
    final entries = <_LegendEntry>[];
    switch (spec.type) {
      case ChartType.pie:
        final s = data.series.isEmpty ? null : data.series.first;
        if (s == null) return entries;
        final opts = spec.pieOptions;
        for (var i = 0; i < data.domain.length; i++) {
          if (!(s.values[i] > 0)) continue;
          entries.add(
            _LegendEntry(
              data.domain.labels[i],
              sliceColor(i, opts.slices[i]?.color),
              'box',
              seriesKey: '$i',
            ),
          );
        }
        return entries;
      case ChartType.scorecard || ChartType.table || ChartType.waterfall:
        return entries;
      case ChartType.candlestick:
        return entries;
      case ChartType.histogram:
        if (data.series.length < 2) return entries;
      case ChartType.bubble:
        return bubbleLegend();
      case ChartType.surface:
        return surfaceLegend();
      default:
        break;
    }
    for (final s in seriesInfos) {
      final kind = spec.is3D
          ? 'box'
          : switch (s.mark) {
              _Mark.column || _Mark.area => 'box',
              _Mark.scatter => 'marker',
              _Mark.line =>
                (s.style.pointSize ?? 0) > 0 ? 'lineMarker' : 'line',
            };
      entries.add(
        _LegendEntry(
          s.series.name,
          s.color,
          kind,
          seriesKey: s.key,
          dash: s.mark == _Mark.line ? seriesDash(s, 2) : null,
          shape: seriesShape(s),
        ),
      );
      final tl = s.style.trendline;
      if (tl != null &&
          tl.label != TrendlineLabel.none &&
          spec.type.supportsTrendlines) {
        final label = trendlineLegendLabel(s, tl);
        if (label != null) {
          entries.add(
            _LegendEntry(
              label,
              theme.color(tl.color, s.color),
              'line',
              seriesKey: s.key,
              dash: dashPattern(tl.lineDash, tl.lineWidth),
            ),
          );
        }
      }
    }
    return entries;
  }

  List<_LegendEntry> bubbleLegend() {
    final groups = bubbleGroups();
    if (groups == null) return [];
    return [
      for (var i = 0; i < groups.$1.length; i++)
        _LegendEntry(
          groups.$1[i],
          sliceColor(i, null),
          'marker',
          seriesKey: 'group:$i',
        ),
    ];
  }

  /// Roles of the series of a bubble chart (08 §2: X, Y, color group?, size): after X
  /// (`series[0]`) and Y (`series[1]`), the first series without numbers is the color group
  /// and the first numeric one the bubble size.
  ({int? group, int? size}) bubbleRoles() {
    int? group, size;
    for (var i = 2; i < data.series.length; i++) {
      final s = data.series[i];
      final numeric = s.values.any((v) => !v.isNaN);
      if (numeric) {
        size ??= i;
      } else if (s.texts != null) {
        group ??= i;
      }
    }
    return (group: group, size: size);
  }

  /// Color groups of a bubble chart (labels, group index per point) or null.
  (List<String>, Int32List)? bubbleGroups() {
    final g = bubbleRoles().group;
    final texts = g == null ? null : data.series[g].texts;
    if (texts == null) return null;
    final names = <String>[];
    final index = <String, int>{};
    final per = Int32List(texts.length);
    for (var i = 0; i < texts.length; i++) {
      per[i] = index.putIfAbsent(texts[i], () {
        names.add(texts[i]);
        return names.length - 1;
      });
    }
    return (names, per);
  }

  String? trendlineLegendLabel(_SeriesInfo s, TrendlineSpec tl) {
    if (tl.label == TrendlineLabel.custom) {
      return tl.customLabel.isEmpty
          ? 'Trendline for ${s.series.name}'
          : tl.customLabel;
    }
    final fit = trendlineFit(s, tl);
    if (fit == null) return null;
    final parts = <String>[fit.equation()];
    if (tl.showR2 && fit.r2Label() != null) parts.add(fit.r2Label()!);
    return parts.join('  ');
  }

  final Map<String, RegressionResult?> _fits = {};

  /// x values for regression of series [s] (domain values or 1..n).
  Float64List regressionX() {
    final d = data.domain;
    if (d.isContinuous && !spec.data.treatLabelsAsText) return d.values;
    return Regression.categoricalX(d.length);
  }

  RegressionResult? trendlineFit(_SeriesInfo s, TrendlineSpec tl) {
    if (tl.type == TrendlineType.movingAverage) return null;
    return _fits.putIfAbsent(s.key, () {
      final kind = RegressionKind.values[tl.type.index];
      final r = Regression.fit(
        kind,
        regressionX(),
        s.series.values,
        degree: tl.degree,
      );
      if (r != null && r.skippedCount > 0) {
        final invalid =
            r.skippedCount - s.series.values.where((v) => v.isNaN).length;
        if (invalid > 0) {
          warnings.add(
            ChartWarning(
              ChartWarningCode.trendlineInvalidPoints,
              'Trendline ignores $invalid non-positive values',
              count: invalid,
              seriesKey: s.key,
            ),
          );
        }
      }
      return r;
    });
  }

  LegendPosition legendPosition(List<_LegendEntry> entries) {
    final p = spec.legend.position;
    if (p != LegendPosition.auto) return p;
    if (maximize) return LegendPosition.inside;
    return switch (spec.type) {
      ChartType.pie || ChartType.surface => LegendPosition.right,
      ChartType.histogram => LegendPosition.top,
      _ =>
        entries.length > 1 || spec.type == ChartType.bubble
            ? LegendPosition.top
            : LegendPosition.none,
    };
  }

  /// Value range of a surface chart: its ticks bound the color bands
  /// (one palette color per band, like Excel); null without values.
  late final NiceRange? surfaceRange = () {
    var lo = double.infinity, hi = -double.infinity;
    for (final s in seriesInfos) {
      for (final v in s.series.values) {
        if (!v.isFinite) continue;
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
    if (!lo.isFinite) return null;
    final a = spec.axes.v;
    final g = spec.gridlines.v;
    return NiceTicks.compute(
      lo,
      hi,
      fixedMin: a.min,
      fixedMax: a.max,
      count: g.major.count,
      spacing: g.major.spacing,
    );
  }();

  /// Color band of surface value [v] (0-based).
  int surfaceBand(double v) {
    final r = surfaceRange;
    if (r == null || r.ticks.length < 2) return 0;
    for (var b = 0; b < r.ticks.length - 1; b++) {
      if (v <= r.ticks[b + 1]) return b;
    }
    return r.ticks.length - 2;
  }

  /// One legend entry per value band of a surface chart ("10 – 20").
  List<_LegendEntry> surfaceLegend() {
    final r = surfaceRange;
    if (r == null || r.ticks.length < 2) return [];
    final fmt = seriesInfos.isEmpty
        ? null
        : seriesInfos.first.series.numberFormat;
    return [
      for (var b = 0; b < r.ticks.length - 1; b++)
        _LegendEntry(
          '${formatValue(r.ticks[b], fmt)} – ${formatValue(r.ticks[b + 1], fmt)}',
          sliceColor(b, null),
          'box',
          seriesKey: 'band:$b',
        ),
    ];
  }

  int sliceColor(int i, String? override) {
    final pal = spec.style.palette;
    final base = pal != null && pal.isNotEmpty
        ? theme.color(pal[i % pal.length], theme.seriesColor(i))
        : theme.seriesColor(i);
    return theme.color(override, base);
  }

  /// Lays out the legend at [pos] inside [r]; appends primitives; returns the rect left for
  /// the chart body.
  ChartRect placeLegend(
    List<_LegendEntry> entries,
    LegendPosition pos,
    ChartRect r,
    List<ScenePrimitive> into,
  ) {
    final style = font(spec.legend.font, size: 12, color: theme.text);
    final lm = measure('Ag', style);
    const swatch = 12.0, gap = 6.0, itemGap = 16.0;
    final rowH = math.max(lm.height, swatch) + 4;
    double itemWidth(String label, double maxLabel) {
      final w = math.min(measure(label, style).width, maxLabel);
      return swatch + gap + w;
    }

    final align = spec.legend.alignment;
    if (pos == LegendPosition.top || pos == LegendPosition.bottom) {
      final maxLabel = r.width * 0.6;
      final rows = <List<(_LegendEntry, double)>>[[]];
      var lineW = 0.0;
      for (final e in entries) {
        final w = itemWidth(e.label, maxLabel);
        if (rows.last.isNotEmpty && lineW + itemGap + w > r.width) {
          if (rows.length == 3) break;
          rows.add([]);
          lineW = 0;
        }
        lineW += (rows.last.isEmpty ? 0 : itemGap) + w;
        rows.last.add((e, w));
      }
      final total = rows.length * rowH;
      final top = pos == LegendPosition.top ? r.top : r.bottom - total;
      for (var ri = 0; ri < rows.length; ri++) {
        final row = rows[ri];
        final rw =
            row.fold<double>(0, (s, x) => s + x.$2) +
            itemGap * (row.length - 1);
        var x = switch (align) {
          LegendAlignment.start => r.left,
          LegendAlignment.center => r.left + (r.width - rw) / 2,
          LegendAlignment.end => r.right - rw,
        };
        final cy = top + ri * rowH + rowH / 2;
        for (final (e, w) in row) {
          drawLegendItem(
            e,
            x,
            cy,
            w - swatch - gap,
            style,
            into,
            entries.indexOf(e),
          );
          x += w + itemGap;
        }
      }
      into.insert(
        0,
        SRect(
          ChartRect(r.left, top, r.width, total),
          tag: const SceneTag(SceneRole.legend),
        ),
      );
      return pos == LegendPosition.top
          ? r.deflate(top: total + 8)
          : r.deflate(bottom: total + 8);
    }
    // Vertical legends (left, right, inside).
    final maxLabel = pos == LegendPosition.inside
        ? r.width * 0.5
        : r.width * 0.3;
    var w = 0.0;
    for (final e in entries) {
      w = math.max(w, itemWidth(e.label, maxLabel));
    }
    final maxRows = math.max(1, (r.height / rowH).floor());
    final shown = entries.take(maxRows).toList();
    final h = shown.length * rowH;
    final double left;
    final double top;
    switch (pos) {
      case LegendPosition.left:
        left = r.left;
        top = r.top + (r.height - h) / 2;
      case LegendPosition.inside:
        left = r.right - w;
        top = r.top;
        into.add(
          SRect(
            ChartRect(left - 6, top - 4, w + 12, h + 8),
            fill: Argb.withOpacity(background, 0.85),
            radius: 4,
            tag: const SceneTag(SceneRole.legend),
          ),
        );
      default:
        left = r.right - w;
        top = r.top + (r.height - h) / 2;
    }
    if (pos != LegendPosition.inside) {
      into.add(
        SRect(
          ChartRect(left, top, w, h),
          tag: const SceneTag(SceneRole.legend),
        ),
      );
    }
    for (var i = 0; i < shown.length; i++) {
      drawLegendItem(
        shown[i],
        left,
        top + i * rowH + rowH / 2,
        w - swatch - gap,
        style,
        into,
        i,
      );
    }
    return switch (pos) {
      LegendPosition.left => r.deflate(left: w + 16),
      LegendPosition.inside => r,
      _ => r.deflate(right: w + 16),
    };
  }

  void drawLegendItem(
    _LegendEntry e,
    double x,
    double cy,
    double labelWidth,
    TextStyleSpec style,
    List<ScenePrimitive> into,
    int index,
  ) {
    final tag = SceneTag(
      SceneRole.legendEntry,
      seriesKey: e.seriesKey,
      detail: '$index',
    );
    final items = <ScenePrimitive>[];
    switch (e.kind) {
      case 'line' || 'lineMarker':
        items.add(
          SPolyline(
            Float64List.fromList([x, cy, x + 12, cy]),
            SStroke(e.color, width: 2, dash: e.dash),
            tag: tag,
          ),
        );
        if (e.kind == 'lineMarker') {
          items.add(
            SMarkers(
              Float64List.fromList([x + 6, cy]),
              e.shape ?? MarkerShape.circle,
              6,
              fill: e.color,
              tag: tag,
            ),
          );
        }
      case 'marker':
        items.add(
          SMarkers(
            Float64List.fromList([x + 6, cy]),
            e.shape ?? MarkerShape.circle,
            9,
            fill: e.color,
            tag: tag,
          ),
        );
      default:
        items.add(
          SRect(
            ChartRect(x, cy - 6, 12, 12),
            fill: e.color,
            radius: 2,
            tag: tag,
          ),
        );
    }
    final label = measurer.ellipsize(e.label, style, labelWidth + 0.01);
    items.add(
      text(label, x + 18, cy, style, anchor: TextAnchor.middleLeft, tag: tag),
    );
    final key = e.seriesKey;
    if (key != null &&
        options.highlightSeriesKey != null &&
        spec.type != ChartType.pie) {
      addSeriesGroup(key, items, into);
    } else {
      into.addAll(items);
    }
  }
}
