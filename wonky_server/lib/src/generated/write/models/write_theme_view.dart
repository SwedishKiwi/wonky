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
import '../../platform/users/user_summary.dart' as _itg9e9ms;

abstract class WriteThemeView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  WriteThemeView._({
    required this.uuid,
    required this.name,
    this.description,
    required this.isBuiltin,
    this.builtinKey,
    this.owner,
    required this.schemaVersion,
    required this.version,
    required this.contentHash,
    required this.json,
    required this.updatedAt,
    this.deletedAt,
  });

  factory WriteThemeView({
    required _is.UuidValue uuid,
    required String name,
    String? description,
    required bool isBuiltin,
    String? builtinKey,
    _itg9e9ms.UserSummary? owner,
    required int schemaVersion,
    required int version,
    required String contentHash,
    required String json,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _WriteThemeViewImpl;

  factory WriteThemeView.fromJson(Map<String, dynamic> jsonSerialization) {
    return WriteThemeView(
      uuid: _is.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String?,
      isBuiltin: _is.BoolJsonExtension.fromJson(jsonSerialization['isBuiltin']),
      builtinKey: jsonSerialization['builtinKey'] as String?,
      owner: jsonSerialization['owner'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_itg9e9ms.UserSummary>(
              jsonSerialization['owner'],
            ),
      schemaVersion: jsonSerialization['schemaVersion'] as int,
      version: jsonSerialization['version'] as int,
      contentHash: jsonSerialization['contentHash'] as String,
      json: jsonSerialization['json'] as String,
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
    );
  }

  _is.UuidValue uuid;

  String name;

  String? description;

  bool isBuiltin;

  String? builtinKey;

  _itg9e9ms.UserSummary? owner;

  int schemaVersion;

  int version;

  String contentHash;

  String json;

  DateTime updatedAt;

  DateTime? deletedAt;

  /// Returns a shallow copy of this [WriteThemeView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WriteThemeView copyWith({
    _is.UuidValue? uuid,
    String? name,
    String? description,
    bool? isBuiltin,
    String? builtinKey,
    _itg9e9ms.UserSummary? owner = const _UndefinedWriteThemeView$owner(),
    int? schemaVersion,
    int? version,
    String? contentHash,
    String? json,
    DateTime? updatedAt,
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WriteThemeView',
      'uuid': uuid.toJson(),
      'name': name,
      if (description != null) 'description': description,
      'isBuiltin': isBuiltin,
      if (builtinKey != null) 'builtinKey': builtinKey,
      if (owner != null) 'owner': owner?.toJson(),
      'schemaVersion': schemaVersion,
      'version': version,
      'contentHash': contentHash,
      'json': json,
      'updatedAt': updatedAt.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WriteThemeView',
      'uuid': uuid.toJson(),
      'name': name,
      if (description != null) 'description': description,
      'isBuiltin': isBuiltin,
      if (builtinKey != null) 'builtinKey': builtinKey,
      if (owner != null) 'owner': owner?.toJsonForProtocol(),
      'schemaVersion': schemaVersion,
      'version': version,
      'contentHash': contentHash,
      'json': json,
      'updatedAt': updatedAt.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedWriteThemeView$owner extends _is.UndefinedSentinel
    implements _itg9e9ms.UserSummary {
  const _UndefinedWriteThemeView$owner();
}

class _WriteThemeViewImpl extends WriteThemeView {
  _WriteThemeViewImpl({
    required _is.UuidValue uuid,
    required String name,
    String? description,
    required bool isBuiltin,
    String? builtinKey,
    _itg9e9ms.UserSummary? owner,
    required int schemaVersion,
    required int version,
    required String contentHash,
    required String json,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) : super._(
         uuid: uuid,
         name: name,
         description: description,
         isBuiltin: isBuiltin,
         builtinKey: builtinKey,
         owner: owner,
         schemaVersion: schemaVersion,
         version: version,
         contentHash: contentHash,
         json: json,
         updatedAt: updatedAt,
         deletedAt: deletedAt,
       );

  /// Returns a shallow copy of this [WriteThemeView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WriteThemeView copyWith({
    _is.UuidValue? uuid,
    String? name,
    Object? description = _Undefined,
    bool? isBuiltin,
    Object? builtinKey = _Undefined,
    _itg9e9ms.UserSummary? owner = const _UndefinedWriteThemeView$owner(),
    int? schemaVersion,
    int? version,
    String? contentHash,
    String? json,
    DateTime? updatedAt,
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
  }) {
    return WriteThemeView(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      description: description is String? ? description : this.description,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      builtinKey: builtinKey is String? ? builtinKey : this.builtinKey,
      owner: owner is _is.UndefinedSentinel ? this.owner?.copyWith() : owner,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      version: version ?? this.version,
      contentHash: contentHash ?? this.contentHash,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt is _is.UndefinedSentinel
          ? this.deletedAt
          : deletedAt,
    );
  }
}
