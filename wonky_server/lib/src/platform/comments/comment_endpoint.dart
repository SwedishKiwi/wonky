import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import '../users/user_service.dart';
import 'comment_service.dart';

/// Comment threads (specs/07 §2.2).
class CommentEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<List<CommentThreadView>> listThreads(
    Session session,
    UuidValue itemUuid,
    CommentFilter filter,
  ) async => CommentService.listThreads(
    session,
    await UserService.actorOf(session),
    itemUuid,
    filter: filter,
  );

  Future<CommentThreadView> getThread(Session session, UuidValue threadUuid) async =>
      CommentService.getThread(session, await UserService.actorOf(session), threadUuid);

  /// Creates a thread; idempotent on the client-generated [threadUuid].
  Future<CommentThreadView> createThread(
    Session session,
    UuidValue threadUuid,
    UuidValue itemUuid,
    CommentAnchorKind anchorKind,
    String anchorJson,
    String? quotedText,
    String body,
    List<int> mentions,
    int? assigneeId,
  ) async => CommentService.createThread(
    session,
    await UserService.actorOf(session),
    threadUuid: threadUuid,
    itemUuid: itemUuid,
    anchorKind: anchorKind,
    anchorJson: anchorJson,
    quotedText: quotedText,
    body: body,
    mentions: mentions,
    assigneeId: assigneeId,
  );

  /// Replies; idempotent on the optional client-generated [commentUuid].
  Future<CommentThreadView> reply(
    Session session,
    UuidValue threadUuid,
    String body,
    List<int> mentions, {
    UuidValue? commentUuid,
    int? assigneeId,
  }) async => CommentService.reply(
    session,
    await UserService.actorOf(session),
    threadUuid,
    body: body,
    mentions: mentions,
    commentUuid: commentUuid,
    assigneeId: assigneeId,
  );

  Future<CommentView> edit(
    Session session,
    int commentId,
    String body, {
    List<int>? mentions,
  }) async => CommentService.edit(
    session,
    await UserService.actorOf(session),
    commentId,
    body,
    mentions: mentions,
  );

  Future<void> delete(Session session, int commentId) async =>
      CommentService.delete(session, await UserService.actorOf(session), commentId);

  Future<void> deleteThread(Session session, UuidValue threadUuid) async =>
      CommentService.deleteThread(
        session,
        await UserService.actorOf(session),
        threadUuid,
      );

  Future<CommentThreadView> resolve(Session session, UuidValue threadUuid) async =>
      CommentService.resolve(session, await UserService.actorOf(session), threadUuid);

  Future<CommentThreadView> reopen(Session session, UuidValue threadUuid) async =>
      CommentService.reopen(session, await UserService.actorOf(session), threadUuid);

  /// Toggles the caller's reaction.
  Future<CommentView> react(Session session, int commentId, String emoji) async =>
      CommentService.react(
        session,
        await UserService.actorOf(session),
        commentId,
        emoji,
      );

  Future<CommentThreadView> updateAnchor(
    Session session,
    UuidValue threadUuid,
    String anchorJson, {
    CommentAnchorKind? anchorKind,
  }) async => CommentService.updateAnchor(
    session,
    await UserService.actorOf(session),
    threadUuid,
    anchorJson,
    anchorKind: anchorKind,
  );

  /// Live comment changes on an item.
  Stream<CommentEvent> watch(Session session, UuidValue itemUuid) async* {
    final actor = await UserService.actorOf(session);
    yield* CommentService.watch(session, actor, itemUuid);
  }
}
