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
import '../../../platform/board/models/board_moderation.dart' as _i04stir2;

/// A comment on a post, or discussion and activity rows on a task.
abstract class BoardComment
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardComment._({
    this.id,
    required this.uuid,
    this.postId,
    this.taskId,
    this.authorId,
    required this.body,
    this.systemEvent,
    required this.moderation,
    this.moderationReason,
    bool? needsCheck,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.removedAt,
  }) : needsCheck = needsCheck ?? false;

  factory BoardComment({
    int? id,
    required _isc.UuidValue uuid,
    int? postId,
    int? taskId,
    int? authorId,
    required String body,
    String? systemEvent,
    required _i04stir2.BoardModeration moderation,
    String? moderationReason,
    bool? needsCheck,
    required DateTime createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    DateTime? removedAt,
  }) = _BoardCommentImpl;

  factory BoardComment.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardComment(
      id: jsonSerialization['id'] as int?,
      uuid: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      postId: jsonSerialization['postId'] as int?,
      taskId: jsonSerialization['taskId'] as int?,
      authorId: jsonSerialization['authorId'] as int?,
      body: jsonSerialization['body'] as String,
      systemEvent: jsonSerialization['systemEvent'] as String?,
      moderation: _i04stir2.BoardModeration.fromJson(
        (jsonSerialization['moderation'] as String),
      ),
      moderationReason: jsonSerialization['moderationReason'] as String?,
      needsCheck: jsonSerialization['needsCheck'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['needsCheck']),
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      editedAt: jsonSerialization['editedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['editedAt']),
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
      removedAt: jsonSerialization['removedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['removedAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// Client-supplied; idempotent create.
  _isc.UuidValue uuid;

  int? postId;

  int? taskId;

  /// Null for system rows and deleted users.
  int? authorId;

  /// Markdown, at most 10,000 chars.
  String body;

  /// claimed, released, expired, prLinked, prClosed, done, shipped, merged…
  String? systemEvent;

  _i04stir2.BoardModeration moderation;

  String? moderationReason;

  bool needsCheck;

  DateTime createdAt;

  DateTime? editedAt;

  DateTime? deletedAt;

  DateTime? removedAt;

  /// Returns a shallow copy of this [BoardComment]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardComment copyWith({
    int? id,
    _isc.UuidValue? uuid,
    int? postId,
    int? taskId,
    int? authorId,
    String? body,
    String? systemEvent,
    _i04stir2.BoardModeration? moderation,
    String? moderationReason,
    bool? needsCheck,
    DateTime? createdAt,
    DateTime? editedAt = const _isc.$UndefinedDateTime(),
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
    DateTime? removedAt = const _isc.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardComment',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      if (postId != null) 'postId': postId,
      if (taskId != null) 'taskId': taskId,
      if (authorId != null) 'authorId': authorId,
      'body': body,
      if (systemEvent != null) 'systemEvent': systemEvent,
      'moderation': moderation.toJson(),
      if (moderationReason != null) 'moderationReason': moderationReason,
      'needsCheck': needsCheck,
      'createdAt': createdAt.toJson(),
      if (editedAt != null) 'editedAt': editedAt?.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
      if (removedAt != null) 'removedAt': removedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardComment',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      if (postId != null) 'postId': postId,
      if (taskId != null) 'taskId': taskId,
      if (authorId != null) 'authorId': authorId,
      'body': body,
      if (systemEvent != null) 'systemEvent': systemEvent,
      'moderation': moderation.toJson(),
      if (moderationReason != null) 'moderationReason': moderationReason,
      'needsCheck': needsCheck,
      'createdAt': createdAt.toJson(),
      if (editedAt != null) 'editedAt': editedAt?.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
      if (removedAt != null) 'removedAt': removedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardCommentImpl extends BoardComment {
  _BoardCommentImpl({
    int? id,
    required _isc.UuidValue uuid,
    int? postId,
    int? taskId,
    int? authorId,
    required String body,
    String? systemEvent,
    required _i04stir2.BoardModeration moderation,
    String? moderationReason,
    bool? needsCheck,
    required DateTime createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    DateTime? removedAt,
  }) : super._(
         id: id,
         uuid: uuid,
         postId: postId,
         taskId: taskId,
         authorId: authorId,
         body: body,
         systemEvent: systemEvent,
         moderation: moderation,
         moderationReason: moderationReason,
         needsCheck: needsCheck,
         createdAt: createdAt,
         editedAt: editedAt,
         deletedAt: deletedAt,
         removedAt: removedAt,
       );

  /// Returns a shallow copy of this [BoardComment]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardComment copyWith({
    Object? id = _Undefined,
    _isc.UuidValue? uuid,
    Object? postId = _Undefined,
    Object? taskId = _Undefined,
    Object? authorId = _Undefined,
    String? body,
    Object? systemEvent = _Undefined,
    _i04stir2.BoardModeration? moderation,
    Object? moderationReason = _Undefined,
    bool? needsCheck,
    DateTime? createdAt,
    DateTime? editedAt = const _isc.$UndefinedDateTime(),
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
    DateTime? removedAt = const _isc.$UndefinedDateTime(),
  }) {
    return BoardComment(
      id: id is int? ? id : this.id,
      uuid: uuid ?? this.uuid,
      postId: postId is int? ? postId : this.postId,
      taskId: taskId is int? ? taskId : this.taskId,
      authorId: authorId is int? ? authorId : this.authorId,
      body: body ?? this.body,
      systemEvent: systemEvent is String? ? systemEvent : this.systemEvent,
      moderation: moderation ?? this.moderation,
      moderationReason: moderationReason is String?
          ? moderationReason
          : this.moderationReason,
      needsCheck: needsCheck ?? this.needsCheck,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt is _isc.UndefinedSentinel ? this.editedAt : editedAt,
      deletedAt: deletedAt is _isc.UndefinedSentinel
          ? this.deletedAt
          : deletedAt,
      removedAt: removedAt is _isc.UndefinedSentinel
          ? this.removedAt
          : removedAt,
    );
  }
}
