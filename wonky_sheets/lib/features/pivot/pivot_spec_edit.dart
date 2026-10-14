import 'package:wonky_sheets_core/model.dart';

/// The four field areas of the pivot editor (07 §7.3).
enum PivotArea {
  row,
  column,
  value,
  filter;

  static PivotArea? byName(Object? name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return null;
  }

  /// Whether fields of the area are groups (Rows, Columns).
  bool get isGroup => this == row || this == column;
}

/// Kind of a source column (type icon, default aggregation).
enum PivotFieldKind { number, date, text, boolean, empty }

/// One column of the pivot source as offered by the field list.
final class PivotSourceField {
  const PivotSourceField(this.colId, this.header, this.kind, {this.format});

  final String colId;
  final String header;
  final PivotFieldKind kind;

  /// The column's number format (first non-empty cell).
  final String? format;

  /// The default *Summarize by* of a new value field.
  PivotSummarize get defaultSummarize => kind == PivotFieldKind.number
      ? PivotSummarize.sum
      : PivotSummarize.counta;

  /// The source columns of [table] with their kinds (from the values).
  static List<PivotSourceField> of(SourceTable table, {String? locale}) => [
    for (final c in table.columns)
      PivotSourceField(
        c.colId,
        c.header,
        _kindOf(c, locale ?? 'en_US'),
        format: c.numberFormat,
      ),
  ];

  static PivotFieldKind _kindOf(SourceColumn c, String locale) {
    var numbers = 0;
    var texts = 0;
    var bools = 0;
    final n = c.values.length < 500 ? c.values.length : 500;
    for (var i = 0; i < n; i++) {
      switch (c.values[i]) {
        case NumberValue():
          numbers++;
        case TextValue():
          texts++;
        case BoolValue():
          bools++;
        default:
          break;
      }
    }
    if (numbers == 0 && texts == 0 && bools == 0) return PivotFieldKind.empty;
    if (numbers >= texts && numbers >= bools) {
      final f = c.numberFormat;
      if (f != null &&
          (NumberFormatInfo.isDatePattern(f, locale: locale) ||
              NumberFormatInfo.isTimePattern(f, locale: locale))) {
        return PivotFieldKind.date;
      }
      return PivotFieldKind.number;
    }
    return bools > texts ? PivotFieldKind.boolean : PivotFieldKind.text;
  }
}

/// Copies of pivot spec parts with changed JSON properties (the core specs
/// have no `copyWith`; their JSON round-trips losslessly).
PivotGroupSpec groupWith(PivotGroupSpec g, Map<String, Object?> changes) =>
    PivotGroupSpec.fromJson({...g.toJson(), ...changes});

PivotValueSpec valueWith(PivotValueSpec v, Map<String, Object?> changes) =>
    PivotValueSpec.fromJson({...v.toJson(), ...changes});

/// Spec edits of the pivot editor; every one is committed as one
/// `sheets.pivot.update` step.
extension PivotSpecEdit on PivotSpec {
  PivotSpec copyWith({
    List<PivotGroupSpec>? rows,
    List<PivotGroupSpec>? columns,
    List<PivotValueSpec>? values,
    List<PivotFilterSpec>? filters,
    PivotValueLayout? valueLayout,
    bool? showEmptyGroups,
  }) => PivotSpec(
    rows: rows ?? this.rows,
    columns: columns ?? this.columns,
    values: values ?? this.values,
    filters: filters ?? this.filters,
    valueLayout: valueLayout ?? this.valueLayout,
    showEmptyGroups: showEmptyGroups ?? this.showEmptyGroups,
  );

  /// Number of fields in [area].
  int count(PivotArea area) => switch (area) {
    PivotArea.row => rows.length,
    PivotArea.column => columns.length,
    PivotArea.value => values.length,
    PivotArea.filter => filters.length,
  };

  /// The source column of field [index] of [area] (null for calculated
  /// fields).
  String? sourceOf(PivotArea area, int index) => switch (area) {
    PivotArea.row => rows[index].source,
    PivotArea.column => columns[index].source,
    PivotArea.value => values[index].source,
    PivotArea.filter => filters[index].source,
  };

  /// Adds the source column [colId] to [area] (at [index], default the end).
  PivotSpec addField(
    PivotArea area,
    String colId, {
    PivotSummarize summarize = PivotSummarize.sum,
    int? index,
  }) => _insert(area, _fieldFor(area, colId, summarize), index);

  /// Adds a calculated field (Values).
  PivotSpec addCalculatedField(String formula, {String? name}) => copyWith(
    values: [
      ...values,
      PivotValueSpec(
        formula: formula,
        summarizeBy: PivotSummarize.sum,
        name: name,
      ),
    ],
  );

  Object _fieldFor(PivotArea area, String colId, PivotSummarize summarize) =>
      switch (area) {
        PivotArea.row || PivotArea.column => PivotGroupSpec(colId),
        PivotArea.value => PivotValueSpec(
          source: colId,
          summarizeBy: summarize,
        ),
        PivotArea.filter => PivotFilterSpec(colId, ColumnCriteria()),
      };

