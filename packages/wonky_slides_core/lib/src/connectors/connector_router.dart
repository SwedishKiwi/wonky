/// Lines, arrows and connectors (02 §6.3, 03 §6.4): endpoints from the
/// line's frame or **derived** from the connected element's current frame
/// (P8: moving a shape never writes its connectors), straight / elbow /
/// curved routes, arrowheads.
library;

import 'dart:math' as math;

import 'package:wonky_sync_models/ids.dart' show Base62Uuid;

import '../geometry/path_ops.dart';
import '../geometry/shape_library.dart';
import '../model/api/kinds.dart';
import '../model/api/resolved.dart';
import '../scene/nodes/scene_nodes.dart';
import '../theme/model/common.dart';

/// A point in slide space (su).
typedef SuPoint = ({double x, double y});

/// One endpoint of `dataJson.start` / `dataJson.end`.
final class LineEndpoint {
  /// Creates an endpoint.
  const LineEndpoint(this.x, this.y, {this.elementId, this.site});

  /// Parses `{x, y, connect: {elementId, site}}` ([fx], [fy] when absent).
  factory LineEndpoint.fromJson(Object? json, double fx, double fy) {
    if (json is! Map) return LineEndpoint(fx, fy);
    final x = json['x'], y = json['y'];
    final connect = json['connect'];
    String? id, site;
    if (connect is Map) {
      final e = connect['elementId'];
      final s = connect['site'];
      if (e is String && e.isNotEmpty) id = elementIdOf(e);
      if (s is String) site = s;
      if (s is num) site = '${s.toInt()}';
    }
    return LineEndpoint(
      x is num && x.isFinite ? x.toDouble() : fx,
      y is num && y.isFinite ? y.toDouble() : fy,
      elementId: id,
      site: site,
    );
  }

  /// The element UUID of a `connect.elementId` (base-62, 02 §2.1; a
  /// dashed UUID is accepted as is).
  static String elementIdOf(String id) =>
      id.length == Base62Uuid.length && Base62Uuid.isValid(id)
      ? Base62Uuid.decode(id)
      : id.toLowerCase();

  /// Normalized position in the line's frame (0..1; may exceed for
  /// degenerate frames).
  final double x;

  /// See [x].
  final double y;

  /// The glued element, or null.
  final String? elementId;

  /// The glued site (`top`, `right`, `bottom`, `left`, `center`, index).
  final String? site;
}

/// The routing of a line.
enum LineRouting {
  straight,
  elbow,
  curved;

  /// The routing named [name] (default straight).
  static LineRouting fromName(Object? name) => switch (name) {
    'elbow' => elbow,
    'curved' => curved,
    _ => straight,
  };
}

/// The decoded `dataJson` of a `line` element.
final class LineData {
  /// Creates line data.
  const LineData({
    this.routing = LineRouting.straight,
    this.start = const LineEndpoint(0, 0),
    this.end = const LineEndpoint(1, 1),
    this.waypoints = const [],
  });

  /// Decodes `dataJson` (missing or malformed values fall back to a
  /// top-left → bottom-right straight line).
  factory LineData.fromJson(Map<String, Object?>? json) {
    final wp = <(double, double)>[];
    final raw = json?['waypoints'];
    if (raw is List) {
      for (final p in raw) {
        if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
          wp.add(((p[0] as num).toDouble(), (p[1] as num).toDouble()));
        } else if (p is Map && p['x'] is num && p['y'] is num) {
          wp.add(((p['x'] as num).toDouble(), (p['y'] as num).toDouble()));
        }
      }
    }
    return LineData(
      routing: LineRouting.fromName(json?['routing']),
      start: LineEndpoint.fromJson(json?['start'], 0, 0),
      end: LineEndpoint.fromJson(json?['end'], 1, 1),
      waypoints: List.unmodifiable(wp),
    );
  }

  final LineRouting routing;
  final LineEndpoint start;
  final LineEndpoint end;

  /// Elbow/curved adjustments (normalized in the frame).
  final List<(double, double)> waypoints;
}

