/// The codec of `Deck.guidesJson` (03 §5.6, A-03-1): a whole-value JSON
/// object `{"v": 1, "guides": [{"axis": "v", "at": 960}]}` (the planner
/// stores JSON objects only; a bare list is read too).
library;

import 'dart:convert';

import 'snap_engine.dart';

/// Reads and writes the user guides of a deck.
abstract final class UserGuides {
  /// At most this many guides per deck.
  static const maxGuides = 200;

  /// The guides of [json] (invalid entries are skipped).
  static List<UserGuide> decode(String? json) {
    if (json == null || json.isEmpty) return const [];
    Object? v;
    try {
      v = jsonDecode(json);
    } on FormatException {
      return const [];
    }
    final list = v is Map ? v['guides'] : v;
    if (list is! List) return const [];
    return [
      for (final g in list)
        if (g is Map &&
            GuideAxis.fromCode(g['axis']) != null &&
            g['at'] is num &&
            (g['at'] as num).isFinite)
          UserGuide(
            GuideAxis.fromCode(g['axis'])!,
            (g['at'] as num).toDouble(),
          ),
    ];
  }

  /// The `guidesJson` value of [guides] (null when empty).
  static String? encode(List<UserGuide> guides) => guides.isEmpty
      ? null
      : jsonEncode({
          'v': 1,
          'guides': [
            for (final g in guides) {'axis': g.axis.code, 'at': _num(g.at)},
          ],
        });

  static num _num(double v) {
    final r = (v * 100).roundToDouble() / 100;
    return r == r.roundToDouble() ? r.toInt() : r;
  }
}
