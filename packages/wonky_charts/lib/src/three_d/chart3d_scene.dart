import 'dart:math' as math;

import '../layout/text_measurer.dart';
import '../scene/geometry.dart';
import '../scene/path.dart';
import '../scene/scene.dart';
import 'chart3d_camera.dart';
import 'chart3d_mesh.dart';
import 'chart3d_model.dart';
import 'chart3d_shading.dart';
import 'chart3d_view.dart';
import 'vec3.dart';

/// Result of [Chart3DScene.pick].
final class Chart3DHit {
  /// Creates a hit.
  const Chart3DHit(this.tag, this.distance, this.point);

  /// Tag of the hit item (point-level).
  final SceneTag tag;

  /// Distance from the eye along the ray.
  final double distance;

  /// World point hit.
  final Vec3 point;
}

/// A 3D chart ready to draw (08 §23): the [model], its fitted [camera], the meshed [chunks]
/// and the [shading]. Renderer-independent: [renderGeometry] gives the software rendering as
/// scene primitives (painter's algorithm, used on the web, in exports and as the fallback),
/// GPU backends mesh [chunks] themselves, and [pick] ray-casts for both.
final class Chart3DScene {
  /// Fits [model] into [viewport] (scene px).
  ///
  /// With [fitViews] the zoom is the smallest of the fits of the model's view and those views
  /// (Slides 08 §10.3: camera animations fit once for the union of their start and end views).
  Chart3DScene(
    this.model,
    this.viewport, {
    this.hover,
    List<Chart3DView>? fitViews,
  }) : camera = Chart3DCamera.fit(
         bounds: model.bounds,
         azimuthDeg: model.azimuth,
         elevationDeg: model.elevation,
         fovDeg: model.fov,
         viewport: viewport,
         maxScale: _scaleLimit(model, viewport, fitViews),
       ),
       shading = Chart3DShading.of(model.lighting);

  static double? _scaleLimit(
    Chart3DModel model,
    ChartRect viewport,
    List<Chart3DView>? views,
  ) {
    if (views == null || views.isEmpty) return null;
    Chart3DCamera fit(double az, double el, double fov) => Chart3DCamera.fit(
      bounds: model.bounds,
      azimuthDeg: az,
      elevationDeg: el,
      fovDeg: fov,
      viewport: viewport,
    );
    // Compare fits in px per world unit at the target (tangent units depend on the field
    // of view's eye distance).
    double density(Chart3DCamera c) =>
        c.scale / math.max((c.eye - c.target).length, 1e-9);
    final current = fit(model.azimuth, model.elevation, model.fov);
    var limit = density(current);
    for (final v in views) {
      final d = density(fit(v.normalizedAzimuth, v.elevation, v.perspective));
      if (d < limit) limit = d;
    }
    return limit * (current.eye - current.target).length;
  }

  final Chart3DModel model;

  /// Rectangle the scene is fitted into.
  final ChartRect viewport;
  final Chart3DCamera camera;
  final Chart3DShading shading;

  /// The data item under the pointer (a picked tag): drawn lighter by both
  /// backends (08 §23.6). Ribbons and slabs light up as a whole series.
  final SceneTag? hover;

  /// How much a hovered item is lightened.
  static const hoverLighten = 0.28;

  /// Whether chunk [c] is the hovered item.
  bool isHovered(Chart3DChunk c) {
    final h = hover;
    if (h == null || c.item.part != Chart3DPart.data) return false;
    final t = c.effectiveTag;
    if (t == null || t.seriesKey != h.seriesKey) return false;
    if (c.item is Chart3DSlab) return true;
    return t.pointIndex == h.pointIndex;
  }

  /// The base color chunk [c] is shaded from (lighter while hovered).
  int colorOf(Chart3DChunk c) =>
      isHovered(c) ? Argb.lerp(c.color, 0xFFFFFFFF, hoverLighten) : c.color;

  /// Changes whenever the GPU meshes must be rebuilt (model or hover).
  int get meshHash => Object.hash(
    model.contentHash,
    hover == null ? null : Object.hash(hover!.seriesKey, hover!.pointIndex),
  );

  /// Meshed items.
  late final List<Chart3DChunk> chunks = Chart3DMesher.meshAll(model.items);

