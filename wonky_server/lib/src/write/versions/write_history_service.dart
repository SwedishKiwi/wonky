import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_write_core/wonky_write_core.dart';

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/drive/drive_service.dart';
import '../../platform/users/user_service.dart';
import '../../platform/versions/version_service.dart';
import '../ot/document_service.dart';
import '../ot/document_store.dart';
import '../../platform/storage/storage_service.dart';

/// Write version history (Write 08 §4.3).
abstract final class WriteHistoryService {
  /// Attributed replay is used up to this many ops.
  static const maxReplayOps = 20000;
  static const diffCacheRetention = Duration(days: 7);

  static Future<WriteVersionDocument> getVersionDocument(
    Session session,
    Actor actor,
    UuidValue documentUuid,
    int revision,
  ) async {
    final (doc, _, _) = await DocumentService.require(
      session,
      actor,
      documentUuid,
      min: Role.editor,
    );
    final content = await DocumentStore.contentAt(session, doc, revision);
    return WriteVersionDocument(
      revision: revision,
      deltaJson: jsonEncode(DeltaUtils.stripOverlays(content).toJson()),
    );
  }

  static Future<WriteDiffView> diff(
    Session session,
    Actor actor,
    UuidValue documentUuid,
    int fromRevision,
    int toRevision,
  ) async {
    final (doc, _, _) = await DocumentService.require(
      session,
      actor,
      documentUuid,
      min: Role.editor,
    );
    var a = fromRevision;
    var b = toRevision;
    if (a > b) (a, b) = (b, a);
    if (a < 0 || b > doc.headRevision) {
      throw Errors.invalid('The revisions are out of range.');
    }
    final cached = await WriteDiffCache.db.findFirstRow(
      session,
      where: (t) =>
          t.documentId.equals(doc.id!) &
          t.fromRevision.equals(a) &
          t.toRevision.equals(b),
    );
    if (cached != null) {
      return WriteDiffView.fromJson(
        (jsonDecode(cached.json) as Map).cast<String, dynamic>(),
      );
    }
    final docA = await DocumentStore.contentAt(session, doc, a);
    final ops = await DocumentOp.db.find(
      session,
      where: (t) =>
          t.documentId.equals(doc.id!) & (t.revision > a) & (t.revision <= b),
      orderBy: (t) => t.revision,
    );
    final users = await UserService.summaries(session, [
      for (final o in ops) o.authorId,
    ]);
    final WriteDiff result;
    if (ops.length == b - a && ops.length <= maxReplayOps) {
      result = AttributedDiff.diff(docA, [
        for (final o in ops)
          AuthoredOp(
            DocumentStore.decodeDelta(o.deltaJson),
            authorUuid: users[o.authorId]?.uuid.uuid,
            actorKind: o.actorKind.name,
          ),
      ]);
    } else {
      final docB = await DocumentStore.contentAt(session, doc, b);
      result = AttributedDiff.diffSnapshots(docA, docB);
    }
    final byUuid = {for (final u in users.values) u.uuid.uuid: u};
    final view = WriteDiffView(
      fromRevision: a,
      toRevision: b,
      exact: result.exact,
      deltaJson: jsonEncode(result.delta.toJson()),
      authors: [
        for (final s in result.authors)
          WriteDiffAuthor(
            userUuid: s.userUuid == null ? null : byUuid[s.userUuid]?.uuid,
            name: byUuid[s.userUuid]?.displayName ?? 'Multiple people',
            colorIndex: byUuid[s.userUuid]?.colorIndex ?? 0,
            actorKind: ActorKind.values.firstWhere(
              (k) => k.name == s.actorKind,
              orElse: () => ActorKind.user,
            ),
            inserted: s.inserted,
            deleted: s.deleted,
            formatted: s.formatted,
          ),
      ],
      changeCount: result.changeCount,
    );
    try {
      await WriteDiffCache.db.insertRow(
        session,
        WriteDiffCache(
          documentId: doc.id!,
          fromRevision: a,
          toRevision: b,
          json: jsonEncode(view.toJson()),
          createdAt: nowUtc(),
        ),
      );
    } on DatabaseException {
      // Computed concurrently.
    }
    return view;
  }

  static Future<ItemVersionView> createRestorePoint(
    Session session,
    Actor actor,
    UuidValue documentUuid,
  ) async {
    final (_, item, _) = await DocumentService.require(
      session,
      actor,
      documentUuid,
      min: Role.editor,
    );
    final version = await VersionService.capture(
      session,
      item,
      kind: VersionKind.restorePoint,
      name: 'Restore point',
      createdById: actor.userId,
    );
    return (await VersionService.viewsOf(session, item, [version])).single;
  }

  static Future<VersionRestoreResult> restore(
    Session session,
    Actor actor,
    UuidValue documentUuid,
    int versionId,
  ) async {
    final (_, item, _) = await DocumentService.require(
      session,
      actor,
      documentUuid,
      min: Role.editor,
    );
    return VersionService.restore(session, actor, item.uuid, versionId);
  }

  /// A new document from a version (overlays stripped).
  static Future<DriveItemView> copyVersion(
    Session session,
    Actor actor,
    UuidValue documentUuid,
    int versionId,
    String name, {
    UuidValue? parentUuid,
  }) async {
    final (doc, item, _) = await DocumentService.require(
      session,
      actor,
      documentUuid,
      min: Role.editor,
    );
    final version = await ItemVersion.db.findById(session, versionId);
    if (version == null ||
        version.itemId != item.id ||
        version.revision == null) {
      throw Errors.notFound('Version');
    }
    final content = DeltaUtils.stripOverlays(
      await DocumentStore.contentAt(session, doc, version.revision!),
    );
    return DriveService.createDocumentFromContent(
      session,
      actor,
      name: name,
      parentUuid: parentUuid,
      content: content,
      source: doc,
      quotaReason: QuotaReason.restoreVersionCopy,
    );
  }

  static Future<int> purgeDiffCache(Session session, {DateTime? now}) async {
    final cutoff = (now ?? nowUtc()).subtract(diffCacheRetention);
    final deleted = await WriteDiffCache.db.deleteWhere(
      session,
      where: (t) => t.createdAt < cutoff,
    );
    return deleted.length;
  }
}
