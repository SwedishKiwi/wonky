/// The easing grammar of builds and transitions (06 §4.3): CSS and Penner
/// curves, `cubic(x1,y1,x2,y2)`, `spring(d,b)` in closed form and
/// `steps(n)`. Pure functions of their arguments (deterministic).
library;

import 'dart:math' as math;

/// An easing curve parsed from an expression (`SlideBuild.easing`,
/// `transitionJson.easing`).
sealed class MotionEasing {
  const MotionEasing();

  /// Parses [expression]. Throws [FormatException] for unknown names and
  /// malformed arguments.
  factory MotionEasing.parse(String expression) {
    final e = expression.trim();
    final named = NamedEasing._byName[e];
    if (named != null) return named;
    final call = RegExp(r'^([a-zA-Z]+)\s*\((.*)\)$').firstMatch(e);
    if (call == null) {
      throw FormatException('Unknown easing "$expression"', expression);
    }
    final name = call.group(1)!;
    final args = <double>[];
    final raw = call.group(2)!.trim();
    if (raw.isNotEmpty) {
      for (final a in raw.split(',')) {
        final v = double.tryParse(a.trim());
        if (v == null || !v.isFinite) {
          throw FormatException('Bad easing argument "$a"', expression);
        }
        args.add(v);
      }
    }
    switch (name) {
      case 'cubic':
        if (args.length != 4) {
          throw FormatException('cubic() takes 4 arguments', expression);
        }
        if (args[0] < 0 || args[0] > 1 || args[2] < 0 || args[2] > 1) {
          throw FormatException('cubic() x values must be 0–1', expression);
        }
        return CubicEasing(args[0], args[1], args[2], args[3]);
      case 'spring':
        if (args.length != 2) {
          throw FormatException('spring() takes 2 arguments', expression);
        }
        if (args[0] <= 0 || args[0] > 20) {
          throw FormatException('spring() duration must be 0–20 s', expression);
        }
        if (args[1] < -1 || args[1] > 1) {
          throw FormatException('spring() bounce must be −1…1', expression);
        }
        return SpringEasing(args[0], args[1]);
      case 'steps':
        if (args.length != 1 ||
            args[0] < 1 ||
            args[0] != args[0].roundToDouble()) {
          throw FormatException('steps() takes a positive integer', expression);
        }
        return StepsEasing(args[0].toInt());
    }
    throw FormatException('Unknown easing "$expression"', expression);
  }

  /// [MotionEasing.parse], or null when [expression] is null or invalid.
  static MotionEasing? tryParse(String? expression) {
    if (expression == null) return null;
    try {
      return MotionEasing.parse(expression);
    } on FormatException {
      return null;
    }
  }

  /// `linear`.
  static const linear = NamedEasing._('linear', _linear);

  /// Jumps to the end immediately (reduced-motion "instant" effects; not
  /// part of the grammar).
  static const jump = NamedEasing._('jump', _jump);

  /// The canonical expression.
  String get expression;

  /// The eased value at progress [t] (0..1; values may overshoot for back
  /// and spring curves). `transform(0) == 0`, `transform(1) == 1`.
  double transform(double t);

  /// The curve bound to a build of [durationMs]: for springs the duration
  /// is the perceptual duration and the effective length is the settle
  /// time (06 §4.3); other curves keep [durationMs].
  BoundEasing bind(int durationMs) => BoundEasing(this, durationMs);

  @override
  String toString() => expression;
}

/// An easing bound to a duration: what a scheduled effect evaluates.
final class BoundEasing {
  /// Binds [easing] to [durationMs].
  const BoundEasing(this.easing, this.durationMs);

  /// The curve (springs: with their effective perceptual duration).
  final MotionEasing easing;

  /// Effective length in ms (springs: the settle time).
  final int durationMs;

  /// The eased value at [localMs] into the effect (clamped to the
  /// effect's length).
  double at(num localMs) {
    if (durationMs <= 0) return 1;
    if (localMs <= 0) return 0;
    if (localMs >= durationMs) return 1;
    return easing.transform(localMs / durationMs);
  }
}

double _linear(double t) => t;

double _jump(double t) => 1;

/// A named curve (CSS keywords, Penner curves, back curves).
final class NamedEasing extends MotionEasing {
  const NamedEasing._(this.expression, this._f);

  @override
  final String expression;
  final double Function(double) _f;

  static final Map<String, MotionEasing> _byName = {
    'linear': MotionEasing.linear,
    'ease': const CubicEasing(0.25, 0.1, 0.25, 1, name: 'ease'),
    'easeIn': const CubicEasing(0.42, 0, 1, 1, name: 'easeIn'),
    'easeOut': const CubicEasing(0, 0, 0.58, 1, name: 'easeOut'),
    'easeInOut': const CubicEasing(0.42, 0, 0.58, 1, name: 'easeInOut'),
    'easeInCubic': const NamedEasing._('easeInCubic', _inCubic),
    'easeOutCubic': const NamedEasing._('easeOutCubic', _outCubic),
    'easeInOutCubic': const NamedEasing._('easeInOutCubic', _inOutCubic),
    'easeOutQuint': const NamedEasing._('easeOutQuint', _outQuint),
    'easeInOutQuint': const NamedEasing._('easeInOutQuint', _inOutQuint),
    'easeOutExpo': const NamedEasing._('easeOutExpo', _outExpo),
    'easeInBack': const NamedEasing._('easeInBack', _inBack),
    'easeOutBack': const NamedEasing._('easeOutBack', _outBack),
    'easeInOutBack': const NamedEasing._('easeInOutBack', _inOutBack),
  };

