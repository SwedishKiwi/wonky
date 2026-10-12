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
import '../../platform/comments/comment_anchor_kind.dart' as _if06qrbr;
import '../../platform/comments/comment_status.dart' as _ifhvdxb2;

/// A comment thread on a drive item (specs/07 §2.1).
abstract class CommentThread
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  CommentThread._({
    this.id,
    required this.uuid,
    required this.itemId,
    required this.anchorKind,
    required this.anchorJson,
    this.quotedText,
    _ifhvdxb2.CommentStatus? status,
    required this.createdById,
    required this.createdAt,
    this.updatedAt,
    this.resolvedById,
    this.resolvedAt,
    this.assigneeId,
    this.statusBeforeOrphan,
    this.orphanReasonJson,
    this.suggestionId,
  }) : status = status ?? _ifhvdxb2.CommentStatus.open;

  factory CommentThread({
    int? id,
    required _isc.UuidValue uuid,
    required int itemId,
    required _if06qrbr.CommentAnchorKind anchorKind,
    required String anchorJson,
    String? quotedText,
    _ifhvdxb2.CommentStatus? status,
    required int createdById,
    required DateTime createdAt,
    DateTime? updatedAt,
    int? resolvedById,
    DateTime? resolvedAt,
    int? assigneeId,
    _ifhvdxb2.CommentStatus? statusBeforeOrphan,
    String? orphanReasonJson,
    String? suggestionId,
  }) = _CommentThreadImpl;

  factory CommentThread.fromJson(Map<String, dynamic> jsonSerialization) {
    return CommentThread(
      id: jsonSerialization['id'] as int?,
      uuid: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      itemId: jsonSerialization['itemId'] as int,
      anchorKind: _if06qrbr.CommentAnchorKind.fromJson(
        (jsonSerialization['anchorKind'] as String),
      ),
      anchorJson: jsonSerialization['anchorJson'] as String,
      quotedText: jsonSerialization['quotedText'] as String?,
      status: jsonSerialization['status'] == null
          ? null
          : _ifhvdxb2.CommentStatus.fromJson(
              (jsonSerialization['status'] as String),
            ),
      createdById: jsonSerialization['createdById'] as int,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
      resolvedById: jsonSerialization['resolvedById'] as int?,
      resolvedAt: jsonSerialization['resolvedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['resolvedAt'],
            ),
      assigneeId: jsonSerialization['assigneeId'] as int?,
      statusBeforeOrphan: jsonSerialization['statusBeforeOrphan'] == null
          ? null
          : _ifhvdxb2.CommentStatus.fromJson(
              (jsonSerialization['statusBeforeOrphan'] as String),
            ),
      orphanReasonJson: jsonSerialization['orphanReasonJson'] as String?,
      suggestionId: jsonSerialization['suggestionId'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// Client-supplied (UUIDv7) so offline creation is idempotent. Write
  /// suggestion threads use UUIDv5(documentUuid, "sug:" + id).
  _isc.UuidValue uuid;

  int itemId;

  _if06qrbr.CommentAnchorKind anchorKind;

  /// App-specific anchor JSON (Write 08 §1.1, Sheets 10 §3.1).
  String anchorJson;

  /// Snapshot of the anchored text or value at creation (≤ 500 chars).
  String? quotedText;

  _ifhvdxb2.CommentStatus status;

  int createdById;

  DateTime createdAt;

  DateTime? updatedAt;

  int? resolvedById;

  DateTime? resolvedAt;

  int? assigneeId;

  /// Restored when an orphaned anchor comes back.
  _ifhvdxb2.CommentStatus? statusBeforeOrphan;

  /// e.g. {"kind":"rowDeleted","rowId":…}.
  String? orphanReasonJson;

  /// Write suggestion id when this is a suggestion thread.
  String? suggestionId;

  /// Returns a shallow copy of this [CommentThread]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  CommentThread copyWith({
    int? id,
    _isc.UuidValue? uuid,
    int? itemId,
    _if06qrbr.CommentAnchorKind? anchorKind,
    String? anchorJson,
    String? quotedText,
    _ifhvdxb2.CommentStatus? status,
    int? createdById,
    DateTime? createdAt,
    DateTime? updatedAt = const _isc.$UndefinedDateTime(),
    int? resolvedById,
    DateTime? resolvedAt = const _isc.$UndefinedDateTime(),
    int? assigneeId,
    _ifhvdxb2.CommentStatus? statusBeforeOrphan,
    String? orphanReasonJson,
    String? suggestionId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CommentThread',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      'itemId': itemId,
      'anchorKind': anchorKind.toJson(),
      'anchorJson': anchorJson,
      if (quotedText != null) 'quotedText': quotedText,
      'status': status.toJson(),
      'createdById': createdById,
      'createdAt': createdAt.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      if (resolvedById != null) 'resolvedById': resolvedById,
      if (resolvedAt != null) 'resolvedAt': resolvedAt?.toJson(),
      if (assigneeId != null) 'assigneeId': assigneeId,
      if (statusBeforeOrphan != null)
        'statusBeforeOrphan': statusBeforeOrphan?.toJson(),
      if (orphanReasonJson != null) 'orphanReasonJson': orphanReasonJson,
      if (suggestionId != null) 'suggestionId': suggestionId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CommentThread',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      'itemId': itemId,
      'anchorKind': anchorKind.toJson(),
      'anchorJson': anchorJson,
      if (quotedText != null) 'quotedText': quotedText,
      'status': status.toJson(),
      'createdById': createdById,
      'createdAt': createdAt.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      if (resolvedById != null) 'resolvedById': resolvedById,
      if (resolvedAt != null) 'resolvedAt': resolvedAt?.toJson(),
      if (assigneeId != null) 'assigneeId': assigneeId,
      if (statusBeforeOrphan != null)
        'statusBeforeOrphan': statusBeforeOrphan?.toJson(),
      if (orphanReasonJson != null) 'orphanReasonJson': orphanReasonJson,
      if (suggestionId != null) 'suggestionId': suggestionId,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CommentThreadImpl extends CommentThread {
  _CommentThreadImpl({
    int? id,
    required _isc.UuidValue uuid,
    required int itemId,
    required _if06qrbr.CommentAnchorKind anchorKind,
    required String anchorJson,
    String? quotedText,
    _ifhvdxb2.CommentStatus? status,
    required int createdById,
    required DateTime createdAt,
    DateTime? updatedAt,
    int? resolvedById,
    DateTime? resolvedAt,
    int? assigneeId,
    _ifhvdxb2.CommentStatus? statusBeforeOrphan,
    String? orphanReasonJson,
    String? suggestionId,
  }) : super._(
         id: id,
         uuid: uuid,
         itemId: itemId,
         anchorKind: anchorKind,
         anchorJson: anchorJson,
         quotedText: quotedText,
         status: status,
         createdById: createdById,
         createdAt: createdAt,
         updatedAt: updatedAt,
         resolvedById: resolvedById,
         resolvedAt: resolvedAt,
         assigneeId: assigneeId,
         statusBeforeOrphan: statusBeforeOrphan,
         orphanReasonJson: orphanReasonJson,
         suggestionId: suggestionId,
       );

  /// Returns a shallow copy of this [CommentThread]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  CommentThread copyWith({
    Object? id = _Undefined,
    _isc.UuidValue? uuid,
    int? itemId,
    _if06qrbr.CommentAnchorKind? anchorKind,
    String? anchorJson,
    Object? quotedText = _Undefined,
    _ifhvdxb2.CommentStatus? status,
    int? createdById,
    DateTime? createdAt,
    DateTime? updatedAt = const _isc.$UndefinedDateTime(),
    Object? resolvedById = _Undefined,
    DateTime? resolvedAt = const _isc.$UndefinedDateTime(),
    Object? assigneeId = _Undefined,
    Object? statusBeforeOrphan = _Undefined,
    Object? orphanReasonJson = _Undefined,
    Object? suggestionId = _Undefined,
  }) {
    return CommentThread(
      id: id is int? ? id : this.id,
      uuid: uuid ?? this.uuid,
      itemId: itemId ?? this.itemId,
      anchorKind: anchorKind ?? this.anchorKind,
      anchorJson: anchorJson ?? this.anchorJson,
      quotedText: quotedText is String? ? quotedText : this.quotedText,
      status: status ?? this.status,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt is _isc.UndefinedSentinel
          ? this.updatedAt
          : updatedAt,
      resolvedById: resolvedById is int? ? resolvedById : this.resolvedById,
      resolvedAt: resolvedAt is _isc.UndefinedSentinel
          ? this.resolvedAt
          : resolvedAt,
      assigneeId: assigneeId is int? ? assigneeId : this.assigneeId,
      statusBeforeOrphan: statusBeforeOrphan is _ifhvdxb2.CommentStatus?
          ? statusBeforeOrphan
          : this.statusBeforeOrphan,
      orphanReasonJson: orphanReasonJson is String?
          ? orphanReasonJson
          : this.orphanReasonJson,
      suggestionId: suggestionId is String? ? suggestionId : this.suggestionId,
    );
  }
}
