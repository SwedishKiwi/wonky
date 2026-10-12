import 'dart:math' as math;
import 'dart:typed_data';

import 'geometry.dart';
import 'path.dart';

/// Semantic role of a scene primitive (08 §6.3), used for hit-testing, tooltips and the
/// double-click → editor section mapping (08 §6.5).
enum SceneRole {
  background,
  plotArea,
  title,
  subtitle,
  axisLine,
  axisLabel,
  axisTitle,
  gridline,
  tick,
  legend,
  legendEntry,
  series,
  point,
  dataLabel,
  trendline,
  connector,
  tableCell,
  tableHeader,
  keyValue,
  baseline,
  emptyState,
}

/// Semantic tag of a primitive: which series/point/element it draws.
final class SceneTag {
  /// Creates a tag.
  const SceneTag(this.role, {this.seriesKey, this.pointIndex, this.detail});

  /// What the primitive is.
  final SceneRole role;

  /// Series key (08 §3.2) for series-related primitives.
  final String? seriesKey;

  /// Domain index of the point (for per-point primitives; markers and polylines resolve the
  /// index per vertex during hit-testing).
  final int? pointIndex;

  /// Extra discriminator: axis id (`h`, `v`, `v2`), legend entry index, table column, ….
  final String? detail;

  /// Copy with a point index.
  SceneTag withPoint(int index) => SceneTag(role, seriesKey: seriesKey, pointIndex: index, detail: detail);

  /// Stable JSON.
  Map<String, Object?> toJson() => {
    'role': role.name,
    'series': ?seriesKey,
    'point': ?pointIndex,
    'detail': ?detail,
  };

  @override
  bool operator ==(Object other) =>
      other is SceneTag &&
      other.role == role &&
      other.seriesKey == seriesKey &&
      other.pointIndex == pointIndex &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(role, seriesKey, pointIndex, detail);

  @override
  String toString() => 'SceneTag(${toJson()})';
}

/// Line cap of a stroke.
enum SStrokeCap { butt, round, square }

/// Line join of a stroke.
enum SStrokeJoin { miter, round, bevel }

/// A stroke (colors are ARGB ints).
final class SStroke {
  /// Creates a stroke.
  const SStroke(
    this.color, {
    this.width = 1,
    this.dash,
    this.cap = SStrokeCap.butt,
    this.join = SStrokeJoin.miter,
  });

  /// ARGB color.
  final int color;

  /// Width in px.
  final double width;

  /// Dash pattern (on, off, …) in px; null = solid.
  final List<double>? dash;

  final SStrokeCap cap;
  final SStrokeJoin join;

  /// Stable JSON.
  Map<String, Object?> toJson(num Function(double) n) => {
    'color': argbHex(color),
    'width': n(width),
    if (dash != null) 'dash': [for (final d in dash!) n(d)],
    if (cap != SStrokeCap.butt) 'cap': cap.name,
    if (join != SStrokeJoin.miter) 'join': join.name,
  };
}

/// Font and color of a text primitive.
final class TextStyleSpec {
  /// Creates a style.
  const TextStyleSpec({
    this.family,
    this.size = 12,
    this.bold = false,
    this.italic = false,
    this.color = 0xFF000000,
  });

  /// Font family (null = renderer default sans).
  final String? family;

  /// Font size in px.
  final double size;
  final bool bold;
  final bool italic;

  /// ARGB color.
  final int color;

  /// Copy with changes.
  TextStyleSpec copyWith({String? family, double? size, bool? bold, bool? italic, int? color}) =>
      TextStyleSpec(
        family: family ?? this.family,
        size: size ?? this.size,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        color: color ?? this.color,
      );

  /// Stable JSON.
  Map<String, Object?> toJson(num Function(double) n) => {
    'family': ?family,
    'size': n(size),
    if (bold) 'bold': true,
    if (italic) 'italic': true,
    'color': argbHex(color),
  };

  @override
  bool operator ==(Object other) =>
      other is TextStyleSpec &&
      other.family == family &&
      other.size == size &&
      other.bold == bold &&
      other.italic == italic &&
      other.color == color;

