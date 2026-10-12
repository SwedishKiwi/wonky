import 'package:serverpod/serverpod.dart';

import 'models.dart';

/// Who performs a service call: the user plus the kind of actor (a person in
/// an app, an MCP client, the AI assistant, a script or the system).
class Actor {
  const Actor({
    required this.userId,
    required this.authUserId,
    this.kind = ActorKind.user,
    this.sessionId,
  });

  /// UserProfile id.
  final int userId;

  /// Serverpod auth user UUID (sync spaces, Write `by` attributes).
  final UuidValue authUserId;

  final ActorKind kind;

  /// Editing session (document stream, presence) the call belongs to.
  final String? sessionId;

  Actor copyWith({ActorKind? kind, String? sessionId}) => Actor(
    userId: userId,
    authUserId: authUserId,
    kind: kind ?? this.kind,
    sessionId: sessionId ?? this.sessionId,
  );

  @override
  String toString() => 'Actor($userId, ${kind.name})';
}
