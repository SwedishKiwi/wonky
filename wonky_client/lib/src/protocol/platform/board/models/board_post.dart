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
import '../../../platform/board/models/board_area.dart' as _iknrpzcb;
import '../../../platform/board/models/board_moderation.dart' as _i04stir2;
import '../../../platform/board/models/board_post_kind.dart' as _i76aj3nz;
import '../../../platform/board/models/board_post_status.dart' as _ij83av7d;
import '../../../platform/board/models/board_size.dart' as _ibr3u4cf;
import '../../../platform/board/models/board_triage_state.dart' as _ijfwzb4l;

/// A bug report or improvement idea on the public board (specs/16 §12).
/// The public number (#123) is the row id.
abstract class BoardPost
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
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
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['aiLabels']),
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
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['needsCheck']),
      editedByModerator: jsonSerialization['editedByModerator'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(
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
          : _isc.BoolJsonExtension.fromJson(
              jsonSerialization['duplicateHintDismissed'],
            ),
      declineReason: jsonSerialization['declineReason'] as String?,
      taskId: jsonSerialization['taskId'] as int?,
      score: jsonSerialization['score'] as int?,
      voteCount: jsonSerialization['voteCount'] as int?,
      commentCount: jsonSerialization['commentCount'] as int?,
      flagCount: jsonSerialization['flagCount'] as int?,
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

  /// Returns a shallow copy of this [BoardPost]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
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
    DateTime? editedAt = const _isc.$UndefinedDateTime(),
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
    DateTime? removedAt = const _isc.$UndefinedDateTime(),
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

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
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
  @_isc.useResult
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
    DateTime? editedAt = const _isc.$UndefinedDateTime(),
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
    DateTime? removedAt = const _isc.$UndefinedDateTime(),
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