/// A resolved route in slide space.
final class ConnectorRoute {
  /// Creates a route.
  const ConnectorRoute({
    required this.points,
    required this.path,
    required this.routing,
    required this.startGlued,
    required this.endGlued,
    required this.startDirection,
    required this.endDirection,
  });

  /// The polyline (straight/elbow) or the curve's end points and control
  /// points (curved: start, c1, c2, end).
  final List<SuPoint> points;

  /// The drawable path (slide space).
  final ScenePath path;

  final LineRouting routing;

  /// Whether the start is glued to an existing element.
  final bool startGlued;

  /// Whether the end is glued to an existing element.
  final bool endGlued;

  /// Unit tangent leaving the start (for the start arrowhead it is
  /// reversed).
  final SuPoint startDirection;

  /// Unit tangent arriving at the end.
  final SuPoint endDirection;

  /// The first point.
  SuPoint get start => points.first;

  /// The last point.
  SuPoint get end => points.last;

  /// The bounds of the path's control points.
  SuRect get bounds =>
      PathOps.bounds(path.commands) ?? SuRect(start.x, start.y, 0, 0);

  /// Midpoints of the polyline's inner segments (elbow segment handles,
  /// 03 §6.4).
  List<SuPoint> get segmentMidpoints => routing == LineRouting.curved
      ? const []
      : [
          for (var i = 1; i + 2 < points.length; i++)
            (
              x: (points[i].x + points[i + 1].x) / 2,
              y: (points[i].y + points[i + 1].y) / 2,
            ),
        ];

  /// Distance from ([x], [y]) to the route (hit testing).
  double distanceTo(double x, double y) =>
      PathOps.distanceToOutline(path.commands, x, y);
}

/// Resolves line endpoints and routes (`ConnectorRouter.route`).
abstract final class ConnectorRouter {
  /// Clearance of elbow routes around connected shapes (03 §6.4).
  static const clearance = 24.0;

  /// The route of line [line] (slide space). [lookup] finds a glued
  /// element by id among the drawn elements of the same slide (null =
  /// dangling: the stored point is used).
  static ConnectorRoute route(
    ResolvedElement line,
    ResolvedElement? Function(String id) lookup,
  ) {
    final data = LineData.fromJson(line.data);
    final frame = line.frame;
    SuPoint free(LineEndpoint p) {
      var nx = p.x, ny = p.y;
      if (line.flipH) nx = 1 - nx;
      if (line.flipV) ny = 1 - ny;
      return _rotate(
        frame.x + nx * frame.width,
        frame.y + ny * frame.height,
        frame,
        line.rotation,
      );
    }

    (SuPoint, SuPoint?, SuRect?) endpoint(LineEndpoint p) {
      final id = p.elementId;
      final target = id == null || id == line.id ? null : lookup(id);
      if (target == null) return (free(p), null, null);
      final (pt, dir) = sitePoint(target, p.site ?? 'center');
      return (pt, dir, rotatedBounds(target));
    }

    final (s, sDir, sBox) = endpoint(data.start);
    final (e, eDir, eBox) = endpoint(data.end);
    final wps = [for (final (x, y) in data.waypoints) free(LineEndpoint(x, y))];
    return switch (data.routing) {
      LineRouting.straight => _straight(s, e, sBox != null, eBox != null),
      LineRouting.curved => _curved(
        s,
        e,
        sDir,
        eDir,
        sBox != null,
        eBox != null,
      ),
      LineRouting.elbow => _elbow(s, e, sDir, eDir, sBox, eBox, wps),
    };
  }

  /// The slide-space position of [site] on [target] and the outward
  /// direction of that site (null for center and indexed sites without a
  /// side).
  static (SuPoint, SuPoint?) sitePoint(ResolvedElement target, String site) {
    final f = target.frame;
    final sites = sitesOf(target);
    var s = sites.firstWhere(
      (x) => x.name == site,
      orElse: () => sites.firstWhere((x) => x.name == 'center'),
    );
    var lx = s.x, ly = s.y;
    if (target.flipH) lx = f.width - lx;
    if (target.flipV) ly = f.height - ly;
    final p = _rotate(f.x + lx, f.y + ly, f, target.rotation);
    SuPoint? dir = switch (s.name) {
      'top' => (x: 0.0, y: -1.0),
      'right' => (x: 1.0, y: 0.0),
      'bottom' => (x: 0.0, y: 1.0),
      'left' => (x: -1.0, y: 0.0),
      _ => null,
    };
    if (dir != null) {
      if (target.flipH) dir = (x: -dir.x, y: dir.y);
      if (target.flipV) dir = (x: dir.x, y: -dir.y);
      final a = target.rotation * math.pi / 180;
      dir = (
        x: dir.x * math.cos(a) - dir.y * math.sin(a),
        y: dir.x * math.sin(a) + dir.y * math.cos(a),
      );
    }
    return (p, dir);
  }

