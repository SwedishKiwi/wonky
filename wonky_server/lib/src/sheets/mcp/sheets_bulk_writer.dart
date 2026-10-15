import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_sync_models/tables.dart'
    show SyncedRowWrite, SyncedTables;
import 'package:wonky_sheets_core/model.dart'
    show
        ChangeKinds,
        ChangeSummary,
        MutationPlan,
        RowChange,
        RowOp,
        SheetsTables;

import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../../platform/files/file_service.dart';
import '../../platform/spaces/space_service.dart';
import '../sync/server_sheets_writer.dart';
import '../sync/sync_db.dart';
import '../sync/synced_tables.dart';

Future<void> _bulkWrite(
  DatabaseSession db,
  String table,
  List<SyncedRowWrite> writes,
  Transaction tx,
) async {
  if (writes.isEmpty) return;
  await SyncedTables.byName[table]!.bulkWrite(db, writes, transaction: tx);
}

/// Batched server writes of tool mutations (Sheets 12 §2.4): the same
/// semantics and records as [ServerSheetsWriter.applyRecorded] (named
/// columns, `transactionForUser` per chunk of ≤ 5,000 changes with a
/// `ChangeLog` row, a [ServerChangeRecord] that `changes.revert` and the
/// `sheets.serverChange` undo domain read), but current rows are read once
/// per table and inserts, revives and updates run as set-based engine
/// writes per table (`SyncedTableSpec.bulkWrite`, offline-sync patch OS-7),
/// which makes large writes (50,000 cells) practical.
abstract final class SheetsBulkWriter {
  static const chunkSize = ServerSheetsWriter.chunkSize;

  /// Identity columns never compared by the revert skip rule.
  static const _keyColumns = {
    'id',
    'sheetId',
    'rowId',
    'columnId',
    'createdAt',
    'spaceId',
  };

  static Object? _jsonValue(Object? v) => switch (v) {
    DateTime() => v.toUtc().toIso8601String(),
    UuidValue() => v.uuid,
    _ => v,
  };

  /// Applies [changes] (planner order) for [actor] on [item] and records
  /// them for revert. [summaries] (the plans' change summaries) become the
  /// `ChangeLog.summaryJson`.
  static Future<(UuidValue, AppliedChanges)> applyRecorded(
    Session session, {
    required Actor actor,
    required DriveItem item,
    required List<RowChange> changes,
    required String label,
    required List<MutationPlan> plans,
    Duration lifetime = const Duration(hours: 24),
    bool skipChanged = false,
    Set<String> kinds = const {},
  }) async {
    await SpaceService.ensureWriter(session, actor, item);
    final applied = await apply(
      session,
      actor: actor,
      spaceUuid: item.contentRef!,
      changes: changes,
      label: label,
      plans: plans,
      skipChanged: skipChanged,
      kinds: kinds,
    );
    final changeId = await SheetsChangeRecords.store(
      session,
      actor: actor,
      item: item,
      label: label,
      applied: applied.applied,
      lifetime: lifetime,
    );
    return (changeId, applied);
  }

  static ChangeSummary _summary(List<MutationPlan> plans, Set<String> kinds) {
    final s = ChangeSummary(kinds: {...kinds});
    for (final p in plans) {
      s.kinds.addAll(p.summary.kinds);
      s.sheets.addAll(p.summary.sheets);
      for (final r in p.summary.ranges) {
        s.addRange(r);
      }
      p.summary.deleted.forEach((k, ids) {
        for (final id in ids) {
          s.addDeleted(k, id);
        }
      });
      p.summary.revived.forEach((k, ids) {
        for (final id in ids) {
          s.addRevived(k, id);
        }
      });
    }
    if (s.kinds.isEmpty) s.kinds.add(ChangeKinds.values);
    return s;
  }

