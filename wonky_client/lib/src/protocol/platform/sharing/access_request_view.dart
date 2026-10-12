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

abstract class AccessRequestView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AccessRequestView._({
    required this.id,
    required this.itemUuid,
    required this.requester,
    required this.requestedRole,
    this.message,
    required this.createdAt,
  });

  factory AccessRequestView({
    required int id,
    required _isc.UuidValue itemUuid,
    required _itg9e9ms.UserSummary requester,
    required _iv7g6vuy.AccessRole requestedRole,
    String? message,
    required DateTime createdAt,
  }) = _AccessRequestViewImpl;

  factory AccessRequestView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AccessRequestView(
      id: jsonSerialization['id'] as int,
      itemUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      requester: _i8pkqg1o.Protocol().deserialize<_itg9e9ms.UserSummary>(
        jsonSerialization['requester'],
      ),
      requestedRole: _iv7g6vuy.AccessRole.fromJson(
        (jsonSerialization['requestedRole'] as String),
      ),
      message: jsonSerialization['message'] as String?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  int id;

  _isc.UuidValue itemUuid;

  _itg9e9ms.UserSummary requester;

  _iv7g6vuy.AccessRole requestedRole;

  String? message;

  DateTime createdAt;

  /// Returns a shallow copy of this [AccessRequestView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AccessRequestView copyWith({
    int? id,
    _isc.UuidValue? itemUuid,
    _itg9e9ms.UserSummary? requester,
    _iv7g6vuy.AccessRole? requestedRole,
    String? message,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AccessRequestView',
      'id': id,
      'itemUuid': itemUuid.toJson(),
      'requester': requester.toJson(),
      'requestedRole': requestedRole.toJson(),
      if (message != null) 'message': message,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AccessRequestView',
      'id': id,
      'itemUuid': itemUuid.toJson(),
      'requester': requester.toJsonForProtocol(),
      'requestedRole': requestedRole.toJson(),
      if (message != null) 'message': message,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AccessRequestViewImpl extends AccessRequestView {
  _AccessRequestViewImpl({
    required int id,
    required _isc.UuidValue itemUuid,
    required _itg9e9ms.UserSummary requester,
    required _iv7g6vuy.AccessRole requestedRole,
    String? message,
    required DateTime createdAt,
  }) : super._(
         id: id,
         itemUuid: itemUuid,
         requester: requester,
         requestedRole: requestedRole,
         message: message,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [AccessRequestView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AccessRequestView copyWith({
    int? id,
    _isc.UuidValue? itemUuid,
    _itg9e9ms.UserSummary? requester,
    _iv7g6vuy.AccessRole? requestedRole,
    Object? message = _Undefined,
    DateTime? createdAt,
  }) {
    return AccessRequestView(
      id: id ?? this.id,
      itemUuid: itemUuid ?? this.itemUuid,
      requester: requester ?? this.requester.copyWith(),
      requestedRole: requestedRole ?? this.requestedRole,
      message: message is String? ? message : this.message,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