  @override
  int get hashCode => Object.hash(family, size, bold, italic, color);
}

/// Which point of the text's box [SText.at] refers to (before rotation; rotation is about
/// [SText.at]). `baseline*` anchors refer to the first line's baseline.
enum TextAnchor {
  topLeft(0, _V.top),
  topCenter(0.5, _V.top),
  topRight(1, _V.top),
  middleLeft(0, _V.middle),
  center(0.5, _V.middle),
  middleRight(1, _V.middle),
  bottomLeft(0, _V.bottom),
  bottomCenter(0.5, _V.bottom),
  bottomRight(1, _V.bottom),
  baselineLeft(0, _V.baseline),
  baselineCenter(0.5, _V.baseline),
  baselineRight(1, _V.baseline);

  const TextAnchor(this.hFactor, this._v);

  /// Horizontal anchor: 0 = left/start, 0.5 = center, 1 = right/end.
  final double hFactor;
  final _V _v;

  /// Whether the anchor is on the top edge.
  bool get isTop => _v == _V.top;

  /// Whether the anchor is on the vertical middle.
  bool get isMiddle => _v == _V.middle;

  /// Whether the anchor is on the bottom edge.
  bool get isBottom => _v == _V.bottom;

  /// Whether the anchor is on the baseline.
  bool get isBaseline => _v == _V.baseline;

  /// Offset from the anchor point to the baseline-left origin of the text, for a text box of
  /// [width] × [height] with [ascent] (unrotated).
  (double dx, double dy) baselineOrigin(double width, double height, double ascent) {
    final dx = -hFactor * width;
    final dy = switch (_v) {
      _V.top => ascent,
      _V.middle => ascent - height / 2,
      _V.bottom => ascent - height,
      _V.baseline => 0.0,
    };
    return (dx, dy);
  }
}

enum _V { top, middle, bottom, baseline }

/// Marker shapes (08 §3.4 `pointShape`).
enum MarkerShape { circle, triangle, square, diamond, star, polygon }

/// A drawing primitive of a [ChartScene] (08 §6.3). Colors are resolved ARGB ints.
sealed class ScenePrimitive {
  const ScenePrimitive({this.tag});

  /// Semantic tag (series key, point index, role).
  final SceneTag? tag;

  /// Type id in JSON.
  String get typeId;

  /// Stable JSON body (without type and tag).
  Map<String, Object?> _body(num Function(double) n);

  /// Stable JSON (numbers rounded through [n]).
  Map<String, Object?> toJson([num Function(double) n = sceneNum]) => {
    't': typeId,
    ..._body(n),
    if (tag != null) 'tag': tag!.toJson(),
  };

  /// Axis-aligned bounds (approximate for text and paths).
  ChartRect get bounds;
}

/// A rectangle, optionally rounded.
final class SRect extends ScenePrimitive {
  /// Creates a rectangle.
  const SRect(this.rect, {this.fill, this.stroke, this.radius = 0, super.tag});

  final ChartRect rect;

  /// ARGB fill or null.
  final int? fill;
  final SStroke? stroke;

  /// Corner radius in px.
  final double radius;

  @override
  String get typeId => 'rect';

  @override
  ChartRect get bounds => rect;

  @override
  Map<String, Object?> _body(num Function(double) n) => {
    'r': [n(rect.left), n(rect.top), n(rect.width), n(rect.height)],
    if (fill != null) 'fill': argbHex(fill!),
    if (stroke != null) 'stroke': stroke!.toJson(n),
    if (radius != 0) 'radius': n(radius),
  };
}

/// A general path.
final class SPath extends ScenePrimitive {
  /// Creates a path.
  const SPath(this.cmds, {this.fill, this.stroke, this.evenOdd = false, super.tag});

  final List<PathCmd> cmds;

  /// ARGB fill or null.
  final int? fill;
  final SStroke? stroke;

  /// Even-odd fill rule (default non-zero).
  final bool evenOdd;

  @override
  String get typeId => 'path';

