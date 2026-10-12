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

/// A Write theme (Write 06 §5.1). Built-ins are global rows (ownerId null).
abstract class WriteTheme
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  WriteTheme._({
    this.id,
    _isc.UuidValue? uuid,
    this.ownerId,
    required this.isBuiltin,
    this.builtinKey,
    required this.name,
    this.description,
    required this.schemaVersion,
    required this.version,
    required this.json,
    required this.contentHash,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  }) : uuid = uuid ?? const _isc.Uuid().v7obj();

  factory WriteTheme({
    int? id,
    _isc.UuidValue? uuid,
    int? ownerId,
    required bool isBuiltin,
    String? builtinKey,
    required String name,
    String? description,
    required int schemaVersion,
    required int version,
    required String json,
    required String contentHash,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _WriteThemeImpl;

  factory WriteTheme.fromJson(Map<String, dynamic> jsonSerialization) {
    return WriteTheme(
      id: jsonSerialization['id'] as int?,
      uuid: jsonSerialization['uuid'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      ownerId: jsonSerialization['ownerId'] as int?,
      isBuiltin: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['isBuiltin'],
      ),
      builtinKey: jsonSerialization['builtinKey'] as String?,
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String?,
      schemaVersion: jsonSerialization['schemaVersion'] as int,
      version: jsonSerialization['version'] as int,
      json: jsonSerialization['json'] as String,
      contentHash: jsonSerialization['contentHash'] as String,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// Built-ins use UUIDv5("wonky-theme:<key>").
  _isc.UuidValue uuid;

  int? ownerId;

  bool isBuiltin;

  String? builtinKey;

  String name;

  String? description;

  int schemaVersion;

  /// 1-based, +1 on every save (optimistic concurrency).
  int version;

  /// Canonical WriteThemeData JSON.
  String json;

  /// sha256(json).
  String contentHash;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? deletedAt;

  /// Returns a shallow copy of this [WriteTheme]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  WriteTheme copyWith({
    int? id,
    _isc.UuidValue? uuid,
    int? ownerId,
    bool? isBuiltin,
    String? builtinKey,
    String? name,
    String? description,
    int? schemaVersion,
    int? version,
    String? json,
    String? contentHash,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WriteTheme',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      if (ownerId != null) 'ownerId': ownerId,
      'isBuiltin': isBuiltin,
      if (builtinKey != null) 'builtinKey': builtinKey,
      'name': name,
      if (description != null) 'description': description,
      'schemaVersion': schemaVersion,
      'version': version,
      'json': json,
      'contentHash': contentHash,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WriteTheme',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      if (ownerId != null) 'ownerId': ownerId,
      'isBuiltin': isBuiltin,
      if (builtinKey != null) 'builtinKey': builtinKey,
      'name': name,
      if (description != null) 'description': description,
      'schemaVersion': schemaVersion,
      'version': version,
      'json': json,
      'contentHash': contentHash,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WriteThemeImpl extends WriteTheme {
  _WriteThemeImpl({
    int? id,
    _isc.UuidValue? uuid,
    int? ownerId,
    required bool isBuiltin,
    String? builtinKey,
    required String name,
    String? description,
    required int schemaVersion,
    required int version,
    required String json,
    required String contentHash,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) : super._(
         id: id,
         uuid: uuid,
         ownerId: ownerId,
         isBuiltin: isBuiltin,
         builtinKey: builtinKey,
         name: name,
         description: description,
         schemaVersion: schemaVersion,
         version: version,
         json: json,
         contentHash: contentHash,
         createdAt: createdAt,
         updatedAt: updatedAt,
         deletedAt: deletedAt,
       );

  /// Returns a shallow copy of this [WriteTheme]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  WriteTheme copyWith({
    Object? id = _Undefined,
    _isc.UuidValue? uuid,
    Object? ownerId = _Undefined,
    bool? isBuiltin,
    Object? builtinKey = _Undefined,
    String? name,
    Object? description = _Undefined,
    int? schemaVersion,
    int? version,
    String? json,
    String? contentHash,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
  }) {
    return WriteTheme(
      id: id is int? ? id : this.id,
      uuid: uuid ?? this.uuid,
      ownerId: ownerId is int? ? ownerId : this.ownerId,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      builtinKey: builtinKey is String? ? builtinKey : this.builtinKey,
      name: name ?? this.name,
      description: description is String? ? description : this.description,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      version: version ?? this.version,
      json: json ?? this.json,
      contentHash: contentHash ?? this.contentHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt is _isc.UndefinedSentinel
          ? this.deletedAt
          : deletedAt,
    );
  }
}
