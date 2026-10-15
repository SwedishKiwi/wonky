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

/// Board-specific data of a user: GitHub login, blocks.
abstract class BoardUserProfile
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardUserProfile._({
    this.id,
    required this.userId,
    this.githubLogin,
    this.blockedAt,
    this.blockedUntil,
    this.blockedReason,
    this.blockedById,
  });

  factory BoardUserProfile({
    int? id,
    required int userId,
    String? githubLogin,
    DateTime? blockedAt,
    DateTime? blockedUntil,
    String? blockedReason,
    int? blockedById,
  }) = _BoardUserProfileImpl;

  factory BoardUserProfile.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardUserProfile(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      githubLogin: jsonSerialization['githubLogin'] as String?,
      blockedAt: jsonSerialization['blockedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['blockedAt']),
      blockedUntil: jsonSerialization['blockedUntil'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['blockedUntil'],
            ),
      blockedReason: jsonSerialization['blockedReason'] as String?,
      blockedById: jsonSerialization['blockedById'] as int?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  String? githubLogin;

  DateTime? blockedAt;

  DateTime? blockedUntil;

  String? blockedReason;

  int? blockedById;

  /// Returns a shallow copy of this [BoardUserProfile]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardUserProfile copyWith({
    int? id,
    int? userId,
    String? githubLogin,
    DateTime? blockedAt = const _isc.$UndefinedDateTime(),
    DateTime? blockedUntil = const _isc.$UndefinedDateTime(),
    String? blockedReason,
    int? blockedById,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardUserProfile',
      if (id != null) 'id': id,
      'userId': userId,
      if (githubLogin != null) 'githubLogin': githubLogin,
      if (blockedAt != null) 'blockedAt': blockedAt?.toJson(),
      if (blockedUntil != null) 'blockedUntil': blockedUntil?.toJson(),
      if (blockedReason != null) 'blockedReason': blockedReason,
      if (blockedById != null) 'blockedById': blockedById,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardUserProfile',
      if (id != null) 'id': id,
      'userId': userId,
      if (githubLogin != null) 'githubLogin': githubLogin,
      if (blockedAt != null) 'blockedAt': blockedAt?.toJson(),
      if (blockedUntil != null) 'blockedUntil': blockedUntil?.toJson(),
      if (blockedReason != null) 'blockedReason': blockedReason,
      if (blockedById != null) 'blockedById': blockedById,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardUserProfileImpl extends BoardUserProfile {
  _BoardUserProfileImpl({
    int? id,
    required int userId,
    String? githubLogin,
    DateTime? blockedAt,
    DateTime? blockedUntil,
    String? blockedReason,
    int? blockedById,
  }) : super._(
         id: id,
         userId: userId,
         githubLogin: githubLogin,
         blockedAt: blockedAt,
         blockedUntil: blockedUntil,
         blockedReason: blockedReason,
         blockedById: blockedById,
       );

  /// Returns a shallow copy of this [BoardUserProfile]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardUserProfile copyWith({
    Object? id = _Undefined,
    int? userId,
    Object? githubLogin = _Undefined,
    DateTime? blockedAt = const _isc.$UndefinedDateTime(),
    DateTime? blockedUntil = const _isc.$UndefinedDateTime(),
    Object? blockedReason = _Undefined,
    Object? blockedById = _Undefined,
  }) {
    return BoardUserProfile(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      githubLogin: githubLogin is String? ? githubLogin : this.githubLogin,
      blockedAt: blockedAt is _isc.UndefinedSentinel
          ? this.blockedAt
          : blockedAt,
      blockedUntil: blockedUntil is _isc.UndefinedSentinel
          ? this.blockedUntil
          : blockedUntil,
      blockedReason: blockedReason is String?
          ? blockedReason
          : this.blockedReason,
      blockedById: blockedById is int? ? blockedById : this.blockedById,
    );
  }
}
