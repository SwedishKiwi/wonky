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
import 'dart:async' as _ida;
import 'package:serverpod/serverpod.dart' as _is;
import '../../../platform/board/models/board_area.dart' as _iknrpzcb;
import '../../../platform/board/models/board_moderation.dart' as _i04stir2;
import '../../../platform/board/models/board_post_kind.dart' as _i76aj3nz;
import '../../../platform/board/models/board_post_status.dart' as _ij83av7d;
import '../../../platform/board/models/board_size.dart' as _ibr3u4cf;
import '../../../platform/board/models/board_triage_state.dart' as _ijfwzb4l;

/// A bug report or improvement idea on the public board (specs/16 §12).
/// The public number (#123) is the row id.
abstract class BoardPost
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  BoardPost._({
    this.id,
    this.authorId,
    required this.kind,
    required this.reportedKind,
    this.area,
    this.size,
    bool? aiLabels,
    required this.title,
    required this.body,
    this.contextJson,
    required this.appHint,
    this.screenshotFileId,
    required this.status,
    required this.moderation,
    this.moderationReason,
    bool? needsCheck,
    bool? editedByModerator,
    required this.triageState,
    this.triageJson,
    int? triageAttempts,
    this.suggestedTitle,
    this.summary,
    this.duplicateOfId,
    this.possibleDuplicateOfId,
    bool? duplicateHintDismissed,
    this.declineReason,
    this.taskId,
    int? score,
    int? voteCount,
    int? commentCount,
    int? flagCount,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.removedAt,
  }) : aiLabels = aiLabels ?? true,
       needsCheck = needsCheck ?? false,
       editedByModerator = editedByModerator ?? false,
       triageAttempts = triageAttempts ?? 0,
       duplicateHintDismissed = duplicateHintDismissed ?? false,
       score = score ?? 0,
       voteCount = voteCount ?? 0,
       commentCount = commentCount ?? 0,
       flagCount = flagCount ?? 0;

  factory BoardPost({
    int? id,
    int? authorId,
    required _i76aj3nz.BoardPostKind kind,
    required _i76aj3nz.BoardPostKind reportedKind,
    _iknrpzcb.BoardArea? area,
    _ibr3u4cf.BoardSize? size,
    bool? aiLabels,
    required String title,
    required String body,
    String? contextJson,
    required String appHint,
    int? screenshotFileId,
    required _ij83av7d.BoardPostStatus status,
    required _i04stir2.BoardModeration moderation,
    String? moderationReason,
    bool? needsCheck,
    bool? editedByModerator,
    required _ijfwzb4l.BoardTriageState triageState,
    String? triageJson,
    int? triageAttempts,
    String? suggestedTitle,
    String? summary,
    int? duplicateOfId,
    int? possibleDuplicateOfId,
    bool? duplicateHintDismissed,
    String? declineReason,
    int? taskId,
    int? score,
    int? voteCount,
    int? commentCount,
    int? flagCount,
    required DateTime createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    DateTime? removedAt,
  }) = _BoardPostImpl;

  factory BoardPost.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardPost(
      id: jsonSerialization['id'] as int?,
      authorId: jsonSerialization['authorId'] as int?,
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
      aiLabels: jsonSerialization['aiLabels'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['aiLabels']),
      title: jsonSerialization['title'] as String,
      body: jsonSerialization['body'] as String,
      contextJson: jsonSerialization['contextJson'] as String?,
      appHint: jsonSerialization['appHint'] as String,
      screenshotFileId: jsonSerialization['screenshotFileId'] as int?,
      status: _ij83av7d.BoardPostStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      moderation: _i04stir2.BoardModeration.fromJson(
        (jsonSerialization['moderation'] as String),
      ),
      moderationReason: jsonSerialization['moderationReason'] as String?,
      needsCheck: jsonSerialization['needsCheck'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['needsCheck']),
      editedByModerator: jsonSerialization['editedByModerator'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['editedByModerator'],
            ),
      triageState: _ijfwzb4l.BoardTriageState.fromJson(
        (jsonSerialization['triageState'] as String),
      ),
      triageJson: jsonSerialization['triageJson'] as String?,
      triageAttempts: jsonSerialization['triageAttempts'] as int?,
      suggestedTitle: jsonSerialization['suggestedTitle'] as String?,
      summary: jsonSerialization['summary'] as String?,
      duplicateOfId: jsonSerialization['duplicateOfId'] as int?,
      possibleDuplicateOfId: jsonSerialization['possibleDuplicateOfId'] as int?,
      duplicateHintDismissed:
          jsonSerialization['duplicateHintDismissed'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['duplicateHintDismissed'],
            ),
      declineReason: jsonSerialization['declineReason'] as String?,
      taskId: jsonSerialization['taskId'] as int?,
      score: jsonSerialization['score'] as int?,
      voteCount: jsonSerialization['voteCount'] as int?,
      commentCount: jsonSerialization['commentCount'] as int?,
      flagCount: jsonSerialization['flagCount'] as int?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      editedAt: jsonSerialization['editedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['editedAt']),
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
      removedAt: jsonSerialization['removedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['removedAt']),
    );
  }

  static final t = BoardPostTable();

  static const db = BoardPostRepository._();

  @override
  int? id;

  int? authorId;

  _i76aj3nz.BoardPostKind kind;

  /// What the author picked (triage may correct [kind]).
  _i76aj3nz.BoardPostKind reportedKind;

  _iknrpzcb.BoardArea? area;

  _ibr3u4cf.BoardSize? size;

  /// The labels come from AI and are not confirmed by an admin yet.
  bool aiLabels;

  String title;

  /// Markdown.
  String body;

  /// Included details (app, version, browser, route…), JSON; public.
  String? contextJson;

  /// The app the post was written in (drive, write, sheets, slides).
  String appHint;

  int? screenshotFileId;

  _ij83av7d.BoardPostStatus status;

  _i04stir2.BoardModeration moderation;

  /// Shown to the author when held or removed.
  String? moderationReason;

  /// Listed in the admin "check" section (a score in the review band).
  bool needsCheck;

  bool editedByModerator;

  _ijfwzb4l.BoardTriageState triageState;

  /// The last triage answers (admins only).
  String? triageJson;

  int triageAttempts;

  String? suggestedTitle;

  String? summary;

  /// Set when merged into another post (status duplicate).
  int? duplicateOfId;

  /// AI hint for admins.
  int? possibleDuplicateOfId;

  /// Admin dismissed the duplicate hint.
  bool duplicateHintDismissed;

  String? declineReason;

  int? taskId;

  int score;

  int voteCount;

  int commentCount;

  int flagCount;

  DateTime createdAt;

  DateTime? editedAt;

  /// Soft delete by the author.
  DateTime? deletedAt;

  /// When moderation became removed (purged after 90 days).
  DateTime? removedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [BoardPost]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardPost copyWith({
    int? id,
    int? authorId,
    _i76aj3nz.BoardPostKind? kind,
    _i76aj3nz.BoardPostKind? reportedKind,
    _iknrpzcb.BoardArea? area,
    _ibr3u4cf.BoardSize? size,
    bool? aiLabels,
    String? title,
    String? body,
    String? contextJson,
    String? appHint,
    int? screenshotFileId,
    _ij83av7d.BoardPostStatus? status,
    _i04stir2.BoardModeration? moderation,
    String? moderationReason,
    bool? needsCheck,
    bool? editedByModerator,
    _ijfwzb4l.BoardTriageState? triageState,
    String? triageJson,
    int? triageAttempts,
    String? suggestedTitle,
    String? summary,
    int? duplicateOfId,
    int? possibleDuplicateOfId,
    bool? duplicateHintDismissed,
    String? declineReason,
    int? taskId,
    int? score,
    int? voteCount,
    int? commentCount,
    int? flagCount,
    DateTime? createdAt,
    DateTime? editedAt = const _is.$UndefinedDateTime(),
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
    DateTime? removedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardPost',
      if (id != null) 'id': id,
      if (authorId != null) 'authorId': authorId,
      'kind': kind.toJson(),
      'reportedKind': reportedKind.toJson(),
      if (area != null) 'area': area?.toJson(),
      if (size != null) 'size': size?.toJson(),
      'aiLabels': aiLabels,
      'title': title,
      'body': body,
      if (contextJson != null) 'contextJson': contextJson,
      'appHint': appHint,
      if (screenshotFileId != null) 'screenshotFileId': screenshotFileId,
      'status': status.toJson(),
      'moderation': moderation.toJson(),
      if (moderationReason != null) 'moderationReason': moderationReason,
      'needsCheck': needsCheck,
      'editedByModerator': editedByModerator,
      'triageState': triageState.toJson(),
      if (triageJson != null) 'triageJson': triageJson,
      'triageAttempts': triageAttempts,
      if (suggestedTitle != null) 'suggestedTitle': suggestedTitle,
      if (summary != null) 'summary': summary,
      if (duplicateOfId != null) 'duplicateOfId': duplicateOfId,
      if (possibleDuplicateOfId != null)
        'possibleDuplicateOfId': possibleDuplicateOfId,
      'duplicateHintDismissed': duplicateHintDismissed,
      if (declineReason != null) 'declineReason': declineReason,
      if (taskId != null) 'taskId': taskId,
      'score': score,
      'voteCount': voteCount,
      'commentCount': commentCount,
      'flagCount': flagCount,
      'createdAt': createdAt.toJson(),
      if (editedAt != null) 'editedAt': editedAt?.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
      if (removedAt != null) 'removedAt': removedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardPost',
      if (id != null) 'id': id,
      if (authorId != null) 'authorId': authorId,
      'kind': kind.toJson(),
      'reportedKind': reportedKind.toJson(),
      if (area != null) 'area': area?.toJson(),
      if (size != null) 'size': size?.toJson(),
      'aiLabels': aiLabels,
      'title': title,
      'body': body,
      if (contextJson != null) 'contextJson': contextJson,
      'appHint': appHint,
      if (screenshotFileId != null) 'screenshotFileId': screenshotFileId,
      'status': status.toJson(),
      'moderation': moderation.toJson(),
      if (moderationReason != null) 'moderationReason': moderationReason,
      'needsCheck': needsCheck,
      'editedByModerator': editedByModerator,
      'triageState': triageState.toJson(),
      if (triageJson != null) 'triageJson': triageJson,
      'triageAttempts': triageAttempts,
      if (suggestedTitle != null) 'suggestedTitle': suggestedTitle,
      if (summary != null) 'summary': summary,
      if (duplicateOfId != null) 'duplicateOfId': duplicateOfId,
      if (possibleDuplicateOfId != null)
        'possibleDuplicateOfId': possibleDuplicateOfId,
      'duplicateHintDismissed': duplicateHintDismissed,
      if (declineReason != null) 'declineReason': declineReason,
      if (taskId != null) 'taskId': taskId,
      'score': score,
      'voteCount': voteCount,
      'commentCount': commentCount,
      'flagCount': flagCount,
      'createdAt': createdAt.toJson(),
      if (editedAt != null) 'editedAt': editedAt?.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
      if (removedAt != null) 'removedAt': removedAt?.toJson(),
    };
  }

  static BoardPostInclude include() {
    return BoardPostInclude._();
  }

  static BoardPostIncludeList includeList({
    _is.WhereExpressionBuilder<BoardPostTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardPostTable>? orderBy,
    _is.OrderByListBuilder<BoardPostTable>? orderByList,
    BoardPostInclude? include,
  }) {
    return BoardPostIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardPost.t),
      orderByList: orderByList?.call(BoardPost.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardPostImpl extends BoardPost {
  _BoardPostImpl({
    int? id,
    int? authorId,
    required _i76aj3nz.BoardPostKind kind,
    required _i76aj3nz.BoardPostKind reportedKind,
    _iknrpzcb.BoardArea? area,
    _ibr3u4cf.BoardSize? size,
    bool? aiLabels,
    required String title,
    required String body,
    String? contextJson,
    required String appHint,
    int? screenshotFileId,
    required _ij83av7d.BoardPostStatus status,
    required _i04stir2.BoardModeration moderation,
    String? moderationReason,
    bool? needsCheck,
    bool? editedByModerator,
    required _ijfwzb4l.BoardTriageState triageState,
    String? triageJson,
    int? triageAttempts,
    String? suggestedTitle,
    String? summary,
    int? duplicateOfId,
    int? possibleDuplicateOfId,
    bool? duplicateHintDismissed,
    String? declineReason,
    int? taskId,
    int? score,
    int? voteCount,
    int? commentCount,
    int? flagCount,
    required DateTime createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    DateTime? removedAt,
  }) : super._(
         id: id,
         authorId: authorId,
         kind: kind,
         reportedKind: reportedKind,
         area: area,
         size: size,
         aiLabels: aiLabels,
         title: title,
         body: body,
         contextJson: contextJson,
         appHint: appHint,
         screenshotFileId: screenshotFileId,
         status: status,
         moderation: moderation,
         moderationReason: moderationReason,
         needsCheck: needsCheck,
         editedByModerator: editedByModerator,
         triageState: triageState,
         triageJson: triageJson,
         triageAttempts: triageAttempts,
         suggestedTitle: suggestedTitle,
         summary: summary,
         duplicateOfId: duplicateOfId,
         possibleDuplicateOfId: possibleDuplicateOfId,
         duplicateHintDismissed: duplicateHintDismissed,
         declineReason: declineReason,
         taskId: taskId,
         score: score,
         voteCount: voteCount,
         commentCount: commentCount,
         flagCount: flagCount,
         createdAt: createdAt,
         editedAt: editedAt,
         deletedAt: deletedAt,
         removedAt: removedAt,
       );

  /// Returns a shallow copy of this [BoardPost]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardPost copyWith({
    Object? id = _Undefined,
    Object? authorId = _Undefined,
    _i76aj3nz.BoardPostKind? kind,
    _i76aj3nz.BoardPostKind? reportedKind,
    Object? area = _Undefined,
    Object? size = _Undefined,
    bool? aiLabels,
    String? title,
    String? body,
    Object? contextJson = _Undefined,
    String? appHint,
    Object? screenshotFileId = _Undefined,
    _ij83av7d.BoardPostStatus? status,
    _i04stir2.BoardModeration? moderation,
    Object? moderationReason = _Undefined,
    bool? needsCheck,
    bool? editedByModerator,
    _ijfwzb4l.BoardTriageState? triageState,
    Object? triageJson = _Undefined,
    int? triageAttempts,
    Object? suggestedTitle = _Undefined,
    Object? summary = _Undefined,
    Object? duplicateOfId = _Undefined,
    Object? possibleDuplicateOfId = _Undefined,
    bool? duplicateHintDismissed,
    Object? declineReason = _Undefined,
    Object? taskId = _Undefined,
    int? score,
    int? voteCount,
    int? commentCount,
    int? flagCount,
    DateTime? createdAt,
    DateTime? editedAt = const _is.$UndefinedDateTime(),
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
    DateTime? removedAt = const _is.$UndefinedDateTime(),
  }) {
    return BoardPost(
      id: id is int? ? id : this.id,
      authorId: authorId is int? ? authorId : this.authorId,
      kind: kind ?? this.kind,
      reportedKind: reportedKind ?? this.reportedKind,
      area: area is _iknrpzcb.BoardArea? ? area : this.area,
      size: size is _ibr3u4cf.BoardSize? ? size : this.size,
      aiLabels: aiLabels ?? this.aiLabels,
      title: title ?? this.title,
      body: body ?? this.body,
      contextJson: contextJson is String? ? contextJson : this.contextJson,
      appHint: appHint ?? this.appHint,
      screenshotFileId: screenshotFileId is int?
          ? screenshotFileId
          : this.screenshotFileId,
      status: status ?? this.status,
      moderation: moderation ?? this.moderation,
      moderationReason: moderationReason is String?
          ? moderationReason
          : this.moderationReason,
      needsCheck: needsCheck ?? this.needsCheck,
      editedByModerator: editedByModerator ?? this.editedByModerator,
      triageState: triageState ?? this.triageState,
      triageJson: triageJson is String? ? triageJson : this.triageJson,
      triageAttempts: triageAttempts ?? this.triageAttempts,
      suggestedTitle: suggestedTitle is String?
          ? suggestedTitle
          : this.suggestedTitle,
      summary: summary is String? ? summary : this.summary,
      duplicateOfId: duplicateOfId is int? ? duplicateOfId : this.duplicateOfId,
      possibleDuplicateOfId: possibleDuplicateOfId is int?
          ? possibleDuplicateOfId
          : this.possibleDuplicateOfId,
      duplicateHintDismissed:
          duplicateHintDismissed ?? this.duplicateHintDismissed,
      declineReason: declineReason is String?
          ? declineReason
          : this.declineReason,
      taskId: taskId is int? ? taskId : this.taskId,
      score: score ?? this.score,
      voteCount: voteCount ?? this.voteCount,
      commentCount: commentCount ?? this.commentCount,
      flagCount: flagCount ?? this.flagCount,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt is _is.UndefinedSentinel ? this.editedAt : editedAt,
      deletedAt: deletedAt is _is.UndefinedSentinel
          ? this.deletedAt
          : deletedAt,
      removedAt: removedAt is _is.UndefinedSentinel
          ? this.removedAt
          : removedAt,
    );
  }
}

