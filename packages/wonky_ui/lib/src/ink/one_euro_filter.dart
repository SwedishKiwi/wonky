import 'dart:math' as math;
import 'dart:ui';

/// A one-euro filter for pointer input (Slides 10 §4.3): smooths jitter at
/// low speeds and keeps up at high speeds.
class OneEuroFilter {
  OneEuroFilter({this.minCutoff = 1.0, this.beta = 0.02, this.dCutoff = 1.0});

  final double minCutoff;
  final double beta;
  final double dCutoff;

  Offset? _x;
  Offset _dx = Offset.zero;
  int? _t;

  static double _alpha(double cutoff, double dt) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dt);
  }

  /// Filters [p] sampled at [ms].
  Offset filter(Offset p, int ms) {
    final x = _x;
    final t = _t;
    if (x == null || t == null) {
      _x = p;
      _t = ms;
      return p;
    }
    final dt = math.max(1, ms - t) / 1000.0;
    final dx = (p - x) / dt;
    final ad = _alpha(dCutoff, dt);
    _dx = _dx + (dx - _dx) * ad;
    final cutoff = minCutoff + beta * _dx.distance;
    final a = _alpha(cutoff, dt);
    final out = x + (p - x) * a;
    _x = out;
    _t = ms;
    return out;
  }
}
