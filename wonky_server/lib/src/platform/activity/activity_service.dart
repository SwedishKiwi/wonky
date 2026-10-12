import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../common/actor.dart';
import '../common/json.dart';
import '../common/models.dart';
import '../common/time.dart';
import '../users/user_service.dart';

/// The activity log of drive items (specs/05 §5).
abstract final class ActivityService {
  /// Window in which consecutive edits by one user are merged into one event.
  static const editWindow = Duration(minutes: 10);

  static Future<void> log(
    Session session,
    int itemId,
    Actor? actor,
    ActivityType type, {
    Map<String, Object?> summary = const {},
    Transaction? transaction,
  }) async {
    await ActivityEvent.db.insertRow(
      session,
      ActivityEvent(
        itemId: itemId,
        actorId: actor?.userId,
        actorKind: actor?.kind ?? ActorKind.system,
        type: type,
        summary: jsonEncode(summary),
        at: nowUtc(),
      ),
      transaction: transaction,
    );
  }

  /// Records an edit, merged with the user's previous edit event on the item
  /// when it is less than [editWindow] old. Numeric [counters] are summed;
  /// actor kinds are collected in `actorKinds`.
  static Future<void> logEdit(
    Session session,
    int itemId,
    Actor actor, {
    Map<String, num> counters = const {},
    Transaction? transaction,
  }) async {
    final now = nowUtc();
    final recent = await ActivityEvent.db.findFirstRow(
      session,
      where: (t) =>
          t.itemId.equals(itemId) &
          t.actorId.equals(actor.userId) &
          t.type.equals(ActivityType.edited) &
          (t.at > now.subtract(editWindow)),
      orderBy: (t) => t.at.desc(),
      transaction: transaction,
    );
    if (recent == null) {
      await ActivityEvent.db.insertRow(
        session,
        ActivityEvent(
          itemId: itemId,
          actorId: actor.userId,
          actorKind: actor.kind,
          type: ActivityType.edited,
          summary: jsonEncode({
            ...counters,
            'actorKinds': [actor.kind.name],
          }),
          at: now,
        ),
        transaction: transaction,
      );
      return;
    }
    final summary = decodeObject(recent.summary);
    counters.forEach((key, value) {
      final prev = summary[key];
      summary[key] = (prev is num ? prev : 0) + value;
    });
    final kinds = {
      ...((summary['actorKinds'] as List<Object?>?) ?? const []).map(
        (k) => '$k',
      ),
      actor.kind.name,
    };
    summary['actorKinds'] = kinds.toList()..sort();
    await ActivityEvent.db.updateRow(
      session,
      recent.copyWith(summary: jsonEncode(summary)),
      columns: (t) => [t.summary],
      transaction: transaction,
    );
  }

  static Future<List<ActivityEventView>> list(
    Session session,
    int itemId, {
    int? beforeId,
    int limit = 50,
  }) async {
    final events = await ActivityEvent.db.find(
      session,
      where: (t) =>
          t.itemId.equals(itemId) &
          (beforeId == null ? Constant.bool(true) : t.id < beforeId),
      orderBy: (t) => t.id.desc(),
      limit: limit.clamp(1, 200),
    );
    final users = await UserService.summaries(session, [
      for (final e in events) e.actorId,
    ]);
    return [
      for (final e in events)
        ActivityEventView(
          id: e.id!,
          type: e.type,
          actor: e.actorId == null ? null : users[e.actorId],
          actorKind: e.actorKind,
          summary: e.summary,
          at: e.at,
        ),
    ];
  }
}
