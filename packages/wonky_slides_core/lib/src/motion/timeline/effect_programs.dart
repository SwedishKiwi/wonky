part of 'slide_timeline.dart';

// Effect programs (06 §9.2): pure functions from progress, parameters and
// element geometry to channel values. In and out effects are evaluated with
// the in-program at "in progress" q (0 = before, 1 = built); out effects
// mirror their in effect at q = 1 − eased progress (06 §3.2).

/// Channel values of one running effect.
final class _Chan {
  double opacity = 1;

  /// Slide-space (element) / local (part) translation (su).
  double dx = 0, dy = 0;
  double sx = 1, sy = 1;

  /// Degrees.
  double rot = 0, rotX = 0, rotY = 0;
  double perspective = 0;

  /// Anchor of scale/rotation as a fraction of the box.
  double ax = 0.5, ay = 0.5;
  ClipSpec? clip;
  double blur = 0;
  double? dissolve;
  double? draw;
  bool drawReverse = false;
  double? fill;

  /// Typewriter: fraction of the reveal time elapsed (0..1).
  double? reveal;

  /// Chart grow 0..1.
  double? grow;

  /// Code type-in 0..1.
  double? typing;

  bool get hasMatrix =>
      sx != 1 || sy != 1 || rot != 0 || rotX != 0 || rotY != 0;

  /// `T(anchor)·P·Rx·Ry·Rz·S·T(−anchor)` for [box] (no translation).
  Matrix4 matrix(SuRect box) {
    final px = box.x + ax * box.width, py = box.y + ay * box.height;
    final m = Matrix4.identity()..translateByDouble(px, py, 0, 1);
    if (perspective != 0 && (rotX != 0 || rotY != 0)) {
      final p = Matrix4.identity()..setEntry(3, 2, -perspective);
      m.multiply(p);
    }
    if (rotX != 0) m.rotateX(rotX * math.pi / 180);
    if (rotY != 0) m.rotateY(rotY * math.pi / 180);
    if (rot != 0) m.rotateZ(rot * math.pi / 180);
    if (sx != 1 || sy != 1) m.scaleByDouble(sx, sy, 1, 1);
    m.translateByDouble(-px, -py, 0, 1);
    return m;
  }
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

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

bool _bool(Map<String, Object?> p, String key, bool orElse) {
  final v = p[key];
  return v is bool ? v : orElse;
}

/// The context of a program: parameters (catalog defaults applied), the box
/// the channels apply to, the element frame and the slide size.
final class _Ctx {
  _Ctx(this.params, this.box, this.frame, this.slideW, this.slideH);

