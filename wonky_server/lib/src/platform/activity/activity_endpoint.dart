import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import '../users/user_service.dart';
import 'activity_service.dart';

/// Tools › Activity dashboard (specs/07 §6): viewers, view and comment
/// trends, and the "Show my view history" privacy setting.
class ActivityEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// The dashboard of [itemUuid] for the last [days] days (1–365).
  Future<ActivityDashboard> dashboard(
    Session session,
    UuidValue itemUuid,
    int days,
  ) async => ActivityService.dashboard(
    session,
    await UserService.actorOf(session),
    itemUuid,
    days: days,
  );

  /// The caller's "Show my view history" setting.
  Future<bool> showViewHistory(Session session) async {
    final actor = await UserService.actorOf(session);
    return ActivityService.showViewHistory(session, actor.userId);
  }

  /// Turns the caller's "Show my view history" on or off; returns it.
  Future<bool> setShowViewHistory(Session session, bool show) async {
    final actor = await UserService.actorOf(session);
    return ActivityService.setShowViewHistory(session, actor.userId, show);
  }
}
