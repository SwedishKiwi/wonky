import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:wonky_slides_core/copy.dart';
import 'package:wonky_slides_core/model.dart' show DeckModel;

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/common/names.dart';
import '../../platform/drive/drive_service.dart';
import '../../platform/files/file_service.dart';
import '../../platform/spaces/space_service.dart';
import '../../platform/storage/content_sizes.dart';
import '../../platform/storage/storage_hooks.dart';
import '../../platform/storage/storage_service.dart';
import '../headless/headless_deck_cache.dart';
import '../sync/server_slides_writer.dart';
import '../sync/slides_sync_service.dart';

/// A deck copied by [DeckCopies.copy].
class CopiedDeck {
  CopiedDeck(this.item, this.ids, this.files, this.filesFailed);

  /// The new presentation item (uuid = space).
  final DriveItem item;

  /// Old → new row ids (comment anchors).
  final Map<String, String> ids;

  /// Uploaded files copied into the new item.
  final int files;

  /// Files that could not be copied (gone, unreadable); their elements
  /// keep the new reference and render as missing images.
  final int filesFailed;
}

/// Server-side deck copies (Slides 02 §9.3): *Make a copy*
/// (`drive.copy`), presentations created from a template item
/// (`drive.createPresentation(templateUuid)`) and version copies
/// (`slidesVersion.makeCopy`, [sourceModel]).
/// Rows are rewritten by the core `DeckCopier` (new ids, deterministic
/// ids for the new deck, references remapped) and written through
/// [ServerSlidesWriter] into a server-created deck space; uploaded images
/// are re-homed into the new item (`FileService.copyToItem`). The caller
/// pays (Drive 03 §7.2): the quota is checked before anything is created
/// (`StorageService.checkRoom` with the source's content + attachment
/// size) and the copy's size is measured after (`ContentSizes.refresh`
/// → `setItemSize`; images as attachment bytes).
abstract final class DeckCopies {
  /// The label of the copy's change-log row.
  static const copyLabel = 'Copy presentation';

  /// Copies the deck of [source] for [actor] into [parentUuid] (null = My
  /// Drive) under [name]. The caller checked read access and the copy
  /// permission; the parent is checked here.
  static Future<CopiedDeck> copy(
    Session session,
    Actor actor,
    DriveItem source, {
    required String name,
    UuidValue? parentUuid,
    String? description,
    String quotaReason = QuotaReason.copy,
    DeckModel? sourceModel,
  }) async {
    if (source.kind != DriveItemKind.presentation ||
        source.contentRef == null) {
      throw Errors.invalid('This is not a presentation.');
    }
    final cleanName = normalizeItemName(name);
    await StorageHooks.checkCaller(
      session,
      actor,
      source.sizeBytes + source.attachmentBytes,
      quotaReason,
    );
    // Checks the folder before anything is created.
    await DriveService.parentFor(session, actor, parentUuid);
    // A version copy (Slides 09 §4.5) passes the version's model.
    final sourceDeck =
        sourceModel ??
        (await HeadlessDeckCache.open(session, source.contentRef!)).model;
    final space = await SpaceService.createSpace(
      session,
      actor,
      kind: SpaceKind.deck,
    );
    final copy = DeckCopier.copy(
      sourceDeck,
      deckId: space.uuid,
      userId: actor.authUserId.uuid,
      now: clock.now().toUtc(),
      title: cleanName,
    );
    await ServerSlidesWriter.write(
      session,
      actor: actor,
      deckSpace: space,
      changes: copy.inserts,
      label: copyLabel,
      // The drive item doesn't exist yet; the registration below runs it.
      consume: false,
    );
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
        description: description,
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
    var copied = 0, failed = 0;
    for (final f in copy.files) {
      try {
        await FileService.copyToItem(
          session,
          actor,
          sourceFileUuid: UuidValue.withValidation(f.sourceFileUuid),
          newFileUuid: UuidValue.withValidation(f.newFileUuid),
          targetItemUuid: item.uuid,
        );
        copied++;
      } on WonkyException catch (e) {
        failed++;
        session.log(
          'Deck copy ${item.uuid}: file ${f.sourceFileUuid} not copied '
          '(${e.message})',
          level: LogLevel.warning,
        );
      }
    }
    await ContentSizes.refresh(session, item);
    // The copy's change-log row: search text, drive mirror, activity.
    await SlidesSyncService.afterRegistration(session, space);
    final fresh = await DriveItem.db.findById(session, item.id!) ?? item;
    return CopiedDeck(fresh, copy.ids, copied, failed);
  }
}
