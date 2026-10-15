import 'package:serverpod/serverpod.dart';

import '../common/actor.dart';
import '../common/models.dart';
import '../drive/templates/builtin_templates.dart' show TemplateSheet;
import '../files/file_service.dart';
import 'storage_service.dart';

/// One-line quota hooks for the byte-adding paths outside the upload
/// endpoints (Drive 03 §7.2): room checks before work and the charging of
/// images stored by the server.
abstract final class StorageHooks {
  /// Refuses (`quotaExceeded`) when [bytes] don't fit [actor]'s quota
  /// (copies, imports, conversions, templates, version copies).
  static Future<void> checkCaller(
    Session session,
    Actor actor,
    int bytes,
    String reason, {
    Transaction? transaction,
  }) => StorageService.instance.checkRoom(
    session,
    userId: actor.userId,
    bytes: bytes,
    reason: reason,
    transaction: transaction,
  );

  /// Refuses when [bytes] don't fit the quota of [item]'s owner (images
  /// added to an item, imports into an existing spreadsheet): the owner
  /// pays (Drive 03 §2), `isCaller` tells the client which dialog to show.
  static Future<void> checkOwnerOf(
    Session session,
    Actor actor,
    DriveItem item,
    int bytes,
    String reason,
  ) => StorageService.instance.checkRoom(
    session,
    userId: item.ownerId,
    bytes: bytes,
    reason: reason,
    callerUserId: actor.userId,
  );

  /// Attaches server-stored [images] to [item] and charges their bytes to
  /// its owner (`attachmentBytes`). Images already attached to [item] are
  /// not charged again.
  static Future<void> attachImages(
    Session session,
    DriveItem item,
    Iterable<StoredFile> images,
  ) async {
    var bytes = 0;
    for (final f in images) {
      if (f.itemId == item.id) continue;
      await FileService.attachToItem(session, f, item);
      if (f.kind == StoredFileKind.image &&
          f.status == StoredFileStatus.ready) {
        bytes += f.sizeBytes;
      }
    }
    if (bytes != 0) {
      await StorageService.instance.addAttachment(session, item, bytes);
    }
  }

  /// Charges an image stored by the server directly for [item] (its
  /// `itemId` already set).
  static Future<void> chargeImage(
    Session session,
    DriveItem item,
    StoredFile image,
  ) => StorageService.instance.addAttachment(session, item, image.sizeBytes);

  /// A pre-check estimate of a spreadsheet created from [sheets] (built-in
  /// templates, sheet lists of MCP/imports): cell text plus a per-row
  /// overhead close to `pg_column_size` of the synced rows. The real size
  /// is measured after creation (`ContentSizes.refresh`).
  static int sheetsEstimate(List<TemplateSheet> sheets) {
    const base = 2048; // spreadsheet, sheet and column rows
    const perCell = 160;
    const perRow = 120;
    var n = base;
    for (final s in sheets) {
      n += 512;
      for (final row in s.rows) {
        n += perRow;
        for (final cell in row) {
          if (cell == null || cell.isEmpty) continue;
          n += perCell + cell.length;
        }
      }
    }
    return n;
  }
}
