import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_sheets_core/model.dart'
    show ChangeKinds, ChangeSummary, RowChange, RowOp, SheetsTables;

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/files/file_service.dart';
import '../spaces/space_service.dart';
import 'sync_db.dart';
import 'synced_tables.dart';

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
abstract final class ServerSheetsWriter {
  static const chunkSize = 5000;
  static const inlineInverseLimit = 256 * 1024;

  static Object? _jsonValue(Object? v) => switch (v) {
    DateTime() => v.toUtc().toIso8601String(),
    UuidValue() => v.uuid,
    _ => v,
  };

  static String _cmp(Object? v) => jsonEncode(_jsonValue(v));

  /// Applies [changes] (ordered) as [actor]. With [skipChangedBy] (revert/
  /// reapply), an update column whose current value differs from the
  /// expected value in that map's change (`columnsBefore` of the given
  /// change) is skipped and reported.
  static Future<AppliedChanges> apply(
    Session session, {
    required Actor actor,
    required UuidValue spaceUuid,
    required List<RowChange> changes,
    required String label,
    Set<String> kinds = const {ChangeKinds.values},
    bool skipChanged = false,
  }) async {
    final db = syncSessionOf(session);
    final applied = <RowChange>[];
    final skipped = <RevertSkip>[];
    for (var i = 0; i < changes.length; i += chunkSize) {
      final chunk = changes.sublist(
        i,
        i + chunkSize > changes.length ? changes.length : i + chunkSize,
      );
      final summary = ChangeSummary(kinds: kinds);
      await db.offlineSyncDb.transactionForUser(
        actor.authUserId,
        (tx) async {
          for (final change in chunk) {
            final table = syncedTablesByName[change.table];
            if (table == null) continue;
            final id = UuidValue.fromString(change.rowId);
            final current = (await table.findByIds(db, {id})).firstOrNull;
            final currentJson = current == null
                ? null
                : (current.toJson() as Map).cast<String, dynamic>();
            final sheetId = (change.columnsAfter['sheetId'] ??
                    change.columnsBefore['sheetId'] ??
                    currentJson?['sheetId'])
                ?.toString();
            if (sheetId != null) summary.sheets.add(sheetId);
            switch (change.op) {
              case RowOp.insert:
                final json = <String, dynamic>{
                  for (final e in change.columnsAfter.entries)
                    e.key: _jsonValue(e.value),
                };
                if (currentJson != null) {
                  // Already visible: overwrite the given columns.
                  final names = json.keys.where((k) => k != 'id').toList();
                  final before = {for (final k in names) k: currentJson[k]};
                  await _update(db, table, currentJson, json, names, tx);
                  applied.add(RowChange.update(change.table, change.rowId, before, json));
                } else {
                  await db.db.insertRow(table.fromJson(json), transaction: tx);
                  applied.add(change);
                  if (change.table == SheetsTables.sheetRow) {
                    summary.addRevived('rows', change.rowId);
                  } else if (change.table == SheetsTables.sheetColumn) {
                    summary.addRevived('cols', change.rowId);
                  } else if (change.table == SheetsTables.sheet) {
                    summary.addRevived('sheets', change.rowId);
                  }
                }
              case RowOp.update:
                if (currentJson == null) {
                  skipped.add(
                    RevertSkip(
                      table: change.table,
                      rowId: id,
                      column: '*',
                      reason: 'row_deleted',
                    ),
                  );
                  continue;
                }
                final names = <String>[];
                final before = <String, Object?>{};
                final after = <String, Object?>{};
                for (final e in change.columnsAfter.entries) {
                  if (e.key == 'id') continue;
                  if (skipChanged &&
                      change.columnsBefore.containsKey(e.key) &&
                      _cmp(currentJson[e.key]) !=
                          _cmp(change.columnsBefore[e.key])) {
                    skipped.add(
                      RevertSkip(
                        table: change.table,
                        rowId: id,
                        column: e.key,
                        reason: 'changed_by_other',
                      ),
                    );
                    continue;
                  }
                  names.add(e.key);
                  before[e.key] = currentJson[e.key];
                  after[e.key] = _jsonValue(e.value);
                }
                if (names.isEmpty) continue;
                await _update(db, table, currentJson, after, names, tx);
                applied.add(
                  RowChange.update(change.table, change.rowId, before, after),
                );
              case RowOp.delete:
                if (currentJson == null) continue;
                await db.db.deleteRow(current!, transaction: tx);
                applied.add(
                  RowChange.delete(change.table, change.rowId, currentJson),
                );
                if (change.table == SheetsTables.sheetRow) {
                  summary.addDeleted('rows', change.rowId);
                } else if (change.table == SheetsTables.sheetColumn) {
                  summary.addDeleted('cols', change.rowId);
                } else if (change.table == SheetsTables.sheet) {
                  summary.addDeleted('sheets', change.rowId);
                }
            }
          }
          await ChangeLog.db.insertRow(
            db,
            ChangeLog(
              spreadsheetId: spaceUuid,
              userId: actor.authUserId,
              actorKind: actor.kind,
              sessionId: 'server:${actor.kind.name}',
              label: label,
              summaryJson: summary.encode(),
              at: nowUtc(),
            ),
            transaction: tx,
          );
        },
        spaceId: spaceUuid,
      );
    }
    return AppliedChanges(applied, skipped);
  }

