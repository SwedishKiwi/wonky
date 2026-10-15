part of 'chart_layout_engine.dart';

/// Lays out a 3D column, bar, line, area or pie chart (08 §23): builds the world-space
/// [Chart3DModel], fits a [Chart3DScene] into [r] and emits its software rendering (one
/// [SGroup] tagged [ChartScene.chart3dGroupDetail]) followed by the labels.
void _layout3D(_Ctx c, ChartRect r) {
  final spec = c.spec;
  final t3 = spec.threeD;
  final az = ChartThreeD.normalizeAzimuth(
    c.options.azimuth3D ?? t3.azimuthFor(spec.type),
  );
  final el = (c.options.elevation3D ?? t3.elevationFor(spec.type)).clamp(
    ChartThreeD.minElevation,
    ChartThreeD.maxElevation,
  );
  final body = _axisTitles3D(c, r);
  final b = _Chart3DBuilder(c, az, el.toDouble(), body);
  var model = spec.type == ChartType.pie ? b.pie() : b.cartesian();
  if (model == null) {
    c.emptyState(r, 'No data');
    return;
  }
  final from = c.options.transitionFrom3D;
  if (from != null && c.options.transition3D < 1 && from.kind == model.kind) {
    model = Chart3DModel.lerp(from, model, c.options.transition3D);
  }
  final transform = c.options.transform3D;
  if (transform != null) model = transform(model);
  final fit = body.deflate(
    left: b.marginLeft,
    top: b.marginTop,
    right: b.marginRight,
    bottom: b.marginBottom,
  );
  if (fit.isEmpty) return;
  final scene = Chart3DScene(
    model,
    fit,
    hover: c.options.hover3D,
    fitViews: c.options.fitViews3D,
  );
  c.threeD = scene;
  c.plotArea = body;
  c.out.add(
    SGroup(
      scene.renderGeometry(),
      tag: const SceneTag(
        SceneRole.plotArea,
        detail: ChartScene.chart3dGroupDetail,
      ),
    ),
  );
  c.out.addAll(scene.renderLabels(c.measurer));
}

/// Axis titles of a 3D cartesian chart, drawn at the edges of [r]; returns the rest.
ChartRect _axisTitles3D(_Ctx c, ChartRect r) {
  final spec = c.spec;
  if (spec.type == ChartType.pie) return r;
  TextStyleSpec style(ChartAxis a) =>
      c.font(a.title.font, size: 12, bold: true, color: c.theme.text);
  var out = r;
  final h = spec.axes.h.title;
  if (h.hasText) {
    final st = style(spec.axes.h);
    final m = c.measure('Ag', st);
    c.out.add(
      c.text(
        c.measurer.ellipsize(h.text, st, r.width),
        r.centerX,
        r.bottom,
        st,
        anchor: TextAnchor.bottomCenter,
        tag: const SceneTag(SceneRole.axisTitle, detail: 'h'),
      ),
    );
    out = out.deflate(bottom: m.height + 6);
  }
  final v = spec.axes.v.title;
  if (v.hasText) {
    final st = style(spec.axes.v);
    final m = c.measure('Ag', st);
    c.out.add(
      c.text(
        c.measurer.ellipsize(v.text, st, out.height),
        r.left,
        out.centerY,
        st,
        anchor: TextAnchor.topCenter,
        angle: -math.pi / 2,
        tag: const SceneTag(SceneRole.axisTitle, detail: 'v'),
      ),
    );
    out = out.deflate(left: m.height + 6);
  }
  return out;
}

final class _Chart3DBuilder {
  _Chart3DBuilder(this.c, this.azimuth, this.elevation, this.region);

  final _Ctx c;
  final double azimuth;
  final double elevation;
  final ChartRect region;

  double marginLeft = 4, marginRight = 4, marginTop = 4, marginBottom = 4;

  ChartSpec get spec => c.spec;
  ChartData get data => c.data;
  ChartThreeD get t3 => spec.threeD;

