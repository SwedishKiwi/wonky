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
import 'package:wonky_client/src/protocol/protocol.dart' as _i8pkqg1o;
import '../../../platform/board/models/board_author.dart' as _imhv5g8m;
import '../../../platform/board/models/board_flag_view.dart' as _ipngornu;
import '../../../platform/board/models/board_moderation.dart' as _i04stir2;

abstract class BoardCommentView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardCommentView._({
    required this.uuid,
    this.postNumber,
    this.taskNumber,
    this.author,
    required this.body,
    this.systemEvent,
    required this.moderation,
    this.moderationReason,
    required this.isMine,
    required this.createdAt,
    this.editedAt,
    required this.deleted,
    required this.needsCheck,
    this.flags,
  });

  factory BoardCommentView({
    required _isc.UuidValue uuid,
    int? postNumber,
    int? taskNumber,
    _imhv5g8m.BoardAuthor? author,
    required String body,
    String? systemEvent,
    required _i04stir2.BoardModeration moderation,
    String? moderationReason,
    required bool isMine,
    required DateTime createdAt,
    DateTime? editedAt,
    required bool deleted,
    required bool needsCheck,
    List<_ipngornu.BoardFlagView>? flags,
  }) = _BoardCommentViewImpl;

  factory BoardCommentView.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardCommentView(
      uuid: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      postNumber: jsonSerialization['postNumber'] as int?,
      taskNumber: jsonSerialization['taskNumber'] as int?,
      author: jsonSerialization['author'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_imhv5g8m.BoardAuthor>(
              jsonSerialization['author'],
            ),
      body: jsonSerialization['body'] as String,
      systemEvent: jsonSerialization['systemEvent'] as String?,
      moderation: _i04stir2.BoardModeration.fromJson(
        (jsonSerialization['moderation'] as String),
      ),
      moderationReason: jsonSerialization['moderationReason'] as String?,
      isMine: _isc.BoolJsonExtension.fromJson(jsonSerialization['isMine']),
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      editedAt: jsonSerialization['editedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['editedAt']),
      deleted: _isc.BoolJsonExtension.fromJson(jsonSerialization['deleted']),
      needsCheck: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['needsCheck'],
      ),
      flags: jsonSerialization['flags'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<List<_ipngornu.BoardFlagView>>(
              jsonSerialization['flags'],
            ),
    );
  }

  _isc.UuidValue uuid;

  int? postNumber;

  int? taskNumber;

  _imhv5g8m.BoardAuthor? author;

  /// Empty when deleted or removed (except for admins and the author).
  String body;

  String? systemEvent;

  _i04stir2.BoardModeration moderation;

  String? moderationReason;

  bool isMine;

  DateTime createdAt;

  DateTime? editedAt;

  bool deleted;

  /// Admin only.
  bool needsCheck;

  List<_ipngornu.BoardFlagView>? flags;

  /// Returns a shallow copy of this [BoardCommentView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardCommentView copyWith({
    _isc.UuidValue? uuid,
    int? postNumber,
    int? taskNumber,
    _imhv5g8m.BoardAuthor? author = const _UndefinedBoardCommentView$author(),
    String? body,
    String? systemEvent,
    _i04stir2.BoardModeration? moderation,
    String? moderationReason,
    bool? isMine,
    DateTime? createdAt,
    DateTime? editedAt = const _isc.$UndefinedDateTime(),
    bool? deleted,
    bool? needsCheck,
    List<_ipngornu.BoardFlagView>? flags =
        const _isc.$UndefinedList<_ipngornu.BoardFlagView>(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardCommentView',
      'uuid': uuid.toJson(),
      if (postNumber != null) 'postNumber': postNumber,
      if (taskNumber != null) 'taskNumber': taskNumber,
      if (author != null) 'author': author?.toJson(),
      'body': body,
      if (systemEvent != null) 'systemEvent': systemEvent,
      'moderation': moderation.toJson(),
      if (moderationReason != null) 'moderationReason': moderationReason,
      'isMine': isMine,
      'createdAt': createdAt.toJson(),
      if (editedAt != null) 'editedAt': editedAt?.toJson(),
      'deleted': deleted,
      'needsCheck': needsCheck,
      if (flags != null) 'flags': flags?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardCommentView',
      'uuid': uuid.toJson(),
      if (postNumber != null) 'postNumber': postNumber,
      if (taskNumber != null) 'taskNumber': taskNumber,
      if (author != null) 'author': author?.toJsonForProtocol(),
      'body': body,
      if (systemEvent != null) 'systemEvent': systemEvent,
      'moderation': moderation.toJson(),
      if (moderationReason != null) 'moderationReason': moderationReason,
      'isMine': isMine,
      'createdAt': createdAt.toJson(),
      if (editedAt != null) 'editedAt': editedAt?.toJson(),
      'deleted': deleted,
      'needsCheck': needsCheck,
      if (flags != null)
        'flags': flags?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedBoardCommentView$author extends _isc.UndefinedSentinel
    implements _imhv5g8m.BoardAuthor {
  const _UndefinedBoardCommentView$author();
}

class _BoardCommentViewImpl extends BoardCommentView {
  _BoardCommentViewImpl({
    required _isc.UuidValue uuid,
    int? postNumber,
    int? taskNumber,
    _imhv5g8m.BoardAuthor? author,
    required String body,
    String? systemEvent,
    required _i04stir2.BoardModeration moderation,
    String? moderationReason,
    required bool isMine,
    required DateTime createdAt,
    DateTime? editedAt,
    required bool deleted,
    required bool needsCheck,
    List<_ipngornu.BoardFlagView>? flags,
  }) : super._(
         uuid: uuid,
         postNumber: postNumber,
         taskNumber: taskNumber,
         author: author,
         body: body,
         systemEvent: systemEvent,
         moderation: moderation,
         moderationReason: moderationReason,
         isMine: isMine,
         createdAt: createdAt,
         editedAt: editedAt,
         deleted: deleted,
         needsCheck: needsCheck,
         flags: flags,
       );

  /// Returns a shallow copy of this [BoardCommentView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardCommentView copyWith({
    _isc.UuidValue? uuid,
    Object? postNumber = _Undefined,
    Object? taskNumber = _Undefined,
    _imhv5g8m.BoardAuthor? author = const _UndefinedBoardCommentView$author(),
    String? body,
    Object? systemEvent = _Undefined,
    _i04stir2.BoardModeration? moderation,
    Object? moderationReason = _Undefined,
    bool? isMine,
    DateTime? createdAt,
    DateTime? editedAt = const _isc.$UndefinedDateTime(),
    bool? deleted,
    bool? needsCheck,
    List<_ipngornu.BoardFlagView>? flags =
        const _isc.$UndefinedList<_ipngornu.BoardFlagView>(),
  }) {
    return BoardCommentView(
      uuid: uuid ?? this.uuid,
      postNumber: postNumber is int? ? postNumber : this.postNumber,
      taskNumber: taskNumber is int? ? taskNumber : this.taskNumber,
      author: author is _isc.UndefinedSentinel
          ? this.author?.copyWith()
          : author,
      body: body ?? this.body,
      systemEvent: systemEvent is String? ? systemEvent : this.systemEvent,
      moderation: moderation ?? this.moderation,
      moderationReason: moderationReason is String?
          ? moderationReason
          : this.moderationReason,
      isMine: isMine ?? this.isMine,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt is _isc.UndefinedSentinel ? this.editedAt : editedAt,
      deleted: deleted ?? this.deleted,
      needsCheck: needsCheck ?? this.needsCheck,
      flags: flags is _isc.UndefinedSentinel
          ? this.flags?.map((e0) => e0.copyWith()).toList()
          : flags,
    );
  }
}
