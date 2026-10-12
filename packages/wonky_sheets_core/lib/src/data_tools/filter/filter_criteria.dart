import 'dart:convert';

import '../../rules/conditions/condition.dart';

/// Criteria of one filter column (07 §3.2):
/// `{"hiddenValues": [...], "condition": {...}, "visibleBackgroundColor": "#F4CCCC", "visibleForegroundColor": null}`.
final class ColumnCriteria {
  /// Creates criteria.
  ColumnCriteria({
    Iterable<String> hiddenValues = const [],
    this.condition,
    this.visibleBackgroundColor,
    this.visibleForegroundColor,
  }) : hiddenValues = Set.unmodifiable(hiddenValues);

  /// Parses a JSON map (missing parts are null/empty).
  factory ColumnCriteria.fromJson(Object? json) {
    if (json is! Map) return ColumnCriteria();
    final hv = json['hiddenValues'];
    String? color(Object? v) => v is String && v.isNotEmpty ? v : null;
    return ColumnCriteria(
      hiddenValues: [
        if (hv is List)
          for (final v in hv) v?.toString() ?? '',
      ],
      condition: Condition.tryParse(json['condition']),
      visibleBackgroundColor: color(json['visibleBackgroundColor']),
      visibleForegroundColor: color(json['visibleForegroundColor']),
    );
  }

  /// Display texts to hide (`""` = blanks), exact case-sensitive match.
  final Set<String> hiddenValues;

  /// Condition the cell must satisfy (07 §3.3), or null.
  final Condition? condition;

  /// Required effective fill color (P1), or null.
  final String? visibleBackgroundColor;

  /// Required effective text color (P1), or null.
  final String? visibleForegroundColor;

  /// Whether no criterion is set.
  bool get isEmpty =>
      hiddenValues.isEmpty && condition == null && visibleBackgroundColor == null && visibleForegroundColor == null;

  /// Whether color criteria are set.
  bool get hasColor => visibleBackgroundColor != null || visibleForegroundColor != null;

  /// JSON map.
  Map<String, Object?> toJson() => {
    if (hiddenValues.isNotEmpty) 'hiddenValues': hiddenValues.toList(),
    if (condition != null) 'condition': condition!.toJson(),
    if (visibleBackgroundColor != null) 'visibleBackgroundColor': visibleBackgroundColor,
    if (visibleForegroundColor != null) 'visibleForegroundColor': visibleForegroundColor,
  };

  @override
  bool operator ==(Object other) => other is ColumnCriteria && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => 'ColumnCriteria(${jsonEncode(toJson())})';
}

/// `criteriaJson` of `BasicFilter` / `FilterView`: column id → [ColumnCriteria].
final class FilterCriteria {
  /// Creates criteria.
  FilterCriteria([Map<String, ColumnCriteria> columns = const {}])
    : columns = Map.unmodifiable({
        for (final e in columns.entries)
          if (!e.value.isEmpty) e.key: e.value,
      });

  /// Parses `criteriaJson`; malformed input → empty criteria.
  factory FilterCriteria.parse(String? json) {
    if (json == null || json.isEmpty) return FilterCriteria();
    Object? d;
    try {
      d = jsonDecode(json);
    } on FormatException {
      return FilterCriteria();
    }
    return FilterCriteria.fromJson(d);
  }

  /// From a decoded JSON map.
  factory FilterCriteria.fromJson(Object? json) {
    if (json is! Map) return FilterCriteria();
    return FilterCriteria({for (final e in json.entries) e.key.toString(): ColumnCriteria.fromJson(e.value)});
  }

  /// Non-empty criteria by column id.
  final Map<String, ColumnCriteria> columns;

  /// Whether no column has criteria.
  bool get isEmpty => columns.isEmpty;

  /// A copy with [colId]'s criteria replaced (null or empty clears).
  FilterCriteria withColumn(String colId, ColumnCriteria? criteria) =>
      FilterCriteria({...columns, colId: ?criteria}..removeWhere((k, v) => k == colId && (criteria?.isEmpty ?? true)));

  /// A copy keeping only [colIds] (after range changes / deleted columns).
  FilterCriteria retain(Set<String> colIds) =>
      FilterCriteria({for (final e in columns.entries) if (colIds.contains(e.key)) e.key: e.value});

  /// JSON map.
  Map<String, Object?> toJson() => {for (final e in columns.entries) e.key: e.value.toJson()};

  /// `criteriaJson`.
  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) => other is FilterCriteria && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}
