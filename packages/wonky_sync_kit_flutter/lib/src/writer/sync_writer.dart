import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_models/tables.dart';

import '../replica/sync_replica.dart';

/// The change-log row a [SyncWriter] stores with the last chunk of a write
/// (Sheets `ChangeLog`, Slides `DeckChangeLog`).
final class ChangeLogEntry {
  const ChangeLogEntry({
    required this.spaceId,
    required this.userId,
    required this.actorKind,
    required this.sessionId,
    required this.label,
    required this.summaryJson,
    required this.detailJson,
    required this.at,
  });

  final UuidValue spaceId;
  final UuidValue userId;
  final String actorKind;
  final String sessionId;
  final String label;
  final String summaryJson;
  final String? detailJson;
  final DateTime at;
}

/// Applies `RowChange`s to the local replica (Sheets 02 §7, 13 §4.1;
/// Slides 02 §12.2): the client implementation of [SyncTxAdapter].
///
/// - One `transactionForUser(user, …, spaceId: space)` per chunk of
///   ≤ [chunkSize] changes (one space per transaction, suite 12 §2.1).
/// - **Updates name exactly the touched columns** (`columnValues` built from
///   `RowChange.columnsAfter`); there is no whole-row update in this file
///   (Sheets' `test/sync/columns_lint_test.dart` enforces it).
/// - Inserts insert full rows; inserting a deleted id revives the tombstone.
///   An insert whose row is already visible (two devices creating the same
///   deterministic id) becomes an update of the given columns
///   ([columnsIfVisible]).
/// - Deletes tombstone.
/// - Consecutive inserts/updates of one table run as one set-based engine
///   write (`SyncedTableSpec.bulkWrite`, offline-sync patch OS-7): a few
///   batched statements per run instead of ~6 queries per row.
/// - The change-log row ([writeChangeLog]) is written in the transaction of
///   the last chunk; the space is then marked dirty.
///
/// Apps subclass it for their change log ([writeChangeLog]) and the summary
/// of changes without a plan ([summarize]).
abstract class SyncWriter implements SyncTxAdapter {
  SyncWriter(this.replica);

  final SyncReplica replica;

  /// Max row changes per transaction.
  static const chunkSize = MutationPlan.chunkSize;

  /// Max rows per set-based engine write inside a transaction.
  static const runSize = 1000;

  DatabaseSession get _s => replica.session;

  /// Inserts the change-log row [entry] in [transaction].
  Future<void> writeChangeLog(
    DatabaseSession session,
    ChangeLogEntry entry,
    Transaction transaction,
  );

  /// The change-log summary of [changes] written without a plan (undo/redo,
  /// remote re-application).
  ChangeSummary summarize(List<RowChange> changes);

  /// Columns an insert of [change] updates when its row is already visible
  /// (default: every given column but `id`). Apps leave out columns fixed
  /// by a deterministic id (Sheets: a cell's foreign keys).
  Iterable<String> columnsIfVisible(RowChange change) => [
    for (final k in change.columnsAfter.keys)
      if (k != RowChange.idColumn) k,
  ];

  @override
  Future<void> apply(
    MutationPlan<ChangeSummary> plan, {
    required String spaceId,
    required String actorKind,
    required String sessionId,
  }) => write(
    spaceId: UuidValue.fromString(spaceId),
    changes: plan.changes,
    plan: plan,
    label: plan.label,
    actorKind: actorKind,
    sessionId: sessionId,
  );

  /// Writes [changes] into the space [spaceId] with the change-log row
  /// ([plan] supplies its summary and detail; without a plan they are
  /// derived from [changes]). [onProgress] is called after each stored
  /// chunk (changes written so far, total).
  Future<void> write({
    required UuidValue spaceId,
    required List<RowChange> changes,
    MutationPlan<ChangeSummary>? plan,
    required String label,
    required String actorKind,
    required String sessionId,
    void Function(int written, int total)? onProgress,
  }) async {
    if (changes.isEmpty) return;
    final summaryJson = plan?.summaryJson ?? _encode(summarize(changes));
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
          await writeChangeLog(
            _s,
            ChangeLogEntry(
              spaceId: spaceId,
              userId: replica.userUuid,
              actorKind: actorKind,
              sessionId: sessionId,
              label: label,
              summaryJson: summaryJson,
              detailJson: detailJson,
              at: clock.now().toUtc(),
            ),
            tx,
          );
        }
      }, spaceId: spaceId);
      onProgress?.call(end, changes.length);
    }
    await replica.markDirty(spaceId);
  }

  static String _encode(ChangeSummary s) => jsonEncode(s.toJson());

  Future<void> _applyChunk(List<RowChange> chunk, Transaction tx) async {
    final tables = replica.tables;
    var i = 0;
    while (i < chunk.length) {
      final c = chunk[i];
      final spec = tables.of(c.table);
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

  /// The engine write of an insert or update.
  SyncedRowWrite _rowWrite(RowChange r) {
    final id = UuidValue.fromString(r.rowId);
    if (r.op == RowOp.update) {
      return SyncedRowWrite.updateColumns(id, r.columnsAfter);
    }
    return SyncedRowWrite.insert(
      id,
      r.columnsAfter,
      columnsIfVisible: columnsIfVisible(r).toList(),
    );
  }
}
