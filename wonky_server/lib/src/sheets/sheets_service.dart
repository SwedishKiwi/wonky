import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import '../platform/common/actor.dart';
import '../platform/common/errors.dart';
import '../platform/common/models.dart';
import '../platform/common/time.dart';
import '../platform/sharing/access_service.dart';
import '../platform/users/user_service.dart';
import 'sync/server_sheets_writer.dart';
import 'sync/sync_db.dart';

/// Online-only Sheets operations (Sheets 10 §5–7, 12 §2.5).
abstract final class SheetsService {
  static const activityCache = Duration(minutes: 10);
  static final Map<String, (DateTime, SheetsActivitySummary)> _activity = {};

  static Future<DriveItem> _spreadsheet(
    Session session,
    Actor actor,
    UuidValue spreadsheetUuid,
    Role min,
  ) async {
    final item = await DriveItem.db.findFirstRow(
      session,
      where: (t) =>
          t.contentRef.equals(spreadsheetUuid) &
          t.kind.equals(DriveItemKind.spreadsheet),
    );
    if (item == null) throw Errors.notFound('Spreadsheet');
    await AccessService.requireRole(session, actor, item, min);
    return item;
  }

  /// Resolves an item uuid or a space uuid to the spreadsheet item.
  static Future<DriveItem> byItemOrSpace(
    Session session,
    Actor actor,
    UuidValue uuid,
    Role min,
  ) async {
    final item = await AccessService.findItem(session, uuid);
    if (item != null) {
      await AccessService.requireRole(session, actor, item, min);
      if (item.kind != DriveItemKind.spreadsheet) {
        throw Errors.invalid('The item is not a spreadsheet.');
      }
      return item;
    }
    return _spreadsheet(session, actor, uuid, min);
  }

  static Future<RevertResult> revertChange(
    Session session,
    Actor actor,
    UuidValue changeId,
  ) async {
    final record = await ServerChangeRecord.db.findFirstRow(
      session,
      where: (t) => t.changeId.equals(changeId),
    );
    if (record == null) throw Errors.notFound('Change');
    final item = await _spreadsheet(
      session,
      actor,
      record.spreadsheetUuid,
      Role.editor,
    );
    return ServerSheetsWriter.revert(session, actor, item, changeId);
  }

  static Future<RevertResult> reapplyChange(
    Session session,
    Actor actor,
    UuidValue changeId,
  ) async {
    final record = await ServerChangeRecord.db.findFirstRow(
      session,
      where: (t) =>
          t.revertChangeId.equals(changeId) | t.changeId.equals(changeId),
    );
    if (record == null) throw Errors.notFound('Change');
    final item = await _spreadsheet(
      session,
      actor,
      record.spreadsheetUuid,
      Role.editor,
    );
    return ServerSheetsWriter.reapply(session, actor, item, record.changeId);
  }

  /// Older value history of a cell from [CellHistory] (newest first).
  static Future<CellHistoryPage> cellHistory(
    Session session,
    Actor actor,
    UuidValue spreadsheetUuid,
    UuidValue sheetId,
    UuidValue rowId,
    UuidValue colId, {
    String? cursor,
    int limit = 50,
  }) async {
    await _spreadsheet(session, actor, spreadsheetUuid, Role.viewer);
    final before = cursor == null ? null : DateTime.tryParse(cursor);
    final rows = await CellHistory.db.find(
      session,
      where: (t) =>
          t.spreadsheetUuid.equals(spreadsheetUuid) &
          t.sheetId.equals(sheetId) &
          t.rowId.equals(rowId) &
          t.colId.equals(colId) &
          (before == null ? Constant.bool(true) : t.at < before),
      orderBy: (t) => t.at.desc(),
      limit: limit.clamp(1, 100),
    );
    final profiles = await UserProfile.db.find(
      session,
      where: (t) => t.authUserId.inSet({for (final r in rows) r.userUuid}),
    );
    final byAuth = {for (final p in profiles) p.authUserId: p};
    final summaries = await UserService.summaries(session, [
      for (final p in profiles) p.id,
    ]);
    return CellHistoryPage(
      entries: [
        for (final r in rows)
          CellHistoryEntry(
            changeLogId: r.changeLogId,
            user: summaries[byAuth[r.userUuid]?.id],
            actorKind: r.actorKind,
            label: r.label,
            at: r.at,
            before: r.before,
            after: r.after,
          ),
      ],
      nextCursor: rows.length == limit.clamp(1, 100)
          ? rows.last.at.toIso8601String()
          : null,
    );
  }

