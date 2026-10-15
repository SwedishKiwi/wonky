import 'dart:math' as math;

import '../scene/scene.dart';
import '../spec/three_d_options.dart';
import 'chart3d_model.dart';
import 'vec3.dart';

/// One planar polygon of a meshed 3D item.
final class Chart3DFace {
  /// Creates a face. [points] wind counter-clockwise seen from outside (the side [normal]
  /// points to).
  const Chart3DFace(
    this.points,
    this.normal, {
    this.normals,
    this.triangles,
    this.edge = true,
    this.doubleSided = false,
    this.outline,
  });

  final List<Vec3> points;

  /// Outward unit normal.
  final Vec3 normal;

  /// Per-vertex normals of curved surfaces (smooth shading); null = [normal].
  final List<Vec3>? normals;

  /// Triangle indices into [points] (null = a fan from point 0).
  final List<int>? triangles;

  /// Whether the software renderer outlines the polygon with a darker edge.
  final bool edge;

  /// Visible from both sides (floor and wall panels).
  final bool doubleSided;

  /// Edges outlined instead of the whole polygon (pairs of points), when [edge] is false.
  final List<(Vec3, Vec3)>? outline;

  /// Centroid of the points.
  Vec3 get centroid {
    var x = 0.0, y = 0.0, z = 0.0;
    for (final p in points) {
      x += p.x;
      y += p.y;
      z += p.z;
    }
    final n = points.length;
    return Vec3(x / n, y / n, z / n);
  }

  /// Triangles as index triples (fan when [triangles] is null).
  List<int> get triangleIndices {
    final t = triangles;
    if (t != null) return t;
    return [
      for (var i = 1; i + 1 < points.length; i++) ...[0, i, i + 1],
    ];
  }

  /// Normal of vertex [i].
  Vec3 normalAt(int i) => normals?[i] ?? normal;
}

/// A convex-ish group of faces the software renderer sorts as a unit (painter's algorithm).
final class Chart3DChunk {
  /// Creates a chunk.
  const Chart3DChunk(
    this.item,
    this.faces,
    this.center, {
    this.layer = 10,
    this.tag,
  });

  /// The item the faces come from (color, part).
  final Chart3DItem item;
  final List<Chart3DFace> faces;

  /// Sorting center.
  final Vec3 center;

  /// Sorting layer inside its part (lower first): pie bottoms 0, sides 10, tops 20.
  final int layer;

  /// Tag of the chunk (point-level for slabs); defaults to the item's.
  final SceneTag? tag;

  /// Base color.
  int get color => item.color;

  /// The chunk's tag.
  SceneTag? get effectiveTag => tag ?? item.tag;
}

/// Newell normal of a polygon.
Vec3 polygonNormal(List<Vec3> pts) {
  var nx = 0.0, ny = 0.0, nz = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    nx += (a.y - b.y) * (a.z + b.z);
    ny += (a.z - b.z) * (a.x + b.x);
    nz += (a.x - b.x) * (a.y + b.y);
  }
  return Vec3(nx, ny, nz).normalized;
}

/// Turns 3D chart items into faces (08 §23.3). The same faces feed the software renderer and
/// the GPU meshes.
abstract final class Chart3DMesher {
  /// Segments of a full circle.
  static const int circleSegments = 96;

  /// Segments of a cylinder or cone.
  static const int cylinderSegments = 40;

  /// Chunks of every item.
  static List<Chart3DChunk> meshAll(Iterable<Chart3DItem> items) => [
    for (final i in items) ...mesh(i),
  ];

  /// Chunks of [item] (gridlines have none: renderers draw them as lines).
  static List<Chart3DChunk> mesh(Chart3DItem item) => switch (item) {
    Chart3DBox() => _box(item),
    Chart3DWedge() => _wedge(item),
    Chart3DSlab() => _slab(item),
    Chart3DPatch() => _patch(item),
    Chart3DLine() => const [],
  };

