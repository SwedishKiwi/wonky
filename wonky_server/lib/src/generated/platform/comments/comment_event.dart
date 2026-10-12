/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;
import 'package:wonky_server/src/generated/protocol.dart' as _il4umwa0;
import '../../platform/comments/comment_event_kind.dart' as _ikhh0xod;
import '../../platform/comments/comment_thread_view.dart' as _ix1f8737;

/// A live comment change on an item (`comment.watch`).
abstract class CommentEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  CommentEvent._({
    required this.kind,
    required this.threadUuid,
    this.thread,
  });

  factory CommentEvent({
    required _ikhh0xod.CommentEventKind kind,
    required _is.UuidValue threadUuid,
    _ix1f8737.CommentThreadView? thread,
  }) = _CommentEventImpl;

  factory CommentEvent.fromJson(Map<String, dynamic> jsonSerialization) {
    return CommentEvent(
      kind: _ikhh0xod.CommentEventKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      threadUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['threadUuid'],
      ),
      thread: jsonSerialization['thread'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_ix1f8737.CommentThreadView>(
              jsonSerialization['thread'],
            ),
    );
  }

  _ikhh0xod.CommentEventKind kind;

  _is.UuidValue threadUuid;

  /// The full thread after the change; null for threadDeleted.
  _ix1f8737.CommentThreadView? thread;

  /// Returns a shallow copy of this [CommentEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  CommentEvent copyWith({
    _ikhh0xod.CommentEventKind? kind,
    _is.UuidValue? threadUuid,
    _ix1f8737.CommentThreadView? thread = const _UndefinedCommentEvent$thread(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CommentEvent',
      'kind': kind.toJson(),
      'threadUuid': threadUuid.toJson(),
      if (thread != null) 'thread': thread?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CommentEvent',
      'kind': kind.toJson(),
      'threadUuid': threadUuid.toJson(),
      if (thread != null) 'thread': thread?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _UndefinedCommentEvent$thread extends _is.UndefinedSentinel
    implements _ix1f8737.CommentThreadView {
  const _UndefinedCommentEvent$thread();
}

class _CommentEventImpl extends CommentEvent {
  _CommentEventImpl({
    required _ikhh0xod.CommentEventKind kind,
    required _is.UuidValue threadUuid,
    _ix1f8737.CommentThreadView? thread,
  }) : super._(
         kind: kind,
         threadUuid: threadUuid,
         thread: thread,
       );

  /// Returns a shallow copy of this [CommentEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  CommentEvent copyWith({
    _ikhh0xod.CommentEventKind? kind,
    _is.UuidValue? threadUuid,
    _ix1f8737.CommentThreadView? thread = const _UndefinedCommentEvent$thread(),
  }) {
    return CommentEvent(
      kind: kind ?? this.kind,
      threadUuid: threadUuid ?? this.threadUuid,
      thread: thread is _is.UndefinedSentinel
          ? this.thread?.copyWith()
          : thread,
    );
  }
}
