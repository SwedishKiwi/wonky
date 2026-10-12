import 'dart:convert';

import '../../model/grid_range.dart';
import '../conditions/condition.dart';

/// Chip colors of a dropdown option (absolute user colors).
final class DvChipColors {
  /// Creates colors.
  const DvChipColors({this.bg, this.fg});

  /// Background (`#RRGGBB`) or null (no color).
  final String? bg;

  /// Text color or null.
  final String? fg;

  /// Whether no color is set.
  bool get isEmpty => bg == null && fg == null;

  Map<String, Object?> toJson() => {'bg': ?bg, 'fg': ?fg};

  static DvChipColors fromJson(Object? json) =>
      json is Map ? DvChipColors(bg: json['bg'] as String?, fg: json['fg'] as String?) : const DvChipColors();

  @override
  bool operator ==(Object other) => other is DvChipColors && other.bg == bg && other.fg == fg;

  @override
  int get hashCode => Object.hash(bg, fg);
}

/// One dropdown item: `{"value": "Open", "bg": "#D4EDBC", "fg": "#11734B"}`.
final class DvOption {
  /// Creates an option.
  const DvOption(this.value, {this.colors = const DvChipColors()});

  /// The item text.
  final String value;

  /// Chip colors.
  final DvChipColors colors;

  Map<String, Object?> toJson() => {'value': value, ...colors.toJson()};

  static DvOption? tryParse(Object? json) {
    if (json is String) return DvOption(json);
    if (json is! Map) return null;
    final v = json['value'];
    if (v == null) return null;
    return DvOption(v.toString(), colors: DvChipColors.fromJson(json));
  }

  @override
  bool operator ==(Object other) => other is DvOption && other.value == value && other.colors == colors;

  @override
  int get hashCode => Object.hash(value, colors);
}

/// The 10-entry chip palette (light pastel background + dark text) cycled for
/// new options (07 §6.1).
abstract final class DvChipPalette {
  static const List<DvChipColors> colors = [
    DvChipColors(bg: '#D4EDBC', fg: '#11734B'),
    DvChipColors(bg: '#FFCFC9', fg: '#B10202'),
    DvChipColors(bg: '#FFE5A0', fg: '#473821'),
    DvChipColors(bg: '#BFE1F6', fg: '#0A53A8'),
    DvChipColors(bg: '#E6CFF2', fg: '#5A3286'),
    DvChipColors(bg: '#C6DBE1', fg: '#215A6C'),
    DvChipColors(bg: '#FFC8AA', fg: '#753800'),
    DvChipColors(bg: '#E8EAED', fg: '#3C4043'),
    DvChipColors(bg: '#B3E5E0', fg: '#0B5A52'),
    DvChipColors(bg: '#F6CEE4', fg: '#8C1D58'),
  ];

  /// Colors of the [index]th new option.
  static DvChipColors at(int index) => colors[index % colors.length];
}

/// How a DV cell is displayed (`DataValidationRule.displayStyle`).
enum DvDisplayStyle {
  chip,
  arrow,
  plainText;

  static DvDisplayStyle parse(String? s) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return chip;
  }

  /// `showDropdown` kept for older readers.
  bool get showDropdown => this != plainText;
}

/// `DataValidationRule.criteriaJson` (07 §6.1).
sealed class DvCriteria {
  const DvCriteria();

  /// Parses JSON (map or string); null when malformed or the type is unknown.
  static DvCriteria? tryParse(Object? json) {
    Object? m = json;
    if (m is String) {
      if (m.isEmpty) return null;
      try {
        m = jsonDecode(m);
      } on FormatException {
        return null;
      }
    }
    if (m is! Map) return null;
    switch (m['type']) {
      case 'oneOfList':
        return DvListCriteria([
          if (m['options'] is List)
            for (final o in m['options'] as List)
              if (DvOption.tryParse(o) case final DvOption opt) opt,
        ], allowMultiple: m['allowMultiple'] == true);
      case 'oneOfRange':
        final range = GridRange.tryParse(m['range']);
        if (range == null) return null;
        final colors = <String, DvChipColors>{};
        if (m['colors'] is Map) {
          (m['colors'] as Map).forEach((k, v) => colors[k.toString()] = DvChipColors.fromJson(v));
        }
        return DvRangeCriteria(range, colors: colors, allowMultiple: m['allowMultiple'] == true);
      case 'checkbox':
        String? s(Object? v) => v?.toString();
        return DvCheckboxCriteria(checked: s(m['checked']), unchecked: s(m['unchecked']));
    }
    final c = Condition.tryParse(m);
    if (c == null || !c.type.usableIn(ConditionUse.dataValidation)) return null;
    return DvConditionCriteria(c);
  }

  /// JSON map.
  Map<String, Object?> toJson();

  /// JSON string.
  String encode() => jsonEncode(toJson());

  /// Whether the criteria render a dropdown.
  bool get isDropdown => this is DvListCriteria || this is DvRangeCriteria;
}

/// Dropdown of items.
final class DvListCriteria extends DvCriteria {
  /// Creates list criteria.
  DvListCriteria(List<DvOption> options, {this.allowMultiple = false}) : options = List.unmodifiable(options);

  final List<DvOption> options;

  /// Multi-select (P2): values joined by `", "`.
  final bool allowMultiple;

  /// Colors of [value], if it is an option.
  DvChipColors? colorsOf(String value) {
    for (final o in options) {
      if (o.value == value) return o.colors;
    }
    return null;
  }

  @override
  Map<String, Object?> toJson() => {
    'type': 'oneOfList',
    'options': [for (final o in options) o.toJson()],
    'allowMultiple': allowMultiple,
  };
}

/// Dropdown from a range: items = distinct display values of [range].
final class DvRangeCriteria extends DvCriteria {
  /// Creates range criteria.
  DvRangeCriteria(this.range, {Map<String, DvChipColors> colors = const {}, this.allowMultiple = false})
    : colors = Map.unmodifiable(colors);

  final GridRange range;

  /// Item text → chip colors.
  final Map<String, DvChipColors> colors;
  final bool allowMultiple;

  @override
  Map<String, Object?> toJson() => {
    'type': 'oneOfRange',
    'range': range.toJson(),
    if (colors.isNotEmpty) 'colors': {for (final e in colors.entries) e.key: e.value.toJson()},
    'allowMultiple': allowMultiple,
  };
}

/// Checkbox; both values omitted = TRUE/FALSE.
final class DvCheckboxCriteria extends DvCriteria {
  /// Creates checkbox criteria.
  const DvCheckboxCriteria({this.checked, this.unchecked});

  /// Custom checked value as typed (parsed like input), or null.
  final String? checked;

  /// Custom unchecked value, or null.
  final String? unchecked;

  /// Whether custom values are used.
  bool get hasCustomValues => checked != null || unchecked != null;

  @override
  Map<String, Object?> toJson() => {'type': 'checkbox', 'checked': ?checked, 'unchecked': ?unchecked};
}

/// Any DV-capable [Condition] (07 §3.3).
final class DvConditionCriteria extends DvCriteria {
  /// Creates condition criteria.
  const DvConditionCriteria(this.condition);

  final Condition condition;

  @override
  Map<String, Object?> toJson() => condition.toJson();
}