  static Future<void> _update(
    DatabaseSession db,
    SyncedTable table,
    Map<String, dynamic> currentJson,
    Map<String, dynamic> changes,
    List<String> names,
    Transaction tx,
  ) async {
    final merged = {...currentJson, ...changes};
    final row = table.fromJson(merged);
    final columns = [
      for (final n in names)
        if (table.column(n) != null) table.column(n)!,
    ];
    if (columns.isEmpty) return;
    await db.db.updateRow(row, columns: columns, transaction: tx);
  }

  // ------------------------------------------------------------ records

  static String _encode(List<RowChange> changes) => base64Encode(
    gzip.encode(utf8.encode(jsonEncode([for (final c in changes) c.toJson()]))),
  );

  static List<RowChange> _decode(String data) => [
    for (final m
        in jsonDecode(utf8.decode(gzip.decode(base64Decode(data))))
            as List<dynamic>)
      RowChange.fromJson((m as Map).cast<String, Object?>()),
  ];

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
  }) async {
    final inverse = [for (final c in applied.reversed) c.inverse()];
    final inverseData = _encode(inverse);
    final forwardData = _encode(applied);
    final changeId = const Uuid().v7obj();
    UuidValue? inverseFile;
    UuidValue? forwardFile;
    String? inlineInverse;
    if (inverseData.length <= inlineInverseLimit) {
      inlineInverse = inverseData;
    } else {
      inverseFile = (await FileService.storeServerFile(
        session,
        ownerId: actor.userId,
        itemId: item.id,
        kind: StoredFileKind.snapshot,
        fileName: '$changeId.inverse',
        mimeType: 'application/octet-stream',
        bytes: Uint8List.fromList(utf8.encode(inverseData)),
      )).fileUuid;
    }
    forwardFile = (await FileService.storeServerFile(
      session,
      ownerId: actor.userId,
      itemId: item.id,
      kind: StoredFileKind.snapshot,
      fileName: '$changeId.forward',
      mimeType: 'application/octet-stream',
      bytes: Uint8List.fromList(utf8.encode(forwardData)),
    )).fileUuid;
    final now = nowUtc();
    await ServerChangeRecord.db.insertRow(
      session,
      ServerChangeRecord(
        changeId: changeId,
        spreadsheetUuid: item.contentRef!,
        userId: actor.userId,
        actorKind: actor.kind,
        label: label,
        inverseJson: inlineInverse,
        inverseFileId: inverseFile,
        forwardFileId: forwardFile,
        cellsAffected: applied.where((c) => c.table == SheetsTables.cell).length,
        createdAt: now,
        expiresAt: now.add(lifetime),
      ),
    );
    return changeId;
  }

  static Future<String> _fileText(Session session, UuidValue fileUuid) async {
    final file = await FileService.byUuid(session, fileUuid);
    if (file == null) throw Errors.expired('The change can no longer be undone.');
    final bytes = await FileService.readBytes(session, file);
    return utf8.decode(bytes.buffer.asUint8List(0, bytes.lengthInBytes));
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
    if (record.spreadsheetUuid != item.contentRef) throw Errors.notFound('Change');
    final data = record.inverseJson ??
        await _fileText(session, record.inverseFileId!);
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
    if (record.spreadsheetUuid != item.contentRef) throw Errors.notFound('Change');
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
