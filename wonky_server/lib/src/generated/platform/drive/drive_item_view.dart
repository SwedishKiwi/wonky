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
import '../../platform/common/access_role.dart' as _iv7g6vuy;
import '../../platform/drive/drive_item_kind.dart' as _i26ubj99;
import '../../platform/drive/template_category.dart' as _i4yf368z;
import '../../platform/users/user_summary.dart' as _itg9e9ms;

/// A drive item as seen by the calling user.
abstract class DriveItemView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DriveItemView._({
    required this.uuid,
    required this.kind,
    required this.name,
    this.description,
    this.contentRef,
    this.parentUuid,
    required this.owner,
    required this.role,
    required this.shared,
    this.linkRole,
    this.thumbnailFileId,
    required this.sizeBytes,
    required this.createdAt,
    required this.modifiedAt,
    this.modifiedBy,
    this.trashedAt,
    this.templateOf,
    required this.starred,
    required this.pinnedOffline,
    this.lastOpenedAt,
    this.lastEditedAt,
    required this.editorsCanShare,
    required this.nonEditorsCanExport,
    required this.viewersSeeComments,
  });

  factory DriveItemView({
    required _is.UuidValue uuid,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    String? description,
    _is.UuidValue? contentRef,
    _is.UuidValue? parentUuid,
    required _itg9e9ms.UserSummary owner,
    required _iv7g6vuy.AccessRole role,
    required bool shared,
    _iv7g6vuy.AccessRole? linkRole,
    _is.UuidValue? thumbnailFileId,
    required int sizeBytes,
    required DateTime createdAt,
    required DateTime modifiedAt,
    _itg9e9ms.UserSummary? modifiedBy,
    DateTime? trashedAt,
    _i4yf368z.TemplateCategory? templateOf,
    required bool starred,
    required bool pinnedOffline,
    DateTime? lastOpenedAt,
    DateTime? lastEditedAt,
    required bool editorsCanShare,
    required bool nonEditorsCanExport,
    required bool viewersSeeComments,
  }) = _DriveItemViewImpl;

  factory DriveItemView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveItemView(
      uuid: _is.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      kind: _i26ubj99.DriveItemKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String?,
      contentRef: jsonSerialization['contentRef'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['contentRef'],
            ),
      parentUuid: jsonSerialization['parentUuid'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['parentUuid'],
            ),
      owner: _il4umwa0.Protocol().deserialize<_itg9e9ms.UserSummary>(
        jsonSerialization['owner'],
      ),
      role: _iv7g6vuy.AccessRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
      shared: _is.BoolJsonExtension.fromJson(jsonSerialization['shared']),
      linkRole: jsonSerialization['linkRole'] == null
          ? null
          : _iv7g6vuy.AccessRole.fromJson(
              (jsonSerialization['linkRole'] as String),
            ),
      thumbnailFileId: jsonSerialization['thumbnailFileId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['thumbnailFileId'],
            ),
      sizeBytes: jsonSerialization['sizeBytes'] as int,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      modifiedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['modifiedAt'],
      ),
      modifiedBy: jsonSerialization['modifiedBy'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_itg9e9ms.UserSummary>(
              jsonSerialization['modifiedBy'],
            ),
      trashedAt: jsonSerialization['trashedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['trashedAt']),
      templateOf: jsonSerialization['templateOf'] == null
          ? null
          : _i4yf368z.TemplateCategory.fromJson(
              (jsonSerialization['templateOf'] as String),
            ),
      starred: _is.BoolJsonExtension.fromJson(jsonSerialization['starred']),
      pinnedOffline: _is.BoolJsonExtension.fromJson(
        jsonSerialization['pinnedOffline'],
      ),
      lastOpenedAt: jsonSerialization['lastOpenedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastOpenedAt'],
            ),
      lastEditedAt: jsonSerialization['lastEditedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastEditedAt'],
            ),
      editorsCanShare: _is.BoolJsonExtension.fromJson(
        jsonSerialization['editorsCanShare'],
      ),
      nonEditorsCanExport: _is.BoolJsonExtension.fromJson(
        jsonSerialization['nonEditorsCanExport'],
      ),
      viewersSeeComments: _is.BoolJsonExtension.fromJson(
        jsonSerialization['viewersSeeComments'],
      ),
    );
  }

  _is.UuidValue uuid;

  _i26ubj99.DriveItemKind kind;

  String name;

  String? description;

  _is.UuidValue? contentRef;

  _is.UuidValue? parentUuid;

  _itg9e9ms.UserSummary owner;

  /// The caller's effective role.
  _iv7g6vuy.AccessRole role;

  /// Shared with anyone besides the owner (people or link).
  bool shared;

  _iv7g6vuy.AccessRole? linkRole;

  _is.UuidValue? thumbnailFileId;

  int sizeBytes;

  DateTime createdAt;

  DateTime modifiedAt;

  _itg9e9ms.UserSummary? modifiedBy;

  DateTime? trashedAt;

  _i4yf368z.TemplateCategory? templateOf;

  bool starred;

  bool pinnedOffline;

  DateTime? lastOpenedAt;

  DateTime? lastEditedAt;

  bool editorsCanShare;

  bool nonEditorsCanExport;

  bool viewersSeeComments;

  /// Returns a shallow copy of this [DriveItemView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DriveItemView copyWith({
    _is.UuidValue? uuid,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    String? description,
    _is.UuidValue? contentRef = const _is.$UndefinedUuidValue(),
    _is.UuidValue? parentUuid = const _is.$UndefinedUuidValue(),
    _itg9e9ms.UserSummary? owner,
    _iv7g6vuy.AccessRole? role,
    bool? shared,
    _iv7g6vuy.AccessRole? linkRole,
    _is.UuidValue? thumbnailFileId = const _is.$UndefinedUuidValue(),
    int? sizeBytes,
    DateTime? createdAt,
    DateTime? modifiedAt,
    _itg9e9ms.UserSummary? modifiedBy =
        const _UndefinedDriveItemView$modifiedBy(),
    DateTime? trashedAt = const _is.$UndefinedDateTime(),
    _i4yf368z.TemplateCategory? templateOf,
    bool? starred,
    bool? pinnedOffline,
    DateTime? lastOpenedAt = const _is.$UndefinedDateTime(),
    DateTime? lastEditedAt = const _is.$UndefinedDateTime(),
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveItemView',
      'uuid': uuid.toJson(),
      'kind': kind.toJson(),
      'name': name,
      if (description != null) 'description': description,
      if (contentRef != null) 'contentRef': contentRef?.toJson(),
      if (parentUuid != null) 'parentUuid': parentUuid?.toJson(),
      'owner': owner.toJson(),
      'role': role.toJson(),
      'shared': shared,
      if (linkRole != null) 'linkRole': linkRole?.toJson(),
      if (thumbnailFileId != null) 'thumbnailFileId': thumbnailFileId?.toJson(),
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toJson(),
      'modifiedAt': modifiedAt.toJson(),
      if (modifiedBy != null) 'modifiedBy': modifiedBy?.toJson(),
      if (trashedAt != null) 'trashedAt': trashedAt?.toJson(),
      if (templateOf != null) 'templateOf': templateOf?.toJson(),
      'starred': starred,
      'pinnedOffline': pinnedOffline,
      if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt?.toJson(),
      if (lastEditedAt != null) 'lastEditedAt': lastEditedAt?.toJson(),
      'editorsCanShare': editorsCanShare,
      'nonEditorsCanExport': nonEditorsCanExport,
      'viewersSeeComments': viewersSeeComments,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveItemView',
      'uuid': uuid.toJson(),
      'kind': kind.toJson(),
      'name': name,
      if (description != null) 'description': description,
      if (contentRef != null) 'contentRef': contentRef?.toJson(),
      if (parentUuid != null) 'parentUuid': parentUuid?.toJson(),
      'owner': owner.toJsonForProtocol(),
      'role': role.toJson(),
      'shared': shared,
      if (linkRole != null) 'linkRole': linkRole?.toJson(),
      if (thumbnailFileId != null) 'thumbnailFileId': thumbnailFileId?.toJson(),
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toJson(),
      'modifiedAt': modifiedAt.toJson(),
      if (modifiedBy != null) 'modifiedBy': modifiedBy?.toJsonForProtocol(),
      if (trashedAt != null) 'trashedAt': trashedAt?.toJson(),
      if (templateOf != null) 'templateOf': templateOf?.toJson(),
      'starred': starred,
      'pinnedOffline': pinnedOffline,
      if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt?.toJson(),
      if (lastEditedAt != null) 'lastEditedAt': lastEditedAt?.toJson(),
      'editorsCanShare': editorsCanShare,
      'nonEditorsCanExport': nonEditorsCanExport,
      'viewersSeeComments': viewersSeeComments,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedDriveItemView$modifiedBy extends _is.UndefinedSentinel
    implements _itg9e9ms.UserSummary {
  const _UndefinedDriveItemView$modifiedBy();
}

