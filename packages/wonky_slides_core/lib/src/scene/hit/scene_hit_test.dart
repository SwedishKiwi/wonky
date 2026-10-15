/// Precise hit testing on a built [SlideScene] (03 §3.2): the topmost
/// element whose drawn content is under a slide point — filled shape
/// areas, strokes and lines within a tolerance, image/chart/code boxes,
/// text line boxes. Shared by the canvas (SL-12), comments and present
/// mode links.
library;

import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import '../../geometry/path_ops.dart';
import '../../theme/resolve/resolved_theme.dart';
import '../nodes/scene_nodes.dart';

/// Hit tests scenes.
abstract final class SceneHitTest {
  /// The id of the topmost element drawn at ([x], [y]) (slide su), or
  /// null. [tolerance] (su) widens strokes and thin lines; [skip] excludes
  /// elements (locked or decorations, 03 §8.2).
  static String? elementAt(
    SlideScene scene,
    double x,
    double y, {
    double tolerance = 4,
    bool Function(String elementId)? skip,
  }) {
    for (final n in scene.nodes.reversed) {
      final id = n.elementId;
      if (id == null || (skip?.call(id) ?? false)) continue;
      if (hits(n, x, y, tolerance: tolerance)) return id;
    }
    return null;
  }

  /// Whether [node] draws content at ([x], [y]) in its parent's space.
  static bool hits(SceneNode node, double x, double y, {double tolerance = 4}) {
    switch (node) {
      case GroupNode():
        final inv = Matrix4.zero();
        final det = inv.copyInverse(node.transform);
        if (det == 0) return false;
        final p = inv.transform3(Vector3(x, y, 0));
        // The tolerance in local units (uniform scale assumed).
        final scale = node.transform.getMaxScaleOnAxis();
        final t = scale == 0 ? tolerance : tolerance / scale;
        final clip = node.clip;
        if (clip != null) {
          final r = clip.rect;
          if (r != null &&
              (p.x < r.x || p.y < r.y || p.x > r.right || p.y > r.bottom)) {
            return false;
          }
          final cp = clip.path;
          if (cp != null && !PathOps.contains(cp, p.x, p.y)) return false;
        }
        for (final c in node.children.reversed) {
          if (hits(c, p.x, p.y, tolerance: t)) return true;
        }
        return false;
      case PathNode():
        final fill = node.fill;
        if (fill != null &&
            fill is! ResolvedNoFill &&
            PathOps.contains(node.path, x, y)) {
          return true;
        }
        final s = node.stroke;
        final reach = (s?.width ?? 0) / 2 + tolerance;
        if (s != null || fill != null) {
          return PathOps.distanceToOutline(node.path.commands, x, y) <= reach;
        }
        return false;
      case ImageNode(:final dst) ||
          ChartNode(:final dst) ||
          CodeNode(:final dst):
        if (node is ImageNode && node.mask != null) {
          return PathOps.contains(node.mask!, x, y);
        }
        return x >= dst.x && y >= dst.y && x <= dst.right && y <= dst.bottom;
      case TextNode(:final layout, :final originX, :final originY):
        final lx = x - originX, ly = y - originY;
        for (final l in layout.lines) {
          if (ly >= l.top &&
              ly <= l.top + l.height &&
              lx >= l.left - tolerance &&
              lx <= l.left + l.width + tolerance) {
            return true;
          }
        }
        return false;
      case PromptNode(:final box):
        return x >= box.x && y >= box.y && x <= box.right && y <= box.bottom;
    }
  }
}
