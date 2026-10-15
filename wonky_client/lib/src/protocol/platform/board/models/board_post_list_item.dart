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
import '../../../platform/board/models/board_area.dart' as _iknrpzcb;
import '../../../platform/board/models/board_author.dart' as _imhv5g8m;
import '../../../platform/board/models/board_moderation.dart' as _i04stir2;
import '../../../platform/board/models/board_post_kind.dart' as _i76aj3nz;
import '../../../platform/board/models/board_post_status.dart' as _ij83av7d;
import '../../../platform/board/models/board_size.dart' as _ibr3u4cf;
import '../../../platform/board/models/board_task_ref.dart' as _ik00spaq;

/// A row of the board list.
abstract class BoardPostListItem
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardPostListItem._({
    required this.number,
    required this.kind,
    this.area,
    this.size,
    required this.aiLabels,
    required this.title,
    required this.status,
    required this.moderation,
    required this.needsCheck,
    required this.score,
    required this.voteCount,
    required this.commentCount,
    required this.myVote,
    this.author,
    required this.isMine,
    required this.hasScreenshot,
    this.task,
    required this.createdAt,
  });

  factory BoardPostListItem({
    required int number,
    required _i76aj3nz.BoardPostKind kind,
    _iknrpzcb.BoardArea? area,
    _ibr3u4cf.BoardSize? size,
    required bool aiLabels,
    required String title,
    required _ij83av7d.BoardPostStatus status,
    required _i04stir2.BoardModeration moderation,
    required bool needsCheck,
    required int score,
    required int voteCount,
    required int commentCount,
    required int myVote,
    _imhv5g8m.BoardAuthor? author,
    required bool isMine,
    required bool hasScreenshot,
    _ik00spaq.BoardTaskRef? task,
    required DateTime createdAt,
  }) = _BoardPostListItemImpl;

  factory BoardPostListItem.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardPostListItem(
      number: jsonSerialization['number'] as int,
      kind: _i76aj3nz.BoardPostKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      area: jsonSerialization['area'] == null
          ? null
          : _iknrpzcb.BoardArea.fromJson((jsonSerialization['area'] as String)),
      size: jsonSerialization['size'] == null
          ? null
          : _ibr3u4cf.BoardSize.fromJson((jsonSerialization['size'] as String)),
      aiLabels: _isc.BoolJsonExtension.fromJson(jsonSerialization['aiLabels']),
      title: jsonSerialization['title'] as String,
      status: _ij83av7d.BoardPostStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      moderation: _i04stir2.BoardModeration.fromJson(
        (jsonSerialization['moderation'] as String),
      ),
      needsCheck: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['needsCheck'],
      ),
      score: jsonSerialization['score'] as int,
      voteCount: jsonSerialization['voteCount'] as int,
      commentCount: jsonSerialization['commentCount'] as int,
      myVote: jsonSerialization['myVote'] as int,
      author: jsonSerialization['author'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_imhv5g8m.BoardAuthor>(
              jsonSerialization['author'],
            ),
      isMine: _isc.BoolJsonExtension.fromJson(jsonSerialization['isMine']),
      hasScreenshot: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['hasScreenshot'],
      ),
      task: jsonSerialization['task'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_ik00spaq.BoardTaskRef>(
              jsonSerialization['task'],
            ),
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  int number;

  _i76aj3nz.BoardPostKind kind;

  _iknrpzcb.BoardArea? area;

  _ibr3u4cf.BoardSize? size;

  bool aiLabels;

  String title;

  _ij83av7d.BoardPostStatus status;

  _i04stir2.BoardModeration moderation;

  bool needsCheck;

  int score;

  int voteCount;

  int commentCount;

  /// The caller's vote: -1, 0 or 1.
  int myVote;

  _imhv5g8m.BoardAuthor? author;

  bool isMine;

  bool hasScreenshot;

  _ik00spaq.BoardTaskRef? task;

  DateTime createdAt;

  /// Returns a shallow copy of this [BoardPostListItem]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardPostListItem copyWith({
    int? number,
    _i76aj3nz.BoardPostKind? kind,
    _iknrpzcb.BoardArea? area,
    _ibr3u4cf.BoardSize? size,
    bool? aiLabels,
    String? title,
    _ij83av7d.BoardPostStatus? status,
    _i04stir2.BoardModeration? moderation,
    bool? needsCheck,
    int? score,
    int? voteCount,
    int? commentCount,
    int? myVote,
    _imhv5g8m.BoardAuthor? author = const _UndefinedBoardPostListItem$author(),
    bool? isMine,
    bool? hasScreenshot,
    _ik00spaq.BoardTaskRef? task = const _UndefinedBoardPostListItem$task(),
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardPostListItem',
      'number': number,
      'kind': kind.toJson(),
      if (area != null) 'area': area?.toJson(),
      if (size != null) 'size': size?.toJson(),
      'aiLabels': aiLabels,
      'title': title,
      'status': status.toJson(),
      'moderation': moderation.toJson(),
      'needsCheck': needsCheck,
      'score': score,
      'voteCount': voteCount,
      'commentCount': commentCount,
      'myVote': myVote,
      if (author != null) 'author': author?.toJson(),
      'isMine': isMine,
      'hasScreenshot': hasScreenshot,
      if (task != null) 'task': task?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardPostListItem',
      'number': number,
      'kind': kind.toJson(),
      if (area != null) 'area': area?.toJson(),
      if (size != null) 'size': size?.toJson(),
      'aiLabels': aiLabels,
      'title': title,
      'status': status.toJson(),
      'moderation': moderation.toJson(),
      'needsCheck': needsCheck,
      'score': score,
      'voteCount': voteCount,
      'commentCount': commentCount,
      'myVote': myVote,
      if (author != null) 'author': author?.toJsonForProtocol(),
      'isMine': isMine,
      'hasScreenshot': hasScreenshot,
      if (task != null) 'task': task?.toJsonForProtocol(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedBoardPostListItem$author extends _isc.UndefinedSentinel
    implements _imhv5g8m.BoardAuthor {
  const _UndefinedBoardPostListItem$author();
}

class _UndefinedBoardPostListItem$task extends _isc.UndefinedSentinel
    implements _ik00spaq.BoardTaskRef {
  const _UndefinedBoardPostListItem$task();
}

class _BoardPostListItemImpl extends BoardPostListItem {
  _BoardPostListItemImpl({
    required int number,
    required _i76aj3nz.BoardPostKind kind,
    _iknrpzcb.BoardArea? area,
    _ibr3u4cf.BoardSize? size,
    required bool aiLabels,
    required String title,
    required _ij83av7d.BoardPostStatus status,
    required _i04stir2.BoardModeration moderation,
    required bool needsCheck,
    required int score,
    required int voteCount,
    required int commentCount,
    required int myVote,
    _imhv5g8m.BoardAuthor? author,
    required bool isMine,
    required bool hasScreenshot,
    _ik00spaq.BoardTaskRef? task,
    required DateTime createdAt,
  }) : super._(
         number: number,
         kind: kind,
         area: area,
         size: size,
         aiLabels: aiLabels,
         title: title,
         status: status,
         moderation: moderation,
         needsCheck: needsCheck,
         score: score,
         voteCount: voteCount,
         commentCount: commentCount,
         myVote: myVote,
         author: author,
         isMine: isMine,
         hasScreenshot: hasScreenshot,
         task: task,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [BoardPostListItem]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardPostListItem copyWith({
    int? number,
    _i76aj3nz.BoardPostKind? kind,
    Object? area = _Undefined,
    Object? size = _Undefined,
    bool? aiLabels,
    String? title,
    _ij83av7d.BoardPostStatus? status,
    _i04stir2.BoardModeration? moderation,
    bool? needsCheck,
    int? score,
    int? voteCount,
    int? commentCount,
    int? myVote,
    _imhv5g8m.BoardAuthor? author = const _UndefinedBoardPostListItem$author(),
    bool? isMine,
    bool? hasScreenshot,
    _ik00spaq.BoardTaskRef? task = const _UndefinedBoardPostListItem$task(),
    DateTime? createdAt,
  }) {
    return BoardPostListItem(
      number: number ?? this.number,
      kind: kind ?? this.kind,
      area: area is _iknrpzcb.BoardArea? ? area : this.area,
      size: size is _ibr3u4cf.BoardSize? ? size : this.size,
      aiLabels: aiLabels ?? this.aiLabels,
      title: title ?? this.title,
      status: status ?? this.status,
      moderation: moderation ?? this.moderation,
      needsCheck: needsCheck ?? this.needsCheck,
      score: score ?? this.score,
      voteCount: voteCount ?? this.voteCount,
      commentCount: commentCount ?? this.commentCount,
      myVote: myVote ?? this.myVote,
      author: author is _isc.UndefinedSentinel
          ? this.author?.copyWith()
          : author,
      isMine: isMine ?? this.isMine,
      hasScreenshot: hasScreenshot ?? this.hasScreenshot,
      task: task is _isc.UndefinedSentinel ? this.task?.copyWith() : task,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