  double get _azRad => azimuth * math.pi / 180;

  /// The camera is in front (+z) of the chart.
  bool get _front => math.cos(_azRad) >= 0;

  /// The camera is right (+x) of the chart.
  bool get _fromRight => math.sin(_azRad) >= 0;

  /// A trendline of series [s] as a thin ribbon in front of its row
  /// (08 §23: trendlines in 3D).
  void _trendline3D(
    List<Chart3DItem> items,
    _SeriesInfo s, {
    required Float64List xs,
    required double Function(double) vw,
    required double z0,
    required double z1,
    required double thick,
    bool bar = false,
  }) {
    final tl = s.style.trendline;
    if (tl == null || !spec.type.supportsTrendlines) return;
    final n = xs.length;
    final Float64List ys;
    if (tl.type == TrendlineType.movingAverage) {
      ys = Regression.movingAverage(s.series.values, math.max(2, tl.period));
    } else {
      final fit = c.trendlineFit(s, tl);
      if (fit == null) return;
      final rx = c.regressionX();
      ys = Float64List.fromList([
        for (var i = 0; i < n; i++) i < rx.length ? fit.predict(rx[i]) : 0,
      ]);
    }
    final tops = Float64List(n), bottoms = Float64List(n);
    for (var i = 0; i < n; i++) {
      final v = i < ys.length ? ys[i] : double.nan;
      if (!v.isFinite) {
        tops[i] = bottoms[i] = double.nan;
        continue;
      }
      final y = vw(v);
      tops[i] = y + thick / 2;
      bottoms[i] = y - thick / 2;
    }
    if (bar) return; // horizontal bars: no ribbon along the value axis yet.
    items.add(
      Chart3DSlab(
        't:${s.key}',
        _dim(c.theme.color(tl.color, s.color), s.key),
        SceneTag(SceneRole.trendline, seriesKey: s.key),
        xs: xs,
        tops: tops,
        bottoms: bottoms,
        z0: z0,
        z1: z1,
      ),
    );
  }

  /// [xs] with [sub] samples per segment.
  static Float64List _dense(Float64List xs, int sub) => Float64List.fromList([
    for (var i = 0; i + 1 < xs.length; i++)
      for (var k = 0; k < sub; k++) xs[i] + (xs[i + 1] - xs[i]) * k / sub,
    xs.last,
  ]);

  /// Monotone cubic (Fritsch–Carlson) through ([xs], [ys]) sampled like
  /// [_dense].
  static Float64List _monotone(Float64List xs, Float64List ys, int sub) {
    final n = xs.length;
    final d = Float64List(n - 1);
    for (var i = 0; i < n - 1; i++) {
      final dx = xs[i + 1] - xs[i];
      d[i] = dx == 0 ? 0 : (ys[i + 1] - ys[i]) / dx;
    }
    final m = Float64List(n);
    m[0] = d[0];
    m[n - 1] = d[n - 2];
    for (var i = 1; i < n - 1; i++) {
      m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2;
    }
    for (var i = 0; i < n - 1; i++) {
      if (d[i] == 0) {
        m[i] = 0;
        m[i + 1] = 0;
        continue;
      }
      final a = m[i] / d[i], b = m[i + 1] / d[i];
      final h = a * a + b * b;
      if (h > 9) {
        final t = 3 / math.sqrt(h);
        m[i] = t * a * d[i];
        m[i + 1] = t * b * d[i];
      }
    }
    final out = <double>[];
    for (var i = 0; i < n - 1; i++) {
      final h = xs[i + 1] - xs[i];
      for (var k = 0; k < sub; k++) {
        final t = k / sub;
        final t2 = t * t, t3 = t2 * t;
        out.add(
          (2 * t3 - 3 * t2 + 1) * ys[i] +
              (t3 - 2 * t2 + t) * h * m[i] +
              (-2 * t3 + 3 * t2) * ys[i + 1] +
              (t3 - t2) * h * m[i + 1],
        );
      }
    }
    out.add(ys[n - 1]);
    return Float64List.fromList(out);
  }