class BoardPostUpdateTable extends _is.UpdateTable<BoardPostTable> {
  BoardPostUpdateTable(super.table);

  _is.ColumnValue<int, int> authorId(int? value) => _is.ColumnValue(
    table.authorId,
    value,
  );

  _is.ColumnValue<_i76aj3nz.BoardPostKind, _i76aj3nz.BoardPostKind> kind(
    _i76aj3nz.BoardPostKind value,
  ) => _is.ColumnValue(
    table.kind,
    value,
  );

  _is.ColumnValue<_i76aj3nz.BoardPostKind, _i76aj3nz.BoardPostKind>
  reportedKind(_i76aj3nz.BoardPostKind value) => _is.ColumnValue(
    table.reportedKind,
    value,
  );

  _is.ColumnValue<_iknrpzcb.BoardArea, _iknrpzcb.BoardArea> area(
    _iknrpzcb.BoardArea? value,
  ) => _is.ColumnValue(
    table.area,
    value,
  );

  _is.ColumnValue<_ibr3u4cf.BoardSize, _ibr3u4cf.BoardSize> size(
    _ibr3u4cf.BoardSize? value,
  ) => _is.ColumnValue(
    table.size,
    value,
  );

  _is.ColumnValue<bool, bool> aiLabels(bool value) => _is.ColumnValue(
    table.aiLabels,
    value,
  );