  final Map<String, Object?> params;
  final SuRect box;
  final SuRect frame;
  final double slideW, slideH;
}

/// The off-slide distance of the element toward [direction] (positive
/// components point away from the slide center along the direction).
(double, double) _offSlide(_Ctx c, String direction) {
  final f = c.frame;
  final left = -(f.x + f.width), right = c.slideW - f.x;
  final top = -(f.y + f.height), bottom = c.slideH - f.y;
  return switch (direction) {
    'right' => (right, 0.0),
    'top' => (0.0, top),
    'bottom' => (0.0, bottom),
    'topLeft' => (left, top),
    'topRight' => (right, top),
    'bottomLeft' => (left, bottom),
    'bottomRight' => (right, bottom),
    _ => (left, 0.0),
  };
}

(double, double) _dirVector(String direction, double d) {
  const s = math.sqrt1_2;
  return switch (direction) {
    'right' => (d, 0.0),
    'top' => (0.0, -d),
    'bottom' => (0.0, d),
    'topLeft' => (-d * s, -d * s),
    'topRight' => (d * s, -d * s),
    'bottomLeft' => (-d * s, d * s),
    'bottomRight' => (d * s, d * s),
    _ => (-d, 0.0),
  };
}

/// Evaluates in-effect [id] at in-progress [q] into [out]. Unknown ids
/// play as fade.
void _evalIn(String id, double q, _Ctx c, _Chan out) {
  final p = c.params;
  final fadeQ = _clamp01(q);
  switch (id) {
    case 'appear':
      out.opacity = 1;
    case 'rise':
      out.dy = _num(p, 'distance', 40) * (1 - q);
      if (_bool(p, 'fade', true)) out.opacity = fadeQ;
    case 'moveIn':
      final dir = p['direction'] as String? ?? 'left';
      final dist = p['distance'];
      final (vx, vy) = dist is num
          ? _dirVector(dir, dist.toDouble())
          : _offSlide(c, dir);
      out.dx = vx * (1 - q);
      out.dy = vy * (1 - q);
      if (_bool(p, 'fade', false)) out.opacity = fadeQ;
    case 'scale':
      final from = _num(p, 'from', 0.5);
      out.sx = out.sy = from + (1 - from) * q;
      final (ax, ay) = _anchor(p['origin']);
      out
        ..ax = ax
        ..ay = ay;
      if (_bool(p, 'fade', true)) out.opacity = fadeQ;
    case 'pop':
      final from = _num(p, 'from', 0);
      out.sx = out.sy = math.max(0, from + (1 - from) * q);
      out.opacity = _clamp01(q * 4);
    case 'zoom':
      final from = _num(p, 'from', 3);
      out.sx = out.sy = from + (1 - from) * q;
      if (_bool(p, 'fade', true)) out.opacity = fadeQ;
    case 'blur':
      out.blur = math.max(0, _num(p, 'from', 24) * (1 - q));
      if (_bool(p, 'fade', true)) out.opacity = fadeQ;
    case 'wipe':
      out.clip = ClipSpec(
        kind: 'wipe',
        progress: fadeQ,
        direction: p['direction'] as String? ?? 'left',
        softness: _num(p, 'softness', 0.2),
      );
    case 'iris':
      final (ox, oy) = _anchor(p['origin']);
      out.clip = ClipSpec(
        kind: 'iris',
        progress: fadeQ,
        shape: p['shape'] as String? ?? 'circle',
        originX: ox,
        originY: oy,
      );
    case 'dissolve':
      out.dissolve = fadeQ;
    case 'drop':
      final h = p['height'];
      final height = h is num ? h.toDouble() : c.frame.y + c.frame.height;
      out.dy = -height * _dropHeight(fadeQ, (_num(p, 'bounces', 2)).round());
    case 'flip':
      final sign = p['direction'] == 'backward' ? -1.0 : 1.0;
      final angle = sign * 90 * (1 - q);
      if (p['axis'] == 'x') {
        out.rotX = angle;
      } else {
        out.rotY = angle;
      }
      out.perspective = _num(p, 'perspective', 0.0012);
    case 'rotate':
      out.rot = _num(p, 'angle', -90) * (1 - q);
      final s = _num(p, 'scale', 1);
      out.sx = out.sy = s + (1 - s) * q;
      final (ax, ay) = _anchor(p['origin']);
      out
        ..ax = ax
        ..ay = ay;
      if (_bool(p, 'fade', true)) out.opacity = fadeQ;
    case 'typewriter':
      out.reveal = fadeQ;
    case 'lineDraw':
      final delay = _num(p, 'fillDelay', 0.6);
      out.draw = fadeQ;
      out.drawReverse = p['direction'] == 'backward';
      out.fill = delay >= 1
          ? (q >= 1 ? 1 : 0)
          : _clamp01((q - delay) / (1 - delay));
    case 'chartGrow':
      out.grow = fadeQ;
    case 'codeType':
      out.typing = fadeQ;
    default: // fade and unknown
      out.opacity = fadeQ;
  }
}

/// Height (fraction of the drop height) of a body dropped from rest with
/// restitution 0.4 and [bounces] bounces, at normalized time [q].
double _dropHeight(double q, int bounces) {
  const e = 0.4;
  // Units: h = 1, g = 2 → fall time 1, impact speed 2; a bounce with
  // speed v lasts v (time 2v/g).
  var total = 1.0;
  var v = 2.0;
  for (var i = 0; i < bounces; i++) {
    v *= e;
    total += v;
  }
  var t = q * total;
  if (t < 1) return 1 - t * t;
  t -= 1;
  v = 2.0;
  for (var i = 0; i < bounces; i++) {
    v *= e;
    if (t < v) return v * t - t * t;
    t -= v;
  }
  return 0;
}

/// Evaluates out effect [id] (mirror [mirror]) at eased out-progress [e].
void _evalOut(String id, String? mirror, double e, _Ctx c, _Chan out) {
  final p = c.params;
  switch (id) {
    case 'popOut':
      final a = _num(p, 'anticipation', 0.08);
      final to = _num(p, 'to', 0);
      final s = e < 0.2
          ? 1 + a * (e / 0.2)
          : (1 + a) + (to - 1 - a) * ((e - 0.2) / 0.8);
      out.sx = out.sy = math.max(0, s);
      out.opacity = _clamp01((1 - e) * 4);
    case 'fall':
      final h = p['height'];
      final height = h is num ? h.toDouble() : c.slideH - c.frame.y;
      out.dy = height * e * e;
      out.rot = _num(p, 'rotation', 15) * e;
    case 'scaleOut' || 'zoomOut':
      final params = {...p, 'from': p['to'] ?? (id == 'zoomOut' ? 3 : 0.5)};
      _evalIn(
        mirror ?? 'fade',
        1 - e,
        _Ctx(params, c.box, c.frame, c.slideW, c.slideH),
        out,
      );
    default:
      _evalIn(mirror ?? 'fade', 1 - e, c, out);
  }
}

/// Evaluates transient emphasis [id] at eased progress [e] (0..1 of one
/// play).
void _evalEmphasis(String id, double e, _Ctx c, _Chan out) {
  final p = c.params;
  final count = math.max(1, _num(p, 'count', 1).round());
  final phase = (e * count) % 1.0;
  switch (id) {
    case 'pulse':
      final s = 1 + (_num(p, 'scale', 1.1) - 1) * math.sin(math.pi * phase);
      out.sx = out.sy = s;
    case 'bounce':
      out.dy = -_num(p, 'height', 40) * 4 * phase * (1 - phase);
    case 'shake':
      final a =
          _num(p, 'amplitude', 12) *
          math.sin(2 * math.pi * count * e) *
          (1 - e);
      if (p['axis'] == 'y') {
        out.dy = a;
      } else {
        out.dx = a;
      }
    case 'blink':
      out.opacity = (e * count * 2).floor().isEven ? 0 : 1;
  }
}
