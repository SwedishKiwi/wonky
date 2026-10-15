import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import '../../slides/spaces/slides_decks.dart';
import '../../slides/sync/slides_sync_service.dart';
import '../common/actor.dart';
import '../common/errors.dart';
import '../common/models.dart';
import '../spaces/space_service.dart';
import 'drive_service.dart';
import 'drive_views.dart';

/// (v2) Drive items of Wonky Slides decks (Slides 02 §9.3).
abstract final class DrivePresentations {
  /// Registers a deck created locally in a reserved `deck` space
  /// (idempotent; works for queued offline creations). The item uuid is the
  /// space uuid. Never refused for quota (content arrives through sync,
  /// Drive 03 §7.2). A parent folder that is gone or no longer editable
  /// puts the deck in My Drive.
  static Future<DriveItemView> register(
    Session session,
    Actor actor, {
    required UuidValue spaceUuid,
    UuidValue? parentUuid,
    required String name,
  }) async {
    final existing = await DriveItem.db.findFirstRow(
      session,
      where: (t) => t.contentRef.equals(spaceUuid) | t.uuid.equals(spaceUuid),
    );
    if (existing != null) {
      if (existing.kind != DriveItemKind.presentation) {
        throw Errors.conflict('This space belongs to another item.');
      }
      return DriveService.get(session, actor, existing.uuid);
    }
    final item = await session.db.transaction((tx) async {
      // Kind-aware: a space reserved for a spreadsheet is refused.
      final reserved = await SpaceService.useReservation(
        session,
        actor,
        spaceUuid,
        kind: SpaceKind.deck,
        transaction: tx,
      );
      if (!reserved) {
        final role = await session.offlineSync.spaces.roleOf(
          user: actor.authUserId,
          space: spaceUuid,
        );
        if (role != OfflineSyncSpaceRole.readWrite) {
          throw Errors.forbidden('This space is not reserved for you.');
        }
      }
      DriveItem? parent;
      try {
        parent = await DriveService.parentFor(
          session,
          actor,
          parentUuid,
          transaction: tx,
        );
      } on WonkyException {
        // Deleted or unshared while offline: My Drive.
        parent = null;
      }
      final item = await DriveService.insertItem(
        session,
        actor,
        kind: DriveItemKind.presentation,
        name: name,
        parent: parent,
        contentRef: spaceUuid,
        transaction: tx,
      );
      await SpaceService.touchSubscription(
        session,
        actor.userId,
        item,
        transaction: tx,
      );
      return item;
    });
    await DriveService.afterCreate(session, actor, item);
    // (SL-5) Change-log rows that synced before the registration.
    await SlidesSyncService.afterRegistration(session, spaceUuid);
    return DriveViews.one(session, actor.userId, item, role: Role.owner);
  }

  /// Creates a deck server-side (`drive.createPresentation`, Slides 02
  /// §9.3; SL-5 `SlidesDecks.create`).
  static Future<DriveItemView> create(
    Session session,
    Actor actor, {
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
    String? themeKey,
  }) => SlidesDecks.create(
    session,
    actor,
    parentUuid: parentUuid,
    name: name,
    templateUuid: templateUuid,
    themeKey: themeKey,
  );
}
