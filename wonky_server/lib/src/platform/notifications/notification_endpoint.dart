import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import '../users/user_service.dart';
import 'notification_service.dart';

/// In-app notifications (specs/07 §4).
class NotificationEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<NotificationPage> list(
    Session session,
    String? cursor,
    int limit,
    bool unreadOnly,
  ) async => NotificationService.list(
    session,
    await UserService.actorOf(session),
    cursor: cursor,
    limit: limit,
    unreadOnly: unreadOnly,
  );

  Future<int> unreadCount(Session session) async {
    final actor = await UserService.actorOf(session);
    return NotificationService.unreadCount(session, actor.userId);
  }

  /// Marks notifications read; returns the unread count.
  Future<int> markRead(Session session, List<int> ids) async =>
      NotificationService.markRead(
        session,
        await UserService.actorOf(session),
        ids,
      );

  Future<int> markAllRead(Session session) async =>
      NotificationService.markAllRead(
        session,
        await UserService.actorOf(session),
      );

  /// New notifications and unread count changes.
  Stream<NotificationEvent> watch(Session session) async* {
    final actor = await UserService.actorOf(session);
    yield* NotificationService.watch(session, actor);
  }
}
