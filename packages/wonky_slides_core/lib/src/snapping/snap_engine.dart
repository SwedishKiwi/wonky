/// Smart guides and snapping (03 §5): the pure-Dart `SnapEngine` the canvas
/// asks on every pointer move of a drag. Targets are built once per gesture
/// ([SnapTargets]); each query is a binary search over sorted lines plus a
/// scan of the moving box's row/column for equal spacing, so a move over
/// 500 elements stays well under the 2 ms budget of 03 §18.
library;

import 'dart:math' as math;

import '../theme/model/common.dart';

/// The axis a snap acts on: [x] moves horizontally (vertical guide lines),
/// [y] vertically (horizontal guide lines).
enum SnapAxis { x, y }

/// Where a snap line comes from, in the priority order of 03 §5.1 (lower
/// index wins a tie at equal distance).
enum SnapSource {
  /// Slide edges.
  slide,

  /// Slide center lines (drawn dashed across the slide).
  slideCenter,

  /// A user guide (§5.6).
  guide,

  /// An edge or center of another element.
  element,

  /// Equal spacing between neighbors.
  spacing,

  /// Equal size (resize only).
  size,
}

/// The axis of a user guide: a vertical guide is a line at `x = at`.
enum GuideAxis {
  vertical,
  horizontal;

  /// `"v"` / `"h"` of `Deck.guidesJson` (03 §5.6).
  String get code => this == vertical ? 'v' : 'h';

  /// The axis of [code] (`"v"`/`"h"`), or null.
  static GuideAxis? fromCode(Object? code) => switch (code) {
    'v' || 'vertical' => vertical,
    'h' || 'horizontal' => horizontal,
    _ => null,
  };
}

/// A user guide of the deck (03 §5.6, `Deck.guidesJson`).
final class UserGuide {
  /// Creates a guide.
  const UserGuide(this.axis, this.at);

  final GuideAxis axis;

  /// Position in su (x for vertical guides, y for horizontal ones).
  final double at;

  @override
  bool operator ==(Object other) =>
      other is UserGuide && other.axis == axis && other.at == at;

  @override
  int get hashCode => Object.hash(axis, at);

  @override
  String toString() => 'UserGuide(${axis.code}, $at)';
}

/// A box offering snap lines: an element's axis-aligned (rotated) bounds.
final class SnapBox {
  /// Creates a box.
  const SnapBox(this.id, this.rect);

  /// The element id.
  final String id;

  /// Bounds in slide space (su).
  final SuRect rect;
}

/// A point lines and connectors glue to (03 §6.4): a connection site.
final class SnapSite {
  /// Creates a site.
  const SnapSite(this.elementId, this.site, this.x, this.y);

  final String elementId;

  /// Site name (`top`, `right`, `center`, an index …).
  final String site;
  final double x;
  final double y;
}

/// An alignment guide to draw (03 §5.2): for [SnapAxis.x] a vertical line
/// at `x = at` from `y = from` to `y = to`, with × markers at [marks].
final class SnapGuide {
  /// Creates a guide.
  const SnapGuide(
    this.axis,
    this.at,
    this.from,
    this.to, {
    this.source = SnapSource.element,
    this.marks = const [],
  });

  final SnapAxis axis;
  final double at;
  final double from;
  final double to;
  final SnapSource source;

  /// Positions along the line of the aligned points.
  final List<double> marks;

  /// Whether the guide is drawn dashed (slide center lines).
  bool get dashed => source == SnapSource.slideCenter;

  @override
  String toString() => 'SnapGuide(${axis.name} $at, $from…$to, ${source.name})';
}

/// One gap of an equal-spacing indicator: for [SnapAxis.x] a horizontal bar
/// from `x = start` to `x = end` at `y = cross`.
final class SpacingGap {
  /// Creates a gap.
  const SpacingGap(this.start, this.end, this.cross);

  final double start;
  final double end;
  final double cross;

  @override
  String toString() => 'SpacingGap($start…$end @ $cross)';
}

