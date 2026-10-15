/// The shape library (03 §6.3, A-03-2): every `dataJson.geometry` key with
/// its outline in a `w × h` box, adjust handles (defaults, ranges, handle
/// tracks), the text rectangle and connection sites. Shared by the scene
/// builder, hit testing, the adjust/connector UI, the PDF renderer and MCP
/// (the key list is the geometry enum).
library;

import 'dart:math' as math;

import '../scene/nodes/scene_nodes.dart';
import '../theme/model/common.dart';
import 'path_ops.dart';
import 'svg_path.dart';

/// Library categories (03 §6.3 table rows).
enum ShapeCategory {
  basic,
  arrows,
  stars,
  callouts,
  flowchart,
  brackets,
  custom,
}

/// The line along which an adjust handle moves: the handle of value `v`
/// sits at `(x0 + v·dx, y0 + v·dy)` in element-local su.
final class AdjustTrack {
  /// Creates a track.
  const AdjustTrack(this.x0, this.y0, this.dx, this.dy);

  final double x0;
  final double y0;
  final double dx;
  final double dy;

  /// The handle position of [v].
  (double, double) at(double v) => (x0 + v * dx, y0 + v * dy);

  /// The value whose handle is closest to ([x], [y]) (projection, not
  /// clamped).
  double valueAt(double x, double y) {
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return 0;
    return ((x - x0) * dx + (y - y0) * dy) / len2;
  }
}

/// One geometry parameter (`dataJson.adjust.<key>`, 02 §6.2).
final class ShapeAdjust {
  /// Creates an adjust.
  const ShapeAdjust(
    this.key,
    this.defaultValue, {
    this.min = 0,
    this.max = 1,
    this.track,
  });

  /// Key in `dataJson.adjust`.
  final String key;

  /// Default value.
  final double defaultValue;

  /// Minimum value.
  final double min;

  /// Maximum value.
  final double max;

  /// Handle track for a `w × h` box with the effective values [a], or null
  /// when the parameter has no on-canvas handle.
  final AdjustTrack Function(double w, double h, double Function(String) a)?
  track;

  /// [v] clamped to the range ([defaultValue] for non-finite values).
  double clamp(double v) =>
      v.isFinite ? v.clamp(min, max).toDouble() : defaultValue;
}

/// A connection site of a shape (03 §6.4): `top`, `right`, `bottom`,
/// `left`, `center` and geometry-specific indexed sites (`"0"`, `"1"`, …).
final class ConnectionSite {
  /// Creates a site.
  const ConnectionSite(this.name, this.x, this.y);

  /// `top`, `right`, `bottom`, `left`, `center` or an index.
  final String name;

  /// Element-local su.
  final double x;

  /// Element-local su.
  final double y;

  @override
  String toString() => 'ConnectionSite($name, $x, $y)';
}

/// One drawn part of a shape outline. Most shapes have one part; 3D-ish
/// shapes add shaded faces and some add stroke-only details.
final class ShapePart {
  /// Creates a part.
  const ShapePart(
    this.path, {
    this.fill = true,
    this.stroke = true,
    this.shade = 0,
  });

  /// The outline (element-local su).
  final ScenePath path;

  /// Whether the element fill is drawn.
  final bool fill;

  /// Whether the element stroke is drawn.
  final bool stroke;

  /// Fill shading: negative darkens, positive lightens (−1..1).
  final double shade;
}

/// A shape laid out in a box.
final class ShapeOutline {
  /// Creates an outline.
  const ShapeOutline({
    required this.parts,
    required this.textRect,
    required this.sites,
  });

  /// Parts back to front.
  final List<ShapePart> parts;

  /// The rectangle text lays out in (before insets).
  final SuRect textRect;

  /// Connection sites.
  final List<ConnectionSite> sites;

  /// The first filled part's path (hit testing, image masks).
  ScenePath get mainPath =>
      parts.firstWhere((p) => p.fill, orElse: () => parts.first).path;

  /// Every filled part's commands combined (masks).
  ScenePath get fillPath {
    final b = ShapePathBuilder();
    var evenOdd = false;
    for (final p in parts) {
      if (!p.fill) continue;
      b.addAll(p.path.commands);
      evenOdd = evenOdd || p.path.evenOdd;
    }
    return b.build(evenOdd: evenOdd);
  }

