import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';
import '../../platform/users/user_service.dart';
import '../spaces/slides_spaces.dart';
import '../sync/server_slides_writer.dart';

/// Online-only Slides operations on deck spaces (Slides 02 §9, suite 12
/// §2.6): reservations for offline creation, subscriptions (membership
/// mirrored from the ACL), the pending-change guard and download progress.
class SlidesEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Reserves up to [count] (≤ 5) empty deck spaces for offline creation.
  Future<List<UuidValue>> reserveSpaces(Session session, int count) async =>
      SlidesSpaces.reserveSpaces(
        session,
        await UserService.actorOf(session),
        count,
      );

  /// Grants membership of the deck's space (role mirrored from the ACL) and
  /// adds it to the caller's active set of decks.
  Future<SubscribeResult> subscribe(
    Session session,
    UuidValue itemUuid,
  ) async => SlidesSpaces.subscribe(
    session,
    await UserService.actorOf(session),
    itemUuid,
  );

  Future<void> unsubscribe(Session session, UuidValue itemUuid) async =>
      SlidesSpaces.unsubscribe(
        session,
        await UserService.actorOf(session),
        itemUuid,
      );

  /// Pending-change guard: re-grants deck spaces with unsynced local
  /// changes.
  Future<List<UuidValue>> ensureSubscribed(
    Session session,
    List<UuidValue> spaces,
  ) async => SlidesSpaces.ensureSubscribed(
    session,
    await UserService.actorOf(session),
    spaces,
  );

  /// Row counts of the deck's space for download progress.
  Future<SpaceStats> spaceStats(Session session, UuidValue itemUuid) async =>
      SlidesSpaces.statsFor(
        session,
        await UserService.actorOf(session),
        itemUuid,
      );

  /// Undo of a server-side change (`slides.serverChange`: MCP, AI,
  /// templates, restores): applies the recorded inverse with the
  /// per-column skip rule (columns others changed since stay; coupled
  /// columns stay together). Editor+.
  Future<RevertResult> revertChange(
    Session session,
    UuidValue changeId,
  ) async => ServerSlidesWriter.revert(
    session,
    await UserService.actorOf(session),
    changeId,
  );

  /// Redo of a reverted server-side change ([changeId] of the original or
  /// of its revert).
  Future<RevertResult> reapplyChange(
    Session session,
    UuidValue changeId,
  ) async => ServerSlidesWriter.reapply(
    session,
    await UserService.actorOf(session),
    changeId,
  );
}