  /// World direction to the key light.
  late final Vec3 lightDirection = camera.viewToWorld(
    Chart3DShading.keyLightView,
  );

  /// World direction to the light that casts floor shadows (steeper than the key light so
  /// shadows stay close to their objects).
  late final Vec3 shadowLightDirection =
      (lightDirection + Vec3.unitY * 1.6).normalized;

  /// Gridlines.
  Iterable<Chart3DLine> get lines => model.items.whereType<Chart3DLine>();

  // ---------------------------------------------------------------------------
  // Picking.

  /// The data item under screen point ([x], [y]) (scene px), by casting a ray through the
  /// meshes; null when the ray misses every data item.
  Chart3DHit? pick(double x, double y) {
    final (o, d) = camera.ray(x, y);
    Chart3DHit? best;
    for (final c in chunks) {
      if (c.item.part != Chart3DPart.data) continue;
      final tag = c.effectiveTag;
      if (tag == null) continue;
      for (final f in c.faces) {
        final tris = f.triangleIndices;
        for (var i = 0; i + 2 < tris.length; i += 3) {
          final t = _intersect(
            o,
            d,
            f.points[tris[i]],
            f.points[tris[i + 1]],
            f.points[tris[i + 2]],
          );
          if (t != null && (best == null || t < best.distance)) {
            best = Chart3DHit(tag, t, o + d * t);
          }
        }
      }
    }
    return best;
  }

  /// Möller–Trumbore ray/triangle intersection (both sides); distance or null.
  static double? _intersect(Vec3 o, Vec3 d, Vec3 a, Vec3 b, Vec3 c) {
    const eps = 1e-12;
    final e1 = b - a, e2 = c - a;
    final p = d.cross(e2);
    final det = e1.dot(p);
    if (det.abs() < eps) return null;
    final inv = 1 / det;
    final s = o - a;
    final u = s.dot(p) * inv;
    if (u < -1e-9 || u > 1 + 1e-9) return null;
    final q = s.cross(e1);
    final v = d.dot(q) * inv;
    if (v < -1e-9 || u + v > 1 + 1e-9) return null;
    final t = e2.dot(q) * inv;
    return t > 1e-9 ? t : null;
  }

  // ---------------------------------------------------------------------------
  // Software rendering.

  /// Whether [f] faces the eye.
  bool _facing(Chart3DFace f) {
    if (f.doubleSided) return true;
    return (camera.eye - f.centroid).dot(f.normal) > 1e-9;
  }

  /// The software rendering of floor, walls, gridlines, shadows and data (painter's
  /// algorithm: back to front), without labels.
  List<ScenePrimitive> renderGeometry() {
    final out = <ScenePrimitive>[];
    double dist(Chart3DChunk c) => camera.distanceTo(c.center);
    final frame =
        chunks
            .where(
              (c) =>
                  c.item.part == Chart3DPart.wall ||
                  c.item.part == Chart3DPart.floor,
            )
            .toList()
          ..sort((a, b) {
            if (a.item.part != b.item.part) {
              return a.item.part == Chart3DPart.wall ? -1 : 1;
            }
            return dist(b).compareTo(dist(a));
          });
    for (final c in frame) {
      _paintChunk(c, out);
    }
    for (final l in lines) {
      final a = camera.project(l.a), b = camera.project(l.b);
      out.add(
        SPath(
          [PMoveTo(a.x, a.y), PLineTo(b.x, b.y)],
          stroke: SStroke(l.color, width: l.width),
          tag: const SceneTag(SceneRole.gridline),
        ),
      );
    }
    final data = chunks.where((c) => c.item.part == Chart3DPart.data).toList();
    sortBackToFront(data);
    _paintShadows(data, out);
    for (final c in data) {
      _paintChunk(c, out);
    }
    return out;
  }

