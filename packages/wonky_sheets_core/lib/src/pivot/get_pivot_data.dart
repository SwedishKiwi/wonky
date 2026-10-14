import '../content/cell_content.dart';
import '../formula/values/numeric.dart';
import 'pivot_engine.dart';
import 'pivot_grouping.dart';

/// `GETPIVOTDATA(value_name, any_pivot_table_cell, [original_column,
/// pivot_item, …])` over a computed pivot (07 §7.8). Resolving the pivot
/// from `any_pivot_table_cell` is the caller's job.
abstract final class PivotDataLookup {
  /// The displayed value (after *show as*) of the value named [valueName]
  /// (its name or source header, case-insensitive) at the items fixed by
  /// [pairs] (field header or custom label → item, case-insensitive; numbers
  /// and dates also match by value). Groups that are not fixed resolve to
  /// their totals.
  ///
  /// Errors: an unknown value or field → `#REF!` "Field 'X' was not found in
  /// the pivot table."; an unknown item, fixing an inner group without its
  /// outer groups, or a total that isn't shown → `#N/A`. [labelText] renders
  /// a label with its number format so formatted labels match too.
  static CellValue lookup(
    PivotResult result,
    String valueName,
    List<(String field, CellValue item)> pairs, {
    String Function(CellValue value, String? numberFormat)? labelText,
  }) {
    final name = valueName.trim().toLowerCase();
    final vi = result.valueFields.indexWhere(
      (v) =>
          v.name.toLowerCase() == name ||
          (v.header.isNotEmpty && v.header.toLowerCase() == name),
    );
    if (vi < 0) return _notFound(valueName);

    final rowItems = <int, CellValue>{};
    final colItems = <int, CellValue>{};
    for (final (field, item) in pairs) {
      final f = field.trim().toLowerCase();
      bool matches(PivotFieldInfo info) =>
          info.header.toLowerCase() == f || info.label.toLowerCase() == f;
      final ri = result.rowFields.indexWhere(matches);
      if (ri >= 0) {
        rowItems[ri] = item;
        continue;
      }
      final ci = result.columnFields.indexWhere(matches);
      if (ci >= 0) {
        colItems[ci] = item;
        continue;
      }
      return _notFound(field);
    }

    final row = _walk(result.rowRoot, result.rowFields, rowItems, labelText);
    final col = _walk(
      result.columnRoot,
      result.columnFields,
      colItems,
      labelText,
    );
    if (row == null || col == null || !result.isDisplayed(row, col)) {
      return const ErrorValue(CellErrorKind.na);
    }
    return result.value(row, col, vi);
  }

  static ErrorValue _notFound(String name) => ErrorValue(
    CellErrorKind.ref,
    "Field '$name' was not found in the pivot table.",
  );

  /// The node fixed by [items] (level → item); null when an item is missing
  /// or the fixed levels are not a prefix of the groups.
  static PivotAxisNode? _walk(
    PivotAxisNode root,
    List<PivotFieldInfo> fields,
    Map<int, CellValue> items,
    String Function(CellValue value, String? numberFormat)? labelText,
  ) {
    var node = root;
    for (var level = 0; level < items.length; level++) {
      final item = items[level];
      if (item == null) return null;
      final field = fields[level];
      final next = node.childWhere((k) => _matches(k, item, field, labelText));
      if (next == null) return null;
      node = next;
    }
    return node;
  }

  static bool _matches(
    PivotKey key,
    CellValue item,
    PivotFieldInfo field,
    String Function(CellValue value, String? numberFormat)? labelText,
  ) {
    final label = key.label;
    if (item is NumberValue && label is NumberValue) {
      return Numeric.approxEqual(item.number, label.number);
    }
    final want = switch (item) {
      NumberValue(:final number) => Numeric.toText(number),
      TextValue(:final text) => text,
      BoolValue(:final value) => value ? 'TRUE' : 'FALSE',
      ErrorValue(:final kind) => kind.literal,
      EmptyValue() => '',
    }.toLowerCase();
    if (key.labelText.toLowerCase() == want) return true;
    if (labelText != null && key.inheritsFormat) {
      return labelText(label, field.numberFormat).toLowerCase() == want;
    }
    return false;
  }
}
