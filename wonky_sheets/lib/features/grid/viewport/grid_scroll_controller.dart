import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Scroll offsets (screen px, at the current zoom) and zoom of the grid
/// (03 §5, §2.3). Offsets are saved per sheet when switching sheets.
class GridScrollController extends ChangeNotifier {
  GridScrollController({this._zoom = 1});

  static const minZoom = 0.5;
  static const maxZoom = 2.0;
  static const zoomSteps = [50, 75, 90, 100, 125, 150, 200];

  double _x = 0;
  double _y = 0;
  double _zoom;
  double _maxX = double.infinity;
  double _maxY = double.infinity;
  Size _viewport = Size.zero;
  final Map<String, (double, double)> _saved = {};

  double get x => _x;
  double get y => _y;
  double get zoom => _zoom;
  Size get viewport => _viewport;
  double get maxX => _maxX;
  double get maxY => _maxY;

  /// Called by the grid on layout with the current limits.
  void updateLimits({
    required double maxX,
    required double maxY,
    required Size viewport,
  }) {
    _maxX = maxX;
    _maxY = maxY;
    _viewport = viewport;
    final nx = _x.clamp(0.0, math.max(0.0, maxX)).toDouble();
    final ny = _y.clamp(0.0, math.max(0.0, maxY)).toDouble();
    if (nx != _x || ny != _y) {
      _x = nx;
      _y = ny;
      // Limits shrink during layout; listeners repaint next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  /// Sets both offsets (clamped).
  void jumpTo(double x, double y) {
    final nx = x.clamp(0.0, math.max(0.0, _maxX)).toDouble();
    final ny = y.clamp(0.0, math.max(0.0, _maxY)).toDouble();
    if (nx == _x && ny == _y) return;
    _x = nx;
    _y = ny;
    notifyListeners();
  }

  /// Scrolls by a delta.
  void scrollBy(double dx, double dy) => jumpTo(_x + dx, _y + dy);

  /// Sets the zoom (clamped to 50–200 %), keeping [focal] (an offset inside
  /// the scrolled pane) fixed on screen.
  void setZoom(double zoom, {Offset focal = Offset.zero}) {
    final z = zoom.clamp(minZoom, maxZoom);
    if (z == _zoom) return;
    final f = z / _zoom;
    final fx = (_x + focal.dx) * f - focal.dx;
    final fy = (_y + focal.dy) * f - focal.dy;
    _zoom = z;
    _maxX = double.infinity;
    _maxY = double.infinity;
    _x = math.max(0, fx);
    _y = math.max(0, fy);
    notifyListeners();
  }

  /// Saves the offsets of [sheetId] and restores those of [nextSheetId].
  void switchSheet(String sheetId, String nextSheetId) {
    _saved[sheetId] = (_x, _y);
    final next = _saved[nextSheetId] ?? (0, 0);
    _x = next.$1;
    _y = next.$2;
    _maxX = double.infinity;
    _maxY = double.infinity;
    notifyListeners();
  }
}
