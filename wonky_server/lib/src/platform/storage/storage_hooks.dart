import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../common/actor.dart';
import '../common/models.dart';
import '../drive/templates/builtin_templates.dart' show TemplateSheet;
import '../files/file_service.dart';
import 'content_sizes.dart';
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
  /// templates, sheet lists of MCP/imports) with the constants of
  /// [SheetsSizeEstimator], following what `SpreadsheetFactory` stores:
  /// the base, each sheet, each sized column and each cell it writes (a
  /// value, or bold in a bold row) — its stored content (text + the
  /// 2-byte prefix; formulas grow by [_formulaRefBytes] per reference in
  /// their stored-reference form), bold and number format. The real size
  /// is measured after creation (`ContentSizes.refresh`) and stays close.
  static int sheetsEstimate(List<TemplateSheet> sheets) {
    const row = SheetsSizeEstimator.propertyRowBytes;
    var n = SheetsSizeEstimator.base;
    for (final s in sheets) {
      n += SheetsSizeEstimator.sheetBytes;
      n += s.columnWidths.length * (row + 8);
      for (final (r, cells) in s.rows.indexed) {
        final bold = s.boldRows.contains(r);
        for (final (c, input) in cells.indexed) {
          final empty = input == null || input.isEmpty;
          if (empty && !bold) continue;
          final format = r >= s.frozenRows ? s.numberFormats[c] : null;
          n +=
              row +
              (empty ? 0 : _contentBytes(input)) +
              (bold ? 1 : 0) +
              (format == null ? 0 : utf8.encode(format).length);
        }
      }
    }
    return n;
  }

  /// Bytes a cell reference adds in the stored-reference form of a
  /// formula (`⟦R:<row id>;C:<column id>⟧`, Sheets 02 §2).
  static const _formulaRefBytes = 56;

  static final _a1Ref = RegExp(r'\$?[A-Z]{1,3}\$?[0-9]+');

  static int _contentBytes(String input) {
    final bytes = utf8.encode(input).length;
    if (input.startsWith('=') && input.length > 1) {
      return bytes + _a1Ref.allMatches(input).length * _formulaRefBytes;
    }
    return bytes + 2;
  }
}
