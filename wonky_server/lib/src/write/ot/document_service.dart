import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_write_core/wonky_write_core.dart';

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/drive/drive_views.dart';
import '../../platform/sharing/access_service.dart';
import '../../platform/users/user_service.dart';
import '../themes/theme_service.dart';
import 'document_bus.dart';
import 'document_store.dart';

/// Non-streaming document operations (Write 03 §1, §6).
abstract final class DocumentService {
  static const metaFields = {'themeId', 'pageSetup', 'language', 'frontMatter'};
  static const maxOpsPerRequest = 1000;
  static const opRetention = Duration(days: 30);

  static Future<(Document, DriveItem, Role)> require(
    Session session,
    Actor actor,
    UuidValue documentUuid, {
    Role min = Role.viewer,
  }) async {
    final doc = await DocumentStore.byUuid(session, documentUuid);
    if (doc == null) throw Errors.notFound('Document');
    final item = await DriveItem.db.findById(session, doc.itemId);
    if (item == null) throw Errors.notFound('Document');
    final role = await AccessService.requireRole(session, actor, item, min);
    return (doc, item, role);
  }

  static Future<DocumentInfo> getInfo(
    Session session,
    Actor actor,
    UuidValue documentUuid,
  ) async {
    final (doc, item, role) = await require(session, actor, documentUuid);
    final report = await DocumentImportReport.db.findFirstRow(
      session,
      where: (t) =>
          t.documentId.equals(doc.id!) &
          t.userId.equals(actor.userId) &
          t.seenAt.equals(null),
    );
    List<ImportWarningView>? warnings;
    if (report != null) {
      warnings = [
        for (final w in jsonDecode(report.warningsJson) as List<dynamic>)
          ImportWarningView.fromJson((w as Map).cast<String, dynamic>()),
      ];
      await DocumentImportReport.db.updateRow(
        session,
        report.copyWith(seenAt: nowUtc()),
      );
    }
    return DocumentInfo(
      documentUuid: doc.uuid,
      item: await DriveViews.one(session, actor.userId, item, role: role),
      headRevision: doc.headRevision,
      meta: DocumentMetaView(
        themeId: doc.themeId,
        pageSetupJson: doc.pageSetupJson,
        language: doc.language,
        frontMatter: doc.frontMatter,
      ),
      charCount: doc.charCount,
      wordCount: doc.wordCount,
      createdAt: doc.createdAt,
      updatedAt: doc.updatedAt,
      importWarnings: warnings,
    );
  }

  static Future<List<DocumentOpView>> getOps(
    Session session,
    Actor actor,
    UuidValue documentUuid,
    int fromRevision,
    int toRevision,
  ) async {
    final (doc, _, _) = await require(session, actor, documentUuid);
    if (toRevision < fromRevision) return const [];
    final to = toRevision.clamp(0, fromRevision + maxOpsPerRequest - 1);
    final ops = await DocumentOp.db.find(
      session,
      where: (t) =>
          t.documentId.equals(doc.id!) &
          (t.revision >= fromRevision) &
          (t.revision <= to),
      orderBy: (t) => t.revision,
    );
    final users = await UserService.summaries(session, [
      for (final o in ops) o.authorId,
    ]);
    return [
      for (final o in ops)
        DocumentOpView(
          revision: o.revision,
          deltaJson: o.deltaJson,
          clientOpId: o.clientOpId,
          authorId: o.authorId,
          authorUuid: users[o.authorId]?.uuid,
          actorKind: o.actorKind,
          kind: o.kind,
          sessionId: o.sessionId,
          createdAt: o.createdAt,
        ),
    ];
  }

  /// The content at [revision] (head when null). Older revisions require
  /// Editor+ (history).
  static Future<DocumentSnapshotView> getSnapshot(
    Session session,
    Actor actor,
    UuidValue documentUuid,
    int? revision,
  ) async {
    final (doc, _, role) = await require(session, actor, documentUuid);
    final rev = revision ?? doc.headRevision;
    if (rev != doc.headRevision && role < Role.editor) {
      throw Errors.forbidden('Viewing history requires edit access.');
    }
    final content = await DocumentStore.contentAt(session, doc, rev);
    return DocumentSnapshotView(
      revision: rev,
      deltaJson: jsonEncode(content.toJson()),
    );
  }

