import '../model/schema.dart';
import '../model/sheet_model.dart';
import '../mutations/row_change.dart';
import 'anchor.dart';

/// Idempotent anchor maintenance (08 §1.2, A-08-4): objects whose anchor row
/// or column was deleted are re-anchored by the first client that notices.
abstract final class AnchorMaintenance {
  /// Objects of [sheet] that need a new anchor, by object id (sorted by id).
  /// Unparseable and chart-sheet anchors are skipped. Empty when nothing is
  /// to do; applying the result and planning again yields an empty map.
  ///
  /// A deleted anchor row/column moves to the next surviving one by sort key
  /// (else the previous one). The anchor's own `rk`/`ck` hint is used first
  /// (shared by every client, so concurrent fixers agree); without it, the
  /// deleted entry's last known sort key ([SheetModel.removedSortKey]); only
  /// when neither is known does it fall back to the first row/column.
  static Map<String, ObjectAnchor> plan(SheetModel sheet) {
    final out = <String, ObjectAnchor>{};
    final ids = sheet.objects.keys.toList()..sort();
    for (final id in ids) {
      var anchor = ObjectAnchor.tryParse(sheet.objects[id]!.anchorJson);
      if (anchor == null || anchor.ownSheet) continue;
      final rowId = anchor.rowId;
      final colId = anchor.colId;
      if (anchor.rowKey == null &&
          rowId != null &&
          !sheet.rows.contains(rowId)) {
        final k = sheet.removedSortKey(Dimension.rows, rowId);
        if (k != null) anchor = anchor.copyWith(rowKey: k);
      }
      if (anchor.colKey == null &&
          colId != null &&
          !sheet.columns.contains(colId)) {
        final k = sheet.removedSortKey(Dimension.columns, colId);
        if (k != null) anchor = anchor.copyWith(colKey: k);
      }
      final fixed = anchor.reanchor(sheet.rows, sheet.columns);
      if (fixed != null) out[id] = fixed;
    }
    return out;
  }

  /// [plan] as `EmbeddedObject.anchorJson` updates.
  static List<RowChange> changes(SheetModel sheet) => [
    for (final e in plan(sheet).entries)
      RowChange.update(
        SheetsTables.embeddedObject,
        e.key,
        {'anchorJson': sheet.objects[e.key]!.anchorJson},
        {'anchorJson': e.value.encode()},
      ),
  ];
}
