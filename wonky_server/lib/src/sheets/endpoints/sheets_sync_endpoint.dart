import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import '../../platform/users/user_service.dart';
import '../sync/sheets_sync_service.dart';

/// The Sheets sync stream (suite 12 §2.5): `session.offlineSync.sync` with
/// `onMergeSuccess` processing. Clients use it as their
/// `OfflineSyncClient` transport instead of the module endpoint.
class SheetsSyncEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Stream<OfflineSyncStreamEvent> sync(
    Session session, {
    required Stream<OfflineSyncStreamEvent> changes,
    bool once = false,
  }) async* {
    final actor = await UserService.actorOf(session);
    yield* SheetsSyncService.sync(session, actor, changes: changes, once: once);
  }
}