  _is.ColumnValue<String, String> title(String value) => _is.ColumnValue(
    table.title,
    value,
  );

  _is.ColumnValue<String, String> body(String value) => _is.ColumnValue(
    table.body,
    value,
  );

  _is.ColumnValue<String, String> contextJson(String? value) => _is.ColumnValue(
    table.contextJson,
    value,
  );

  _is.ColumnValue<String, String> appHint(String value) => _is.ColumnValue(
    table.appHint,
    value,
  );

  _is.ColumnValue<int, int> screenshotFileId(int? value) => _is.ColumnValue(
    table.screenshotFileId,
    value,
  );

  _is.ColumnValue<_ij83av7d.BoardPostStatus, _ij83av7d.BoardPostStatus> status(
    _ij83av7d.BoardPostStatus value,
  ) => _is.ColumnValue(
    table.status,
    value,
  );

  _is.ColumnValue<_i04stir2.BoardModeration, _i04stir2.BoardModeration>
  moderation(_i04stir2.BoardModeration value) => _is.ColumnValue(
    table.moderation,
    value,
  );

  _is.ColumnValue<String, String> moderationReason(String? value) =>
      _is.ColumnValue(
        table.moderationReason,
        value,
      );

  _is.ColumnValue<bool, bool> needsCheck(bool value) => _is.ColumnValue(
    table.needsCheck,
    value,
  );

