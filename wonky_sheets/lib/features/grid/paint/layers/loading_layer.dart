import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

import '../../../model/workbook_session.dart';
import '../grid_layer.dart';

/// Skeleton bars over rows whose cells are still streaming in (03 §2.8,
/// viewport-first loading 02 §6). Shimmers at 2 Hz (static with reduced
/// motion) and asks the session to load the visible rows first. Removes
/// itself once everything is loaded.
class LoadingLayer extends GridLayer {
  LoadingLayer(this.loading, {required this.onDone}) {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_animate) return;
      _phase.value = (_phase.value + 1) % 2;
    });
    loading.addListener(_onLoading);
  }

  final WorkbookRowLoading loading;

  /// Called once loading completed (the owner removes the layer).
  final VoidCallback onDone;

  final ValueNotifier<int> _phase = ValueNotifier(0);
  late final Timer _timer;
  bool _disposed = false;

  /// Paints only while visible rows are missing (no timer repaints after).
  bool _animate = false;

  @override
  int get zOrder => GridZ.presence + 5;

  @override
  Listenable get repaint => _phase;

  void _onLoading() {
    if (_disposed) return;
    if (loading.complete) {
      dispose();
      onDone();
    } else {
      _phase.value = _phase.value + 2;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer.cancel();
    loading.removeListener(_onLoading);
  }

  static bool get _reduceMotion => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    if (loading.complete) return;
    final sheet = ctx.sheet;
    if (loading.isSheetLoaded(sheet.id)) {
      _animate = false;
      return;
    }
    final rows = sheet.rows;
    var missing = false;
    var first = -1;
    var last = -1;
    final bright = (_phase.value % 2 == 1) && !_reduceMotion;
    final paint = Paint()
      ..color = bright
          ? Color.lerp(ctx.tokens.skeleton, ctx.tokens.sheetBackground, 0.45)!
          : ctx.tokens.skeleton;
    ctx.forEachPane(canvas, (pane) {
      if (pane.isEmpty) return;
      for (var r = pane.rowStart; r <= pane.rowEnd; r++) {
        if (rows.sizeAt(r) <= 0) continue;
        if (loading.isRowLoaded(sheet.id, rows.idAt(r))) continue;
        missing = true;
        if (first < 0 || r < first) first = r;
        if (r > last) last = r;
        final top = pane.y(r);
        final bottom = pane.y(r + 1);
        final h = bottom - top;
        if (h < 6) continue;
        final barH = math.min(8.0 * ctx.zoom, h - 6);
        final y = top + (h - barH) / 2;
        for (var c = pane.colStart; c <= pane.colEnd; c++) {
          final left = pane.x(c);
          final w = pane.x(c + 1) - left;
          if (w < 12) continue;
          // Varying widths look like text instead of a table of bars.
          final share = 0.45 + ((r * 7 + c * 13) % 5) * 0.1;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left + 6, y, (w - 12) * share, barH),
              Radius.circular(barH / 2),
            ),
            paint,
          );
        }
      }
    });
    _animate = missing;
    if (missing) loading.prioritize(sheet.id, first, last);
  }
}
