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

/// One vote per user and post: +1, or -1 (ideas only).
abstract class BoardVote
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardVote._({
    this.id,
    required this.postId,
    required this.userId,
    required this.value,
    required this.createdAt,
  });

  factory BoardVote({
    int? id,
    required int postId,
    required int userId,
    required int value,
    required DateTime createdAt,
  }) = _BoardVoteImpl;

  factory BoardVote.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardVote(
      id: jsonSerialization['id'] as int?,
      postId: jsonSerialization['postId'] as int,
      userId: jsonSerialization['userId'] as int,
      value: jsonSerialization['value'] as int,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int postId;

  int userId;

  int value;

  DateTime createdAt;

  /// Returns a shallow copy of this [BoardVote]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardVote copyWith({
    int? id,
    int? postId,
    int? userId,
    int? value,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardVote',
      if (id != null) 'id': id,
      'postId': postId,
      'userId': userId,
      'value': value,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardVote',
      if (id != null) 'id': id,
      'postId': postId,
      'userId': userId,
      'value': value,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardVoteImpl extends BoardVote {
  _BoardVoteImpl({
    int? id,
    required int postId,
    required int userId,
    required int value,
    required DateTime createdAt,
  }) : super._(
         id: id,
         postId: postId,
         userId: userId,
         value: value,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [BoardVote]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardVote copyWith({
    Object? id = _Undefined,
    int? postId,
    int? userId,
    int? value,
    DateTime? createdAt,
  }) {
    return BoardVote(
      id: id is int? ? id : this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
