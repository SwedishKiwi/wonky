import 'dart:math' as math;
import 'dart:typed_data';

import '../scene/geometry.dart';
import '../scene/path.dart';
import '../scene/scene.dart';
import '../spec/chart_spec.dart';
import '../spec/chart_type.dart';
import '../three_d/chart3d_model.dart';

/// A revealable part of a chart's data (Slides 08 §9.1): a series ([seriesKey] only), a
/// category ([pointIndex] only), one point (both) or everything (neither).
final class ChartRevealKey {
  /// Creates a key.
  const ChartRevealKey({this.seriesKey, this.pointIndex});

  /// Every data part.
  static const all = ChartRevealKey();

  final String? seriesKey;
  final int? pointIndex;

  @override
  bool operator ==(Object other) =>
      other is ChartRevealKey &&
      other.seriesKey == seriesKey &&
      other.pointIndex == pointIndex;

  @override
  int get hashCode => Object.hash(seriesKey, pointIndex);

  @override
  String toString() => 'ChartRevealKey($seriesKey, $pointIndex)';
}

/// The progress of one part: [grow] for `chartGrow` (bars grow, lines draw on, wedges sweep,
/// markers scale) and [opacity] for fade-based effects, both 0..1.
final class ChartPartReveal {
  /// Creates a part state.
  const ChartPartReveal({this.grow = 1, this.opacity = 1});

  /// Fully shown.
  static const shown = ChartPartReveal();

  /// Not shown yet.
  static const hidden = ChartPartReveal(grow: 0, opacity: 0);

  final double grow;
  final double opacity;

  /// Whether the part is fully shown.
  bool get isShown => grow >= 1 && opacity >= 1;

  /// Whether nothing of the part is visible.
  bool get isHidden => grow <= 0 || opacity <= 0;

  @override
  bool operator ==(Object other) =>
      other is ChartPartReveal &&
      other.grow == grow &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(grow, opacity);

  @override
  String toString() => 'ChartPartReveal(grow: $grow, opacity: $opacity)';
}

/// What of a chart is visible during a chart build (Slides 08 §9, 06 §9.2) — the renderer
/// side of the Slides timeline's per-element chart state:
///
/// - [backgroundOpacity] for everything that is not data (background, plot area, titles,
///   axes, gridlines, ticks, legend, baselines);
/// - per data part a [ChartPartReveal], looked up most specific first: the point
///   (series + index), its series, its category (index), then [ChartRevealKey.all]; parts
///   that aren't listed are fully shown;
/// - [dataLabels]: the `labels` part of `chartElement` deliveries (multiplied with the
///   label's own part; labels also appear only in the last 20 % of their part's growth);
/// - an emphasis highlight ([highlightSeries] / [highlightPoint]): other data dims to
///   [dimOthers], blended by [highlightMix].
///
/// [applyTo] transforms a laid-out 2D scene (so every renderer — the Flutter painter, PDF,
/// SVG and raster — honors it without changes; lay out once, apply per frame), [applyTo3D] a
/// 3D model (pass it as `ChartLayoutOptions.transform3D`; `ChartPipeline.layout(reveal:)`
/// does both).
final class ChartReveal {
  /// Creates a reveal state.
  const ChartReveal({
    this.backgroundOpacity = 1,
    this.parts = const {},
    this.dataLabels = ChartPartReveal.shown,
    this.highlightSeries,
    this.highlightPoint,
    this.dimOthers = 0.3,
    this.highlightMix = 0,
  });

  /// Everything shown.
  static const full = ChartReveal();

  final double backgroundOpacity;
  final Map<ChartRevealKey, ChartPartReveal> parts;
  final ChartPartReveal dataLabels;

  /// Series key of a `chartHighlight` on a series.
  final String? highlightSeries;

  /// `(seriesKey, pointIndex)` of a `chartHighlight` on a point.
  final (String, int)? highlightPoint;

  /// Opacity of the other data at full highlight.
  final double dimOthers;

  /// 0 = no highlight, 1 = full highlight.
  final double highlightMix;

