/// Layout remapping (Slides 05 §5.4, §9): matching a slide's placeholder
/// instances to another layout's placeholders, and choosing the layout of a
/// new theme for a slide (by stable key, else by placeholder signature).
library;

import 'placeholder_type.dart';

/// A placeholder instance on a slide, in matching order (the order of the
/// old layout's placeholders, then reading order).
final class RemapInstance {
  /// Creates an instance description.
  const RemapInstance({
    required this.id,
    required this.type,
    required this.isEmpty,
  });

  /// The instance element id.
  final String id;

  /// Its placeholder type.
  final SlidePlaceholderType type;

  /// Whether it holds no content (`text` null/empty, no image/code/chart).
  final bool isEmpty;
}

/// A placeholder of the target layout, in layout order.
final class RemapTarget {
  /// Creates a target description.
  const RemapTarget({required this.id, required this.type});

  /// The layout placeholder element id.
  final String id;

  /// Its placeholder type.
  final SlidePlaceholderType type;
}

/// The outcome of [LayoutRemapper.remap] (05 §5.4 steps 1–3). The planner
/// turns it into row changes and writes `Slide.layoutId` (step 4).
final class LayoutRemapPlan {
  /// Creates a plan.
  const LayoutRemapPlan({
    required this.repoint,
    required this.materialize,
    required this.delete,
    required this.create,
  });

  /// Instance id → new layout placeholder id (`placeholderOf` re-pointed;
  /// null frame/style columns stay null).
  final Map<String, String> repoint;

  /// Instances without a match that hold content: become regular elements
  /// in place (effective frame/style written, `placeholderOf = null`).
  final List<String> materialize;

  /// Empty instances without a match: deleted.
  final List<String> delete;

  /// Target placeholders without an instance: new empty instances
  /// (`SlidesIds.placeholderInstanceId(slide, target)`).
  final List<String> create;

  /// Whether nothing changes.
  bool get isEmpty =>
      repoint.isEmpty &&
      materialize.isEmpty &&
      delete.isEmpty &&
      create.isEmpty;
}

/// Placeholder matching between layouts (05 §5.4).
abstract final class LayoutRemapper {
  /// Matches [instances] to [targets] by type, in order (1st body → 1st
  /// body, 2nd body → 2nd body). Targets that are not instantiated
  /// (slide number, footer, date) are ignored.
  static LayoutRemapPlan remap(
    List<RemapInstance> instances,
    List<RemapTarget> targets,
  ) {
    final free = <SlidePlaceholderType, List<RemapTarget>>{};
    for (final t in targets) {
      if (!t.type.isInstantiated) continue;
      (free[t.type] ??= []).add(t);
    }
    final repoint = <String, String>{};
    final materialize = <String>[];
    final delete = <String>[];
    final used = <String>{};
    for (final i in instances) {
      final pool = free[i.type];
      if (pool != null && pool.isNotEmpty) {
        final t = pool.removeAt(0);
        repoint[i.id] = t.id;
        used.add(t.id);
      } else if (i.isEmpty) {
        delete.add(i.id);
      } else {
        materialize.add(i.id);
      }
    }
    return LayoutRemapPlan(
      repoint: repoint,
      materialize: materialize,
      delete: delete,
      create: [
        for (final t in targets)
          if (t.type.isInstantiated && !used.contains(t.id)) t.id,
      ],
    );
  }
}

/// A layout offered by a theme, for [LayoutMatcher].
final class LayoutCandidate {
  /// Creates a candidate.
  const LayoutCandidate({required this.id, this.key, required this.types});

  /// Layout id.
  final String id;

  /// Built-in layout key, or `null`.
  final String? key;

  /// Its placeholder types in order.
  final List<SlidePlaceholderType> types;
}

/// Chooses the layout of another theme for a slide (05 §9 *Apply theme*):
/// same key, else the best placeholder-signature match, else `titleBody`
/// (slides with placeholders) or `blank`.
abstract final class LayoutMatcher {
  /// The best layout among [candidates] for a slide whose current layout
  /// has [key] and placeholder [types]; `null` when [candidates] is empty.
  static LayoutCandidate? match({
    required String? key,
    required List<SlidePlaceholderType> types,
    required List<LayoutCandidate> candidates,
  }) {
    if (candidates.isEmpty) return null;
    if (key != null) {
      for (final c in candidates) {
        if (c.key == key) return c;
      }
    }
    final wanted = _counts(types);
    LayoutCandidate? best;
    var bestScore = 0;
    var bestExtra = 0;
    for (final c in candidates) {
      final have = _counts(c.types);
      var score = 0;
      var extra = 0;
      for (final e in have.entries) {
        final w = wanted[e.key] ?? 0;
        score += e.value < w ? e.value : w;
        if (e.value > w) extra += e.value - w;
      }
      if (score > bestScore ||
          (score == bestScore && score > 0 && extra < bestExtra)) {
        best = c;
        bestScore = score;
        bestExtra = extra;
      }
    }
    if (best != null && bestScore > 0) return best;
    final fallbackKey = wanted.isEmpty ? 'blank' : 'titleBody';
    for (final c in candidates) {
      if (c.key == fallbackKey) return c;
    }
    for (final c in candidates) {
      if (c.key == 'blank') return c;
    }
    return candidates.first;
  }

  static Map<SlidePlaceholderType, int> _counts(
    List<SlidePlaceholderType> types,
  ) {
    final out = <SlidePlaceholderType, int>{};
    for (final t in types) {
      if (!t.isInstantiated) continue;
      out[t] = (out[t] ?? 0) + 1;
    }
    return out;
  }
}