  /// Applies [changes] in chunks. Deletes run first (children first, as
  /// planned), then inserts in dependency order (one batch per table), then
  /// updates naming only their columns. [summary] is merged into the
  /// `ChangeLog` summary (callers without plans: reverts, scripts).
  static Future<AppliedChanges> apply(
    Session session, {
    required Actor actor,
    required UuidValue spaceUuid,
    required List<RowChange> changes,
    required String label,
    required List<MutationPlan> plans,
    bool skipChanged = false,
    Set<String> kinds = const {},
    ChangeSummary? summary,
  }) async {
    final db = syncSessionOf(session);
    final applied = <RowChange>[];
    final skipped = <RevertSkip>[];
    final summary0 = _summary(plans, kinds);
    if (summary != null) {
      summary0.kinds.addAll(summary.kinds);
      summary0.sheets.addAll(summary.sheets);
      summary.deleted.forEach((k, ids) {
        for (final id in ids) {
          summary0.addDeleted(k, id);
        }
      });
      summary.revived.forEach((k, ids) {
        for (final id in ids) {
          summary0.addRevived(k, id);
        }
      });
    }
    for (final c in changes) {
      final sheetId = c.columnsAfter['sheetId'] ?? c.columnsBefore['sheetId'];
      if (sheetId != null) summary0.sheets.add('$sheetId');
    }
    final detail = plans.length == 1 ? plans.single.detailJson : null;
    for (var i = 0; i < changes.length; i += chunkSize) {
      final chunk = changes.sublist(
        i,
        i + chunkSize > changes.length ? changes.length : i + chunkSize,
      );
      // Current rows of the chunk (admin read), one query per table.
      final ids = <String, Set<UuidValue>>{};
      for (final c in chunk) {
        ids.putIfAbsent(c.table, () => {}).add(UuidValue.fromString(c.rowId));
      }
      final current = <String, Map<String, dynamic>>{};
      for (final e in ids.entries) {
        final table = syncedTablesByName[e.key];
        if (table == null) continue;
        for (final r in await table.findByIds(db, e.value)) {
          final json = (r.toJson() as Map).cast<String, dynamic>();
          current['${e.key}:${json['id']}'] = json;
        }
      }
      await db.offlineSyncDb.transactionForUser(
        actor.authUserId,
        (tx) async {
          // Deletes per table in planner order (children first).
          final deletes = <String, Set<UuidValue>>{};
          final inserts = <String, List<RowChange>>{};
          final updates = <(RowChange, Map<String, dynamic>)>[];
          for (final c in chunk) {
            final table = syncedTablesByName[c.table];
            if (table == null) continue;
            final key = '${c.table}:${c.rowId}';
            final cur = current[key];
            switch (c.op) {
              case RowOp.delete:
                if (cur == null) {
                  // Deleting a row inserted earlier in this chunk cancels
                  // the pending insert.
                  final pending = inserts[c.table];
                  pending?.removeWhere((i) => i.rowId == c.rowId);
                  continue;
                }
                if (skipChanged && c.table == SheetsTables.cell) {
                  // Reverting a cell insert: values others changed since
                  // are kept; only our own columns are cleared.
                  final changed = <String>{
                    for (final e in c.columnsBefore.entries)
                      if (!_keyColumns.contains(e.key) &&
                          jsonEncode(cur[e.key]) !=
                              jsonEncode(_jsonValue(e.value)))
                        e.key,
                  };
                  if (changed.isNotEmpty) {
                    for (final col in changed) {
                      skipped.add(
                        RevertSkip(
                          table: c.table,
                          rowId: UuidValue.fromString(c.rowId),
                          column: col,
                          reason: 'changed_by_other',
                        ),
                      );
                    }
                    final clear = {
                      for (final e in c.columnsBefore.entries)
                        if (!_keyColumns.contains(e.key) &&
                            !changed.contains(e.key) &&
                            e.value != null)
                          e.key: null,
                    };
                    if (clear.isNotEmpty) {
                      updates.add((
                        RowChange.update(c.table, c.rowId, {
                          for (final k in clear.keys) k: cur[k],
                        }, clear),
                        cur,
                      ));
                    }
                    continue;
                  }
                }
                deletes
                    .putIfAbsent(c.table, () => {})
                    .add(UuidValue.fromString(c.rowId));
                applied.add(RowChange.delete(c.table, c.rowId, cur));
                current.remove(key);
              case RowOp.insert:
                if (cur != null) {
                  // Already visible: overwrite the given columns.
                  final after = {
                    for (final e in c.columnsAfter.entries)
                      if (e.key != 'id') e.key: _jsonValue(e.value),
                  };
                  updates.add((
                    RowChange.update(
                      c.table,
                      c.rowId,
                      {for (final k in after.keys) k: cur[k]},
                      after,
                    ),
                    cur,
                  ));
                } else {
                  inserts.putIfAbsent(c.table, () => []).add(c);
                }
              case RowOp.update:
                // An update of a row inserted earlier in this chunk (one
                // tool call that adds and then changes a row) is merged into
                // the pending insert.
                final pending = cur == null ? inserts[c.table] : null;
                final at = pending?.indexWhere((i) => i.rowId == c.rowId) ?? -1;
                if (at >= 0) {
                  final ins = pending![at];
                  pending[at] = RowChange.insert(c.table, c.rowId, {
                    ...ins.columnsAfter,
                    ...c.columnsAfter,
                  });
                  continue;
                }
                if (cur == null) {
                  skipped.add(
                    RevertSkip(
                      table: c.table,
                      rowId: UuidValue.fromString(c.rowId),
                      column: '*',
                      reason: 'row_deleted',
                    ),
                  );
                  continue;
                }
                updates.add((c, cur));
            }
          }
          for (final e in deletes.entries) {
            await deleteSyncedRows(db, e.key, e.value, transaction: tx);
          }
          // Inserts (new and revived rows) in dependency order, one
          // set-based engine write per table (offline-sync patch OS-7).
          for (final name in SheetsTables.dependencyOrder) {
            final list = inserts[name];
            if (list == null) continue;
            await _bulkWrite(db, name, [
              for (final c in list)
                SyncedRowWrite.insert(UuidValue.fromString(c.rowId), {
                  for (final e in c.columnsAfter.entries)
                    e.key: _jsonValue(e.value),
                }),
            ], tx);
            applied.addAll(list);
          }
          // Updates naming only their columns, batched per table (a row
          // updated twice in one chunk starts a new batch).
          final batches = <String, List<List<SyncedRowWrite>>>{};
          final batchIds = <String, Set<String>>{};
          for (final (c, cur) in updates) {
            final table = syncedTablesByName[c.table]!;
            final after = <String, Object?>{};
            final before = <String, Object?>{};
            for (final e in c.columnsAfter.entries) {
              if (e.key == 'id') continue;
              if (skipChanged &&
                  c.columnsBefore.containsKey(e.key) &&
                  jsonEncode(cur[e.key]) !=
                      jsonEncode(_jsonValue(c.columnsBefore[e.key]))) {
                skipped.add(
                  RevertSkip(
                    table: c.table,
                    rowId: UuidValue.fromString(c.rowId),
                    column: e.key,
                    reason: 'changed_by_other',
                  ),
                );
                continue;
              }
              if (table.column(e.key) == null) continue;
              after[e.key] = _jsonValue(e.value);
              before[e.key] = cur[e.key];
            }
            if (after.isEmpty) continue;
            final ids = batchIds.putIfAbsent(c.table, () => {});
            final tableBatches = batches.putIfAbsent(c.table, () => [[]]);
            if (!ids.add(c.rowId)) {
              tableBatches.add([]);
              ids
                ..clear()
                ..add(c.rowId);
            }
            tableBatches.last.add(
              SyncedRowWrite.updateColumns(
                UuidValue.fromString(c.rowId),
                after,
              ),
            );
            applied.add(RowChange.update(c.table, c.rowId, before, after));
          }
          for (final e in batches.entries) {
            for (final batch in e.value) {
              await _bulkWrite(db, e.key, batch, tx);
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
              summaryJson: summary0.encode(),
              detailJson: detail,
              at: clock.now().toUtc(),
            ),
            transaction: tx,
          );
        },
        spaceId: spaceUuid,
      );
    }
    return AppliedChanges(applied, skipped);
  }
}

