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

  Future<CommentThreadView> updateAnchor(UuidValue threadUuid, String anchorJson);

  Stream<CommentEvent> watch(UuidValue itemUuid);
}

class ServerCommentRepository implements CommentRepository {
  ServerCommentRepository(this.api);

  final Api api;
  static const _e = 'comment';

  @override
  Future<List<CommentThreadView>> listThreads(
    UuidValue itemUuid, {
    CommentFilter filter = CommentFilter.all,
  }) => api.call<List<CommentThreadView>>(_e, 'listThreads', {
    'itemUuid': itemUuid,
    'filter': filter,
  });

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
  }) => api.call<CommentThreadView>(_e, 'createThread', {
    'threadUuid': threadUuid,
    'itemUuid': itemUuid,
    'anchorKind': anchorKind,
    'anchorJson': anchorJson,
    'quotedText': quotedText,
    'body': body,
    'mentions': mentions,
    'assigneeId': assigneeId,
  });

  @override
  Future<CommentThreadView> reply(
    UuidValue threadUuid, {
    required String body,
    List<int> mentions = const [],
    UuidValue? commentUuid,
  }) => api.call<CommentThreadView>(_e, 'reply', {
    'threadUuid': threadUuid,
    'body': body,
    'mentions': mentions,
    'commentUuid': commentUuid,
  });

  @override
  Future<CommentView> edit(int commentId, String body) =>
      api.call<CommentView>(_e, 'edit', {'commentId': commentId, 'body': body});

  @override
  Future<void> delete(int commentId) => api.call<void>(_e, 'delete', {'commentId': commentId});

  @override
  Future<void> deleteThread(UuidValue threadUuid) =>
      api.call<void>(_e, 'deleteThread', {'threadUuid': threadUuid});

  @override
  Future<CommentThreadView> resolve(UuidValue threadUuid) =>
      api.call<CommentThreadView>(_e, 'resolve', {'threadUuid': threadUuid});

  @override
  Future<CommentThreadView> reopen(UuidValue threadUuid) =>
      api.call<CommentThreadView>(_e, 'reopen', {'threadUuid': threadUuid});

  @override
  Future<CommentView> react(int commentId, String emoji) =>
      api.call<CommentView>(_e, 'react', {'commentId': commentId, 'emoji': emoji});

  @override
  Future<CommentThreadView> updateAnchor(UuidValue threadUuid, String anchorJson) =>
      api.call<CommentThreadView>(_e, 'updateAnchor', {
        'threadUuid': threadUuid,
        'anchorJson': anchorJson,
      });

  @override
  Stream<CommentEvent> watch(UuidValue itemUuid) =>
      api.stream<CommentEvent>(_e, 'watch', {'itemUuid': itemUuid});
}

/// In-app notifications (suite 07 §4).
abstract class NotificationRepository {
  Future<NotificationPage> list({String? cursor, int limit = 30, bool unreadOnly = false});

  Future<void> markRead(List<int> ids);

  Future<void> markAllRead();

  Stream<NotificationEvent> watch();
}

class ServerNotificationRepository implements NotificationRepository {
  ServerNotificationRepository(this.api);

  final Api api;
  static const _e = 'notification';

  @override
  Future<NotificationPage> list({String? cursor, int limit = 30, bool unreadOnly = false}) =>
      api.call<NotificationPage>(_e, 'list', {
        'cursor': cursor,
        'limit': limit,
        'unreadOnly': unreadOnly,
      });

  @override
  Future<void> markRead(List<int> ids) => api.call<void>(_e, 'markRead', {'ids': ids});

  @override
  Future<void> markAllRead() => api.call<void>(_e, 'markAllRead');

  @override
  Stream<NotificationEvent> watch() => api.stream<NotificationEvent>(_e, 'watch');
}

/// Ephemeral presence (suite 07 §1).
abstract class PresenceRepository {
  /// Joins the roster of [itemUuid]; [updates] carries this session's state.
  Stream<PresenceEvent> join(UuidValue itemUuid, Stream<PresenceUpdate> updates);
}

class ServerPresenceRepository implements PresenceRepository {
  ServerPresenceRepository(this.api);

  final Api api;

  @override
  Stream<PresenceEvent> join(UuidValue itemUuid, Stream<PresenceUpdate> updates) =>
      api.stream<PresenceEvent>('presence', 'join', {'itemUuid': itemUuid}, {'updates': updates});
}

/// Version history (suite 07 §5).
abstract class VersionRepository {
  Future<List<ItemVersionView>> list(UuidValue itemUuid, {bool namedOnly = false});

  Future<ItemVersionView> nameCurrent(UuidValue itemUuid, String name);

  Future<ItemVersionView> rename(int versionId, String? name);

  Future<VersionRestoreResult> restore(UuidValue itemUuid, int versionId);

  Future<DriveItemView> makeCopy(UuidValue itemUuid, int versionId, String name);
}

class ServerVersionRepository implements VersionRepository {
  ServerVersionRepository(this.api);

  final Api api;
  static const _e = 'version';

  @override
  Future<List<ItemVersionView>> list(UuidValue itemUuid, {bool namedOnly = false}) =>
      api.call<List<ItemVersionView>>(_e, 'list', {
        'itemUuid': itemUuid,
        'namedOnly': namedOnly,
      });

  @override
  Future<ItemVersionView> nameCurrent(UuidValue itemUuid, String name) =>
      api.call<ItemVersionView>(_e, 'nameCurrent', {'itemUuid': itemUuid, 'name': name});

  @override
  Future<ItemVersionView> rename(int versionId, String? name) =>
      api.call<ItemVersionView>(_e, 'rename', {'versionId': versionId, 'name': name});

  @override
  Future<VersionRestoreResult> restore(UuidValue itemUuid, int versionId) =>
      api.call<VersionRestoreResult>(_e, 'restore', {
        'itemUuid': itemUuid,
        'versionId': versionId,
      });

  @override
  Future<DriveItemView> makeCopy(UuidValue itemUuid, int versionId, String name) =>
      api.call<DriveItemView>(_e, 'makeCopy', {
        'itemUuid': itemUuid,
        'versionId': versionId,
        'name': name,
      });
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
  Future<ProtocolInfo> getInfo() => api.call<ProtocolInfo>('meta', 'getInfo', const {}, false);

  @override
  Future<void> submitFeedback(FeedbackSubmission submission) =>
      api.call<void>('feedback', 'submit', {'submission': submission});
}
