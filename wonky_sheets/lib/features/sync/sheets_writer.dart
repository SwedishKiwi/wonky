import 'package:clock/clock.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:wonky_client/wonky_client.dart' as proto show ActorKind;
import 'package:wonky_client/wonky_client.dart' hide ActorKind;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/tables.dart';

import 'sheets_replica.dart';

/// Applies `RowChange`s to the local replica (Sheets 02 §7, 13 §4.1): the
/// client implementation of the `SyncTxAdapter` contract.
///
/// - One `transactionForUser(user, …, spaceId: spreadsheetId)` per chunk of
///   ≤ [chunkSize] changes (one space per transaction, suite 12 §2.1).
/// - **Updates name exactly the touched columns** (`columnValues` built from
///   `RowChange.columnsAfter`); there is no whole-row update in this file
///   (`test/sync/columns_lint_test.dart` enforces it).
/// - Inserts insert full rows; inserting a deleted id revives the tombstone.
///   An insert whose row is already visible (two devices creating the same
///   deterministic cell id) becomes an update of the given columns.
/// - Deletes tombstone.
/// - Consecutive inserts/updates of one table run as one set-based engine
///   write (`SyncedTableSpec.bulkWrite`, offline-sync patch OS-7): a few
///   batched statements per run instead of ~6 queries per row.
/// - The `ChangeLog` row is written in the transaction of the last chunk.
class SheetsWriter {
  SheetsWriter(this.replica);

  final SheetsReplica replica;

  /// Max row changes per transaction (02 §7).
  static const chunkSize = MutationPlan.chunkSize;

  /// Max rows per set-based engine write inside a transaction.
  static const runSize = 1000;

  DatabaseSession get _s => replica.session;

  /// Writes [changes] into the space [spaceId] with the `ChangeLog` row
  /// ([plan] supplies its summary and detail; without a plan they are
  /// derived from [changes]). [onProgress] is called after each stored
  /// chunk (changes written so far, total).
  Future<void> write({
    required UuidValue spaceId,
    required List<RowChange> changes,
    MutationPlan? plan,
    required String label,
    required String actorKind,
    required String sessionId,
    void Function(int written, int total)? onProgress,
  }) async {
    if (changes.isEmpty) return;
    final summary = plan?.summary ?? summarize(changes);
    final detailJson = plan?.detailJson;
    for (var i = 0; i < changes.length; i += chunkSize) {
      final end = i + chunkSize > changes.length
          ? changes.length
          : i + chunkSize;
      final chunk = changes.sublist(i, end);
      final last = end == changes.length;
      await replica.db.transactionForUser(replica.userUuid, (tx) async {
        await _applyChunk(chunk, tx);
        if (last) {
          await ChangeLog.db.insertRow(
            _s,
            ChangeLog(
              spreadsheetId: spaceId,
              userId: replica.userUuid,
              actorKind: _actorKind(actorKind),
              sessionId: sessionId,
              label: label,
              summaryJson: summary.encode(),
              detailJson: detailJson,
              at: clock.now().toUtc(),
            ),
            transaction: tx,
          );
        }
      }, spaceId: spaceId);
      onProgress?.call(end, changes.length);
    }
    await replica.markDirty(spaceId);
  }

  Future<void> _applyChunk(List<RowChange> chunk, Transaction tx) async {
    var i = 0;
    while (i < chunk.length) {
      final c = chunk[i];
      final spec = SyncedTables.of(c.table);
      var j = i + 1;
      if (c.op == RowOp.delete) {
        // A run of deletes of one table is one statement per 500 ids.
        while (j < chunk.length &&
            chunk[j].op == RowOp.delete &&
            chunk[j].table == c.table) {
          j++;
        }
        await spec.deleteByIds(_s, [
          for (final r in chunk.sublist(i, j)) UuidValue.fromString(r.rowId),
        ], transaction: tx);
        i = j;
        continue;
      }
      // A run of inserts and updates of one table with distinct ids is one
      // set-based engine write (offline-sync patch OS-7). Runs are capped
      // at [runSize] rows so the Dart-side encoding between two awaits stays
      // within a frame or two.
      final ids = {c.rowId};
      while (j < chunk.length &&
          j - i < runSize &&
          chunk[j].op != RowOp.delete &&
          chunk[j].table == c.table &&
          ids.add(chunk[j].rowId)) {
        j++;
      }
      final writes = [for (final r in chunk.sublist(i, j)) _rowWrite(r)];
      await spec.bulkWrite(_s, writes, transaction: tx);
      i = j;
    }
  }

  /// The engine write of an insert or update. An insert whose row is
  /// already visible updates the given columns; a cell's foreign keys are
  /// left out of that update (they are fixed by its deterministic id, and
  /// rewriting them would force a projection pass).
  static SyncedRowWrite _rowWrite(RowChange r) {
    final id = UuidValue.fromString(r.rowId);
    if (r.op == RowOp.update) {
      return SyncedRowWrite.updateColumns(id, r.columnsAfter);
    }
    return SyncedRowWrite.insert(
      id,
      r.columnsAfter,
      columnsIfVisible: [
        for (final k in r.columnsAfter.keys)
          if (k != Cols.id &&
              !(r.table == SheetsTables.cell && _cellKeys.contains(k)))
            k,
      ],
    );
  }

  static const _cellKeys = {Cols.sheetId, CellCols.rowId, CellCols.columnId};

  static proto.ActorKind _actorKind(String name) {
    for (final k in proto.ActorKind.values) {
      if (k.name == name) return k;
    }
    return proto.ActorKind.user;
  }

  /// A `ChangeLog` summary for changes without a plan (undo/redo, remote
  /// re-application): sheets, kinds and deleted/revived structure ids.
  static ChangeSummary summarize(List<RowChange> changes) {
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
