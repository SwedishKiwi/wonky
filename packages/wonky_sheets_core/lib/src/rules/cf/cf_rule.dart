import 'dart:convert';

import '../../format/attributes.dart';
import '../conditions/condition.dart';

/// Kinds of threshold values of color scales, data bars and icon sets (06 §15.5–15.7).
enum CfValueKind {
  min,
  max,
  number,
  percent,
  percentile,
  formula;

  static CfValueKind? byName(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// A threshold: `{"kind": "percentile", "value": "50"}`. [value] is a number
/// literal or a stored formula (`=…`) for `number`/`percent`/`percentile`/`formula`.
final class CfThreshold {
  /// Creates a threshold.
  const CfThreshold(this.kind, [this.value]);

  /// The kind.
  final CfValueKind kind;

  /// The value text (null for min/max).
  final String? value;

  /// Parses a JSON map; null when malformed.
  static CfThreshold? tryParse(Object? json) {
    if (json is! Map) return null;
    final kind = CfValueKind.byName(json['kind']);
    if (kind == null) return null;
    final v = json['value'];
    return CfThreshold(kind, v?.toString());
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (value != null) 'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is CfThreshold && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);
}

/// A color scale point: threshold plus color (`#RRGGBB` or `theme:*`).
final class ColorScalePoint {
  /// Creates a point.
  const ColorScalePoint(this.threshold, this.color);

  /// Shorthand constructor.
  ColorScalePoint.of(CfValueKind kind, this.color, [String? value])
    : threshold = CfThreshold(kind, value);

  /// Threshold.
  final CfThreshold threshold;

  /// Color.
  final String color;

  /// Parses a JSON map.
  static ColorScalePoint? tryParse(Object? json) {
    final t = CfThreshold.tryParse(json);
    if (t == null || json is! Map) return null;
    final c = json['color'];
    if (c is! String) return null;
    return ColorScalePoint(t, c);
  }

  /// JSON map.
  Map<String, Object?> toJson() => {...threshold.toJson(), 'color': color};

  @override
  bool operator ==(Object other) =>
      other is ColorScalePoint &&
      other.threshold == threshold &&
      other.color == color;

  @override
  int get hashCode => Object.hash(threshold, color);
}

/// `ruleJson` of a `ConditionalFormatRule` (06 §15.1, version 1).
sealed class CfRule {
  const CfRule();

  /// Parses `ruleJson` (map or string). Unknown types decode as [CfUnknownRule]
  /// (kept for round-tripping, never rendered).
  static CfRule parse(Object? json) {
    Object? m = json;
    if (m is String) {
      try {
        m = jsonDecode(m);
      } on FormatException {
        return const CfUnknownRule({});
      }
    }
    if (m is! Map) return const CfUnknownRule({});
    final map = m.cast<String, Object?>();
    switch (map['type']) {
      case 'boolean':
        final cond = Condition.tryParse(map['condition']);
        if (cond == null) break;
        final rawFormat = map['format'] is Map
            ? (map['format'] as Map).cast<String, Object?>()
            : const <String, Object?>{};
        final allowed = <String, Object?>{};
        final extra = <String, Object?>{};
        rawFormat.forEach((k, v) {
          final a = FormatAttr.byColumn(k);
          if (a != null && FormatAttr.conditional.contains(a)) {
            allowed[k] = v;
          } else {
            extra[k] = v;
          }
        });
        return CfBooleanRule(
          condition: cond,
          format: CellFormat.fromMap(allowed),
          stopIfTrue: map['stopIfTrue'] == true,
          extraFormat: extra,
        );
      case 'colorScale':
        final pts = <ColorScalePoint>[
          if (map['points'] is List)
            for (final p in map['points'] as List)
              if (ColorScalePoint.tryParse(p) case final ColorScalePoint cp) cp,
        ];
        if (pts.length < 2) break;
        return CfColorScaleRule(pts.length > 3 ? pts.sublist(0, 3) : pts);
      case 'dataBar':
        return CfDataBarRule(
          min:
              CfThreshold.tryParse(map['min']) ??
              const CfThreshold(CfValueKind.min),
          max:
              CfThreshold.tryParse(map['max']) ??
              const CfThreshold(CfValueKind.max),
          color: map['color'] as String? ?? '#638EC6',
          negativeColor: map['negativeColor'] as String? ?? '#E06666',
          gradient: map['gradient'] != false,
          axis: DataBarAxis.byName(map['axis']) ?? DataBarAxis.auto,
          direction:
              DataBarDirection.byName(map['direction']) ??
              DataBarDirection.context,
          showValue: map['showValue'] != false,
        );
      case 'iconSet':
        final set = IconSetKind.byId(map['set'] as String?);
        if (set == null) break;
        final th = <IconThreshold>[
          if (map['thresholds'] is List)
            for (final t in map['thresholds'] as List)
              if (IconThreshold.tryParse(t) case final IconThreshold it) it,
        ];
        return CfIconSetRule(
          set: set,
          thresholds: th,
          reverse: map['reverse'] == true,
          showValue: map['showValue'] != false,
        );
    }
    return CfUnknownRule(map);
  }

  /// JSON map (`"v": 1`).
  Map<String, Object?> toJson();

  /// JSON string.
  String encode() => jsonEncode(toJson());

  /// Whether the rule depends on statistics of its ranges (min/max/percentiles).
  bool get usesRangeStats;

  @override
  String toString() => 'CfRule(${encode()})';
}

/// Single color rule: condition + format (06 §15.4 allowed attributes only).
final class CfBooleanRule extends CfRule {
  /// Creates a rule. New rules created in Wonky default to [stopIfTrue] true
  /// (Google semantics); parsed rules without the flag read false (XLSX).
  CfBooleanRule({
    required this.condition,
    required CellFormat format,
    this.stopIfTrue = true,
    Map<String, Object?> extraFormat = const {},
  }) : format = format.without([
         for (final a in FormatAttr.values)
           if (!FormatAttr.conditional.contains(a)) a,
       ]),
       extraFormat = Map.unmodifiable(extraFormat);

  /// The condition.
  final Condition condition;

  /// The applied format (bold, italic, underline, strikethrough, textColor, fillColor).
  final CellFormat format;

  /// Stop evaluating later rules for a matching cell.
  final bool stopIfTrue;

  /// Unsupported format keys kept for export (never rendered).
  final Map<String, Object?> extraFormat;

  @override
  bool get usesRangeStats => false;

  @override
  Map<String, Object?> toJson() => {
    'v': 1,
    'type': 'boolean',
    'condition': condition.toJson(),
    'format': {...extraFormat, ...format.toMap()},
    'stopIfTrue': stopIfTrue,
  };

  /// Copy with changes.
  CfBooleanRule copyWith({
    Condition? condition,
    CellFormat? format,
    bool? stopIfTrue,
  }) => CfBooleanRule(
    condition: condition ?? this.condition,
    format: format ?? this.format,
    stopIfTrue: stopIfTrue ?? this.stopIfTrue,
    extraFormat: extraFormat,
  );

  @override
  bool operator ==(Object other) =>
      other is CfBooleanRule && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// Color scale with 2 or 3 points (min, optional midpoint, max).
final class CfColorScaleRule extends CfRule {
  /// Creates a color scale.
  CfColorScaleRule(List<ColorScalePoint> points)
    : points = List.unmodifiable(points);

  /// The points, lowest first.
  final List<ColorScalePoint> points;

  @override
  bool get usesRangeStats => true;

  @override
  Map<String, Object?> toJson() => {
    'v': 1,
    'type': 'colorScale',
    'points': [for (final p in points) p.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is CfColorScaleRule && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// Data bar axis placement.
enum DataBarAxis {
  auto,
  middle,
  none;

  static DataBarAxis? byName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return null;
  }
}

/// Data bar direction.
enum DataBarDirection {
  context,
  ltr,
  rtl;

  static DataBarDirection? byName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return null;
  }
}

/// Data bar (06 §15.6).
final class CfDataBarRule extends CfRule {
  /// Creates a data bar rule.
  const CfDataBarRule({
    this.min = const CfThreshold(CfValueKind.min),
    this.max = const CfThreshold(CfValueKind.max),
    this.color = '#638EC6',
    this.negativeColor = '#E06666',
    this.gradient = true,
    this.axis = DataBarAxis.auto,
    this.direction = DataBarDirection.context,
    this.showValue = true,
  });

  final CfThreshold min;
  final CfThreshold max;
  final String color;
  final String negativeColor;
  final bool gradient;
  final DataBarAxis axis;
  final DataBarDirection direction;
  final bool showValue;

  @override
  bool get usesRangeStats => true;

  @override
  Map<String, Object?> toJson() => {
    'v': 1,
    'type': 'dataBar',
    'min': min.toJson(),
    'max': max.toJson(),
    'color': color,
    'negativeColor': negativeColor,
    'gradient': gradient,
    'axis': axis.name,
    'direction': direction.name,
    'showValue': showValue,
  };

  @override
  bool operator ==(Object other) =>
      other is CfDataBarRule && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// Icon sets (06 §15.7) with their icon counts.
enum IconSetKind {
  arrows3('3arrows', 3),
  arrowsGray3('3arrowsGray', 3),
  triangles3('3triangles', 3),
  trafficLights3('3trafficLights', 3),
  signs3('3signs', 3),
  symbols3('3symbols', 3),
  flags3('3flags', 3),
  stars3('3stars', 3),
  arrows4('4arrows', 4),
  ratings4('4ratings', 4),
  trafficLights4('4trafficLights', 4),
  arrows5('5arrows', 5),
  ratings5('5ratings', 5),
  quarters5('5quarters', 5);

  const IconSetKind(this.id, this.iconCount);

  /// JSON id.
  final String id;

  /// Number of icons.
  final int iconCount;

  static IconSetKind? byId(String? id) {
    for (final k in values) {
      if (k.id == id) return k;
    }
    return null;
  }
}

/// One icon threshold: `{"op": ">=", "kind": "percent", "value": "67"}`.
final class IconThreshold {
  /// Creates a threshold; [inclusive] is `>=` (else `>`).
  const IconThreshold(this.threshold, {this.inclusive = true});

  /// The threshold.
  final CfThreshold threshold;

  /// `>=` when true, `>` otherwise.
  final bool inclusive;

  /// Parses JSON.
  static IconThreshold? tryParse(Object? json) {
    final t = CfThreshold.tryParse(json);
    if (t == null || json is! Map) return null;
    return IconThreshold(t, inclusive: json['op'] != '>');
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
    'op': inclusive ? '>=' : '>',
    ...threshold.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is IconThreshold &&
      other.threshold == threshold &&
      other.inclusive == inclusive;

  @override
  int get hashCode => Object.hash(threshold, inclusive);
}

/// Icon set rule (P2).
final class CfIconSetRule extends CfRule {
  /// Creates an icon set rule; [thresholds] has `iconCount - 1` entries, highest first.
  CfIconSetRule({
    required this.set,
    required List<IconThreshold> thresholds,
    this.reverse = false,
    this.showValue = true,
  }) : thresholds = List.unmodifiable(thresholds);

  final IconSetKind set;
  final List<IconThreshold> thresholds;
  final bool reverse;
  final bool showValue;

  @override
  bool get usesRangeStats => true;

  @override
  Map<String, Object?> toJson() => {
    'v': 1,
    'type': 'iconSet',
    'set': set.id,
    'thresholds': [for (final t in thresholds) t.toJson()],
    'reverse': reverse,
    'showValue': showValue,
  };

  @override
  bool operator ==(Object other) =>
      other is CfIconSetRule && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// A rule of an unknown/invalid type (kept verbatim, ignored for rendering).
final class CfUnknownRule extends CfRule {
  /// Creates the rule.
  const CfUnknownRule(this.json);

  /// The raw JSON.
  final Map<String, Object?> json;

  @override
  bool get usesRangeStats => false;

  @override
  Map<String, Object?> toJson() => json;
}
