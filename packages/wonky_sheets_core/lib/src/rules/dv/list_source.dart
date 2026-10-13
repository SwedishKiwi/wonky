import '../../addressing/grid_geometry.dart';
import '../../model/sheet_model.dart';
import '../conditions/display_text.dart';
import 'dv_criteria.dart';

/// Items of dropdown rules (07 §6.5).
abstract final class ListSource {
  /// Maximum number of items of a `oneOfRange` dropdown.
  static const int maxItems = 1000;

  /// Distinct non-empty display values of [rect] on [sheetId] in range order
  /// (row-major), at most [limit].
  static List<String> distinctValues(
    CellTextReader reader,
    String sheetId,
    GridRect rect, {
    int limit = maxItems,
    SheetModel? sheet,
  }) {
    final seen = <String>{};
    final out = <String>[];
    void visit(int r, int c) {
      final v = reader.valueAt(sheetId, r, c);
      if (v.isBlank()) return;
      final t = reader.display.displayText(
        v,
        reader.numberFormatAt(sheetId, r, c),
      );
      if (t.isEmpty) return;
      if (seen.add(t)) out.add(t);
    }

    // Large (open-ended) ranges iterate stored cells only.
    if (sheet != null && rect.cellCount > 200000) {
      for (final (r, c, _) in sheet.cellsIn(rect, contentOnly: true)) {
        visit(r, c);
        if (out.length >= limit) break;
      }
      return out;
    }
    for (var r = rect.top; r <= rect.bottom && out.length < limit; r++) {
      for (var c = rect.left; c <= rect.right && out.length < limit; c++) {
        visit(r, c);
      }
    }
    return out;
  }

  /// The items of list criteria.
  static List<String> listItems(DvListCriteria criteria) => [
    for (final o in criteria.options) o.value,
  ];

  /// Items of `oneOfRange` criteria resolved against [sheet] (empty when the
  /// range doesn't resolve).
  static List<String> rangeItems(
    DvRangeCriteria criteria,
    SheetModel sheet,
    CellTextReader reader,
  ) {
    final rr = sheet.resolve(criteria.range);
    if (rr == null) return const [];
    return distinctValues(reader, sheet.id, rr.rect, sheet: sheet);
  }

  /// Distinct display values of a selection for *Convert to dropdown* (≤ 500,
  /// else null: "Too many distinct values to convert to a dropdown").
  static List<DvOption>? optionsFromValues(
    CellTextReader reader,
    String sheetId,
    GridRect rect,
  ) {
    final values = distinctValues(reader, sheetId, rect, limit: 501);
    if (values.length > 500) return null;
    return [
      for (var i = 0; i < values.length; i++)
        DvOption(values[i], colors: DvChipPalette.at(i)),
    ];
  }
}