  /// A surface patch: two double-sided triangles (seen from below the
  /// software renderer flips their normal; GPU materials are double-sided).
  static List<Chart3DChunk> _patch(Chart3DPatch p) {
    final c = p.corners;
    if (c.length != 4 || c.any((v) => !v.x.isFinite || !v.y.isFinite)) {
      return const [];
    }
    final faces = <Chart3DFace>[];
    for (final tri in [
      [c[0], c[1], c[2]],
      [c[0], c[2], c[3]],
    ]) {
      final n = polygonNormal(tri);
      if (!n.x.isFinite || n.length < 1e-9) continue;
      faces.add(Chart3DFace(tri, n, doubleSided: true));
    }
    if (faces.isEmpty) return const [];
    return [Chart3DChunk(p, faces, _centroid(c))];
  }

  /// [pts] as a face pointing away from [inside].
  static Chart3DFace _outward(
    List<Vec3> pts,
    Vec3 inside, {
    List<Vec3>? normals,
    bool edge = true,
    List<(Vec3, Vec3)>? outline,
  }) {
    var n = polygonNormal(pts);
    final c = _centroid(pts);
    if ((c - inside).dot(n) < 0) {
      pts = pts.reversed.toList();
      normals = normals?.reversed.toList();
      n = -n;
    }
    return Chart3DFace(pts, n, normals: normals, edge: edge, outline: outline);
  }

  static Vec3 _centroid(List<Vec3> pts) {
    var x = 0.0, y = 0.0, z = 0.0;
    for (final p in pts) {
      x += p.x;
      y += p.y;
      z += p.z;
    }
    return Vec3(x / pts.length, y / pts.length, z / pts.length);
  }

  // ---------------------------------------------------------------------------
  // Boxes, cylinders, cones, pyramids.

  static List<Chart3DChunk> _box(Chart3DBox b) {
    final lo = b.min, hi = b.max;
    if (!(hi.x - lo.x).isFinite ||
        !(hi.y - lo.y).isFinite ||
        !(hi.z - lo.z).isFinite) {
      return const [];
    }
    // Local frame: a = along the axis, p and q across it.
    final ax = b.axis == 0;
    final a0 = ax ? lo.x : lo.y, a1 = ax ? hi.x : hi.y;
    final p0 = ax ? lo.y : lo.x, p1 = ax ? hi.y : hi.x;
    final q0 = lo.z, q1 = hi.z;
    Vec3 w(double a, double p, double q) => ax ? Vec3(a, p, q) : Vec3(p, a, q);
    final pc = (p0 + p1) / 2, qc = (q0 + q1) / 2;
    final rp = (p1 - p0) / 2, rq = (q1 - q0) / 2;
    final base = b.tipAtMax ? a0 : a1, top = b.tipAtMax ? a1 : a0;
    final center = b.center;
    if ((a1 - a0).abs() < 1e-9) {
      // Flat (zero value): one cap so the item stays visible and pickable.
      return [
        Chart3DChunk(b, [
          _outward([
            w(base, p0, q0),
            w(base, p1, q0),
            w(base, p1, q1),
            w(base, p0, q1),
          ], w(base - (b.tipAtMax ? 1 : -1), pc, qc)),
        ], center),
      ];
    }
    final (
      int n,
      double rot,
      double factor,
      double topScale,
      bool smooth,
    ) = switch (b.shape) {
      Chart3DShape.box => (4, math.pi / 4, math.sqrt2, 1.0, false),
      Chart3DShape.pyramid => (4, math.pi / 4, math.sqrt2, 0.0, false),
      Chart3DShape.cylinder => (cylinderSegments, 0.0, 1.0, 1.0, true),
      Chart3DShape.cone => (cylinderSegments, 0.0, 1.0, 0.0, true),
    };
    Vec3 ring(int k, double a, double scale) {
      final t = rot + 2 * math.pi * k / n;
      return w(
        a,
        pc + math.cos(t) * rp * factor * scale,
        qc + math.sin(t) * rq * factor * scale,
      );
    }

    final dirSign = b.tipAtMax ? 1.0 : -1.0;
    final axisDir = ax ? Vec3(dirSign, 0, 0) : Vec3(0, dirSign, 0);
    final height = (top - base).abs();
    Vec3 radial(int k) {
      final t = rot + 2 * math.pi * k / n;
      final rpN = rp == 0 ? 0.0 : math.cos(t) / rp;
      final rqN = rq == 0 ? 0.0 : math.sin(t) / rq;
      final r = (ax ? Vec3(0, rpN, rqN) : Vec3(rpN, 0, rqN)).normalized;
      if (topScale > 0) return r;
      // Cone: tilt toward the axis by the slope.
      final rr = math.max(rp, rq);
      return (r * height + axisDir * rr).normalized;
    }

    final faces = <Chart3DFace>[];
    final bottomRing = [for (var k = 0; k < n; k++) ring(k, base, 1)];
    final topRing = topScale > 0
        ? [for (var k = 0; k < n; k++) ring(k, top, topScale)]
        : null;
    final tip = w(top, pc, qc);
    for (var k = 0; k < n; k++) {
      final k1 = (k + 1) % n;
      final pts = topRing == null
          ? [bottomRing[k], bottomRing[k1], tip]
          : [bottomRing[k], bottomRing[k1], topRing[k1], topRing[k]];
      final normals = smooth
          ? (topRing == null
                ? [
                    radial(k),
                    radial(k1),
                    ((radial(k) + radial(k1)) * 0.5).normalized,
                  ]
                : [radial(k), radial(k1), radial(k1), radial(k)])
          : null;
      faces.add(_outward(pts, center, normals: normals, edge: !smooth));
    }
    // Caps (curved shapes outline their caps only).
    faces.add(_outward(bottomRing, center));
    if (topRing != null) faces.add(_outward(topRing, center));
    return [Chart3DChunk(b, faces, center)];
  }

