import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import '../users/user_service.dart';
import 'presence_service.dart';

/// Ephemeral presence on an item (specs/07 §1).
class PresenceEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Joins [itemUuid]; the first event is a [PresenceRoster].
  Stream<PresenceEvent> join(
    Session session,
    UuidValue itemUuid,
    Stream<PresenceUpdate> updates,
  ) async* {
    final actor = await UserService.actorOf(session);
    yield* PresenceService.join(session, actor, itemUuid, updates);
  }
}
