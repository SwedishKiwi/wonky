import 'package:serverpod_database/serverpod_database.dart';
import 'package:wonky_client/wonky_client.dart' as proto show ActorKind;
import 'package:wonky_client/wonky_client.dart' show DeckChangeLog;
import 'package:wonky_slides_core/ops.dart' show SlidesChangeSummary;
import 'package:wonky_slides_core/schema.dart'
    show SlidesCols, SlidesTables, TableCellCols;
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show ChangeLogEntry, SyncWriter;

import 'slides_replica.dart';

/// Applies `RowChange`s to the local Slides replica (Slides 02 §12.2): the
/// shared kit's [SyncWriter] — one `transactionForUser(user, …, spaceId:
/// deck)` per ≤ 5,000 changes, updates naming exactly the touched columns
/// (`columnValues`), set-based `bulkWrite` runs, dirty marks — with the
/// `DeckChangeLog` row in the transaction of the last chunk.
///
/// An insert whose row is already visible (two devices creating the same
/// deterministic id: table cells, placeholder instances, theme copies,
/// chart links; 02 §2.1) updates the given columns but `id`, `createdAt`
/// and the foreign keys fixed by a table cell's deterministic id.
class SlidesWriter extends SyncWriter {
  SlidesWriter(SlidesReplica super.replica);

  /// Max row changes per transaction (02 §12.2).
  static const chunkSize = SyncWriter.chunkSize;

  @override
  Future<void> writeChangeLog(
    DatabaseSession session,
    ChangeLogEntry entry,
    Transaction transaction,
  ) => DeckChangeLog.db.insertRow(
    session,
    DeckChangeLog(
      deckId: entry.spaceId,
      userId: entry.userId,
      actorKind: actorKindOf(entry.actorKind),
      sessionId: entry.sessionId,
      label: entry.label,
      summaryJson: entry.summaryJson,
      detailJson: entry.detailJson,
      at: entry.at,
    ),
    transaction: transaction,
  );

  /// The summary of changes written without a plan (undo/redo, AI,
  /// recovery): kinds, slides, elements and deleted/revived ids (02
  /// §3.10.1).
  @override
  ChangeSummary summarize(List<RowChange> changes) =>
      SlidesChangeSummary.of(changes);

  @override
  Iterable<String> columnsIfVisible(RowChange change) => [
    for (final k in change.columnsAfter.keys)
      if (k != SlidesCols.id &&
          k != SlidesCols.createdAt &&
          !(change.table == SlidesTables.slideTableCell &&
              _cellKeys.contains(k)))
        k,
  ];

  static const _cellKeys = {
    SlidesCols.elementId,
    TableCellCols.rowId,
    TableCellCols.columnId,
  };

  /// The protocol actor kind named [name] (`user` for unknown names).
  static proto.ActorKind actorKindOf(String name) {
    for (final k in proto.ActorKind.values) {
      if (k.name == name) return k;
    }
    return proto.ActorKind.user;
  }
}
