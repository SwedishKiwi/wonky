/// The snapshot transition programs (06 §7.2, §12.2): pure functions from
/// eased progress `p` (0 = the outgoing slide, 1 = the incoming slide) to
/// the quads of a frame. 3D types use a camera at 2.2 × the slide width
/// (perspective entry `(3, 2) = −1 / (2.2 × width)`, +z toward the viewer,
/// the timeline's convention), cull back faces and shade faces turned away
/// by up to 12 %.
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector4;

import '../../theme/model/common.dart' show SuRect;
import '../timeline/slide_frame.dart';
import 'transition_frame.dart';

const _out = TransitionLayer.outgoing;
const _in = TransitionLayer.incoming;

/// Maximum shading of a face turned edge-on (06 §7.2).
const double faceShade = 0.12;

/// Snapshot frame of [type] at eased progress [p] (forward direction).
/// Unknown types play as `fade`.
(List<TransitionQuad>, int?) snapshotQuads(
  String type,
  Map<String, Object?> params,
  double p,
  double w,
  double h, {
  int seed = 0,
  int? throughColor,
}) {
  final dir = params['direction'] is String
      ? params['direction']! as String
      : 'left';
  switch (type) {
    case 'none':
      return ([TransitionQuad(layer: p >= 1 ? _in : _out)], null);
    case 'dissolve':
      return (
        [
          TransitionQuad(layer: _out),
          TransitionQuad(
            layer: _in,
            dissolve: DissolveState(p, seed, _num(params, 'cell', 8)),
            visible: p > 0,
          ),
        ],
        null,
      );
    case 'push':
      final (dx, dy) = _vector(dir);
      return (
        [
          TransitionQuad(layer: _out, transform: _t(dx * w * p, dy * h * p)),
          TransitionQuad(
            layer: _in,
            transform: _t(-dx * w * (1 - p), -dy * h * (1 - p)),
          ),
        ],
        null,
      );
    case 'slide' || 'cover':
      final (dx, dy) = _vector(dir);
      return (
        [
          TransitionQuad(layer: _out, shade: type == 'cover' ? 0.2 * p : 0),
          TransitionQuad(
            layer: _in,
            transform: _t(-dx * w * (1 - p), -dy * h * (1 - p)),
          ),
        ],
        null,
      );
    case 'uncover':
      final (dx, dy) = _vector(dir);
      return (
        [
          TransitionQuad(layer: _in),
          TransitionQuad(layer: _out, transform: _t(dx * w * p, dy * h * p)),
        ],
        null,
      );
    case 'wipe':
      return (
        [
          TransitionQuad(layer: _out),
          TransitionQuad(
            layer: _in,
            clip: ClipSpec(
              kind: 'wipe',
              progress: p,
              direction: dir,
              softness: _num(params, 'softness', 0.15),
            ),
            visible: p > 0,
          ),
        ],
        null,
      );
    case 'iris':
      final (ox, oy) = _anchor(params['origin']);
      return (
        [
          TransitionQuad(layer: _out),
          TransitionQuad(
            layer: _in,
            clip: ClipSpec(
              kind: 'iris',
              progress: p,
              shape: params['shape'] is String
                  ? params['shape']! as String
                  : 'circle',
              originX: ox,
              originY: oy,
            ),
            visible: p > 0,
          ),
        ],
        null,
      );
    case 'zoom':
      final (ox, oy) = _anchor(params['origin']);
      if (params['mode'] == 'out') {
        final s = 1 - 0.75 * p;
        final o = 1 - _clamp01((p - 0.6) / 0.4);
        return (
          [
            TransitionQuad(layer: _in),
            TransitionQuad(
              layer: _out,
              transform: _scaleAbout(ox * w, oy * h, s),
              opacity: o,
              visible: o > 0,
            ),
          ],
          null,
        );
      }
      final s = 0.25 + 0.75 * p;
      final o = _clamp01(p / 0.4);
      return (
        [
          TransitionQuad(layer: _out),
          TransitionQuad(
            layer: _in,
            transform: _scaleAbout(ox * w, oy * h, s),
            opacity: o,
            visible: o > 0,
          ),
        ],
        null,
      );
    case 'flip':
      return (_flip(params['axis'] == 'x', dir, p, w, h), null);
    case 'cube':
      return (_cube(dir, p, w, h), null);
    case 'doorway':
      return (_doorway(p, w, h), null);
    case 'swap':
      return (_swap(dir, p, w, h), null);
    case 'revolve':
      return (_revolve(dir, p, w, h), null);
    default: // fade (and unknown/unavailable types)
      if (throughColor != null) {
        final o = _clamp01(1 - 2 * p), n = _clamp01(2 * p - 1);
        return (
          [
            TransitionQuad(layer: _out, opacity: o, visible: o > 0),
            TransitionQuad(layer: _in, opacity: n, visible: n > 0),
          ],
          throughColor,
        );
      }
      return (
        [
          TransitionQuad(layer: _out),
          TransitionQuad(layer: _in, opacity: p, visible: p > 0),
        ],
        null,
      );
  }
}

