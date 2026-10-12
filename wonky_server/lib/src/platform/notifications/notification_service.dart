import 'dart:async';
import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../common/actor.dart';
import '../common/errors.dart';
import '../common/models.dart';
import '../common/time.dart';
import '../users/user_service.dart';

/// Sends notification digests by email. The default implementation logs the
/// digest; deployments plug in their mail provider with [NotificationService.mailer].
abstract interface class NotificationMailer {
  Future<void> sendDigest(
    Session session, {
    required String email,
    required String displayName,
    required List<NotificationView> notifications,
  });
}

class LoggingNotificationMailer implements NotificationMailer {
  const LoggingNotificationMailer();

  @override
  Future<void> sendDigest(
    Session session, {
    required String email,
    required String displayName,
    required List<NotificationView> notifications,
  }) async {
    session.log(
      'Notification digest with ${notifications.length} notification(s) '
      'not sent: no mail provider is configured.',
    );
  }
}

/// In-app notifications (specs/07 §4).
abstract final class NotificationService {
  static NotificationMailer mailer = const LoggingNotificationMailer();

  static String channel(int userId) => 'notifications:$userId';

  /// The preference key (notificationSettings) of a [kind].
  static String settingKey(NotificationKind kind) => switch (kind) {
    NotificationKind.mention => 'mentions',
    NotificationKind.reply => 'replies',
    NotificationKind.assigned => 'mentions',
    NotificationKind.shared => 'shares',
    NotificationKind.accessRequest => 'shares',
    NotificationKind.ownershipTransfer => 'shares',
    NotificationKind.suggestion => 'suggestions',
    NotificationKind.suggestionDecided => 'suggestions',
    NotificationKind.scriptFailure => 'scripts',
  };

  /// Creates a notification for [userId] unless they turned this kind off.
  /// Notifications about one's own actions are never created.
  static Future<UserNotification?> notify(
    Session session, {
    required int userId,
    required NotificationKind kind,
    DriveItem? item,
    Actor? actor,
    Map<String, Object?> payload = const {},
  }) async {
    if (actor != null && actor.userId == userId) return null;
    final channelSetting = await UserService.notificationChannel(
      session,
      userId,
      settingKey(kind),
    );
    if (channelSetting == 'off') return null;
    final row = await UserNotification.db.insertRow(
      session,
      UserNotification(
        userId: userId,
        kind: kind,
        itemId: item?.id,
        actorId: actor?.userId,
        payload: jsonEncode({
          ...payload,
          if (item != null) 'itemName': item.name,
          if (actor != null) 'actorKind': actor.kind.name,
        }),
        createdAt: nowUtc(),
      ),
    );
    await session.messages.postMessage(
      channel(userId),
      NotificationSignal(notificationId: row.id),
    );
    return row;
  }

  static Future<List<NotificationView>> _views(
    Session session,
    List<UserNotification> rows,
  ) async {
    final itemIds = {for (final r in rows) ?r.itemId};
    final items = itemIds.isEmpty
        ? <DriveItem>[]
        : await DriveItem.db.find(session, where: (t) => t.id.inSet(itemIds));
    final itemById = {for (final i in items) i.id!: i};
    final users = await UserService.summaries(session, [
      for (final r in rows) r.actorId,
    ]);
    return [
      for (final r in rows)
        NotificationView(
          id: r.id!,
          kind: r.kind,
          itemUuid: itemById[r.itemId]?.uuid,
          itemName: itemById[r.itemId]?.name,
          itemKind: itemById[r.itemId]?.kind,
          actor: r.actorId == null ? null : users[r.actorId],
          payload: r.payload,
          createdAt: r.createdAt,
          readAt: r.readAt,
        ),
    ];
  }

  static Future<int> unreadCount(Session session, int userId) =>
      UserNotification.db.count(
        session,
        where: (t) => t.userId.equals(userId) & t.readAt.equals(null),
      );

