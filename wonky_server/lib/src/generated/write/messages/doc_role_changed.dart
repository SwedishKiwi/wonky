/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'doc_server_message.dart';

/// The caller's effective role changed; viewers can no longer submit ops.
abstract class DocRoleChanged extends _iototaiw.DocServerMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DocRoleChanged._({required this.role});

  factory DocRoleChanged({required _iv7g6vuy.AccessRole role}) =
      _DocRoleChangedImpl;

  factory DocRoleChanged.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocRoleChanged(
      role: _iv7g6vuy.AccessRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
    );
  }

  _iv7g6vuy.AccessRole role;

  /// Returns a shallow copy of this [DocRoleChanged]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  DocRoleChanged copyWith({_iv7g6vuy.AccessRole? role});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocRoleChanged',
      'role': role.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocRoleChanged',
      'role': role.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _DocRoleChangedImpl extends DocRoleChanged {
  _DocRoleChangedImpl({required _iv7g6vuy.AccessRole role})
    : super._(role: role);

  /// Returns a shallow copy of this [DocRoleChanged]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocRoleChanged copyWith({_iv7g6vuy.AccessRole? role}) {
    return DocRoleChanged(role: role ?? this.role);
  }
}
