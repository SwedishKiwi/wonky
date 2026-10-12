import 'dart:typed_data';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../format/attributes.dart';
import '../../format/format_resolver.dart';
import '../../model/axis_index.dart';
import '../../model/grid_range.dart';
import '../../model/records.dart';
import '../../model/sheet_model.dart';
import '../../rules/conditions/condition_evaluator.dart';
import '../../rules/conditions/display_text.dart';
import 'filter_criteria.dart';
import 'value_index.dart';

/// Cell data a filter reads (07 §3.4 input snapshot): computed values,
/// display texts and effective colors.
abstract interface class FilterDataSource {
  /// Computed value.
  CellValue valueAt(int row, int col);

  /// Display text (formatted value).
  String displayTextAt(int row, int col);

  /// Effective number format (null = Automatic).
  String? numberFormatAt(int row, int col);

  /// Effective fill color (`#RRGGBB`), null = none.
  String? fillColorAt(int row, int col);

  /// Effective text color (`#RRGGBB`), null = automatic.
  String? textColorAt(int row, int col);
}

/// [FilterDataSource] over a sheet: values/display through a [CellTextReader],
/// colors through [EffectiveFormatResolver] (with the optional CF overlay).
final class SheetFilterSource implements FilterDataSource {
  /// Creates the source.
  SheetFilterSource(this.sheetId, this.reader, {this.formats, this.conditional});

  final String sheetId;
  final CellTextReader reader;

  /// Resolver for color criteria (null: colors are unknown → null).
  final EffectiveFormatResolver? formats;

  /// CF overlay of a cell (e.g. `CfEvaluator.evaluate(...).overlay`).
  final CellFormat Function(int row, int col)? conditional;

  @override
  CellValue valueAt(int row, int col) => reader.valueAt(sheetId, row, col);

  @override
  String displayTextAt(int row, int col) => reader.displayTextAt(sheetId, row, col);

  @override
  String? numberFormatAt(int row, int col) => reader.numberFormatAt(sheetId, row, col);

  ResolvedFormat? _fmt(int row, int col) =>
      formats?.resolve(sheetId, row, col, conditional: conditional?.call(row, col));

  @override
  String? fillColorAt(int row, int col) {
    final f = _fmt(row, col);
    return f == null ? null : formats!.color(f.fillColor);
  }

  @override
  String? textColorAt(int row, int col) {
    final f = _fmt(row, col);
    return f == null ? null : formats!.color(f.textColor);
  }
}

/// A filter resolved to indices (07 §3.4).
final class FilterInput {
  /// Creates the input. [range] includes the header row (its first row);
  /// [criteria] maps column indices inside the range to criteria.
  FilterInput({
    required this.sheetId,
    required this.range,
    required this.criteria,
    required this.source,
    required this.conditions,
  });

  /// Resolves column ids of [criteria] on [sheet]; ids that no longer exist
  /// or lie outside [range] are ignored (07 §3.2).
  factory FilterInput.resolve({
    required SheetModel sheet,
    required GridRect range,
    required FilterCriteria criteria,
    required FilterDataSource source,
    required ConditionEvaluator conditions,
  }) {
    final byIndex = <int, ColumnCriteria>{};
    for (final e in criteria.columns.entries) {
      final c = sheet.columns.indexOf(e.key);
      if (c >= range.left && c <= range.right) byIndex[c] = e.value;
    }
    return FilterInput(sheetId: sheet.id, range: range, criteria: byIndex, source: source, conditions: conditions);
  }

  final String sheetId;
  final GridRect range;
  final Map<int, ColumnCriteria> criteria;
  final FilterDataSource source;
  final ConditionEvaluator conditions;

  /// First data row (below the header).
  int get dataTop => range.top + 1;

  /// Number of data rows.
  int get dataRowCount => range.rowCount - 1;
}

/// Hidden rows of a filter over the data rows of its range (header excluded).
final class RowVisibility {
  /// Creates a visibility mask; [hidden] has one entry per data row.
  RowVisibility(this.range, this.hidden) : hiddenCount = _count(hidden);

  static int _count(Uint8List l) {
    var n = 0;
    for (final b in l) {
      n += b;
    }
    return n;
  }

  /// The filter range (header row included).
  final GridRect range;

  /// 1 = hidden, per data row (`range.top + 1 + i`).
  final Uint8List hidden;

  /// Number of hidden rows.
  final int hiddenCount;

  /// Number of visible data rows.
  int get visibleCount => hidden.length - hiddenCount;

  /// Whether sheet row [row] is hidden by the filter (header and rows outside never are).
  bool isHidden(int row) {
    final i = row - range.top - 1;
    return i >= 0 && i < hidden.length && hidden[i] == 1;
  }

  /// Hidden sheet row indices, ascending.
  Iterable<int> get hiddenRows sync* {
    for (var i = 0; i < hidden.length; i++) {
      if (hidden[i] == 1) yield range.top + 1 + i;
    }
  }

  /// Hidden row ids (for `AxisIndex.setHiddenLayer`).
  Set<String> hiddenRowIds(AxisIndex rows) => {
    for (final r in hiddenRows)
      if (rows.tryIdAt(r) case final String id) id,
  };
}

/// One entry of the values checklist (07 §1.3 `ValueChecklist`).
final class ChecklistEntry {
  /// Creates an entry.
  const ChecklistEntry(this.text, this.count, {this.hiddenByOthers = false});

  /// Display text (`""` = (Blanks)).
  final String text;

  /// Rows with this text (among rows visible under the other columns, or —
  /// when [hiddenByOthers] — among rows hidden by them).
  final int count;

