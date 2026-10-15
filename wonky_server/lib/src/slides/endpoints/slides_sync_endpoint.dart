import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import '../../platform/users/user_service.dart';
import '../sync/slides_sync_service.dart';

/// The Slides sync stream (Slides 02 §9.1, suite 12 §2.5–2.6): the engine's
/// sync over deck spaces + the personal space (patch OS-8) with
/// `onMergeSuccess` processing of the deck change log. Clients use it as
/// their `OfflineSyncClient` transport.
class SlidesSyncEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Stream<OfflineSyncStreamEvent> sync(
    Session session, {
    required Stream<OfflineSyncStreamEvent> changes,
    bool once = false,
  }) async* {
    final actor = await UserService.actorOf(session);
    yield* SlidesSyncService.sync(session, actor, changes: changes, once: once);
  }
}
