import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides_core/ops.dart' show SlidesChangeSummary;
import 'package:wonky_slides_core/schema.dart'
    show SlidesTables, SlidesUndoHooks;
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_models/tables.dart'
    show SlidesSyncedTables, SyncedRowWrite;

import '../../platform/cluster/cluster_bus.dart';
import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/sharing/access_service.dart';
import '../../platform/spaces/space_service.dart';
import '../../sheets/mcp/sheets_bulk_writer.dart' show SheetsChangeRecords;
import '../../sheets/sync/sync_db.dart';
import '../headless/headless_deck_cache.dart';
import 'slides_sync_service.dart';

/// Outcome of a server write to a deck.
class DeckAppliedChanges {
  DeckAppliedChanges(this.applied, this.skipped, this.logIds);

  /// The changes as applied, with the actual previous values (their
  /// inverse undoes exactly what was written).
  final List<RowChange> applied;

  /// Columns/rows not written by a revert (changed by others, deleted).
  final List<RevertSkip> skipped;

  /// The `DeckChangeLog` rows written (one per chunk).
  final List<UuidValue> logIds;
}

/// A recorded server write ([ServerSlidesWriter.applyRecorded]).
class DeckRecordedWrite {
  DeckRecordedWrite(this.changeId, this.result);

  /// The `ServerChangeRecord.changeId` (`slides.revertChange`, MCP
  /// `changes.revert`); null when nothing changed.
  final UuidValue? changeId;
  final DeckAppliedChanges result;

  /// The last `DeckChangeLog` id (MCP `sync_version`).
  UuidValue? get syncVersion =>
      result.logIds.isEmpty ? null : result.logIds.last;
}

/// Writes `RowChange`s into a deck space on the server (Slides 02 §9.3,
/// §12.2; 11 §2.1): server-side creation and copies ([write]), the
/// headless deck (MCP, AI, templates, restores) and reverts
/// ([applyRecorded], [revert], [reapply]). The rules are the app writer's:
/// one `transactionForUser` per chunk of ≤ [chunkSize] changes, updates
/// name exactly their columns, each chunk with a `DeckChangeLog` row (P9).
/// After a write the deck change-log consumer runs (server writes don't
/// pass `onMergeSuccess`), the headless cache is written through and other
/// instances are told with a `slides:merged:<space>` signal.
///
/// Recorded writes store a `ServerChangeRecord` (the Sheets model, its
/// `spreadsheetUuid` holding the deck space; Slides 02 §8 "shared format")
/// with the inverse and forward changes, for `slides.serverChange` undo.
abstract final class ServerSlidesWriter {
  static const chunkSize = 5000;

  /// Applies [changes] (in order) to [deckSpace] as [actor], who must be a
  /// readWrite member of the space. No current-row reads: for new rows
  /// (creation, copies). Returns the ids of the change-log rows.
  static Future<List<UuidValue>> write(
    Session session, {
    required Actor actor,
    required UuidValue deckSpace,
    required List<RowChange> changes,
    required String label,
    String? detailJson,
    bool consume = true,
  }) async {
    final db = syncSessionOf(session);
    final logs = <UuidValue>[];
    for (var i = 0; i < changes.length; i += chunkSize) {
      final chunk = changes.sublist(
        i,
        i + chunkSize > changes.length ? changes.length : i + chunkSize,
      );
      final logId = const Uuid().v7obj();
      await db.offlineSyncDb.transactionForUser(
        actor.authUserId,
        (tx) async {
          await _apply(db, chunk, tx);
          await _log(
            db,
            tx,
            logId: logId,
            deckSpace: deckSpace,
            actor: actor,
            label: label,
            summary: SlidesChangeSummary.of(chunk),
            detailJson: i == 0 ? detailJson : null,
          );
        },
        spaceId: deckSpace,
      );
      logs.add(logId);
    }
    if (logs.isNotEmpty) await _after(session, deckSpace, changes, consume);
    return logs;
  }