  /// The connection sites of [e] (element-local su): the shape library's
  /// sites for shapes, the frame's sides and center otherwise.
  static List<ConnectionSite> sitesOf(ResolvedElement e) {
    final w = e.frame.width, h = e.frame.height;
    if (e.record.kind == ElementKind.shape) {
      return ShapeLibrary.outlineOf(e.data, w, h).sites;
    }
    return [
      ConnectionSite('top', w / 2, 0),
      ConnectionSite('right', w, h / 2),
      ConnectionSite('bottom', w / 2, h),
      ConnectionSite('left', 0, h / 2),
      ConnectionSite('center', w / 2, h / 2),
    ];
  }

  /// The slide-space sites of [e] (connector UI, snapping).
  static List<(ConnectionSite, SuPoint)> slideSites(ResolvedElement e) => [
    for (final s in sitesOf(e)) (s, sitePoint(e, s.name).$1),
  ];

  /// The axis-aligned bounds of [e]'s rotated frame.
  static SuRect rotatedBounds(ResolvedElement e) {
    final f = e.frame;
    final r = e.rotation % 360;
    if (r == 0) return f;
    final a = r * math.pi / 180;
    final c = math.cos(a).abs(), s = math.sin(a).abs();
    final w = f.width * c + f.height * s, h = f.width * s + f.height * c;
    return SuRect(f.x + f.width / 2 - w / 2, f.y + f.height / 2 - h / 2, w, h);
  }

  static SuPoint _rotate(double x, double y, SuRect f, double degrees) {
    if (degrees % 360 == 0) return (x: x, y: y);
    final a = degrees * math.pi / 180;
    final cx = f.x + f.width / 2, cy = f.y + f.height / 2;
    final dx = x - cx, dy = y - cy;
    return (
      x: cx + dx * math.cos(a) - dy * math.sin(a),
      y: cy + dx * math.sin(a) + dy * math.cos(a),
    );
  }

  static SuPoint _unit(double x, double y) {
    final l = math.sqrt(x * x + y * y);
    return l == 0 ? (x: 1, y: 0) : (x: x / l, y: y / l);
  }

  static ConnectorRoute _straight(SuPoint s, SuPoint e, bool sg, bool eg) {
    final d = _unit(e.x - s.x, e.y - s.y);
    return ConnectorRoute(
      points: [s, e],
      path: ScenePath(
        (ShapePathBuilder()
              ..moveTo(s.x, s.y)
              ..lineTo(e.x, e.y))
            .commands,
      ),
      routing: LineRouting.straight,
      startGlued: sg,
      endGlued: eg,
      startDirection: d,
      endDirection: d,
    );
  }

  static ConnectorRoute _curved(
    SuPoint s,
    SuPoint e,
    SuPoint? sDir,
    SuPoint? eDir,
    bool sg,
    bool eg,
  ) {
    final dist = math.sqrt(math.pow(e.x - s.x, 2) + math.pow(e.y - s.y, 2));
    final k = math.max(dist * 0.4, clearance);
    final dx = e.x - s.x, dy = e.y - s.y;
    final horizontal = dx.abs() >= dy.abs();
    final sd =
        sDir ??
        (horizontal
            ? (x: dx.sign == 0 ? 1.0 : dx.sign, y: 0.0)
            : (x: 0.0, y: dy.sign == 0 ? 1.0 : dy.sign));
    final ed =
        eDir ??
        (horizontal
            ? (x: dx.sign == 0 ? -1.0 : -dx.sign, y: 0.0)
            : (x: 0.0, y: dy.sign == 0 ? -1.0 : -dy.sign));
    final c1 = (x: s.x + sd.x * k, y: s.y + sd.y * k);
    final c2 = (x: e.x + ed.x * k, y: e.y + ed.y * k);
    return ConnectorRoute(
      points: [s, c1, c2, e],
      path: ScenePath(
        (ShapePathBuilder()
              ..moveTo(s.x, s.y)
              ..cubicTo(c1.x, c1.y, c2.x, c2.y, e.x, e.y))
            .commands,
      ),
      routing: LineRouting.curved,
      startGlued: sg,
      endGlued: eg,
      startDirection: _unit(c1.x - s.x, c1.y - s.y),
      endDirection: _unit(e.x - c2.x, e.y - c2.y),
    );
  }

