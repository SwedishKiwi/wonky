import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides_core/themes.dart' show BuiltInThemes;

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/common/names.dart';
import '../../platform/drive/drive_service.dart';
import '../../platform/drive/drive_views.dart';
import '../../platform/drive/templates/builtin_templates.dart';
import '../../platform/sharing/access_service.dart';
import '../../platform/storage/storage_service.dart';
import '../../platform/spaces/space_service.dart';
import '../../platform/storage/content_sizes.dart';
import '../../platform/storage/storage_hooks.dart';
import '../../sheets/sync/sync_db.dart';
import '../sync/slides_sync_service.dart';
import '../templates/slides_template_decks.dart';
import 'deck_copies.dart';
import 'deck_factory.dart';

/// Server-side deck lifecycle (Slides 02 §9.3): creating a deck online
/// (`drive.createPresentation`; MCP and AI later) and mirroring drive
/// renames into `Deck.title` (the other direction of the change-log
/// consumer's title mirroring).
abstract final class SlidesDecks {
  /// Creates a deck: a server-created `deck` space (kind recorded from
  /// birth), the rows of a new deck with built-in theme [themeKey] and a
  /// title slide, and its drive item (uuid = space). Blank decks are tiny
  /// and always allowed (Drive 03 §7.2); their size is estimated at once.
  /// With [templateUuid] (a presentation the caller can read, e.g. one
  /// marked as a template) the deck is a copy of it ([DeckCopies], SL-8;
  /// the quota is checked first, reason `template`); a built-in
  /// presentation template (`SlidesTemplates`, SL-22) is built into the new
  /// space by the core's planner.
  static Future<DriveItemView> create(
    Session session,
    Actor actor, {
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
    String? themeKey,
  }) async {
    if (templateUuid != null) {
      return _fromTemplate(
        session,
        actor,
        templateUuid,
        parentUuid: parentUuid,
        name: name,
      );
    }
    final theme = themeKey ?? BuiltInThemes.defaultKey;
    if (BuiltInThemes.byKey(theme) == null) {
      throw Errors.invalid('Unknown theme "$theme".');
    }
    return _createDeck(
      session,
      actor,
      parentUuid: parentUuid,
      name: name,
      summary: {'theme': theme},
      write: (space, title) => DeckFactory.write(
        session,
        actor: actor,
        deckSpace: space,
        title: title,
        themeKey: theme,
      ),
    );
  }

  /// Creates a deck space, lets [write] fill it, then the drive item (uuid
  /// = space), its size and the creation's change-log consumers.
  static Future<DriveItemView> _createDeck(
    Session session,
    Actor actor, {
    UuidValue? parentUuid,
    required String name,
    required Map<String, Object?> summary,
    required Future<void> Function(UuidValue space, String title) write,
  }) async {
    final cleanName = normalizeItemName(name);
    // Checks the folder before anything is created.
    await DriveService.parentFor(session, actor, parentUuid);
    final space = await SpaceService.createSpace(
      session,
      actor,
      kind: SpaceKind.deck,
    );
    await write(space, cleanName);
    final item = await session.db.transaction((tx) async {
      final parent = await DriveService.parentFor(
        session,
        actor,
        parentUuid,
        transaction: tx,
      );
      final item = await DriveService.insertItem(
        session,
        actor,
        kind: DriveItemKind.presentation,
        name: cleanName,
        parent: parent,
        contentRef: space,
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
    await ContentSizes.refresh(session, item);
    await DriveService.afterCreate(session, actor, item, summary: summary);
    // The creation's change-log row (search text, version state).
    await SlidesSyncService.afterRegistration(session, space);
    return DriveViews.one(session, actor.userId, item, role: Role.owner);
  }

  static Future<DriveItemView> _fromTemplate(
    Session session,
    Actor actor,
    UuidValue templateUuid, {
    UuidValue? parentUuid,
    required String name,
  }) async {
    final builtin = BuiltinTemplates.byUuid(templateUuid);
    if (builtin != null) {
      if (builtin.kind != DriveItemKind.presentation) {
        throw Errors.invalid('This is not a presentation template.');
      }
      // (SL-22) A built-in template: its deck is built by the core's
      // planner into the new space; the quota is checked first.
      final template = builtin.slides!;
      await StorageHooks.checkCaller(
        session,
        actor,
        SlidesTemplateDecks.estimate(template),
        QuotaReason.template,
      );
      return _createDeck(
        session,
        actor,
        parentUuid: parentUuid,
        name: name,
        summary: {'template': builtin.key},
        write: (space, title) => SlidesTemplateDecks.write(
          session,
          actor: actor,
          deckSpace: space,
          template: template,
          title: title,
        ),
      );
    }
    final (template, role) = await AccessService.require(
      session,
      actor,
      templateUuid,
      Role.viewer,
    );
    if (template.kind != DriveItemKind.presentation) {
      throw Errors.invalid('This is not a presentation template.');
    }
    if (role < Role.editor && !template.nonEditorsCanExport) {
      throw Errors.forbidden('The owner has disabled copying for viewers.');
    }
    final copied = await DeckCopies.copy(
      session,
      actor,
      template,
      name: name,
      parentUuid: parentUuid,
      quotaReason: QuotaReason.template,
    );
    await DriveService.afterCreate(
      session,
      actor,
      copied.item,
      summary: {'template': template.uuid.uuid},
    );
    return DriveViews.one(session, actor.userId, copied.item, role: Role.owner);
  }

  /// Writes a drive rename into the synced `Deck.title` (best effort: needs
  /// write membership, which editors get on demand). Not a change-log row:
  /// like Sheets, a rename from the drive is not an undoable deck edit.
  static Future<void> mirrorTitleToDeck(
    Session session,
    Actor actor,
    DriveItem item,
  ) async {
    if (item.kind != DriveItemKind.presentation || item.contentRef == null) {
      return;
    }
    try {
      final db = syncSessionOf(session);
      final deck = await Deck.db.findById(db, item.contentRef!);
      if (deck == null || deck.title == item.name) return;
      await SpaceService.ensureWriter(
        session,
        actor,
        item,
        reason: SubscriptionReason.recent,
      );
      await db.offlineSyncDb.transactionForUser(
        actor.authUserId,
        (tx) => Deck.db.updateById(
          db,
          item.contentRef!,
          columnValues: (t) => [t.title(item.name)],
          transaction: tx,
        ),
        spaceId: item.contentRef!,
      );
    } on Exception catch (e) {
      session.log(
        'Could not mirror the title of ${item.uuid} to its deck: $e',
        level: LogLevel.warning,
      );
    }
  }
}