  @override
  ChartRect get bounds {
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    void add(double x, double y) {
      if (x < l) l = x;
      if (x > r) r = x;
      if (y < t) t = y;
      if (y > b) b = y;
    }

    for (final c in cmds) {
      switch (c) {
        case PMoveTo(:final x, :final y):
          add(x, y);
        case PLineTo(:final x, :final y):
          add(x, y);
        case PCubicTo(:final x1, :final y1, :final x2, :final y2, :final x, :final y):
          add(x1, y1);
          add(x2, y2);
          add(x, y);
        case PClose():
          break;
      }
    }
    if (l > r) return ChartRect.zero;
    return ChartRect.fromLTRB(l, t, r, b);
  }

  @override
  Map<String, Object?> _body(num Function(double) n) => {
    'cmds': [for (final c in cmds) c.toJson(n)],
    if (fill != null) 'fill': argbHex(fill!),
    if (stroke != null) 'stroke': stroke!.toJson(n),
    if (evenOdd) 'evenOdd': true,
  };
}

/// A polyline (`x0, y0, x1, y1, …`); the fast path for large line series.
final class SPolyline extends ScenePrimitive {
  /// Creates a polyline. [indices] maps vertex k to its domain point index (null = k).
  const SPolyline(this.xy, this.stroke, {this.indices, super.tag});

  final Float64List xy;
  final SStroke stroke;

  /// Point index per vertex (after gaps/downsampling), or null for identity.
  final Int32List? indices;

  /// Number of vertices.
  int get length => xy.length ~/ 2;

  /// Domain point index of vertex [k].
  int pointIndexOf(int k) => indices == null ? k : indices![k];

  @override
  String get typeId => 'polyline';

  @override
  ChartRect get bounds => _boundsOf(xy, 0);

  @override
  Map<String, Object?> _body(num Function(double) n) => {
    'xy': [for (final v in xy) n(v)],
    'stroke': stroke.toJson(n),
    if (indices != null) 'indices': indices!.toList(),
  };
}

/// Point markers of one series, all with the same shape, size and paint.
final class SMarkers extends ScenePrimitive {
  /// Creates markers. [sizes] (per marker diameter) overrides [size] for bubbles; [fills]
  /// (per marker ARGB) overrides [fill] (per-point colors, bubble color groups).
  const SMarkers(
    this.xy,
    this.shape,
    this.size, {
    required this.fill,
    this.stroke,
    this.indices,
    this.sizes,
    this.fills,
    super.tag,
  });

  final Float64List xy;
  final MarkerShape shape;

  /// Diameter in px.
  final double size;

  /// ARGB fill.
  final int fill;
  final SStroke? stroke;

  /// Point index per marker, or null for identity.
  final Int32List? indices;

  /// Per-marker diameters or null.
  final Float64List? sizes;

  /// Per-marker fills or null.
  final Int32List? fills;

  /// Number of markers.
  int get length => xy.length ~/ 2;

  /// Domain point index of marker [k].
  int pointIndexOf(int k) => indices == null ? k : indices![k];

  /// Diameter of marker [k].
  double sizeOf(int k) => sizes == null ? size : sizes![k];

  /// Fill of marker [k] (ARGB).
  int fillOf(int k) => fills == null ? fill : fills![k] & 0xFFFFFFFF;

  @override
  String get typeId => 'markers';

  @override
  ChartRect get bounds {
    var maxSize = size;
    if (sizes != null) {
      for (final s in sizes!) {
        if (s > maxSize) maxSize = s;
      }
    }
    return _boundsOf(xy, maxSize / 2);
  }

  @override
  Map<String, Object?> _body(num Function(double) n) => {
    'xy': [for (final v in xy) n(v)],
    'shape': shape.name,
    'size': n(size),
    'fill': argbHex(fill),
    if (stroke != null) 'stroke': stroke!.toJson(n),
    if (indices != null) 'indices': indices!.toList(),
    if (sizes != null) 'sizes': [for (final s in sizes!) n(s)],
    if (fills != null) 'fills': [for (final f in fills!) argbHex(f & 0xFFFFFFFF)],
  };
}