  int _dim(int color, String key) {
    final h = c.options.highlightSeriesKey;
    if (h == null || h == key) return color;
    return Argb.lerp(color, c.background, 0.72);
  }

  Chart3DModel _model(
    Chart3DKind kind,
    List<Chart3DItem> items,
    List<Chart3DLabel> labels,
    Aabb3 bounds,
  ) => Chart3DModel(
    kind: kind,
    items: items,
    labels: labels,
    bounds: bounds,
    azimuth: azimuth,
    elevation: elevation,
    fov: c.options.perspective3D ?? t3.perspective,
    lighting: t3.lighting,
    background: c.background,
    floorY: 0,
    dark: c.theme.isDark,
  );

  // ---------------------------------------------------------------------------
  // Pie.

  Chart3DModel? pie() {
    if (data.series.isEmpty) return null;
    final s = data.series.first;
    final opts = spec.pieOptions;
    var total = 0.0;
    var negatives = 0;
    for (final v in s.values) {
      if (v > 0) {
        total += v;
      } else if (v < 0) {
        negatives++;
      }
    }
    if (negatives > 0) {
      c.warnings.add(
        ChartWarning(
          ChartWarningCode.pieNegativeIgnored,
          'Negative values are not shown in pie charts',
          count: negatives,
          seriesKey: s.key,
        ),
      );
    }
    if (total <= 0) return null;
    const radius = 1.0;
    final inner = radius * opts.pieHole;
    final height = (radius * 0.24 * t3.depth / 100).clamp(0.02, 2.0);
    var maxOffset = 0.0;
    final items = <Chart3DItem>[];
    final labels = <Chart3DLabel>[];
    final style = c.font(
      spec.seriesStyle(s.key).dataLabels.font,
      size: 12,
      bold: true,
    );
    var angle = opts.startAngle * math.pi / 180;
    for (var i = 0; i < s.length; i++) {
      final v = s.values[i];
      if (!(v > 0)) continue;
      final sweep = v / total * 2 * math.pi;
      final offset = math.max(opts.slices[i]?.offset ?? 0, t3.explode) * 0.5;
      maxOffset = math.max(maxOffset, offset);
      final base = c.sliceColor(i, opts.slices[i]?.color);
      final fill = _dim(base, '$i');
      final w = Chart3DWedge(
        'w:$i',
        fill,
        SceneTag(SceneRole.point, seriesKey: s.key, pointIndex: i),
        center: Vec3.zero,
        start: angle,
        sweep: sweep,
        radius: radius,
        innerRadius: inner,
        height: height,
        offset: offset * radius,
      );
      items.add(w);
      final frac = v / total;
      final text = switch (opts.sliceLabel) {
        SliceLabel.none => '',
        SliceLabel.label => data.domain.labels[i],
        SliceLabel.value => c.formatValue(v, s.numberFormat),
        SliceLabel.percentage => c.formatValue(frac, '0.0%'),
        SliceLabel.valueAndPercentage =>
          '${c.formatValue(v, s.numberFormat)} (${c.formatValue(frac, '0.0%')})',
      };
      if (text.isNotEmpty && frac >= 0.03) {
        final lr = inner > 0 ? (radius + inner) / 2 : radius * 0.62;
        final full = sweep >= 2 * math.pi - 1e-9 && inner == 0;
        labels.add(
          Chart3DLabel(
            text,
            Chart3DWedge.polar(w.shiftedCenter, w.mid, full ? 0 : lr, height),
            style.copyWith(
              color: c.theme.color(
                spec.seriesStyle(s.key).dataLabels.font.color,
                c.theme.onColor(fill),
              ),
            ),
            tag: SceneTag(SceneRole.dataLabel, seriesKey: s.key, pointIndex: i),
          ),
        );
      }
      angle += sweep;
    }
    final ext = radius * (1 + maxOffset);
    return _model(
      Chart3DKind.pie,
      items,
      labels,
      Aabb3(Vec3(-ext, 0, -ext), Vec3(ext, height, ext)),
    );
  }

