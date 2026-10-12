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
import '../../platform/users/user_summary.dart' as _itg9e9ms;

/// The signed-in user's own profile (`user.getMe`).
abstract class UserProfileView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  UserProfileView._({
    required this.summary,
    this.locale,
    this.timeZone,
    required this.createdAt,
  });

  factory UserProfileView({
    required _itg9e9ms.UserSummary summary,
    String? locale,
    String? timeZone,
    required DateTime createdAt,
  }) = _UserProfileViewImpl;

  factory UserProfileView.fromJson(Map<String, dynamic> jsonSerialization) {
    return UserProfileView(
      summary: _il4umwa0.Protocol().deserialize<_itg9e9ms.UserSummary>(
        jsonSerialization['summary'],
      ),
      locale: jsonSerialization['locale'] as String?,
      timeZone: jsonSerialization['timeZone'] as String?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  _itg9e9ms.UserSummary summary;

  String? locale;

  String? timeZone;

  DateTime createdAt;

  /// Returns a shallow copy of this [UserProfileView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  UserProfileView copyWith({
    _itg9e9ms.UserSummary? summary,
    String? locale,
    String? timeZone,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserProfileView',
      'summary': summary.toJson(),
      if (locale != null) 'locale': locale,
      if (timeZone != null) 'timeZone': timeZone,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UserProfileView',
      'summary': summary.toJsonForProtocol(),
      if (locale != null) 'locale': locale,
      if (timeZone != null) 'timeZone': timeZone,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserProfileViewImpl extends UserProfileView {
  _UserProfileViewImpl({
    required _itg9e9ms.UserSummary summary,
    String? locale,
    String? timeZone,
    required DateTime createdAt,
  }) : super._(
         summary: summary,
         locale: locale,
         timeZone: timeZone,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [UserProfileView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UserProfileView copyWith({
    _itg9e9ms.UserSummary? summary,
    Object? locale = _Undefined,
    Object? timeZone = _Undefined,
    DateTime? createdAt,
  }) {
    return UserProfileView(
      summary: summary ?? this.summary.copyWith(),
      locale: locale is String? ? locale : this.locale,
      timeZone: timeZone is String? ? timeZone : this.timeZone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
