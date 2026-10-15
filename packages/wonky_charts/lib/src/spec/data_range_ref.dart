import 'dart:convert';

import 'package:collection/collection.dart';

/// An opaque reference to the cells a chart reads (`ChartDataSpec.ranges`, scorecard
/// `keyValueRef`/`baselineRef`; Slides 08 §2.4).
///
/// The chart engine never interprets it: Wonky Sheets stores its id-based GridRange JSON
/// (`{"s": sheetId, "r1", "r2", "c1", "c2", …}`) and converts with `GridRange.fromRef` /
/// `GridRange.toRef`; specs without a data source (snapshots) have none. The JSON is stored
/// unchanged, so specs round-trip byte-identically. The only requirement is a string `s`
/// (the source the reference points into, e.g. a sheet id).
final class DataRangeRef {
  /// Wraps [json], which must hold a string `s`; null values are dropped.
  factory DataRangeRef(Map<String, Object?> json) {
    final r = tryParse(json);
    if (r == null) {
      throw ArgumentError.value(json, 'json', 'needs a string "s"');
    }
    return r;
  }

  const DataRangeRef._(this._json);

  final Map<String, Object?> _json;

  /// Parses a JSON map, or a JSON string of one; null when it is not a reference (no string
  /// `s`).
  static DataRangeRef? tryParse(Object? json) {
    Object? m = json;
    if (m is String) {
      if (m.isEmpty) return null;
      try {
        m = jsonDecode(m);
      } on FormatException {
        return null;
      }
    }
    if (m is! Map || m['s'] is! String) return null;
    return DataRangeRef._(
      Map.unmodifiable(<String, Object?>{
        for (final e in m.entries)
          if (e.value != null) '${e.key}': e.value,
      }),
    );
  }

  /// The source id (`s`): the sheet of a Sheets range.
  String get sourceId => _json['s']! as String;

  /// The stored JSON.
  Map<String, Object?> toJson() => Map.of(_json);

  static const _eq = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is DataRangeRef && _eq.equals(_json, other._json);

  @override
  int get hashCode => _eq.hash(_json);

  @override
  String toString() => 'DataRangeRef(${jsonEncode(_json)})';
}
