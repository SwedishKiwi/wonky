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
import '../../platform/comments/comment_anchor_kind.dart' as _if06qrbr;
import '../../platform/comments/comment_status.dart' as _ifhvdxb2;
import '../../platform/comments/comment_view.dart' as _iei0dwna;
import '../../platform/users/user_summary.dart' as _itg9e9ms;

abstract class CommentThreadView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  CommentThreadView._({
    required this.uuid,
    required this.itemUuid,
    required this.anchorKind,
    required this.anchorJson,
    this.quotedText,
    required this.status,
    this.createdBy,
    required this.createdAt,
    this.resolvedBy,
    this.resolvedAt,
    this.assignee,
    this.orphanReasonJson,
    this.suggestionId,
    required this.comments,
  });

  factory CommentThreadView({
    required _is.UuidValue uuid,
    required _is.UuidValue itemUuid,
    required _if06qrbr.CommentAnchorKind anchorKind,
    required String anchorJson,
    String? quotedText,
    required _ifhvdxb2.CommentStatus status,
    _itg9e9ms.UserSummary? createdBy,
    required DateTime createdAt,
    _itg9e9ms.UserSummary? resolvedBy,
    DateTime? resolvedAt,
    _itg9e9ms.UserSummary? assignee,
    String? orphanReasonJson,
    String? suggestionId,
    required List<_iei0dwna.CommentView> comments,
  }) = _CommentThreadViewImpl;

  factory CommentThreadView.fromJson(Map<String, dynamic> jsonSerialization) {
    return CommentThreadView(
      uuid: _is.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      itemUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      anchorKind: _if06qrbr.CommentAnchorKind.fromJson(
        (jsonSerialization['anchorKind'] as String),
      ),
      anchorJson: jsonSerialization['anchorJson'] as String,
      quotedText: jsonSerialization['quotedText'] as String?,
      status: _ifhvdxb2.CommentStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      createdBy: jsonSerialization['createdBy'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_itg9e9ms.UserSummary>(
              jsonSerialization['createdBy'],
            ),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      resolvedBy: jsonSerialization['resolvedBy'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_itg9e9ms.UserSummary>(
              jsonSerialization['resolvedBy'],
            ),
      resolvedAt: jsonSerialization['resolvedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['resolvedAt']),
      assignee: jsonSerialization['assignee'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_itg9e9ms.UserSummary>(
              jsonSerialization['assignee'],
            ),
      orphanReasonJson: jsonSerialization['orphanReasonJson'] as String?,
      suggestionId: jsonSerialization['suggestionId'] as String?,
      comments: _il4umwa0.Protocol().deserialize<List<_iei0dwna.CommentView>>(
        jsonSerialization['comments'],
      ),
    );
  }

  _is.UuidValue uuid;

  _is.UuidValue itemUuid;

  _if06qrbr.CommentAnchorKind anchorKind;

  String anchorJson;

  String? quotedText;

  _ifhvdxb2.CommentStatus status;

  _itg9e9ms.UserSummary? createdBy;

  DateTime createdAt;

  _itg9e9ms.UserSummary? resolvedBy;

  DateTime? resolvedAt;

  _itg9e9ms.UserSummary? assignee;

  String? orphanReasonJson;

  String? suggestionId;

  List<_iei0dwna.CommentView> comments;

  /// Returns a shallow copy of this [CommentThreadView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  CommentThreadView copyWith({
    _is.UuidValue? uuid,
    _is.UuidValue? itemUuid,
    _if06qrbr.CommentAnchorKind? anchorKind,
    String? anchorJson,
    String? quotedText,
    _ifhvdxb2.CommentStatus? status,
    _itg9e9ms.UserSummary? createdBy =
        const _UndefinedCommentThreadView$createdBy(),
    DateTime? createdAt,
    _itg9e9ms.UserSummary? resolvedBy =
        const _UndefinedCommentThreadView$createdBy(),
    DateTime? resolvedAt = const _is.$UndefinedDateTime(),
    _itg9e9ms.UserSummary? assignee =
        const _UndefinedCommentThreadView$createdBy(),
    String? orphanReasonJson,
    String? suggestionId,
    List<_iei0dwna.CommentView>? comments,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CommentThreadView',
      'uuid': uuid.toJson(),
      'itemUuid': itemUuid.toJson(),
      'anchorKind': anchorKind.toJson(),
      'anchorJson': anchorJson,
      if (quotedText != null) 'quotedText': quotedText,
      'status': status.toJson(),
      if (createdBy != null) 'createdBy': createdBy?.toJson(),
      'createdAt': createdAt.toJson(),
      if (resolvedBy != null) 'resolvedBy': resolvedBy?.toJson(),
      if (resolvedAt != null) 'resolvedAt': resolvedAt?.toJson(),
      if (assignee != null) 'assignee': assignee?.toJson(),
      if (orphanReasonJson != null) 'orphanReasonJson': orphanReasonJson,
      if (suggestionId != null) 'suggestionId': suggestionId,
      'comments': comments.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CommentThreadView',
      'uuid': uuid.toJson(),
      'itemUuid': itemUuid.toJson(),
      'anchorKind': anchorKind.toJson(),
      'anchorJson': anchorJson,
      if (quotedText != null) 'quotedText': quotedText,
      'status': status.toJson(),
      if (createdBy != null) 'createdBy': createdBy?.toJsonForProtocol(),
      'createdAt': createdAt.toJson(),
      if (resolvedBy != null) 'resolvedBy': resolvedBy?.toJsonForProtocol(),
      if (resolvedAt != null) 'resolvedAt': resolvedAt?.toJson(),
      if (assignee != null) 'assignee': assignee?.toJsonForProtocol(),
      if (orphanReasonJson != null) 'orphanReasonJson': orphanReasonJson,
      if (suggestionId != null) 'suggestionId': suggestionId,
      'comments': comments.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedCommentThreadView$createdBy extends _is.UndefinedSentinel
    implements _itg9e9ms.UserSummary {
  const _UndefinedCommentThreadView$createdBy();
}

class _CommentThreadViewImpl extends CommentThreadView {
  _CommentThreadViewImpl({
    required _is.UuidValue uuid,
    required _is.UuidValue itemUuid,
    required _if06qrbr.CommentAnchorKind anchorKind,
    required String anchorJson,
    String? quotedText,
    required _ifhvdxb2.CommentStatus status,
    _itg9e9ms.UserSummary? createdBy,
    required DateTime createdAt,
    _itg9e9ms.UserSummary? resolvedBy,
    DateTime? resolvedAt,
    _itg9e9ms.UserSummary? assignee,
    String? orphanReasonJson,
    String? suggestionId,
    required List<_iei0dwna.CommentView> comments,
  }) : super._(
         uuid: uuid,
         itemUuid: itemUuid,
         anchorKind: anchorKind,
         anchorJson: anchorJson,
         quotedText: quotedText,
         status: status,
         createdBy: createdBy,
         createdAt: createdAt,
         resolvedBy: resolvedBy,
         resolvedAt: resolvedAt,
         assignee: assignee,
         orphanReasonJson: orphanReasonJson,
         suggestionId: suggestionId,
         comments: comments,
       );

  /// Returns a shallow copy of this [CommentThreadView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  CommentThreadView copyWith({
    _is.UuidValue? uuid,
    _is.UuidValue? itemUuid,
    _if06qrbr.CommentAnchorKind? anchorKind,
    String? anchorJson,
    Object? quotedText = _Undefined,
    _ifhvdxb2.CommentStatus? status,
    _itg9e9ms.UserSummary? createdBy =
        const _UndefinedCommentThreadView$createdBy(),
    DateTime? createdAt,
    _itg9e9ms.UserSummary? resolvedBy =
        const _UndefinedCommentThreadView$createdBy(),
    DateTime? resolvedAt = const _is.$UndefinedDateTime(),
    _itg9e9ms.UserSummary? assignee =
        const _UndefinedCommentThreadView$createdBy(),
    Object? orphanReasonJson = _Undefined,
    Object? suggestionId = _Undefined,
    List<_iei0dwna.CommentView>? comments,
  }) {
    return CommentThreadView(
      uuid: uuid ?? this.uuid,
      itemUuid: itemUuid ?? this.itemUuid,
      anchorKind: anchorKind ?? this.anchorKind,
      anchorJson: anchorJson ?? this.anchorJson,
      quotedText: quotedText is String? ? quotedText : this.quotedText,
      status: status ?? this.status,
      createdBy: createdBy is _is.UndefinedSentinel
          ? this.createdBy?.copyWith()
          : createdBy,
      createdAt: createdAt ?? this.createdAt,
      resolvedBy: resolvedBy is _is.UndefinedSentinel
          ? this.resolvedBy?.copyWith()
          : resolvedBy,
      resolvedAt: resolvedAt is _is.UndefinedSentinel
          ? this.resolvedAt
          : resolvedAt,
      assignee: assignee is _is.UndefinedSentinel
          ? this.assignee?.copyWith()
          : assignee,
      orphanReasonJson: orphanReasonJson is String?
          ? orphanReasonJson
          : this.orphanReasonJson,
      suggestionId: suggestionId is String? ? suggestionId : this.suggestionId,
      comments: comments ?? this.comments.map((e0) => e0.copyWith()).toList(),
    );
  }
}
