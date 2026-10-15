import 'dart:math' as math;
import 'dart:typed_data';

import '../reveal/chart_reveal.dart' show fadePrimitive;
import '../scene/geometry.dart';
import '../scene/path.dart';
import '../scene/scene.dart';
import 'oklab.dart';

/// Interpolates between two laid-out 2D chart scenes (Slides 08 §9.4): Magic Move between two
/// chart elements with the same `matchKey`, and the editor's animation when a linked chart is
/// updated.
///
/// Primitives are matched by their [SceneTag] (role, series key, point index, detail), their
/// type and their order among equal tags. Matched rects, arcs, polylines, markers and paths
/// with the same command structure interpolate their geometry; colors interpolate in OKLab;
/// texts with the same string move, other texts crossfade; unmatched primitives fade out
/// (from) or in (to). When fewer than [minDataMatch] of the data primitives (series, points,
/// data labels, trendlines) match — e.g. column → line — the whole scene crossfades instead
/// ([isCrossfade]).
///
/// 3D charts: the 3D group is crossfaded; morph the camera with `Chart3DView.lerp` and the
/// model with `ChartLayoutOptions.transitionFrom3D` (`Chart3DModel.lerp`) while laying out.
final class ChartSceneMorph {
  /// Prepares the morph from [from] to [to].
  ChartSceneMorph(this.from, this.to, {this.minDataMatch = 0.5}) {
    _a = _flatten(from);
    _b = _flatten(to);
    final byKey = <_Key, int>{};
    for (final (i, e) in _a.indexed) {
      byKey[e.key] = i;
    }
    var dataA = 0, dataB = 0, dataMatched = 0;
    for (final e in _a) {
      if (e.isData) dataA++;
    }
    for (final (j, e) in _b.indexed) {
      if (e.isData) dataB++;
      final i = byKey[e.key];
      if (i != null && _compatible(_a[i].p, e.p)) {
        _match[j] = i;
        _matchedA.add(i);
        if (e.isData) dataMatched++;
      }
    }
    final most = math.max(dataA, dataB);
    matchRatio = most == 0 ? 1 : dataMatched / most;
  }

  final ChartScene from;
  final ChartScene to;

  /// Fraction of data primitives that must match for a geometric morph.
  final double minDataMatch;

  /// Matched data primitives / data primitives of the larger scene (1 without data).
  late final double matchRatio;

  late final List<_Entry> _a;
  late final List<_Entry> _b;
  final Map<int, int> _match = {};
  final Set<int> _matchedA = {};

  /// Whether the scenes are too different to morph and crossfade instead.
  bool get isCrossfade => matchRatio < minDataMatch;

  /// The scene at [t] (0 = [from], 1 = [to]; already eased).
  ChartScene at(double t) {
    if (t <= 0) return from;
    if (t >= 1) return to;
    final w = from.width + (to.width - from.width) * t;
    final h = from.height + (to.height - from.height) * t;
    final bg = OkLab.lerp(from.background, to.background, t);
    if (isCrossfade) {
      return ChartScene(
        width: w,
        height: h,
        background: bg,
        primitives: [
          SGroup(from.primitives, opacity: 1 - t),
          SGroup(to.primitives, opacity: t),
        ],
        plotArea: _lerpRect(from.plotArea, to.plotArea, t),
      );
    }
    // From-only primitives are inserted after the output of their nearest matched
    // predecessor (so a fading gridline stays behind the data).
    final after = <int, List<int>>{};
    final outOf = <int, int>{};
    for (final e in _match.entries) {
      outOf[e.value] = e.key;
    }
    var anchor = -1;
    for (var i = 0; i < _a.length; i++) {
      if (_matchedA.contains(i)) {
        anchor = outOf[i]!;
      } else {
        (after[anchor] ??= []).add(i);
      }
    }
    final out = <ScenePrimitive>[];
    void fadeOut(int ai) {
      final e = _a[ai];
      final p = fadePrimitive(e.p, e.opacity * (1 - t));
      out.add(_clipped(p, e.clip));
    }

    for (final ai in after[-1] ?? const <int>[]) {
      fadeOut(ai);
    }
    for (var j = 0; j < _b.length; j++) {
      final e = _b[j];
      final i = _match[j];
      if (i == null) {
        out.add(_clipped(fadePrimitive(e.p, e.opacity * t), e.clip));
      } else {
        final a = _a[i];
        final o = a.opacity + (e.opacity - a.opacity) * t;
        final clip = _lerpRect(a.clip, e.clip, t);
        for (final p in _lerp(a.p, e.p, t)) {
          out.add(_clipped(fadePrimitive(p, o), clip));
        }
      }
      for (final ai in after[j] ?? const <int>[]) {
        fadeOut(ai);
      }
    }
    return ChartScene(
      width: w,
      height: h,
      background: bg,
      primitives: List.unmodifiable(out),
      plotArea: _lerpRect(from.plotArea, to.plotArea, t),
      threeD: to.threeD,
    );
  }

  // ---------------------------------------------------------------------------

