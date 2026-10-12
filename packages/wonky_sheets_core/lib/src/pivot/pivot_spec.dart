import 'dart:convert';

import '../data_tools/filter/filter_criteria.dart';

/// Aggregation functions of pivot values (07 §7.1).
enum PivotSummarize {
  sum('SUM'),
  counta('COUNTA'),
  count('COUNT'),
  countunique('COUNTUNIQUE'),
  average('AVERAGE'),
  max('MAX'),
  min('MIN'),
  median('MEDIAN'),
  product('PRODUCT'),
  stdev('STDEV'),
  stdevp('STDEVP'),
  variance('VAR'),
  variancep('VARP'),
  custom('CUSTOM');

  const PivotSummarize(this.label);

  /// Upper-case function name used in default value names.
  final String label;

  /// JSON id (`var`/`varp` for the variance pair).
  String get id => switch (this) {
    variance => 'var',
    variancep => 'varp',
    _ => name,
  };

  static PivotSummarize byId(Object? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return sum;
  }

  /// Whether the result inherits the source column's number format (07 §7.5).
  bool get inheritsFormat => this == sum || this == average || this == min || this == max || this == median;
}

/// "Show as" of pivot values.
enum PivotShowAs {
  defaultValue('default'),
  percentOfRowTotal('percentOfRowTotal'),
  percentOfColumnTotal('percentOfColumnTotal'),
  percentOfGrandTotal('percentOfGrandTotal');

  const PivotShowAs(this.id);
  final String id;

  static PivotShowAs byId(Object? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return defaultValue;
  }
}

/// Where multiple values are laid out.
enum PivotValueLayout { columns, rows }

/// Date grouping units (07 §7.7).
enum PivotDateUnit {
  second,
  minute,
  hour,
  hourMinute,
  hourMinuteAmPm,
  dayOfWeek,
  dayOfYear,
  dayOfMonth,
  dayMonth,
  month,
  quarter,
  year,
  yearMonth,
  yearQuarter,
  yearMonthDay;

  static PivotDateUnit? byName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return null;
  }
}

/// Grouping of a row/column field.
sealed class PivotGrouping {
  const PivotGrouping();

  static PivotGrouping? tryParse(Object? json) {
    if (json is! Map) return null;
    switch (json['kind']) {
      case 'date':
        final u = PivotDateUnit.byName(json['unit']);
        return u == null ? null : PivotDateGrouping(u);
      case 'histogram':
        final size = json['size'];
        if (size is! num || size <= 0) return null;
        double? n(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
        return PivotHistogramGrouping(size.toDouble(), min: n(json['min']), max: n(json['max']));
      case 'manual':
        final groups = <PivotManualGroup>[];
        if (json['groups'] is List) {
          for (final g in json['groups'] as List) {
            if (g is! Map || g['name'] is! String) continue;
            groups.add(PivotManualGroup(g['name'] as String, [
              if (g['items'] is List)
                for (final i in g['items'] as List) i.toString(),
            ]));
          }
        }
        return PivotManualGrouping(groups, ungrouped: json['ungrouped'] as String?);
    }
    return null;
  }

  Map<String, Object?> toJson();
}

/// Date grouping by [unit].
final class PivotDateGrouping extends PivotGrouping {
  const PivotDateGrouping(this.unit);
  final PivotDateUnit unit;

  @override
  Map<String, Object?> toJson() => {'kind': 'date', 'unit': unit.name};
}

/// Histogram buckets of [size] (values below [min] / above [max] go to the `< min` / `> max` buckets).
final class PivotHistogramGrouping extends PivotGrouping {
  const PivotHistogramGrouping(this.size, {this.min, this.max});
  final double size;
  final double? min;
  final double? max;

  @override
  Map<String, Object?> toJson() => {'kind': 'histogram', 'size': size, 'min': ?min, 'max': ?max};
}

/// One named manual group.
final class PivotManualGroup {
  const PivotManualGroup(this.name, this.items);
  final String name;
  final List<String> items;

  Map<String, Object?> toJson() => {'name': name, 'items': items};
}

/// Manual groups; [ungrouped] names the group of the other items (else they stay as themselves).
final class PivotManualGrouping extends PivotGrouping {
  const PivotManualGrouping(this.groups, {this.ungrouped});
  final List<PivotManualGroup> groups;
  final String? ungrouped;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'manual',
    'groups': [for (final g in groups) g.toJson()],
    'ungrouped': ?ungrouped,
  };
}

/// A row or column group (07 §7.1 `PivotGroup`).
final class PivotGroupSpec {
  const PivotGroupSpec(
    this.source, {
    this.label,
    this.showTotals = true,
    this.ascending = true,
    this.sortByValueIndex,
    this.repeatLabels = false,
    this.group,
  });

  factory PivotGroupSpec.fromJson(Map<String, Object?> m) {
    final sbv = m['sortByValue'];
    return PivotGroupSpec(
      m['source']?.toString() ?? '',
      label: m['label'] as String?,
      showTotals: m['showTotals'] != false,
      ascending: m['order'] != 'desc',
      sortByValueIndex: sbv is Map && sbv['valueIndex'] is num ? (sbv['valueIndex'] as num).toInt() : null,
      repeatLabels: m['repeatLabels'] == true,
      group: PivotGrouping.tryParse(m['group']),
    );
  }

  /// Source column id.
  final String source;

  /// Custom header text.
  final String? label;
  final bool showTotals;
  final bool ascending;

