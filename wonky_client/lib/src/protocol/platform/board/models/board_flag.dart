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
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import '../../../platform/board/models/board_flag_reason.dart' as _ienu5u16;

/// A user's flag on a post or comment (specs/16 §7.5).
abstract class BoardFlag
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardFlag._({
    this.id,
    this.postId,
    this.commentId,
    required this.userId,
    required this.reason,
    this.note,
    required this.createdAt,
  });

  factory BoardFlag({
    int? id,
    int? postId,
    int? commentId,
    required int userId,
    required _ienu5u16.BoardFlagReason reason,
    String? note,
    required DateTime createdAt,
  }) = _BoardFlagImpl;

  factory BoardFlag.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardFlag(
      id: jsonSerialization['id'] as int?,
      postId: jsonSerialization['postId'] as int?,
      commentId: jsonSerialization['commentId'] as int?,
      userId: jsonSerialization['userId'] as int,
      reason: _ienu5u16.BoardFlagReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
      note: jsonSerialization['note'] as String?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int? postId;

  int? commentId;

  int userId;

  _ienu5u16.BoardFlagReason reason;

  String? note;

  DateTime createdAt;

  /// Returns a shallow copy of this [BoardFlag]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardFlag copyWith({
    int? id,
    int? postId,
    int? commentId,
    int? userId,
    _ienu5u16.BoardFlagReason? reason,
    String? note,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardFlag',
      if (id != null) 'id': id,
      if (postId != null) 'postId': postId,
      if (commentId != null) 'commentId': commentId,
      'userId': userId,
      'reason': reason.toJson(),
      if (note != null) 'note': note,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardFlag',
      if (id != null) 'id': id,
      if (postId != null) 'postId': postId,
      if (commentId != null) 'commentId': commentId,
      'userId': userId,
      'reason': reason.toJson(),
      if (note != null) 'note': note,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardFlagImpl extends BoardFlag {
  _BoardFlagImpl({
    int? id,
    int? postId,
    int? commentId,
    required int userId,
    required _ienu5u16.BoardFlagReason reason,
    String? note,
    required DateTime createdAt,
  }) : super._(
         id: id,
         postId: postId,
         commentId: commentId,
         userId: userId,
         reason: reason,
         note: note,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [BoardFlag]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardFlag copyWith({
    Object? id = _Undefined,
    Object? postId = _Undefined,
    Object? commentId = _Undefined,
    int? userId,
    _ienu5u16.BoardFlagReason? reason,
    Object? note = _Undefined,
    DateTime? createdAt,
  }) {
    return BoardFlag(
      id: id is int? ? id : this.id,
      postId: postId is int? ? postId : this.postId,
      commentId: commentId is int? ? commentId : this.commentId,
      userId: userId ?? this.userId,
      reason: reason ?? this.reason,
      note: note is String? ? note : this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
