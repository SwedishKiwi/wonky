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
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:wonky_client/src/protocol/protocol.dart' as _i8pkqg1o;

/// A Wonky Work user. One row per Serverpod auth user (specs/04 §3).
abstract class UserProfile
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  UserProfile._({
    this.id,
    required this.authUserId,
    this.authUser,
    required this.displayName,
    required this.email,
    this.avatarFileId,
    required this.avatarColor,
    this.locale,
    this.timeZone,
    required this.createdAt,
    this.lastSeenAt,
  });

  factory UserProfile({
    int? id,
    required _isc.UuidValue authUserId,
    _iacc.AuthUser? authUser,
    required String displayName,
    required String email,
    _isc.UuidValue? avatarFileId,
    required String avatarColor,
    String? locale,
    String? timeZone,
    required DateTime createdAt,
    DateTime? lastSeenAt,
  }) = _UserProfileImpl;

  factory UserProfile.fromJson(Map<String, dynamic> jsonSerialization) {
    return UserProfile(
      id: jsonSerialization['id'] as int?,
      authUserId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['authUserId'],
      ),
      authUser: jsonSerialization['authUser'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_iacc.AuthUser>(
              jsonSerialization['authUser'],
            ),
      displayName: jsonSerialization['displayName'] as String,
      email: jsonSerialization['email'] as String,
      avatarFileId: jsonSerialization['avatarFileId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['avatarFileId'],
            ),
      avatarColor: jsonSerialization['avatarColor'] as String,
      locale: jsonSerialization['locale'] as String?,
      timeZone: jsonSerialization['timeZone'] as String?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      lastSeenAt: jsonSerialization['lastSeenAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastSeenAt'],
            ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  _isc.UuidValue authUserId;

  /// The Serverpod auth user. Deleting it deletes the profile.
  _iacc.AuthUser? authUser;

  String displayName;

  /// Lowercased; denormalized for search and mentions.
  String email;

  /// StoredFile.fileUuid of the avatar image (public storage).
  _isc.UuidValue? avatarFileId;

  /// Hex color derived from the user id, used for presence and initials.
  String avatarColor;

  /// BCP-47; null follows the browser/OS.
  String? locale;

  /// IANA; null follows the device.
  String? timeZone;

  DateTime createdAt;

  DateTime? lastSeenAt;

  /// Returns a shallow copy of this [UserProfile]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  UserProfile copyWith({
    int? id,
    _isc.UuidValue? authUserId,
    _iacc.AuthUser? authUser = const _UndefinedUserProfile$authUser(),
    String? displayName,
    String? email,
    _isc.UuidValue? avatarFileId = const _isc.$UndefinedUuidValue(),
    String? avatarColor,
    String? locale,
    String? timeZone,
    DateTime? createdAt,
    DateTime? lastSeenAt = const _isc.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserProfile',
      if (id != null) 'id': id,
      'authUserId': authUserId.toJson(),
      if (authUser != null) 'authUser': authUser?.toJson(),
      'displayName': displayName,
      'email': email,
      if (avatarFileId != null) 'avatarFileId': avatarFileId?.toJson(),
      'avatarColor': avatarColor,
      if (locale != null) 'locale': locale,
      if (timeZone != null) 'timeZone': timeZone,
      'createdAt': createdAt.toJson(),
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UserProfile',
      if (id != null) 'id': id,
      'authUserId': authUserId.toJson(),
      if (authUser != null) 'authUser': authUser?.toJson(),
      'displayName': displayName,
      'email': email,
      if (avatarFileId != null) 'avatarFileId': avatarFileId?.toJson(),
      'avatarColor': avatarColor,
      if (locale != null) 'locale': locale,
      if (timeZone != null) 'timeZone': timeZone,
      'createdAt': createdAt.toJson(),
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedUserProfile$authUser extends _isc.UndefinedSentinel
    implements _iacc.AuthUser {
  const _UndefinedUserProfile$authUser();
}

class _UserProfileImpl extends UserProfile {
  _UserProfileImpl({
    int? id,
    required _isc.UuidValue authUserId,
    _iacc.AuthUser? authUser,
    required String displayName,
    required String email,
    _isc.UuidValue? avatarFileId,
    required String avatarColor,
    String? locale,
    String? timeZone,
    required DateTime createdAt,
    DateTime? lastSeenAt,
  }) : super._(
         id: id,
         authUserId: authUserId,
         authUser: authUser,
         displayName: displayName,
         email: email,
         avatarFileId: avatarFileId,
         avatarColor: avatarColor,
         locale: locale,
         timeZone: timeZone,
         createdAt: createdAt,
         lastSeenAt: lastSeenAt,
       );

  /// Returns a shallow copy of this [UserProfile]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UserProfile copyWith({
    Object? id = _Undefined,
    _isc.UuidValue? authUserId,
    _iacc.AuthUser? authUser = const _UndefinedUserProfile$authUser(),
    String? displayName,
    String? email,
    _isc.UuidValue? avatarFileId = const _isc.$UndefinedUuidValue(),
    String? avatarColor,
    Object? locale = _Undefined,
    Object? timeZone = _Undefined,
    DateTime? createdAt,
    DateTime? lastSeenAt = const _isc.$UndefinedDateTime(),
  }) {
    return UserProfile(
      id: id is int? ? id : this.id,
      authUserId: authUserId ?? this.authUserId,
      authUser: authUser is _isc.UndefinedSentinel
          ? this.authUser?.copyWith()
          : authUser,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarFileId: avatarFileId is _isc.UndefinedSentinel
          ? this.avatarFileId
          : avatarFileId,
      avatarColor: avatarColor ?? this.avatarColor,
      locale: locale is String? ? locale : this.locale,
      timeZone: timeZone is String? ? timeZone : this.timeZone,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt is _isc.UndefinedSentinel
          ? this.lastSeenAt
          : lastSeenAt,
    );
  }
}