  _is.ColumnValue<bool, bool> editedByModerator(bool value) => _is.ColumnValue(
    table.editedByModerator,
    value,
  );

  _is.ColumnValue<_ijfwzb4l.BoardTriageState, _ijfwzb4l.BoardTriageState>
  triageState(_ijfwzb4l.BoardTriageState value) => _is.ColumnValue(
    table.triageState,
    value,
  );

  _is.ColumnValue<String, String> triageJson(String? value) => _is.ColumnValue(
    table.triageJson,
    value,
  );

  _is.ColumnValue<int, int> triageAttempts(int value) => _is.ColumnValue(
    table.triageAttempts,
    value,
  );

  _is.ColumnValue<String, String> suggestedTitle(String? value) =>
      _is.ColumnValue(
        table.suggestedTitle,
        value,
      );

  _is.ColumnValue<String, String> summary(String? value) => _is.ColumnValue(
    table.summary,
    value,
  );

  _is.ColumnValue<int, int> duplicateOfId(int? value) => _is.ColumnValue(
    table.duplicateOfId,
    value,
  );

  _is.ColumnValue<int, int> possibleDuplicateOfId(int? value) =>
      _is.ColumnValue(
        table.possibleDuplicateOfId,
        value,
      );

  _is.ColumnValue<bool, bool> duplicateHintDismissed(bool value) =>
      _is.ColumnValue(
        table.duplicateHintDismissed,
        value,
      );