// -----------------------------------------------------------------------
// 3D programs

/// `T(c)·P·T(−c)·body`: [body] (a 3D transform in slide space) seen by the
/// camera at 2.2 × [w] in front of the slide center.
Matrix4 _view(double w, double h, Matrix4 body) {
  final m = Matrix4.identity()..translateByDouble(w / 2, h / 2, 0, 1);
  m.multiply(Matrix4.identity()..setEntry(3, 2, -1 / (2.2 * w)));
  m.translateByDouble(-w / 2, -h / 2, 0, 1);
  return m..multiply(body);
}

/// A rotation of [deg] degrees about the axis through ([px], [py], [pz])
/// parallel to y ([vertical]) or x, after a translation by [tz].
Matrix4 _rotAbout(
  bool vertical,
  double deg,
  double px,
  double py,
  double pz, {
  double tx = 0,
  double ty = 0,
  double tz = 0,
}) {
  final a = deg * math.pi / 180;
  final m = Matrix4.identity()..translateByDouble(px + tx, py + ty, pz + tz, 1);
  if (vertical) {
    m.rotateY(a);
  } else {
    m.rotateX(a);
  }
  return m..translateByDouble(-px, -py, -pz, 1);
}

/// Whether the quad [region] (or the slide) faces the viewer under [m]:
/// every corner in front of the camera and a clockwise (screen) winding.
bool frontFacing(Matrix4 m, SuRect region) {
  final xs = [region.x, region.right, region.right, region.x];
  final ys = [region.y, region.y, region.bottom, region.bottom];
  final px = <double>[], py = <double>[];
  for (var i = 0; i < 4; i++) {
    final v = m.transformed(Vector4(xs[i], ys[i], 0, 1));
    if (v.w <= 1e-9) return false;
    px.add(v.x / v.w);
    py.add(v.y / v.w);
  }
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final j = (i + 1) % 4;
    area += px[i] * py[j] - px[j] * py[i];
  }
  return area > 1e-6 * region.width * region.height;
}

double _shadeOf(double deg) =>
    faceShade * (1 - math.cos(deg.abs().clamp(0, 90) * math.pi / 180));

List<TransitionQuad> _flip(
  bool axisX,
  String dir,
  double p,
  double w,
  double h,
) {
  // Rotation sign: the card turns toward [dir].
  final s = switch (dir) {
    'right' || 'down' => 1.0,
    _ => -1.0,
  };
  final span = axisX ? h : w;
  final push = -0.5 * span * math.sin(math.pi * p);
  final front = s * 180 * p;
  final back = front - s * 180;
  final full = SuRect(0, 0, w, h);
  Matrix4 m(double deg) => _view(
    w,
    h,
    _rotAbout(!axisX, axisX ? -deg : deg, w / 2, h / 2, 0, tz: push),
  );
  final mo = m(front), mi = m(back);
  return [
    TransitionQuad(
      layer: _out,
      transform: mo,
      shade: _shadeOf(front),
      visible: p < 0.5 && frontFacing(mo, full),
    ),
    TransitionQuad(
      layer: _in,
      transform: mi,
      shade: _shadeOf(back),
      visible: p >= 0.5 && frontFacing(mi, full),
    ),
  ];
}

List<TransitionQuad> _cube(String dir, double p, double w, double h) {
  final vertical = dir == 'up' || dir == 'down';
  final d = (vertical ? h : w) / 2;
  final push = -0.25 * w * math.sin(math.pi * p);
  // Angles of the outgoing / incoming faces (see 06 §12.2: the slides are
  // two faces of a cube rotating 90° about its center axis).
  final (ao, ai) = switch (dir) {
    'right' => (90 * p, -90 * (1 - p)),
    'up' => (90 * p, -90 * (1 - p)),
    'down' => (-90 * p, 90 * (1 - p)),
    _ => (-90 * p, 90 * (1 - p)),
  };
  Matrix4 m(double deg) =>
      _view(w, h, _rotAbout(!vertical, deg, w / 2, h / 2, -d, tz: push));
  final full = SuRect(0, 0, w, h);
  final mo = m(ao), mi = m(ai);
  return [
    TransitionQuad(
      layer: _out,
      transform: mo,
      shade: _shadeOf(ao),
      visible: frontFacing(mo, full),
    ),
    TransitionQuad(
      layer: _in,
      transform: mi,
      shade: _shadeOf(ai),
      visible: frontFacing(mi, full),
    ),
  ];
}