  /// Whether nothing is hidden, grown or dimmed.
  bool get isFull =>
      backgroundOpacity >= 1 &&
      dataLabels.isShown &&
      parts.values.every((p) => p.isShown) &&
      !_highlighting;

  bool get _highlighting =>
      (highlightSeries != null || highlightPoint != null) &&
      highlightMix > 0 &&
      dimOthers < 1;

  /// The state of the data at series [seriesKey] / point [pointIndex].
  ChartPartReveal partOf(String? seriesKey, int? pointIndex) {
    if (parts.isEmpty) return ChartPartReveal.shown;
    if (seriesKey != null && pointIndex != null) {
      final p =
          parts[ChartRevealKey(seriesKey: seriesKey, pointIndex: pointIndex)];
      if (p != null) return p;
    }
    if (seriesKey != null) {
      final p = parts[ChartRevealKey(seriesKey: seriesKey)];
      if (p != null) return p;
    }
    if (pointIndex != null) {
      final p = parts[ChartRevealKey(pointIndex: pointIndex)];
      if (p != null) return p;
    }
    return parts[ChartRevealKey.all] ?? ChartPartReveal.shown;
  }

  /// The highlight factor of data at [seriesKey]/[pointIndex] (1 = not dimmed).
  double dimOf(String? seriesKey, int? pointIndex) {
    if (!_highlighting) return 1;
    final hp = highlightPoint;
    final target = hp != null
        ? seriesKey == hp.$1 && (pointIndex == null || pointIndex == hp.$2)
        : seriesKey == highlightSeries;
    if (target) return 1;
    return 1 + (dimOthers.clamp(0.0, 1.0) - 1) * highlightMix.clamp(0.0, 1.0);
  }

