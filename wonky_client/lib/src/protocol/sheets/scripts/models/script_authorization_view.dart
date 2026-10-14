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

/// The caller's script authorization for a spreadsheet.
abstract class ScriptAuthorizationView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ScriptAuthorizationView._({
    required this.scopes,
    this.grantedAt,
  });

  factory ScriptAuthorizationView({
    required List<String> scopes,
    DateTime? grantedAt,
  }) = _ScriptAuthorizationViewImpl;

  factory ScriptAuthorizationView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ScriptAuthorizationView(
      scopes: _i8pkqg1o.Protocol().deserialize<List<String>>(
        jsonSerialization['scopes'],
      ),
      grantedAt: jsonSerialization['grantedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['grantedAt']),
    );
  }

  List<String> scopes;

  DateTime? grantedAt;

  /// Returns a shallow copy of this [ScriptAuthorizationView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ScriptAuthorizationView copyWith({
    List<String>? scopes,
    DateTime? grantedAt = const _isc.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScriptAuthorizationView',
      'scopes': scopes.toJson(),
      if (grantedAt != null) 'grantedAt': grantedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ScriptAuthorizationView',
      'scopes': scopes.toJson(),
      if (grantedAt != null) 'grantedAt': grantedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _ScriptAuthorizationViewImpl extends ScriptAuthorizationView {
  _ScriptAuthorizationViewImpl({
    required List<String> scopes,
    DateTime? grantedAt,
  }) : super._(
         scopes: scopes,
         grantedAt: grantedAt,
       );

  /// Returns a shallow copy of this [ScriptAuthorizationView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ScriptAuthorizationView copyWith({
    List<String>? scopes,
    DateTime? grantedAt = const _isc.$UndefinedDateTime(),
  }) {
    return ScriptAuthorizationView(
      scopes: scopes ?? this.scopes.map((e0) => e0).toList(),
      grantedAt: grantedAt is _isc.UndefinedSentinel
          ? this.grantedAt
          : grantedAt,
    );
  }
}
