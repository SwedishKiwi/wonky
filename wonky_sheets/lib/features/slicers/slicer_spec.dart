import 'dart:convert';

import 'package:wonky_sheets_core/model.dart';

/// Style of a slicer (07 §5 `SlicerSpec.style`).
class SlicerStyle {
  const SlicerStyle({
    this.backgroundColor,
    this.textColor,
    this.fontSize = 10,
    this.bold = false,
  });

  factory SlicerStyle.fromJson(Object? json) {
    if (json is! Map) return const SlicerStyle();
    return SlicerStyle(
      backgroundColor: json['backgroundColor'] as String?,
      textColor: json['textColor'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 10,
      bold: json['bold'] == true,
    );
  }

  /// Null = the theme's card color (readable in light and dark).
  final String? backgroundColor;
  final String? textColor;
  final double fontSize;
  final bool bold;

  Map<String, Object?> toJson() => {
    'backgroundColor': ?backgroundColor,
    'textColor': ?textColor,
    'fontSize': fontSize,
    'bold': bold,
  };

  SlicerStyle copyWith({
    String? Function()? backgroundColor,
    String? Function()? textColor,
    double? fontSize,
    bool? bold,
  }) => SlicerStyle(
    backgroundColor: backgroundColor == null
        ? this.backgroundColor
        : backgroundColor(),
    textColor: textColor == null ? this.textColor : textColor(),
    fontSize: fontSize ?? this.fontSize,
    bold: bold ?? this.bold,
  );
}

/// `EmbeddedObject(kind: slicer).specJson` (07 §5, addition D4): the data
/// range (incl. header row), the filtered column, its criteria, title,
/// whether pivots on the same data follow it, and the style.
class SlicerSpec {
  const SlicerSpec({
    required this.dataRange,
    this.colId,
    this.criteria,
    this.title,
    this.applyToPivotTables = true,
    this.style = const SlicerStyle(),
  });

  static SlicerSpec? tryParse(String json) {
    try {
      final d = jsonDecode(json);
      if (d is! Map) return null;
      final range = GridRange.tryParse(d['dataRange']);
      if (range == null) return null;
      final c = d['criteria'];
      final criteria = c == null ? null : ColumnCriteria.fromJson(c);
      return SlicerSpec(
        dataRange: range,
        colId: d['colId'] as String?,
        criteria: criteria == null || criteria.isEmpty ? null : criteria,
        title: d['title'] as String?,
        applyToPivotTables: d['applyToPivotTables'] != false,
        style: SlicerStyle.fromJson(d['style']),
      );
    } on FormatException {
      return null;
    }
  }

  final GridRange dataRange;
  final String? colId;
  final ColumnCriteria? criteria;
  final String? title;
  final bool applyToPivotTables;
  final SlicerStyle style;

  Map<String, Object?> toJson() => {
    'v': 1,
    'dataRange': dataRange.toJson(),
    'colId': ?colId,
    'criteria': criteria?.toJson() ?? {'hiddenValues': <String>[]},
    'title': ?title,
    'applyToPivotTables': applyToPivotTables,
    'style': style.toJson(),
  };

  String encode() => jsonEncode(toJson());

  SlicerSpec copyWith({
    GridRange? dataRange,
    String? Function()? colId,
    ColumnCriteria? Function()? criteria,
    String? Function()? title,
    bool? applyToPivotTables,
    SlicerStyle? style,
  }) => SlicerSpec(
    dataRange: dataRange ?? this.dataRange,
    colId: colId == null ? this.colId : colId(),
    criteria: criteria == null ? this.criteria : criteria(),
    title: title == null ? this.title : title(),
    applyToPivotTables: applyToPivotTables ?? this.applyToPivotTables,
    style: style ?? this.style,
  );
}