  _is.ColumnValue<String, String> declineReason(String? value) =>
      _is.ColumnValue(
        table.declineReason,
        value,
      );

  _is.ColumnValue<int, int> taskId(int? value) => _is.ColumnValue(
    table.taskId,
    value,
  );

  _is.ColumnValue<int, int> score(int value) => _is.ColumnValue(
    table.score,
    value,
  );

  _is.ColumnValue<int, int> voteCount(int value) => _is.ColumnValue(
    table.voteCount,
    value,
  );

  _is.ColumnValue<int, int> commentCount(int value) => _is.ColumnValue(
    table.commentCount,
    value,
  );

  _is.ColumnValue<int, int> flagCount(int value) => _is.ColumnValue(
    table.flagCount,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> editedAt(DateTime? value) =>
      _is.ColumnValue(
        table.editedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> deletedAt(DateTime? value) =>
      _is.ColumnValue(
        table.deletedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> removedAt(DateTime? value) =>
      _is.ColumnValue(
        table.removedAt,
        value,
      );
}

class BoardPostTable extends _is.Table<int?> {
  BoardPostTable({super.tableRelation}) : super(tableName: 'board_post') {
    updateTable = BoardPostUpdateTable(this);
    authorId = _is.ColumnInt(
      'authorId',
      this,
    );
    kind = _is.ColumnEnum(
      'kind',
      this,
      _is.EnumSerialization.byName,
    );
    reportedKind = _is.ColumnEnum(
      'reportedKind',
      this,
      _is.EnumSerialization.byName,
    );
    area = _is.ColumnEnum(
      'area',
      this,
      _is.EnumSerialization.byName,
    );
    size = _is.ColumnEnum(
      'size',
      this,
      _is.EnumSerialization.byName,
    );
    aiLabels = _is.ColumnBool(
      'aiLabels',
      this,
      hasDefault: true,
    );
    title = _is.ColumnString(
      'title',
      this,
    );
    body = _is.ColumnString(
      'body',
      this,
    );
    contextJson = _is.ColumnString(
      'contextJson',
      this,
    );
    appHint = _is.ColumnString(
      'appHint',
      this,
    );
    screenshotFileId = _is.ColumnInt(
      'screenshotFileId',
      this,
    );
    status = _is.ColumnEnum(
      'status',
      this,
      _is.EnumSerialization.byName,
    );
    moderation = _is.ColumnEnum(
      'moderation',
      this,
      _is.EnumSerialization.byName,
    );
    moderationReason = _is.ColumnString(
      'moderationReason',
      this,
    );
    needsCheck = _is.ColumnBool(
      'needsCheck',
      this,
      hasDefault: true,
    );
    editedByModerator = _is.ColumnBool(
      'editedByModerator',
      this,
      hasDefault: true,
    );
    triageState = _is.ColumnEnum(
      'triageState',
      this,
      _is.EnumSerialization.byName,
    );
    triageJson = _is.ColumnString(
      'triageJson',
      this,
    );
    triageAttempts = _is.ColumnInt(
      'triageAttempts',
      this,
      hasDefault: true,
    );
    suggestedTitle = _is.ColumnString(
      'suggestedTitle',
      this,
    );
    summary = _is.ColumnString(
      'summary',
      this,
    );
    duplicateOfId = _is.ColumnInt(
      'duplicateOfId',
      this,
    );
    possibleDuplicateOfId = _is.ColumnInt(
      'possibleDuplicateOfId',
      this,
    );
    duplicateHintDismissed = _is.ColumnBool(
      'duplicateHintDismissed',
      this,
      hasDefault: true,
    );
    declineReason = _is.ColumnString(
      'declineReason',
      this,
    );
    taskId = _is.ColumnInt(
      'taskId',
      this,
    );
    score = _is.ColumnInt(
      'score',
      this,
      hasDefault: true,
    );
    voteCount = _is.ColumnInt(
      'voteCount',
      this,
      hasDefault: true,
    );
    commentCount = _is.ColumnInt(
      'commentCount',
      this,
      hasDefault: true,
    );
    flagCount = _is.ColumnInt(
      'flagCount',
      this,
      hasDefault: true,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    editedAt = _is.ColumnDateTime(
      'editedAt',
      this,
    );
    deletedAt = _is.ColumnDateTime(
      'deletedAt',
      this,
    );
    removedAt = _is.ColumnDateTime(
      'removedAt',
      this,
    );
  }

  late final BoardPostUpdateTable updateTable;

  late final _is.ColumnInt authorId;

  late final _is.ColumnEnum<_i76aj3nz.BoardPostKind> kind;

  /// What the author picked (triage may correct [kind]).
  late final _is.ColumnEnum<_i76aj3nz.BoardPostKind> reportedKind;

  late final _is.ColumnEnum<_iknrpzcb.BoardArea> area;

  late final _is.ColumnEnum<_ibr3u4cf.BoardSize> size;

  /// The labels come from AI and are not confirmed by an admin yet.
  late final _is.ColumnBool aiLabels;

  late final _is.ColumnString title;

  /// Markdown.
  late final _is.ColumnString body;

  /// Included details (app, version, browser, route…), JSON; public.
  late final _is.ColumnString contextJson;

  /// The app the post was written in (drive, write, sheets, slides).
  late final _is.ColumnString appHint;

  late final _is.ColumnInt screenshotFileId;

  late final _is.ColumnEnum<_ij83av7d.BoardPostStatus> status;

  late final _is.ColumnEnum<_i04stir2.BoardModeration> moderation;

  /// Shown to the author when held or removed.
  late final _is.ColumnString moderationReason;

  /// Listed in the admin "check" section (a score in the review band).
  late final _is.ColumnBool needsCheck;

  late final _is.ColumnBool editedByModerator;

  late final _is.ColumnEnum<_ijfwzb4l.BoardTriageState> triageState;

  /// The last triage answers (admins only).
  late final _is.ColumnString triageJson;

  late final _is.ColumnInt triageAttempts;

  late final _is.ColumnString suggestedTitle;

  late final _is.ColumnString summary;

  /// Set when merged into another post (status duplicate).
  late final _is.ColumnInt duplicateOfId;

  /// AI hint for admins.
  late final _is.ColumnInt possibleDuplicateOfId;

  /// Admin dismissed the duplicate hint.
  late final _is.ColumnBool duplicateHintDismissed;

  late final _is.ColumnString declineReason;

  late final _is.ColumnInt taskId;

  late final _is.ColumnInt score;

  late final _is.ColumnInt voteCount;

  late final _is.ColumnInt commentCount;

  late final _is.ColumnInt flagCount;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime editedAt;

  /// Soft delete by the author.
  late final _is.ColumnDateTime deletedAt;

  /// When moderation became removed (purged after 90 days).
  late final _is.ColumnDateTime removedAt;

  @override
  List<_is.Column> get columns => [
    id,
    authorId,
    kind,
    reportedKind,
    area,
    size,
    aiLabels,
    title,
    body,
    contextJson,
    appHint,
    screenshotFileId,
    status,
    moderation,
    moderationReason,
    needsCheck,
    editedByModerator,
    triageState,
    triageJson,
    triageAttempts,
    suggestedTitle,
    summary,
    duplicateOfId,
    possibleDuplicateOfId,
    duplicateHintDismissed,
    declineReason,
    taskId,
    score,
    voteCount,
    commentCount,
    flagCount,
    createdAt,
    editedAt,
    deletedAt,
    removedAt,
  ];
}

class BoardPostInclude extends _is.IncludeObject {
  BoardPostInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => BoardPost.t;
}

class BoardPostIncludeList extends _is.IncludeList {
  BoardPostIncludeList._({
    _is.WhereExpressionBuilder<BoardPostTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BoardPost.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => BoardPost.t;
}

class BoardPostRepository {
  const BoardPostRepository._();

  /// Returns a list of [BoardPost]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<BoardPost>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardPostTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardPostTable>? orderBy,
    _is.OrderByListBuilder<BoardPostTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BoardPost>(
      where: where?.call(BoardPost.t),
      orderBy: orderBy?.call(BoardPost.t),
      orderByList: orderByList?.call(BoardPost.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [BoardPost]s matching the given query parameters every time the
  /// source tables are modified.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// Use [throttle] to specify the minimum interval between queries. It can
  /// also be set to `null`, in which case the stream will only be throttled
  /// when its subscription is paused.
  ///
  /// Source tables are collected from the queried table, [where], [orderBy],
  /// [orderByList], and the [include] graph. [alsoTriggerOnTables] is added
  /// to that set. Pass [Table] instances such as `BoardPost.t`.
  ///
  /// Raw [Expression] SQL is not inspected. Tables referenced only in raw
  /// SQL must be passed via [alsoTriggerOnTables].
  ///
  /// The stream always reads committed state and never joins an ambient
  /// [Transaction]. Emissions for a write fire after that write commits.
  ///
  /// Currently only supported on SQLite. Calling this method on PostgreSQL
  /// throws an [UnsupportedError].
  ///
  /// ```dart
  /// var subscription = Persons.db.watch(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// ).listen((persons) {
  ///   // Handle the latest matching rows.
  /// });
  /// ```
  _ida.Stream<List<BoardPost>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardPostTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardPostTable>? orderBy,
    _is.OrderByListBuilder<BoardPostTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<BoardPost>(
      where: where?.call(BoardPost.t),
      orderBy: orderBy?.call(BoardPost.t),
      orderByList: orderByList?.call(BoardPost.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [BoardPost] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<BoardPost?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardPostTable>? where,
    int? offset,
    _is.OrderByBuilder<BoardPostTable>? orderBy,
    _is.OrderByListBuilder<BoardPostTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BoardPost>(
      where: where?.call(BoardPost.t),
      orderBy: orderBy?.call(BoardPost.t),
      orderByList: orderByList?.call(BoardPost.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BoardPost] by its [id] or null if no such row exists.
  Future<BoardPost?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BoardPost>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BoardPost]s in the list and returns the inserted rows.
  ///
  /// The returned [BoardPost]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardPost>> insert(
    _is.DatabaseSession session,
    List<BoardPost> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BoardPost>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BoardPost] and returns the inserted row.
  ///
  /// The returned [BoardPost] will have its `id` field set.
  Future<BoardPost> insertRow(
    _is.DatabaseSession session,
    BoardPost row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BoardPost>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BoardPost]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [BoardPost]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardPost>> upsert(
    _is.DatabaseSession session,
    List<BoardPost> rows, {
    required _is.ColumnSelections<BoardPostTable> conflictColumns,
    _is.ColumnSelections<BoardPostTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardPostTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BoardPost>(
      rows,
      conflictColumns: conflictColumns(BoardPost.t),
      updateColumns: updateColumns?.call(BoardPost.t),
      updateWhere: updateWhere?.call(BoardPost.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BoardPost] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [BoardPost] will have its `id` field set.
  Future<BoardPost?> upsertRow(
    _is.DatabaseSession session,
    BoardPost row, {
    required _is.ColumnSelections<BoardPostTable> conflictColumns,
    _is.ColumnSelections<BoardPostTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardPostTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BoardPost>(
      row,
      conflictColumns: conflictColumns(BoardPost.t),
      updateColumns: updateColumns?.call(BoardPost.t),
      updateWhere: updateWhere?.call(BoardPost.t),
      transaction: transaction,
    );
  }

  /// Updates all [BoardPost]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardPost>> update(
    _is.DatabaseSession session,
    List<BoardPost> rows, {
    _is.ColumnSelections<BoardPostTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BoardPost>(
      rows,
      columns: columns?.call(BoardPost.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BoardPost]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BoardPost> updateRow(
    _is.DatabaseSession session,
    BoardPost row, {
    _is.ColumnSelections<BoardPostTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BoardPost>(
      row,
      columns: columns?.call(BoardPost.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BoardPost] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BoardPost?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BoardPostUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BoardPost>(
      id,
      columnValues: columnValues(BoardPost.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BoardPost]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardPost>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BoardPostUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<BoardPostTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardPostTable>? orderBy,
    _is.OrderByListBuilder<BoardPostTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BoardPost>(
      columnValues: columnValues(BoardPost.t.updateTable),
      where: where(BoardPost.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardPost.t),
      orderByList: orderByList?.call(BoardPost.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BoardPost]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardPost>> delete(
    _is.DatabaseSession session,
    List<BoardPost> rows, {
    _is.OrderByBuilder<BoardPostTable>? orderBy,
    _is.OrderByListBuilder<BoardPostTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BoardPost>(
      rows,
      orderBy: orderBy?.call(BoardPost.t),
      orderByList: orderByList?.call(BoardPost.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BoardPost].
  Future<BoardPost> deleteRow(
    _is.DatabaseSession session,
    BoardPost row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BoardPost>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardPost>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardPostTable> where,
    _is.OrderByBuilder<BoardPostTable>? orderBy,
    _is.OrderByListBuilder<BoardPostTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BoardPost>(
      where: where(BoardPost.t),
      orderBy: orderBy?.call(BoardPost.t),
      orderByList: orderByList?.call(BoardPost.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardPostTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BoardPost>(
      where: where?.call(BoardPost.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BoardPost] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardPostTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BoardPost>(
      where: where(BoardPost.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