  // ---------------------------------------------------------------------------
  // Pie wedges.

  static List<Chart3DChunk> _wedge(Chart3DWedge w) {
    if (!(w.sweep > 1e-6) || !(w.radius > 0)) return const [];
    final c = w.shiftedCenter;
    final y0 = c.y, y1 = c.y + w.height;
    final full = w.sweep >= 2 * math.pi - 1e-6;
    final n = math.max(2, (w.sweep / (2 * math.pi) * circleSegments).ceil());
    final angles = [for (var k = 0; k <= n; k++) w.start + w.sweep * k / n];
    Vec3 at(double a, double r, double y) => Chart3DWedge.polar(c, a, r, y);
    final hollow = w.innerRadius > 1e-9;
    final chunks = <Chart3DChunk>[];

    // Top and bottom.
    Chart3DFace cap(double y, bool up) {
      List<Vec3> pts;
      List<int>? tris;
      if (hollow) {
        pts = [
          for (final a in angles) at(a, w.radius, y),
          for (final a in angles.reversed) at(a, w.innerRadius, y),
        ];
        final m = angles.length;
        tris = [
          for (var k = 0; k + 1 < m; k++) ...[
            k,
            k + 1,
            2 * m - 2 - k,
            k,
            2 * m - 2 - k,
            2 * m - 1 - k,
          ],
        ];
      } else if (full) {
        pts = [for (final a in angles.take(n)) at(a, w.radius, y)];
      } else {
        pts = [Vec3(c.x, y, c.z), for (final a in angles) at(a, w.radius, y)];
      }
      // Seen from above, increasing angles run clockwise; flip for the top face.
      final normal = up ? Vec3.unitY : -Vec3.unitY;
      final ordered = up ? pts.reversed.toList() : pts;
      final orderedTris = tris == null
          ? null
          : (up ? [for (final i in tris) pts.length - 1 - i] : tris);
      return Chart3DFace(ordered, normal, triangles: orderedTris);
    }

    final topTag = w.tag;
    chunks.add(Chart3DChunk(w, [cap(y0, false)], Vec3(c.x, y0, c.z), layer: 0));
    // Rims and sides in sub-chunks for sorting.
    const perChunk = 6;
    for (var k0 = 0; k0 < n; k0 += perChunk) {
      final k1 = math.min(n, k0 + perChunk);
      final faces = <Chart3DFace>[];
      for (var k = k0; k < k1; k++) {
        final a = angles[k], b = angles[k + 1];
        final na = Chart3DWedge.polar(Vec3.zero, a, 1, 0);
        final nb = Chart3DWedge.polar(Vec3.zero, b, 1, 0);
        faces.add(
          Chart3DFace(
            [
              at(a, w.radius, y0),
              at(a, w.radius, y1),
              at(b, w.radius, y1),
              at(b, w.radius, y0),
            ],
            ((na + nb) * 0.5).normalized,
            normals: [na, na, nb, nb],
            edge: false,
          ),
        );
        if (hollow) {
          faces.add(
            Chart3DFace(
              [
                at(a, w.innerRadius, y0),
                at(b, w.innerRadius, y0),
                at(b, w.innerRadius, y1),
                at(a, w.innerRadius, y1),
              ],
              -((na + nb) * 0.5).normalized,
              normals: [-na, -nb, -nb, -na],
              edge: false,
            ),
          );
        }
      }
      final aMid = angles[(k0 + k1) ~/ 2];
      final rMid = hollow ? (w.radius + w.innerRadius) / 2 : w.radius * 0.75;
      final sideCenter = at(aMid, rMid, (y0 + y1) / 2);
      if (!full && k0 == 0) {
        faces.add(_side(w, c, angles.first, y0, y1));
      }
      if (!full && k1 == n) {
        faces.add(_side(w, c, angles.last, y0, y1));
      }
      chunks.add(Chart3DChunk(w, faces, sideCenter, tag: topTag));
    }
    chunks.add(
      Chart3DChunk(
        w,
        [cap(y1, true)],
        at(w.mid, hollow ? (w.radius + w.innerRadius) / 2 : w.radius / 2, y1),
        layer: 20,
      ),
    );
    return chunks;
  }