  /// Sorts [data] chunks back to front: by layer, then by an axis-aligned plane separating
  /// their bounds (the chunk on the eye's side of it is drawn later), else by distance.
  void sortBackToFront(List<Chart3DChunk> data) {
    final boxes = {for (final c in data) c: _bounds(c)};
    final eye = camera.eye;
    int cmp(Chart3DChunk a, Chart3DChunk b) {
      if (a.layer != b.layer) return a.layer.compareTo(b.layer);
      final ba = boxes[a]!, bb = boxes[b]!;
      // The axis with the widest gap between the boxes decides.
      var best = -1;
      var gap = -double.infinity;
      var aFirst = true;
      for (var axis = 0; axis < 3; axis++) {
        final aMin = _c(ba.min, axis), aMax = _c(ba.max, axis);
        final bMin = _c(bb.min, axis), bMax = _c(bb.max, axis);
        final e = _c(eye, axis);
        if (aMax <= bMin + 1e-9 && bMin - aMax > gap) {
          gap = bMin - aMax;
          best = axis;
          aFirst = e > bMin;
        } else if (bMax <= aMin + 1e-9 && aMin - bMax > gap) {
          gap = aMin - bMax;
          best = axis;
          aFirst = e < aMin;
        }
      }
      if (best >= 0) return aFirst ? -1 : 1;
      return camera.distanceTo(b.center).compareTo(camera.distanceTo(a.center));
    }

    // Insertion sort: stable and robust with a comparator that is only a partial order.
    for (var i = 1; i < data.length; i++) {
      final x = data[i];
      var j = i - 1;
      while (j >= 0 && cmp(data[j], x) > 0) {
        data[j + 1] = data[j];
        j--;
      }
      data[j + 1] = x;
    }
  }

  static double _c(Vec3 v, int axis) => switch (axis) {
    0 => v.x,
    1 => v.y,
    _ => v.z,
  };

  static Aabb3 _bounds(Chart3DChunk c) =>
      Aabb3.of([for (final f in c.faces) ...f.points]);

  void _paintChunk(Chart3DChunk c, List<ScenePrimitive> out) {
    final base = colorOf(c);
    final edgeColor = Argb.lerp(base, 0xFF000000, shading.edgeDarken);
    final tag = c.effectiveTag;
    final isData = c.item.part == Chart3DPart.data;
    for (final f in c.faces) {
      if (!_facing(f)) continue;
      var n = f.normal;
      final toEye = (camera.eye - f.centroid).normalized;
      final flip = f.doubleSided && n.dot(toEye) < 0;
      if (flip) n = -n;
      final pts = [for (final p in f.points) camera.project(p)];
      // Vertex colors.
      final colors = <int>[];
      for (var i = 0; i < f.points.length; i++) {
        final p = f.points[i];
        var vn = f.normals == null ? n : f.normalAt(i);
        if (flip) vn = -vn;
        final v = (camera.eye - p).normalized;
        final contact = isData && n.y.abs() < 0.5
            ? 1 - ((p.y - model.floorY) / _contactHeight).clamp(0.0, 1.0)
            : 0.0;
        colors.add(
          isData
              ? shading.shade(
                  base,
                  vn,
                  lightDirection,
                  v,
                  contactFactor: contact,
                )
              : shading.shadeFrame(base, vn, lightDirection),
        );
      }
      final avg = _average(colors);
      SGradient? gradient;
      if (shading.gradients && f.normals == null && colors.length > 2) {
        var hi = 0, lo = 0;
        for (var i = 1; i < colors.length; i++) {
          if (Chart3DShading.luma(colors[i]) >
              Chart3DShading.luma(colors[hi])) {
            hi = i;
          }
          if (Chart3DShading.luma(colors[i]) <
              Chart3DShading.luma(colors[lo])) {
            lo = i;
          }
        }
        final d =
            Chart3DShading.luma(colors[hi]) - Chart3DShading.luma(colors[lo]);
        final dx = pts[hi].x - pts[lo].x, dy = pts[hi].y - pts[lo].y;
        if (d > 2 && dx * dx + dy * dy > 4) {
          gradient = SGradient(
            pts[hi].x,
            pts[hi].y,
            pts[lo].x,
            pts[lo].y,
            colors[hi],
            colors[lo],
          );
        }
      }
      final cmds = <PathCmd>[PMoveTo(pts[0].x, pts[0].y)];
      for (var i = 1; i < pts.length; i++) {
        cmds.add(PLineTo(pts[i].x, pts[i].y));
      }
      cmds.add(const PClose());
      out.add(
        SPath(
          cmds,
          fill: avg,
          gradient: gradient,
          // An outline hides anti-aliasing seams between adjacent faces; edges get a
          // darker one.
          stroke: f.edge
              ? SStroke(
                  Argb.lerp(avg, 0xFF000000, shading.edgeDarken),
                  width: 0.8,
                  join: SStrokeJoin.round,
                )
              : SStroke(avg, width: 0.7, join: SStrokeJoin.round),
          tag: tag,
        ),
      );
      final outline = f.outline;
      if (outline != null && !f.edge) {
        for (final (a3, b3) in outline) {
          final a = camera.project(a3), b = camera.project(b3);
          out.add(
            SPath([
              PMoveTo(a.x, a.y),
              PLineTo(b.x, b.y),
            ], stroke: SStroke(edgeColor, width: 0.8, cap: SStrokeCap.round)),
          );
        }
      }
    }
  }