  /// An orthogonal route avoiding both connected boxes (inflated by the
  /// clearance), the fewest bends and shortest length winning.
  static ConnectorRoute _elbow(
    SuPoint s,
    SuPoint e,
    SuPoint? sDir,
    SuPoint? eDir,
    SuRect? sBox,
    SuRect? eBox,
    List<SuPoint> waypoints,
  ) {
    SuPoint axisDir(SuPoint? d, SuPoint from, SuPoint to) {
      if (d != null) {
        return d.x.abs() >= d.y.abs()
            ? (x: d.x.sign, y: 0.0)
            : (x: 0.0, y: d.y.sign);
      }
      final dx = to.x - from.x, dy = to.y - from.y;
      if (dx.abs() >= dy.abs()) return (x: dx >= 0 ? 1.0 : -1.0, y: 0.0);
      return (x: 0.0, y: dy >= 0 ? 1.0 : -1.0);
    }

    final sd = axisDir(sDir, s, e);
    final ed = axisDir(eDir, e, s); // points away from e
    final c = clearance;
    final s1 = sBox == null ? s : (x: s.x + sd.x * c, y: s.y + sd.y * c);
    final e1 = eBox == null ? e : (x: e.x + ed.x * c, y: e.y + ed.y * c);
    final boxes = [
      if (sBox != null) _inflate(sBox, c - 1),
      if (eBox != null) _inflate(eBox, c - 1),
    ];

    List<SuPoint> route;
    if (waypoints.isNotEmpty) {
      route = _orthogonalThrough([s, s1, ...waypoints, e1, e], sd);
    } else {
      final candidates = <List<SuPoint>>[];
      final mx = (s1.x + e1.x) / 2, my = (s1.y + e1.y) / 2;
      candidates
        ..add([s1, (x: e1.x, y: s1.y), e1])
        ..add([s1, (x: s1.x, y: e1.y), e1])
        ..add([s1, (x: mx, y: s1.y), (x: mx, y: e1.y), e1])
        ..add([s1, (x: s1.x, y: my), (x: e1.x, y: my), e1]);
      if (boxes.isNotEmpty) {
        final l = boxes.map((b) => b.x).reduce(math.min) - 1;
        final r = boxes.map((b) => b.right).reduce(math.max) + 1;
        final t = boxes.map((b) => b.y).reduce(math.min) - 1;
        final bt = boxes.map((b) => b.bottom).reduce(math.max) + 1;
        for (final x in [l, r]) {
          candidates.add([s1, (x: x, y: s1.y), (x: x, y: e1.y), e1]);
        }
        for (final y in [t, bt]) {
          candidates.add([s1, (x: s1.x, y: y), (x: e1.x, y: y), e1]);
        }
        // Gaps between the two boxes.
        if (boxes.length == 2) {
          final a = boxes[0], b = boxes[1];
          final gx = a.right < b.x
              ? (a.right + b.x) / 2
              : b.right < a.x
              ? (b.right + a.x) / 2
              : null;
          final gy = a.bottom < b.y
              ? (a.bottom + b.y) / 2
              : b.bottom < a.y
              ? (b.bottom + a.y) / 2
              : null;
          if (gx != null) {
            for (final y in [t, bt]) {
              candidates.add([
                s1,
                (x: s1.x, y: y),
                (x: gx, y: y),
                (x: gx, y: e1.y),
                e1,
              ]);
              candidates.add([
                s1,
                (x: gx, y: s1.y),
                (x: gx, y: y),
                (x: e1.x, y: y),
                e1,
              ]);
            }
          }
          if (gy != null) {
            for (final x in [l, r]) {
              candidates.add([
                s1,
                (x: x, y: s1.y),
                (x: x, y: gy),
                (x: e1.x, y: gy),
                e1,
              ]);
              candidates.add([
                s1,
                (x: s1.x, y: gy),
                (x: x, y: gy),
                (x: x, y: e1.y),
                e1,
              ]);
            }
          }
        }
      }
      List<SuPoint>? best;
      var bestScore = double.infinity;
      for (final mid in candidates) {
        final full = _simplify([s, ...mid, e]);
        if (!_validStart(full, sd, sBox != null) ||
            !_validStart(full.reversed.toList(), ed, eBox != null)) {
          continue;
        }
        if (_hitsBoxes(full, boxes)) continue;
        final score = _length(full) + (full.length - 2) * c * 2;
        if (score < bestScore) {
          bestScore = score;
          best = full;
        }
      }
      route = best ?? _simplify([s, ...candidates[2], e]);
    }
    route = _simplify(route);
    if (route.length < 2) route = [s, e];
    final b = ShapePathBuilder()..moveTo(route.first.x, route.first.y);
    for (final p in route.skip(1)) {
      b.lineTo(p.x, p.y);
    }
    final n = route.length;
    return ConnectorRoute(
      points: route,
      path: b.build(),
      routing: LineRouting.elbow,
      startGlued: sBox != null,
      endGlued: eBox != null,
      startDirection: _unit(route[1].x - route[0].x, route[1].y - route[0].y),
      endDirection: _unit(
        route[n - 1].x - route[n - 2].x,
        route[n - 1].y - route[n - 2].y,
      ),
    );
  }

