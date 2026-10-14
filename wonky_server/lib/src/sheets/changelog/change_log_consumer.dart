import 'dart:async';
import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_sheets_core/model.dart' show ChangeSummary;

import '../../platform/activity/activity_service.dart';
import '../../platform/comments/comment_service.dart';
import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/drive/drive_events.dart';
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

  /// A claim older than this that never completed (the server stopped
  /// while processing) is processed again.
  static const staleClaim = Duration(minutes: 10);

  /// Processes the new change log rows of [spaceUuid]; concurrent calls for
  /// the same space are coalesced on this instance (another call while one
  /// runs triggers one more pass afterwards).
  static Future<int> processSpace(Session session, UuidValue spaceUuid) {
    final key = spaceUuid.uuid;
    final running = _running[key];
    if (running != null) {
      _again.add(key);
      return running.then((_) => 0);
    }
    final future = () async {
      var total = 0;
      do {
        _again.remove(key);
        total += await _process(session, spaceUuid);
      } while (_again.contains(key));
      return total;
    }();
    _running[key] = future.then((_) {});
    return future.whenComplete(() => _running.remove(key));
  }

  static final Set<String> _again = {};

  /// Exactly-once per row, across instances and restarts: a row is claimed
  /// by inserting its [SheetsChangeLogReceipt] (unique), consumed, then the
  /// receipt is completed. Rows without a receipt, and rows whose claim is
  /// older than [staleClaim] and never completed, are (re)processed. The
  /// per-space "cursor" is the set of receipts of the space.
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
    final seen = <UuidValue>{};
    while (true) {
      final rows = await session.db.unsafeQuery(
        r'''
        SELECT c.id FROM change_log c
        JOIN offline_sync_spaces s ON s.id = c."spaceId"
        LEFT JOIN sheets_change_log_receipt r ON r."changeLogId" = c.id
        WHERE s."uuidSpaceId" = @space::uuid
          AND (r.id IS NULL
            OR (r."completedAt" IS NULL AND r."processedAt" < @stale))
        ORDER BY c.at, c.id
        LIMIT @limit
        ''',
        parameters: QueryParameters.named({
          'space': spaceUuid.uuid,
          'limit': batchSize,
          'stale': nowUtc().subtract(staleClaim),
        }),
      );
      final ids = {
        for (final r in rows)
          if (!seen.contains(_uuid(r[0]))) _uuid(r[0]),
      };
      if (ids.isEmpty) break;
      seen.addAll(ids);
      final db = syncSessionOf(session);
      final changes = await ChangeLog.db.find(
        db,
        where: (t) => t.id.inSet(ids),
        orderBy: (t) => t.at,
      );
      final visible = {for (final c in changes) c.id};
      for (final id in ids.difference(visible)) {
        // Deleted change log rows: just mark them.
        if (await _claim(session, id, spaceUuid)) {
          await _complete(session, id);
        }
      }
      for (final change in changes) {
        if (!await _claim(session, change.id, spaceUuid)) continue;
        await _consume(session, item, change);
        await _complete(session, change.id);
        total++;
      }
      if (ids.length < batchSize) break;
    }
    return total;
  }

  /// Claims [id]; false when another instance already did (and its claim is
  /// not stale).
  static Future<bool> _claim(
    Session session,
    UuidValue id,
    UuidValue spaceUuid,
  ) async {
    final now = nowUtc();
    final inserted = await session.db.unsafeExecute(
      r'''
      INSERT INTO sheets_change_log_receipt ("changeLogId", "spaceUuid", "processedAt")
      VALUES (@id::uuid, @space::uuid, @at)
      ON CONFLICT ("changeLogId") DO UPDATE SET "processedAt" = @at
        WHERE sheets_change_log_receipt."completedAt" IS NULL
          AND sheets_change_log_receipt."processedAt" < @stale
      ''',
      parameters: QueryParameters.named({
        'id': id.uuid,
        'space': spaceUuid.uuid,
        'at': now,
        'stale': now.subtract(staleClaim),
      }),
    );
    return inserted > 0;
  }

  static UuidValue _uuid(Object? v) =>
      v is UuidValue ? v : UuidValue.fromString('$v');

  static Future<void> _complete(Session session, UuidValue id) =>
      session.db.unsafeExecute(
        r'''
        UPDATE sheets_change_log_receipt SET "completedAt" = @at
        WHERE "changeLogId" = @id::uuid
        ''',
        parameters: QueryParameters.named({'id': id.uuid, 'at': nowUtc()}),
      );

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
      await _mirrorTitle(session, item);
      await _touch(session, item, profile.id!);
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

  static final Map<String, Timer> _trailing = {};

  /// `modifiedAt` and the search text, at most every [modifiedThrottle] per
  /// spreadsheet; edits inside the window get one trailing refresh.
  static Future<void> _touch(
    Session session,
    DriveItem item,
    int userId,
  ) async {
    final key = item.uuid.uuid;
    final now = nowUtc();
    final last = _lastTouch[key];
    if (last == null || now.difference(last) > modifiedThrottle) {
      _lastTouch[key] = now;
      await _refreshModified(session, item, userId);
      return;
    }
    if (_trailing[key] != null) return;
    final pod = session.serverpod;
    final itemId = item.id!;
    _trailing[key] = Timer(modifiedThrottle - now.difference(last), () async {
      _trailing.remove(key);
      _lastTouch[key] = nowUtc();
      // Best effort and detached from any request: the server (or a test)
      // may have shut the database down meanwhile, which throws errors, not
      // just exceptions.
      Session? internal;
      try {
        internal = await pod.createSession(enableLogging: false);
        final fresh = await DriveItem.db.findById(internal, itemId);
        if (fresh != null) await _refreshModified(internal, fresh, userId);
      } catch (e) {
        try {
          internal?.log('Trailing refresh of $key failed: $e');
        } catch (_) {}
      } finally {
        try {
          await internal?.close();
        } catch (_) {}
      }
    });
  }

  /// Spreadsheet.title → DriveItem.name (every change: renames are rare
  /// and must show at once).
  static Future<void> _mirrorTitle(Session session, DriveItem item) async {
    final db = syncSessionOf(session);
    final spreadsheet = await Spreadsheet.db.findById(db, item.contentRef!);
    final title = spreadsheet?.title.trim();
    if (title == null ||
        title.isEmpty ||
        title.length > 255 ||
        title.contains('/')) {
      return;
    }
    final current = await DriveItem.db.findById(session, item.id!);
    if (current == null || current.name == title) return;
    final updated = await DriveItem.db.updateRow(
      session,
      current.copyWith(name: title),
      columns: (t) => [t.name],
    );
    await DriveEvents.notify(session, updated, DriveChangeKind.updated);
  }

  /// `modifiedAt` and search text (sheet names, text and numbers of up to
  /// 10,000 cells).
  static Future<void> _refreshModified(
    Session session,
    DriveItem item,
    int userId,
  ) async {
    final db = syncSessionOf(session);
    final sheets = await Sheet.db.find(
      db,
      where: (t) => t.spreadsheetId.equals(item.contentRef!),
    );
    final cells = await Cell.db.find(
      db,
      where: (t) =>
          t.sheetId.inSet({for (final s in sheets) s.id}) &
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
        VALUES (@sp::uuid, @sh::uuid, @r::uuid, @c::uuid, @cl::uuid, @u::uuid, @k, @l, @at, @b, @a)
        ON CONFLICT ("changeLogId", "rowId", "colId") DO NOTHING
        ''',
        parameters: QueryParameters.named({
          'sp': row.spreadsheetUuid.uuid,
          'sh': row.sheetId.uuid,
          'r': row.rowId.uuid,
          'c': row.colId.uuid,
          'cl': row.changeLogId.uuid,
          'u': row.userUuid.uuid,
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
          WHERE "spreadsheetUuid" = @sp::uuid AND "sheetId" = @sh::uuid
            AND "rowId" = @r::uuid AND "colId" = @c::uuid
          ORDER BY at DESC OFFSET @keep)
        ''',
        parameters: QueryParameters.named({
          'sp': row.spreadsheetUuid.uuid,
          'sh': row.sheetId.uuid,
          'r': row.rowId.uuid,
          'c': row.colId.uuid,
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