  /// Height (world units) over which vertical faces darken toward the floor.
  double get _contactHeight =>
      math.max(1e-6, (model.bounds.max.y - model.bounds.min.y) * 0.18);

  static int _average(List<int> colors) {
    var a = 0, r = 0, g = 0, b = 0;
    for (final c in colors) {
      a += Argb.alpha(c);
      r += Argb.red(c);
      g += Argb.green(c);
      b += Argb.blue(c);
    }
    final n = colors.length;
    return Argb.of(
      (a / n).round(),
      (r / n).round(),
      (g / n).round(),
      (b / n).round(),
    );
  }

  /// Soft shadows of the data items on the floor plane: each item's points projected along
  /// [shadowLightDirection], as a few stacked translucent hulls.
  void _paintShadows(List<Chart3DChunk> data, List<ScenePrimitive> out) {
    if (shading.shadowAlpha <= 0) return;
    final l = shadowLightDirection;
    if (l.y < 0.2) return;
    final floor = model.floorY;
    final clip = _floorRect();
    // One hull per item (pies: one for the whole pie).
    final byItem = <Object, List<Vec3>>{};
    for (final c in data) {
      final item = c.item;
      if (!(item is Chart3DWedge || (item is Chart3DBox && item.axis == 1))) {
        continue;
      }
      final key = model.kind == Chart3DKind.pie ? 'pie' : item.key;
      final pts = byItem.putIfAbsent(key, () => []);
      for (final f in c.faces) {
        for (final p in f.points) {
          final h = p.y - floor;
          pts.add(Vec3(p.x - l.x * h / l.y, floor, p.z - l.z * h / l.y));
        }
      }
    }
    final color = model.dark ? 0xFF000000 : 0xFF1F2937;
    const layers = [(1.0, 0.45), (1.04, 0.3), (1.09, 0.25)];
    // Doughnuts keep their hole free of shadow.
    (Vec3, double)? hole;
    for (final c in data) {
      final w = c.item;
      if (w is Chart3DWedge && w.innerRadius > 0) {
        hole = (w.center, w.innerRadius * 0.9);
        break;
      }
    }
    for (final pts in byItem.values) {
      var hull = _hullXZ(pts);
      if (clip != null) hull = _clipXZ(hull, clip);
      if (hull.length < 3) continue;
      final cx = hull.fold(0.0, (s, p) => s + p.x) / hull.length;
      final cz = hull.fold(0.0, (s, p) => s + p.z) / hull.length;
      for (final (scale, share) in layers) {
        final cmds = <PathCmd>[];
        for (var i = 0; i < hull.length; i++) {
          final p = hull[i];
          final q = camera.project(
            Vec3(cx + (p.x - cx) * scale, floor, cz + (p.z - cz) * scale),
          );
          cmds.add(i == 0 ? PMoveTo(q.x, q.y) : PLineTo(q.x, q.y));
        }
        cmds.add(const PClose());
        if (hole != null) {
          const k = 48;
          for (var i = 0; i < k; i++) {
            final a = 2 * math.pi * i / k;
            final r = hole.$2 / scale;
            final q = camera.project(
              Vec3(
                hole.$1.x + math.sin(a) * r,
                floor,
                hole.$1.z - math.cos(a) * r,
              ),
            );
            cmds.add(i == 0 ? PMoveTo(q.x, q.y) : PLineTo(q.x, q.y));
          }
          cmds.add(const PClose());
        }
        out.add(
          SPath(
            cmds,
            fill: Argb.withOpacity(color, shading.shadowAlpha * share),
            evenOdd: hole != null,
          ),
        );
      }
    }
  }