  static Future<void> _log(
    DatabaseSession db,
    Transaction tx, {
    required UuidValue logId,
    required UuidValue deckSpace,
    required Actor actor,
    required String label,
    required SlidesChangeSummary summary,
    String? detailJson,
  }) => DeckChangeLog.db.insertRow(
    db,
    DeckChangeLog(
      id: logId,
      deckId: deckSpace,
      userId: actor.authUserId,
      actorKind: actor.kind,
      sessionId: actor.sessionId ?? 'server:${actor.kind.name}',
      label: label,
      summaryJson: jsonEncode(summary.toJson()),
      detailJson: detailJson,
      at: nowUtc(),
    ),
    transaction: tx,
  );

  /// Consumer, cache write-through and the merge signal for other
  /// instances.
  static Future<void> _after(
    Session session,
    UuidValue deckSpace,
    List<RowChange> applied,
    bool consume,
  ) async {
    HeadlessDeckCache.writeThrough(deckSpace, applied);
    try {
      await ClusterBus.post(
        session,
        SlidesSyncService.mergedChannel(deckSpace),
        SheetsMergedSignal(
          spaceUuid: deckSpace,
          hlc: HeadlessDeckCache.ownSignal,
        ),
      );
    } on Exception catch (e) {
      session.log(
        'Could not signal the write to $deckSpace: $e',
        level: LogLevel.warning,
      );
    }
    if (consume) await SlidesSyncService.process(session, deckSpace);
  }

  static Future<void> _apply(
    DatabaseSession db,
    List<RowChange> changes,
    Transaction tx,
  ) async {
    var i = 0;
    while (i < changes.length) {
      final c = changes[i];
      final spec = SlidesSyncedTables.of(c.table);
      switch (c.op) {
        case RowOp.insert:
          final run = <Map<String, Object?>>[c.columnsAfter];
          while (i + run.length < changes.length &&
              changes[i + run.length].op == RowOp.insert &&
              changes[i + run.length].table == c.table) {
            run.add(changes[i + run.length].columnsAfter);
          }
          await spec.insertRows(db, run, transaction: tx);
          i += run.length;
          continue;
        case RowOp.update:
          await spec.updateColumns(
            db,
            UuidValue.fromString(c.rowId),
            c.columnsAfter,
            transaction: tx,
          );
        case RowOp.delete:
          await spec.deleteByIds(db, [
            UuidValue.fromString(c.rowId),
          ], transaction: tx);
      }
      i++;
    }
  }

  // ------------------------------------------------------------ recorded

  /// Identity columns never compared by the revert skip rule.
  static const _keyColumns = {
    'id',
    'elementId',
    'rowId',
    'columnId',
    'createdAt',
  };

  static Object? _jsonValue(Object? v) => switch (v) {
    DateTime() => v.toUtc().toIso8601String(),
    UuidValue() => v.uuid,
    String() when v.length > 19 && v[10] == 'T' => _isoUtc(v),
    _ => v,
  };

  /// ISO time strings in one canonical UTC form (records hold JSON times).
  static String _isoUtc(String v) {
    final t = DateTime.tryParse(v);
    return t == null ? v : t.toUtc().toIso8601String();
  }

  static bool _same(Object? a, Object? b) {
    final x = _jsonValue(a), y = _jsonValue(b);
    if (x is num && y is num) return x == y;
    return jsonEncode(x) == jsonEncode(y);
  }