  /// Joins [pts] with axis-aligned segments (a corner between points that
  /// differ in both coordinates, alternating with the previous segment).
  static List<SuPoint> _orthogonalThrough(List<SuPoint> pts, SuPoint sd) {
    final out = <SuPoint>[pts.first];
    var lastHorizontal = sd.y == 0;
    for (var i = 1; i < pts.length; i++) {
      final a = out.last, b = pts[i];
      if ((a.x - b.x).abs() > 1e-6 && (a.y - b.y).abs() > 1e-6) {
        // Turn: continue the previous axis first, then switch.
        final corner = lastHorizontal ? (x: b.x, y: a.y) : (x: a.x, y: b.y);
        out.add(corner);
        lastHorizontal = !lastHorizontal;
      } else {
        lastHorizontal = (a.y - b.y).abs() <= 1e-6;
      }
      out.add(b);
    }
    return out;
  }

  static bool _validStart(List<SuPoint> r, SuPoint d, bool glued) {
    if (!glued || r.length < 2) return true;
    final dx = r[1].x - r[0].x, dy = r[1].y - r[0].y;
    // The first segment leaves along the site direction.
    return dx * d.x + dy * d.y > 0 &&
        (d.x == 0 ? dx.abs() < 1e-6 : dy.abs() < 1e-6);
  }

  static SuRect _inflate(SuRect r, double d) =>
      SuRect(r.x - d, r.y - d, r.width + 2 * d, r.height + 2 * d);

  static double _length(List<SuPoint> r) {
    var l = 0.0;
    for (var i = 1; i < r.length; i++) {
      l += (r[i].x - r[i - 1].x).abs() + (r[i].y - r[i - 1].y).abs();
    }
    return l;
  }

  /// Whether a segment of [r] other than the first and last passes
  /// through a box interior (the stubs start on the boxes' edges).
  static bool _hitsBoxes(List<SuPoint> r, List<SuRect> boxes) {
    for (var i = 1; i < r.length - 2; i++) {
      for (final box in boxes) {
        if (_segmentInRect(r[i], r[i + 1], box)) return true;
      }
    }
    return false;
  }