  static Future<NotificationPage> list(
    Session session,
    Actor actor, {
    String? cursor,
    int limit = 30,
    bool unreadOnly = false,
  }) async {
    final beforeId = int.tryParse(cursor ?? '');
    final rows = await UserNotification.db.find(
      session,
      where: (t) =>
          t.userId.equals(actor.userId) &
          (unreadOnly ? t.readAt.equals(null) : Constant.bool(true)) &
          (beforeId == null ? Constant.bool(true) : t.id < beforeId),
      orderBy: (t) => t.id.desc(),
      limit: limit.clamp(1, 100),
    );
    return NotificationPage(
      items: await _views(session, rows),
      nextCursor: rows.length == limit.clamp(1, 100) ? '${rows.last.id}' : null,
      unreadCount: await unreadCount(session, actor.userId),
    );
  }

  static Future<int> markRead(
    Session session,
    Actor actor,
    List<int> ids,
  ) async {
    if (ids.isNotEmpty) {
      await UserNotification.db.updateWhere(
        session,
        columnValues: (t) => [t.readAt(nowUtc())],
        where: (t) =>
            t.userId.equals(actor.userId) &
            t.id.inSet(ids.toSet()) &
            t.readAt.equals(null),
      );
    }
    await session.messages.postMessage(
      channel(actor.userId),
      NotificationSignal(),
    );
    return unreadCount(session, actor.userId);
  }

  static Future<int> markAllRead(Session session, Actor actor) async {
    await UserNotification.db.updateWhere(
      session,
      columnValues: (t) => [t.readAt(nowUtc())],
      where: (t) => t.userId.equals(actor.userId) & t.readAt.equals(null),
    );
    await session.messages.postMessage(
      channel(actor.userId),
      NotificationSignal(),
    );
    return 0;
  }

  static Stream<NotificationEvent> watch(Session session, Actor actor) async* {
    final signals = session.messages.createStream<NotificationSignal>(
      channel(actor.userId),
    );
    await for (final signal in signals) {
      NotificationView? view;
      if (signal.notificationId != null) {
        final row = await UserNotification.db.findById(
          session,
          signal.notificationId!,
        );
        if (row != null && row.userId == actor.userId) {
          view = (await _views(session, [row])).single;
        }
      }
      yield NotificationEvent(
        notification: view,
        unreadCount: await unreadCount(session, actor.userId),
      );
    }
  }

  /// Email digest job (every 15 min): unread notifications whose kind the
  /// user set to "email" and that were not emailed yet.
  static Future<int> sendDigests(Session session, {DateTime? now}) async {
    final at = now ?? nowUtc();
    final pending = await UserNotification.db.find(
      session,
      where: (t) =>
          t.readAt.equals(null) &
          t.emailedAt.equals(null) &
          (t.createdAt > at.subtract(const Duration(days: 2))),
      orderBy: (t) => t.userId,
      limit: 5000,
    );
    final byUser = <int, List<UserNotification>>{};
    for (final n in pending) {
      byUser.putIfAbsent(n.userId, () => []).add(n);
    }
    var sent = 0;
    for (final entry in byUser.entries) {
      final wanted = <UserNotification>[];
      for (final n in entry.value) {
        final setting = await UserService.notificationChannel(
          session,
          entry.key,
          settingKey(n.kind),
        );
        if (setting == 'email') wanted.add(n);
      }
      if (wanted.isEmpty) continue;
      final profile = await UserProfile.db.findById(session, entry.key);
      if (profile == null) continue;
      try {
        await mailer.sendDigest(
          session,
          email: profile.email,
          displayName: profile.displayName,
          notifications: await _views(session, wanted),
        );
      } on Exception catch (e) {
        session.log('Digest for ${entry.key} failed: $e', level: LogLevel.warning);
        continue;
      }
      await UserNotification.db.updateWhere(
        session,
        columnValues: (t) => [t.emailedAt(at)],
        where: (t) => t.id.inSet({for (final n in wanted) n.id!}),
      );
      sent++;
    }
    return sent;
  }

  static Never notFound() => throw Errors.notFound('Notification');
}
