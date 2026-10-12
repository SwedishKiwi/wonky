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

abstract class ShareLinkView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ShareLinkView._({
    required this.token,
    this.role,
  });

  factory ShareLinkView({
    required String token,
    _iv7g6vuy.AccessRole? role,
  }) = _ShareLinkViewImpl;

  factory ShareLinkView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ShareLinkView(
      token: jsonSerialization['token'] as String,
      role: jsonSerialization['role'] == null
          ? null
          : _iv7g6vuy.AccessRole.fromJson(
              (jsonSerialization['role'] as String),
            ),
    );
  }

  String token;

  /// Null = restricted.
  _iv7g6vuy.AccessRole? role;

  /// Returns a shallow copy of this [ShareLinkView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ShareLinkView copyWith({
    String? token,
    _iv7g6vuy.AccessRole? role,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ShareLinkView',
      'token': token,
      if (role != null) 'role': role?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ShareLinkView',
      'token': token,
      if (role != null) 'role': role?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ShareLinkViewImpl extends ShareLinkView {
  _ShareLinkViewImpl({
    required String token,
    _iv7g6vuy.AccessRole? role,
  }) : super._(
         token: token,
         role: role,
       );

  /// Returns a shallow copy of this [ShareLinkView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ShareLinkView copyWith({
    String? token,
    Object? role = _Undefined,
  }) {
    return ShareLinkView(
      token: token ?? this.token,
      role: role is _iv7g6vuy.AccessRole? ? role : this.role,
    );
  }
}
