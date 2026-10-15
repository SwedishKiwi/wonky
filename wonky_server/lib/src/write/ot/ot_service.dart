import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_write_core/wonky_write_core.dart';

import '../../platform/activity/activity_service.dart';
import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/config/wonky_config.dart';
import '../../platform/drive/drive_service.dart';
import '../../platform/versions/version_service.dart';
import '../collab/overlay_lifecycle.dart';
import 'document_bus.dart';
import 'document_cache.dart';
import 'document_store.dart';
import '../../platform/storage/content_sizes.dart';

/// Thrown by [OtService.submit] when an op is rejected (sent to the client
/// as `DocOpRejected`).
class OpRejection implements Exception {
  OpRejection(this.code, this.message);
  final DocRejectCode code;
  final String message;

  @override
  String toString() => 'OpRejection(${code.name}: $message)';
}

/// Result of a committed (or idempotently re-acknowledged) op.
class CommittedOp {
  CommittedOp(this.revision, this.delta, {this.duplicate = false});
  final int revision;
  final Delta delta;
  final bool duplicate;
}

/// Server-authoritative OT (Write 03 §2).
abstract final class OtService {
  static const modifiedThrottle = Duration(seconds: 10);
  static const searchTextThrottle = Duration(seconds: 30);
  static const statsEvery = 50;