  /// Every named curve (catalog of the pane's custom picker and MCP).
  static Iterable<String> get names => _byName.keys;

  @override
  double transform(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return _f(t);
  }

  static double _inCubic(double t) => t * t * t;
  static double _outCubic(double t) {
    final u = 1 - t;
    return 1 - u * u * u;
  }

  static double _inOutCubic(double t) {
    if (t < 0.5) return 4 * t * t * t;
    final u = -2 * t + 2;
    return 1 - u * u * u / 2;
  }

  static double _outQuint(double t) => 1 - math.pow(1 - t, 5).toDouble();
  static double _inOutQuint(double t) => t < 0.5
      ? 16 * math.pow(t, 5).toDouble()
      : 1 - math.pow(-2 * t + 2, 5).toDouble() / 2;
  static double _outExpo(double t) => 1 - math.pow(2, -10 * t).toDouble();

  static const double _c1 = 1.70158;
  static const double _c2 = _c1 * 1.525;
  static const double _c3 = _c1 + 1;

  static double _inBack(double t) => _c3 * t * t * t - _c1 * t * t;
  static double _outBack(double t) {
    final u = t - 1;
    return 1 + _c3 * u * u * u + _c1 * u * u;
  }

  static double _inOutBack(double t) {
    if (t < 0.5) {
      final u = 2 * t;
      return u * u * ((_c2 + 1) * u - _c2) / 2;
    }
    final u = 2 * t - 2;
    return (u * u * ((_c2 + 1) * u + _c2) + 2) / 2;
  }
}

/// A cubic Bézier curve from (0,0) to (1,1) with control points
/// ([x1], [y1]) and ([x2], [y2]) (CSS `cubic-bezier`).
final class CubicEasing extends MotionEasing {
  /// Creates the curve.
  const CubicEasing(this.x1, this.y1, this.x2, this.y2, {this.name});

  final double x1, y1, x2, y2;

  /// The CSS keyword this curve stands for (`ease`, …), or null.
  final String? name;

  @override
  String get expression =>
      name ?? 'cubic(${_n(x1)},${_n(y1)},${_n(x2)},${_n(y2)})';

  static String _n(double v) {
    final s = v.toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  double _bx(double t) {
    final u = 1 - t;
    return 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t;
  }

  double _by(double t) {
    final u = 1 - t;
    return 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t;
  }

  double _dbx(double t) {
    final u = 1 - t;
    return 3 * u * u * x1 + 6 * u * t * (x2 - x1) + 3 * t * t * (1 - x2);
  }

  @override
  double transform(double x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    // Newton–Raphson, then bisection if it didn't converge (fixed
    // iteration counts: deterministic).
    var t = x;
    for (var i = 0; i < 8; i++) {
      final err = _bx(t) - x;
      if (err.abs() < 1e-9) return _by(t);
      final d = _dbx(t);
      if (d.abs() < 1e-9) break;
      t -= err / d;
    }
    var lo = 0.0, hi = 1.0;
    t = x;
    for (var i = 0; i < 60; i++) {
      final v = _bx(t);
      if ((v - x).abs() < 1e-12) break;
      if (v < x) {
        lo = t;
      } else {
        hi = t;
      }
      t = (lo + hi) / 2;
    }
    return _by(t);
  }
}

/// `steps(n)`: jumps at the end of each of [n] intervals (CSS
/// `steps(n, end)`); 1 at progress 1.
final class StepsEasing extends MotionEasing {
  /// Creates the curve.
  const StepsEasing(this.n);

  final int n;

  @override
  String get expression => 'steps($n)';

  @override
  double transform(double t) {
    if (t >= 1) return 1;
    if (t <= 0) return 0;
    return (t * n).floor() / n;
  }
}

/// A damped spring with perceptual duration [d] seconds and bounce [b]
/// (06 §4.3, the SwiftUI/Figma model): mass 1, stiffness `(2π/d)²`,
/// damping `4π(1−b)/d` (b ≥ 0) or `4π/(d(1+b))` (b < 0), initial velocity
/// 0, from 0 to 1. Evaluated in closed form; the effective length is the
/// settle time (|x − 1| < 0.001 and |v| < 0.01 per second), capped at 4 d.
final class SpringEasing extends MotionEasing {
  /// Creates the spring; [b] is clamped to −0.95…0.95 (±1 would be an
  /// undamped or infinitely damped spring).
  SpringEasing(this.d, double b) : b = b.clamp(-0.95, 0.95).toDouble() {
    final omega = 2 * math.pi / d;
    final c = this.b >= 0
        ? 4 * math.pi * (1 - this.b) / d
        : 4 * math.pi / (d * (1 + this.b));
    _omega = omega;
    _zeta = c / (2 * omega);
    _settle = _settleTime();
  }