List<TransitionQuad> _doorway(double p, double w, double h) {
  final s = 0.6 + 0.4 * p;
  final open = 75 * p;
  final o = 1 - _clamp01((p - 0.6) / 0.4);
  final left = SuRect(0, 0, w / 2, h), right = SuRect(w / 2, 0, w / 2, h);
  final ml = _view(w, h, _rotAbout(true, -open, 0, h / 2, 0));
  final mr = _view(w, h, _rotAbout(true, open, w, h / 2, 0));
  return [
    TransitionQuad(
      layer: _in,
      transform: _scaleAbout(w / 2, h / 2, s),
      shade: 0.4 * (1 - p),
    ),
    TransitionQuad(
      layer: _out,
      transform: ml,
      region: left,
      opacity: o,
      shade: _shadeOf(open),
      visible: o > 0 && frontFacing(ml, left),
    ),
    TransitionQuad(
      layer: _out,
      transform: mr,
      region: right,
      opacity: o,
      shade: _shadeOf(open),
      visible: o > 0 && frontFacing(mr, right),
    ),
  ];
}

List<TransitionQuad> _swap(String dir, double p, double w, double h) {
  final (vx, vy) = _vector(dir);
  final a = math.sin(math.pi * p);
  final depth = 0.7 * w;
  final vertical = vy != 0;
  Matrix4 m(double sign, double back) {
    final tx = sign * vx * 0.55 * w * a, ty = sign * vy * 0.55 * h * a;
    final deg = sign * 25 * a * (vertical ? -vy : vx);
    return _view(
      w,
      h,
      _rotAbout(!vertical, deg, w / 2, h / 2, 0, tx: tx, ty: ty, tz: -back),
    );
  }

  final mo = m(1, depth * p), mi = m(-1, depth * (1 - p));
  final out = TransitionQuad(layer: _out, transform: mo, shade: faceShade * p);
  final inc = TransitionQuad(
    layer: _in,
    transform: mi,
    shade: faceShade * (1 - p),
  );
  return p < 0.5 ? [inc, out] : [out, inc];
}

List<TransitionQuad> _revolve(String dir, double p, double w, double h) {
  // The outgoing slide swings away (into the screen) on its leading edge.
  final (vertical, px, py, deg) = switch (dir) {
    'right' => (true, w, h / 2, -90 * p),
    'up' => (false, w / 2, 0.0, -90 * p),
    'down' => (false, w / 2, h, 90 * p),
    _ => (true, 0.0, h / 2, 90 * p),
  };
  final m = _view(w, h, _rotAbout(vertical, deg, px, py, 0));
  final o = 1 - _clamp01((p - 0.7) / 0.3);
  return [
    TransitionQuad(layer: _in, shade: 0.2 * (1 - p)),
    TransitionQuad(
      layer: _out,
      transform: m,
      opacity: o,
      shade: _shadeOf(deg),
      visible: o > 0 && frontFacing(m, SuRect(0, 0, w, h)),
    ),
  ];
}

// -----------------------------------------------------------------------
// Helpers

Matrix4 _t(double dx, double dy) =>
    Matrix4.identity()..translateByDouble(dx, dy, 0, 1);

Matrix4 _scaleAbout(double x, double y, double s) => Matrix4.identity()
  ..translateByDouble(x, y, 0, 1)
  ..scaleByDouble(s, s, 1, 1)
  ..translateByDouble(-x, -y, 0, 1);

/// The direction the slides move: `left` = toward the left (the new slide
/// comes from the right).
(double, double) _vector(String dir) => switch (dir) {
  'right' => (1.0, 0.0),
  'up' => (0.0, -1.0),
  'down' => (0.0, 1.0),
  _ => (-1.0, 0.0),
};

(double, double) _anchor(Object? origin) => switch (origin) {
  'top' => (0.5, 0.0),
  'bottom' => (0.5, 1.0),
  'left' => (0.0, 0.5),
  'right' => (1.0, 0.5),
  'topLeft' => (0.0, 0.0),
  'topRight' => (1.0, 0.0),
  'bottomLeft' => (0.0, 1.0),
  'bottomRight' => (1.0, 1.0),
  _ => (0.5, 0.5),
};

double _num(Map<String, Object?> p, String key, double orElse) {
  final v = p[key];
  return v is num ? v.toDouble() : orElse;
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