  /// LWW metadata change (Write 03 §6); idempotent on [clientOpId].
  static Future<void> updateMeta(
    Session session,
    Actor actor,
    UuidValue documentUuid,
    DocumentMetaPatch patch,
    UuidValue clientOpId,
  ) async {
    final (doc, _, _) = await require(
      session,
      actor,
      documentUuid,
      min: Role.editor,
    );
    if (!metaFields.contains(patch.field)) {
      throw Errors.invalid('Unknown document property "${patch.field}".');
    }
    final duplicate = await DocumentMetaChange.db.findFirstRow(
      session,
      where: (t) =>
          t.documentId.equals(doc.id!) & t.clientOpId.equals(clientOpId),
    );
    if (duplicate != null) return;
    final Object? value;
    try {
      value = jsonDecode(patch.valueJson);
    } on FormatException {
      throw Errors.invalid('The value is not valid JSON.');
    }
    late Document updated;
    late String beforeJson;
    late String afterJson;
    switch (patch.field) {
      case 'themeId':
        UuidValue? themeId;
        if (value != null) {
          if (value is! String) throw Errors.invalid('themeId must be a UUID.');
          themeId = UuidValue.withValidation(value);
          final theme = await ThemeService.requireAssignable(
            session,
            actor,
            themeId,
            doc,
          );
          afterJson = jsonEncode({
            'themeId': themeId.uuid,
            'version': theme.version,
            'hash': theme.contentHash,
          });
        } else {
          afterJson = jsonEncode({'themeId': null});
        }
        beforeJson = jsonEncode({'themeId': doc.themeId?.uuid});
        updated = _withMeta(doc, themeId: themeId, clearTheme: themeId == null);
      case 'pageSetup':
        if (value is! Map) throw Errors.invalid('pageSetup must be an object.');
        beforeJson = doc.pageSetupJson;
        afterJson = canonicalJsonEncode(value);
        updated = doc.copyWith(pageSetupJson: afterJson);
      case 'language':
        if (value != null &&
            (value is! String ||
                !RegExp(
                  r'^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$',
                ).hasMatch(value))) {
          throw Errors.invalid('language must be a BCP-47 tag.');
        }
        beforeJson = jsonEncode(doc.language);
        afterJson = jsonEncode(value);
        updated = _withMeta(
          doc,
          language: value as String?,
          clearLanguage: value == null,
        );
      case 'frontMatter':
        if (value != null && value is! String) {
          throw Errors.invalid('frontMatter must be a string.');
        }
        if (value is String && value.length > 64 * 1024) {
          throw Errors.tooLarge('The front matter is too long.');
        }
        beforeJson = jsonEncode(doc.frontMatter);
        afterJson = jsonEncode(value);
        updated = _withMeta(
          doc,
          frontMatter: value as String?,
          clearFrontMatter: value == null,
        );
    }
    await session.db.transaction((tx) async {
      await Document.db.updateRow(
        session,
        updated.copyWith(updatedAt: nowUtc()),
        transaction: tx,
      );
      await DocumentMetaChange.db.insertRow(
        session,
        DocumentMetaChange(
          documentId: doc.id!,
          field: patch.field,
          clientOpId: clientOpId,
          beforeJson: beforeJson,
          afterJson: afterJson,
          authorId: actor.userId,
          actorKind: actor.kind,
          createdAt: nowUtc(),
        ),
        transaction: tx,
      );
    });
    await DocumentBus.metaChanged(
      session,
      doc.uuid,
      DocMetaChanged(
        field: patch.field,
        valueJson: patch.valueJson,
        authorId: actor.userId,
      ),
    );
  }

  static Document _withMeta(
    Document d, {
    UuidValue? themeId,
    bool clearTheme = false,
    String? language,
    bool clearLanguage = false,
    String? frontMatter,
    bool clearFrontMatter = false,
  }) => Document(
    id: d.id,
    uuid: d.uuid,
    itemId: d.itemId,
    headRevision: d.headRevision,
    latestSnapshotRevision: d.latestSnapshotRevision,
    themeId: clearTheme ? null : (themeId ?? d.themeId),
    pageSetupJson: d.pageSetupJson,
    language: clearLanguage ? null : (language ?? d.language),
    frontMatter: clearFrontMatter ? null : (frontMatter ?? d.frontMatter),
    charCount: d.charCount,
    wordCount: d.wordCount,
    createdAt: d.createdAt,
    updatedAt: d.updatedAt,
  );

  /// Daily job: deletes ops older than [opRetention], after making sure a
  /// snapshot exists at the newest pruned revision (materialization of later
  /// revisions and versions keeps working).
  static Future<int> pruneOps(Session session, {DateTime? now}) async {
    final cutoff = (now ?? nowUtc()).subtract(opRetention);
    final rows = await session.db.unsafeQuery(
      r'''
      SELECT "documentId", max(revision) FROM document_op
      WHERE "createdAt" < @cutoff GROUP BY "documentId" LIMIT 500
      ''',
      parameters: QueryParameters.named({'cutoff': cutoff}),
    );
    var pruned = 0;
    for (final row in rows) {
      final doc = await Document.db.findById(session, row[0] as int);
      if (doc == null) continue;
      final upTo = row[1] as int;
      final content = await DocumentStore.contentAt(session, doc, upTo);
      await DocumentStore.writeSnapshot(session, doc, upTo, content);
      pruned += await DocumentOp.db
          .deleteWhere(
            session,
            where: (t) => t.documentId.equals(doc.id!) & (t.revision <= upTo),
          )
          .then((r) => r.length);
    }
    return pruned;
  }
}
