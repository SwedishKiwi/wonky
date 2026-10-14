import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_sheets_core/model.dart'
    show ChangeKinds, ChangeSummary, RowChange, RowOp, SheetsTables;

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/files/file_service.dart';
import '../mcp/sheets_bulk_writer.dart';
import '../spaces/space_service.dart';

/// Outcome of applying row changes server-side.
class AppliedChanges {
  AppliedChanges(this.applied, this.skipped);

  /// The changes as applied, with the actual previous values (their inverse
  /// undoes exactly what was written).
  final List<RowChange> applied;
  final List<RevertSkip> skipped;

  int get cellsAffected =>
      applied.where((c) => c.table == SheetsTables.cell).length;
}

/// Applies `RowChange`s to a spreadsheet space on the server (Sheets 12
/// §2.4): every update names its columns, writes run in
/// `transactionForUser` per chunk of ≤ 5,000 changes, each chunk with a
/// `ChangeLog` row. Server changes are recorded as [ServerChangeRecord]s so
/// they can be reverted/reapplied (`sheets.serverChange` undo domain).
///
/// The writes go through the batched [SheetsBulkWriter] (current rows read
/// once per table and chunk, inserts and deletes in one CRDT-tracked
/// statement per table), so reverts and restores of 50,000 cells take
/// seconds instead of minutes.
abstract final class ServerSheetsWriter {
  static const chunkSize = 5000;
  static const inlineInverseLimit = 256 * 1024;

  /// Applies [changes] (ordered) as [actor]. With [skipChanged] (revert/
  /// reapply), an update column whose current value differs from the
  /// expected value (`columnsBefore` of the change) is skipped and
  /// reported; a reverted cell insert keeps the columns others changed.
  static Future<AppliedChanges> apply(
    Session session, {
    required Actor actor,
    required UuidValue spaceUuid,
    required List<RowChange> changes,
    required String label,
    Set<String> kinds = const {ChangeKinds.values},
    bool skipChanged = false,
  }) => SheetsBulkWriter.apply(
    session,
    actor: actor,
    spaceUuid: spaceUuid,
    changes: changes,
    label: label,
    plans: const [],
    skipChanged: skipChanged,
    kinds: kinds,
    summary: structureSummary(changes),
  );

  /// Deleted/revived rows, columns and sheets of [changes] for the
  /// `ChangeLog` summary (history and "row deleted by …" read them).
  static ChangeSummary structureSummary(List<RowChange> changes) {
    final s = ChangeSummary();
    for (final c in changes) {
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

  /// Applies [changes] for [actor] on [item] and stores a record for undo.
  static Future<(UuidValue, AppliedChanges)> applyRecorded(
    Session session, {
    required Actor actor,
    required DriveItem item,
    required List<RowChange> changes,
    required String label,
    Set<String> kinds = const {ChangeKinds.values},
    Duration lifetime = const Duration(hours: 24),
  }) async {
    await SpaceService.ensureWriter(session, actor, item);
    final result = await apply(
      session,
      actor: actor,
      spaceUuid: item.contentRef!,
      changes: changes,
      label: label,
      kinds: kinds,
    );
    final changeId = await _record(
      session,
      actor: actor,
      item: item,
      label: label,
      applied: result.applied,
      lifetime: lifetime,
    );
    return (changeId, result);
  }

  static Future<UuidValue> _record(
    Session session, {
    required Actor actor,
    required DriveItem item,
    required String label,
    required List<RowChange> applied,
    required Duration lifetime,
  }) => SheetsChangeRecords.store(
    session,
    actor: actor,
    item: item,
    label: label,
    applied: applied,
    lifetime: lifetime,
  );

  static List<RowChange> _decode(String data) =>
      SheetsChangeRecords.decode(data);

  static Future<String> _fileText(Session session, UuidValue fileUuid) async {
    final file = await FileService.byUuid(session, fileUuid);
    if (file == null) {
      throw Errors.expired('The change can no longer be undone.');
    }
    final bytes = await FileService.readBytes(session, file);
    return utf8.decode(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }

  static Future<ServerChangeRecord> _requireRecord(
    Session session,
    Actor actor,
    UuidValue changeId,
  ) async {
    final record = await ServerChangeRecord.db.findFirstRow(
      session,
      where: (t) => t.changeId.equals(changeId),
    );
    if (record == null) throw Errors.notFound('Change');
    if (record.expiresAt.isBefore(nowUtc())) {
      throw Errors.expired('The change can no longer be undone.');
    }
    return record;
  }

  /// Reverts a recorded change with the per-column skip rule.
  static Future<RevertResult> revert(
    Session session,
    Actor actor,
    DriveItem item,
    UuidValue changeId,
  ) async {
    final record = await _requireRecord(session, actor, changeId);
    if (record.spreadsheetUuid != item.contentRef) {
      throw Errors.notFound('Change');
    }
    final data =
        record.inverseJson ?? await _fileText(session, record.inverseFileId!);
    final inverse = _decode(data);
    await SpaceService.ensureWriter(session, actor, item);
    final result = await apply(
      session,
      actor: actor,
      spaceUuid: record.spreadsheetUuid,
      changes: inverse,
      label: 'Undo ${record.label}',
      skipChanged: true,
    );
    final revertId = await _record(
      session,
      actor: actor,
      item: item,
      label: 'Undo ${record.label}',
      applied: result.applied,
      lifetime: const Duration(hours: 24),
    );
    await ServerChangeRecord.db.updateRow(
      session,
      record.copyWith(revertedAt: nowUtc(), revertChangeId: revertId),
    );
    return RevertResult(
      changeId: revertId,
      revertedCells: result.cellsAffected,
      skipped: result.skipped,
    );
  }

  /// Re-applies a reverted change (redo) with the same skip rule.
  static Future<RevertResult> reapply(
    Session session,
    Actor actor,
    DriveItem item,
    UuidValue changeId,
  ) async {
    final record = await _requireRecord(session, actor, changeId);
    if (record.spreadsheetUuid != item.contentRef) {
      throw Errors.notFound('Change');
    }
    if (record.forwardFileId == null) {
      throw Errors.expired('The change can no longer be redone.');
    }
    final forward = _decode(await _fileText(session, record.forwardFileId!));
    await SpaceService.ensureWriter(session, actor, item);
    final result = await apply(
      session,
      actor: actor,
      spaceUuid: record.spreadsheetUuid,
      changes: forward,
      label: record.label,
      skipChanged: true,
    );
    final redoId = await _record(
      session,
      actor: actor,
      item: item,
      label: record.label,
      applied: result.applied,
      lifetime: const Duration(hours: 24),
    );
    return RevertResult(
      changeId: redoId,
      revertedCells: result.cellsAffected,
      skipped: result.skipped,
    );
  }

  /// Daily job: deletes expired records and their files.
  static Future<int> purgeExpired(Session session, {DateTime? now}) async {
    final at = now ?? nowUtc();
    final expired = await ServerChangeRecord.db.find(
      session,
      where: (t) => t.expiresAt < at,
      limit: 1000,
    );
    for (final r in expired) {
      if (r.inverseFileId != null) {
        await FileService.deleteFile(session, r.inverseFileId!);
      }
      if (r.forwardFileId != null) {
        await FileService.deleteFile(session, r.forwardFileId!);
      }
      await ServerChangeRecord.db.deleteRow(session, r);
    }
    return expired.length;
  }
}