/// A circular arc sector (pie slice) or ring segment (doughnut). Angles in radians, 0 =
/// 3 o'clock, positive sweeps clockwise on screen (same as Flutter `Canvas.drawArc`).
final class SArc extends ScenePrimitive {
  /// Creates an arc.
  const SArc(
    this.center,
    this.radius,
    this.start,
    this.sweep, {
    this.innerRadius = 0,
    this.fill,
    this.stroke,
    super.tag,
  });

  final ChartPoint center;
  final double radius;
  final double innerRadius;
  final double start;
  final double sweep;

  /// ARGB fill or null.
  final int? fill;
  final SStroke? stroke;

  /// The arc outline as path commands (sector or ring segment).
  List<PathCmd> toPath() {
    final b = PathBuilder();
    final full = sweep.abs() >= 2 * math.pi - 1e-9;
    if (full) {
      b
        ..arc(center.x, center.y, radius, start, math.pi)
        ..arc(center.x, center.y, radius, start + math.pi, math.pi)
        ..close();
      if (innerRadius > 0) {
        b
          ..arc(center.x, center.y, innerRadius, start, -math.pi)
          ..arc(center.x, center.y, innerRadius, start - math.pi, -math.pi)
          ..close();
      }
      return b.commands;
    }
    if (innerRadius > 0) {
      b
        ..arc(center.x, center.y, radius, start, sweep)
        ..arc(center.x, center.y, innerRadius, start + sweep, -sweep)
        ..close();
    } else {
      b
        ..moveTo(center.x, center.y)
        ..arc(center.x, center.y, radius, start, sweep)
        ..close();
    }
    return b.commands;
  }

  /// Whether the full ring (or disc) is drawn (two even-odd sub-paths when hollow).
  bool get isFullCircle => sweep.abs() >= 2 * math.pi - 1e-9;

  @override
  String get typeId => 'arc';

  @override
  ChartRect get bounds =>
      ChartRect(center.x - radius, center.y - radius, radius * 2, radius * 2);

  @override
  Map<String, Object?> _body(num Function(double) n) => {
    'c': [n(center.x), n(center.y)],
    'r': n(radius),
    if (innerRadius != 0) 'ir': n(innerRadius),
    'start': n(start),
    'sweep': n(sweep),
    if (fill != null) 'fill': argbHex(fill!),
    if (stroke != null) 'stroke': stroke!.toJson(n),
  };
}

/// A single line of text. [width], [height] and [ascent] are the layout measurer's metrics
/// (used for hit-testing and by renderers without their own font metrics).
final class SText extends ScenePrimitive {
  /// Creates a text primitive.
  const SText(
    this.text,
    this.at,
    this.style, {
    this.anchor = TextAnchor.baselineLeft,
    this.angle = 0,
    this.width = 0,
    this.height = 0,
    this.ascent = 0,
    super.tag,
  });

  final String text;
  final ChartPoint at;
  final TextStyleSpec style;
  final TextAnchor anchor;

  /// Rotation in radians around [at], positive = clockwise on screen.
  final double angle;
  final double width;
  final double height;
  final double ascent;

  /// The unrotated text box.
  ChartRect get box {
    final (dx, dy) = anchor.baselineOrigin(width, height, ascent);
    return ChartRect(at.x + dx, at.y + dy - ascent, width, height);
  }

  @override
  String get typeId => 'text';

  @override
  ChartRect get bounds {
    final b = box;
    if (angle == 0) return b;
    final c = math.cos(angle), s = math.sin(angle);
    var l = double.infinity, t = double.infinity, r = -double.infinity, bt = -double.infinity;
    for (final (x, y) in [(b.left, b.top), (b.right, b.top), (b.right, b.bottom), (b.left, b.bottom)]) {
      final dx = x - at.x, dy = y - at.y;
      final rx = at.x + dx * c - dy * s, ry = at.y + dx * s + dy * c;
      l = math.min(l, rx);
      r = math.max(r, rx);
      t = math.min(t, ry);
      bt = math.max(bt, ry);
    }
    return ChartRect.fromLTRB(l, t, r, bt);
  }