  /// Opacity of a data label of a part in state [p] (appears in the last 20 % of the growth).
  double labelOpacity(ChartPartReveal p) {
    final g = ((p.grow - 0.8) / 0.2).clamp(0.0, 1.0);
    return g * p.opacity * dataLabels.opacity * dataLabels.grow.clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // 2D scenes.

  /// [scene] (laid out from [spec]) as it looks in this state. Returns [scene] itself when
  /// [isFull]. 3D charts: the 3D group is left alone (apply [applyTo3D] to the model while
  /// laying out); their labels are faded here.
  ChartScene applyTo(ChartScene scene, ChartSpec spec) {
    if (isFull) return scene;
    final r = _Revealer(this, spec, scene);
    return ChartScene(
      width: scene.width,
      height: scene.height,
      background: _fadeColor(scene.background, backgroundOpacity),
      primitives: List.unmodifiable(r.list(scene.primitives)),
      plotArea: scene.plotArea,
      threeD: scene.threeD,
    );
  }

  // ---------------------------------------------------------------------------
  // 3D models.

  /// [model] in this state: data items grow from their collapsed state by their part's
  /// growth and fade toward the chart background by its opacity (and the highlight); items
  /// that aren't visible are left out; floor, walls and gridlines fade with
  /// [backgroundOpacity].
  Chart3DModel applyTo3D(Chart3DModel model) {
    if (isFull) return model;
    final items = <Chart3DItem>[];
    for (final item in model.items) {
      if (item.part != Chart3DPart.data) {
        if (backgroundOpacity <= 0.01) continue;
        items.add(
          backgroundOpacity >= 1
              ? item
              : item.withColor(
                  Argb.lerp(model.background, item.color, backgroundOpacity),
                ),
        );
        continue;
      }
      final tag = item.tag;
      final p = partOf(tag?.seriesKey, tag?.pointIndex);
      final o = p.opacity * dimOf(tag?.seriesKey, tag?.pointIndex);
      if (p.grow <= 0 || o <= 0.01) continue;
      var out = p.grow >= 1
          ? item
          : item.collapsed.lerpTo(item, p.grow.clamp(0.0, 1.0));
      if (o < 1) {
        out = out.withColor(Argb.lerp(model.background, out.color, o));
      }
      items.add(out);
    }
    return Chart3DModel(
      kind: model.kind,
      items: items,
      labels: model.labels,
      bounds: model.bounds,
      azimuth: model.azimuth,
      elevation: model.elevation,
      fov: model.fov,
      lighting: model.lighting,
      background: model.background,
      floorY: model.floorY,
      dark: model.dark,
    );
  }
}

int _fadeColor(int argb, double o) =>
    o >= 1 ? argb : Argb.withOpacity(argb, o.clamp(0.0, 1.0));

SStroke? _fadeStroke(SStroke? s, double o) => s == null || o >= 1
    ? s
    : SStroke(
        _fadeColor(s.color, o),
        width: s.width,
        dash: s.dash,
        cap: s.cap,
        join: s.join,
      );

/// [p] with every color's alpha multiplied by [o] (cheaper for painters than a group layer
/// per primitive; groups multiply their own opacity).
ScenePrimitive fadePrimitive(ScenePrimitive p, double o) {
  if (o >= 1) return p;
  final f = o.clamp(0.0, 1.0);
  return switch (p) {
    SRect() => SRect(
      p.rect,
      fill: p.fill == null ? null : _fadeColor(p.fill!, f),
      stroke: _fadeStroke(p.stroke, f),
      radius: p.radius,
      tag: p.tag,
    ),
    SPath() => SPath(
      p.cmds,
      fill: p.fill == null ? null : _fadeColor(p.fill!, f),
      stroke: _fadeStroke(p.stroke, f),
      evenOdd: p.evenOdd,
      gradient: p.gradient == null
          ? null
          : SGradient(
              p.gradient!.x0,
              p.gradient!.y0,
              p.gradient!.x1,
              p.gradient!.y1,
              _fadeColor(p.gradient!.color0, f),
              _fadeColor(p.gradient!.color1, f),
            ),
      tag: p.tag,
    ),
    SPolyline() => SPolyline(
      p.xy,
      _fadeStroke(p.stroke, f)!,
      indices: p.indices,
      tag: p.tag,
    ),
    SMarkers() => SMarkers(
      p.xy,
      p.shape,
      p.size,
      fill: _fadeColor(p.fill, f),
      stroke: _fadeStroke(p.stroke, f),
      indices: p.indices,
      sizes: p.sizes,
      fills: p.fills == null
          ? null
          : Int32List.fromList([
              for (final c in p.fills!) _fadeColor(c & 0xFFFFFFFF, f),
            ]),
      tag: p.tag,
    ),
    SArc() => SArc(
      p.center,
      p.radius,
      p.start,
      p.sweep,
      innerRadius: p.innerRadius,
      fill: p.fill == null ? null : _fadeColor(p.fill!, f),
      stroke: _fadeStroke(p.stroke, f),
      tag: p.tag,
    ),
    SText() => SText(
      p.text,
      p.at,
      p.style.copyWith(color: _fadeColor(p.style.color, f)),
      anchor: p.anchor,
      angle: p.angle,
      width: p.width,
      height: p.height,
      ascent: p.ascent,
      tag: p.tag,
    ),
    SClip() => SClip(p.rect, [
      for (final c in p.children) fadePrimitive(c, f),
    ], tag: p.tag),
    SGroup() => SGroup(p.children, opacity: p.opacity * f, tag: p.tag),
  };
}

final class _Revealer {
  _Revealer(this.r, this.spec, this.scene)
    : horizontal = spec.type == ChartType.bar,
      radial = spec.type == ChartType.radar,
      scatter =
          spec.type == ChartType.scatter || spec.type == ChartType.bubble {
    _prepare(scene.primitives);
    _baseline = _mode(_edges);
  }

  final ChartReveal r;
  final ChartSpec spec;
  final ChartScene scene;
  final bool horizontal;
  final bool radial;
  final bool scatter;

  /// Rounded bar edges (value axis) → count, for the zero line.
  final Map<int, int> _edges = {};
  double? _baseline;

  /// Revealed fraction of each line/area series (0..1 along its x extent).
  final Map<String, double> _lineFraction = {};

  static const _backgroundRoles = {
    SceneRole.background,
    SceneRole.plotArea,
    SceneRole.title,
    SceneRole.subtitle,
    SceneRole.axisLine,
    SceneRole.axisLabel,
    SceneRole.axisTitle,
    SceneRole.gridline,
    SceneRole.tick,
    SceneRole.legend,
    SceneRole.legendEntry,
    SceneRole.baseline,
    SceneRole.emptyState,
    SceneRole.tableHeader,
  };

