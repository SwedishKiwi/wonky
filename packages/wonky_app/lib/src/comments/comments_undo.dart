import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../shell/shell_services.dart';
import 'comment_anchor.dart';

/// Comment operations recorded on the document stack (suite 08 §3.3
/// `comments`): undo of a create deletes, undo of a delete re-creates (as a
/// new comment), resolve ⇄ reopen.
enum CommentUndoOp { createThread, reply, resolve, reopen, deleteThread, deleteComment, edit }

class CommentUndoEntry extends UndoEntry {
  const CommentUndoEntry({
    required this.op,
    required this.threadUuid,
    this.commentId,
    this.body,
    this.previousBody,
    this.anchorKind,
    this.anchorJson,
    this.quotedText,
  });

  final CommentUndoOp op;
  final String threadUuid;
  final int? commentId;

  /// Comment body snapshot (to re-create).
  final String? body;

  /// For [CommentUndoOp.edit]: the body before the edit.
  final String? previousBody;
  final CommentAnchorKind? anchorKind;
  final String? anchorJson;
  final String? quotedText;

  static const domainName = 'comments';

  @override
  String get domain => domainName;

  @override
  UndoEntry? rebase(RemoteChange change) {
    if (change is FieldRemoteChange && change.target == threadUuid && change.deleted) return null;
    return this;
  }

  CommentUndoEntry copyWith({String? threadUuid, int? commentId}) => CommentUndoEntry(
    op: op,
    threadUuid: threadUuid ?? this.threadUuid,
    commentId: commentId ?? this.commentId,
    body: body,
    previousBody: previousBody,
    anchorKind: anchorKind,
    anchorJson: anchorJson,
    quotedText: quotedText,
  );
}

/// Applies [CommentUndoEntry]s through the open file's comments controller.
class CommentsUndoHandler extends UndoHandler<CommentUndoEntry> {
  CommentsUndoHandler(this.services);

  final ShellServices services;

  @override
  String get domain => CommentUndoEntry.domainName;

  @override
  Future<CommentUndoEntry> undo(CommentUndoEntry e) => _apply(e, undo: true);

  @override
  Future<CommentUndoEntry> redo(CommentUndoEntry e) => _apply(e, undo: false);

  Future<CommentUndoEntry> _apply(CommentUndoEntry e, {required bool undo}) async {
    final c = services.comments.value;
    if (c == null) throw const UndoConflict('Comments are not open');
    try {
      switch ((e.op, undo)) {
        case (CommentUndoOp.createThread, true) || (CommentUndoOp.deleteThread, false):
          await c.deleteThread(e.threadUuid);
          return e;
        case (CommentUndoOp.createThread, false) || (CommentUndoOp.deleteThread, true):
          final t = await c.createThread(
            anchor: NewCommentAnchor(
              kind: e.anchorKind ?? CommentAnchorKind.document,
              anchorJson: e.anchorJson ?? '{}',
              quotedText: e.quotedText,
            ),
            body: e.body ?? '',
          );
          return e.copyWith(threadUuid: t.uuid.uuid);
        case (CommentUndoOp.reply, true) || (CommentUndoOp.deleteComment, false):
          if (e.commentId != null) await c.deleteComment(e.commentId!);
          return e;
        case (CommentUndoOp.reply, false) || (CommentUndoOp.deleteComment, true):
          final t = await c.reply(e.threadUuid, e.body ?? '');
          final last = t.comments.isEmpty ? null : t.comments.last;
          return e.copyWith(commentId: last?.id);
        case (CommentUndoOp.resolve, true) || (CommentUndoOp.reopen, false):
          await c.reopen(e.threadUuid);
          return e;
        case (CommentUndoOp.resolve, false) || (CommentUndoOp.reopen, true):
          await c.resolve(e.threadUuid);
          return e;
        case (CommentUndoOp.edit, _):
          await c.edit(e.commentId!, (undo ? e.previousBody : e.body) ?? '');
          return e;
      }
    } on WonkyException catch (err) {
      if (err.code == WonkyErrorCode.notFound) throw const UndoConflict('Comment deleted');
      rethrow;
    }
  }
}