  static ScenePrimitive _clipped(ScenePrimitive p, ChartRect? clip) =>
      clip == null ? p : SClip(clip, [p]);

  static List<_Entry> _flatten(ChartScene s) {
    final out = <_Entry>[];
    final seen = <(String, String), int>{};
    void walk(List<ScenePrimitive> list, double opacity, ChartRect? clip) {
      for (final p in list) {
        switch (p) {
          case SGroup(:final children, :final tag)
              when tag?.detail != ChartScene.chart3dGroupDetail:
            walk(children, opacity * p.opacity, clip);
            continue;
          case SClip(:final rect, :final children):
            final c = clip == null
                ? rect
                : (clip.intersect(rect) ?? ChartRect.zero);
            walk(children, opacity, c);
            continue;
          default:
            break;
        }
        final tagKey = p.tag == null ? '' : p.tag.toString();
        final type = p.typeId;
        final n = seen[(tagKey, type)] ?? 0;
        seen[(tagKey, type)] = n + 1;
        out.add(_Entry(p, opacity, clip, _Key(tagKey, type, n)));
      }
    }

    walk(s.primitives, 1, null);
    return out;
  }

  static bool _compatible(ScenePrimitive a, ScenePrimitive b) =>
      a is! SGroup && a.typeId == b.typeId; // 3D groups crossfade

  static double _l(double a, double b, double t) => a + (b - a) * t;

  static int? _color(int? a, int? b, double t) {
    if (a == null && b == null) return null;
    final ca = a ?? (b! & 0x00FFFFFF);
    final cb = b ?? (a! & 0x00FFFFFF);
    return OkLab.lerp(ca, cb, t);
  }

  static ChartRect? _lerpRect(ChartRect? a, ChartRect? b, double t) {
    if (a == null || b == null) return t < 0.5 ? a : b;
    return ChartRect(
      _l(a.left, b.left, t),
      _l(a.top, b.top, t),
      _l(a.width, b.width, t),
      _l(a.height, b.height, t),
    );
  }

  static SStroke? _stroke(SStroke? a, SStroke? b, double t) {
    if (a == null && b == null) return null;
    final sa = a ?? SStroke(b!.color & 0x00FFFFFF, width: b.width);
    final sb = b ?? SStroke(a!.color & 0x00FFFFFF, width: a.width);
    return SStroke(
      OkLab.lerp(sa.color, sb.color, t),
      width: _l(sa.width, sb.width, t),
      dash: t < 0.5 ? sa.dash : sb.dash,
      cap: sb.cap,
      join: sb.join,
    );
  }

  /// [a] → [b] at [t]: one primitive, or two for a crossfade.
  static List<ScenePrimitive> _lerp(
    ScenePrimitive a,
    ScenePrimitive b,
    double t,
  ) {
    switch ((a, b)) {
      case (final SRect a, final SRect b):
        return [
          SRect(
            _lerpRect(a.rect, b.rect, t)!,
            fill: _color(a.fill, b.fill, t),
            stroke: _stroke(a.stroke, b.stroke, t),
            radius: _l(a.radius, b.radius, t),
            tag: b.tag,
          ),
        ];
      case (final SArc a, final SArc b):
        return [
          SArc(
            ChartPoint(
              _l(a.center.x, b.center.x, t),
              _l(a.center.y, b.center.y, t),
            ),
            _l(a.radius, b.radius, t),
            _l(a.start, b.start, t),
            _l(a.sweep, b.sweep, t),
            innerRadius: _l(a.innerRadius, b.innerRadius, t),
            fill: _color(a.fill, b.fill, t),
            stroke: _stroke(a.stroke, b.stroke, t),
            tag: b.tag,
          ),
        ];
      case (final SPolyline a, final SPolyline b):
        final n = math.max(a.length, b.length);
        final xa = _resample(a.xy, n), xb = _resample(b.xy, n);
        return [
          SPolyline(
            Float64List.fromList([
              for (var i = 0; i < xa.length; i++) _l(xa[i], xb[i], t),
            ]),
            _stroke(a.stroke, b.stroke, t)!,
            indices: b.length == n ? b.indices : null,
            tag: b.tag,
          ),
        ];
      case (final SMarkers a, final SMarkers b):
        return [_markers(a, b, t)];
      case (final SPath a, final SPath b) when _sameStructure(a.cmds, b.cmds):
        return [
          SPath(
            [
              for (var i = 0; i < a.cmds.length; i++)
                _cmd(a.cmds[i], b.cmds[i], t),
            ],
            fill: _color(a.fill, b.fill, t),
            stroke: _stroke(a.stroke, b.stroke, t),
            evenOdd: b.evenOdd,
            gradient: a.gradient != null && b.gradient != null
                ? SGradient(
                    _l(a.gradient!.x0, b.gradient!.x0, t),
                    _l(a.gradient!.y0, b.gradient!.y0, t),
                    _l(a.gradient!.x1, b.gradient!.x1, t),
                    _l(a.gradient!.y1, b.gradient!.y1, t),
                    OkLab.lerp(a.gradient!.color0, b.gradient!.color0, t),
                    OkLab.lerp(a.gradient!.color1, b.gradient!.color1, t),
                  )
                : b.gradient,
            tag: b.tag,
          ),
        ];
      case (final SText a, final SText b)
          when a.text == b.text && a.angle == b.angle && a.anchor == b.anchor:
        final size = _l(a.style.size, b.style.size, t);
        return [
          SText(
            b.text,
            ChartPoint(_l(a.at.x, b.at.x, t), _l(a.at.y, b.at.y, t)),
            b.style.copyWith(
              size: size,
              color: OkLab.lerp(a.style.color, b.style.color, t),
            ),
            anchor: b.anchor,
            angle: b.angle,
            width: _l(a.width, b.width, t),
            height: _l(a.height, b.height, t),
            ascent: _l(a.ascent, b.ascent, t),
            tag: b.tag,
          ),
        ];
      default:
        return [fadePrimitive(a, 1 - t), fadePrimitive(b, t)];
    }
  }

