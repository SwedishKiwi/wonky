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
import '../../platform/users/user_summary.dart' as _itg9e9ms;
import '../../platform/versions/version_kind.dart' as _i8rqnb03;
import '../../platform/versions/version_storage.dart' as _iozipb7v;

abstract class ItemVersionView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ItemVersionView._({
    required this.id,
    required this.itemUuid,
    required this.kind,
    this.name,
    required this.createdAt,
    required this.authors,
    required this.storageKind,
    this.revision,
    required this.sizeBytes,
  });

  factory ItemVersionView({
    required int id,
    required _isc.UuidValue itemUuid,
    required _i8rqnb03.VersionKind kind,
    String? name,
    required DateTime createdAt,
    required List<_itg9e9ms.UserSummary> authors,
    required _iozipb7v.VersionStorage storageKind,
    int? revision,
    required int sizeBytes,
  }) = _ItemVersionViewImpl;

  factory ItemVersionView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ItemVersionView(
      id: jsonSerialization['id'] as int,
      itemUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      kind: _i8rqnb03.VersionKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      name: jsonSerialization['name'] as String?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      authors: _i8pkqg1o.Protocol().deserialize<List<_itg9e9ms.UserSummary>>(
        jsonSerialization['authors'],
      ),
      storageKind: _iozipb7v.VersionStorage.fromJson(
        (jsonSerialization['storageKind'] as String),
      ),
      revision: jsonSerialization['revision'] as int?,
      sizeBytes: jsonSerialization['sizeBytes'] as int,
    );
  }

  int id;

  _isc.UuidValue itemUuid;

  _i8rqnb03.VersionKind kind;

  String? name;

  DateTime createdAt;

  List<_itg9e9ms.UserSummary> authors;

  _iozipb7v.VersionStorage storageKind;

  int? revision;

  int sizeBytes;

  /// Returns a shallow copy of this [ItemVersionView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ItemVersionView copyWith({
    int? id,
    _isc.UuidValue? itemUuid,
    _i8rqnb03.VersionKind? kind,
    String? name,
    DateTime? createdAt,
    List<_itg9e9ms.UserSummary>? authors,
    _iozipb7v.VersionStorage? storageKind,
    int? revision,
    int? sizeBytes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ItemVersionView',
      'id': id,
      'itemUuid': itemUuid.toJson(),
      'kind': kind.toJson(),
      if (name != null) 'name': name,
      'createdAt': createdAt.toJson(),
      'authors': authors.toJson(valueToJson: (v) => v.toJson()),
      'storageKind': storageKind.toJson(),
      if (revision != null) 'revision': revision,
      'sizeBytes': sizeBytes,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ItemVersionView',
      'id': id,
      'itemUuid': itemUuid.toJson(),
      'kind': kind.toJson(),
      if (name != null) 'name': name,
      'createdAt': createdAt.toJson(),
      'authors': authors.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'storageKind': storageKind.toJson(),
      if (revision != null) 'revision': revision,
      'sizeBytes': sizeBytes,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ItemVersionViewImpl extends ItemVersionView {
  _ItemVersionViewImpl({
    required int id,
    required _isc.UuidValue itemUuid,
    required _i8rqnb03.VersionKind kind,
    String? name,
    required DateTime createdAt,
    required List<_itg9e9ms.UserSummary> authors,
    required _iozipb7v.VersionStorage storageKind,
    int? revision,
    required int sizeBytes,
  }) : super._(
         id: id,
         itemUuid: itemUuid,
         kind: kind,
         name: name,
         createdAt: createdAt,
         authors: authors,
         storageKind: storageKind,
         revision: revision,
         sizeBytes: sizeBytes,
       );

  /// Returns a shallow copy of this [ItemVersionView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ItemVersionView copyWith({
    int? id,
    _isc.UuidValue? itemUuid,
    _i8rqnb03.VersionKind? kind,
    Object? name = _Undefined,
    DateTime? createdAt,
    List<_itg9e9ms.UserSummary>? authors,
    _iozipb7v.VersionStorage? storageKind,
    Object? revision = _Undefined,
    int? sizeBytes,
  }) {
    return ItemVersionView(
      id: id ?? this.id,
      itemUuid: itemUuid ?? this.itemUuid,
      kind: kind ?? this.kind,
      name: name is String? ? name : this.name,
      createdAt: createdAt ?? this.createdAt,
      authors: authors ?? this.authors.map((e0) => e0.copyWith()).toList(),
      storageKind: storageKind ?? this.storageKind,
      revision: revision is int? ? revision : this.revision,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}