/// Equal spacing bars with their distance label ("48", 03 §5.2).
final class SpacingGuide {
  /// Creates the indicator.
  const SpacingGuide(this.axis, this.gaps, this.distance);

  final SnapAxis axis;
  final List<SpacingGap> gaps;
  final double distance;
}

/// A box whose width ([SnapAxis.x]) or height matches the resized box.
final class SizeMatch {
  /// Creates the match.
  const SizeMatch(this.axis, this.rect);

  final SnapAxis axis;
  final SuRect rect;
}

/// The result of a move query: the correction to apply and what to draw.
final class SnapResult {
  /// Creates a result.
  const SnapResult({
    this.dx = 0,
    this.dy = 0,
    this.snappedX = false,
    this.snappedY = false,
    this.guides = const [],
    this.spacings = const [],
  });

  /// No snapping.
  static const none = SnapResult();

  /// Correction (su) to add to the moving box.
  final double dx;
  final double dy;
  final bool snappedX;
  final bool snappedY;
  final List<SnapGuide> guides;
  final List<SpacingGuide> spacings;
}

/// The result of a resize query.
final class SnapResizeResult {
  /// Creates a result.
  const SnapResizeResult(
    this.rect, {
    this.guides = const [],
    this.sizes = const [],
    this.snappedX = false,
    this.snappedY = false,
  });

  /// The snapped box.
  final SuRect rect;
  final List<SnapGuide> guides;
  final List<SizeMatch> sizes;
  final bool snappedX;
  final bool snappedY;
}

/// The result of a point query (line endpoints).
final class SnapPointResult {
  /// Creates a result.
  const SnapPointResult(this.x, this.y, {this.site, this.guides = const []});

  final double x;
  final double y;

  /// The connection site the point glued to, or null.
  final SnapSite? site;
  final List<SnapGuide> guides;
}

/// A snap line: a value on one axis with the cross-axis extent of what
/// offers it.
final class _Line {
  const _Line(this.value, this.source, this.lo, this.hi, [this.id]);

  final double value;
  final SnapSource source;
  final double lo;
  final double hi;
  final String? id;
}

/// The snap targets of one gesture (03 §5.1): slide edges and centers,
/// user guides, the edges and centers of the other visible elements, and
/// their boxes for equal spacing and equal size. Build once per drag.
final class SnapTargets {
  /// Creates targets. [boxes] must not contain the moving elements.
  /// [objects] off drops the slide and element lines, equal spacing and
  /// equal size (*Snap to objects*); [guidesOn] off drops [guides].
  SnapTargets({
    required this.slide,
    List<SnapBox> boxes = const [],
    List<UserGuide> guides = const [],
    this.sites = const [],
    this.objects = true,
    this.guidesOn = true,
  }) : boxes = objects ? List.unmodifiable(boxes) : const [] {
    final xs = <_Line>[], ys = <_Line>[];
    if (objects) {
      final s = slide;
      xs
        ..add(_Line(s.x, SnapSource.slide, s.y, s.bottom))
        ..add(_Line(s.right, SnapSource.slide, s.y, s.bottom))
        ..add(_Line(s.x + s.width / 2, SnapSource.slideCenter, s.y, s.bottom));
      ys
        ..add(_Line(s.y, SnapSource.slide, s.x, s.right))
        ..add(_Line(s.bottom, SnapSource.slide, s.x, s.right))
        ..add(_Line(s.y + s.height / 2, SnapSource.slideCenter, s.x, s.right));
      for (final b in this.boxes) {
        final r = b.rect;
        for (final v in [r.x, r.x + r.width / 2, r.right]) {
          xs.add(_Line(v, SnapSource.element, r.y, r.bottom, b.id));
        }
        for (final v in [r.y, r.y + r.height / 2, r.bottom]) {
          ys.add(_Line(v, SnapSource.element, r.x, r.right, b.id));
        }
      }
    }
    if (guidesOn) {
      for (final g in guides) {
        if (g.axis == GuideAxis.vertical) {
          xs.add(_Line(g.at, SnapSource.guide, slide.y, slide.bottom));
        } else {
          ys.add(_Line(g.at, SnapSource.guide, slide.x, slide.right));
        }
      }
    }
    int byValue(_Line a, _Line b) => a.value.compareTo(b.value);
    _xs = xs..sort(byValue);
    _ys = ys..sort(byValue);
  }