  static bool _sameStructure(List<PathCmd> a, List<PathCmd> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].runtimeType != b[i].runtimeType) return false;
    }
    return true;
  }

  static PathCmd _cmd(PathCmd a, PathCmd b, double t) => switch ((a, b)) {
    (final PMoveTo p, final PMoveTo q) => PMoveTo(
      _l(p.x, q.x, t),
      _l(p.y, q.y, t),
    ),
    (final PLineTo p, final PLineTo q) => PLineTo(
      _l(p.x, q.x, t),
      _l(p.y, q.y, t),
    ),
    (final PCubicTo p, final PCubicTo q) => PCubicTo(
      _l(p.x1, q.x1, t),
      _l(p.y1, q.y1, t),
      _l(p.x2, q.x2, t),
      _l(p.y2, q.y2, t),
      _l(p.x, q.x, t),
      _l(p.y, q.y, t),
    ),
    _ => b,
  };

  /// [xy] resampled to [n] vertices evenly along its vertex parameter.
  static Float64List _resample(Float64List xy, int n) {
    final m = xy.length ~/ 2;
    if (m == n || m == 0) return xy;
    final out = Float64List(n * 2);
    for (var k = 0; k < n; k++) {
      final u = n == 1 ? 0.0 : k * (m - 1) / (n - 1);
      final i = u.floor().clamp(0, m - 1);
      final j = math.min(i + 1, m - 1);
      final f = u - i;
      out[2 * k] = _l(xy[2 * i], xy[2 * j], f);
      out[2 * k + 1] = _l(xy[2 * i + 1], xy[2 * j + 1], f);
    }
    return out;
  }

  static SMarkers _markers(SMarkers a, SMarkers b, double t) {
    final ka = <int, int>{
      for (var k = 0; k < a.length; k++) a.pointIndexOf(k): k,
    };
    final usedA = <int>{};
    final xy = <double>[];
    final sizes = <double>[];
    final fills = <int>[];
    final idx = <int>[];
    for (var k = 0; k < b.length; k++) {
      final i = b.pointIndexOf(k);
      final j = ka[i];
      if (j != null) {
        usedA.add(j);
        xy
          ..add(_l(a.xy[2 * j], b.xy[2 * k], t))
          ..add(_l(a.xy[2 * j + 1], b.xy[2 * k + 1], t));
        sizes.add(_l(a.sizeOf(j), b.sizeOf(k), t));
        fills.add(OkLab.lerp(a.fillOf(j), b.fillOf(k), t));
      } else {
        xy
          ..add(b.xy[2 * k])
          ..add(b.xy[2 * k + 1]);
        sizes.add(b.sizeOf(k) * t);
        fills.add(b.fillOf(k));
      }
      idx.add(i);
    }
    for (var j = 0; j < a.length; j++) {
      if (usedA.contains(j)) continue;
      xy
        ..add(a.xy[2 * j])
        ..add(a.xy[2 * j + 1]);
      sizes.add(a.sizeOf(j) * (1 - t));
      fills.add(a.fillOf(j));
      idx.add(a.pointIndexOf(j));
    }
    return SMarkers(
      Float64List.fromList(xy),
      b.shape,
      b.size,
      fill: b.fill,
      stroke: _stroke(a.stroke, b.stroke, t),
      indices: Int32List.fromList(idx),
      sizes: Float64List.fromList(sizes),
      fills: Int32List.fromList(fills),
      tag: b.tag,
    );
  }
}

final class _Key {
  const _Key(this.tag, this.type, this.n);

  final String tag;
  final String type;
  final int n;

  @override
  bool operator ==(Object other) =>
      other is _Key && other.tag == tag && other.type == type && other.n == n;

  @override
  int get hashCode => Object.hash(tag, type, n);
}

final class _Entry {
  _Entry(this.p, this.opacity, this.clip, this.key);

  final ScenePrimitive p;
  final double opacity;
  final ChartRect? clip;
  final _Key key;

  bool get isData => switch (p.tag?.role) {
    SceneRole.series ||
    SceneRole.point ||
    SceneRole.dataLabel ||
    SceneRole.trendline => true,
    _ => false,
  };
}