class _DriveItemViewImpl extends DriveItemView {
  _DriveItemViewImpl({
    required _is.UuidValue uuid,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    String? description,
    _is.UuidValue? contentRef,
    _is.UuidValue? parentUuid,
    required _itg9e9ms.UserSummary owner,
    required _iv7g6vuy.AccessRole role,
    required bool shared,
    _iv7g6vuy.AccessRole? linkRole,
    _is.UuidValue? thumbnailFileId,
    required int sizeBytes,
    required DateTime createdAt,
    required DateTime modifiedAt,
    _itg9e9ms.UserSummary? modifiedBy,
    DateTime? trashedAt,
    _i4yf368z.TemplateCategory? templateOf,
    required bool starred,
    required bool pinnedOffline,
    DateTime? lastOpenedAt,
    DateTime? lastEditedAt,
    required bool editorsCanShare,
    required bool nonEditorsCanExport,
    required bool viewersSeeComments,
  }) : super._(
         uuid: uuid,
         kind: kind,
         name: name,
         description: description,
         contentRef: contentRef,
         parentUuid: parentUuid,
         owner: owner,
         role: role,
         shared: shared,
         linkRole: linkRole,
         thumbnailFileId: thumbnailFileId,
         sizeBytes: sizeBytes,
         createdAt: createdAt,
         modifiedAt: modifiedAt,
         modifiedBy: modifiedBy,
         trashedAt: trashedAt,
         templateOf: templateOf,
         starred: starred,
         pinnedOffline: pinnedOffline,
         lastOpenedAt: lastOpenedAt,
         lastEditedAt: lastEditedAt,
         editorsCanShare: editorsCanShare,
         nonEditorsCanExport: nonEditorsCanExport,
         viewersSeeComments: viewersSeeComments,
       );