  /// The site named [name], or null.
  ConnectionSite? site(String name) {
    for (final s in sites) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// A geometry of the library.
final class ShapeGeometry {
  const ShapeGeometry._(
    this.key,
    this.category, {
    required this.p0,
    required this.adjusts,
    required _Build build,
    this.aspect,
  }) : _build = build; // ignore: prefer_initializing_formals

  /// The `dataJson.geometry` key.
  final String key;

  /// Library category.
  final ShapeCategory category;

  /// Priority P0 (else P1/P2) in 03 §6.3.
  final bool p0;

  /// Adjustable parameters.
  final List<ShapeAdjust> adjusts;

  /// Natural aspect ratio (w / h) of the insert size, or null for 1:1.
  final double? aspect;

  final _Build _build;

  /// The defaults of [adjusts].
  Map<String, double> get adjustDefaults => {
    for (final a in adjusts) a.key: a.defaultValue,
  };

  /// The effective value of [key] in [adjust] (clamped; default when
  /// absent).
  double adjustValue(String key, Map<String, Object?>? adjust) {
    for (final a in adjusts) {
      if (a.key == key) {
        final v = adjust?[key];
        return v is num ? a.clamp(v.toDouble()) : a.defaultValue;
      }
    }
    return 0;
  }

  /// The outline in a [w] × [h] box. [customPath] is the SVG path of
  /// `custom` shapes (0..1000 box).
  ShapeOutline outline(
    double w,
    double h, {
    Map<String, Object?>? adjust,
    String? customPath,
    bool evenOdd = false,
  }) {
    final ctx = _Ctx(
      math.max(w, 0),
      math.max(h, 0),
      (k) => adjustValue(k, adjust),
      customPath: customPath,
      evenOdd: evenOdd,
    );
    _build(ctx);
    if (ctx.parts.isEmpty) ctx.main.rect(0, 0, ctx.w, ctx.h);
    return ctx.finish();
  }

  /// The handle positions of [adjusts] with a track (element-local su).
  Map<String, (double, double)> handles(
    double w,
    double h, {
    Map<String, Object?>? adjust,
  }) {
    double a(String k) => adjustValue(k, adjust);
    return {
      for (final x in adjusts)
        if (x.track != null) x.key: x.track!(w, h, a).at(a(x.key)),
    };
  }

  /// The value of adjust [key] for a handle dragged to ([x], [y]).
  double adjustFromPoint(
    String key,
    double w,
    double h,
    double x,
    double y, {
    Map<String, Object?>? adjust,
  }) {
    double a(String k) => adjustValue(k, adjust);
    for (final s in adjusts) {
      if (s.key != key) continue;
      final t = s.track;
      if (t == null) return a(key);
      return s.clamp(t(w, h, a).valueAt(x, y));
    }
    return 0;
  }
}

typedef _Build = void Function(_Ctx c);

final class _Ctx {
  _Ctx(this.w, this.h, this.a, {this.customPath, this.evenOdd = false});

  final double w;
  final double h;
  final double Function(String) a;
  final String? customPath;
  final bool evenOdd;
  final List<(ShapePathBuilder, bool fill, bool stroke, double shade, bool eo)>
  parts = [];
  SuRect? text;
  final Map<String, (double, double)> named = {};
  final List<(double, double)> indexed = [];

  double get m => math.min(w, h);

  ShapePathBuilder _main = ShapePathBuilder();
  bool _mainAdded = false;

  /// The main (filled and stroked) part.
  ShapePathBuilder get main {
    if (!_mainAdded) {
      parts.add((_main, true, true, 0, false));
      _mainAdded = true;
    }
    return _main;
  }

  /// The main part with the even-odd rule.
  ShapePathBuilder get mainEvenOdd {
    if (!_mainAdded) {
      parts.add((_main, true, true, 0, true));
      _mainAdded = true;
    }
    return _main;
  }

  /// Adds a separate part.
  ShapePathBuilder part({
    bool fill = true,
    bool stroke = true,
    double shade = 0,
  }) {
    final b = ShapePathBuilder();
    parts.add((b, fill, stroke, shade, false));
    return b;
  }

  /// Starts a new main part (after other parts, painted on top).
  ShapePathBuilder newMain() {
    _main = ShapePathBuilder();
    _mainAdded = false;
    return main;
  }

  void vertices(List<double> xy) {
    for (var i = 0; i + 1 < xy.length; i += 2) {
      indexed.add((xy[i], xy[i + 1]));
    }
  }

  ShapeOutline finish() {
    final sites = <ConnectionSite>[];
    final defaults = {
      'top': (w / 2, 0.0),
      'right': (w, h / 2),
      'bottom': (w / 2, h),
      'left': (0.0, h / 2),
      'center': (w / 2, h / 2),
    };
    for (final e in defaults.entries) {
      final p = named[e.key] ?? e.value;
      sites.add(ConnectionSite(e.key, p.$1, p.$2));
    }
    for (var i = 0; i < indexed.length; i++) {
      sites.add(ConnectionSite('$i', indexed[i].$1, indexed[i].$2));
    }
    return ShapeOutline(
      parts: [
        for (final (b, fill, stroke, shade, eo) in parts)
          ShapePart(
            b.build(evenOdd: eo || evenOdd),
            fill: fill,
            stroke: stroke,
            shade: shade,
          ),
      ],
      textRect: text ?? SuRect(0, 0, w, h),
      sites: sites,
    );
  }
}

const double _pi = math.pi;

/// The geometry catalog.
abstract final class ShapeLibrary {
  /// The geometry used for unknown keys.
  static const fallbackKey = 'rect';

  /// Every geometry, in library order.
  static final List<ShapeGeometry> all = _catalog();

  static final Map<String, ShapeGeometry> _byKey = {
    for (final g in all) g.key: g,
  };

  /// Every key (the `dataJson.geometry` enum, A-03-2).
  static List<String> get keys => [for (final g in all) g.key];

  /// The geometry [key], or null.
  static ShapeGeometry? of(String? key) => _byKey[key];

  /// The geometry [key] or the fallback `rect`.
  static ShapeGeometry resolve(String? key) =>
      _byKey[key] ?? _byKey[fallbackKey]!;

  /// The geometries of [category].
  static List<ShapeGeometry> inCategory(ShapeCategory category) => [
    for (final g in all)
      if (g.category == category) g,
  ];

  /// The outline of `dataJson` [data] (`geometry`, `adjust`, `path`,
  /// `fillRule`) in a [w] × [h] box.
  static ShapeOutline outlineOf(
    Map<String, Object?>? data,
    double w,
    double h,
  ) {
    final key = data?['geometry'];
    final adjust = data?['adjust'];
    final g = resolve(key is String ? key : null);
    return g.outline(
      w,
      h,
      adjust: adjust is Map ? adjust.cast<String, Object?>() : null,
      customPath: data?['path'] is String ? data!['path'] as String : null,
      evenOdd: data?['fillRule'] == 'evenOdd',
    );
  }
}

// ---------------------------------------------------------------------------
// Catalog

ShapeGeometry _g(
  String key,
  ShapeCategory cat,
  _Build build, {
  bool p0 = false,
  List<ShapeAdjust> adjusts = const [],
  double? aspect,
}) => ShapeGeometry._(
  key,
  cat,
  p0: p0,
  adjusts: adjusts,
  build: build,
  aspect: aspect,
);

AdjustTrack _horizontal(double w, double h, double _) =>
    AdjustTrack(0, 0, w, 0);

List<ShapeGeometry> _catalog() {
  const basic = ShapeCategory.basic;
  const arrows = ShapeCategory.arrows;
  const stars = ShapeCategory.stars;
  const callouts = ShapeCategory.callouts;
  const flow = ShapeCategory.flowchart;
  const brackets = ShapeCategory.brackets;

  final radius = ShapeAdjust(
    'radius',
    0.12,
    max: 0.5,
    track: (w, h, a) => AdjustTrack(0, 0, math.min(w, h), 0),
  );
  ShapeAdjust inset(double d, {double max = 0.5}) => ShapeAdjust(
    'inset',
    d,
    max: max,
    track: (w, h, a) => _horizontal(w, h, 0),
  );
  ShapeAdjust thickness(double d) => ShapeAdjust(
    'thickness',
    d,
    max: 0.5,
    track: (w, h, a) => AdjustTrack(0, h / 2, math.min(w, h), 0),
  );
  List<ShapeAdjust> angles(double start, double end) => [
    ShapeAdjust('start', start),
    ShapeAdjust('end', end),
  ];
  final tip = [
    ShapeAdjust(
      'tipX',
      0.2,
      min: -1,
      max: 2,
      track: (w, h, a) => AdjustTrack(0, a('tipY') * h, w, 0),
    ),
    ShapeAdjust(
      'tipY',
      1.3,
      min: -1,
      max: 2,
      track: (w, h, a) => AdjustTrack(a('tipX') * w, 0, 0, h),
    ),
  ];
  final arrowAdjusts = [
    ShapeAdjust(
      'head',
      0.5,
      max: 1,
      track: (w, h, a) => AdjustTrack(w, 0, -math.min(w, h), 0),
    ),
    ShapeAdjust(
      'shaft',
      0.5,
      max: 1,
      track: (w, h, a) => AdjustTrack(0, h / 2, 0, -h / 2),
    ),
  ];
  final vArrowAdjusts = [
    ShapeAdjust(
      'head',
      0.5,
      max: 1,
      track: (w, h, a) => AdjustTrack(0, 0, 0, math.min(w, h)),
    ),
    ShapeAdjust(
      'shaft',
      0.5,
      max: 1,
      track: (w, h, a) => AdjustTrack(w / 2, 0, -w / 2, 0),
    ),
  ];
  ShapeAdjust inner(double d) => ShapeAdjust(
    'inner',
    d,
    min: 0.05,
    max: 0.95,
    track: (w, h, a) => AdjustTrack(w / 2, h / 2, 0, -h / 2),
  );

  return [
    // Basic (P0: the first 12).
    _g('rect', basic, (c) => c.main.rect(0, 0, c.w, c.h), p0: true),
    _g(
      'roundRect',
      basic,
      (c) {
        c.main.roundRect(0, 0, c.w, c.h, c.a('radius') * c.m);
      },
      p0: true,
      adjusts: [radius],
    ),
    _g('ellipse', basic, _ellipse, p0: true),
    _g(
      'triangle',
      basic,
      (c) {
        final ax = c.a('apex') * c.w;
        final pts = [ax, 0.0, c.w, c.h, 0.0, c.h];
        c.main.polygon(pts);
        c.vertices(pts);
        c.named['top'] = (ax, 0);
        c.named['left'] = (ax / 2, c.h / 2);
        c.named['right'] = ((ax + c.w) / 2, c.h / 2);
        c.text = SuRect(c.w / 4, c.h / 2, c.w / 2, c.h / 2);
      },
      p0: true,
      adjusts: [
        ShapeAdjust('apex', 0.5, track: (w, h, a) => _horizontal(w, h, 0)),
      ],
    ),
    _g('rightTriangle', basic, (c) {
      final pts = [0.0, 0.0, c.w, c.h, 0.0, c.h];
      c.main.polygon(pts);
      c.vertices(pts);
      c.named['top'] = (0, 0);
      c.named['right'] = (c.w / 2, c.h / 2);
      c.text = SuRect(c.w * 0.05, c.h / 2, c.w / 2, c.h * 0.45);
    }, p0: true),
    _g('diamond', basic, _diamond, p0: true),
    _g('pentagon', basic, (c) => _regular(c, 5), p0: true),
    _g(
      'hexagon',
      basic,
      (c) {
        final o = c.a('inset') * c.w;
        final pts = [
          o,
          0.0,
          c.w - o,
          0.0,
          c.w,
          c.h / 2,
          c.w - o,
          c.h,
          o,
          c.h,
          0.0,
          c.h / 2,
        ];
        c.main.polygon(pts);
        c.vertices(pts);
        c.text = SuRect(o / 2, 0, c.w - o, c.h);
      },
      p0: true,
      adjusts: [inset(0.25)],
    ),
    _g(
      'octagon',
      basic,
      (c) {
        final k = c.a('inset') * c.m;
        final w = c.w, h = c.h;
        final pts = [
          k,
          0.0,
          w - k,
          0.0,
          w,
          k,
          w,
          h - k,
          w - k,
          h,
          k,
          h,
          0.0,
          h - k,
          0.0,
          k,
        ];
        c.main.polygon(pts);
        c.vertices(pts);
        c.text = SuRect(k / 2, k / 2, w - k, h - k);
      },
      p0: true,
      adjusts: [
        ShapeAdjust(
          'inset',
          0.29,
          max: 0.5,
          track: (w, h, a) => AdjustTrack(0, 0, math.min(w, h), 0),
        ),
      ],
    ),
    _g(
      'parallelogram',
      basic,
      (c) {
        final o = c.a('inset') * c.w;
        final pts = [o, 0.0, c.w, 0.0, c.w - o, c.h, 0.0, c.h];
        c.main.polygon(pts);
        c.vertices(pts);
        c.text = SuRect(o / 2, 0, c.w - o, c.h);
      },
      p0: true,
      adjusts: [inset(0.25, max: 1)],
    ),
    _g(
      'trapezoid',
      basic,
      (c) {
        final o = c.a('inset') * c.w;
        final pts = [o, 0.0, c.w - o, 0.0, c.w, c.h, 0.0, c.h];
        c.main.polygon(pts);
        c.vertices(pts);
        c.text = SuRect(o / 2, 0, c.w - o, c.h);
      },
      p0: true,
      adjusts: [inset(0.25)],
    ),
    _g(
      'donut',
      basic,
      (c) {
        final t = c.a('thickness') * c.m;
        c.mainEvenOdd
          ..ellipse(0, 0, c.w, c.h)
          ..ellipse(t, t, math.max(0, c.w - 2 * t), math.max(0, c.h - 2 * t));
      },
      p0: true,
      adjusts: [thickness(0.25)],
    ),
    _g('arc', basic, (c) {
      final (s, sw) = _sweep(c);
      c
          .part(fill: false)
          .ellipseArc(
            c.w / 2,
            c.h / 2,
            c.w / 2,
            c.h / 2,
            s,
            sw,
            connect: false,
          );
    }, adjusts: angles(0.75, 0)),
    _g('blockArc', basic, (c) {
      final (s, sw) = _sweep(c);
      final t = c.a('thickness') * c.m;
      final rx = c.w / 2, ry = c.h / 2;
      c.main
        ..ellipseArc(rx, ry, rx, ry, s, sw, connect: false)
        ..ellipseArc(
          rx,
          ry,
          math.max(0, rx - t),
          math.max(0, ry - t),
          s + sw,
          -sw,
        )
        ..close();
    }, adjusts: [...angles(0.5, 0), thickness(0.25)]),
    _g('pie', basic, (c) {
      final (s, sw) = _sweep(c);
      c.main
        ..moveTo(c.w / 2, c.h / 2)
        ..ellipseArc(c.w / 2, c.h / 2, c.w / 2, c.h / 2, s, sw)
        ..close();
    }, adjusts: angles(0, 0.75)),
    _g('chord', basic, (c) {
      final (s, sw) = _sweep(c);
      c.main
        ..ellipseArc(c.w / 2, c.h / 2, c.w / 2, c.h / 2, s, sw, connect: false)
        ..close();
    }, adjusts: angles(0.125, 0.75)),
    _g('frame', basic, (c) {
      final t = c.a('thickness') * c.m;
      c.mainEvenOdd
        ..rect(0, 0, c.w, c.h)
        ..rect(t, t, math.max(0, c.w - 2 * t), math.max(0, c.h - 2 * t));
      c.text = SuRect(t, t, math.max(0, c.w - 2 * t), math.max(0, c.h - 2 * t));
    }, adjusts: [thickness(0.125)]),
    _g('halfFrame', basic, (c) {
      final t = c.a('thickness') * c.m;
      c.main.polygon([0, 0, c.w, 0, c.w - t, t, t, t, t, c.h - t, 0, c.h]);
    }, adjusts: [thickness(0.33)]),
    _g(
      'plus',
      basic,
      (c) {
        final t = c.a('inset') * c.m;
        final w = c.w, h = c.h;
        c.main.polygon([
          t,
          0,
          w - t,
          0,
          w - t,
          t,
          w,
          t,
          w,
          h - t,
          w - t,
          h - t,
          w - t,
          h,
          t,
          h,
          t,
          h - t,
          0,
          h - t,
          0,
          t,
          t,
          t,
        ]);
        c.text = SuRect(t, t, w - 2 * t, h - 2 * t);
      },
      adjusts: [
        ShapeAdjust(
          'inset',
          0.25,
          max: 0.5,
          track: (w, h, a) => AdjustTrack(0, 0, math.min(w, h), 0),
        ),
      ],
    ),
    _g('cross', basic, _cross, adjusts: [ShapeAdjust('inset', 0.2, max: 0.5)]),
    _g('cylinder', basic, _cylinder, adjusts: [_capAdjust()]),
    _g(
      'cube',
      basic,
      (c) {
        final d = c.a('depth') * c.m;
        final w = c.w, h = c.h;
        c.main.rect(0, d, w - d, h - d);
        c.part(shade: 0.2).polygon([0, d, d, 0, w, 0, w - d, d]);
        c.part(shade: -0.2).polygon([w - d, d, w, 0, w, h - d, w - d, h]);
        c.text = SuRect(0, d, w - d, h - d);
      },
      adjusts: [
        ShapeAdjust(
          'depth',
          0.25,
          max: 1,
          track: (w, h, a) => AdjustTrack(0, 0, 0, math.min(w, h)),
        ),
      ],
    ),
    _g('can', basic, _cylinder, adjusts: [_capAdjust()]),
    _g('heart', basic, (c) {
      final w = c.w, h = c.h;
      c.main
        ..moveTo(0.5 * w, 0.25 * h)
        ..cubicTo(0.5 * w, 0, 0, 0, 0, 0.3 * h)
        ..cubicTo(0, 0.55 * h, 0.3 * w, 0.75 * h, 0.5 * w, h)
        ..cubicTo(0.7 * w, 0.75 * h, w, 0.55 * h, w, 0.3 * h)
        ..cubicTo(w, 0, 0.5 * w, 0, 0.5 * w, 0.25 * h)
        ..close();
      c.named['top'] = (w / 2, 0.25 * h);
      c.text = SuRect(w * 0.2, h * 0.2, w * 0.6, h * 0.45);
    }),
    _g('cloud', basic, (c) {
      _cloud(c.main, c.w, c.h);
      c.text = SuRect(c.w * 0.2, c.h * 0.22, c.w * 0.6, c.h * 0.56);
    }),
    _g(
      'moon',
      basic,
      (c) {
        final v = c.a('inset');
        final w = c.w, h = c.h;
        c.main
          ..moveTo(w, 0)
          ..ellipseArc(w, h / 2, w, h / 2, -_pi / 2, -_pi)
          ..ellipseArc(w, h / 2, w * (1 - v), h / 2, _pi / 2, _pi)
          ..close();
        c.named['right'] = (w * (1 - v), h / 2);
      },
      adjusts: [
        ShapeAdjust(
          'inset',
          0.5,
          max: 0.875,
          track: (w, h, a) => AdjustTrack(0, h / 2, w, 0),
        ),
      ],
    ),
    _g('sun', basic, (c) {
      final w = c.w, h = c.h, cx = w / 2, cy = h / 2;
      final r = c.a('inner');
      c.main.ellipse(cx - w * r / 2, cy - h * r / 2, w * r, h * r);
      for (var i = 0; i < 8; i++) {
        final a = i * _pi / 4;
        const d = 0.12;
        final rb = r / 2 + 0.07;
        c.main.polygon([
          cx + math.cos(a) * w / 2,
          cy + math.sin(a) * h / 2,
          cx + math.cos(a + d) * w * rb,
          cy + math.sin(a + d) * h * rb,
          cx + math.cos(a - d) * w * rb,
          cy + math.sin(a - d) * h * rb,
        ]);
      }
      c.text = SuRect(
        cx - w * r * 0.35,
        cy - h * r * 0.35,
        w * r * 0.7,
        h * r * 0.7,
      );
    }, adjusts: [ShapeAdjust('inner', 0.5, min: 0.2, max: 0.75)]),
    _g('lightning', basic, (c) {
      const pts = [
        8458,
        0,
        0,
        3923,
        7564,
        8416,
        4993,
        9720,
        12197,
        13904,
        9987,
        14934,
        21600,
        21600,
        14768,
        12911,
        16558,
        12016,
        11030,
        6840,
        12831,
        6120,
      ];
      c.main.polygon([
        for (var i = 0; i < pts.length; i++)
          pts[i] / 21600 * (i.isEven ? c.w : c.h),
      ]);
      c.named['bottom'] = (c.w, c.h);
      c.named['top'] = (c.w * 8458 / 21600, 0);
    }),

    // Arrows (P0: the first 6).
    _g(
      'arrowRight',
      arrows,
      (c) => _arrow(c, _Dir.right),
      p0: true,
      adjusts: arrowAdjusts,
      aspect: 2,
    ),
    _g(
      'arrowLeft',
      arrows,
      (c) => _arrow(c, _Dir.left),
      p0: true,
      adjusts: arrowAdjusts,
      aspect: 2,
    ),
    _g(
      'arrowUp',
      arrows,
      (c) => _arrow(c, _Dir.up),
      p0: true,
      adjusts: vArrowAdjusts,
      aspect: 0.5,
    ),
    _g(
      'arrowDown',
      arrows,
      (c) => _arrow(c, _Dir.down),
      p0: true,
      adjusts: vArrowAdjusts,
      aspect: 0.5,
    ),
    _g(
      'arrowLeftRight',
      arrows,
      (c) => _arrow(c, _Dir.right, both: true),
      p0: true,
      adjusts: arrowAdjusts,
      aspect: 2,
    ),
    _g(
      'arrowUpDown',
      arrows,
      (c) => _arrow(c, _Dir.down, both: true),
      p0: true,
      adjusts: vArrowAdjusts,
      aspect: 0.5,
    ),
    _g(
      'chevron',
      arrows,
      (c) {
        final d = math.min(c.a('head') * c.m, c.w);
        final w = c.w, h = c.h;
        c.main.polygon([0, 0, w - d, 0, w, h / 2, w - d, h, 0, h, d, h / 2]);
        c.named['left'] = (d, h / 2);
        c.text = SuRect(d, 0, math.max(0, w - 2 * d), h);
      },
      adjusts: [
        ShapeAdjust(
          'head',
          0.5,
          track: (w, h, a) => AdjustTrack(w, 0, -math.min(w, h), 0),
        ),
      ],
      aspect: 2,
    ),
    _g(
      'homePlate',
      arrows,
      (c) {
        final d = math.min(c.a('head') * c.m, c.w);
        final w = c.w, h = c.h;
        c.main.polygon([0, 0, w - d, 0, w, h / 2, w - d, h, 0, h]);
        c.text = SuRect(0, 0, w - d / 2, h);
      },
      adjusts: [
        ShapeAdjust(
          'head',
          0.5,
          track: (w, h, a) => AdjustTrack(w, 0, -math.min(w, h), 0),
        ),
      ],
      aspect: 2,
    ),
    _g(
      'notchedArrow',
      arrows,
      (c) => _arrow(c, _Dir.right, notched: true),
      adjusts: arrowAdjusts,
      aspect: 2,
    ),
    _g('curvedArrow', arrows, _curvedArrow),
    _g('circularArrow', arrows, _circularArrow, adjusts: [thickness(0.2)]),
    _g('uTurn', arrows, _uTurn),

    // Stars and badges.
    _g('star4', stars, (c) => _star(c, 4), adjusts: [inner(0.35)]),
    _g('star5', stars, (c) => _star(c, 5), adjusts: [inner(0.4)]),
    _g('star6', stars, (c) => _star(c, 6), adjusts: [inner(0.5)]),
    _g('star8', stars, (c) => _star(c, 8), adjusts: [inner(0.65)]),
    _g('star12', stars, (c) => _star(c, 12), adjusts: [inner(0.75)]),
    _g('burst', stars, _burst),
    _g('ribbon', stars, (c) {
      final w = c.w, h = c.h;
      c.part(shade: -0.15).polygon([
        0,
        h * 0.25,
        w * 0.2,
        h * 0.25,
        w * 0.2,
        h,
        0,
        h,
        w * 0.07,
        h * 0.625,
      ]);
      c.part(shade: -0.15).polygon([
        w,
        h * 0.25,
        w * 0.8,
        h * 0.25,
        w * 0.8,
        h,
        w,
        h,
        w * 0.93,
        h * 0.625,
      ]);
      c.newMain().rect(w * 0.15, 0, w * 0.7, h * 0.75);
      c.text = SuRect(w * 0.15, 0, w * 0.7, h * 0.75);
    }, aspect: 3),
    _g(
      'wave',
      stars,
      (c) {
        final a = c.a('amplitude') * c.h;
        final w = c.w, h = c.h;
        c.main
          ..moveTo(0, a)
          ..cubicTo(w / 3, -a, 2 * w / 3, 3 * a, w, a)
          ..lineTo(w, h - a)
          ..cubicTo(2 * w / 3, h + a, w / 3, h - 3 * a, 0, h - a)
          ..close();
        c.text = SuRect(0, 2 * a, w, math.max(0, h - 4 * a));
      },
      adjusts: [
        ShapeAdjust(
          'amplitude',
          0.12,
          max: 0.25,
          track: (w, h, a) => AdjustTrack(0, 0, 0, h),
        ),
      ],
      aspect: 2,
    ),
    _g('seal', stars, (c) => _star(c, 24, innerOverride: 0.86)),

    // Callouts (P0: speech, calloutRect).
    _g('speech', callouts, _speech, p0: true, adjusts: tip),
    _g('speechRound', callouts, (c) {
      _rectCallout(c, c.main, c.a('radius') * c.m);
    }, adjusts: [...tip, radius]),
    _g('thought', callouts, (c) {
      _cloud(c.main, c.w, c.h);
      final tx = c.a('tipX') * c.w, ty = c.a('tipY') * c.h;
      final bx = c.w / 2, by = c.h / 2;
      for (final (f, r) in [(0.55, 0.07), (0.8, 0.045), (1.0, 0.03)]) {
        final px = bx + (tx - bx) * f, py = by + (ty - by) * f;
        c.main.ellipse(px - c.w * r, py - c.h * r, 2 * c.w * r, 2 * c.h * r);
      }
      c.text = SuRect(c.w * 0.2, c.h * 0.22, c.w * 0.6, c.h * 0.56);
    }, adjusts: tip),
    _g(
      'calloutRect',
      callouts,
      (c) => _rectCallout(c, c.main, 0),
      p0: true,
      adjusts: tip,
    ),
    _g('calloutLine', callouts, (c) {
      c.main.rect(0, 0, c.w, c.h);
      final tx = c.a('tipX') * c.w, ty = c.a('tipY') * c.h;
      final (ex, ey) = _edgeAnchor(c.w, c.h, tx, ty);
      c.part(fill: false).polyline([ex, ey, tx, ty]);
    }, adjusts: tip),
    _g(
      'banner',
      callouts,
      (c) {
        final n = c.a('inset') * c.w;
        final w = c.w, h = c.h;
        c.main.polygon([0, 0, w, 0, w - n, h / 2, w, h, 0, h, n, h / 2]);
        c.text = SuRect(n, 0, math.max(0, w - 2 * n), h);
      },
      adjusts: [inset(0.1, max: 0.4)],
      aspect: 3,
    ),

    // Flowchart.
    _g('process', flow, (c) => c.main.rect(0, 0, c.w, c.h)),
    _g('decision', flow, _diamond),
    _g('terminator', flow, (c) {
      c.main.roundRect(0, 0, c.w, c.h, c.m / 2);
      c.text = SuRect(c.m * 0.15, 0, c.w - c.m * 0.3, c.h);
    }, aspect: 2),
    _g('document', flow, (c) {
      final w = c.w, h = c.h;
      c.main
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h * 0.83)
        ..cubicTo(w * 0.75, h * 0.66, w * 0.5, h * 1.08, 0, h * 0.9)
        ..close();
      c.text = SuRect(0, 0, w, h * 0.8);
    }),
    _g('data', flow, (c) {
      final o = c.w * 0.2;
      c.main.polygon([o, 0, c.w, 0, c.w - o, c.h, 0, c.h]);
      c.text = SuRect(o / 2, 0, c.w - o, c.h);
    }),
    _g('manualInput', flow, (c) {
      c.main.polygon([0, c.h * 0.2, c.w, 0, c.w, c.h, 0, c.h]);
      c.text = SuRect(0, c.h * 0.2, c.w, c.h * 0.8);
    }),
    _g('predefinedProcess', flow, (c) {
      c.main.rect(0, 0, c.w, c.h);
      c.part(fill: false)
        ..polyline([c.w * 0.1, 0, c.w * 0.1, c.h])
        ..polyline([c.w * 0.9, 0, c.w * 0.9, c.h]);
      c.text = SuRect(c.w * 0.1, 0, c.w * 0.8, c.h);
    }),
    _g('connector', flow, _ellipse),
    _g('offPage', flow, (c) {
      c.main.polygon([
        0,
        0,
        c.w,
        0,
        c.w,
        c.h * 0.8,
        c.w / 2,
        c.h,
        0,
        c.h * 0.8,
      ]);
      c.text = SuRect(0, 0, c.w, c.h * 0.8);
    }),
    _g('delay', flow, (c) {
      final w = c.w, h = c.h;
      c.main
        ..moveTo(0, 0)
        ..lineTo(w / 2, 0)
        ..ellipseArc(w / 2, h / 2, w / 2, h / 2, -_pi / 2, _pi)
        ..lineTo(0, h)
        ..close();
      c.text = SuRect(0, 0, w * 0.85, h);
    }),
    _g('storage', flow, (c) {
      final w = c.w, h = c.h, k = w * 0.17;
      c.main
        ..moveTo(k, 0)
        ..lineTo(w, 0)
        ..ellipseArc(w, h / 2, k, h / 2, -_pi / 2, -_pi)
        ..lineTo(k, h)
        ..ellipseArc(k, h / 2, k, h / 2, _pi / 2, _pi)
        ..close();
      c.named['right'] = (w - k, h / 2);
      c.text = SuRect(k, 0, w - 2 * k, h);
    }),

    // Brackets (stroke only).
    _g('brace', brackets, (c) {
      _brace(c.part(fill: false), 0, c.w, c.h, left: true);
    }, aspect: 0.2),
    _g('bracket', brackets, (c) {
      final r = math.min(c.w, c.h * 0.08);
      c.part(fill: false)
        ..moveTo(c.w, 0)
        ..ellipseArc(c.w, r, c.w, r, -_pi / 2, -_pi / 2)
        ..lineTo(0, c.h - r)
        ..ellipseArc(c.w, c.h - r, c.w, r, _pi, -_pi / 2);
    }, aspect: 0.2),
    _g('doubleBrace', brackets, (c) {
      final bw = c.w * 0.12;
      final p = c.part(fill: false);
      _brace(p, 0, bw, c.h, left: true);
      _brace(p, c.w - bw, bw, c.h, left: false);
      c.text = SuRect(bw, 0, c.w - 2 * bw, c.h);
    }),

    // Custom (SVG path in a 0..1000 box).
    _g('custom', ShapeCategory.custom, (c) {
      final d = c.customPath;
      final cmds = d == null ? const <Never>[] : SvgPathParser.parse(d);
      if (cmds.isEmpty) {
        c.main.rect(0, 0, c.w, c.h);
        return;
      }
      c.main.addAll(PathOps.scale(cmds, c.w / 1000, c.h / 1000));
    }),
  ];
}

ShapeAdjust _capAdjust() => ShapeAdjust(
  'cap',
  0.25,
  max: 1,
  track: (w, h, a) => AdjustTrack(w / 2, 0, 0, h / 2),
);

void _ellipse(_Ctx c) {
  c.main.ellipse(0, 0, c.w, c.h);
  const k = 0.146; // 1 − cos 45° / 2: the inscribed rectangle
  c.text = SuRect(c.w * k, c.h * k, c.w * (1 - 2 * k), c.h * (1 - 2 * k));
}

void _diamond(_Ctx c) {
  final pts = [c.w / 2, 0.0, c.w, c.h / 2, c.w / 2, c.h, 0.0, c.h / 2];
  c.main.polygon(pts);
  c.vertices(pts);
  c.text = SuRect(c.w / 4, c.h / 4, c.w / 2, c.h / 2);
}

/// A regular polygon with [n] corners, first corner on top, scaled to fill
/// the box.
void _regular(_Ctx c, int n) {
  final xs = <double>[], ys = <double>[];
  for (var i = 0; i < n; i++) {
    final a = -_pi / 2 + i * 2 * _pi / n;
    xs.add(math.cos(a));
    ys.add(math.sin(a));
  }
  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  final pts = <double>[
    for (var i = 0; i < n; i++) ...[
      (xs[i] - minX) / (maxX - minX) * c.w,
      (ys[i] - minY) / (maxY - minY) * c.h,
    ],
  ];
  c.main.polygon(pts);
  c.vertices(pts);
  c.text = SuRect(c.w * 0.2, c.h * 0.3, c.w * 0.6, c.h * 0.6);
}

/// The start angle and clockwise sweep (radians) of `start`/`end` (turn
/// fractions, 0 = 3 o'clock).
(double, double) _sweep(_Ctx c) {
  final s = c.a('start') * 2 * _pi;
  var e = c.a('end') * 2 * _pi;
  while (e <= s) {
    e += 2 * _pi;
  }
  final sweep = e - s;
  return (s, sweep > 2 * _pi ? 2 * _pi : sweep);
}

(double, double) _intersect(
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
  double dx,
  double dy,
) {
  final d = (ax - bx) * (cy - dy) - (ay - by) * (cx - dx);
  if (d.abs() < 1e-12) return ((ax + cx) / 2, (ay + cy) / 2);
  final t = ((ax - cx) * (cy - dy) - (ay - cy) * (cx - dx)) / d;
  return (ax + t * (bx - ax), ay + t * (by - ay));
}

void _cross(_Ctx c) {
  final u = c.a('inset') * c.m;
  final w = c.w, h = c.h;
  // Edges of the "\" arm (upper-right, lower-left) and the "/" arm
  // (upper-left, lower-right).
  final n = _intersect(u, 0, w, h - u, w - u, 0, 0, h - u);
  final e = _intersect(u, 0, w, h - u, w, u, u, h);
  final s = _intersect(0, u, w - u, h, w, u, u, h);
  final wst = _intersect(0, u, w - u, h, w - u, 0, 0, h - u);
  c.main.polygon([
    0,
    u,
    u,
    0,
    n.$1,
    n.$2,
    w - u,
    0,
    w,
    u,
    e.$1,
    e.$2,
    w,
    h - u,
    w - u,
    h,
    s.$1,
    s.$2,
    u,
    h,
    0,
    h - u,
    wst.$1,
    wst.$2,
  ]);
}

void _cylinder(_Ctx c) {
  final e = math.min(c.a('cap') * c.h, c.h / 2);
  final w = c.w, h = c.h;
  c.main
    ..moveTo(0, e / 2)
    ..lineTo(0, h - e / 2)
    ..ellipseArc(w / 2, h - e / 2, w / 2, e / 2, _pi, -_pi)
    ..lineTo(w, e / 2)
    ..ellipseArc(w / 2, e / 2, w / 2, e / 2, 0, -_pi)
    ..close();
  c.part(shade: 0.15).ellipse(0, 0, w, e);
  c.text = SuRect(0, e, w, math.max(0, h - 1.5 * e));
}

void _cloud(ShapePathBuilder b, double w, double h) {
  const n = 9;
  final cx = w / 2, cy = h / 2;
  final pts = <(double, double)>[
    for (var i = 0; i < n; i++)
      (
        cx + math.cos(-_pi / 2 + i * 2 * _pi / n) * w / 2 * 0.8,
        cy + math.sin(-_pi / 2 + i * 2 * _pi / n) * h / 2 * 0.76,
      ),
  ];
  b.moveTo(pts[0].$1, pts[0].$2);
  for (var i = 0; i < n; i++) {
    final p = pts[i], q = pts[(i + 1) % n];
    final mx = (p.$1 + q.$1) / 2, my = (p.$2 + q.$2) / 2;
    b.quadTo(cx + (mx - cx) * 1.5, cy + (my - cy) * 1.5, q.$1, q.$2);
  }
  b.close();
}

enum _Dir { right, left, up, down }

void _arrow(_Ctx c, _Dir dir, {bool both = false, bool notched = false}) {
  final vertical = dir == _Dir.up || dir == _Dir.down;
  // Lay out a right-pointing arrow in a (len × thick) box, then map.
  final len = vertical ? c.h : c.w, thick = vertical ? c.w : c.h;
  final m = math.min(len, thick);
  final hl = math.min(c.a('head') * m, both ? len / 2 : len);
  final st = c.a('shaft') * thick;
  final y0 = (thick - st) / 2, y1 = y0 + st;
  final pts = <double>[
    if (both) ...[0, thick / 2, hl, 0, hl, y0] else ...[0, y0],
    len - hl,
    y0,
    len - hl,
    0,
    len,
    thick / 2,
    len - hl,
    thick,
    len - hl,
    y1,
    if (both) ...[hl, y1, hl, thick] else ...[0, y1],
    if (notched && !both) ...[math.min(st / 2, len - hl), thick / 2],
  ];
  (double, double) map(double x, double y) => switch (dir) {
    _Dir.right => (x, y),
    _Dir.left => (c.w - x, y),
    _Dir.up => (y, c.h - x),
    _Dir.down => (y, x),
  };
  final mapped = <double>[];
  for (var i = 0; i + 1 < pts.length; i += 2) {
    final (x, y) = map(pts[i], pts[i + 1]);
    mapped
      ..add(x)
      ..add(y);
  }
  c.main.polygon(mapped);
  final tip = map(len, thick / 2);
  c.indexed.add(tip);
  final shaftStart = map(both ? hl : 0, y0);
  final shaftEnd = map(len - hl, y1);
  c.text = SuRect(
    math.min(shaftStart.$1, shaftEnd.$1),
    math.min(shaftStart.$2, shaftEnd.$2),
    (shaftEnd.$1 - shaftStart.$1).abs(),
    (shaftEnd.$2 - shaftStart.$2).abs(),
  );
}

void _curvedArrow(_Ctx c) {
  final w = c.w, h = c.h;
  final t = 0.25 * c.m, e = 0.15 * c.m;
  final hl = math.min(0.35 * c.m, w * 0.5);
  final cx = w - hl, cy = h;
  final rxo = cx, ryo = h - e;
  final rxi = math.max(0.0, rxo - t), ryi = math.max(0.0, ryo - t);
  c.main
    ..moveTo(0, h)
    ..ellipseArc(cx, cy, rxo, ryo, _pi, _pi / 2)
    ..lineTo(cx, 0)
    ..lineTo(w, e + t / 2)
    ..lineTo(cx, t + 2 * e)
    ..lineTo(cx, e + t)
    ..ellipseArc(cx, cy, rxi, ryi, 3 * _pi / 2, -_pi / 2)
    ..close();
  c.indexed.add((w, e + t / 2));
}

void _circularArrow(_Ctx c) {
  final w = c.w, h = c.h, cx = w / 2, cy = h / 2;
  final e = 0.08 * c.m;
  final t = c.a('thickness') * c.m;
  final rxo = w / 2 - e, ryo = h / 2 - e;
  final rxi = math.max(0.0, rxo - t), ryi = math.max(0.0, ryo - t);
  const start = _pi, end = 2 * _pi - 0.35, delta = 0.45;
  (double, double) at(double rx, double ry, double a) =>
      (cx + rx * math.cos(a), cy + ry * math.sin(a));
  final p1 = at(rxo + e, ryo + e, end);
  final tip = at((rxo + rxi) / 2, (ryo + ryi) / 2, end + delta);
  final p2 = at(math.max(0, rxi - e), math.max(0, ryi - e), end);
  c.main
    ..ellipseArc(cx, cy, rxo, ryo, start, end - start, connect: false)
    ..lineTo(p1.$1, p1.$2)
    ..lineTo(tip.$1, tip.$2)
    ..lineTo(p2.$1, p2.$2)
    ..ellipseArc(cx, cy, rxi, ryi, end, -(end - start))
    ..close();
  c.indexed.add(tip);
}

void _uTurn(_Ctx c) {
  final w = c.w, h = c.h;
  final t = 0.25 * w;
  final hl = 0.25 * h;
  final ro = (w - 0.5 * t) / 2;
  final ry = math.min(ro, h * 0.4);
  final cxu = ro, cyu = ry;
  c.main
    ..moveTo(0, h)
    ..lineTo(0, cyu)
    ..ellipseArc(cxu, cyu, ro, ry, _pi, _pi)
    ..lineTo(w - 0.5 * t, h - hl)
    ..lineTo(w, h - hl)
    ..lineTo(w - t, h)
    ..lineTo(w - 2 * t, h - hl)
    ..lineTo(w - 1.5 * t, h - hl)
    ..lineTo(w - 1.5 * t, cyu)
    ..ellipseArc(cxu, cyu, math.max(0, ro - t), math.max(0, ry - t), 0, -_pi)
    ..lineTo(t, h)
    ..close();
  c.indexed.add((w - t, h));
}

void _star(_Ctx c, int n, {double? innerOverride}) {
  final r = innerOverride ?? c.a('inner');
  final cx = c.w / 2, cy = c.h / 2;
  final pts = <double>[];
  for (var i = 0; i < 2 * n; i++) {
    final a = -_pi / 2 + i * _pi / n;
    final k = i.isEven ? 1.0 : r;
    pts
      ..add(cx + math.cos(a) * c.w / 2 * k)
      ..add(cy + math.sin(a) * c.h / 2 * k);
    if (i.isEven) c.indexed.add((pts[pts.length - 2], pts.last));
  }
  c.main.polygon(pts);
  c.text = SuRect(
    cx - c.w / 2 * r * 0.7,
    cy - c.h / 2 * r * 0.7,
    c.w * r * 0.7,
    c.h * r * 0.7,
  );
}

void _burst(_Ctx c) {
  const outer = [1.0, 0.82, 0.95, 0.76, 1.0, 0.88, 0.8, 0.97];
  const n = 16;
  final cx = c.w / 2, cy = c.h / 2;
  final pts = <double>[];
  for (var i = 0; i < 2 * n; i++) {
    final a = -_pi / 2 + i * _pi / n;
    final k = i.isEven ? outer[(i ~/ 2) % outer.length] : 0.62;
    pts
      ..add(cx + math.cos(a) * c.w / 2 * k)
      ..add(cy + math.sin(a) * c.h / 2 * k);
  }
  c.main.polygon(pts);
  c.text = SuRect(c.w * 0.28, c.h * 0.28, c.w * 0.44, c.h * 0.44);
}

void _speech(_Ctx c) {
  final w = c.w, h = c.h, cx = w / 2, cy = h / 2;
  final tx = c.a('tipX') * w, ty = c.a('tipY') * h;
  // Angle in the unit-circle space of the ellipse.
  final theta = math.atan2(
    (ty - cy) / math.max(h / 2, 1e-9),
    (tx - cx) / math.max(w / 2, 1e-9),
  );
  final inside =
      math.pow((tx - cx) / (w / 2), 2) + math.pow((ty - cy) / (h / 2), 2) <= 1;
  if (inside || !tx.isFinite || !ty.isFinite) {
    _ellipse(c);
    return;
  }
  const d = 0.18;
  c.main
    ..ellipseArc(
      cx,
      cy,
      w / 2,
      h / 2,
      theta + d,
      2 * _pi - 2 * d,
      connect: false,
    )
    ..lineTo(tx, ty)
    ..close();
  c.indexed.add((tx, ty));
  const k = 0.146;
  c.text = SuRect(w * k, h * k, w * (1 - 2 * k), h * (1 - 2 * k));
}

/// The point on the box edge facing ([tx], [ty]) (callout lines).
(double, double) _edgeAnchor(double w, double h, double tx, double ty) {
  final dx = (tx - w / 2) / math.max(w, 1e-9);
  final dy = (ty - h / 2) / math.max(h, 1e-9);
  if (dx.abs() > dy.abs()) return (dx > 0 ? w : 0, h / 2);
  return (w / 2, dy > 0 ? h : 0);
}

/// A rectangle (corner radius [r]) with a wedge toward the tip on the edge
/// facing it.
void _rectCallout(_Ctx c, ShapePathBuilder b, double r) {
  final w = c.w, h = c.h;
  final tx = c.a('tipX') * w, ty = c.a('tipY') * h;
  final inside = tx >= 0 && tx <= w && ty >= 0 && ty <= h;
  final rr = math.max(0.0, math.min(r, math.min(w, h) / 2));
  // Edge 0 top, 1 right, 2 bottom, 3 left.
  int edge;
  if (inside) {
    edge = -1;
  } else {
    final dx = (tx - w / 2) / math.max(w, 1e-9);
    final dy = (ty - h / 2) / math.max(h, 1e-9);
    edge = dx.abs() > dy.abs() ? (dx > 0 ? 1 : 3) : (dy > 0 ? 2 : 0);
  }
  void wedge(int e) {
    if (e != edge) return;
    final horizontal = e == 0 || e == 2;
    final len = horizontal ? w : h;
    final bw = math.min(len * 0.2, math.max(0.0, len - 2 * rr));
    if (bw <= 0) return;
    final proj = horizontal ? tx : ty;
    final mid = proj.clamp(rr + bw / 2, len - rr - bw / 2).toDouble();
    // Clockwise order along the edge.
    final (a, z) = switch (e) {
      0 => (mid - bw / 2, mid + bw / 2),
      1 => (mid - bw / 2, mid + bw / 2),
      2 => (mid + bw / 2, mid - bw / 2),
      _ => (mid + bw / 2, mid - bw / 2),
    };
    (double, double) on(double v) => switch (e) {
      0 => (v, 0.0),
      1 => (w, v),
      2 => (v, h),
      _ => (0.0, v),
    };
    final p = on(a), q = on(z);
    b
      ..lineTo(p.$1, p.$2)
      ..lineTo(tx, ty)
      ..lineTo(q.$1, q.$2);
  }

  const q = _pi / 2;
  b.moveTo(rr, 0);
  wedge(0);
  b.lineTo(w - rr, 0);
  if (rr > 0) b.ellipseArc(w - rr, rr, rr, rr, -q, q);
  wedge(1);
  b.lineTo(w, h - rr);
  if (rr > 0) b.ellipseArc(w - rr, h - rr, rr, rr, 0, q);
  wedge(2);
  b.lineTo(rr, h);
  if (rr > 0) b.ellipseArc(rr, h - rr, rr, rr, q, q);
  wedge(3);
  b.lineTo(0, rr);
  if (rr > 0) b.ellipseArc(rr, rr, rr, rr, _pi, q);
  b.close();
  if (!inside) c.indexed.add((tx, ty));
}

/// A curly brace in the box `[x, x + w] × [0, h]` (`{` when [left]).
void _brace(
  ShapePathBuilder b,
  double x,
  double w,
  double h, {
  required bool left,
}) {
  double fx(double v) => left ? x + v : x + w - v;
  b
    ..moveTo(fx(w), 0)
    ..cubicTo(fx(w / 2), 0, fx(w / 2), 0, fx(w / 2), h * 0.08)
    ..lineTo(fx(w / 2), h * 0.42)
    ..cubicTo(fx(w / 2), h / 2, fx(w / 2), h / 2, fx(0), h / 2)
    ..cubicTo(fx(w / 2), h / 2, fx(w / 2), h / 2, fx(w / 2), h * 0.58)
    ..lineTo(fx(w / 2), h * 0.92)
    ..cubicTo(fx(w / 2), h, fx(w / 2), h, fx(w), h);
}
