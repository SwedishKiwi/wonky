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
import '../../platform/drive/drive_item_kind.dart' as _i26ubj99;
import '../../platform/drive/template_category.dart' as _i4yf368z;

/// A file or folder in Wonky Drive (specs/05 §1, sharing settings 06 §2).
abstract class DriveItem
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DriveItem._({
    this.id,
    _isc.UuidValue? uuid,
    required this.kind,
    required this.name,
    required this.ownerId,
    this.parentId,
    this.description,
    this.contentRef,
    this.thumbnailFileId,
    int? sizeBytes,
    required this.createdAt,
    required this.createdById,
    required this.modifiedAt,
    this.modifiedById,
    this.trashedAt,
    this.trashedById,
    this.templateOf,
    this.templateKey,
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
  }) : uuid = uuid ?? const _isc.Uuid().v7obj(),
       sizeBytes = sizeBytes ?? 0,
       editorsCanShare = editorsCanShare ?? true,
       nonEditorsCanExport = nonEditorsCanExport ?? true,
       viewersSeeComments = viewersSeeComments ?? false;

  factory DriveItem({
    int? id,
    _isc.UuidValue? uuid,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    required int ownerId,
    int? parentId,
    String? description,
    _isc.UuidValue? contentRef,
    _isc.UuidValue? thumbnailFileId,
    int? sizeBytes,
    required DateTime createdAt,
    required int createdById,
    required DateTime modifiedAt,
    int? modifiedById,
    DateTime? trashedAt,
    int? trashedById,
    _i4yf368z.TemplateCategory? templateOf,
    String? templateKey,
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
  }) = _DriveItemImpl;

  factory DriveItem.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveItem(
      id: jsonSerialization['id'] as int?,
      uuid: jsonSerialization['uuid'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      kind: _i26ubj99.DriveItemKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      name: jsonSerialization['name'] as String,
      ownerId: jsonSerialization['ownerId'] as int,
      parentId: jsonSerialization['parentId'] as int?,
      description: jsonSerialization['description'] as String?,
      contentRef: jsonSerialization['contentRef'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['contentRef'],
            ),
      thumbnailFileId: jsonSerialization['thumbnailFileId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['thumbnailFileId'],
            ),
      sizeBytes: jsonSerialization['sizeBytes'] as int?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      createdById: jsonSerialization['createdById'] as int,
      modifiedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['modifiedAt'],
      ),
      modifiedById: jsonSerialization['modifiedById'] as int?,
      trashedAt: jsonSerialization['trashedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['trashedAt']),
      trashedById: jsonSerialization['trashedById'] as int?,
      templateOf: jsonSerialization['templateOf'] == null
          ? null
          : _i4yf368z.TemplateCategory.fromJson(
              (jsonSerialization['templateOf'] as String),
            ),
      templateKey: jsonSerialization['templateKey'] as String?,
      editorsCanShare: jsonSerialization['editorsCanShare'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(
              jsonSerialization['editorsCanShare'],
            ),
      nonEditorsCanExport: jsonSerialization['nonEditorsCanExport'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(
              jsonSerialization['nonEditorsCanExport'],
            ),
      viewersSeeComments: jsonSerialization['viewersSeeComments'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(
              jsonSerialization['viewersSeeComments'],
            ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// Public id used in URLs: /d/<uuid>, /s/<uuid>.
  _isc.UuidValue uuid;

  _i26ubj99.DriveItemKind kind;

  String name;

  int ownerId;

  /// Null = the owner's root.
  int? parentId;

  String? description;

  /// Documents: Document.uuid; spreadsheets: the sync space UUID (= Spreadsheet.id).
  _isc.UuidValue? contentRef;

  _isc.UuidValue? thumbnailFileId;

  int sizeBytes;

  DateTime createdAt;

  int createdById;

  /// Last content modification (any user).
  DateTime modifiedAt;

  int? modifiedById;

  DateTime? trashedAt;

  int? trashedById;

  /// Non-null = this item is a template in the gallery.
  _i4yf368z.TemplateCategory? templateOf;

  /// Built-in template key (gallery seeding), e.g. "write.meeting-notes".
  String? templateKey;

  bool editorsCanShare;

  bool nonEditorsCanExport;

  bool viewersSeeComments;

  /// Returns a shallow copy of this [DriveItem]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DriveItem copyWith({
    int? id,
    _isc.UuidValue? uuid,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    int? ownerId,
    int? parentId,
    String? description,
    _isc.UuidValue? contentRef = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? thumbnailFileId = const _isc.$UndefinedUuidValue(),
    int? sizeBytes,
    DateTime? createdAt,
    int? createdById,
    DateTime? modifiedAt,
    int? modifiedById,
    DateTime? trashedAt = const _isc.$UndefinedDateTime(),
    int? trashedById,
    _i4yf368z.TemplateCategory? templateOf,
    String? templateKey,
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveItem',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      'kind': kind.toJson(),
      'name': name,
      'ownerId': ownerId,
      if (parentId != null) 'parentId': parentId,
      if (description != null) 'description': description,
      if (contentRef != null) 'contentRef': contentRef?.toJson(),
      if (thumbnailFileId != null) 'thumbnailFileId': thumbnailFileId?.toJson(),
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toJson(),
      'createdById': createdById,
      'modifiedAt': modifiedAt.toJson(),
      if (modifiedById != null) 'modifiedById': modifiedById,
      if (trashedAt != null) 'trashedAt': trashedAt?.toJson(),
      if (trashedById != null) 'trashedById': trashedById,
      if (templateOf != null) 'templateOf': templateOf?.toJson(),
      if (templateKey != null) 'templateKey': templateKey,
      'editorsCanShare': editorsCanShare,
      'nonEditorsCanExport': nonEditorsCanExport,
      'viewersSeeComments': viewersSeeComments,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveItem',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      'kind': kind.toJson(),
      'name': name,
      'ownerId': ownerId,
      if (parentId != null) 'parentId': parentId,
      if (description != null) 'description': description,
      if (contentRef != null) 'contentRef': contentRef?.toJson(),
      if (thumbnailFileId != null) 'thumbnailFileId': thumbnailFileId?.toJson(),
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toJson(),
      'createdById': createdById,
      'modifiedAt': modifiedAt.toJson(),
      if (modifiedById != null) 'modifiedById': modifiedById,
      if (trashedAt != null) 'trashedAt': trashedAt?.toJson(),
      if (trashedById != null) 'trashedById': trashedById,
      if (templateOf != null) 'templateOf': templateOf?.toJson(),
      if (templateKey != null) 'templateKey': templateKey,
      'editorsCanShare': editorsCanShare,
      'nonEditorsCanExport': nonEditorsCanExport,
      'viewersSeeComments': viewersSeeComments,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DriveItemImpl extends DriveItem {
  _DriveItemImpl({
    int? id,
    _isc.UuidValue? uuid,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    required int ownerId,
    int? parentId,
    String? description,
    _isc.UuidValue? contentRef,
    _isc.UuidValue? thumbnailFileId,
    int? sizeBytes,
    required DateTime createdAt,
    required int createdById,
    required DateTime modifiedAt,
    int? modifiedById,
    DateTime? trashedAt,
    int? trashedById,
    _i4yf368z.TemplateCategory? templateOf,
    String? templateKey,
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
  }) : super._(
         id: id,
         uuid: uuid,
         kind: kind,
         name: name,
         ownerId: ownerId,
         parentId: parentId,
         description: description,
         contentRef: contentRef,
         thumbnailFileId: thumbnailFileId,
         sizeBytes: sizeBytes,
         createdAt: createdAt,
         createdById: createdById,
         modifiedAt: modifiedAt,
         modifiedById: modifiedById,
         trashedAt: trashedAt,
         trashedById: trashedById,
         templateOf: templateOf,
         templateKey: templateKey,
         editorsCanShare: editorsCanShare,
         nonEditorsCanExport: nonEditorsCanExport,
         viewersSeeComments: viewersSeeComments,
       );

  /// Returns a shallow copy of this [DriveItem]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DriveItem copyWith({
    Object? id = _Undefined,
    _isc.UuidValue? uuid,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    int? ownerId,
    Object? parentId = _Undefined,
    Object? description = _Undefined,
    _isc.UuidValue? contentRef = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? thumbnailFileId = const _isc.$UndefinedUuidValue(),
    int? sizeBytes,
    DateTime? createdAt,
    int? createdById,
    DateTime? modifiedAt,
    Object? modifiedById = _Undefined,
    DateTime? trashedAt = const _isc.$UndefinedDateTime(),
    Object? trashedById = _Undefined,
    Object? templateOf = _Undefined,
    Object? templateKey = _Undefined,
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
  }) {
    return DriveItem(
      id: id is int? ? id : this.id,
      uuid: uuid ?? this.uuid,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      parentId: parentId is int? ? parentId : this.parentId,
      description: description is String? ? description : this.description,
      contentRef: contentRef is _isc.UndefinedSentinel
          ? this.contentRef
          : contentRef,
      thumbnailFileId: thumbnailFileId is _isc.UndefinedSentinel
          ? this.thumbnailFileId
          : thumbnailFileId,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      modifiedById: modifiedById is int? ? modifiedById : this.modifiedById,
      trashedAt: trashedAt is _isc.UndefinedSentinel
          ? this.trashedAt
          : trashedAt,
      trashedById: trashedById is int? ? trashedById : this.trashedById,
      templateOf: templateOf is _i4yf368z.TemplateCategory?
          ? templateOf
          : this.templateOf,
      templateKey: templateKey is String? ? templateKey : this.templateKey,
      editorsCanShare: editorsCanShare ?? this.editorsCanShare,
      nonEditorsCanExport: nonEditorsCanExport ?? this.nonEditorsCanExport,
      viewersSeeComments: viewersSeeComments ?? this.viewersSeeComments,
    );
  }
}