  /// The slide bounds (su).
  final SuRect slide;

  /// Other elements' boxes (empty when [objects] is off).
  final List<SnapBox> boxes;

  /// Connection sites lines may glue to.
  final List<SnapSite> sites;

  /// *Snap to objects*.
  final bool objects;

  /// *Snap to guides*.
  final bool guidesOn;

  late final List<_Line> _xs;
  late final List<_Line> _ys;

  List<_Line> _lines(SnapAxis a) => a == SnapAxis.x ? _xs : _ys;

  /// Lines with a value in `[lo, hi]` (binary search).
  Iterable<_Line> _range(SnapAxis a, double lo, double hi) sync* {
    final l = _lines(a);
    var i = 0, j = l.length;
    while (i < j) {
      final m = (i + j) >> 1;
      if (l[m].value < lo) {
        i = m + 1;
      } else {
        j = m;
      }
    }
    for (; i < l.length && l[i].value <= hi; i++) {
      yield l[i];
    }
  }
}

/// A candidate correction on one axis.
final class _Cand {
  const _Cand(this.d, this.source, [this.spacing]);

  final double d;
  final SnapSource source;
  final double? spacing;

  bool beats(_Cand? o) {
    if (o == null) return true;
    final a = d.abs(), b = o.d.abs();
    if ((a - b).abs() > 1e-9) return a < b;
    return source.index < o.source.index;
  }
}

/// Snapping math of 03 §5 (pure Dart).
abstract final class SnapEngine {
  /// Values closer than this count as aligned (guides, equal gaps).
  static const epsilon = 0.5;

  /// The threshold in su for [pixels] screen px at [scale] px per su (03
  /// §5.1: 6 px).
  static double thresholdFor(double scale, {double pixels = 6}) =>
      scale <= 0 ? pixels : pixels / scale;

  // ---------------------------------------------------------------- move

  /// Snaps a moving [box] (the selection's bounds after the raw pointer
  /// delta): its left/center/right and top/middle/bottom against [t]
  /// within [threshold] su, and equal spacing in its row/column. Axes in
  /// [lockX]/[lockY] don't snap (Shift-constrained drags).
  static SnapResult snapMove(
    SuRect box,
    SnapTargets t,
    double threshold, {
    bool lockX = false,
    bool lockY = false,
  }) {
    final cx = lockX ? null : _best(box, t, SnapAxis.x, threshold, true);
    final cy = lockY ? null : _best(box, t, SnapAxis.y, threshold, true);
    final dx = cx?.d ?? 0, dy = cy?.d ?? 0;
    final moved = box.translate(dx, dy);
    return SnapResult(
      dx: dx,
      dy: dy,
      snappedX: cx != null,
      snappedY: cy != null,
      guides: [
        ..._guides(moved, t, SnapAxis.x, _anchors(moved, SnapAxis.x)),
        ..._guides(moved, t, SnapAxis.y, _anchors(moved, SnapAxis.y)),
      ],
      spacings: [
        ?_spacing(moved, t, SnapAxis.x),
        ?_spacing(moved, t, SnapAxis.y),
      ],
    );
  }

  static List<double> _anchors(SuRect r, SnapAxis a) => a == SnapAxis.x
      ? [r.x, r.x + r.width / 2, r.right]
      : [r.y, r.y + r.height / 2, r.bottom];

  static _Cand? _best(
    SuRect box,
    SnapTargets t,
    SnapAxis a,
    double th,
    bool spacing,
  ) {
    _Cand? best;
    for (final v in _anchors(box, a)) {
      for (final l in t._range(a, v - th, v + th)) {
        final c = _Cand(l.value - v, l.source);
        if (c.beats(best)) best = c;
      }
    }
    if (spacing && t.objects) {
      for (final c in _spacingCandidates(box, t, a, th)) {
        if (c.beats(best)) best = c;
      }
    }
    return best;
  }

