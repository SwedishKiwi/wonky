import 'dart:async';
import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_sheets_core/model.dart' show ChangeSummary;

import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../../platform/presence/presence_service.dart';
import '../../platform/users/user_service.dart';

/// Cursors of agents writing without a window (Sheets 10 §1.1): after a
/// headless MCP/AI write is consumed, the agent shows as a participant whose
/// `ranges` are the written ranges, for [ttl] after its last write. One
/// participant per spreadsheet, user and actor kind; later writes move it.
abstract final class AgentCursors {
  static const ttl = Duration(seconds: 5);

  /// Max ranges in a presence cursor (Sheets 10 §1.1).
  static const maxRanges = 20;

  static final Map<String, ({String sessionId, Timer bye})> _live = {};

  /// Whether the cursor of [actor] is currently shown on [item] (tests).
  static bool isShown(DriveItem item, Actor actor) =>
      _live.containsKey(_key(item, actor));

  static String _key(DriveItem item, Actor actor) =>
      '${item.uuid.uuid}|${actor.userId}|${actor.kind.name}';

  /// The `PresenceCursor` JSON of a write's [summary] (null when it names
  /// no range, e.g. sheet settings).
  static String? cursorOf(ChangeSummary summary) {
    final ranges = [
      for (final r in summary.ranges)
        if (r['s'] is String) r,
    ];
    if (ranges.isEmpty) return null;
    final sheetId = ranges.first['s'] as String;
    final onSheet = [
      for (final r in ranges)
        if (r['s'] == sheetId) r,
    ].take(maxRanges).toList();
    final first = onSheet.first;
    return jsonEncode({
      'route': 'grid',
      'sheetId': sheetId,
      if (first['r1'] is String && first['c1'] is String)
        'activeCell': {'rowId': first['r1'], 'colId': first['c1']},
      'ranges': [
        for (final r in onSheet)
          {
            if (r['r1'] != null) 'r1': r['r1'],
            if (r['c1'] != null) 'c1': r['c1'],
            if (r['r2'] != null) 'r2': r['r2'],
            if (r['c2'] != null) 'c2': r['c2'],
          },
      ],
    });
  }

  /// Shows (or moves) the cursor of an MCP/AI [actor] after its write.
  static Future<void> show(
    Session session,
    DriveItem item,
    Actor actor,
    ChangeSummary summary,
  ) async {
    if (actor.kind != ActorKind.mcp && actor.kind != ActorKind.ai) return;
    final cursor = cursorOf(summary);
    if (cursor == null) return;
    final key = _key(item, actor);
    final existing = _live.remove(key);
    existing?.bye.cancel();
    String name;
    try {
      final profile = await UserService.requireProfile(session, actor.userId);
      name = (await UserService.summaryOf(session, profile)).displayName;
    } on Exception {
      name = '';
    }
    final id = await PresenceService.injectAgent(
      session,
      item.uuid,
      actor: actor,
      displayName: name,
      ttl: null,
      sessionId: existing?.sessionId,
      cursorJson: cursor,
    );
    final pod = session.serverpod;
    final itemUuid = item.uuid;
    _live[key] = (
      sessionId: id,
      bye: Timer(ttl, () {
        _live.remove(key);
        PresenceService.removeAgent(pod, itemUuid, id);
      }),
    );
  }
}