  // ---------------------------------------------------------------------------
  // Column, bar, line, area.

  Chart3DModel? cartesian() {
    final type = spec.type;
    final n = data.domain.length;
    final series = c.seriesInfos;
    if (n == 0 || series.isEmpty) return null;
    final m = series.length;
    final bar = type == ChartType.bar;
    final columnLike = type == ChartType.column || bar;
    final surface = type == ChartType.surface && series.length > 1;
    final stacked =
        spec.stacking != ChartStacking.none &&
        (columnLike || type == ChartType.area);
    final percent = stacked && spec.stacking == ChartStacking.percent;
    final rows = !columnLike && !stacked;

    // Values (stacked: from/to per series and point).
    final from = <Float64List>[];
    final to = <Float64List>[];
    final posBase = Float64List(n), negBase = Float64List(n);
    final totals = Float64List(n);
    if (percent) {
      for (final s in series) {
        for (var i = 0; i < n; i++) {
          final v = i < s.series.length ? s.series.values[i] : double.nan;
          if (v.isFinite) totals[i] += v.abs();
        }
      }
    }
    var lo = double.infinity, hi = -double.infinity;
    for (final s in series) {
      final f = Float64List(n), t = Float64List(n);
      for (var i = 0; i < n; i++) {
        var v = i < s.series.length ? s.series.values[i] : double.nan;
        if (percent && v.isFinite) v = totals[i] == 0 ? 0 : v / totals[i];
        if (!v.isFinite) {
          f[i] = double.nan;
          t[i] = double.nan;
          continue;
        }
        if (stacked) {
          final base = type == ChartType.area || v >= 0 ? posBase : negBase;
          f[i] = base[i];
          t[i] = base[i] + v;
          base[i] += v;
        } else {
          f[i] = 0;
          t[i] = v;
        }
        lo = math.min(lo, math.min(f[i], t[i]));
        hi = math.max(hi, math.max(f[i], t[i]));
      }
      from.add(f);
      to.add(t);
    }
    if (!lo.isFinite) return null;
    final valueAxis = bar ? spec.axes.h : spec.axes.v;
    final valueGrid = bar ? spec.gridlines.h : spec.gridlines.v;
    if (type != ChartType.line && type != ChartType.surface) {
      lo = math.min(lo, 0);
      hi = math.max(hi, 0);
    }
    final range = surface && c.surfaceRange != null
        ? c.surfaceRange!
        : NiceTicks.compute(
            percent ? 0 : lo,
            percent ? math.max(1, hi) : hi,
            target: bar ? 6 : 5,
            fixedMin: valueAxis.min,
            fixedMax: valueAxis.max,
            count: valueGrid.major.count,
            spacing: valueGrid.major.spacing,
          );
    final vmin = range.min, vmax = range.max;
    final span = vmax - vmin == 0 ? 1.0 : vmax - vmin;

    // World extents.
    final catLen = bar ? 1.6 : 2.4;
    final valLen = bar ? 2.4 : 1.45;
    final slot = catLen / n;
    double vw(double v) => ((v - vmin) / span).clamp(0.0, 1.0) * valLen;
    final baseline = vw(0.0.clamp(vmin, vmax));
    // Category coordinate → world position (bars run top to bottom).
    double catW(double cpos) => bar ? catLen - cpos : cpos;
    Vec3 place(double cpos, double val, double z) =>
        bar ? Vec3(val, catW(cpos), z) : Vec3(cpos, val, z);

    final items = <Chart3DItem>[];
    final labels = <Chart3DLabel>[];
    var depth = 0.0;
    if (columnLike) {
      final cluster = slot / 1.45;
      final bw = stacked ? cluster : cluster / m;
      final bd = (bw * t3.depth / 100).clamp(0.02, catLen);
      depth = bd * (1 + t3.gapDepth / 100);
      for (var k = 0; k < m; k++) {
        final s = series[k];
        final color = _dim(s.color, s.key);
        for (var i = 0; i < n; i++) {
          final f = from[k][i], t = to[k][i];
          if (f.isNaN || t.isNaN) continue;
          var c0 = i * slot + (slot - cluster) / 2 + (stacked ? 0 : k * bw);
          var c1 = c0 + bw;
          final inset = stacked ? bw * 0.02 : bw * 0.05;
          c0 += inset;
          c1 -= inset;
          final a = place(c0, vw(f), -bd / 2), b = place(c1, vw(t), bd / 2);
          items.add(
            Chart3DBox(
              'c:${s.key}:$i',
              color,
              SceneTag(SceneRole.point, seriesKey: s.key, pointIndex: i),
              min: Vec3(
                math.min(a.x, b.x),
                math.min(a.y, b.y),
                math.min(a.z, b.z),
              ),
              max: Vec3(
                math.max(a.x, b.x),
                math.max(a.y, b.y),
                math.max(a.z, b.z),
              ),
              shape: t3.shape,
              axis: bar ? 0 : 1,
              tipAtMax: t >= f,
            ),
          );
        }
      }
    } else {
      final rowCount = rows ? m : 1;
      var rd =
          (catLen / math.max(n, 5)).clamp(catLen * 0.06, catLen * 0.3) *
          t3.depth /
          100;
      var spacing = rd * (1 + t3.gapDepth / 100 * 0.4);
      if (surface) {
        // The surface spans a deep floor (its depth % scales it).
        spacing = catLen * 0.8 * t3.depth / 100 / rowCount;
        rd = spacing;
      }
      depth = rowCount * spacing;
      if (depth > catLen * 1.1) {
        final f = catLen * 1.1 / depth;
        rd *= f;
        spacing *= f;
        depth = catLen * 1.1;
      }
      final thick = valLen * 0.035;
      final xs = Float64List.fromList([
        for (var i = 0; i < n; i++) i * slot + slot / 2,
      ]);
      if (surface) {
        // A height field between the series rows, colored by value band
        // (08 §23 surface).
        double zOf(int k) => depth / 2 - spacing * (k + 0.5);
        // Series names along the depth axis, opposite the value labels.
        final st = c.font(
          spec.axes.h.labels.font,
          size: 11,
          color: c.theme.mutedText,
        );
        for (var k = 0; k < m; k++) {
          labels.add(
            Chart3DLabel(
              c.measurer.ellipsize(series[k].series.name, st, 120),
              Vec3(_fromRight ? catLen + 0.04 : -0.04, 0, zOf(k)),
              st,
              outward: Vec3(_fromRight ? 1 : -1, 0, 0),
              tag: SceneTag(
                SceneRole.axisLabel,
                detail: 'z',
                seriesKey: series[k].key,
              ),
            ),
          );
        }
        for (var k = 0; k + 1 < m; k++) {
          final a = to[k], b = to[k + 1];
          for (var i = 0; i + 1 < n; i++) {
            final v = [a[i], a[i + 1], b[i + 1], b[i]];
            if (v.any((x) => x.isNaN)) continue;
            final avg = (v[0] + v[1] + v[2] + v[3]) / 4;
            final band = c.surfaceBand(avg);
            items.add(
              Chart3DPatch(
                'p:$k:$i',
                _dim(c.sliceColor(band, null), 'band:$band'),
                SceneTag(
                  SceneRole.point,
                  seriesKey: series[k].key,
                  pointIndex: i,
                ),
                corners: [
                  Vec3(xs[i], vw(v[0]), zOf(k)),
                  Vec3(xs[i + 1], vw(v[1]), zOf(k)),
                  Vec3(xs[i + 1], vw(v[2]), zOf(k + 1)),
                  Vec3(xs[i], vw(v[3]), zOf(k + 1)),
                ],
                floorY: baseline,
              ),
            );
          }
        }
      }
      for (var k = 0; k < m && !surface; k++) {
        final s = series[k];
        final row = rows ? k : 0;
        final zc = depth / 2 - spacing * (row + 0.5);
        final tops = Float64List(n), bottoms = Float64List(n);
        for (var i = 0; i < n; i++) {
          final f = from[k][i], t = to[k][i];
          if (t.isNaN) {
            tops[i] = double.nan;
            bottoms[i] = double.nan;
          } else if (type == ChartType.line) {
            tops[i] = vw(t) + thick / 2;
            bottoms[i] = vw(t) - thick / 2;
          } else {
            tops[i] = vw(t);
            bottoms[i] = stacked ? vw(f) : baseline;
          }
        }
        // Smooth lines and areas: a monotone cubic through the points,
        // sampled 8× (picking maps back to the nearest point).
        final smooth =
            spec.style.smooth &&
            n >= 3 &&
            !tops.any((v) => v.isNaN) &&
            !bottoms.any((v) => v.isNaN);
        final sx = smooth ? _dense(xs, 8) : xs;
        items.add(
          Chart3DSlab(
            's:${s.key}',
            _dim(s.color, s.key),
            SceneTag(SceneRole.series, seriesKey: s.key),
            xs: sx,
            tops: smooth ? _monotone(xs, tops, 8) : tops,
            bottoms: smooth ? _monotone(xs, bottoms, 8) : bottoms,
            z0: zc - rd / 2,
            z1: zc + rd / 2,
            pointIndexes: smooth
                ? Int32List.fromList([
                    for (var j = 0; j < sx.length; j++) (j / 8).round(),
                  ])
                : null,
          ),
        );
        // Data labels on the ribbon (08 §23.2).
        final dl = s.style.dataLabels;
        if (dl.show && !stacked) {
          final st = c.font(dl.font, size: 11, color: c.theme.text);
          for (var i = 0; i < n; i++) {
            final v = s.series.values[i];
            if (!v.isFinite || tops[i].isNaN) continue;
            labels.add(
              Chart3DLabel(
                c.formatValue(v, s.series.numberFormat),
                Vec3(xs[i], tops[i], zc),
                st,
                outward: const Vec3(0, 1, 0),
                gap: 3,
                tag: SceneTag(
                  SceneRole.dataLabel,
                  seriesKey: s.key,
                  pointIndex: i,
                ),
              ),
            );
          }
        }
        _trendline3D(
          items,
          s,
          xs: xs,
          vw: vw,
          z0: zc + rd / 2 + 0.004,
          z1: zc + rd / 2 + 0.03,
          thick: thick,
        );
      }
    }
    if (columnLike && !stacked) {
      final cluster = slot / 1.45;
      final bd = ((cluster / m) * t3.depth / 100).clamp(0.02, catLen);
      for (var k = 0; k < m; k++) {
        final c0 = slot / 2 - cluster / 2 + (k + 0.5) * cluster / m;
        _trendline3D(
          items,
          series[k],
          xs: Float64List.fromList([for (var i = 0; i < n; i++) i * slot + c0]),
          vw: vw,
          z0: bd / 2 + 0.004,
          z1: bd / 2 + 0.03,
          thick: valLen * 0.03,
          bar: bar,
        );
      }
    }

    // Frame: floor, back and side walls, gridlines.
    const th = 0.035;
    final xw = bar ? valLen : catLen, yh = bar ? catLen : valLen;
    final zf = depth / 2;
    final backZ = _front ? -zf : zf;
    final sideX = _fromRight ? 0.0 : xw;
    final frontZ = _front ? zf : -zf;
    final zLo = -zf - (_front ? th : 0), zHi = zf + (_front ? 0 : th);
    final xLo = _fromRight ? -th : 0.0, xHi = _fromRight ? xw : xw + th;
    final theme = c.theme;
    final floorBase = theme.color(
      t3.floorColor,
      theme.isDark
          ? Argb.lerp(c.background, 0xFFFFFFFF, 0.12)
          : Argb.lerp(c.background, theme.axisLine, 0.16),
    );
    final wallColor = theme.isDark
        ? Argb.lerp(c.background, 0xFFFFFFFF, 0.06)
        : Argb.lerp(c.background, theme.axisLine, 0.06);
    final showMajor = valueGrid.major.show ?? true;
    final gridColor = theme.color(valueGrid.major.color, theme.gridline);
    if (t3.wallsVisible) {
      items.insertAll(0, [
        Chart3DBox(
          'frame:floor',
          floorBase,
          null,
          part: Chart3DPart.floor,
          min: Vec3(xLo, -th, zLo),
          max: Vec3(xHi, 0, zHi),
        ),
        Chart3DBox(
          'frame:back',
          wallColor,
          null,
          part: Chart3DPart.wall,
          min: Vec3(xLo, 0, _front ? -zf - th : zf),
          max: Vec3(xHi, yh, _front ? -zf : zf + th),
        ),
        Chart3DBox(
          'frame:side',
          wallColor,
          null,
          part: Chart3DPart.wall,
          min: Vec3(_fromRight ? -th : xw, 0, zLo),
          max: Vec3(_fromRight ? 0 : xw + th, yh, zHi),
        ),
      ]);
      if (showMajor) {
        for (final tick in range.ticks) {
          final p = vw(tick);
          final zero = tick == 0 && vmin < 0;
          final col = zero ? theme.axisLine : gridColor;
          if (!bar) {
            if (p <= 1e-9 && !zero) continue;
            items.add(
              Chart3DLine(
                'grid:b:$tick',
                col,
                a: Vec3(0, p, backZ),
                b: Vec3(xw, p, backZ),
                normal: Vec3(0, 0, _front ? 1 : -1),
              ),
            );
            items.add(
              Chart3DLine(
                'grid:s:$tick',
                col,
                a: Vec3(sideX, p, backZ),
                b: Vec3(sideX, p, frontZ),
                normal: Vec3(_fromRight ? 1 : -1, 0, 0),
              ),
            );
          } else {
            items.add(
              Chart3DLine(
                'grid:b:$tick',
                col,
                a: Vec3(p, 0, backZ),
                b: Vec3(p, yh, backZ),
                normal: Vec3(0, 0, _front ? 1 : -1),
              ),
            );
            items.add(
              Chart3DLine(
                'grid:f:$tick',
                col,
                a: Vec3(p, 0, backZ),
                b: Vec3(p, 0, frontZ),
                normal: Vec3.unitY,
              ),
            );
          }
        }
      }
    }

    // Labels.
    final valueStyle = c.font(
      valueAxis.labels.font,
      size: 11,
      color: theme.mutedText,
    );
    final domainAxis = bar ? spec.axes.v : spec.axes.h;
    final catStyle = c.font(
      domainAxis.labels.font,
      size: 11,
      color: theme.mutedText,
    );
    final fmtPattern =
        valueAxis.numberFormat ??
        (percent ? '0%' : series.first.series.numberFormat);
    var maxValueW = 0.0;
    if (valueAxis.labels.show) {
      for (final tick in range.ticks) {
        final text = c.formatValue(tick, fmtPattern);
        maxValueW = math.max(maxValueW, c.measure(text, valueStyle).width);
        final p = vw(tick);
        labels.add(
          bar
              ? Chart3DLabel(
                  text,
                  Vec3(p, -th, frontZ),
                  valueStyle,
                  outward: const Vec3(0, -1, 0),
                  tag: const SceneTag(SceneRole.axisLabel, detail: 'h'),
                )
              : Chart3DLabel(
                  text,
                  Vec3(_fromRight ? -th : xw + th, p, frontZ),
                  valueStyle,
                  outward: Vec3(_fromRight ? -1 : 1, 0, 0),
                  tag: const SceneTag(SceneRole.axisLabel, detail: 'v'),
                ),
        );
      }
    }
    var maxCatW = 0.0;
    final catH = c.measure('Ag', catStyle).height;
    if (domainAxis.labels.show && !data.domain.isSynthetic) {
      // Thin out labels that would collide.
      final avail = bar ? region.height : region.width * 0.8;
      final maxW = bar
          ? math.max(40.0, region.width * 0.28)
          : math.max(36.0, avail / n * 1.6);
      var widest = 0.0;
      final texts = <String>[];
      for (var i = 0; i < n; i++) {
        final t = c.measurer.ellipsize(data.domain.labels[i], catStyle, maxW);
        texts.add(t);
        widest = math.max(widest, c.measure(t, catStyle).width);
      }
      final per = bar ? catH + 2 : widest + 8;
      final step = math.max(1, (n * per / math.max(1.0, avail)).ceil());
      for (var i = 0; i < n; i += step) {
        maxCatW = math.max(maxCatW, c.measure(texts[i], catStyle).width);
        final cp = i * slot + slot / 2;
        labels.add(
          bar
              ? Chart3DLabel(
                  texts[i],
                  Vec3(_fromRight ? -th : 0, catW(cp), frontZ),
                  catStyle,
                  outward: const Vec3(-1, 0, 0),
                  tag: const SceneTag(SceneRole.axisLabel, detail: 'v'),
                )
              : Chart3DLabel(
                  texts[i],
                  Vec3(cp, -th, frontZ),
                  catStyle,
                  outward: const Vec3(0, -1, 0),
                  tag: const SceneTag(SceneRole.axisLabel, detail: 'h'),
                ),
        );
      }
    }
    // Data labels on columns and bars.
    if (columnLike) {
      for (var k = 0; k < m; k++) {
        final s = series[k];
        final dl = s.style.dataLabels;
        if (!dl.show) continue;
        final st = c.font(dl.font, size: 11, color: theme.text);
        for (final it in items) {
          if (it is! Chart3DBox || it.tag?.seriesKey != s.key) continue;
          final i = it.tag!.pointIndex!;
          final v = s.series.values[i];
          if (!v.isFinite) continue;
          final tip = bar
              ? Vec3(it.tipAtMax ? it.max.x : it.min.x, it.center.y, it.max.z)
              : Vec3(it.center.x, it.tipAtMax ? it.max.y : it.min.y, it.max.z);
          labels.add(
            Chart3DLabel(
              c.formatValue(
                percent ? to[k][i] - from[k][i] : v,
                s.series.numberFormat,
              ),
              tip,
              st,
              outward: bar
                  ? Vec3(it.tipAtMax ? 1 : -1, 0, 0)
                  : Vec3(0, it.tipAtMax ? 1 : -1, 0),
              gap: 3,
              tag: SceneTag(
                SceneRole.dataLabel,
                seriesKey: s.key,
                pointIndex: i,
              ),
            ),
          );
        }
      }
    }
    // Room for the labels around the projected frame.
    if (bar) {
      marginLeft = maxCatW + 10;
      marginRight = 6;
      marginBottom = c.measure('Ag', valueStyle).height + 10;
      marginTop = 6;
    } else {
      marginLeft = marginRight = maxValueW + 10;
      marginBottom = catH + 10;
      marginTop = 6;
    }
    return _model(
      Chart3DKind.cartesian,
      items,
      labels,
      Aabb3(Vec3(-th, -th, -zf - th), Vec3(xw + th, yh, zf + th)),
    );
  }
}