  /// Returns a shallow copy of this [DriveItemView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DriveItemView copyWith({
    _is.UuidValue? uuid,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    Object? description = _Undefined,
    _is.UuidValue? contentRef = const _is.$UndefinedUuidValue(),
    _is.UuidValue? parentUuid = const _is.$UndefinedUuidValue(),
    _itg9e9ms.UserSummary? owner,
    _iv7g6vuy.AccessRole? role,
    bool? shared,
    Object? linkRole = _Undefined,
    _is.UuidValue? thumbnailFileId = const _is.$UndefinedUuidValue(),
    int? sizeBytes,
    DateTime? createdAt,
    DateTime? modifiedAt,
    _itg9e9ms.UserSummary? modifiedBy =
        const _UndefinedDriveItemView$modifiedBy(),
    DateTime? trashedAt = const _is.$UndefinedDateTime(),
    Object? templateOf = _Undefined,
    bool? starred,
    bool? pinnedOffline,
    DateTime? lastOpenedAt = const _is.$UndefinedDateTime(),
    DateTime? lastEditedAt = const _is.$UndefinedDateTime(),
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
  }) {
    return DriveItemView(
      uuid: uuid ?? this.uuid,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      description: description is String? ? description : this.description,
      contentRef: contentRef is _is.UndefinedSentinel
          ? this.contentRef
          : contentRef,
      parentUuid: parentUuid is _is.UndefinedSentinel
          ? this.parentUuid
          : parentUuid,
      owner: owner ?? this.owner.copyWith(),
      role: role ?? this.role,
      shared: shared ?? this.shared,
      linkRole: linkRole is _iv7g6vuy.AccessRole? ? linkRole : this.linkRole,
      thumbnailFileId: thumbnailFileId is _is.UndefinedSentinel
          ? this.thumbnailFileId
          : thumbnailFileId,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      modifiedBy: modifiedBy is _is.UndefinedSentinel
          ? this.modifiedBy?.copyWith()
          : modifiedBy,
      trashedAt: trashedAt is _is.UndefinedSentinel
          ? this.trashedAt
          : trashedAt,
      templateOf: templateOf is _i4yf368z.TemplateCategory?
          ? templateOf
          : this.templateOf,
      starred: starred ?? this.starred,
      pinnedOffline: pinnedOffline ?? this.pinnedOffline,
      lastOpenedAt: lastOpenedAt is _is.UndefinedSentinel
          ? this.lastOpenedAt
          : lastOpenedAt,
      lastEditedAt: lastEditedAt is _is.UndefinedSentinel
          ? this.lastEditedAt
          : lastEditedAt,
      editorsCanShare: editorsCanShare ?? this.editorsCanShare,
      nonEditorsCanExport: nonEditorsCanExport ?? this.nonEditorsCanExport,
      viewersSeeComments: viewersSeeComments ?? this.viewersSeeComments,
    );
  }
}
