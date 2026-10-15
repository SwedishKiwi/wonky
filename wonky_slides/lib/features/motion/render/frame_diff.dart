import 'package:flutter/widgets.dart' show Matrix4;
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';

/// Cheap structural comparison of frame states, so a stage repaints only
/// the elements whose state changed between two frames (06 §12.1: static
/// elements are not repainted per frame). Timeline frames create new
/// state objects on every evaluation; identity alone would repaint every
/// element with a persistent state on every tick.
abstract final class FrameDiff {
  static final Expando<List<String>> _ids = Expando('nodeElementIds');

  /// Every element id drawn by [node] (itself and nested elements).
  static List<String> idsOf(SceneNode node) => _ids[node] ??= () {
    final out = <String>{};
    void walk(SceneNode n) {
      final id = n.elementId;
      if (id != null) out.add(id);
      if (n is GroupNode) n.children.forEach(walk);
    }

    walk(node);
    return out.toList();
  }();

  /// Whether [node] looks the same in frames [a] and [b].
  static bool sameFor(SceneNode node, SlideFrame a, SlideFrame b) {
    if (identical(a, b)) return true;
    for (final id in idsOf(node)) {
      if (!same(a.elements[id], b.elements[id])) return false;
    }
    return true;
  }

  /// Whether two element states paint the same (null = edit state).
  static bool same(ElementVisualState? a, ElementVisualState? b) {
    if (identical(a, b)) return true;
    a ??= ElementVisualState.edit;
    b ??= ElementVisualState.edit;
    if (a.visible != b.visible) return false;
    if (!a.visible) return true;
    return a.opacity == b.opacity &&
        a.blurSigma == b.blurSigma &&
        a.drawProgress == b.drawProgress &&
        a.drawReverse == b.drawReverse &&
        a.fillOpacity == b.fillOpacity &&
        a.codeStateIndex == b.codeStateIndex &&
        a.codeHighlightStep == b.codeHighlightStep &&
        _matrix(a.transform, b.transform) &&
        _clip(a.clip, b.clip) &&
        _dissolve(a.dissolve, b.dissolve) &&
        _colors(a.colors, b.colors) &&
        _highlights(a.highlights, b.highlights) &&
        _parts(a.parts, b.parts) &&
        _json(a.chart?.toJson(), b.chart?.toJson()) &&
        _json(a.code?.toJson(), b.code?.toJson());
  }

  static bool _matrix(Matrix4 a, Matrix4 b) {
    final x = a.storage, y = b.storage;
    for (var i = 0; i < 16; i++) {
      if (x[i] != y[i]) return false;
    }
    return true;
  }

  static bool _clip(ClipSpec? a, ClipSpec? b) {
    if (a == null || b == null) return a == b;
    return a.kind == b.kind &&
        a.progress == b.progress &&
        a.direction == b.direction &&
        a.shape == b.shape &&
        a.originX == b.originX &&
        a.originY == b.originY &&
        a.softness == b.softness;
  }

  static bool _dissolve(DissolveState? a, DissolveState? b) {
    if (a == null || b == null) return a == b;
    return a.amount == b.amount && a.seed == b.seed && a.cell == b.cell;
  }

  static bool _override(ColorOverride? a, ColorOverride? b) {
    if (a == null || b == null) return a == b;
    return a.from == b.from && a.to == b.to && a.mix == b.mix;
  }

  static bool _colors(
    Map<String, ColorOverride> a,
    Map<String, ColorOverride> b,
  ) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!_override(e.value, b[e.key])) return false;
    }
    return true;
  }

  static bool _highlights(
    List<TextHighlightState> a,
    List<TextHighlightState> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i], y = b[i];
      if (x.start != y.start ||
          x.end != y.end ||
          x.color != y.color ||
          x.style != y.style ||
          x.progress != y.progress) {
        return false;
      }
    }
    return true;
  }

  static bool _parts(TextPartStates? a, TextPartStates? b) {
    if (a == null || b == null) return a == b;
    if (a.backgroundOpacity != b.backgroundOpacity) return false;
    if (a.parts.length != b.parts.length) return false;
    for (var i = 0; i < a.parts.length; i++) {
      final x = a.parts[i], y = b.parts[i];
      if (x.start != y.start ||
          x.end != y.end ||
          x.visible != y.visible ||
          x.opacity != y.opacity ||
          x.blurSigma != y.blurSigma ||
          x.revealEnd != y.revealEnd ||
          x.caret != y.caret ||
          x.dim != y.dim ||
          x.dimColor != y.dimColor ||
          !_override(x.color, y.color) ||
          !_clip(x.clip, y.clip) ||
          !_matrix(x.transform, y.transform)) {
        return false;
      }
    }
    return true;
  }

  static bool _json(Object? a, Object? b) {
    if (a == null || b == null) return a == b;
    return a.toString() == b.toString();
  }
}