  static bool _segmentInRect(SuPoint a, SuPoint b, SuRect r) {
    final minX = math.min(a.x, b.x), maxX = math.max(a.x, b.x);
    final minY = math.min(a.y, b.y), maxY = math.max(a.y, b.y);
    return maxX > r.x && minX < r.right && maxY > r.y && minY < r.bottom;
  }

  static List<SuPoint> _simplify(List<SuPoint> pts) {
    final out = <SuPoint>[];
    for (final p in pts) {
      if (out.isNotEmpty &&
          (out.last.x - p.x).abs() < 1e-6 &&
          (out.last.y - p.y).abs() < 1e-6) {
        continue;
      }
      if (out.length >= 2) {
        final a = out[out.length - 2], b = out.last;
        final collinear =
            ((a.x - b.x).abs() < 1e-6 && (b.x - p.x).abs() < 1e-6) ||
            ((a.y - b.y).abs() < 1e-6 && (b.y - p.y).abs() < 1e-6);
        if (collinear) {
          out.removeLast();
        }
      }
      out.add(p);
    }
    return out;
  }
}

/// Arrowhead geometry (02 §5.3 `startArrow`/`endArrow`/`arrowSize`).
abstract final class ArrowHeads {
  /// The head length for a stroke of [width] and size key [size].
  static double lengthFor(double width, String? size) {
    final k = switch (size) {
      's' => 0.75,
      'l' => 1.5,
      _ => 1.0,
    };
    return math.max(width * 3, 6) * k;
  }

  /// How far the shaft is shortened at an end with [style] so it doesn't
  /// poke through the head.
  static double trimFor(ArrowHead style, double length) => switch (style) {
    ArrowHead.triangle || ArrowHead.stealth => length * 0.8,
    ArrowHead.diamond || ArrowHead.oval => length * 0.5,
    _ => 0,
  };

  /// The head at [tip] pointing along unit [dir] (the line arrives with
  /// direction [dir]); filled heads return `filled: true`.
  static (ScenePath, {bool filled}) head(
    ArrowHead style,
    SuPoint tip,
    SuPoint dir,
    double length,
    double strokeWidth,
  ) {
    final b = ShapePathBuilder();
    final ux = dir.x, uy = dir.y; // forward
    final px = -uy, py = ux; // perpendicular
    (double, double) at(double back, double side) =>
        (tip.x - ux * back + px * side, tip.y - uy * back + py * side);
    final half = length * 0.45;
    switch (style) {
      case ArrowHead.none:
        return (b.build(), filled: false);
      case ArrowHead.triangle:
        final l = at(length, half), r = at(length, -half);
        b.polygon([tip.x, tip.y, l.$1, l.$2, r.$1, r.$2]);
        return (b.build(), filled: true);
      case ArrowHead.stealth:
        final l = at(length, half), r = at(length, -half);
        final n = at(length * 0.65, 0);
        b.polygon([tip.x, tip.y, l.$1, l.$2, n.$1, n.$2, r.$1, r.$2]);
        return (b.build(), filled: true);
      case ArrowHead.open:
        final l = at(length, half), r = at(length, -half);
        b.polyline([l.$1, l.$2, tip.x, tip.y, r.$1, r.$2]);
        return (b.build(), filled: false);
      case ArrowHead.diamond:
        final f = at(length / 2, half * 0.8), bk = at(length, 0);
        final g = at(length / 2, -half * 0.8);
        b.polygon([tip.x, tip.y, f.$1, f.$2, bk.$1, bk.$2, g.$1, g.$2]);
        return (b.build(), filled: true);
      case ArrowHead.oval:
        final c = at(length / 2, 0);
        final r = length * 0.5;
        b.ellipse(c.$1 - r, c.$2 - r, 2 * r, 2 * r);
        return (b.build(), filled: true);
    }
  }

  /// Parses a `strokeJson` arrow value (`circle` = [ArrowHead.oval];
  /// `bar` is drawn as an open head, P1).
  static ArrowHead parse(Object? value) => switch (value) {
    'triangle' => ArrowHead.triangle,
    'open' || 'bar' => ArrowHead.open,
    'stealth' => ArrowHead.stealth,
    'circle' || 'oval' => ArrowHead.oval,
    'diamond' => ArrowHead.diamond,
    _ => ArrowHead.none,
  };
}