  void _prepare(List<ScenePrimitive> list) {
    for (final p in list) {
      switch (p) {
        case SGroup(:final children, :final tag):
          if (tag?.detail == ChartScene.chart3dGroupDetail) continue;
          _prepare(children);
        case SClip(:final children):
          _prepare(children);
        case SRect(:final rect, :final tag)
            when tag != null && tag.role == SceneRole.point:
          final (a, b) = horizontal
              ? (rect.left, rect.right)
              : (rect.top, rect.bottom);
          _edges.update(a.round(), (n) => n + 1, ifAbsent: () => 1);
          _edges.update(b.round(), (n) => n + 1, ifAbsent: () => 1);
        case SPolyline(:final tag) when tag?.seriesKey != null:
          final key = tag!.seriesKey!;
          _lineFraction[key] = math.max(
            _lineFraction[key] ?? 0,
            _fractionOf(p),
          );
        default:
          break;
      }
    }
  }

  static double? _mode(Map<int, int> counts) {
    int? best;
    var n = 0;
    for (final e in counts.entries) {
      if (e.value > n || (e.value == n && best != null && e.key > best)) {
        best = e.key;
        n = e.value;
      }
    }
    return best?.toDouble();
  }

  /// The revealed fraction of a polyline: uniform growth → that growth; otherwise the
  /// prefix of fully grown vertices plus the next one's growth.
  double _fractionOf(SPolyline p) {
    final n = p.length;
    if (n == 0) return 1;
    final key = p.tag?.seriesKey;
    final g = [
      for (var k = 0; k < n; k++) r.partOf(key, p.pointIndexOf(k)).grow,
    ];
    if (g.every((x) => x == g.first)) return g.first.clamp(0.0, 1.0);
    if (n == 1) return g.first.clamp(0.0, 1.0);
    var done = 0;
    while (done < n && g[done] >= 1) {
      done++;
    }
    if (done >= n) return 1;
    final partial = g[done].clamp(0.0, 1.0);
    // Vertex k sits at k / (n − 1); vertex `done` is reached at (done − 1 + partial).
    final at = done == 0 ? 0.0 : (done - 1 + partial) / (n - 1);
    return at.clamp(0.0, 1.0);
  }

  List<ScenePrimitive> list(List<ScenePrimitive> prims) => [
    for (final p in prims) ?one(p),
  ];

  ScenePrimitive? one(ScenePrimitive p) {
    final tag = p.tag;
    switch (p) {
      case SGroup(:final children):
        if (tag?.detail == ChartScene.chart3dGroupDetail) {
          return p; // 3D: the model carries the reveal.
        }
        final kids = list(children);
        if (kids.isEmpty) return null;
        return SGroup(kids, opacity: p.opacity, tag: tag);
      case SClip(:final rect, :final children):
        final kids = list(children);
        if (kids.isEmpty) return null;
        return SClip(rect, kids, tag: tag);
      default:
        break;
    }
    if (tag == null || _backgroundRoles.contains(tag.role)) {
      return _visible(
        fadePrimitive(p, r.backgroundOpacity),
        r.backgroundOpacity,
      );
    }
    if (tag.role == SceneRole.dataLabel) {
      final part = r.partOf(tag.seriesKey, tag.pointIndex);
      final o = r.labelOpacity(part) * r.dimOf(tag.seriesKey, tag.pointIndex);
      return _visible(fadePrimitive(p, o), o);
    }
    return _data(p, tag);
  }

  static ScenePrimitive? _visible(ScenePrimitive p, double o) =>
      o <= 0.001 ? null : p;