  /// Whether ([x], [y]) lies inside the (rotated) text box grown by [tolerance].
  bool containsPoint(double x, double y, double tolerance) {
    final c = math.cos(-angle), s = math.sin(-angle);
    final dx = x - at.x, dy = y - at.y;
    final ux = at.x + dx * c - dy * s, uy = at.y + dx * s + dy * c;
    return box.inflate(tolerance).contains(ux, uy);
  }

  @override
  Map<String, Object?> _body(num Function(double) n) => {
    'text': text,
    'at': [n(at.x), n(at.y)],
    'style': style.toJson(n),
    'anchor': anchor.name,
    if (angle != 0) 'angle': n(angle),
    'w': n(width),
    'h': n(height),
  };
}

/// Clips [children] to [rect].
final class SClip extends ScenePrimitive {
  /// Creates a clip.
  const SClip(this.rect, this.children, {super.tag});

  final ChartRect rect;
  final List<ScenePrimitive> children;

  @override
  String get typeId => 'clip';

  @override
  ChartRect get bounds => rect;

  @override
  Map<String, Object?> _body(num Function(double) n) => {
    'r': [n(rect.left), n(rect.top), n(rect.width), n(rect.height)],
    'children': [for (final c in children) c.toJson(n)],
  };
}

/// Groups [children], optionally with an [opacity] applied to the group as a whole.
final class SGroup extends ScenePrimitive {
  /// Creates a group.
  const SGroup(this.children, {this.opacity = 1, super.tag});

  final List<ScenePrimitive> children;

  /// Group opacity 0..1.
  final double opacity;

  @override
  String get typeId => 'group';

  @override
  ChartRect get bounds {
    ChartRect? b;
    for (final c in children) {
      final cb = c.bounds;
      b = b == null
          ? cb
          : ChartRect.fromLTRB(
              math.min(b.left, cb.left),
              math.min(b.top, cb.top),
              math.max(b.right, cb.right),
              math.max(b.bottom, cb.bottom),
            );
    }
    return b ?? ChartRect.zero;
  }

  @override
  Map<String, Object?> _body(num Function(double) n) => {
    if (opacity != 1) 'opacity': n(opacity),
    'children': [for (final c in children) c.toJson(n)],
  };
}

/// Result of [ChartScene.hitTest].
final class SceneHit {
  /// Creates a hit.
  const SceneHit(this.tag, this.primitive, this.distance);

  /// Tag of the hit primitive, with [SceneTag.pointIndex] resolved for markers/polylines.
  final SceneTag tag;

  /// The primitive.
  final ScenePrimitive primitive;

  /// Distance from the query point in px (0 when inside).
  final double distance;

  @override
  String toString() => 'SceneHit($tag, ${primitive.typeId}, $distance)';
}

/// A laid-out chart: renderer-independent list of primitives (08 §6.3).
final class ChartScene {
  /// Creates a scene.
  const ChartScene({
    required this.width,
    required this.height,
    required this.background,
    required this.primitives,
    this.plotArea,
  });

  final double width;
  final double height;

  /// ARGB background (drawn by renderers before the primitives; 0 = transparent).
  final int background;

  /// Primitives in paint order.
  final List<ScenePrimitive> primitives;

  /// The plot rectangle (cartesian/radial charts) or null.
  final ChartRect? plotArea;

  /// Stable JSON (numbers rounded to 2 decimals) for scene goldens.
  Map<String, Object?> toJson() => {
    'w': sceneNum(width),
    'h': sceneNum(height),
    'bg': argbHex(background),
    if (plotArea != null)
      'plot': [
        sceneNum(plotArea!.left),
        sceneNum(plotArea!.top),
        sceneNum(plotArea!.width),
        sceneNum(plotArea!.height),
      ],
    'p': [for (final p in primitives) p.toJson()],
  };

  /// All primitives depth-first (groups and clips expanded), in paint order.
  Iterable<ScenePrimitive> get flattened sync* {
    Iterable<ScenePrimitive> walk(List<ScenePrimitive> list) sync* {
      for (final p in list) {
        switch (p) {
          case SGroup(:final children):
            yield* walk(children);
          case SClip(:final children):
            yield* walk(children);
          default:
            yield p;
        }
      }
    }

    yield* walk(primitives);
  }

