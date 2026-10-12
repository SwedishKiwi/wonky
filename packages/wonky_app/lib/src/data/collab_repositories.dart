import 'package:wonky_client/wonky_client.dart';

import 'api.dart';

/// Comments (suite 07 §2.2).
abstract class CommentRepository {
  Future<List<CommentThreadView>> listThreads(
    UuidValue itemUuid, {
    CommentFilter filter = CommentFilter.all,
  });

  /// Idempotent on the client-supplied [threadUuid].
  Future<CommentThreadView> createThread({
    required UuidValue threadUuid,
    required UuidValue itemUuid,
    required CommentAnchorKind anchorKind,
    required String anchorJson,
    String? quotedText,
    required String body,
    List<int> mentions = const [],
    int? assigneeId,
  });

  Future<CommentThreadView> reply(
    UuidValue threadUuid, {
    required String body,
    List<int> mentions = const [],
    UuidValue? commentUuid,
  });

  Future<CommentView> edit(int commentId, String body);

  Future<void> delete(int commentId);

  Future<void> deleteThread(UuidValue threadUuid);

  Future<CommentThreadView> resolve(UuidValue threadUuid);

  Future<CommentThreadView> reopen(UuidValue threadUuid);

  Future<CommentView> react(int commentId, String emoji);

  Future<CommentThreadView> updateAnchor(
    UuidValue threadUuid,
    String anchorJson,
  );

  Stream<CommentEvent> watch(UuidValue itemUuid);
}

class ServerCommentRepository implements CommentRepository {
  ServerCommentRepository(this.api);

  final Api api;

  @override
  Future<List<CommentThreadView>> listThreads(
    UuidValue itemUuid, {
    CommentFilter filter = CommentFilter.all,
  }) => api.guard((c) => c.comment.listThreads(itemUuid, filter));

  @override
  Future<CommentThreadView> createThread({
    required UuidValue threadUuid,
    required UuidValue itemUuid,
    required CommentAnchorKind anchorKind,
    required String anchorJson,
    String? quotedText,
    required String body,
    List<int> mentions = const [],
    int? assigneeId,
  }) => api.guard(
    (c) => c.comment.createThread(
      threadUuid,
      itemUuid,
      anchorKind,
      anchorJson,
      quotedText,
      body,
      mentions,
      assigneeId,
    ),
  );

  @override
  Future<CommentThreadView> reply(
    UuidValue threadUuid, {
    required String body,
    List<int> mentions = const [],
    UuidValue? commentUuid,
  }) => api.guard(
    (c) =>
        c.comment.reply(threadUuid, body, mentions, commentUuid: commentUuid),
  );

  @override
  Future<CommentView> edit(int commentId, String body) =>
      api.guard((c) => c.comment.edit(commentId, body));

  @override
  Future<void> delete(int commentId) =>
      api.guard((c) => c.comment.delete(commentId));

  @override
  Future<void> deleteThread(UuidValue threadUuid) =>
      api.guard((c) => c.comment.deleteThread(threadUuid));

  @override
  Future<CommentThreadView> resolve(UuidValue threadUuid) =>
      api.guard((c) => c.comment.resolve(threadUuid));

  @override
  Future<CommentThreadView> reopen(UuidValue threadUuid) =>
      api.guard((c) => c.comment.reopen(threadUuid));

  @override
  Future<CommentView> react(int commentId, String emoji) =>
      api.guard((c) => c.comment.react(commentId, emoji));

  @override
  Future<CommentThreadView> updateAnchor(
    UuidValue threadUuid,
    String anchorJson,
  ) => api.guard((c) => c.comment.updateAnchor(threadUuid, anchorJson));

  @override
  Stream<CommentEvent> watch(UuidValue itemUuid) =>
      api.client.comment.watch(itemUuid);
}

/// In-app notifications (suite 07 §4).
abstract class NotificationRepository {
  Future<NotificationPage> list({
    String? cursor,
    int limit = 30,
    bool unreadOnly = false,
  });

  Future<void> markRead(List<int> ids);

  Future<void> markAllRead();

  Stream<NotificationEvent> watch();
}

class ServerNotificationRepository implements NotificationRepository {
  ServerNotificationRepository(this.api);

  final Api api;

  @override
  Future<NotificationPage> list({
    String? cursor,
    int limit = 30,
    bool unreadOnly = false,
  }) => api.guard((c) => c.notification.list(cursor, limit, unreadOnly));

  @override
  Future<void> markRead(List<int> ids) =>
      api.guard((c) => c.notification.markRead(ids));

  @override
  Future<void> markAllRead() => api.guard((c) => c.notification.markAllRead());

  @override
  Stream<NotificationEvent> watch() => api.client.notification.watch();
}

/// Ephemeral presence (suite 07 §1).
abstract class PresenceRepository {
  /// Joins the roster of [itemUuid]; [updates] carries this session's state.
  Stream<PresenceEvent> join(
    UuidValue itemUuid,
    Stream<PresenceUpdate> updates,
  );
}

class ServerPresenceRepository implements PresenceRepository {
  ServerPresenceRepository(this.api);

  final Api api;

  @override
  Stream<PresenceEvent> join(
    UuidValue itemUuid,
    Stream<PresenceUpdate> updates,
  ) => api.client.presence.join(itemUuid, updates);
}

/// Version history (suite 07 §5).
abstract class VersionRepository {
  Future<List<ItemVersionView>> list(
    UuidValue itemUuid, {
    bool namedOnly = false,
  });

  Future<ItemVersionView> nameCurrent(UuidValue itemUuid, String name);

  Future<ItemVersionView> rename(
    UuidValue itemUuid,
    int versionId,
    String? name,
  );

  Future<VersionRestoreResult> restore(UuidValue itemUuid, int versionId);
}

class ServerVersionRepository implements VersionRepository {
  ServerVersionRepository(this.api);

  final Api api;

  @override
  Future<List<ItemVersionView>> list(
    UuidValue itemUuid, {
    bool namedOnly = false,
  }) => api.guard((c) => c.version.list(itemUuid, namedOnly));

  @override
  Future<ItemVersionView> nameCurrent(UuidValue itemUuid, String name) =>
      api.guard((c) => c.version.nameCurrent(itemUuid, name));

  @override
  Future<ItemVersionView> rename(
    UuidValue itemUuid,
    int versionId,
    String? name,
  ) => api.guard((c) => c.version.rename(itemUuid, versionId, name));

  @override
  Future<VersionRestoreResult> restore(UuidValue itemUuid, int versionId) =>
      api.guard((c) => c.version.restore(itemUuid, versionId));
}

/// Server metadata, feedback and error reports (suite 01 §7, 11 §5).
abstract class MetaRepository {
  Future<ProtocolInfo> getInfo();

  Future<void> submitFeedback(FeedbackSubmission submission);
}

class ServerMetaRepository implements MetaRepository {
  ServerMetaRepository(this.api);

  final Api api;

  @override
  Future<ProtocolInfo> getInfo() => api.guard((c) => c.meta.getInfo());

  @override
  Future<void> submitFeedback(FeedbackSubmission submission) =>
      api.guard((c) => c.feedback.submit(submission));
}
