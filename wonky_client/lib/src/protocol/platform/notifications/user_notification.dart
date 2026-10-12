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
import '../../platform/notifications/notification_kind.dart' as _ike46sel;

/// An in-app notification (specs/07 §4). Named UserNotification so it does
/// not clash with Flutter's `Notification`.
abstract class UserNotification
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  UserNotification._({
    this.id,
    required this.userId,
    required this.kind,
    this.itemId,
    this.actorId,
    required this.payload,
    required this.createdAt,
    this.readAt,
  });

  factory UserNotification({
    int? id,
    required int userId,
    required _ike46sel.NotificationKind kind,
    int? itemId,
    int? actorId,
    required String payload,
    required DateTime createdAt,
    DateTime? readAt,
  }) = _UserNotificationImpl;

  factory UserNotification.fromJson(Map<String, dynamic> jsonSerialization) {
    return UserNotification(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      kind: _ike46sel.NotificationKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      itemId: jsonSerialization['itemId'] as int?,
      actorId: jsonSerialization['actorId'] as int?,
      payload: jsonSerialization['payload'] as String,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      readAt: jsonSerialization['readAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['readAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  _ike46sel.NotificationKind kind;

  int? itemId;

  int? actorId;

  /// JSON payload for rendering (names, quoted text, links).
  String payload;

  DateTime createdAt;

  DateTime? readAt;

  /// Returns a shallow copy of this [UserNotification]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  UserNotification copyWith({
    int? id,
    int? userId,
    _ike46sel.NotificationKind? kind,
    int? itemId,
    int? actorId,
    String? payload,
    DateTime? createdAt,
    DateTime? readAt = const _isc.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserNotification',
      if (id != null) 'id': id,
      'userId': userId,
      'kind': kind.toJson(),
      if (itemId != null) 'itemId': itemId,
      if (actorId != null) 'actorId': actorId,
      'payload': payload,
      'createdAt': createdAt.toJson(),
      if (readAt != null) 'readAt': readAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UserNotification',
      if (id != null) 'id': id,
      'userId': userId,
      'kind': kind.toJson(),
      if (itemId != null) 'itemId': itemId,
      if (actorId != null) 'actorId': actorId,
      'payload': payload,
      'createdAt': createdAt.toJson(),
      if (readAt != null) 'readAt': readAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserNotificationImpl extends UserNotification {
  _UserNotificationImpl({
    int? id,
    required int userId,
    required _ike46sel.NotificationKind kind,
    int? itemId,
    int? actorId,
    required String payload,
    required DateTime createdAt,
    DateTime? readAt,
  }) : super._(
         id: id,
         userId: userId,
         kind: kind,
         itemId: itemId,
         actorId: actorId,
         payload: payload,
         createdAt: createdAt,
         readAt: readAt,
       );

  /// Returns a shallow copy of this [UserNotification]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UserNotification copyWith({
    Object? id = _Undefined,
    int? userId,
    _ike46sel.NotificationKind? kind,
    Object? itemId = _Undefined,
    Object? actorId = _Undefined,
    String? payload,
    DateTime? createdAt,
    DateTime? readAt = const _isc.$UndefinedDateTime(),
  }) {
    return UserNotification(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      kind: kind ?? this.kind,
      itemId: itemId is int? ? itemId : this.itemId,
      actorId: actorId is int? ? actorId : this.actorId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt is _isc.UndefinedSentinel ? this.readAt : readAt,
    );
  }
}
