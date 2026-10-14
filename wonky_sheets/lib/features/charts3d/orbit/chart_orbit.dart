import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Pointers that orbit a 3D chart (08 §23.6): the objects layer doesn't
/// start a move with them. The chart view claims the pointer on pointer
/// down, before the objects layer sees it.
abstract final class ChartPointerClaims {
  static int? _orbit;

  /// Claims [pointer] for orbiting.
  static void claim(int pointer) => _orbit = pointer;

  /// Whether [pointer] orbits a chart.
  static bool isClaimed(int pointer) => _orbit == pointer;

  /// Releases [pointer].
  static void release(int pointer) {
    if (_orbit == pointer) _orbit = null;
  }
}

/// Drag-to-orbit with inertia: horizontal drags turn the chart about its
/// vertical axis, vertical drags tilt it. [onChanged] receives every
/// intermediate angle, [onEnd] the final one (one undo step for the caller).
class ChartOrbitGesture {
  ChartOrbitGesture({
    required TickerProvider vsync,
    required this.onChanged,
    required this.onEnd,
  }) {
    _ticker = vsync.createTicker(_tick);
  }

  /// Degrees per logical px.
  static const double azimuthPerPx = 0.45;
  static const double elevationPerPx = 0.3;

  /// Friction of the inertia (fraction of the velocity left after 1 s).
  static const double friction = 0.02;

  final void Function(double azimuth, double elevation) onChanged;
  final void Function(double azimuth, double elevation) onEnd;

  late final Ticker _ticker;
  Offset? _start;
  double _az0 = 0, _el0 = 0;
  double _az = 0, _el = 0;
  bool _moved = false;
  FrictionSimulation? _simAz;
  FrictionSimulation? _simEl;

  /// Whether a drag or its inertia is running.
  bool get active => _start != null || _ticker.isActive;

  /// Whether the current drag moved (a click otherwise).
  bool get moved => _moved;

  /// Starts a drag at [position] from the angles shown now.
  void start(Offset position, double azimuth, double elevation) {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _start = position;
    _az0 = _az = azimuth;
    _el0 = _el = elevation;
    _moved = false;
  }

  /// The pointer moved to [position].
  void update(Offset position) {
    final s = _start;
    if (s == null) return;
    final d = position - s;
    if (!_moved && d.distance < 3) return;
    _moved = true;
    _az = _az0 - d.dx * azimuthPerPx;
    _el = (_el0 + d.dy * elevationPerPx).clamp(0.0, 90.0);
    onChanged(_az, _el);
  }

  /// The pointer went up with [velocity] (logical px/s): coasts, then ends.
  void end(Offset velocity) {
    if (_start == null) return;
    _start = null;
    if (!_moved) return;
    final vAz = -velocity.dx * azimuthPerPx;
    final vEl = velocity.dy * elevationPerPx;
    if (math.sqrt(vAz * vAz + vEl * vEl) < 20) {
      onEnd(_az, _el);
      return;
    }
    _simAz = FrictionSimulation(friction, _az, vAz);
    _simEl = FrictionSimulation(friction, _el, vEl);
    _ticker.start();
  }

  /// Cancels the drag (no end callback).
  void cancel() {
    _start = null;
    _ticker.stop();
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    final a = _simAz!, e = _simEl!;
    _az = a.x(t);
    _el = e.x(t).clamp(0.0, 90.0);
    onChanged(_az, _el);
    final slow = a.dx(t).abs() < 4 && e.dx(t).abs() < 4;
    if (slow || t > 1.2) {
      _ticker.stop();
      onEnd(_az, _el);
    }
  }

  void dispose() => _ticker.dispose();
}