  /// The tagged primitive under ([x], [y]) within [tolerance] px (08 §6.5: 8 px). Point-level
  /// hits (markers, polyline vertices, columns, slices) win over larger elements; among equals
  /// the topmost (last painted) and then the nearest wins.
  SceneHit? hitTest(double x, double y, {double tolerance = 8}) {
    SceneHit? best;
    var bestRank = -1;
    void consider(SceneHit hit, int rank) {
      if (best == null ||
          rank > bestRank ||
          (rank == bestRank && hit.distance <= best!.distance)) {
        best = hit;
        bestRank = rank;
      }
    }

    void walk(List<ScenePrimitive> list, ChartRect? clip) {
      for (final p in list) {
        switch (p) {
          case SGroup(:final children):
            walk(children, clip);
            continue;
          case SClip(:final rect, :final children):
            final c = clip == null ? rect : (clip.intersect(rect) ?? ChartRect.zero);
            walk(children, c);
            continue;
          default:
            break;
        }
        final tag = p.tag;
        if (tag == null) continue;
        if (clip != null && !clip.inflate(tolerance).contains(x, y)) continue;
        final hit = _hitPrimitive(p, tag, x, y, tolerance);
        if (hit == null) continue;
        consider(hit, _rank(hit.tag));
      }
    }

    walk(primitives, null);
    return best;
  }

  static int _rank(SceneTag t) => switch (t.role) {
    SceneRole.point || SceneRole.dataLabel => 5,
    SceneRole.series || SceneRole.trendline || SceneRole.legendEntry => 4,
    SceneRole.tableCell || SceneRole.tableHeader || SceneRole.keyValue || SceneRole.baseline => 4,
    SceneRole.title || SceneRole.subtitle || SceneRole.axisTitle || SceneRole.axisLabel => 3,
    SceneRole.legend || SceneRole.axisLine || SceneRole.connector => 2,
    SceneRole.gridline || SceneRole.tick => 1,
    _ => 0,
  };

  static SceneHit? _hitPrimitive(ScenePrimitive p, SceneTag tag, double x, double y, double tol) {
    switch (p) {
      case SRect(:final rect):
        final d = rect.distanceTo(x, y);
        return d <= tol ? SceneHit(tag, p, d) : null;
      case SArc(:final center, :final radius, :final innerRadius, :final start, :final sweep):
        final dx = x - center.x, dy = y - center.y;
        final r = math.sqrt(dx * dx + dy * dy);
        if (r > radius + tol || r < innerRadius - tol) return null;
        if (p.isFullCircle) return SceneHit(tag, p, 0);
        var a = math.atan2(dy, dx) - (sweep >= 0 ? start : start + sweep);
        a %= 2 * math.pi;
        if (a > sweep.abs()) return null;
        final d = r > radius ? r - radius : (r < innerRadius ? innerRadius - r : 0.0);
        return SceneHit(tag, p, d);
      case SText():
        return p.containsPoint(x, y, tol) ? SceneHit(tag, p, 0) : null;
      case SMarkers(:final xy):
        var bestK = -1;
        var bestD = double.infinity;
        for (var k = 0; k < p.length; k++) {
          final dx = xy[2 * k] - x, dy = xy[2 * k + 1] - y;
          final d = math.max(0.0, math.sqrt(dx * dx + dy * dy) - p.sizeOf(k) / 2);
          if (d < bestD) {
            bestD = d;
            bestK = k;
          }
        }
        if (bestK < 0 || bestD > tol) return null;
        return SceneHit(tag.withPoint(p.pointIndexOf(bestK)), p, bestD);
      case SPolyline(:final xy, :final stroke):
        final n = p.length;
        var bestD = double.infinity;
        var bestK = -1;
        for (var k = 0; k < n; k++) {
          final vx = xy[2 * k], vy = xy[2 * k + 1];
          final dv = math.sqrt((vx - x) * (vx - x) + (vy - y) * (vy - y));
          if (dv < bestD) {
            bestD = dv;
            bestK = k;
          }
        }
        var segD = double.infinity;
        for (var k = 0; k + 1 < n; k++) {
          final d = PathGeometry.segmentDistance(x, y, xy[2 * k], xy[2 * k + 1], xy[2 * k + 2], xy[2 * k + 3]);
          if (d < segD) segD = d;
        }
        final d = math.max(0.0, math.min(segD, bestD) - stroke.width / 2);
        if (bestK < 0 || d > tol) return null;
        return SceneHit(tag.withPoint(p.pointIndexOf(bestK)), p, d);
      case SPath(:final cmds, :final fill, :final stroke):
        final polys = PathGeometry.flatten(cmds, tolerance: 0.5);
        if (fill != null && PathGeometry.containsPoint(polys, x, y)) return SceneHit(tag, p, 0);
        var segD = double.infinity;
        for (final (poly, closed) in polys) {
          final n = poly.length ~/ 2;
          for (var k = 0; k + 1 < n; k++) {
            final d = PathGeometry.segmentDistance(x, y, poly[2 * k], poly[2 * k + 1], poly[2 * k + 2], poly[2 * k + 3]);
            if (d < segD) segD = d;
          }
          if (closed && n > 1) {
            final d = PathGeometry.segmentDistance(x, y, poly[2 * n - 2], poly[2 * n - 1], poly[0], poly[1]);
            if (d < segD) segD = d;
          }
        }
        final d = math.max(0.0, segD - (stroke?.width ?? 0) / 2);
        return d <= tol ? SceneHit(tag, p, d) : null;
      case SClip() || SGroup():
        return null;
    }
  }
}