  /// The floor's top rectangle in x/z, or null without a floor.
  (double, double, double, double)? _floorRect() {
    for (final i in model.items) {
      if (i is Chart3DBox && i.part == Chart3DPart.floor) {
        return (i.min.x, i.min.z, i.max.x, i.max.z);
      }
    }
    return null;
  }

  /// Convex hull of [pts] in the x/z plane (monotone chain).
  static List<Vec3> _hullXZ(List<Vec3> pts) {
    if (pts.length < 3) return pts;
    final s = [...pts]
      ..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.z.compareTo(b.z));
    double cross(Vec3 o, Vec3 a, Vec3 b) =>
        (a.x - o.x) * (b.z - o.z) - (a.z - o.z) * (b.x - o.x);
    final lower = <Vec3>[];
    for (final p in s) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    final upper = <Vec3>[];
    for (final p in s.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    return [...lower.take(lower.length - 1), ...upper.take(upper.length - 1)];
  }

  /// [poly] clipped to the x/z rectangle [r] (Sutherland–Hodgman).
  static List<Vec3> _clipXZ(
    List<Vec3> poly,
    (double, double, double, double) r,
  ) {
    final (x0, z0, x1, z1) = r;
    var out = poly;
    for (final edge in [0, 1, 2, 3]) {
      if (out.isEmpty) break;
      bool inside(Vec3 p) => switch (edge) {
        0 => p.x >= x0,
        1 => p.x <= x1,
        2 => p.z >= z0,
        _ => p.z <= z1,
      };
      Vec3 cut(Vec3 a, Vec3 b) {
        final t = switch (edge) {
          0 => (x0 - a.x) / (b.x - a.x),
          1 => (x1 - a.x) / (b.x - a.x),
          2 => (z0 - a.z) / (b.z - a.z),
          _ => (z1 - a.z) / (b.z - a.z),
        };
        return a.lerp(b, t);
      }

      final input = out;
      out = [];
      for (var i = 0; i < input.length; i++) {
        final a = input[i], b = input[(i + 1) % input.length];
        final ia = inside(a), ib = inside(b);
        if (ia) out.add(a);
        if (ia != ib) out.add(cut(a, b));
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Labels.

  /// The labels as text primitives placed next to their projected anchors.
  List<ScenePrimitive> renderLabels(TextMeasurer measurer) {
    final out = <ScenePrimitive>[];
    for (final l in model.labels) {
      if (l.text.isEmpty) continue;
      final m = measurer.measure(l.text, l.style);
      final a = camera.project(l.anchor);
      var x = a.x, y = a.y;
      var anchor = TextAnchor.center;
      final o = l.outward;
      if (o != null) {
        final b = camera.project(l.anchor + o.normalized * _labelProbe);
        var dx = b.x - a.x, dy = b.y - a.y;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 1e-9) {
          dx /= len;
          dy /= len;
          x += dx * l.gap;
          y += dy * l.gap;
          anchor = _anchorFor(dx, dy);
        }
      }
      out.add(
        SText(
          l.text,
          ChartPoint(x, y),
          l.style,
          anchor: anchor,
          width: m.width,
          height: m.height,
          ascent: m.ascent,
          tag: l.tag,
        ),
      );
    }
    return out;
  }

  double get _labelProbe =>
      math.max(1e-6, (model.bounds.max - model.bounds.min).length * 0.05);

  /// The text anchor of a label moved in screen direction ([dx], [dy]).
  static TextAnchor _anchorFor(double dx, double dy) {
    const k = 0.38; // ~22°
    if (dx.abs() < k) {
      return dy > 0 ? TextAnchor.topCenter : TextAnchor.bottomCenter;
    }
    if (dy.abs() < k) {
      return dx > 0 ? TextAnchor.middleLeft : TextAnchor.middleRight;
    }
    if (dy > 0) return dx > 0 ? TextAnchor.topLeft : TextAnchor.topRight;
    return dx > 0 ? TextAnchor.bottomLeft : TextAnchor.bottomRight;
  }

  /// Screen bounds of the projected model bounds (for layout tests).
  ChartRect get projectedBounds {
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    for (final p in model.bounds.corners) {
      final q = camera.project(p);
      l = math.min(l, q.x);
      r = math.max(r, q.x);
      t = math.min(t, q.y);
      b = math.max(b, q.y);
    }
    return ChartRect.fromLTRB(l, t, r, b);
  }
}