/// [ServerChangeRecord]s of server changes in the format
/// [ServerSheetsWriter.revert] reads: the inverse row changes as
/// gzip+base64 JSON (inline up to 256 KB, else a stored file) and the
/// forward changes in a file (redo).
abstract final class SheetsChangeRecords {
  static String encode(List<RowChange> changes) => base64Encode(
    gzip.encode(utf8.encode(jsonEncode([for (final c in changes) c.toJson()]))),
  );

  static List<RowChange> decode(String data) => [
    for (final m
        in jsonDecode(utf8.decode(gzip.decode(base64Decode(data))))
            as List<dynamic>)
      RowChange.fromJson((m as Map).cast<String, Object?>()),
  ];

  /// The inverse changes of a record.
  static Future<List<RowChange>> inverse(
    Session session,
    ServerChangeRecord r,
  ) async {
    final inline = r.inverseJson;
    if (inline != null) return decode(inline);
    if (r.inverseFileId == null) return const [];
    final file = await FileService.byUuid(session, r.inverseFileId!);
    if (file == null) return const [];
    final bytes = await FileService.readBytes(session, file);
    return decode(
      utf8.decode(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      ),
    );
  }

  /// The forward changes of a record (empty when its file is gone).
  static Future<List<RowChange>> forward(
    Session session,
    ServerChangeRecord r,
  ) async {
    if (r.forwardFileId == null) return const [];
    final file = await FileService.byUuid(session, r.forwardFileId!);
    if (file == null) return const [];
    final bytes = await FileService.readBytes(session, file);
    return decode(
      utf8.decode(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      ),
    );
  }

  /// Stores the record of [applied] and returns its change id.
  static Future<UuidValue> store(
    Session session, {
    required Actor actor,
    required DriveItem item,
    required String label,
    required List<RowChange> applied,
    Duration lifetime = const Duration(hours: 24),
    int? cellsAffected,
  }) async {
    final changeId = const Uuid().v7obj();
    final inverse = [for (final c in applied.reversed) c.inverse()];
    final inverseData = encode(inverse);
    UuidValue? inverseFile;
    String? inline;
    if (inverseData.length <= ServerSheetsWriter.inlineInverseLimit) {
      inline = inverseData;
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
    final forwardFile = (await FileService.storeServerFile(
      session,
      ownerId: actor.userId,
      itemId: item.id,
      kind: StoredFileKind.snapshot,
      fileName: '$changeId.forward',
      mimeType: 'application/octet-stream',
      bytes: Uint8List.fromList(utf8.encode(encode(applied))),
    )).fileUuid;
    final now = clock.now().toUtc();
    await ServerChangeRecord.db.insertRow(
      session,
      ServerChangeRecord(
        changeId: changeId,
        spreadsheetUuid: item.contentRef!,
        userId: actor.userId,
        actorKind: actor.kind,
        label: label,
        inverseJson: inline,
        inverseFileId: inverseFile,
        forwardFileId: forwardFile,
        cellsAffected:
            cellsAffected ??
            applied.where((c) => c.table == SheetsTables.cell).length,
        createdAt: now,
        expiresAt: now.add(lifetime),
      ),
    );
    return changeId;
  }
}