  static Chart3DFace _side(
    Chart3DWedge w,
    Vec3 c,
    double a,
    double y0,
    double y1,
  ) {
    final r0 = w.innerRadius;
    final pts = [
      Chart3DWedge.polar(c, a, r0, y0),
      Chart3DWedge.polar(c, a, w.radius, y0),
      Chart3DWedge.polar(c, a, w.radius, y1),
      Chart3DWedge.polar(c, a, r0, y1),
    ];
    // The inside of the wedge is toward its middle angle.
    final into = Chart3DWedge.polar(
      c,
      w.mid,
      (w.radius + r0) / 2,
      (y0 + y1) / 2,
    );
    return _outward(pts, into);
  }

  // ---------------------------------------------------------------------------
  // Area slabs and line ribbons.

  static List<Chart3DChunk> _slab(Chart3DSlab s) {
    final chunks = <Chart3DChunk>[];
    final n = s.xs.length;
    var i = 0;
    while (i < n) {
      if (s.tops[i].isNaN || s.bottoms[i].isNaN) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < n && !s.tops[j + 1].isNaN && !s.bottoms[j + 1].isNaN) {
        j++;
      }
      _run(s, i, j, chunks);
      i = j + 1;
    }
    return chunks;
  }

  /// Chunks of the run of valid points [i0]..[i1]: one chunk per half segment, so each chunk
  /// maps to the nearest domain point.
  static void _run(Chart3DSlab s, int i0, int i1, List<Chart3DChunk> out) {
    final z0 = s.z0, z1 = s.z1;
    // Half segments: (xa, ta, ba) → (xb, tb, bb) owned by point k.
    final pieces =
        <(double, double, double, double, double, double, int, bool, bool)>[];
    if (i0 == i1) {
      // A single point: a narrow block around it.
      final x = s.xs[i0];
      final hw = (z1 - z0).abs() * 0.5;
      pieces.add((
        x - hw,
        s.tops[i0],
        s.bottoms[i0],
        x + hw,
        s.tops[i0],
        s.bottoms[i0],
        i0,
        true,
        true,
      ));
    } else {
      for (var k = i0; k < i1; k++) {
        final xm = (s.xs[k] + s.xs[k + 1]) / 2;
        final tm = (s.tops[k] + s.tops[k + 1]) / 2;
        final bm = (s.bottoms[k] + s.bottoms[k + 1]) / 2;
        pieces.add((
          s.xs[k],
          s.tops[k],
          s.bottoms[k],
          xm,
          tm,
          bm,
          k,
          k == i0,
          false,
        ));
        pieces.add((
          xm,
          tm,
          bm,
          s.xs[k + 1],
          s.tops[k + 1],
          s.bottoms[k + 1],
          k + 1,
          false,
          k + 1 == i1,
        ));
      }
    }
    for (final (xa, ta, ba, xb, tb, bb, k, startCap, endCap) in pieces) {
      final da = ta - ba, db = tb - bb;
      if (da * db < 0) {
        // The profile crosses its base: split at the crossing.
        final f = da / (da - db);
        final xc = xa + (xb - xa) * f;
        final tc = ta + (tb - ta) * f;
        final bc = ba + (bb - ba) * f;
        _piece(s, xa, ta, ba, xc, tc, bc, k, startCap, false, z0, z1, out);
        _piece(s, xc, tc, bc, xb, tb, bb, k, false, endCap, z0, z1, out);
      } else {
        _piece(s, xa, ta, ba, xb, tb, bb, k, startCap, endCap, z0, z1, out);
      }
    }
  }

  static void _piece(
    Chart3DSlab s,
    double xa,
    double ta,
    double ba,
    double xb,
    double tb,
    double bb,
    int k,
    bool startCap,
    bool endCap,
    double z0,
    double z1,
    List<Chart3DChunk> out,
  ) {
    final hiA = math.max(ta, ba), loA = math.min(ta, ba);
    final hiB = math.max(tb, bb), loB = math.min(tb, bb);
    final center = Vec3(
      (xa + xb) / 2,
      (hiA + loA + hiB + loB) / 4,
      (z0 + z1) / 2,
    );
    Vec3 p(double x, double y, double z) => Vec3(x, y, z);
    final fa = p(xa, loA, z1), fb = p(xb, loB, z1);
    final fta = p(xa, hiA, z1), ftb = p(xb, hiB, z1);
    final ba0 = p(xa, loA, z0), bb0 = p(xb, loB, z0);
    final bta = p(xa, hiA, z0), btb = p(xb, hiB, z0);
    final faces = <Chart3DFace>[
      _outward(
        [fa, fb, ftb, fta],
        center,
        edge: false,
        outline: [(fta, ftb), (fa, fb)],
      ),
      _outward(
        [ba0, bta, btb, bb0],
        center,
        edge: false,
        outline: [(bta, btb), (ba0, bb0)],
      ),
      _outward(
        [fta, ftb, btb, bta],
        center,
        edge: false,
        outline: [(fta, ftb), (bta, btb)],
      ),
      _outward([fa, ba0, bb0, fb], center, edge: false),
      if (startCap) _outward([fa, fta, bta, ba0], center),
      if (endCap) _outward([fb, bb0, btb, ftb], center),
    ];
    out.add(
      Chart3DChunk(s, faces, center, tag: s.tag?.withPoint(s.pointIndexOf(k))),
    );
  }
}
