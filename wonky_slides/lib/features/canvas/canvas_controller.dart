import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../editor_screen/deck_editor_controller.dart';

/// The canvas viewport (03 §1.1 `CanvasController`, §2): the viewport size,
/// the pan offset of the pasteboard and the mapping between slide units
/// (su) and viewport pixels. The zoom itself lives in the editor
/// ([DeckEditorController.zoom] / `zoomFit`, so the toolbar and status bar
/// show it); *Fit* keeps the slide fitted with a [margin] while the window
/// resizes and disables panning.
///
/// The slide is centered in the viewport; when zoomed in, [pan] scrolls
/// the pasteboard, which extends one slide width/height beyond each edge
/// (03 §2.1). Zoom and pan are view state (never undoable).
class CanvasController extends ChangeNotifier {
  CanvasController(this.editor);

  final DeckEditorController editor;

  Size _viewport = Size.zero;
  Size _slide = const Size(1920, 1080);
  Offset _pan = Offset.zero;

  /// Viewport size in logical px.
  Size get viewport => _viewport;

  /// Slide size in su.
  Size get slideSize => _slide;

  /// Margin around the fitted slide (48 px; 16 px on narrow screens).
  double get margin => _viewport.width < 768 ? 16 : 48;

  /// The scale *Fit* resolves to for the current viewport.
  double get fitScale {
    if (_viewport.isEmpty || _slide.isEmpty) return 1;
    final m = margin;
    return math.max(
      0.02,
      math.min(
        (_viewport.width - 2 * m) / _slide.width,
        (_viewport.height - 2 * m) / _slide.height,
      ),
    );
  }

  /// Logical px per su (the editor's effective zoom).
  double get scale => editor.zoom;

  /// The pan offset (px) of the slide center from the viewport center.
  Offset get pan => editor.zoomFit ? Offset.zero : _clampPan(_pan, scale);

  /// Viewport position of the slide's top-left corner.
  Offset get origin => _originFor(scale, pan);

  Offset _originFor(double s, Offset pan) => Offset(
    (_viewport.width - _slide.width * s) / 2 + pan.dx,
    (_viewport.height - _slide.height * s) / 2 + pan.dy,
  );

  /// The largest pan offsets keeping the pasteboard (3 × the slide around
  /// its center) reachable; zero on an axis that fits.
  Offset _maxPan(double s) {
    final ex = 1.5 * _slide.width * s + margin - _viewport.width / 2;
    final ey = 1.5 * _slide.height * s + margin - _viewport.height / 2;
    final fitsX = _slide.width * s + 2 * margin <= _viewport.width;
    final fitsY = _slide.height * s + 2 * margin <= _viewport.height;
    return Offset(fitsX ? 0 : math.max(0, ex), fitsY ? 0 : math.max(0, ey));
  }

  Offset _clampPan(Offset p, double s) {
    final m = _maxPan(s);
    return Offset(p.dx.clamp(-m.dx, m.dx), p.dy.clamp(-m.dy, m.dy));
  }

  /// Whether the slide (with its margin) is larger than the viewport on
  /// some axis (scrollbars show, the wheel pans).
  bool get scrollable {
    final m = _maxPan(scale);
    return !editor.zoomFit && (m.dx > 0 || m.dy > 0);
  }

  /// Called by the canvas during layout with the viewport and slide size;
  /// reports the fitted scale to the editor.
  void layout(Size viewport, Size slide) {
    _viewport = viewport;
    _slide = slide;
    editor.reportFitScale(fitScale);
  }

  /// Slide point (su) → viewport point (px).
  Offset toViewport(Offset su) => origin + su * scale;

  /// Viewport point (px) → slide point (su).
  Offset toSlide(Offset px) => (px - origin) / scale;

  /// A slide rectangle in viewport px.
  Rect rectToViewport(SuRect r) {
    final s = scale, o = origin;
    return Rect.fromLTWH(
      o.dx + r.x * s,
      o.dy + r.y * s,
      r.width * s,
      r.height * s,
    );
  }

  /// Pans by [delta] px (wheel, Space+drag, middle-drag, auto-scroll).
  /// Returns whether the view moved.
  bool panBy(Offset delta) {
    if (editor.zoomFit) return false;
    final before = pan;
    _pan = _clampPan(pan + delta, scale);
    if (_pan == before) return false;
    notifyListeners();
    return true;
  }

  /// Zooms to [zoom] (0.1–4) keeping the slide point under [focal]
  /// (viewport px) in place — Mod+wheel and pinch (03 §2.2).
  void zoomAt(double zoom, Offset focal) {
    final z = zoom.clamp(0.1, 4.0);
    final anchor = toSlide(focal);
    editor.setZoom(z);
    final centered = _originFor(z, Offset.zero);
    _pan = _clampPan(focal - anchor * z - centered, z);
    notifyListeners();
  }

  /// Zooms so [r] (su) fills the viewport, centered (`slides.view.
  /// zoomToSelection`).
  void zoomToRect(SuRect r) {
    if (_viewport.isEmpty) return;
    final m = margin;
    final w = math.max(r.width, 1.0), h = math.max(r.height, 1.0);
    final z = math
        .min((_viewport.width - 2 * m) / w, (_viewport.height - 2 * m) / h)
        .clamp(0.1, 4.0);
    editor.setZoom(z);
    final c = Offset(r.x + r.width / 2, r.y + r.height / 2);
    final slideCenter = Offset(_slide.width / 2, _slide.height / 2);
    _pan = _clampPan(-(c - slideCenter) * z, z);
    notifyListeners();
  }

  /// Scrolls so [r] (su) is visible (keyboard nudges, Tab cycling).
  void reveal(SuRect r) {
    if (editor.zoomFit || _viewport.isEmpty) return;
    final v = rectToViewport(r);
    var dx = 0.0, dy = 0.0;
    if (v.left < 0) dx = -v.left + margin;
    if (v.right > _viewport.width) dx = _viewport.width - v.right - margin;
    if (v.top < 0) dy = -v.top + margin;
    if (v.bottom > _viewport.height) dy = _viewport.height - v.bottom - margin;
    if (dx != 0 || dy != 0) panBy(Offset(dx, dy));
  }

  /// Scrollbar thumbs (fraction start/extent of the content per axis), or
  /// null on an axis that doesn't scroll.
  (double, double)? thumb(Axis axis) {
    final m = _maxPan(scale);
    final max = axis == Axis.horizontal ? m.dx : m.dy;
    if (editor.zoomFit || max <= 0) return null;
    final view = axis == Axis.horizontal ? _viewport.width : _viewport.height;
    final content = view + 2 * max;
    final p = axis == Axis.horizontal ? pan.dx : pan.dy;
    // pan = +max shows the content's start.
    return ((max - p) / content, view / content);
  }
}
