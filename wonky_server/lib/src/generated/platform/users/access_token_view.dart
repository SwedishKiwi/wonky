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

/// A personal access token without its secret.
abstract class AccessTokenView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AccessTokenView._({
    required this.id,
    required this.name,
    required this.prefix,
    required this.scopes,
    this.expiresAt,
    this.lastUsedAt,
    required this.createdAt,
    this.revokedAt,
  });

  factory AccessTokenView({
    required int id,
    required String name,
    required String prefix,
    required List<String> scopes,
    DateTime? expiresAt,
    DateTime? lastUsedAt,
    required DateTime createdAt,
    DateTime? revokedAt,
  }) = _AccessTokenViewImpl;

  factory AccessTokenView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AccessTokenView(
      id: jsonSerialization['id'] as int,
      name: jsonSerialization['name'] as String,
      prefix: jsonSerialization['prefix'] as String,
      scopes: _il4umwa0.Protocol().deserialize<List<String>>(
        jsonSerialization['scopes'],
      ),
      expiresAt: jsonSerialization['expiresAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['expiresAt']),
      lastUsedAt: jsonSerialization['lastUsedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['lastUsedAt']),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      revokedAt: jsonSerialization['revokedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['revokedAt']),
    );
  }

  int id;

  String name;

  String prefix;

  List<String> scopes;

  DateTime? expiresAt;

  DateTime? lastUsedAt;

  DateTime createdAt;

  DateTime? revokedAt;

  /// Returns a shallow copy of this [AccessTokenView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AccessTokenView copyWith({
    int? id,
    String? name,
    String? prefix,
    List<String>? scopes,
    DateTime? expiresAt = const _is.$UndefinedDateTime(),
    DateTime? lastUsedAt = const _is.$UndefinedDateTime(),
    DateTime? createdAt,
    DateTime? revokedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AccessTokenView',
      'id': id,
      'name': name,
      'prefix': prefix,
      'scopes': scopes.toJson(),
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
      if (lastUsedAt != null) 'lastUsedAt': lastUsedAt?.toJson(),
      'createdAt': createdAt.toJson(),
      if (revokedAt != null) 'revokedAt': revokedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AccessTokenView',
      'id': id,
      'name': name,
      'prefix': prefix,
      'scopes': scopes.toJson(),
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
      if (lastUsedAt != null) 'lastUsedAt': lastUsedAt?.toJson(),
      'createdAt': createdAt.toJson(),
      if (revokedAt != null) 'revokedAt': revokedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _AccessTokenViewImpl extends AccessTokenView {
  _AccessTokenViewImpl({
    required int id,
    required String name,
    required String prefix,
    required List<String> scopes,
    DateTime? expiresAt,
    DateTime? lastUsedAt,
    required DateTime createdAt,
    DateTime? revokedAt,
  }) : super._(
         id: id,
         name: name,
         prefix: prefix,
         scopes: scopes,
         expiresAt: expiresAt,
         lastUsedAt: lastUsedAt,
         createdAt: createdAt,
         revokedAt: revokedAt,
       );

  /// Returns a shallow copy of this [AccessTokenView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AccessTokenView copyWith({
    int? id,
    String? name,
    String? prefix,
    List<String>? scopes,
    DateTime? expiresAt = const _is.$UndefinedDateTime(),
    DateTime? lastUsedAt = const _is.$UndefinedDateTime(),
    DateTime? createdAt,
    DateTime? revokedAt = const _is.$UndefinedDateTime(),
  }) {
    return AccessTokenView(
      id: id ?? this.id,
      name: name ?? this.name,
      prefix: prefix ?? this.prefix,
      scopes: scopes ?? this.scopes.map((e0) => e0).toList(),
      expiresAt: expiresAt is _is.UndefinedSentinel
          ? this.expiresAt
          : expiresAt,
      lastUsedAt: lastUsedAt is _is.UndefinedSentinel
          ? this.lastUsedAt
          : lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      revokedAt: revokedAt is _is.UndefinedSentinel
          ? this.revokedAt
          : revokedAt,
    );
  }
}
