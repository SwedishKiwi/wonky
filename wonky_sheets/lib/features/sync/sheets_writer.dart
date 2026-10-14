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
/// - The `ChangeLog` row is written in the transaction of the last chunk.
class SheetsWriter {
  SheetsWriter(this.replica);

  final SheetsReplica replica;

  /// Max row changes per transaction (02 §7).
  static const chunkSize = MutationPlan.chunkSize;

  DatabaseSession get _s => replica.session;

  /// Writes [changes] into the space [spaceId] with the `ChangeLog` row
  /// ([plan] supplies its summary and detail; without a plan they are
  /// derived from [changes]).
  Future<void> write({
    required UuidValue spaceId,
    required List<RowChange> changes,
    MutationPlan? plan,
    required String label,
    required String actorKind,
    required String sessionId,
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
    }
    await replica.markDirty(spaceId);
  }

  Future<void> _applyChunk(List<RowChange> chunk, Transaction tx) async {
    var i = 0;
    while (i < chunk.length) {
      final c = chunk[i];
      final spec = SyncedTables.of(c.table);
      if (c.op == RowOp.update) {
        await spec.updateColumns(
          _s,
          UuidValue.fromString(c.rowId),
          c.columnsAfter,
          transaction: tx,
        );
        i++;
        continue;
      }
      // A run of inserts (or deletes) into one table is one statement.
      var j = i + 1;
      while (j < chunk.length &&
          chunk[j].op == c.op &&
          chunk[j].table == c.table) {
        j++;
      }
      final run = chunk.sublist(i, j);
      i = j;
      final ids = [for (final r in run) UuidValue.fromString(r.rowId)];
      if (c.op == RowOp.delete) {
        await spec.deleteByIds(_s, ids, transaction: tx);
        continue;
      }
      final visible = {
        for (final r in await spec.findByIds(_s, ids, transaction: tx))
          r.id.uuid,
      };
      final inserts = <Map<String, Object?>>[];
      for (final r in run) {
        if (visible.contains(r.rowId)) {
          await spec.updateColumns(
            _s,
            UuidValue.fromString(r.rowId),
            {...r.columnsAfter}..remove(Cols.id),
            transaction: tx,
          );
        } else {
          inserts.add({...r.columnsAfter, Cols.id: r.rowId});
        }
      }
      await spec.insertRows(_s, inserts, transaction: tx);
    }
  }

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
