import 'package:wonky_client/wonky_client.dart';

/// Kinds of comment operations that can be queued offline (Sheets 10 §3.7):
/// creating threads, replying, resolving/reopening and moving anchors.
/// Edits and deletes of comments need a connection.
enum PendingCommentKind { create, reply, resolve, reopen, anchor }

/// A comment operation made offline (Additions A-10-4 `PendingCommentOp`),
/// kept in the user's local store until it is posted. Thread and comment
/// uuids are client-generated, so posting is idempotent.
class PendingCommentOp {
  const PendingCommentOp({
    required this.opId,
    required this.threadUuid,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });

  final String opId;
  final String threadUuid;
  final PendingCommentKind kind;

  /// create: `anchorKind`, `anchorJson`, `quotedText`, `body`, `mentions`,
  /// `assigneeId`; reply: `body`, `mentions`, `commentUuid`; anchor:
  /// `anchorJson`.
  final Map<String, Object?> payload;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'op': opId,
    't': threadUuid,
    'k': kind.name,
    'p': payload,
    'at': createdAt.toUtc().toIso8601String(),
  };

  static PendingCommentOp? fromJson(Object? j) {
    if (j is! Map) return null;
    final kind = PendingCommentKind.values
        .where((k) => k.name == j['k'])
        .firstOrNull;
    final op = j['op'];
    final t = j['t'];
    if (kind == null || op is! String || t is! String) return null;
    return PendingCommentOp(
      opId: op,
      threadUuid: t,
      kind: kind,
      payload: j['p'] is Map
          ? (j['p'] as Map).cast<String, Object?>()
          : const <String, Object?>{},
      createdAt: DateTime.tryParse('${j['at']}') ?? DateTime.now().toUtc(),
    );
  }

  List<int> get mentions => [
    for (final m in (payload['mentions'] as List?) ?? const [])
      if (m is num) m.toInt(),
  ];

  /// Applies this operation to [threads] for display (the optimistic view
  /// of the queue). [me] authors new comments; [localId] numbers them.
  List<CommentThreadView> overlay(
    List<CommentThreadView> threads, {
    required UuidValue itemUuid,
    required UserSummary? me,
    required int Function() localId,
  }) {
    final i = threads.indexWhere((t) => t.uuid.uuid == threadUuid);
    CommentView comment(String body, String? uuid) => CommentView(
      id: localId(),
      uuid: uuid == null ? null : UuidValue.fromString(uuid),
      threadUuid: UuidValue.fromString(threadUuid),
      author: me,
      authorKind: ActorKind.user,
      body: body,
      mentions: const [],
      reactions: const {},
      createdAt: createdAt,
      deleted: false,
    );
    switch (kind) {
      case PendingCommentKind.create:
        if (i >= 0) return threads;
        return [
          ...threads,
          CommentThreadView(
            uuid: UuidValue.fromString(threadUuid),
            itemUuid: itemUuid,
            anchorKind:
                CommentAnchorKind.values
                    .where((k) => k.name == payload['anchorKind'])
                    .firstOrNull ??
                CommentAnchorKind.document,
            anchorJson: '${payload['anchorJson'] ?? '{}'}',
            quotedText: payload['quotedText'] as String?,
            status: CommentStatus.open,
            createdBy: me,
            createdAt: createdAt,
            comments: [comment('${payload['body'] ?? ''}', null)],
          ),
        ];
      case PendingCommentKind.reply:
        if (i < 0) return threads;
        final t = threads[i];
        final uuid = payload['commentUuid'] as String?;
        if (uuid != null && t.comments.any((c) => c.uuid?.uuid == uuid)) {
          return threads;
        }
        return [...threads]
          ..[i] = t.copyWith(
            comments: [
              ...t.comments,
              comment('${payload['body'] ?? ''}', uuid),
            ],
          );
      case PendingCommentKind.resolve || PendingCommentKind.reopen:
        if (i < 0) return threads;
        return [...threads]
          ..[i] = threads[i].copyWith(
            status: kind == PendingCommentKind.resolve
                ? CommentStatus.resolved
                : CommentStatus.open,
          );
      case PendingCommentKind.anchor:
        if (i < 0) return threads;
        return [...threads]
          ..[i] = threads[i].copyWith(
            anchorJson: '${payload['anchorJson'] ?? threads[i].anchorJson}',
          );
    }
  }
}