ChartRect _boundsOf(Float64List xy, double pad) {
  if (xy.length < 2) return ChartRect.zero;
  var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
  for (var i = 0; i + 1 < xy.length; i += 2) {
    final x = xy[i], y = xy[i + 1];
    if (x < l) l = x;
    if (x > r) r = x;
    if (y < t) t = y;
    if (y > b) b = y;
  }
  return ChartRect.fromLTRB(l - pad, t - pad, r + pad, b + pad);
}

/// Rounds to 2 decimals for stable JSON (integral values become ints).
num sceneNum(double v) {
  if (v.isNaN || v.isInfinite) return 0;
  final r = (v * 100).roundToDouble() / 100;
  if (r == r.truncateToDouble() && r.abs() < 1e15) return r.toInt();
  return r;
}

/// `#AARRGGBB` for an ARGB int.
String argbHex(int argb) => '#${(argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// Color helpers on ARGB ints.
abstract final class Argb {
  /// Alpha 0..255.
  static int alpha(int c) => (c >> 24) & 0xFF;

  /// Red 0..255.
  static int red(int c) => (c >> 16) & 0xFF;

  /// Green 0..255.
  static int green(int c) => (c >> 8) & 0xFF;

  /// Blue 0..255.
  static int blue(int c) => c & 0xFF;

  /// Builds an ARGB int.
  static int of(int a, int r, int g, int b) =>
      ((a.clamp(0, 255) << 24) | (r.clamp(0, 255) << 16) | (g.clamp(0, 255) << 8) | b.clamp(0, 255)) &
      0xFFFFFFFF;

  /// [c] with its alpha multiplied by [opacity] (0..1).
  static int withOpacity(int c, double opacity) =>
      of((alpha(c) * opacity.clamp(0.0, 1.0)).round(), red(c), green(c), blue(c));

  /// Linear mix of [a] and [b] (t = 0 → a).
  static int lerp(int a, int b, double t) {
    final tt = t.clamp(0.0, 1.0);
    int ch(int x, int y) => (x + (y - x) * tt).round();
    return of(ch(alpha(a), alpha(b)), ch(red(a), red(b)), ch(green(a), green(b)), ch(blue(a), blue(b)));
  }

  /// `#RRGGBB` of [c] (alpha dropped).
  static String rgbHex(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Opacity 0..1 of [c].
  static double opacity(int c) => alpha(c) / 255.0;
}
