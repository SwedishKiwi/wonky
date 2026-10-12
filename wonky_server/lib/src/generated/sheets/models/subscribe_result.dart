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
import '../../sheets/models/space_stats.dart' as _ijqzxrw0;

abstract class SubscribeResult
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SubscribeResult._({
    required this.spaceUuid,
    required this.role,
    required this.canWrite,
    required this.alreadyMember,
    required this.stats,
  });

  factory SubscribeResult({
    required _is.UuidValue spaceUuid,
    required _iv7g6vuy.AccessRole role,
    required bool canWrite,
    required bool alreadyMember,
    required _ijqzxrw0.SpaceStats stats,
  }) = _SubscribeResultImpl;

  factory SubscribeResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return SubscribeResult(
      spaceUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spaceUuid'],
      ),
      role: _iv7g6vuy.AccessRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
      canWrite: _is.BoolJsonExtension.fromJson(jsonSerialization['canWrite']),
      alreadyMember: _is.BoolJsonExtension.fromJson(
        jsonSerialization['alreadyMember'],
      ),
      stats: _il4umwa0.Protocol().deserialize<_ijqzxrw0.SpaceStats>(
        jsonSerialization['stats'],
      ),
    );
  }

  _is.UuidValue spaceUuid;

  _iv7g6vuy.AccessRole role;

  /// False for viewers/commenters (space role readOnly).
  bool canWrite;

  /// True when the membership already existed (no sync wait needed).
  bool alreadyMember;

  _ijqzxrw0.SpaceStats stats;

  /// Returns a shallow copy of this [SubscribeResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SubscribeResult copyWith({
    _is.UuidValue? spaceUuid,
    _iv7g6vuy.AccessRole? role,
    bool? canWrite,
    bool? alreadyMember,
    _ijqzxrw0.SpaceStats? stats,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SubscribeResult',
      'spaceUuid': spaceUuid.toJson(),
      'role': role.toJson(),
      'canWrite': canWrite,
      'alreadyMember': alreadyMember,
      'stats': stats.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SubscribeResult',
      'spaceUuid': spaceUuid.toJson(),
      'role': role.toJson(),
      'canWrite': canWrite,
      'alreadyMember': alreadyMember,
      'stats': stats.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _SubscribeResultImpl extends SubscribeResult {
  _SubscribeResultImpl({
    required _is.UuidValue spaceUuid,
    required _iv7g6vuy.AccessRole role,
    required bool canWrite,
    required bool alreadyMember,
    required _ijqzxrw0.SpaceStats stats,
  }) : super._(
         spaceUuid: spaceUuid,
         role: role,
         canWrite: canWrite,
         alreadyMember: alreadyMember,
         stats: stats,
       );

  /// Returns a shallow copy of this [SubscribeResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SubscribeResult copyWith({
    _is.UuidValue? spaceUuid,
    _iv7g6vuy.AccessRole? role,
    bool? canWrite,
    bool? alreadyMember,
    _ijqzxrw0.SpaceStats? stats,
  }) {
    return SubscribeResult(
      spaceUuid: spaceUuid ?? this.spaceUuid,
      role: role ?? this.role,
      canWrite: canWrite ?? this.canWrite,
      alreadyMember: alreadyMember ?? this.alreadyMember,
      stats: stats ?? this.stats.copyWith(),
    );
  }
}
