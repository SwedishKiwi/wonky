import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_sheets_core/model.dart' show ChangeSummary;

import '../../platform/activity/activity_service.dart';
import '../../platform/comments/comment_service.dart';
import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/drive/drive_service.dart';
import '../../platform/versions/version_service.dart';
import '../sync/sync_db.dart';

/// A pluggable consumer of synced `ChangeLog` rows (Sheets 13 §4.6), e.g.
/// script triggers registered by the scripting workstream.
abstract interface class ChangeLogPlugin {
  Future<void> consume(
    Session session,
    DriveItem item,
    ChangeLog change,
    Actor actor,
  );
}

/// Processes `ChangeLog` rows after `onMergeSuccess` (Sheets 02 §3.7):
/// activity, modifiedAt, version capture state, cell history, title
/// mirroring and comment orphaning. Exactly once per row via
/// [SheetsChangeLogReceipt].
abstract final class ChangeLogConsumer {
  static const batchSize = 500;
  static const modifiedThrottle = Duration(seconds: 10);
  static const maxHistoryPerCell = 100;
  static const changeLogRetention = Duration(days: 30);

  static final List<ChangeLogPlugin> plugins = [];
  static final Map<String, DateTime> _lastTouch = {};
  static final Map<String, Future<void>> _running = {};

  /// Processes the new change log rows of [spaceUuid]; concurrent calls for
  /// the same space are coalesced on this instance.
  static Future<int> processSpace(Session session, UuidValue spaceUuid) {
    final key = spaceUuid.uuid;
    final running = _running[key];
    if (running != null) return running.then((_) => 0);
    final future = _process(session, spaceUuid);
    _running[key] = future.then((_) {});
    return future.whenComplete(() => _running.remove(key));
  }

  static Future<int> _process(Session session, UuidValue spaceUuid) async {
    final item = await DriveItem.db.findFirstRow(
      session,
      where: (t) =>
          t.contentRef.equals(spaceUuid) &
          t.kind.equals(DriveItemKind.spreadsheet),
    );
    // Unregistered spreadsheets are processed once registered.
    if (item == null) return 0;
    var total = 0;
    while (true) {
      final rows = await session.db.unsafeQuery(
        r'''
        SELECT c.id FROM change_log c
        JOIN offline_sync_spaces s ON s.id = c."spaceId"
        WHERE s."uuidSpaceId" = @space
          AND NOT EXISTS (
            SELECT 1 FROM sheets_change_log_receipt r WHERE r."changeLogId" = c.id)
        ORDER BY c.at, c.id
        LIMIT @limit
        ''',
        parameters: QueryParameters.named({
          'space': spaceUuid,
          'limit': batchSize,
        }),
      );
      final ids = {for (final r in rows) r[0] as UuidValue};
      if (ids.isEmpty) break;
      final db = syncSessionOf(session);
      final changes = await ChangeLog.db.find(
        db,
        where: (t) => t.id.inSet(ids),
        orderBy: (t) => t.at,
      );
      final visible = {for (final c in changes) c.id};
      for (final id in ids.difference(visible)) {
        // Deleted change log rows: just mark them.
        await _receipt(session, id, spaceUuid);
      }
      for (final change in changes) {
        if (!await _receipt(session, change.id, spaceUuid)) continue;
        await _consume(session, item, change);
        total++;
      }
      if (ids.length < batchSize) break;
    }
    return total;
  }

  /// Claims [id]; false when another instance already did.
  static Future<bool> _receipt(
    Session session,
    UuidValue id,
    UuidValue spaceUuid,
  ) async {
    final inserted = await session.db.unsafeExecute(
      r'''
      INSERT INTO sheets_change_log_receipt ("changeLogId", "spaceUuid", "processedAt")
      VALUES (@id, @space, @at) ON CONFLICT ("changeLogId") DO NOTHING
      ''',
      parameters: QueryParameters.named({
        'id': id,
        'space': spaceUuid,
        'at': nowUtc(),
      }),
    );
    return inserted > 0;
  }