  /// Sort groups by the total of this value index (P1).
  final int? sortByValueIndex;
  final bool repeatLabels;
  final PivotGrouping? group;

  Map<String, Object?> toJson() => {
    'source': source,
    'label': label,
    'showTotals': showTotals,
    'order': ascending ? 'asc' : 'desc',
    'sortByValue': sortByValueIndex == null ? null : {'valueIndex': sortByValueIndex},
    'repeatLabels': repeatLabels,
    'group': group?.toJson(),
  };
}

/// A value field (07 §7.1 `PivotValue`).
final class PivotValueSpec {
  const PivotValueSpec({
    this.source,
    this.formula,
    this.summarizeBy = PivotSummarize.sum,
    this.name,
    this.showAs = PivotShowAs.defaultValue,
    this.numberFormat,
  });

  factory PivotValueSpec.fromJson(Map<String, Object?> m) => PivotValueSpec(
    source: m['source'] as String?,
    formula: m['formula'] as String?,
    summarizeBy: PivotSummarize.byId(m['summarizeBy']),
    name: m['name'] as String?,
    showAs: PivotShowAs.byId(m['showAs']),
    numberFormat: m['numberFormat'] as String?,
  );

  /// Source column id; null for calculated fields.
  final String? source;

  /// Calculated field formula (stored form with `⟦F:<colId>⟧` field tokens).
  final String? formula;
  final PivotSummarize summarizeBy;

  /// Display name; default "<SUMMARIZE> of <header>".
  final String? name;
  final PivotShowAs showAs;
  final String? numberFormat;

  bool get isCalculated => formula != null;

  /// The display name given the source column [header].
  String displayName(String? header, {int calculatedIndex = 1}) {
    if (name != null && name!.isNotEmpty) return name!;
    if (isCalculated) return 'Calculated Field $calculatedIndex';
    return '${summarizeBy.label} of ${header ?? ''}';
  }

  Map<String, Object?> toJson() => {
    'source': source,
    'formula': formula,
    'summarizeBy': summarizeBy.id,
    'name': name,
    'showAs': showAs.id,
    'numberFormat': numberFormat,
  };
}

/// A filter field (07 §7.1 `PivotFilter`).
final class PivotFilterSpec {
  const PivotFilterSpec(this.source, this.criteria);

  factory PivotFilterSpec.fromJson(Map<String, Object?> m) =>
      PivotFilterSpec(m['source']?.toString() ?? '', ColumnCriteria.fromJson(m['criteria']));

  final String source;
  final ColumnCriteria criteria;

  Map<String, Object?> toJson() => {'source': source, 'criteria': criteria.toJson()};
}

/// `PivotTable.specJson` v1 (07 §7.1).
final class PivotSpec {
  const PivotSpec({
    this.rows = const [],
    this.columns = const [],
    this.values = const [],
    this.filters = const [],
    this.valueLayout = PivotValueLayout.columns,
    this.showEmptyGroups = false,
  });

  /// Parses JSON (string or map); malformed input → the empty spec.
  factory PivotSpec.parse(Object? json) {
    Object? m = json;
    if (m is String) {
      if (m.isEmpty) return const PivotSpec();
      try {
        m = jsonDecode(m);
      } on FormatException {
        return const PivotSpec();
      }
    }
    if (m is! Map) return const PivotSpec();
    List<T> list<T>(String k, T Function(Map<String, Object?>) f) => [
      if (m is Map && m[k] is List)
        for (final e in m[k] as List)
          if (e is Map) f(e.cast<String, Object?>()),
    ];
    return PivotSpec(
      rows: list('rows', PivotGroupSpec.fromJson),
      columns: list('columns', PivotGroupSpec.fromJson),
      values: list('values', PivotValueSpec.fromJson),
      filters: list('filters', PivotFilterSpec.fromJson),
      valueLayout: m['valueLayout'] == 'rows' ? PivotValueLayout.rows : PivotValueLayout.columns,
      showEmptyGroups: m['showEmptyGroups'] == true,
    );
  }

  final List<PivotGroupSpec> rows;
  final List<PivotGroupSpec> columns;
  final List<PivotValueSpec> values;
  final List<PivotFilterSpec> filters;
  final PivotValueLayout valueLayout;
  final bool showEmptyGroups;

  /// Whether rows, columns and values are all empty.
  bool get isEmpty => rows.isEmpty && columns.isEmpty && values.isEmpty;

  Map<String, Object?> toJson() => {
    'v': 1,
    'rows': [for (final g in rows) g.toJson()],
    'columns': [for (final g in columns) g.toJson()],
    'values': [for (final v in values) v.toJson()],
    'filters': [for (final f in filters) f.toJson()],
    'valueLayout': valueLayout.name,
    'showEmptyGroups': showEmptyGroups,
  };

  /// Canonical JSON (cache key with the source generation).
  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) => other is PivotSpec && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// Field tokens `⟦F:<colId>⟧` of calculated field formulas.
abstract final class PivotFormula {
  static final RegExp token = RegExp('⟦F:([^⟧]+)⟧');

  /// Column ids referenced by [formula], in order of first use.
  static List<String> fieldIds(String formula) {
    final out = <String>[];
    for (final m in token.allMatches(formula)) {
      final id = m.group(1)!;
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  /// The field token of [colId].
  static String tokenOf(String colId) => '⟦F:$colId⟧';
}
