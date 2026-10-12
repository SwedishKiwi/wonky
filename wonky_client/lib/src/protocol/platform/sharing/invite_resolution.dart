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
import '../../platform/common/access_role.dart' as _iv7g6vuy;
import '../../platform/drive/drive_item_kind.dart' as _i26ubj99;

/// Result of resolving a share link token (`sharing.resolveInvite`).
abstract class InviteResolution
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  InviteResolution._({
    required this.itemUuid,
    required this.kind,
    required this.name,
    required this.role,
  });

  factory InviteResolution({
    required _isc.UuidValue itemUuid,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    required _iv7g6vuy.AccessRole role,
  }) = _InviteResolutionImpl;

  factory InviteResolution.fromJson(Map<String, dynamic> jsonSerialization) {
    return InviteResolution(
      itemUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      kind: _i26ubj99.DriveItemKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      name: jsonSerialization['name'] as String,
      role: _iv7g6vuy.AccessRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
    );
  }

  _isc.UuidValue itemUuid;

  _i26ubj99.DriveItemKind kind;

  String name;

  _iv7g6vuy.AccessRole role;

  /// Returns a shallow copy of this [InviteResolution]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  InviteResolution copyWith({
    _isc.UuidValue? itemUuid,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    _iv7g6vuy.AccessRole? role,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'InviteResolution',
      'itemUuid': itemUuid.toJson(),
      'kind': kind.toJson(),
      'name': name,
      'role': role.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'InviteResolution',
      'itemUuid': itemUuid.toJson(),
      'kind': kind.toJson(),
      'name': name,
      'role': role.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _InviteResolutionImpl extends InviteResolution {
  _InviteResolutionImpl({
    required _isc.UuidValue itemUuid,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    required _iv7g6vuy.AccessRole role,
  }) : super._(
         itemUuid: itemUuid,
         kind: kind,
         name: name,
         role: role,
       );

  /// Returns a shallow copy of this [InviteResolution]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  InviteResolution copyWith({
    _isc.UuidValue? itemUuid,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    _iv7g6vuy.AccessRole? role,
  }) {
    return InviteResolution(
      itemUuid: itemUuid ?? this.itemUuid,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }
}
