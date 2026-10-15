import 'package:serverpod_database/serverpod_database.dart';
import 'package:wonky_client/wonky_client.dart' as proto show ActorKind;
import 'package:wonky_client/wonky_client.dart' hide ActorKind;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show ChangeLogEntry, SyncWriter;

import 'sheets_replica.dart';

/// Applies `RowChange`s to the local Sheets replica (Sheets 02 §7, 13
/// §4.1): the shared kit's [SyncWriter] (chunked `transactionForUser`,
/// column-named updates, set-based `bulkWrite` runs, dirty marks) with the
/// Sheets `ChangeLog` row.
///
/// An insert whose cell is already visible (two devices creating the same
/// deterministic cell id) updates the given columns but the cell's foreign
/// keys (fixed by its deterministic id; rewriting them would force a
/// projection pass).
class SheetsWriter extends SyncWriter {
  SheetsWriter(SheetsReplica super.replica);

  /// Max row changes per transaction (02 §7).
  static const chunkSize = SyncWriter.chunkSize;

  /// Max rows per set-based engine write inside a transaction.
  static const runSize = SyncWriter.runSize;

  @override
  Future<void> writeChangeLog(
    DatabaseSession session,
    ChangeLogEntry entry,
    Transaction transaction,
  ) => ChangeLog.db.insertRow(
    session,
    ChangeLog(
      spreadsheetId: entry.spaceId,
      userId: entry.userId,
      actorKind: _actorKind(entry.actorKind),
      sessionId: entry.sessionId,
      label: entry.label,
      summaryJson: entry.summaryJson,
      detailJson: entry.detailJson,
      at: entry.at,
    ),
    transaction: transaction,
  );

  @override
  Iterable<String> columnsIfVisible(RowChange change) => [
    for (final k in change.columnsAfter.keys)
      if (k != Cols.id &&
          !(change.table == SheetsTables.cell && _cellKeys.contains(k)))
        k,
  ];

  static const _cellKeys = {Cols.sheetId, CellCols.rowId, CellCols.columnId};

  static proto.ActorKind _actorKind(String name) {
    for (final k in proto.ActorKind.values) {
      if (k.name == name) return k;
    }
    return proto.ActorKind.user;
  }

  /// A `ChangeLog` summary for changes without a plan (undo/redo, remote
  /// re-application): sheets, kinds and deleted/revived structure ids.
  @override
  ChangeSummary summarize(List<RowChange> changes) {
    final s = ChangeSummary();
    for (final c in changes) {
      final sheet =
          c.columnsAfter[Cols.sheetId] ?? c.columnsBefore[Cols.sheetId];
      if (sheet != null) s.sheets.add('$sheet');
      s.kinds.add(switch (c.table) {
        SheetsTables.cell =>
          c.touchedColumns.any(
                (k) => k == CellCols.content || k == CellCols.note,
              )
              ? ChangeKinds.values
              : ChangeKinds.format,
        SheetsTables.sheetRow ||
        SheetsTables.sheetColumn ||
        SheetsTables.mergedRange ||
        SheetsTables.dimensionGroup => ChangeKinds.structure,
        SheetsTables.sheet => ChangeKinds.sheets,
        SheetsTables.spreadsheet => ChangeKinds.settings,
        SheetsTables.namedRange => ChangeKinds.names,
        SheetsTables.protectedRange => ChangeKinds.protection,
        SheetsTables.basicFilter ||
        SheetsTables.filterView => ChangeKinds.filters,
        SheetsTables.embeddedObject ||
        SheetsTables.pivotTable => ChangeKinds.objects,
        SheetsTables.conditionalFormatRule ||
        SheetsTables.dataValidationRule ||
        SheetsTables.banding => ChangeKinds.rules,
        _ => ChangeKinds.scripts,
      });
      final kind = switch (c.table) {
        SheetsTables.sheetRow => 'rows',
        SheetsTables.sheetColumn => 'cols',
        SheetsTables.sheet => 'sheets',
        _ => null,
      };
      if (kind == null) continue;
      if (c.op == RowOp.delete) s.addDeleted(kind, c.rowId);
      if (c.op == RowOp.insert) s.addRevived(kind, c.rowId);
    }
    return s;
  }
}
