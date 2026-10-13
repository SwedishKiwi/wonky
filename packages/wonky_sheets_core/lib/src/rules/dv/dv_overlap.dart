import '../../addressing/grid_geometry.dart';
import '../../model/grid_range.dart';

/// Result of [DvOverlap.subtract].
final class DvOverlapResult {
  /// Creates a result.
  const DvOverlapResult(this.updates, this.deletions, {this.capped = false});

  /// Rules whose rectangles changed → their new rectangles.
  final Map<String, List<GridRect>> updates;

  /// Rules whose ranges became empty (to delete).
  final Set<String> deletions;

  /// Whether a rule exceeded the rectangle cap and was merged into bounding
  /// rows (the UI shows a toast).
  final bool capped;

  /// Whether nothing changes.
  bool get isEmpty => updates.isEmpty && deletions.isEmpty;
}

/// Overlap semantics when applying a DV rule (07 §6.4): the new rule's ranges
/// are subtracted from every other rule.
abstract final class DvOverlap {
  /// Maximum rectangles per rule.
  static const int maxRects = 1000;

  /// Subtracts [newRects] from each rule in [rules] (rule id → rectangles),
  /// skipping [excludeRuleId] (the rule being saved).
  static DvOverlapResult subtract(
    Map<String, List<GridRect>> rules,
    List<GridRect> newRects, {
    String? excludeRuleId,
    int cap = maxRects,
  }) {
    final updates = <String, List<GridRect>>{};
    final deletions = <String>{};
    var capped = false;
    final ids = rules.keys.toList()..sort();
    for (final id in ids) {
      if (id == excludeRuleId) continue;
      final rects = rules[id]!;
      if (!rects.any((r) => newRects.any(r.intersects))) continue;
      var out = rects;
      for (final n in newRects) {
        out = RectSet.subtractAll(out, n);
      }
      out = RectCoalescer.coalesce(out);
      if (out.isEmpty) {
        deletions.add(id);
        continue;
      }
      if (out.length > cap) {
        out = RectCoalescer.boundRows(out, cap);
        capped = true;
      }
      updates[id] = out;
    }
    return DvOverlapResult(updates, deletions, capped: capped);
  }
}

/// Rectangle list normalization.
abstract final class RectCoalescer {
  /// Merges horizontally adjacent rectangles with equal rows, then vertically
  /// adjacent ones with equal columns, until stable. Output sorted row-major.
  static List<GridRect> coalesce(List<GridRect> rects) {
    var list = List.of(rects);
    var changed = true;
    while (changed && list.length > 1) {
      changed = false;
      list.sort(
        (a, b) => a.top != b.top
            ? a.top - b.top
            : (a.bottom != b.bottom ? a.bottom - b.bottom : a.left - b.left),
      );
      final h = <GridRect>[];
      for (final r in list) {
        if (h.isNotEmpty) {
          final l = h.last;
          if (l.top == r.top && l.bottom == r.bottom && l.right + 1 == r.left) {
            h[h.length - 1] = GridRect(l.top, l.left, l.bottom, r.right);
            changed = true;
            continue;
          }
        }
        h.add(r);
      }
      h.sort(
        (a, b) => a.left != b.left
            ? a.left - b.left
            : (a.right != b.right ? a.right - b.right : a.top - b.top),
      );
      final v = <GridRect>[];
      for (final r in h) {
        if (v.isNotEmpty) {
          final l = v.last;
          if (l.left == r.left && l.right == r.right && l.bottom + 1 == r.top) {
            v[v.length - 1] = GridRect(l.top, l.left, r.bottom, l.right);
            changed = true;
            continue;
          }
        }
        v.add(r);
      }
      list = v;
    }
    list.sort((a, b) => a.top != b.top ? a.top - b.top : a.left - b.left);
    return list;
  }

  /// Reduces [rects] to at most [cap] rectangles by replacing consecutive
  /// groups (in row order) with their bounding boxes.
  static List<GridRect> boundRows(List<GridRect> rects, int cap) {
    final sorted = List.of(rects)
      ..sort((a, b) => a.top != b.top ? a.top - b.top : a.left - b.left);
    final per = (sorted.length / cap).ceil();
    final out = <GridRect>[];
    for (var i = 0; i < sorted.length; i += per) {
      final end = i + per > sorted.length ? sorted.length : i + per;
      out.add(RectSet.bounds(sorted.sublist(i, end))!);
    }
    return out;
  }
}
