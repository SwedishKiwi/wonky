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

/// Public information about a user, embedded in views (owners, authors,
/// participants).
abstract class UserSummary
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  UserSummary._({
    required this.id,
    required this.uuid,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    required this.avatarColor,
    required this.colorIndex,
  });

  factory UserSummary({
    required int id,
    required _isc.UuidValue uuid,
    required String displayName,
    required String email,
    String? avatarUrl,
    required String avatarColor,
    required int colorIndex,
  }) = _UserSummaryImpl;

  factory UserSummary.fromJson(Map<String, dynamic> jsonSerialization) {
    return UserSummary(
      id: jsonSerialization['id'] as int,
      uuid: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      displayName: jsonSerialization['displayName'] as String,
      email: jsonSerialization['email'] as String,
      avatarUrl: jsonSerialization['avatarUrl'] as String?,
      avatarColor: jsonSerialization['avatarColor'] as String,
      colorIndex: jsonSerialization['colorIndex'] as int,
    );
  }

  int id;

  /// The auth user UUID (used by Sheets synced rows and Write `by` attributes).
  _isc.UuidValue uuid;

  String displayName;

  String email;

  String? avatarUrl;

  String avatarColor;

  /// Stable presence color index (0–11) derived from the user id.
  int colorIndex;

  /// Returns a shallow copy of this [UserSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  UserSummary copyWith({
    int? id,
    _isc.UuidValue? uuid,
    String? displayName,
    String? email,
    String? avatarUrl,
    String? avatarColor,
    int? colorIndex,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserSummary',
      'id': id,
      'uuid': uuid.toJson(),
      'displayName': displayName,
      'email': email,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'avatarColor': avatarColor,
      'colorIndex': colorIndex,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UserSummary',
      'id': id,
      'uuid': uuid.toJson(),
      'displayName': displayName,
      'email': email,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'avatarColor': avatarColor,
      'colorIndex': colorIndex,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserSummaryImpl extends UserSummary {
  _UserSummaryImpl({
    required int id,
    required _isc.UuidValue uuid,
    required String displayName,
    required String email,
    String? avatarUrl,
    required String avatarColor,
    required int colorIndex,
  }) : super._(
         id: id,
         uuid: uuid,
         displayName: displayName,
         email: email,
         avatarUrl: avatarUrl,
         avatarColor: avatarColor,
         colorIndex: colorIndex,
       );

  /// Returns a shallow copy of this [UserSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UserSummary copyWith({
    int? id,
    _isc.UuidValue? uuid,
    String? displayName,
    String? email,
    Object? avatarUrl = _Undefined,
    String? avatarColor,
    int? colorIndex,
  }) {
    return UserSummary(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl is String? ? avatarUrl : this.avatarUrl,
      avatarColor: avatarColor ?? this.avatarColor,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }
}