  // Row (x) / column (y) helpers: start, end and cross extent per axis.
  static double _s(SuRect r, SnapAxis a) => a == SnapAxis.x ? r.x : r.y;
  static double _e(SuRect r, SnapAxis a) =>
      a == SnapAxis.x ? r.right : r.bottom;
  static double _cs(SuRect r, SnapAxis a) => a == SnapAxis.x ? r.y : r.x;
  static double _ce(SuRect r, SnapAxis a) =>
      a == SnapAxis.x ? r.bottom : r.right;
  static double _len(SuRect r, SnapAxis a) =>
      a == SnapAxis.x ? r.width : r.height;

  /// Boxes sharing the moving box's row ([SnapAxis.x]) or column.
  static List<SuRect> _band(SuRect box, SnapTargets t, SnapAxis a) => [
    for (final b in t.boxes)
      if (_cs(b.rect, a) < _ce(box, a) && _cs(box, a) < _ce(b.rect, a)) b.rect,
  ];

  /// Positive gaps between consecutive, non-overlapping boxes of [band].
  static List<(SuRect, SuRect, double)> _gaps(List<SuRect> band, SnapAxis a) {
    final sorted = [...band]..sort((p, q) => _s(p, a).compareTo(_s(q, a)));
    final out = <(SuRect, SuRect, double)>[];
    for (var i = 0; i + 1 < sorted.length; i++) {
      // The nearest box starting after this one ends.
      final p = sorted[i];
      SuRect? next;
      for (var j = i + 1; j < sorted.length; j++) {
        final q = sorted[j];
        if (_s(q, a) >= _e(p, a) - 1e-9 &&
            (next == null || _s(q, a) < _s(next, a))) {
          next = q;
        }
      }
      if (next != null) {
        final g = _s(next, a) - _e(p, a);
        if (g > epsilon) out.add((p, next, g));
      }
    }
    return out;
  }

  /// The nearest neighbor before and after [box] in its band.
  static (SuRect?, SuRect?) _neighbors(
    SuRect box,
    List<SuRect> band,
    SnapAxis a,
    double th,
  ) {
    final mid = _s(box, a) + _len(box, a) / 2;
    SuRect? before, after;
    for (final b in band) {
      final bm = _s(b, a) + _len(b, a) / 2;
      if (bm < mid && _e(b, a) <= _s(box, a) + th) {
        if (before == null || _e(b, a) > _e(before, a)) before = b;
      } else if (bm > mid && _s(b, a) >= _e(box, a) - th) {
        if (after == null || _s(b, a) < _s(after, a)) after = b;
      }
    }
    return (before, after);
  }

  static Iterable<_Cand> _spacingCandidates(
    SuRect box,
    SnapTargets t,
    SnapAxis a,
    double th,
  ) sync* {
    final band = _band(box, t, a);
    if (band.isEmpty) return;
    final (before, after) = _neighbors(box, band, a, th);
    final len = _len(box, a);
    final start = _s(box, a);
    if (before != null && after != null) {
      final pos = (_e(before, a) + _s(after, a) - len) / 2;
      final g = pos - _e(before, a);
      if (g > epsilon && (pos - start).abs() <= th) {
        yield _Cand(pos - start, SnapSource.spacing, g);
      }
    }
    for (final (_, _, g) in _gaps(band, a)) {
      if (before != null) {
        final pos = _e(before, a) + g;
        if ((pos - start).abs() <= th) {
          yield _Cand(pos - start, SnapSource.spacing, g);
        }
      }
      if (after != null) {
        final pos = _s(after, a) - g - len;
        if ((pos - start).abs() <= th) {
          yield _Cand(pos - start, SnapSource.spacing, g);
        }
      }
    }
  }

