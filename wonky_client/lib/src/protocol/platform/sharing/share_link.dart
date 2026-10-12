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

/// Link sharing of an item; one row per item (specs/06 §2.2).
abstract class ShareLink
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ShareLink._({
    this.id,
    required this.itemId,
    required this.token,
    this.role,
    required this.createdById,
    required this.createdAt,
  });

  factory ShareLink({
    int? id,
    required int itemId,
    required String token,
    _iv7g6vuy.AccessRole? role,
    required int createdById,
    required DateTime createdAt,
  }) = _ShareLinkImpl;

  factory ShareLink.fromJson(Map<String, dynamic> jsonSerialization) {
    return ShareLink(
      id: jsonSerialization['id'] as int?,
      itemId: jsonSerialization['itemId'] as int,
      token: jsonSerialization['token'] as String,
      role: jsonSerialization['role'] == null
          ? null
          : _iv7g6vuy.AccessRole.fromJson(
              (jsonSerialization['role'] as String),
            ),
      createdById: jsonSerialization['createdById'] as int,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int itemId;

  /// 22-char random url-safe token.
  String token;

  /// Null = link sharing off ("Restricted").
  _iv7g6vuy.AccessRole? role;

  int createdById;

  DateTime createdAt;

  /// Returns a shallow copy of this [ShareLink]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ShareLink copyWith({
    int? id,
    int? itemId,
    String? token,
    _iv7g6vuy.AccessRole? role,
    int? createdById,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ShareLink',
      if (id != null) 'id': id,
      'itemId': itemId,
      'token': token,
      if (role != null) 'role': role?.toJson(),
      'createdById': createdById,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ShareLink',
      if (id != null) 'id': id,
      'itemId': itemId,
      'token': token,
      if (role != null) 'role': role?.toJson(),
      'createdById': createdById,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ShareLinkImpl extends ShareLink {
  _ShareLinkImpl({
    int? id,
    required int itemId,
    required String token,
    _iv7g6vuy.AccessRole? role,
    required int createdById,
    required DateTime createdAt,
  }) : super._(
         id: id,
         itemId: itemId,
         token: token,
         role: role,
         createdById: createdById,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ShareLink]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ShareLink copyWith({
    Object? id = _Undefined,
    int? itemId,
    String? token,
    Object? role = _Undefined,
    int? createdById,
    DateTime? createdAt,
  }) {
    return ShareLink(
      id: id is int? ? id : this.id,
      itemId: itemId ?? this.itemId,
      token: token ?? this.token,
      role: role is _iv7g6vuy.AccessRole? ? role : this.role,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