  ScenePrimitive? _data(ScenePrimitive p, SceneTag tag) {
    final key = tag.seriesKey;
    switch (p) {
      case SRect(:final rect):
        final part = r.partOf(key, tag.pointIndex);
        final o = part.opacity * r.dimOf(key, tag.pointIndex);
        if (part.isHidden || o <= 0.001) return null;
        final grown = part.grow >= 1 ? p : _growRect(p, rect, part.grow);
        return fadePrimitive(grown, o);
      case SArc():
        final part = r.partOf(key, tag.pointIndex);
        final o = part.opacity * r.dimOf(key, tag.pointIndex);
        if (part.isHidden || o <= 0.001) return null;
        final grown = part.grow >= 1
            ? p
            : SArc(
                p.center,
                p.radius,
                p.start,
                p.sweep * part.grow,
                innerRadius: p.innerRadius,
                fill: p.fill,
                stroke: p.stroke,
                tag: p.tag,
              );
        return fadePrimitive(grown, o);
      case SPolyline():
        return _polyline(p, tag);
      case SMarkers():
        return _markers(p, tag);
      case SPath():
        return _path(p, tag);
      case SText():
        final part = r.partOf(key, tag.pointIndex);
        final o = part.opacity * r.dimOf(key, tag.pointIndex);
        if (part.isHidden || o <= 0.001) return null;
        return fadePrimitive(p, o);
      case SGroup() || SClip():
        return p;
    }
  }

  SRect _growRect(SRect p, ChartRect rect, double g) {
    final base = _baseline;
    late ChartRect out;
    if (horizontal) {
      final fromLeft =
          base == null || (rect.left - base).abs() <= (rect.right - base).abs();
      final w = rect.width * g;
      out = fromLeft
          ? ChartRect(rect.left, rect.top, w, rect.height)
          : ChartRect(rect.right - w, rect.top, w, rect.height);
    } else {
      final fromBottom =
          base == null || (rect.bottom - base).abs() <= (rect.top - base).abs();
      final h = rect.height * g;
      out = fromBottom
          ? ChartRect(rect.left, rect.bottom - h, rect.width, h)
          : ChartRect(rect.left, rect.top, rect.width, h);
    }
    return SRect(
      out,
      fill: p.fill,
      stroke: p.stroke,
      radius: math.min(p.radius, math.min(out.width, out.height) / 2),
      tag: p.tag,
    );
  }

  ScenePrimitive? _polyline(SPolyline p, SceneTag tag) {
    final key = tag.seriesKey;
    final series = r.partOf(key, null);
    final o = series.opacity * r.dimOf(key, null);
    if (o <= 0.001) return null;
    if (radial) {
      final g = series.grow;
      if (g <= 0) return null;
      final scaled = g >= 1
          ? p
          : SPolyline(
              _scaleXy(p.xy, g),
              p.stroke,
              indices: p.indices,
              tag: p.tag,
            );
      return fadePrimitive(scaled, o);
    }
    final f = _fractionOf(p);
    if (f <= 0) return null;
    final cut = f >= 1 ? p : _truncate(p, f);
    return cut == null ? null : fadePrimitive(cut, o);
  }

  /// The first [f] of [p]'s length.
  static SPolyline? _truncate(SPolyline p, double f) {
    final xy = p.xy;
    final n = p.length;
    if (n < 2) return p;
    var total = 0.0;
    for (var k = 0; k + 1 < n; k++) {
      total += math.sqrt(
        math.pow(xy[2 * k + 2] - xy[2 * k], 2) +
            math.pow(xy[2 * k + 3] - xy[2 * k + 1], 2),
      );
    }
    var left = total * f;
    final out = <double>[xy[0], xy[1]];
    final idx = <int>[p.pointIndexOf(0)];
    for (var k = 0; k + 1 < n; k++) {
      final dx = xy[2 * k + 2] - xy[2 * k], dy = xy[2 * k + 3] - xy[2 * k + 1];
      final len = math.sqrt(dx * dx + dy * dy);
      if (len <= left) {
        out
          ..add(xy[2 * k + 2])
          ..add(xy[2 * k + 3]);
        idx.add(p.pointIndexOf(k + 1));
        left -= len;
        continue;
      }
      final t = len == 0 ? 0.0 : left / len;
      out
        ..add(xy[2 * k] + dx * t)
        ..add(xy[2 * k + 1] + dy * t);
      idx.add(p.pointIndexOf(k));
      break;
    }
    if (out.length < 4) return null;
    return SPolyline(
      Float64List.fromList(out),
      p.stroke,
      indices: Int32List.fromList(idx),
      tag: p.tag,
    );
  }