  /// The equal-spacing indicator of a (snapped) box, or null.
  static SpacingGuide? _spacing(SuRect box, SnapTargets t, SnapAxis a) {
    if (!t.objects) return null;
    final band = _band(box, t, a);
    if (band.isEmpty) return null;
    final (before, after) = _neighbors(box, band, a, 0);
    final own = <(SuRect, SuRect, double)>[
      if (before != null) (before, box, _s(box, a) - _e(before, a)),
      if (after != null) (box, after, _s(after, a) - _e(box, a)),
    ].where((g) => g.$3 > epsilon).toList();
    if (own.isEmpty) return null;
    final others = _gaps(band, a);
    for (final (_, _, g) in own) {
      final equal = [
        for (final x in [...own, ...others])
          if ((x.$3 - g).abs() < epsilon) x,
      ];
      if (equal.length < 2) continue;
      return SpacingGuide(a, [
        for (final (p, q, _) in equal)
          SpacingGap(
            _e(p, a),
            _s(q, a),
            (math.max(_cs(p, a), _cs(q, a)) + math.min(_ce(p, a), _ce(q, a))) /
                2,
          ),
      ], g);
    }
    return null;
  }

  /// Alignment guides of [box] (already snapped) on axis [a]: every target
  /// line at one of [anchors].
  static List<SnapGuide> _guides(
    SuRect box,
    SnapTargets t,
    SnapAxis a,
    List<double> anchors,
  ) {
    final out = <SnapGuide>[];
    final done = <double>{};
    final lo = _cs(box, a), hi = _ce(box, a);
    for (final v in anchors) {
      final lines = t._range(a, v - epsilon, v + epsilon).toList();
      if (lines.isEmpty) continue;
      final at = lines.first.value;
      if (!done.add((at * 2).roundToDouble())) continue;
      // One guide per position: slide center lines span the slide; others
      // span between the aligned boxes.
      final center = lines.any((l) => l.source == SnapSource.slideCenter);
      final els = lines.where((l) => l.source == SnapSource.element).toList();
      if (center) {
        out.add(
          SnapGuide(
            a,
            at,
            a == SnapAxis.x ? t.slide.y : t.slide.x,
            a == SnapAxis.x ? t.slide.bottom : t.slide.right,
            source: SnapSource.slideCenter,
          ),
        );
      }
      if (els.isNotEmpty) {
        var from = lo, to = hi;
        final marks = <double>[lo, hi];
        for (final l in els) {
          from = math.min(from, l.lo);
          to = math.max(to, l.hi);
          marks
            ..add(l.lo)
            ..add(l.hi);
        }
        out.add(SnapGuide(a, at, from, to, marks: marks));
      } else if (!center && lines.any((l) => l.source == SnapSource.slide)) {
        out.add(
          SnapGuide(
            a,
            at,
            math.min(lo, a == SnapAxis.x ? t.slide.y : t.slide.x),
            math.max(hi, a == SnapAxis.x ? t.slide.bottom : t.slide.right),
            source: SnapSource.slide,
            marks: [lo, hi],
          ),
        );
      }
    }
    return out;
  }

  // -------------------------------------------------------------- resize

