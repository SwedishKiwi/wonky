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
import '../../../platform/board/models/board_flag_view.dart' as _ipngornu;
import '../../../platform/board/models/board_moderation.dart' as _i04stir2;
import '../../../platform/board/models/board_post_kind.dart' as _i76aj3nz;
import '../../../platform/board/models/board_post_status.dart' as _ij83av7d;
import '../../../platform/board/models/board_size.dart' as _ibr3u4cf;
import '../../../platform/board/models/board_task_ref.dart' as _ik00spaq;
import '../../../platform/board/models/board_triage_state.dart' as _ijfwzb4l;

/// A post with everything the post page shows. Admin-only fields are
/// null for everyone else.
abstract class BoardPostView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardPostView._({
    required this.number,
    required this.kind,
    required this.reportedKind,
    this.area,
    this.size,
    required this.aiLabels,
    required this.title,
    required this.body,
    this.contextJson,
    required this.appHint,
    required this.hasScreenshot,
    required this.status,
    required this.moderation,
    this.moderationReason,
    required this.editedByModerator,
    required this.triageState,
    this.summary,
    this.duplicateOfNumber,
    this.declineReason,
    this.task,
    required this.mergedFrom,
    required this.score,
    required this.voteCount,
    required this.commentCount,
    required this.myVote,
    this.author,
    required this.isMine,
    required this.canEdit,
    required this.createdAt,
    this.editedAt,
    required this.deleted,
    required this.needsCheck,
    this.suggestedTitle,
    this.possibleDuplicateOfNumber,
    this.triageJson,
    this.flags,
  });

  factory BoardPostView({
    required int number,
    required _i76aj3nz.BoardPostKind kind,
    required _i76aj3nz.BoardPostKind reportedKind,
    _iknrpzcb.BoardArea? area,
    _ibr3u4cf.BoardSize? size,
    required bool aiLabels,
    required String title,
    required String body,
    String? contextJson,
    required String appHint,
    required bool hasScreenshot,
    required _ij83av7d.BoardPostStatus status,
    required _i04stir2.BoardModeration moderation,
    String? moderationReason,
    required bool editedByModerator,
    required _ijfwzb4l.BoardTriageState triageState,
    String? summary,
    int? duplicateOfNumber,
    String? declineReason,
    _ik00spaq.BoardTaskRef? task,
    required List<int> mergedFrom,
    required int score,
    required int voteCount,
    required int commentCount,
    required int myVote,
    _imhv5g8m.BoardAuthor? author,
    required bool isMine,
    required bool canEdit,
    required DateTime createdAt,
    DateTime? editedAt,
    required bool deleted,
    required bool needsCheck,
    String? suggestedTitle,
    int? possibleDuplicateOfNumber,
    String? triageJson,
    List<_ipngornu.BoardFlagView>? flags,
  }) = _BoardPostViewImpl;

  factory BoardPostView.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardPostView(
      number: jsonSerialization['number'] as int,
      kind: _i76aj3nz.BoardPostKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      reportedKind: _i76aj3nz.BoardPostKind.fromJson(
        (jsonSerialization['reportedKind'] as String),
      ),
      area: jsonSerialization['area'] == null
          ? null
          : _iknrpzcb.BoardArea.fromJson((jsonSerialization['area'] as String)),
      size: jsonSerialization['size'] == null
          ? null
          : _ibr3u4cf.BoardSize.fromJson((jsonSerialization['size'] as String)),
      aiLabels: _isc.BoolJsonExtension.fromJson(jsonSerialization['aiLabels']),
      title: jsonSerialization['title'] as String,
      body: jsonSerialization['body'] as String,
      contextJson: jsonSerialization['contextJson'] as String?,
      appHint: jsonSerialization['appHint'] as String,
      hasScreenshot: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['hasScreenshot'],
      ),
      status: _ij83av7d.BoardPostStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      moderation: _i04stir2.BoardModeration.fromJson(
        (jsonSerialization['moderation'] as String),
      ),
      moderationReason: jsonSerialization['moderationReason'] as String?,
      editedByModerator: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['editedByModerator'],
      ),
      triageState: _ijfwzb4l.BoardTriageState.fromJson(
        (jsonSerialization['triageState'] as String),
      ),
      summary: jsonSerialization['summary'] as String?,
      duplicateOfNumber: jsonSerialization['duplicateOfNumber'] as int?,
      declineReason: jsonSerialization['declineReason'] as String?,
      task: jsonSerialization['task'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_ik00spaq.BoardTaskRef>(
              jsonSerialization['task'],
            ),
      mergedFrom: _i8pkqg1o.Protocol().deserialize<List<int>>(
        jsonSerialization['mergedFrom'],
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
      canEdit: _isc.BoolJsonExtension.fromJson(jsonSerialization['canEdit']),
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
      suggestedTitle: jsonSerialization['suggestedTitle'] as String?,
      possibleDuplicateOfNumber:
          jsonSerialization['possibleDuplicateOfNumber'] as int?,
      triageJson: jsonSerialization['triageJson'] as String?,
      flags: jsonSerialization['flags'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<List<_ipngornu.BoardFlagView>>(
              jsonSerialization['flags'],
            ),
    );
  }

  int number;

  _i76aj3nz.BoardPostKind kind;

  _i76aj3nz.BoardPostKind reportedKind;

  _iknrpzcb.BoardArea? area;

  _ibr3u4cf.BoardSize? size;

  bool aiLabels;

  String title;

  String body;

  String? contextJson;

  String appHint;

  bool hasScreenshot;

  _ij83av7d.BoardPostStatus status;

  _i04stir2.BoardModeration moderation;

  /// For the author (held, removed) and admins.
  String? moderationReason;

  bool editedByModerator;

  _ijfwzb4l.BoardTriageState triageState;

  String? summary;

  int? duplicateOfNumber;

  String? declineReason;

  _ik00spaq.BoardTaskRef? task;

  List<int> mergedFrom;

  int score;

  int voteCount;

  int commentCount;

  int myVote;

  _imhv5g8m.BoardAuthor? author;

  bool isMine;

  /// The author may edit (open, not in a task, not removed).
  bool canEdit;

  DateTime createdAt;

  DateTime? editedAt;

  bool deleted;

  /// Admin only.
  bool needsCheck;

  String? suggestedTitle;

  int? possibleDuplicateOfNumber;

  String? triageJson;

  List<_ipngornu.BoardFlagView>? flags;

  /// Returns a shallow copy of this [BoardPostView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardPostView copyWith({
    int? number,
    _i76aj3nz.BoardPostKind? kind,
    _i76aj3nz.BoardPostKind? reportedKind,
    _iknrpzcb.BoardArea? area,
    _ibr3u4cf.BoardSize? size,
    bool? aiLabels,
    String? title,
    String? body,
    String? contextJson,
    String? appHint,
    bool? hasScreenshot,
    _ij83av7d.BoardPostStatus? status,
    _i04stir2.BoardModeration? moderation,
    String? moderationReason,
    bool? editedByModerator,
    _ijfwzb4l.BoardTriageState? triageState,
    String? summary,
    int? duplicateOfNumber,
    String? declineReason,
    _ik00spaq.BoardTaskRef? task = const _UndefinedBoardPostView$task(),
    List<int>? mergedFrom,
    int? score,
    int? voteCount,
    int? commentCount,
    int? myVote,
    _imhv5g8m.BoardAuthor? author = const _UndefinedBoardPostView$author(),
    bool? isMine,
    bool? canEdit,
    DateTime? createdAt,
    DateTime? editedAt = const _isc.$UndefinedDateTime(),
    bool? deleted,
    bool? needsCheck,
    String? suggestedTitle,
    int? possibleDuplicateOfNumber,
    String? triageJson,
    List<_ipngornu.BoardFlagView>? flags =
        const _isc.$UndefinedList<_ipngornu.BoardFlagView>(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardPostView',
      'number': number,
      'kind': kind.toJson(),
      'reportedKind': reportedKind.toJson(),
      if (area != null) 'area': area?.toJson(),
      if (size != null) 'size': size?.toJson(),
      'aiLabels': aiLabels,
      'title': title,
      'body': body,
      if (contextJson != null) 'contextJson': contextJson,
      'appHint': appHint,
      'hasScreenshot': hasScreenshot,
      'status': status.toJson(),
      'moderation': moderation.toJson(),
      if (moderationReason != null) 'moderationReason': moderationReason,
      'editedByModerator': editedByModerator,
      'triageState': triageState.toJson(),
      if (summary != null) 'summary': summary,
      if (duplicateOfNumber != null) 'duplicateOfNumber': duplicateOfNumber,
      if (declineReason != null) 'declineReason': declineReason,
      if (task != null) 'task': task?.toJson(),
      'mergedFrom': mergedFrom.toJson(),
      'score': score,
      'voteCount': voteCount,
      'commentCount': commentCount,
      'myVote': myVote,
      if (author != null) 'author': author?.toJson(),
      'isMine': isMine,
      'canEdit': canEdit,
      'createdAt': createdAt.toJson(),
      if (editedAt != null) 'editedAt': editedAt?.toJson(),
      'deleted': deleted,
      'needsCheck': needsCheck,
      if (suggestedTitle != null) 'suggestedTitle': suggestedTitle,
      if (possibleDuplicateOfNumber != null)
        'possibleDuplicateOfNumber': possibleDuplicateOfNumber,
      if (triageJson != null) 'triageJson': triageJson,
      if (flags != null) 'flags': flags?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardPostView',
      'number': number,
      'kind': kind.toJson(),
      'reportedKind': reportedKind.toJson(),
      if (area != null) 'area': area?.toJson(),
      if (size != null) 'size': size?.toJson(),
      'aiLabels': aiLabels,
      'title': title,
      'body': body,
      if (contextJson != null) 'contextJson': contextJson,
      'appHint': appHint,
      'hasScreenshot': hasScreenshot,
      'status': status.toJson(),
      'moderation': moderation.toJson(),
      if (moderationReason != null) 'moderationReason': moderationReason,
      'editedByModerator': editedByModerator,
      'triageState': triageState.toJson(),
      if (summary != null) 'summary': summary,
      if (duplicateOfNumber != null) 'duplicateOfNumber': duplicateOfNumber,
      if (declineReason != null) 'declineReason': declineReason,
      if (task != null) 'task': task?.toJsonForProtocol(),
      'mergedFrom': mergedFrom.toJson(),
      'score': score,
      'voteCount': voteCount,
      'commentCount': commentCount,
      'myVote': myVote,
      if (author != null) 'author': author?.toJsonForProtocol(),
      'isMine': isMine,
      'canEdit': canEdit,
      'createdAt': createdAt.toJson(),
      if (editedAt != null) 'editedAt': editedAt?.toJson(),
      'deleted': deleted,
      'needsCheck': needsCheck,
      if (suggestedTitle != null) 'suggestedTitle': suggestedTitle,
      if (possibleDuplicateOfNumber != null)
        'possibleDuplicateOfNumber': possibleDuplicateOfNumber,
      if (triageJson != null) 'triageJson': triageJson,
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

class _UndefinedBoardPostView$task extends _isc.UndefinedSentinel
    implements _ik00spaq.BoardTaskRef {
  const _UndefinedBoardPostView$task();
}

class _UndefinedBoardPostView$author extends _isc.UndefinedSentinel
    implements _imhv5g8m.BoardAuthor {
  const _UndefinedBoardPostView$author();
}

class _BoardPostViewImpl extends BoardPostView {
  _BoardPostViewImpl({
    required int number,
    required _i76aj3nz.BoardPostKind kind,
    required _i76aj3nz.BoardPostKind reportedKind,
    _iknrpzcb.BoardArea? area,
    _ibr3u4cf.BoardSize? size,
    required bool aiLabels,
    required String title,
    required String body,
    String? contextJson,
    required String appHint,
    required bool hasScreenshot,
    required _ij83av7d.BoardPostStatus status,
    required _i04stir2.BoardModeration moderation,
    String? moderationReason,
    required bool editedByModerator,
    required _ijfwzb4l.BoardTriageState triageState,
    String? summary,
    int? duplicateOfNumber,
    String? declineReason,
    _ik00spaq.BoardTaskRef? task,
    required List<int> mergedFrom,
    required int score,
    required int voteCount,
    required int commentCount,
    required int myVote,
    _imhv5g8m.BoardAuthor? author,
    required bool isMine,
    required bool canEdit,
    required DateTime createdAt,
    DateTime? editedAt,
    required bool deleted,
    required bool needsCheck,
    String? suggestedTitle,
    int? possibleDuplicateOfNumber,
    String? triageJson,
    List<_ipngornu.BoardFlagView>? flags,
  }) : super._(
         number: number,
         kind: kind,
         reportedKind: reportedKind,
         area: area,
         size: size,
         aiLabels: aiLabels,
         title: title,
         body: body,
         contextJson: contextJson,
         appHint: appHint,
         hasScreenshot: hasScreenshot,
         status: status,
         moderation: moderation,
         moderationReason: moderationReason,
         editedByModerator: editedByModerator,
         triageState: triageState,
         summary: summary,
         duplicateOfNumber: duplicateOfNumber,
         declineReason: declineReason,
         task: task,
         mergedFrom: mergedFrom,
         score: score,
         voteCount: voteCount,
         commentCount: commentCount,
         myVote: myVote,
         author: author,
         isMine: isMine,
         canEdit: canEdit,
         createdAt: createdAt,
         editedAt: editedAt,
         deleted: deleted,
         needsCheck: needsCheck,
         suggestedTitle: suggestedTitle,
         possibleDuplicateOfNumber: possibleDuplicateOfNumber,
         triageJson: triageJson,
         flags: flags,
       );

  /// Returns a shallow copy of this [BoardPostView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardPostView copyWith({
    int? number,
    _i76aj3nz.BoardPostKind? kind,
    _i76aj3nz.BoardPostKind? reportedKind,
    Object? area = _Undefined,
    Object? size = _Undefined,
    bool? aiLabels,
    String? title,
    String? body,
    Object? contextJson = _Undefined,
    String? appHint,
    bool? hasScreenshot,
    _ij83av7d.BoardPostStatus? status,
    _i04stir2.BoardModeration? moderation,
    Object? moderationReason = _Undefined,
    bool? editedByModerator,
    _ijfwzb4l.BoardTriageState? triageState,
    Object? summary = _Undefined,
    Object? duplicateOfNumber = _Undefined,
    Object? declineReason = _Undefined,
    _ik00spaq.BoardTaskRef? task = const _UndefinedBoardPostView$task(),
    List<int>? mergedFrom,
    int? score,
    int? voteCount,
    int? commentCount,
    int? myVote,
    _imhv5g8m.BoardAuthor? author = const _UndefinedBoardPostView$author(),
    bool? isMine,
    bool? canEdit,
    DateTime? createdAt,
    DateTime? editedAt = const _isc.$UndefinedDateTime(),
    bool? deleted,
    bool? needsCheck,
    Object? suggestedTitle = _Undefined,
    Object? possibleDuplicateOfNumber = _Undefined,
    Object? triageJson = _Undefined,
    List<_ipngornu.BoardFlagView>? flags =
        const _isc.$UndefinedList<_ipngornu.BoardFlagView>(),
  }) {
    return BoardPostView(
      number: number ?? this.number,
      kind: kind ?? this.kind,
      reportedKind: reportedKind ?? this.reportedKind,
      area: area is _iknrpzcb.BoardArea? ? area : this.area,
      size: size is _ibr3u4cf.BoardSize? ? size : this.size,
      aiLabels: aiLabels ?? this.aiLabels,
      title: title ?? this.title,
      body: body ?? this.body,
      contextJson: contextJson is String? ? contextJson : this.contextJson,
      appHint: appHint ?? this.appHint,
      hasScreenshot: hasScreenshot ?? this.hasScreenshot,
      status: status ?? this.status,
      moderation: moderation ?? this.moderation,
      moderationReason: moderationReason is String?
          ? moderationReason
          : this.moderationReason,
      editedByModerator: editedByModerator ?? this.editedByModerator,
      triageState: triageState ?? this.triageState,
      summary: summary is String? ? summary : this.summary,
      duplicateOfNumber: duplicateOfNumber is int?
          ? duplicateOfNumber
          : this.duplicateOfNumber,
      declineReason: declineReason is String?
          ? declineReason
          : this.declineReason,
      task: task is _isc.UndefinedSentinel ? this.task?.copyWith() : task,
      mergedFrom: mergedFrom ?? this.mergedFrom.map((e0) => e0).toList(),
      score: score ?? this.score,
      voteCount: voteCount ?? this.voteCount,
      commentCount: commentCount ?? this.commentCount,
      myVote: myVote ?? this.myVote,
      author: author is _isc.UndefinedSentinel
          ? this.author?.copyWith()
          : author,
      isMine: isMine ?? this.isMine,
      canEdit: canEdit ?? this.canEdit,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt is _isc.UndefinedSentinel ? this.editedAt : editedAt,
      deleted: deleted ?? this.deleted,
      needsCheck: needsCheck ?? this.needsCheck,
      suggestedTitle: suggestedTitle is String?
          ? suggestedTitle
          : this.suggestedTitle,
      possibleDuplicateOfNumber: possibleDuplicateOfNumber is int?
          ? possibleDuplicateOfNumber
          : this.possibleDuplicateOfNumber,
      triageJson: triageJson is String? ? triageJson : this.triageJson,
      flags: flags is _isc.UndefinedSentinel
          ? this.flags?.map((e0) => e0.copyWith()).toList()
          : flags,
    );
  }
}