  PivotSpec _insert(PivotArea area, Object field, int? index) {
    List<T> ins<T>(List<T> list) {
      final out = List<T>.of(list);
      out.insert((index ?? out.length).clamp(0, out.length), field as T);
      return out;
    }

    return switch (area) {
      PivotArea.row => copyWith(rows: ins(rows)),
      PivotArea.column => copyWith(columns: ins(columns)),
      PivotArea.value => copyWith(values: ins(values)),
      PivotArea.filter => copyWith(filters: ins(filters)),
    };
  }

  /// Removes field [index] of [area].
  PivotSpec removeAt(PivotArea area, int index) {
    List<T> rm<T>(List<T> list) => List<T>.of(list)..removeAt(index);
    switch (area) {
      case PivotArea.row:
        return copyWith(rows: rm(rows));
      case PivotArea.column:
        return copyWith(columns: rm(columns));
      case PivotArea.filter:
        return copyWith(filters: rm(filters));
      case PivotArea.value:
        // Sort-by-value references shift with the removed value.
        PivotGroupSpec fix(PivotGroupSpec g) {
          final i = g.sortByValueIndex;
          if (i == null || i < index) return g;
          return groupWith(g, {
            'sortByValue': i == index ? null : {'valueIndex': i - 1},
          });
        }
        return copyWith(
          values: rm(values),
          rows: [for (final g in rows) fix(g)],
          columns: [for (final g in columns) fix(g)],
        );
    }
  }

  /// Moves field [index] of [from] to [to] at [toIndex] (drag & drop,
  /// card ⋮ › Move to). Rows ↔ Columns keep the group options; other moves
  /// create a fresh field for the source column. Calculated values can't
  /// leave Values (unchanged spec).
  PivotSpec move(
    PivotArea from,
    int index,
    PivotArea to,
    int toIndex, {
    PivotSummarize summarize = PivotSummarize.sum,
  }) {
    if (from == to) {
      final n = count(from);
      final target = toIndex.clamp(0, n);
      if (target == index || target == index + 1) return this;
      List<T> reorder<T>(List<T> list) {
        final out = List<T>.of(list);
        final item = out.removeAt(index);
        out.insert(target > index ? target - 1 : target, item);
        return out;
      }

      return switch (from) {
        PivotArea.row => copyWith(rows: reorder(rows)),
        PivotArea.column => copyWith(columns: reorder(columns)),
        // Reordering values keeps sort-by-value pointing at the same value.
        PivotArea.value => _reorderValues(index, target),
        PivotArea.filter => copyWith(filters: reorder(filters)),
      };
    }
    final colId = sourceOf(from, index);
    if (colId == null) return this;
    final removed = removeAt(from, index);
    final Object field;
    if ((from == PivotArea.row || from == PivotArea.column) &&
        (to == PivotArea.row || to == PivotArea.column)) {
      field = from == PivotArea.row ? rows[index] : columns[index];
    } else {
      field = _fieldFor(to, colId, summarize);
    }
    return removed._insert(to, field, toIndex);
  }

  PivotSpec _reorderValues(int index, int target) {
    final order = List<int>.generate(values.length, (i) => i);
    final item = order.removeAt(index);
    order.insert(target > index ? target - 1 : target, item);
    PivotGroupSpec fix(PivotGroupSpec g) {
      final i = g.sortByValueIndex;
      if (i == null) return g;
      return groupWith(g, {
        'sortByValue': {'valueIndex': order.indexOf(i)},
      });
    }

    return copyWith(
      values: [for (final i in order) values[i]],
      rows: [for (final g in rows) fix(g)],
      columns: [for (final g in columns) fix(g)],
    );
  }

  /// Replaces group [index] of Rows or Columns.
  PivotSpec withGroup(PivotArea area, int index, PivotGroupSpec g) {
    List<PivotGroupSpec> set(List<PivotGroupSpec> l) => List.of(l)..[index] = g;
    return area == PivotArea.row
        ? copyWith(rows: set(rows))
        : copyWith(columns: set(columns));
  }

  /// Replaces value [index].
  PivotSpec withValue(int index, PivotValueSpec v) =>
      copyWith(values: List.of(values)..[index] = v);

  /// Replaces filter [index].
  PivotSpec withFilter(int index, PivotFilterSpec f) =>
      copyWith(filters: List.of(filters)..[index] = f);

  /// Sets the grouping of the first Rows/Columns field on [colId]
  /// (`sheets.pivot.createGroup`); false when no such field exists.
  (PivotSpec, bool) withGrouping(String colId, PivotGrouping? group) {
    for (final area in [PivotArea.row, PivotArea.column]) {
      final list = area == PivotArea.row ? rows : columns;
      final i = list.indexWhere((g) => g.source == colId);
      if (i < 0) continue;
      return (
        withGroup(area, i, groupWith(list[i], {'group': group?.toJson()})),
        true,
      );
    }
    return (this, false);
  }
}
