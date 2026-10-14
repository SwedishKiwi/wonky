import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import '../../platform/comments/comment_copier.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/drive/drive_service.dart';
import '../../platform/files/file_service.dart';
import '../../platform/sharing/access_service.dart';
import '../../platform/users/user_service.dart';
import '../../platform/versions/version_service.dart';
import 'sheets_version_changes.dart';
import 'sheets_version_provider.dart';

/// Sheets extensions of version history (Sheets 10 §5.2, §5.4): changed
/// ranges with authors, the server-side diff of big versions, and the
/// comments/sharing options of *Make a copy* from a version.
class SheetsVersionEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// `changedRangesJson` of a version (`{v, approx, ranges: [{s, r1, c1,
  /// r2, c2, u}]}`, oldest first; `u` = user id of the author). Versions
  /// captured before the index existed are computed on the fly.
  Future<String> changes(
    Session session,
    UuidValue itemUuid,
    int versionId,
  ) async {
    final actor = await UserService.actorOf(session);
    final (item, version) = await VersionService.requireVersion(
      session,
      actor,
      itemUuid,
      versionId,
      min: Role.editor,
    );
    final index = await SheetsSnapshotIndex.db.findFirstRow(
      session,
      where: (t) => t.itemVersionId.equals(version.id!),
    );
    final stored = index?.changedRangesJson;
    if (stored != null && stored.startsWith('{')) return stored;
    final (from, to) = await SheetsVersionChanges.windowOf(session, version);
    final (ranges, approx) = await SheetsVersionChanges.rangesBetween(
      session,
      item.contentRef!,
      from: from,
      to: to,
    );
    return SheetsVersionChanges.encode(ranges, approx: approx);
  }

  /// The diff of [versionId] against [previousVersionId] (default: the
  /// version before it) computed on the server for versions too big for the
  /// client (Sheets 10 §5.2 step 4), with the author of every changed cell.
  /// Cached as `<versionId>.diff.gz`; returns its signed URL (gzip JSON
  /// `{diff: SnapshotDiff JSON, a: [author user ids, 0 = unknown]}`).
  Future<FileUrlView> diff(
    Session session,
    UuidValue itemUuid,
    int versionId,
    int? previousVersionId,
  ) async {
    final actor = await UserService.actorOf(session);
    final (item, version) = await VersionService.requireVersion(
      session,
      actor,
      itemUuid,
      versionId,
      min: Role.editor,
    );
    final (from, to) = await SheetsVersionChanges.windowOf(session, version);
    final previous = previousVersionId == null
        ? await ItemVersion.db.findFirstRow(
            session,
            where: (t) => t.itemId.equals(item.id!) & (t.id < version.id!),
            orderBy: (t) => t.id.desc(),
          )
        : (await VersionService.requireVersion(
            session,
            actor,
            itemUuid,
            previousVersionId,
            min: Role.editor,
          )).$2;
    final immediate =
        previous == null || previous.createdAt == from || from == null;
    final index = await SheetsSnapshotIndex.db.findFirstRow(
      session,
      where: (t) => t.itemVersionId.equals(version.id!),
    );
    if (immediate && index?.diffFileId != null) {
      final cached = await FileService.byUuid(session, index!.diffFileId!);
      if (cached != null) {
        return FileService.getUrl(session, actor, cached.fileUuid);
      }
    }
    final current = await _snapshot(session, version);
    final before = previous == null
        ? const <String, Map<String, Map<String, dynamic>>>{}
        : await _snapshot(session, previous);
    final (ranges, _) = await SheetsVersionChanges.rangesBetween(
      session,
      item.contentRef!,
      from: previous?.createdAt,
      to: to,
    );
    final bytes = SheetsVersionChanges.gzipJson(
      SheetsVersionChanges.attributedDiff(before, current, ranges),
    );
    final file = await FileService.storeServerFile(
      session,
      ownerId: item.ownerId,
      itemId: item.id,
      kind: StoredFileKind.snapshot,
      fileName: '${version.id}.diff.gz',
      mimeType: 'application/gzip',
      bytes: bytes,
    );
    if (immediate && index != null) {
      await SheetsSnapshotIndex.db.updateRow(
        session,
        index.copyWith(diffFileId: file.fileUuid),
      );
    }
    return FileService.getUrl(session, actor, file.fileUuid);
  }

  static Future<Map<String, Map<String, Map<String, dynamic>>>> _snapshot(
    Session session,
    ItemVersion version,
  ) async {
    final id = version.snapshotFileId;
    if (id == null) throw Errors.invalid('The version has no snapshot.');
    final file = await FileService.byUuid(session, id);
    if (file == null) throw Errors.expired('The snapshot is no longer stored.');
    final data = await FileService.readBytes(session, file);
    return SheetsVersionProvider.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  /// The *Copy comments* / *Share with the same people* options of a copy
  /// made on the client from a version (Sheets 10 §5.4): copies the
  /// comment threads of [sourceItemUuid] to [targetItemUuid] with anchors
  /// remapped through [anchorIdMapJson] (`{oldId: newId}`), and the source's
  /// sharing. The caller must own the target and be able to copy the source.
  Future<void> copyExtras(
    Session session,
    UuidValue sourceItemUuid,
    UuidValue targetItemUuid,
    String anchorIdMapJson,
    bool copyComments,
    bool copySharing,
  ) async {
    final actor = await UserService.actorOf(session);
    final (source, role) = await AccessService.require(
      session,
      actor,
      sourceItemUuid,
      Role.viewer,
    );
    if (role < Role.editor && !source.nonEditorsCanExport) {
      throw Errors.forbidden('The owner has disabled copying for viewers.');
    }
    final (target, targetRole) = await AccessService.require(
      session,
      actor,
      targetItemUuid,
      Role.owner,
    );
    if (targetRole != Role.owner || target.kind != source.kind) {
      throw Errors.forbidden('Only the owner of the copy can do this.');
    }
    Map<String, String> idMap;
    try {
      idMap = (jsonDecode(anchorIdMapJson) as Map).map(
        (k, v) => MapEntry('$k', '$v'),
      );
    } on Object {
      throw Errors.invalid('anchorIdMapJson must be a JSON object.');
    }
    if (copyComments) {
      await session.db.transaction(
        (tx) => CommentCopier.copyThreads(
          session,
          from: source,
          to: target,
          anchorIdMap: idMap,
          transaction: tx,
        ),
      );
    }
    if (copySharing) {
      await DriveService.copyGrants(session, actor, source, target);
    }
  }
}