  /// Applies a client op based on [baseRevision].
  ///
  /// 1. idempotency on [clientOpId]; 2. role / op shape; 3. row lock;
  /// 4. transform against ops since the base (server ops win ties);
  /// 5. normalize + validate; 6. persist op, inverse and head; 7. fan-out.
  static Future<CommittedOp> submit(
    Session session, {
    required Actor actor,
    required Document document,
    required DriveItem item,
    required Role role,
    required UuidValue clientOpId,
    required int baseRevision,
    required String deltaJson,
    DocumentOpKind kind = DocumentOpKind.content,
    String? sessionId,
    String? groupId,
    String? onBehalfOfSessionId,
  }) async {
    final duplicate = await DocumentOp.db.findFirstRow(
      session,
      where: (t) =>
          t.documentId.equals(document.id!) & t.clientOpId.equals(clientOpId),
    );
    if (duplicate != null) {
      return CommittedOp(
        duplicate.revision,
        DocumentStore.decodeDelta(duplicate.deltaJson),
        duplicate: true,
      );
    }
    if (role < Role.commenter) {
      throw OpRejection(
        DocRejectCode.forbiddenForRole,
        'Viewers cannot edit this document.',
      );
    }
    Delta incoming;
    try {
      incoming = DocumentStore.decodeDelta(deltaJson);
    } on Object {
      throw OpRejection(
        DocRejectCode.invalidOp,
        'The op is not a valid delta.',
      );
    }
    if (incoming.toList().any(
      (o) => (o.length ?? 0) <= 0 && !(o.isInsert && o.data is Map),
    )) {
      throw OpRejection(
        DocRejectCode.invalidOp,
        'Empty operations are invalid.',
      );
    }

    final state = await DocumentCache.of(session, document);
    return state.lock(() async {
      final now = nowUtc();
      late Delta finalOp;
      late Delta before;
      late Delta after;
      late Delta inverse;
      late int revision;
      await session.db.transaction((tx) async {
        final locked = await Document.db.findById(
          session,
          document.id!,
          transaction: tx,
          lockMode: LockMode.forUpdate,
        );
        if (locked == null) {
          throw OpRejection(
            DocRejectCode.invalidOp,
            'The document was deleted.',
          );
        }
        await state.catchUp(session, locked.headRevision, transaction: tx);
        final head = locked.headRevision;
        if (baseRevision > head) {
          throw OpRejection(
            DocRejectCode.unknownBase,
            'Revision $baseRevision does not exist yet.',
          );
        }
        var transformed = incoming;
        if (baseRevision < head) {
          var since = state.opsSince(baseRevision);
          if (since == null) {
            final ops = await DocumentOp.db.find(
              session,
              where: (t) =>
                  t.documentId.equals(document.id!) &
                  (t.revision > baseRevision) &
                  (t.revision <= head),
              orderBy: (t) => t.revision,
              transaction: tx,
            );
            if (ops.length != head - baseRevision) {
              throw OpRejection(
                DocRejectCode.rebaseTooOld,
                'The change is based on a revision that is no longer kept.',
              );
            }
            since = [
              for (final o in ops) DocumentStore.decodeDelta(o.deltaJson),
            ];
          }
          transformed = WonkyOt.rebaseOnServer(incoming, since);
        }
        before = state.content;
        if (DeltaUtils.baseLength(transformed) >
            DeltaUtils.documentLength(before)) {
          throw OpRejection(
            DocRejectCode.invalidOp,
            'The change does not fit the document.',
          );
        }
        if (role < Role.editor) {
          final violation = OpShapeValidator.validateCommenterOp(
            before,
            transformed,
            actor.authUserId.uuid,
          );
          if (violation != null) {
            throw OpRejection(
              DocRejectCode.forbiddenForRole,
              'Commenters can only comment and suggest: ${violation.message}',
            );
          }
        }
        final NormalizeChangeResult normalized;
        try {
          normalized = const WonkyDeltaNormalizer().normalizeChange(
            before,
            transformed,
            suggestionTimestamp: now.millisecondsSinceEpoch,
          );
        } on Object catch (e) {
          throw OpRejection(
            DocRejectCode.invalidOp,
            'The change is invalid: $e',
          );
        }
        after = normalized.document;
        final validation = WonkyDeltaValidator(
          maxDocumentChars: WonkyConfig.current.maxDocumentChars,
        ).validate(after);
        if (!validation.isValid) {
          final tooLong =
              DeltaUtils.documentLength(after) >
              WonkyConfig.current.maxDocumentChars;
          throw OpRejection(
            tooLong ? DocRejectCode.tooLarge : DocRejectCode.invalidOp,
            tooLong
                ? 'The document would exceed the maximum length.'
                : 'The result is not a valid document: $validation',
          );
        }
        finalOp = normalized.change;
        revision = head + 1;
        inverse = WonkyOt.invert(finalOp, before);
        await DocumentOp.db.insertRow(
          session,
          DocumentOp(
            documentId: document.id!,
            revision: revision,
            clientOpId: clientOpId,
            authorId: actor.userId,
            actorKind: actor.kind,
            sessionId: sessionId,
            kind: kind,
            baseRevision: baseRevision,
            deltaJson: jsonEncode(finalOp.toJson()),
            inverseJson: jsonEncode(inverse.toJson()),
            createdAt: now,
          ),
          transaction: tx,
        );
        final text = revision % statsEvery == 0 ? DeltaUtils.text(after) : null;
        await Document.db.updateWhere(
          session,
          columnValues: (t) => [
            t.headRevision(revision),
            t.updatedAt(now),
            if (text != null) t.charCount(text.length),
            if (text != null) t.wordCount(DocumentStore.wordCount(text)),
          ],
          where: (t) => t.id.equals(document.id!),
          transaction: tx,
        );
      });

      // Committed: update the in-memory state.
      final transitions = state.overlays.apply(finalOp, inverse);
      state.content = after;
      state.revision = revision;
      state.remember(revision, finalOp);

      await DocumentBus.post(
        session,
        document.uuid,
        DocBusMessage(
          type: 'op',
          originSessionId: sessionId,
          op: DocRemoteOp(
            revision: revision,
            deltaJson: jsonEncode(finalOp.toJson()),
            authorId: actor.userId,
            authorUuid: actor.authUserId,
            authorSessionId: sessionId,
            actorKind: actor.kind,
            kind: kind,
            onBehalfOfSessionId: onBehalfOfSessionId,
            groupId: groupId,
          ),
        ),
      );
      await _afterCommit(
        session,
        state,
        document,
        item,
        actor,
        before: before,
        op: finalOp,
        after: after,
        revision: revision,
        transitions: transitions,
      );
      return CommittedOp(revision, finalOp);
    });
  }