  /// Listed greyed under "Hidden by other filters".
  final bool hiddenByOthers;

  @override
  bool operator ==(Object other) =>
      other is ChecklistEntry && other.text == text && other.count == count && other.hiddenByOthers == hiddenByOthers;

  @override
  int get hashCode => Object.hash(text, count, hiddenByOthers);

  @override
  String toString() => 'ChecklistEntry("$text", $count${hiddenByOthers ? ', hidden' : ''})';
}

/// Computes filter-hidden rows (07 §3.4): a row is visible iff for every
/// column with criteria the cell is not in `hiddenValues`, satisfies the
/// condition and matches the color criteria.
abstract final class FilterEngine {
  static String _normColor(String? c, String dflt) => (c ?? dflt).toUpperCase();

  static bool Function(int row) _columnTest(FilterInput input, int col, ColumnCriteria cc, ValueIndex? index) {
    final src = input.source;
    final compiled = cc.condition == null
        ? null
        : input.conditions.compile(cc.condition!, sheetId: input.sheetId, anchorRow: input.dataTop, anchorCol: col);
    final hidden = cc.hiddenValues;
    final bg = cc.visibleBackgroundColor?.toUpperCase();
    final fg = cc.visibleForegroundColor?.toUpperCase();
    return (row) {
      if (hidden.isNotEmpty) {
        final t = index != null ? index.textAt(row) : src.displayTextAt(row, col);
        if (hidden.contains(t)) return false;
      }
      if (compiled != null) {
        final v = src.valueAt(row, col);
        if (!compiled.test(v, row: row, col: col, numberFormat: src.numberFormatAt(row, col))) return false;
      }
      if (bg != null && _normColor(src.fillColorAt(row, col), '#FFFFFF') != bg) return false;
      if (fg != null && _normColor(src.textColorAt(row, col), '#000000') != fg) return false;
      return true;
    };
  }

  /// Computes the visibility of all data rows. [indexes] (column → value
  /// index) speed up values criteria. [excludeColumn] ignores one column's
  /// criteria (checklist "hidden by other filters").
  static RowVisibility compute(
    FilterInput input, {
    Map<int, ValueIndex>? indexes,
    int? excludeColumn,
    bool Function()? isCancelled,
  }) {
    final n = input.dataRowCount < 0 ? 0 : input.dataRowCount;
    final hidden = Uint8List(n);
    final tests = <bool Function(int)>[
      for (final e in input.criteria.entries)
        if (e.key != excludeColumn) _columnTest(input, e.key, e.value, indexes?[e.key]),
    ];
    if (tests.isNotEmpty) {
      for (var i = 0; i < n; i++) {
        if ((i & 0x3fff) == 0 && (isCancelled?.call() ?? false)) break;
        final row = input.dataTop + i;
        for (final t in tests) {
          if (!t(row)) {
            hidden[i] = 1;
            break;
          }
        }
      }
    }
    return RowVisibility(input.range, hidden);
  }

  /// Re-evaluates only [rows] (live re-filtering after cell edits).
  static RowVisibility update(RowVisibility previous, FilterInput input, Iterable<int> rows, {Map<int, ValueIndex>? indexes}) {
    if (previous.range != input.range) return compute(input, indexes: indexes);
    final hidden = Uint8List.fromList(previous.hidden);
    final tests = [for (final e in input.criteria.entries) _columnTest(input, e.key, e.value, indexes?[e.key])];
    for (final row in rows) {
      final i = row - input.dataTop;
      if (i < 0 || i >= hidden.length) continue;
      hidden[i] = tests.every((t) => t(row)) ? 0 : 1;
    }
    return RowVisibility(input.range, hidden);
  }

  /// The values checklist of column [col] considering the other columns'
  /// criteria (07 §3.5): `(Blanks)` first, then the column's sort order.
  static List<ChecklistEntry> checklist(FilterInput input, int col, {ValueIndex? index}) {
    final idx = index ?? ValueIndex.build(input.source, col, input.dataTop, input.range.bottom);
    final others = compute(input, excludeColumn: col);
    final visible = <String, int>{};
    final hiddenOnly = <String, int>{};
    for (var i = 0; i < others.hidden.length; i++) {
      final t = idx.textAt(input.dataTop + i);
      if (others.hidden[i] == 0) {
        visible[t] = (visible[t] ?? 0) + 1;
      } else {
        hiddenOnly[t] = (hiddenOnly[t] ?? 0) + 1;
      }
    }
    final out = <ChecklistEntry>[];
    for (final t in idx.sortedTexts) {
      final v = visible[t];
      if (v != null) {
        out.add(ChecklistEntry(t, v));
      }
    }
    for (final t in idx.sortedTexts) {
      if (visible.containsKey(t)) continue;
      final h = hiddenOnly[t];
      if (h != null) out.add(ChecklistEntry(t, h, hiddenByOthers: true));
    }
    return out;
  }

  /// Convenience: the visibility of a `BasicFilter` / `FilterView` record.
  /// Null when its range doesn't resolve.
  static RowVisibility? computeForRecord(
    SheetModel sheet,
    FilterRecord filter,
    FilterDataSource source,
    ConditionEvaluator conditions,
  ) {
    final g = GridRange.tryParse(filter.rangeJson);
    if (g == null) return null;
    final rr = sheet.resolve(g);
    if (rr == null) return null;
    final input = FilterInput.resolve(
      sheet: sheet,
      range: rr.rect,
      criteria: FilterCriteria.parse(filter.criteriaJson),
      source: source,
      conditions: conditions,
    );
    return compute(input);
  }
}
