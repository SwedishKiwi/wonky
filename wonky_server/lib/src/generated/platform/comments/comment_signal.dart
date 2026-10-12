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
import '../../platform/comments/comment_event_kind.dart' as _ikhh0xod;

/// Internal session.messages payload on `comments:<itemUuid>`.
abstract class CommentSignal
    implements _is.SerializableModel, _is.ProtocolSerialization {
  CommentSignal._({
    required this.kind,
    required this.threadUuid,
  });

  factory CommentSignal({
    required _ikhh0xod.CommentEventKind kind,
    required _is.UuidValue threadUuid,
  }) = _CommentSignalImpl;

  factory CommentSignal.fromJson(Map<String, dynamic> jsonSerialization) {
    return CommentSignal(
      kind: _ikhh0xod.CommentEventKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      threadUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['threadUuid'],
      ),
    );
  }

  _ikhh0xod.CommentEventKind kind;

  _is.UuidValue threadUuid;

  /// Returns a shallow copy of this [CommentSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  CommentSignal copyWith({
    _ikhh0xod.CommentEventKind? kind,
    _is.UuidValue? threadUuid,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CommentSignal',
      'kind': kind.toJson(),
      'threadUuid': threadUuid.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _CommentSignalImpl extends CommentSignal {
  _CommentSignalImpl({
    required _ikhh0xod.CommentEventKind kind,
    required _is.UuidValue threadUuid,
  }) : super._(
         kind: kind,
         threadUuid: threadUuid,
       );

  /// Returns a shallow copy of this [CommentSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  CommentSignal copyWith({
    _ikhh0xod.CommentEventKind? kind,
    _is.UuidValue? threadUuid,
  }) {
    return CommentSignal(
      kind: kind ?? this.kind,
      threadUuid: threadUuid ?? this.threadUuid,
    );
  }
}