  static Future<void> _consume(
    Session session,
    DriveItem item,
    ChangeLog change,
  ) async {
    final profile = await UserProfile.db.findFirstRow(
      session,
      where: (t) => t.authUserId.equals(change.userId),
    );
    if (profile == null) return;
    final actor = Actor(
      userId: profile.id!,
      authUserId: change.userId,
      kind: change.actorKind,
      sessionId: change.sessionId,
    );
    try {
      final summary = ChangeSummary.parse(change.summaryJson);
      final cells = _detailCells(change.detailJson);
      await ActivityService.logEdit(
        session,
        item.id!,
        actor,
        counters: {'changes': 1, 'cells': cells.length},
      );
      await VersionService.recordEdit(session, item, profile.id!);
      await DriveService.recordEdit(session, profile.id!, item);
      final now = nowUtc();
      final last = _lastTouch[item.uuid.uuid];
      if (last == null || now.difference(last) > modifiedThrottle) {
        _lastTouch[item.uuid.uuid] = now;
        await _mirrorTitle(session, item, profile.id!);
      }
      await _history(session, item, change, cells);
      await _orphans(session, item, summary, change);
      for (final plugin in plugins) {
        await plugin.consume(session, item, change, actor);
      }
    } on Exception catch (e, st) {
      session.log(
        'Change log ${change.id} of ${item.uuid} failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
    }
  }

  static List<Map<String, Object?>> _detailCells(String? json) {
    if (json == null) return const [];
    try {
      final value = jsonDecode(json);
      if (value is Map && value['cells'] is List) {
        return [
          for (final c in value['cells'] as List)
            if (c is Map) c.cast<String, Object?>(),
        ];
      }
    } on FormatException {
      // Ignore malformed details.
    }
    return const [];
  }

  /// Spreadsheet.title → DriveItem.name, plus modifiedAt and search text.
  static Future<void> _mirrorTitle(
    Session session,
    DriveItem item,
    int userId,
  ) async {
    final db = syncSessionOf(session);
    final spreadsheet = await Spreadsheet.db.findById(db, item.contentRef!);
    final sheets = await Sheet.db.find(
      db,
      where: (t) => t.spreadsheetId.equals(item.contentRef!),
    );
    final cells = await Cell.db.find(
      db,
      where: (t) => t.sheetId.inSet({for (final s in sheets) s.id}) &
          t.content.notEquals(null),
      limit: 10000,
    );
    final text = StringBuffer()..writeAll(sheets.map((s) => s.name), ' ');
    for (final c in cells) {
      final content = c.content!;
      if (content.startsWith('s:')) {
        text
          ..write(' ')
          ..write(content.substring(2));
      } else if (content.startsWith('n:')) {
        text
          ..write(' ')
          ..write(content.substring(2));
      }
    }
    final title = spreadsheet?.title.trim();
    if (title != null &&
        title.isNotEmpty &&
        title != item.name &&
        title.length <= 255 &&
        !title.contains('/')) {
      await DriveItem.db.updateWhere(
        session,
        columnValues: (t) => [t.name(title)],
        where: (t) => t.id.equals(item.id!),
      );
    }
    final searchText = text.toString();
    await DriveService.touchModified(
      session,
      item,
      userId,
      searchText: searchText.length > 100000
          ? searchText.substring(0, 100000)
          : searchText,
    );
  }

  static Future<void> _history(
    Session session,
    DriveItem item,
    ChangeLog change,
    List<Map<String, Object?>> cells,
  ) async {
    if (cells.isEmpty) return;
    final rows = <CellHistory>[];
    for (final c in cells) {
      final s = c['s'] ?? c['sheetId'];
      final r = c['r'] ?? c['rowId'];
      final col = c['c'] ?? c['colId'];
      if (s is! String || r is! String || col is! String) continue;
      try {
        rows.add(
          CellHistory(
            spreadsheetUuid: item.contentRef!,
            sheetId: UuidValue.withValidation(s),
            rowId: UuidValue.withValidation(r),
            colId: UuidValue.withValidation(col),
            changeLogId: change.id,
            userUuid: change.userId,
            actorKind: change.actorKind,
            label: change.label,
            at: change.at,
            before: (c['b'] ?? c['before']) as String?,
            after: (c['a'] ?? c['after']) as String?,
          ),
        );
      } on FormatException {
        continue;
      }
    }
    for (final row in rows) {
      await session.db.unsafeExecute(
        r'''
        INSERT INTO cell_history ("spreadsheetUuid", "sheetId", "rowId", "colId",
          "changeLogId", "userUuid", "actorKind", label, at, before, after)
        VALUES (@sp, @sh, @r, @c, @cl, @u, @k, @l, @at, @b, @a)
        ON CONFLICT ("changeLogId", "rowId", "colId") DO NOTHING
        ''',
        parameters: QueryParameters.named({
          'sp': row.spreadsheetUuid,
          'sh': row.sheetId,
          'r': row.rowId,
          'c': row.colId,
          'cl': row.changeLogId,
          'u': row.userUuid,
          'k': row.actorKind.name,
          'l': row.label,
          'at': row.at,
          'b': row.before,
          'a': row.after,
        }),
      );
    }
    // Keep the latest entries per touched cell.
    for (final row in rows) {
      await session.db.unsafeExecute(
        r'''
        DELETE FROM cell_history WHERE id IN (
          SELECT id FROM cell_history
          WHERE "spreadsheetUuid" = @sp AND "sheetId" = @sh AND "rowId" = @r AND "colId" = @c
          ORDER BY at DESC OFFSET @keep)
        ''',
        parameters: QueryParameters.named({
          'sp': row.spreadsheetUuid,
          'sh': row.sheetId,
          'r': row.rowId,
          'c': row.colId,
          'keep': maxHistoryPerCell,
        }),
      );
    }
  }

  /// Orphans comment threads anchored to deleted rows/columns/sheets and
  /// revives them when the ids come back (Sheets 10 §3.2).
  static Future<void> _orphans(
    Session session,
    DriveItem item,
    ChangeSummary summary,
    ChangeLog change,
  ) async {
    final deleted = {
      for (final kind in const ['rows', 'cols', 'sheets'])
        for (final id in summary.deleted[kind] ?? const <String>[]) id: kind,
    };
    final revived = {
      for (final kind in const ['rows', 'cols', 'sheets'])
        ...?summary.revived[kind],
    };
    if (deleted.isEmpty && revived.isEmpty) return;
    final threads = await CommentThread.db.find(
      session,
      where: (t) => t.itemId.equals(item.id!),
    );
    for (final thread in threads) {
      final anchor = thread.anchorJson;
      if (thread.status == CommentStatus.orphaned) {
        final reason = thread.orphanReasonJson ?? '';
        if (revived.any(reason.contains)) {
          await CommentService.revive(session, thread, item);
        }
        continue;
      }
      for (final entry in deleted.entries) {
        if (anchor.contains(entry.key)) {
          await CommentService.orphan(
            session,
            thread,
            item,
            reason: {
              'kind': switch (entry.value) {
                'rows' => 'row',
                'cols' => 'column',
                _ => 'sheet',
              },
              'id': entry.key,
              'changeLogId': change.id.uuid,
            },
          );
          break;
        }
      }
    }
  }

  /// Daily job: moves remaining change log details into the history and
  /// deletes change log rows older than [changeLogRetention] (their
  /// receipts too).
  static Future<int> pruneOld(Session session, {DateTime? now}) async {
    final cutoff = (now ?? nowUtc()).subtract(changeLogRetention);
    final db = syncSessionOf(session);
    final old = await ChangeLog.db.find(
      db,
      where: (t) => t.at < cutoff,
      limit: 2000,
    );
    if (old.isEmpty) return 0;
    final bySpace = <UuidValue, List<ChangeLog>>{};
    for (final c in old) {
      bySpace.putIfAbsent(c.spreadsheetId, () => []).add(c);
    }
    var pruned = 0;
    for (final entry in bySpace.entries) {
      final item = await DriveItem.db.findFirstRow(
        session,
        where: (t) => t.contentRef.equals(entry.key),
      );
      // Rows are deleted as the spreadsheet's owner (a member of the space).
      final owner = item == null
          ? null
          : await UserProfile.db.findById(session, item.ownerId);
      if (item == null || owner == null) continue;
      final role = await session.offlineSync.spaces.roleOf(
        user: owner.authUserId,
        space: entry.key,
      );
      if (role != OfflineSyncSpaceRole.readWrite) continue;
      for (final c in entry.value) {
        await _history(session, item, c, _detailCells(c.detailJson));
      }
      await db.offlineSyncDb.transactionForUser(
        owner.authUserId,
        (tx) => ChangeLog.db.deleteWhere(
          db,
          where: (t) => t.id.inSet({for (final c in entry.value) c.id}),
          transaction: tx,
        ),
        spaceId: entry.key,
      );
      await SheetsChangeLogReceipt.db.deleteWhere(
        session,
        where: (t) => t.changeLogId.inSet({for (final c in entry.value) c.id}),
      );
      pruned += entry.value.length;
    }
    return pruned;
  }
}
