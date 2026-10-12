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
  static Map<String, ObjectAnchor> plan(SheetModel sheet) {
    final out = <String, ObjectAnchor>{};
    final ids = sheet.objects.keys.toList()..sort();
    for (final id in ids) {
      final anchor = ObjectAnchor.tryParse(sheet.objects[id]!.anchorJson);
      if (anchor == null || anchor.ownSheet) continue;
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
