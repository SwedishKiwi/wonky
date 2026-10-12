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
import '../../platform/versions/version_kind.dart' as _i8rqnb03;
import '../../platform/versions/version_storage.dart' as _iozipb7v;

/// A version of a drive item (specs/07 §5).
abstract class ItemVersion
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ItemVersion._({
    this.id,
    required this.itemId,
    required this.kind,
    this.name,
    required this.createdAt,
    this.createdById,
    required this.authors,
    required this.storageKind,
    this.revision,
    this.snapshotFileId,
    int? sizeBytes,
  }) : sizeBytes = sizeBytes ?? 0;

  factory ItemVersion({
    int? id,
    required int itemId,
    required _i8rqnb03.VersionKind kind,
    String? name,
    required DateTime createdAt,
    int? createdById,
    required List<int> authors,
    required _iozipb7v.VersionStorage storageKind,
    int? revision,
    _isc.UuidValue? snapshotFileId,
    int? sizeBytes,
  }) = _ItemVersionImpl;

  factory ItemVersion.fromJson(Map<String, dynamic> jsonSerialization) {
    return ItemVersion(
      id: jsonSerialization['id'] as int?,
      itemId: jsonSerialization['itemId'] as int,
      kind: _i8rqnb03.VersionKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      name: jsonSerialization['name'] as String?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      createdById: jsonSerialization['createdById'] as int?,
      authors: _i8pkqg1o.Protocol().deserialize<List<int>>(
        jsonSerialization['authors'],
      ),
      storageKind: _iozipb7v.VersionStorage.fromJson(
        (jsonSerialization['storageKind'] as String),
      ),
      revision: jsonSerialization['revision'] as int?,
      snapshotFileId: jsonSerialization['snapshotFileId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['snapshotFileId'],
            ),
      sizeBytes: jsonSerialization['sizeBytes'] as int?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int itemId;

  _i8rqnb03.VersionKind kind;

  String? name;

  DateTime createdAt;

  int? createdById;

  /// Users who contributed since the previous version.
  List<int> authors;

  _iozipb7v.VersionStorage storageKind;

  int? revision;

  _isc.UuidValue? snapshotFileId;

  int sizeBytes;

  /// Returns a shallow copy of this [ItemVersion]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ItemVersion copyWith({
    int? id,
    int? itemId,
    _i8rqnb03.VersionKind? kind,
    String? name,
    DateTime? createdAt,
    int? createdById,
    List<int>? authors,
    _iozipb7v.VersionStorage? storageKind,
    int? revision,
    _isc.UuidValue? snapshotFileId = const _isc.$UndefinedUuidValue(),
    int? sizeBytes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ItemVersion',
      if (id != null) 'id': id,
      'itemId': itemId,
      'kind': kind.toJson(),
      if (name != null) 'name': name,
      'createdAt': createdAt.toJson(),
      if (createdById != null) 'createdById': createdById,
      'authors': authors.toJson(),
      'storageKind': storageKind.toJson(),
      if (revision != null) 'revision': revision,
      if (snapshotFileId != null) 'snapshotFileId': snapshotFileId?.toJson(),
      'sizeBytes': sizeBytes,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ItemVersion',
      if (id != null) 'id': id,
      'itemId': itemId,
      'kind': kind.toJson(),
      if (name != null) 'name': name,
      'createdAt': createdAt.toJson(),
      if (createdById != null) 'createdById': createdById,
      'authors': authors.toJson(),
      'storageKind': storageKind.toJson(),
      if (revision != null) 'revision': revision,
      if (snapshotFileId != null) 'snapshotFileId': snapshotFileId?.toJson(),
      'sizeBytes': sizeBytes,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ItemVersionImpl extends ItemVersion {
  _ItemVersionImpl({
    int? id,
    required int itemId,
    required _i8rqnb03.VersionKind kind,
    String? name,
    required DateTime createdAt,
    int? createdById,
    required List<int> authors,
    required _iozipb7v.VersionStorage storageKind,
    int? revision,
    _isc.UuidValue? snapshotFileId,
    int? sizeBytes,
  }) : super._(
         id: id,
         itemId: itemId,
         kind: kind,
         name: name,
         createdAt: createdAt,
         createdById: createdById,
         authors: authors,
         storageKind: storageKind,
         revision: revision,
         snapshotFileId: snapshotFileId,
         sizeBytes: sizeBytes,
       );

  /// Returns a shallow copy of this [ItemVersion]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ItemVersion copyWith({
    Object? id = _Undefined,
    int? itemId,
    _i8rqnb03.VersionKind? kind,
    Object? name = _Undefined,
    DateTime? createdAt,
    Object? createdById = _Undefined,
    List<int>? authors,
    _iozipb7v.VersionStorage? storageKind,
    Object? revision = _Undefined,
    _isc.UuidValue? snapshotFileId = const _isc.$UndefinedUuidValue(),
    int? sizeBytes,
  }) {
    return ItemVersion(
      id: id is int? ? id : this.id,
      itemId: itemId ?? this.itemId,
      kind: kind ?? this.kind,
      name: name is String? ? name : this.name,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById is int? ? createdById : this.createdById,
      authors: authors ?? this.authors.map((e0) => e0).toList(),
      storageKind: storageKind ?? this.storageKind,
      revision: revision is int? ? revision : this.revision,
      snapshotFileId: snapshotFileId is _isc.UndefinedSentinel
          ? this.snapshotFileId
          : snapshotFileId,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}