  ChartPoint get _center {
    final a = scene.plotArea;
    return a == null
        ? ChartPoint(scene.width / 2, scene.height / 2)
        : ChartPoint(a.left + a.width / 2, a.top + a.height / 2);
  }

  Float64List _scaleXy(Float64List xy, double g) {
    final c = _center;
    return Float64List.fromList([
      for (var i = 0; i < xy.length; i++)
        i.isEven ? c.x + (xy[i] - c.x) * g : c.y + (xy[i] - c.y) * g,
    ]);
  }

  ScenePrimitive? _markers(SMarkers p, SceneTag tag) {
    final key = tag.seriesKey;
    final n = p.length;
    final line = !scatter && !radial ? _lineFraction[key] : null;
    final sizes = Float64List(n);
    final fills = Int32List(n);
    var any = false;
    var changed = false;
    for (var k = 0; k < n; k++) {
      final i = p.pointIndexOf(k);
      final part = r.partOf(key, i);
      final o = part.opacity * r.dimOf(key, i);
      var scale = part.grow.clamp(0.0, 1.0);
      if (line != null) {
        // Pops in when the line reaches it.
        final at = n == 1 ? 0.0 : k / (n - 1);
        scale = line >= at - 1e-9 ? 1.0 : 0.0;
      }
      final size = p.sizeOf(k) * scale;
      sizes[k] = o <= 0.001 ? 0 : size;
      fills[k] = _fadeColor(p.fillOf(k), o);
      if (sizes[k] > 0) any = true;
      if (sizes[k] != p.sizeOf(k) || o < 1) changed = true;
    }
    if (!any) return null;
    if (!changed) return p;
    final xy = radial ? _scaleXy(p.xy, r.partOf(key, null).grow) : p.xy;
    return SMarkers(
      xy,
      p.shape,
      p.size,
      fill: p.fill,
      stroke: p.stroke,
      indices: p.indices,
      sizes: sizes,
      fills: fills,
      tag: p.tag,
    );
  }

  ScenePrimitive? _path(SPath p, SceneTag tag) {
    final key = tag.seriesKey;
    final part = r.partOf(
      key,
      tag.role == SceneRole.series ? null : tag.pointIndex,
    );
    final o = part.opacity * r.dimOf(key, tag.pointIndex);
    if (o <= 0.001) return null;
    if (radial) {
      final g = part.grow;
      if (g <= 0) return null;
      final c = _center;
      return fadePrimitive(g >= 1 ? p : _scalePath(p, c, g), o);
    }
    if (tag.role != SceneRole.series) {
      // Per-point shapes (candlestick wicks, error bars): fade and scale-free.
      if (part.isHidden) return null;
      return fadePrimitive(p, o);
    }
    final f = key == null ? part.grow : (_lineFraction[key] ?? part.grow);
    if (f <= 0) return null;
    if (f >= 1) return fadePrimitive(p, o);
    final b = p.bounds;
    final clip = horizontal
        ? ChartRect(b.left, b.top, b.width, b.height * f)
        : ChartRect(b.left, b.top - 1, b.width * f, b.height + 2);
    return SClip(clip, [fadePrimitive(p, o)]);
  }

  static SPath _scalePath(SPath p, ChartPoint c, double g) {
    double x(double v) => c.x + (v - c.x) * g;
    double y(double v) => c.y + (v - c.y) * g;
    return SPath(
      [
        for (final cmd in p.cmds)
          switch (cmd) {
            PMoveTo() => PMoveTo(x(cmd.x), y(cmd.y)),
            PLineTo() => PLineTo(x(cmd.x), y(cmd.y)),
            PCubicTo() => PCubicTo(
              x(cmd.x1),
              y(cmd.y1),
              x(cmd.x2),
              y(cmd.y2),
              x(cmd.x),
              y(cmd.y),
            ),
            PClose() => cmd,
          },
      ],
      fill: p.fill,
      stroke: p.stroke,
      evenOdd: p.evenOdd,
      gradient: p.gradient,
      tag: p.tag,
    );
  }
}