  /// Snaps the moving edges of a resized [box] ([left]/[right]/[top]/
  /// [bottom] say which edges follow the pointer): edges to target lines,
  /// and the width/height to other elements' sizes (equal size, 03 §5.1).
  static SnapResizeResult snapResize(
    SuRect box,
    SnapTargets t,
    double threshold, {
    bool left = false,
    bool right = false,
    bool top = false,
    bool bottom = false,
  }) {
    var l = box.x, r = box.right, tp = box.y, b = box.bottom;
    (double, SnapSource)? edge(SnapAxis a, double v, double fixed, bool end) {
      _Cand? best;
      for (final line in t._range(a, v - threshold, v + threshold)) {
        final c = _Cand(line.value - v, line.source);
        if (c.beats(best)) best = c;
      }
      for (final o in t.boxes) {
        final size = _len(o.rect, a);
        final target = end ? fixed + size : fixed - size;
        if ((target - v).abs() <= threshold) {
          final c = _Cand(target - v, SnapSource.size);
          if (c.beats(best)) best = c;
        }
      }
      return best == null ? null : (v + best.d, best.source);
    }

    var sx = false, sy = false;
    if (right != left) {
      final s = right
          ? edge(SnapAxis.x, r, l, true)
          : edge(SnapAxis.x, l, r, false);
      if (s != null) {
        sx = true;
        if (right) {
          r = s.$1;
        } else {
          l = s.$1;
        }
      }
    }
    if (bottom != top) {
      final s = bottom
          ? edge(SnapAxis.y, b, tp, true)
          : edge(SnapAxis.y, tp, b, false);
      if (s != null) {
        sy = true;
        if (bottom) {
          b = s.$1;
        } else {
          tp = s.$1;
        }
      }
    }
    final rect = SuRect(l, tp, r - l, b - tp);
    final guides = <SnapGuide>[
      if (right != left) ..._guides(rect, t, SnapAxis.x, [right ? r : l]),
      if (bottom != top) ..._guides(rect, t, SnapAxis.y, [bottom ? b : tp]),
    ];
    final sizes = <SizeMatch>[
      if (right != left)
        for (final o in t.boxes)
          if ((o.rect.width - rect.width).abs() < epsilon)
            SizeMatch(SnapAxis.x, o.rect),
      if (bottom != top)
        for (final o in t.boxes)
          if ((o.rect.height - rect.height).abs() < epsilon)
            SizeMatch(SnapAxis.y, o.rect),
    ];
    return SnapResizeResult(
      rect,
      guides: guides,
      sizes: sizes.isEmpty
          ? const []
          : [
              if (right != left && sizes.any((s) => s.axis == SnapAxis.x))
                SizeMatch(SnapAxis.x, rect),
              if (bottom != top && sizes.any((s) => s.axis == SnapAxis.y))
                SizeMatch(SnapAxis.y, rect),
              ...sizes,
            ],
      snappedX: sx,
      snappedY: sy,
    );
  }

  // --------------------------------------------------------------- point

  /// Snaps a line endpoint at ([x], [y]): to the nearest connection site
  /// of [SnapTargets.sites] within [threshold] (gluing, 03 §6.4), else
  /// each coordinate to target lines.
  static SnapPointResult snapPoint(
    double x,
    double y,
    SnapTargets t,
    double threshold, {
    bool glue = true,
  }) {
    if (glue) {
      SnapSite? best;
      var bestD = threshold;
      for (final s in t.sites) {
        final d = math.sqrt((s.x - x) * (s.x - x) + (s.y - y) * (s.y - y));
        if (d <= bestD) {
          best = s;
          bestD = d;
        }
      }
      if (best != null) return SnapPointResult(best.x, best.y, site: best);
    }
    double snap1(SnapAxis a, double v) {
      _Cand? best;
      for (final l in t._range(a, v - threshold, v + threshold)) {
        final c = _Cand(l.value - v, l.source);
        if (c.beats(best)) best = c;
      }
      return v + (best?.d ?? 0);
    }

    final sx = snap1(SnapAxis.x, x), sy = snap1(SnapAxis.y, y);
    final p = SuRect(sx, sy, 0, 0);
    return SnapPointResult(
      sx,
      sy,
      guides: [
        ..._guides(p, t, SnapAxis.x, [sx]),
        ..._guides(p, t, SnapAxis.y, [sy]),
      ],
    );
  }

  // ------------------------------------------------------------ rotation

  /// Snaps a rotation angle (degrees): with [shift] to 15° steps; else
  /// within 3° of 0/90/180/270 (03 §4.3); [free] (Mod) disables snapping.
  /// The result is normalized to `[0, 360)`.
  static double snapAngle(
    double degrees, {
    bool shift = false,
    bool free = false,
  }) {
    var d = degrees % 360;
    if (d < 0) d += 360;
    if (shift) {
      d = (d / 15).roundToDouble() * 15;
    } else if (!free) {
      final q = (d / 90).roundToDouble() * 90;
      if ((q - d).abs() <= 3) d = q;
    }
    d %= 360;
    return (d * 1e6).roundToDouble() / 1e6;
  }
}
