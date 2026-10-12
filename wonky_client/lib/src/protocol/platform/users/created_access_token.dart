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
import '../../platform/users/access_token_view.dart' as _ip0470du;

/// Result of creating a token: the secret is returned exactly once.
abstract class CreatedAccessToken
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  CreatedAccessToken._({
    required this.token,
    required this.secret,
  });

  factory CreatedAccessToken({
    required _ip0470du.AccessTokenView token,
    required String secret,
  }) = _CreatedAccessTokenImpl;

  factory CreatedAccessToken.fromJson(Map<String, dynamic> jsonSerialization) {
    return CreatedAccessToken(
      token: _i8pkqg1o.Protocol().deserialize<_ip0470du.AccessTokenView>(
        jsonSerialization['token'],
      ),
      secret: jsonSerialization['secret'] as String,
    );
  }

  _ip0470du.AccessTokenView token;

  String secret;

  /// Returns a shallow copy of this [CreatedAccessToken]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  CreatedAccessToken copyWith({
    _ip0470du.AccessTokenView? token,
    String? secret,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CreatedAccessToken',
      'token': token.toJson(),
      'secret': secret,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CreatedAccessToken',
      'token': token.toJsonForProtocol(),
      'secret': secret,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _CreatedAccessTokenImpl extends CreatedAccessToken {
  _CreatedAccessTokenImpl({
    required _ip0470du.AccessTokenView token,
    required String secret,
  }) : super._(
         token: token,
         secret: secret,
       );

  /// Returns a shallow copy of this [CreatedAccessToken]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  CreatedAccessToken copyWith({
    _ip0470du.AccessTokenView? token,
    String? secret,
  }) {
    return CreatedAccessToken(
      token: token ?? this.token.copyWith(),
      secret: secret ?? this.secret,
    );
  }
}