  /// Perceptual duration (s).
  final double d;

  /// Bounce (−0.95…0.95).
  final double b;

  late final double _omega;
  late final double _zeta;
  late final double _settle;

  /// Position tolerance of the settle time.
  static const double settlePosition = 0.001;

  /// Velocity tolerance of the settle time (per second).
  static const double settleVelocity = 0.01;

  @override
  String get expression => 'spring(${CubicEasing._n(d)},${CubicEasing._n(b)})';

  /// Natural angular frequency (rad/s).
  double get omega => _omega;

  /// Damping ratio (1 − b for b ≥ 0, 1 / (1 + b) below).
  double get zeta => _zeta;

  /// The settle time (s), ≤ 4 d.
  double get settleSeconds => _settle;

  bool get _critical => (_zeta - 1).abs() < 1e-9;

  /// Displacement from the target (`x − 1`) at [t] seconds.
  double displacement(double t) {
    final w = _omega, z = _zeta;
    if (_critical) return -(1 + w * t) * math.exp(-w * t);
    if (z < 1) {
      final wd = w * math.sqrt(1 - z * z);
      final a = z * w;
      return -math.exp(-a * t) * (math.cos(wd * t) + a / wd * math.sin(wd * t));
    }
    final s = math.sqrt(z * z - 1);
    final r1 = -w * (z - s), r2 = -w * (z + s);
    final c1 = r2 / (r1 - r2);
    final c2 = -1 - c1;
    return c1 * math.exp(r1 * t) + c2 * math.exp(r2 * t);
  }

  /// Velocity (per second) at [t] seconds.
  double velocity(double t) {
    final w = _omega, z = _zeta;
    if (_critical) return w * w * t * math.exp(-w * t);
    if (z < 1) {
      final wd = w * math.sqrt(1 - z * z);
      return math.exp(-z * w * t) * math.sin(wd * t) * w * w / wd;
    }
    final s = math.sqrt(z * z - 1);
    final r1 = -w * (z - s), r2 = -w * (z + s);
    final c1 = r2 / (r1 - r2);
    final c2 = -1 - c1;
    return c1 * r1 * math.exp(r1 * t) + c2 * r2 * math.exp(r2 * t);
  }

  /// The position (0 → 1) at [t] seconds.
  double valueAt(double t) => t <= 0 ? 0 : 1 + displacement(t);

  double _settleTime() {
    final cap = 4 * d;
    final w = _omega, z = _zeta;
    double t;
    if (_critical) {
      // Both bounds decrease after 1/ω: bisection on the predicate.
      bool settled(double t) =>
          (1 + w * t) * math.exp(-w * t) < settlePosition &&
          w * w * t * math.exp(-w * t) < settleVelocity;
      var lo = 1 / w, hi = cap;
      if (!settled(hi)) return cap;
      for (var i = 0; i < 60; i++) {
        final mid = (lo + hi) / 2;
        if (settled(mid)) {
          hi = mid;
        } else {
          lo = mid;
        }
      }
      t = hi;
    } else if (z < 1) {
      // Envelopes: |x−1| ≤ R e^{−ζωt}, |v| ≤ (ω²/ωd) e^{−ζωt}.
      final wd = w * math.sqrt(1 - z * z);
      final a = z * w;
      final r = 1 / math.sqrt(1 - z * z);
      t =
          math.max(
            math.log(r / settlePosition),
            math.log(w * w / wd / settleVelocity),
          ) /
          a;
    } else {
      final s = math.sqrt(z * z - 1);
      final r1 = -w * (z - s), r2 = -w * (z + s);
      final c1 = r2 / (r1 - r2);
      final c2 = -1 - c1;
      final pos = c1.abs() + c2.abs();
      final vel = (c1 * r1).abs() + (c2 * r2).abs();
      t =
          math.max(
            math.log(pos / settlePosition),
            math.log(vel / settleVelocity),
          ) /
          -r1;
    }
    return t.clamp(0.0, cap).toDouble();
  }

  /// [transform] maps progress over the settle time.
  @override
  double transform(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return valueAt(t * _settle);
  }

  /// This spring with perceptual duration [seconds] (same bounce).
  SpringEasing withDuration(double seconds) =>
      seconds == d ? this : SpringEasing(seconds, b);

  /// For springs a build's `durationMs` is the perceptual duration (the
  /// pane keeps the `d` of the expression in sync; 0 = the expression's
  /// `d`); the effective length is the settle time.
  @override
  BoundEasing bind(int durationMs) {
    final s = durationMs > 0 ? withDuration(durationMs / 1000) : this;
    return BoundEasing(s, (s.settleSeconds * 1000).ceil());
  }
}