  /// The Sheets activity dashboard data (Editors+), cached 10 minutes.
  static Future<SheetsActivitySummary> activitySummary(
    Session session,
    Actor actor,
    UuidValue spreadsheetUuid,
    int days,
  ) async {
    await _spreadsheet(session, actor, spreadsheetUuid, Role.editor);
    final span = days.clamp(1, 30);
    final key = '${spreadsheetUuid.uuid}|$span';
    final cached = _activity[key];
    if (cached != null && nowUtc().difference(cached.$1) < activityCache) {
      return cached.$2;
    }
    final since = nowUtc().subtract(Duration(days: span));
    final db = syncSessionOf(session);
    final logs = await ChangeLog.db.find(
      db,
      where: (t) => t.spreadsheetId.equals(spreadsheetUuid) & (t.at > since),
      limit: 50000,
    );
    final profiles = await UserProfile.db.find(
      session,
      where: (t) => t.authUserId.inSet({for (final l in logs) l.userId}),
    );
    final idByAuth = {for (final p in profiles) p.authUserId: p.id!};
    final edits = <int, int>{};
    final last = <int, DateTime>{};
    final kinds = <int, ActorKind>{};
    final perDay = <String, Map<int, int>>{};
    final perSheet = <String, int>{};
    var mcp = 0;
    var ai = 0;
    var script = 0;
    for (final l in logs) {
      final uid = idByAuth[l.userId] ?? 0;
      edits[uid] = (edits[uid] ?? 0) + 1;
      if (last[uid] == null || l.at.isAfter(last[uid]!)) last[uid] = l.at;
      kinds[uid] ??= l.actorKind;
      final day = l.at.toIso8601String().substring(0, 10);
      final dayMap = perDay.putIfAbsent(day, () => {});
      dayMap[uid] = (dayMap[uid] ?? 0) + 1;
      switch (l.actorKind) {
        case ActorKind.mcp:
          mcp++;
        case ActorKind.ai:
          ai++;
        case ActorKind.script:
          script++;
        default:
          break;
      }
      try {
        final summary = jsonDecode(l.summaryJson);
        if (summary is Map && summary['sheets'] is List) {
          for (final s in summary['sheets'] as List) {
            perSheet['$s'] = (perSheet['$s'] ?? 0) + 1;
          }
        }
      } on FormatException {
        // Ignore malformed summaries.
      }
    }
    // Top 8 contributors, the rest as "others" (0).
    final ranked = edits.keys.toList()
      ..sort((a, b) => edits[b]!.compareTo(edits[a]!));
    final top = ranked.take(8).toSet();
    final users = await UserService.summaries(session, top);
    for (final day in perDay.values) {
      final others = day.entries
          .where((e) => !top.contains(e.key))
          .fold(0, (a, e) => a + e.value);
      day.removeWhere((k, _) => !top.contains(k));
      if (others > 0) day[0] = others;
    }
    final result = SheetsActivitySummary(
      days: span,
      editsPerDay: perDay,
      contributors: [
        for (final uid in ranked)
          SheetsContributorStat(
            user: users[uid],
            actorKind: kinds[uid] ?? ActorKind.user,
            edits: edits[uid]!,
            lastEditAt: last[uid]!,
          ),
      ],
      editsPerSheet: perSheet,
      mcpEdits: mcp,
      aiEdits: ai,
      scriptEdits: script,
    );
    _activity[key] = (nowUtc(), result);
    return result;
  }
}