  static Future<void> _afterCommit(
    Session session,
    DocumentState state,
    Document document,
    DriveItem item,
    Actor actor, {
    required Delta before,
    required Delta op,
    required Delta after,
    required int revision,
    required List<OverlayTransition> transitions,
  }) async {
    final now = nowUtc();
    try {
      if (revision % WonkyConfig.current.snapshotEveryNOps == 0) {
        await DocumentStore.writeSnapshot(session, document, revision, after);
      }
      var inserted = 0;
      var deleted = 0;
      for (final o in op.toList()) {
        if (o.isInsert) inserted += o.length!;
        if (o.isDelete) deleted += o.length!;
      }
      final lastEdit = state.lastUserEdit[actor.userId];
      if (lastEdit == null ||
          now.difference(lastEdit) > const Duration(minutes: 1)) {
        state.lastUserEdit[actor.userId] = now;
        await DriveService.recordEdit(session, actor.userId, item);
      }
      await ActivityService.logEdit(
        session,
        item.id!,
        actor,
        counters: {'insertedChars': inserted, 'deletedChars': deleted},
      );
      await VersionService.recordEdit(
        session,
        item,
        actor.userId,
        revision: revision,
      );
      if (now.difference(state.lastModifiedTouch) > modifiedThrottle) {
        state.lastModifiedTouch = now;
        final updateSearch =
            now.difference(state.lastSearchTextUpdate) > searchTextThrottle;
        if (updateSearch) state.lastSearchTextUpdate = now;
        await DriveService.touchModified(
          session,
          item,
          actor.userId,
          searchText: updateSearch ? DocumentStore.searchText(after) : null,
          sizeBytes: updateSearch ? DocumentSize.of(after) : null,
        );
      }
      await OverlayLifecycle.handle(
        session,
        item: item,
        documentUuid: document.uuid,
        actor: actor,
        before: before,
        op: op,
        transitions: transitions,
      );
    } on Exception catch (e, st) {
      session.log(
        'Post-commit work for ${document.uuid} r$revision failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
    }
  }

  /// Transforms a selection given at [revision] to the head of [state].
  static (int, int) transformCursor(
    DocumentState state,
    int revision,
    int anchor,
    int head,
  ) {
    final ops = state.opsSince(revision);
    if (ops == null) return (anchor, head);
    var a = anchor;
    var h = head;
    for (final op in ops) {
      a = WonkyOt.transformPosition(op, a);
      h = WonkyOt.transformPosition(op, h);
    }
    final length = DeltaUtils.documentLength(state.content);
    return (a.clamp(0, length - 1), h.clamp(0, length - 1));
  }

  /// Submits a server-computed change on behalf of [actor] (restores, MCP,
  /// AI), based on the current head.
  static Future<CommittedOp> submitServerChange(
    Session session, {
    required Actor actor,
    required Document document,
    required DriveItem item,
    required Delta Function(Delta head) build,
    DocumentOpKind kind = DocumentOpKind.content,
    String? groupId,
    String? onBehalfOfSessionId,
  }) async {
    final state = await DocumentCache.of(session, document);
    final fresh = await Document.db.findById(session, document.id!);
    await state.lock(() => state.catchUp(session, fresh!.headRevision));
    final head = state.content;
    final change = build(head);
    return submit(
      session,
      actor: actor,
      document: document,
      item: item,
      role: Role.owner,
      clientOpId: const Uuid().v7obj(),
      baseRevision: state.revision,
      deltaJson: jsonEncode(change.toJson()),
      kind: kind,
      sessionId: actor.sessionId,
      groupId: groupId,
      onBehalfOfSessionId: onBehalfOfSessionId,
    );
  }
}
