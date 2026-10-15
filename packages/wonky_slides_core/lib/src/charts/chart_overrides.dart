import 'package:wonky_charts/wonky_charts.dart';

/// The style overrides a deck may put on a linked or static chart (Slides 08 §8.2):
/// `dataJson.overrides` is an RFC 7386 merge patch over the source spec limited to
/// presentation keys. Data, type, scales and other meaning-changing keys are edited in Sheets.
abstract final class ChartOverrides {
  /// Allowed paths (`*` = any key); everything below an allowed path is allowed.
  static const List<List<String>> allowlist = [
    ['title'],
    ['subtitle'],
    ['legend'],
    ['axes', '*', 'title'],
    ['axes', '*', 'labels'],
    ['axes', '*', 'showLine'],
    ['axes', '*', 'numberFormat'],
    ['gridlines'],
    ['series', '*', 'color'],
    ['series', '*', 'lineWidth'],
    ['series', '*', 'pointSize'],
    ['series', '*', 'pointShape'],
    ['series', '*', 'dataLabels'],
    ['series', '*', 'labelOverride'],
    ['style', 'background'],
    ['style', 'fontFamily'],
    ['style', 'border'],
    ['style', 'maximize'],
    ['style', 'palette'],
    ['threeD', 'lighting'],
    ['threeD', 'wallsVisible'],
    ['threeD', 'floorColor'],
    ['threeD', 'depth'],
    ['threeD', 'gapDepth'],
    ['threeD', 'shape'],
    ['threeD', 'explode'],
    ['typeOptions', 'pieHole'],
    ['typeOptions', 'sliceLabel'],
    ['typeOptions', 'startAngle'],
    ['typeOptions', 'slices', '*', 'offset'],
    ['typeOptions', 'slices', '*', 'color'],
  ];

  /// Whether [path] is at or below an allowed path.
  static bool allows(List<String> path) {
    for (final a in allowlist) {
      if (path.length < a.length) continue;
      var ok = true;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != '*' && a[i] != path[i]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  /// Whether [path] lies above an allowed path (an object containing allowed keys).
  static bool _isPrefix(List<String> path) {
    for (final a in allowlist) {
      if (path.length >= a.length) continue;
      var ok = true;
      for (var i = 0; i < path.length; i++) {
        if (a[i] != '*' && a[i] != path[i]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  /// The dotted paths of [patch] (a `slides.chart.updateStyle` patch onto the overrides)
  /// that are not allowed. A null above allowed keys (clearing e.g. every override of a
  /// series) is allowed in a patch.
  static List<String> rejectedPaths(Map<String, Object?> patch) {
    final out = <String>[];
    void walk(Map<Object?, Object?> m, List<String> path) {
      for (final e in m.entries) {
        final p = [...path, '${e.key}'];
        if (allows(p)) continue;
        final v = e.value;
        if (v is Map && _isPrefix(p)) {
          walk(v, p);
        } else if (v == null && _isPrefix(p)) {
          continue;
        } else {
          out.add(p.join('.'));
        }
      }
    }

    walk(patch, const []);
    return out;
  }

  /// [overrides] with everything outside the allowlist dropped (nulls above allowed keys
  /// too: in the stored overrides they would delete source keys that aren't allowed).
  static Map<String, Object?> filter(Map<String, Object?> overrides) {
    Map<String, Object?> walk(Map<Object?, Object?> m, List<String> path) {
      final out = <String, Object?>{};
      for (final e in m.entries) {
        final p = [...path, '${e.key}'];
        if (allows(p)) {
          out['${e.key}'] = _copy(e.value);
        } else if (e.value is Map && _isPrefix(p)) {
          final sub = walk(e.value! as Map, p);
          if (sub.isNotEmpty) out['${e.key}'] = sub;
        }
      }
      return out;
    }

    return walk(overrides, const []);
  }

  /// The overrides after applying [patch] (nulls clear; empty objects are pruned).
  static Map<String, Object?> merge(
    Map<String, Object?> overrides,
    Map<String, Object?> patch,
  ) {
    return _prune(mergePatch(overrides, patch));
  }

  /// RFC 7386 merge patch of [patch] onto [target] (a new value).
  static Map<String, Object?> mergePatch(
    Map<String, Object?> target,
    Map<String, Object?> patch,
  ) {
    final out = <String, Object?>{
      for (final e in target.entries) e.key: _copy(e.value),
    };
    for (final e in patch.entries) {
      final v = e.value;
      if (v == null) {
        out.remove(e.key);
      } else if (v is Map) {
        final cur = out[e.key];
        out[e.key] = mergePatch(
          cur is Map ? cur.cast<String, Object?>() : const {},
          v.cast<String, Object?>(),
        );
      } else {
        out[e.key] = _copy(v);
      }
    }
    return out;
  }

  static Object? _copy(Object? v) => switch (v) {
    Map() => {for (final e in v.entries) '${e.key}': _copy(e.value)},
    List() => [for (final x in v) _copy(x)],
    _ => v,
  };

  static Map<String, Object?> _prune(Map<String, Object?> m) {
    final out = <String, Object?>{};
    for (final e in m.entries) {
      final v = e.value;
      if (v is Map) {
        final p = _prune(v.cast<String, Object?>());
        if (p.isNotEmpty) out[e.key] = p;
      } else {
        out[e.key] = v;
      }
    }
    return out;
  }

  /// Series keys overridden in [overrides] that [data] doesn't have (shown as "unused" with
  /// *Clean up*, 08 §8.2).
  static List<String> unusedSeries(
    Map<String, Object?> overrides,
    ChartData data,
  ) {
    final s = overrides['series'];
    if (s is! Map) return const [];
    return [
      for (final k in s.keys)
        if (data.seriesByKey('$k') == null) '$k',
    ];
  }
}
