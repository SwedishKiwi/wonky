import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_slides_core/model.dart' show DeckModel;
import 'package:wonky_slides_core/schema.dart' show SlidesTables;
import 'package:wonky_sync_kit/rows.dart';

/// Builds the `RowChange`s that bring a [DeckModel] in line with rows read
/// from the replica (Slides 02 §11 "Remote changes", as Sheets 02 §6): the
/// shared kit's [RowPatch] in the Slides dependency order
/// (`SlidesTables.rank`).
///
/// Rows still queued for the writer (`pending`, oldest first) are overlaid
/// on the replica rows, so a remote patch never undoes an optimistic local
/// edit that isn't stored yet. Rows whose model columns already equal the
/// replica (the echo of the device's own writes) produce no change.
abstract final class DeckRemotePatch {
  /// Changes for the rows [changed] (table → ids) given their current
  /// replica values [rows] (table → id → columns; missing = not visible).
  static List<RowChange> build(
    DeckModel model,
    Map<String, Set<UuidValue>> changed,
    Map<String, Map<String, Map<String, Object?>>> rows,
    List<RowChange> pending,
  ) => RowPatch.build(
    model,
    {for (final e in changed.entries) e.key: e.value.map((id) => id.uuid)},
    rows,
    pending,
    rank: SlidesTables.rank,
  );

  /// Changes that turn [model] into exactly [all] (every model row of the
  /// deck, as read by `SlidesReplica.loadSpace`) plus [pending].
  static List<RowChange> reconcile(
    DeckModel model,
    List<(String, Map<String, Object?>)> all,
    List<RowChange> pending,
  ) => RowPatch.reconcile(
    model,
    modelRows(model),
    all,
    pending,
    rank: SlidesTables.rank,
  );

  /// Every row of [model] as `(table, columns)`, in dependency order.
  static Iterable<(String, Map<String, Object?>)> modelRows(
    DeckModel model,
  ) sync* {
    for (final table in SlidesTables.dependencyOrder) {
      if (SlidesTables.nonModelTables.contains(table)) continue;
      for (final r in model.records(table)) {
        yield (table, r.columns);
      }
    }
  }
}