  /// Applies [changes] (planner order) reading the current rows first, so
  /// the result lists what was really written. Deletes of rows already
  /// gone are skipped (or cancel an insert of the same chunk); inserts of
  /// visible rows update the given columns; updates of deleted rows are
  /// reported (`row_deleted`). With [skipChanged] (revert/reapply), a
  /// column whose current value differs from `columnsBefore` is not
  /// written (`changed_by_other`) — together with its coupled columns
  /// (02 P4) — and a reverted table-cell insert keeps the columns others
  /// changed (column-wise, like Sheets cells).
  static Future<DeckAppliedChanges> apply(
    Session session, {
    required Actor actor,
    required UuidValue deckSpace,
    required List<RowChange> changes,
    required String label,
    bool skipChanged = false,
    String? detailJson,
    bool consume = true,
  }) async {
    final db = syncSessionOf(session);
    final applied = <RowChange>[];
    final skipped = <RevertSkip>[];
    final logs = <UuidValue>[];
    for (var i = 0; i < changes.length; i += chunkSize) {
      final chunk = changes.sublist(
        i,
        i + chunkSize > changes.length ? changes.length : i + chunkSize,
      );
      final ids = <String, Set<UuidValue>>{};
      for (final c in chunk) {
        ids.putIfAbsent(c.table, () => {}).add(UuidValue.fromString(c.rowId));
      }
      final current = <String, Map<String, Object?>>{};
      for (final e in ids.entries) {
        final spec = SlidesSyncedTables.byName[e.key];
        if (spec == null) continue;
        for (final r in await spec.findByIds(db, e.value)) {
          final cols = spec.toColumns(r);
          current['${e.key}:${cols['id']}'] = cols;
        }
      }
      final chunkApplied = <RowChange>[];
      final deletes = <(String, Set<UuidValue>)>[];
      final inserts = <String, List<RowChange>>{};
      final updates = <(RowChange, Map<String, Object?>)>[];
      for (final c in chunk) {
        if (SlidesSyncedTables.byName[c.table] == null) continue;
        final key = '${c.table}:${c.rowId}';
        final cur = current[key];
        final id = UuidValue.fromString(c.rowId);
        switch (c.op) {
          case RowOp.delete:
            if (cur == null) {
              inserts[c.table]?.removeWhere((x) => x.rowId == c.rowId);
              continue;
            }
            final identity = SlidesUndoHooks.columnwise.identityColumns(
              c.table,
            );
            if (skipChanged && identity != null) {
              // Reverting a cell insert: values others changed since stay.
              final changed = <String>{
                for (final e in c.columnsBefore.entries)
                  if (!_keyColumns.contains(e.key) &&
                      !identity.contains(e.key) &&
                      !_same(cur[e.key], e.value))
                    e.key,
              };
              if (changed.isNotEmpty) {
                for (final col in changed) {
                  skipped.add(
                    RevertSkip(
                      table: c.table,
                      rowId: id,
                      column: col,
                      reason: 'changed_by_other',
                    ),
                  );
                }
                final clear = {
                  for (final e in c.columnsBefore.entries)
                    if (!_keyColumns.contains(e.key) &&
                        !identity.contains(e.key) &&
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
            if (deletes.isEmpty || deletes.last.$1 != c.table) {
              deletes.add((c.table, {}));
            }
            deletes.last.$2.add(id);
            chunkApplied.add(RowChange.delete(c.table, c.rowId, cur));
            current.remove(key);
          case RowOp.insert:
            if (cur != null) {
              final after = {
                for (final e in c.columnsAfter.entries)
                  if (e.key != 'id') e.key: e.value,
              };
              updates.add((
                RowChange.update(c.table, c.rowId, {
                  for (final k in after.keys) k: cur[k],
                }, after),
                cur,
              ));
            } else {
              inserts.putIfAbsent(c.table, () => []).add(c);
            }
          case RowOp.update:
            final pending = cur == null ? inserts[c.table] : null;
            final at = pending?.indexWhere((x) => x.rowId == c.rowId) ?? -1;
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
                  rowId: id,
                  column: '*',
                  reason: 'row_deleted',
                ),
              );
              continue;
            }
            updates.add((c, cur));
        }
      }
      // Updates naming only their columns; skipped columns take their
      // coupled group along (P4).
      final writes = <(RowChange, Map<String, Object?>)>[];
      for (final (c, cur) in updates) {
        final spec = SlidesSyncedTables.byName[c.table]!;
        final skip = <String>{};
        if (skipChanged) {
          for (final e in c.columnsAfter.entries) {
            if (e.key == 'id' || !c.columnsBefore.containsKey(e.key)) continue;
            if (_same(cur[e.key], c.columnsBefore[e.key])) continue;
            skip.add(e.key);
            skip.addAll(
              SlidesUndoHooks.coupled.groupOf(c.table, e.key) ?? const {},
            );
          }
        }
        final after = <String, Object?>{};
        final before = <String, Object?>{};
        for (final e in c.columnsAfter.entries) {
          if (e.key == 'id' || spec.column(e.key) == null) continue;
          if (skip.contains(e.key)) {
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
          if (_same(cur[e.key], e.value)) continue;
          after[e.key] = e.value;
          before[e.key] = cur[e.key];
        }
        if (after.isEmpty) continue;
        writes.add((RowChange.update(c.table, c.rowId, before, after), cur));
      }
      final insertList = [
        for (final t in SlidesTables.dependencyOrder) ...?inserts[t],
      ];
      if (deletes.isEmpty && insertList.isEmpty && writes.isEmpty) continue;
      final logId = const Uuid().v7obj();
      await db.offlineSyncDb.transactionForUser(
        actor.authUserId,
        (tx) async {
          for (final (table, set) in deletes) {
            await SlidesSyncedTables.of(
              table,
            ).deleteByIds(db, set, transaction: tx);
          }
          // Inserts and revives in dependency order, one set-based write
          // per table (offline-sync patch OS-7).
          for (final t in SlidesTables.dependencyOrder) {
            final list = inserts[t];
            if (list == null || list.isEmpty) continue;
            await SlidesSyncedTables.of(t).bulkWrite(db, [
              for (final c in list)
                SyncedRowWrite.insert(UuidValue.fromString(c.rowId), {
                  for (final e in c.columnsAfter.entries)
                    if (e.key != 'id') e.key: e.value,
                }),
            ], transaction: tx);
          }
          // Updates batched per table (a row updated twice starts a new
          // batch).
          final batches = <String, List<List<SyncedRowWrite>>>{};
          final batchIds = <String, Set<String>>{};
          for (final (c, _) in writes) {
            final seen = batchIds.putIfAbsent(c.table, () => {});
            final list = batches.putIfAbsent(c.table, () => [[]]);
            if (!seen.add(c.rowId)) {
              list.add([]);
              seen
                ..clear()
                ..add(c.rowId);
            }
            list.last.add(
              SyncedRowWrite.updateColumns(
                UuidValue.fromString(c.rowId),
                c.columnsAfter,
              ),
            );
          }
          for (final e in batches.entries) {
            for (final batch in e.value) {
              if (batch.isEmpty) continue;
              await SlidesSyncedTables.of(
                e.key,
              ).bulkWrite(db, batch, transaction: tx);
            }
          }
          final all = [
            ...chunkApplied,
            ...insertList,
            for (final (c, _) in writes) c,
          ];
          await _log(
            db,
            tx,
            logId: logId,
            deckSpace: deckSpace,
            actor: actor,
            label: label,
            summary: SlidesChangeSummary.of(all),
            detailJson: i == 0 ? detailJson : null,
          );
        },
        spaceId: deckSpace,
      );
      logs.add(logId);
      applied
        ..addAll(chunkApplied)
        ..addAll(insertList)
        ..addAll([for (final (c, _) in writes) c]);
    }
    if (logs.isNotEmpty) await _after(session, deckSpace, applied, consume);
    return DeckAppliedChanges(applied, skipped, logs);
  }

  /// Applies [changes] for [actor] on the deck [item] (granting write
  /// membership with reason `mcp`) and records them for undo (24 h).
  static Future<DeckRecordedWrite> applyRecorded(
    Session session, {
    required Actor actor,
    required DriveItem item,
    required List<RowChange> changes,
    required String label,
    String? detailJson,
    bool skipChanged = false,
    Duration lifetime = const Duration(hours: 24),
  }) async {
    await SpaceService.ensureWriter(session, actor, item);
    final result = await apply(
      session,
      actor: actor,
      deckSpace: item.contentRef!,
      changes: changes,
      label: label,
      detailJson: detailJson,
      skipChanged: skipChanged,
    );
    if (result.applied.isEmpty) return DeckRecordedWrite(null, result);
    final changeId = await SheetsChangeRecords.store(
      session,
      actor: actor,
      item: item,
      label: label,
      applied: result.applied,
      lifetime: lifetime,
      cellsAffected: result.applied.length,
    );
    return DeckRecordedWrite(changeId, result);
  }

  /// The deck item of a change record, checked for [min] role.
  static Future<(ServerChangeRecord, DriveItem)> _recordAndItem(
    Session session,
    Actor actor,
    UuidValue changeId, {
    bool orRevert = false,
  }) async {
    // Redo by the id of a revert means the change it reverted.
    final record =
        (orRevert
            ? await ServerChangeRecord.db.findFirstRow(
                session,
                where: (t) => t.revertChangeId.equals(changeId),
              )
            : null) ??
        await ServerChangeRecord.db.findFirstRow(
          session,
          where: (t) => t.changeId.equals(changeId),
        );
    if (record == null) throw Errors.notFound('Change');
    final item = await DriveItem.db.findFirstRow(
      session,
      where: (t) =>
          t.contentRef.equals(record.spreadsheetUuid) &
          t.kind.equals(DriveItemKind.presentation),
    );
    if (item == null) throw Errors.notFound('Change');
    await AccessService.requireRole(session, actor, item, Role.editor);
    if (record.expiresAt.isBefore(nowUtc())) {
      throw Errors.expired('The change can no longer be undone.');
    }
    return (record, item);
  }

  /// Reverts a recorded deck change with the per-column skip rule
  /// (`slides.revertChange`, MCP `changes.revert`).
  static Future<RevertResult> revert(
    Session session,
    Actor actor,
    UuidValue changeId,
  ) async {
    final (record, item) = await _recordAndItem(session, actor, changeId);
    final inverse = await SheetsChangeRecords.inverse(session, record);
    final label = 'Undo ${record.label}';
    final write = await applyRecorded(
      session,
      actor: actor,
      item: item,
      changes: inverse,
      label: label,
      skipChanged: true,
    );
    final revertId = write.changeId ?? const Uuid().v7obj();
    await ServerChangeRecord.db.updateWhere(
      session,
      columnValues: (t) => [
        t.revertedAt(clock.now().toUtc()),
        t.revertChangeId(revertId),
      ],
      where: (t) => t.id.equals(record.id!),
    );
    return RevertResult(
      changeId: revertId,
      revertedCells: write.result.applied.length,
      skipped: write.result.skipped,
    );
  }

  /// Re-applies a reverted deck change (redo; [changeId] of the original
  /// or of its revert) with the same skip rule.
  static Future<RevertResult> reapply(
    Session session,
    Actor actor,
    UuidValue changeId,
  ) async {
    final (record, item) = await _recordAndItem(
      session,
      actor,
      changeId,
      orRevert: true,
    );
    if (record.forwardFileId == null) {
      throw Errors.expired('The change can no longer be redone.');
    }
    final forward = await SheetsChangeRecords.forward(session, record);
    if (forward.isEmpty) {
      throw Errors.expired('The change can no longer be redone.');
    }
    final write = await applyRecorded(
      session,
      actor: actor,
      item: item,
      changes: forward,
      label: record.label,
      skipChanged: true,
    );
    return RevertResult(
      changeId: write.changeId ?? const Uuid().v7obj(),
      revertedCells: write.result.applied.length,
      skipped: write.result.skipped,
    );
  }
}
