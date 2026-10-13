import 'dart:convert';

/// One sort key (07 §2.1): `{colId, ascending}` or, for sort by color (P2),
/// `{colId, fillColor}` / `{colId, textColor}` (rows with the color first).
///
/// Also the `sortJson` model of `BasicFilter` / `FilterView` (07 §3.2, §4.4).
sealed class SortSpec {
  const SortSpec(this.colId);

  /// The column id.
  final String colId;

  /// Parses one JSON map; null when malformed.
  static SortSpec? tryParse(Object? json) {
    if (json is! Map) return null;
    final col = json['colId'];
    if (col is! String || col.isEmpty) return null;
    final fill = json['fillColor'];
    final text = json['textColor'];
    if (fill is String) return ColorSortSpec(col, fillColor: fill);
    if (text is String) return ColorSortSpec(col, textColor: text);
    return ValueSortSpec(col, ascending: json['ascending'] != false);
  }

  /// Parses `sortJson` (a JSON list); invalid entries are skipped.
  static List<SortSpec> parseList(String? json) {
    if (json == null || json.isEmpty) return const [];
    Object? d;
    try {
      d = jsonDecode(json);
    } on FormatException {
      return const [];
    }
    if (d is! List) return const [];
    return [
      for (final e in d)
        if (tryParse(e) case final SortSpec s) s,
    ];
  }

  /// Encodes a list (`sortJson`); null for an empty list.
  static String? encodeList(List<SortSpec> specs) =>
      specs.isEmpty ? null : jsonEncode([for (final s in specs) s.toJson()]);

  /// JSON map.
  Map<String, Object?> toJson();
}

/// Sort by value.
final class ValueSortSpec extends SortSpec {
  /// Creates a value sort key.
  const ValueSortSpec(super.colId, {this.ascending = true});

  /// A→Z when true.
  final bool ascending;

  @override
  Map<String, Object?> toJson() => {'colId': colId, 'ascending': ascending};

  @override
  bool operator ==(Object other) =>
      other is ValueSortSpec &&
      other.colId == colId &&
      other.ascending == ascending;

  @override
  int get hashCode => Object.hash(colId, ascending);

  @override
  String toString() => 'ValueSortSpec($colId, ${ascending ? 'asc' : 'desc'})';
}

/// Sort by color: rows whose effective fill (or text) color equals the color first.
final class ColorSortSpec extends SortSpec {
  /// Creates a color sort key; exactly one of [fillColor]/[textColor].
  const ColorSortSpec(super.colId, {this.fillColor, this.textColor});

  final String? fillColor;
  final String? textColor;

  @override
  Map<String, Object?> toJson() => {
    'colId': colId,
    'fillColor': ?fillColor,
    'textColor': ?textColor,
  };

  @override
  bool operator ==(Object other) =>
      other is ColorSortSpec &&
      other.colId == colId &&
      other.fillColor == fillColor &&
      other.textColor == textColor;

  @override
  int get hashCode => Object.hash(colId, fillColor, textColor);
}
