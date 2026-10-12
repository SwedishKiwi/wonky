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
import '../../platform/sharing/access_request_outcome.dart' as _iy0p00sl;

abstract class AccessRequest
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AccessRequest._({
    this.id,
    required this.itemId,
    required this.requesterId,
    required this.requestedRole,
    this.message,
    required this.createdAt,
    this.handledAt,
    this.handledById,
    this.outcome,
  });

  factory AccessRequest({
    int? id,
    required int itemId,
    required int requesterId,
    required _iv7g6vuy.AccessRole requestedRole,
    String? message,
    required DateTime createdAt,
    DateTime? handledAt,
    int? handledById,
    _iy0p00sl.AccessRequestOutcome? outcome,
  }) = _AccessRequestImpl;

  factory AccessRequest.fromJson(Map<String, dynamic> jsonSerialization) {
    return AccessRequest(
      id: jsonSerialization['id'] as int?,
      itemId: jsonSerialization['itemId'] as int,
      requesterId: jsonSerialization['requesterId'] as int,
      requestedRole: _iv7g6vuy.AccessRole.fromJson(
        (jsonSerialization['requestedRole'] as String),
      ),
      message: jsonSerialization['message'] as String?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      handledAt: jsonSerialization['handledAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['handledAt']),
      handledById: jsonSerialization['handledById'] as int?,
      outcome: jsonSerialization['outcome'] == null
          ? null
          : _iy0p00sl.AccessRequestOutcome.fromJson(
              (jsonSerialization['outcome'] as String),
            ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int itemId;

  int requesterId;

  _iv7g6vuy.AccessRole requestedRole;

  String? message;

  DateTime createdAt;

  DateTime? handledAt;

  int? handledById;

  _iy0p00sl.AccessRequestOutcome? outcome;

  /// Returns a shallow copy of this [AccessRequest]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AccessRequest copyWith({
    int? id,
    int? itemId,
    int? requesterId,
    _iv7g6vuy.AccessRole? requestedRole,
    String? message,
    DateTime? createdAt,
    DateTime? handledAt = const _isc.$UndefinedDateTime(),
    int? handledById,
    _iy0p00sl.AccessRequestOutcome? outcome,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AccessRequest',
      if (id != null) 'id': id,
      'itemId': itemId,
      'requesterId': requesterId,
      'requestedRole': requestedRole.toJson(),
      if (message != null) 'message': message,
      'createdAt': createdAt.toJson(),
      if (handledAt != null) 'handledAt': handledAt?.toJson(),
      if (handledById != null) 'handledById': handledById,
      if (outcome != null) 'outcome': outcome?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AccessRequest',
      if (id != null) 'id': id,
      'itemId': itemId,
      'requesterId': requesterId,
      'requestedRole': requestedRole.toJson(),
      if (message != null) 'message': message,
      'createdAt': createdAt.toJson(),
      if (handledAt != null) 'handledAt': handledAt?.toJson(),
      if (handledById != null) 'handledById': handledById,
      if (outcome != null) 'outcome': outcome?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AccessRequestImpl extends AccessRequest {
  _AccessRequestImpl({
    int? id,
    required int itemId,
    required int requesterId,
    required _iv7g6vuy.AccessRole requestedRole,
    String? message,
    required DateTime createdAt,
    DateTime? handledAt,
    int? handledById,
    _iy0p00sl.AccessRequestOutcome? outcome,
  }) : super._(
         id: id,
         itemId: itemId,
         requesterId: requesterId,
         requestedRole: requestedRole,
         message: message,
         createdAt: createdAt,
         handledAt: handledAt,
         handledById: handledById,
         outcome: outcome,
       );

  /// Returns a shallow copy of this [AccessRequest]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AccessRequest copyWith({
    Object? id = _Undefined,
    int? itemId,
    int? requesterId,
    _iv7g6vuy.AccessRole? requestedRole,
    Object? message = _Undefined,
    DateTime? createdAt,
    DateTime? handledAt = const _isc.$UndefinedDateTime(),
    Object? handledById = _Undefined,
    Object? outcome = _Undefined,
  }) {
    return AccessRequest(
      id: id is int? ? id : this.id,
      itemId: itemId ?? this.itemId,
      requesterId: requesterId ?? this.requesterId,
      requestedRole: requestedRole ?? this.requestedRole,
      message: message is String? ? message : this.message,
      createdAt: createdAt ?? this.createdAt,
      handledAt: handledAt is _isc.UndefinedSentinel
          ? this.handledAt
          : handledAt,
      handledById: handledById is int? ? handledById : this.handledById,
      outcome: outcome is _iy0p00sl.AccessRequestOutcome?
          ? outcome
          : this.outcome,
    );
  }
}
