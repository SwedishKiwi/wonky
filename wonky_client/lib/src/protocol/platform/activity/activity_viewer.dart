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
import '../../platform/common/access_role.dart' as _iv7g6vuy;
import '../../platform/users/user_summary.dart' as _itg9e9ms;

/// A row of the activity dashboard's viewers list.
abstract class ActivityViewer
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ActivityViewer._({
    required this.user,
    this.role,
    required this.lastViewedAt,
    required this.views,
  });

  factory ActivityViewer({
    required _itg9e9ms.UserSummary user,
    _iv7g6vuy.AccessRole? role,
    required DateTime lastViewedAt,
    required int views,
  }) = _ActivityViewerImpl;

  factory ActivityViewer.fromJson(Map<String, dynamic> jsonSerialization) {
    return ActivityViewer(
      user: _i8pkqg1o.Protocol().deserialize<_itg9e9ms.UserSummary>(
        jsonSerialization['user'],
      ),
      role: jsonSerialization['role'] == null
          ? null
          : _iv7g6vuy.AccessRole.fromJson(
              (jsonSerialization['role'] as String),
            ),
      lastViewedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['lastViewedAt'],
      ),
      views: jsonSerialization['views'] as int,
    );
  }

  _itg9e9ms.UserSummary user;

  /// The viewer's current role on the item.
  _iv7g6vuy.AccessRole? role;

  DateTime lastViewedAt;

  /// Views within the dashboard's period.
  int views;

  /// Returns a shallow copy of this [ActivityViewer]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ActivityViewer copyWith({
    _itg9e9ms.UserSummary? user,
    _iv7g6vuy.AccessRole? role,
    DateTime? lastViewedAt,
    int? views,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ActivityViewer',
      'user': user.toJson(),
      if (role != null) 'role': role?.toJson(),
      'lastViewedAt': lastViewedAt.toJson(),
      'views': views,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ActivityViewer',
      'user': user.toJsonForProtocol(),
      if (role != null) 'role': role?.toJson(),
      'lastViewedAt': lastViewedAt.toJson(),
      'views': views,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ActivityViewerImpl extends ActivityViewer {
  _ActivityViewerImpl({
    required _itg9e9ms.UserSummary user,
    _iv7g6vuy.AccessRole? role,
    required DateTime lastViewedAt,
    required int views,
  }) : super._(
         user: user,
         role: role,
         lastViewedAt: lastViewedAt,
         views: views,
       );

  /// Returns a shallow copy of this [ActivityViewer]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ActivityViewer copyWith({
    _itg9e9ms.UserSummary? user,
    Object? role = _Undefined,
    DateTime? lastViewedAt,
    int? views,
  }) {
    return ActivityViewer(
      user: user ?? this.user.copyWith(),
      role: role is _iv7g6vuy.AccessRole? ? role : this.role,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      views: views ?? this.views,
    );
  }
}
