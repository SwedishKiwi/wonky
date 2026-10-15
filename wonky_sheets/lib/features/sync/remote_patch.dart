import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets_core/model.dart';

/// Builds the `RowChange`s that bring a [WorkbookModel] in line with rows
/// read from the replica (Sheets 02 §6 change ingestion): the shared kit's
/// [RowPatch] in Sheets' table order.
///
/// Rows still queued for the writer (`pending`, oldest first) are overlaid
/// on the replica rows, so a remote patch never undoes an optimistic local
/// edit that isn't stored yet. Rows whose model columns already equal the
/// replica (the echo of the device's own writes) produce no change.
abstract final class RemotePatch {
  /// Changes for the rows [changed] (table → ids) given their current
  /// replica values [rows] (table → id → columns; missing = not visible).
  static List<RowChange> build(
    WorkbookModel model,
    Map<String, Set<UuidValue>> changed,
    Map<String, Map<String, Map<String, Object?>>> rows,
    List<RowChange> pending,
  ) => RowPatch.build(
    model,
    {for (final e in changed.entries) e.key: e.value.map((id) => id.uuid)},
    rows,
    pending,
    rank: SheetsTables.rank,
  );

  /// Changes that turn [model] into exactly [all] (every model row of the
  /// space, as read by `SheetsReplica.loadSpace`) plus [pending].
  static List<RowChange> reconcile(
    WorkbookModel model,
    List<(String, Map<String, Object?>)> all,
    List<RowChange> pending,
  ) => RowPatch.reconcile(
    model,
    model.allRows(),
    all,
    pending,
    rank: SheetsTables.rank,
  );

  /// Whether every column of [next] has the same value in [current]
  /// (numbers by value, times to the millisecond).
  static bool sameColumns(
    Map<String, Object?> current,
    Map<String, Object?> next,
  ) => RowPatch.sameColumns(current, next);
}
