import 'dart:convert';

import '../../model/grid_range.dart';

/// The chart spec convention of the IR ([IrChart.spec]): the Wonky
/// `ChartSpec` JSON (08 §20) made independent of row/column ids.
///
/// - `data.ranges` are A1 strings with a sheet prefix (`'Q3 plan'!A1:C10`)
///   instead of `GridRange` maps.
/// - Series and domain keys (column ids, row ids when switched) are
///   positional: `#<range>:<offset>` (the `ref` of the series), also as keys
///   of the `series` style map.
abstract final class IrChartSpec {
  /// The positional key of a data reference.
  static String positionalKey(int range, int offset) => '#$range:$offset';

  /// Model spec JSON → IR spec. [rangeA1] renders a `GridRange` as A1 with a
  /// sheet prefix (null when it cannot be resolved: the range is dropped and
  /// references to later ranges shift).
  static Map<String, Object?> fromModel(
    Map<String, Object?> spec, {
    required String? Function(GridRange range) rangeA1,
  }) {
    final out = _copy(spec);
    final data = out['data'];
    if (data is! Map<String, Object?>) return out;
    final ranges = data['ranges'];
    if (ranges is List) {
      data['ranges'] = [
        for (final r in ranges)
          if (GridRange.tryParse(r) case final GridRange g)
            if (rangeA1(g) case final String a1) a1,
      ];
    }
    final renames = <String, String>{};
    String? keyOf(Object? ref) {
      if (ref is! Map) return null;
      final range = ref['range'] is num ? (ref['range']! as num).toInt() : 0;
      final offset = ref['offset'] is num ? (ref['offset']! as num).toInt() : 0;
      return positionalKey(range, offset);
    }

    final refs = data['seriesRefs'];
    if (refs is List) {
      for (final s in refs) {
        if (s is! Map<String, Object?>) continue;
        final k = keyOf(s['ref']);
        final old = s['key'];
        if (k == null) continue;
        if (old is String) renames[old] = k;
        s['key'] = k;
      }
    }
    final domain = data['domain'];
    if (domain is Map<String, Object?> && domain['key'] is String) {
      final k = keyOf(domain['ref']);
      if (k != null) domain['key'] = k;
    }
    _renameSeries(out, renames);
    return out;
  }

  /// IR spec → model spec JSON. [resolveRange] parses an A1 range (null when
  /// its sheet does not exist: the chart is skipped and null is returned);
  /// [idAt] returns the column id (row id when [switched]) at [offset]
  /// inside a resolved range.
  static Map<String, Object?>? toModel(
    Map<String, Object?> spec, {
    required GridRange? Function(String a1) resolveRange,
    required String? Function(GridRange range, int offset, bool switched) idAt,
  }) {
    final out = _copy(spec);
    final data = out['data'];
    if (data is! Map<String, Object?>) return out;
    final resolved = <GridRange>[];
    final ranges = data['ranges'];
    if (ranges is List) {
      for (final r in ranges) {
        final g = r is String ? resolveRange(r) : GridRange.tryParse(r);
        if (g == null) return null;
        resolved.add(g);
      }
      data['ranges'] = [for (final g in resolved) g.toJson()];
    }
    final switched = data['switchRowsColumns'] == true;
    String? idOf(Object? ref) {
      if (ref is! Map) return null;
      final range = ref['range'] is num ? (ref['range']! as num).toInt() : 0;
      final offset = ref['offset'] is num ? (ref['offset']! as num).toInt() : 0;
      if (range < 0 || range >= resolved.length) return null;
      return idAt(resolved[range], offset, switched);
    }

    final renames = <String, String>{};
    final refs = data['seriesRefs'];
    if (refs is List) {
      for (final s in refs) {
        if (s is! Map<String, Object?>) continue;
        final id = idOf(s['ref']);
        final old = s['key'];
        if (id == null) continue;
        if (old is String) renames[old] = id;
        s['key'] = id;
      }
    }
    final domain = data['domain'];
    if (domain is Map<String, Object?> && domain['key'] is String) {
      final id = idOf(domain['ref']);
      if (id != null) domain['key'] = id;
    }
    _renameSeries(out, renames);
    return out;
  }

  static void _renameSeries(
    Map<String, Object?> spec,
    Map<String, String> renames,
  ) {
    final series = spec['series'];
    if (series is! Map || renames.isEmpty) return;
    spec['series'] = {
      for (final e in series.entries) renames[e.key] ?? '${e.key}': e.value,
    };
  }

  static Map<String, Object?> _copy(Map<String, Object?> m) =>
      (jsonDecode(jsonEncode(m)) as Map).cast<String, Object?>();
}
