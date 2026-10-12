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
import '../../platform/drive/drive_item_kind.dart' as _i26ubj99;
import '../../platform/notifications/notification_kind.dart' as _ike46sel;
import '../../platform/users/user_summary.dart' as _itg9e9ms;

abstract class NotificationView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  NotificationView._({
    required this.id,
    required this.kind,
    this.itemUuid,
    this.itemName,
    this.itemKind,
    this.actor,
    required this.payload,
    required this.createdAt,
    this.readAt,
  });

  factory NotificationView({
    required int id,
    required _ike46sel.NotificationKind kind,
    _isc.UuidValue? itemUuid,
    String? itemName,
    _i26ubj99.DriveItemKind? itemKind,
    _itg9e9ms.UserSummary? actor,
    required String payload,
    required DateTime createdAt,
    DateTime? readAt,
  }) = _NotificationViewImpl;

  factory NotificationView.fromJson(Map<String, dynamic> jsonSerialization) {
    return NotificationView(
      id: jsonSerialization['id'] as int,
      kind: _ike46sel.NotificationKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      itemUuid: jsonSerialization['itemUuid'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['itemUuid']),
      itemName: jsonSerialization['itemName'] as String?,
      itemKind: jsonSerialization['itemKind'] == null
          ? null
          : _i26ubj99.DriveItemKind.fromJson(
              (jsonSerialization['itemKind'] as String),
            ),
      actor: jsonSerialization['actor'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_itg9e9ms.UserSummary>(
              jsonSerialization['actor'],
            ),
      payload: jsonSerialization['payload'] as String,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      readAt: jsonSerialization['readAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['readAt']),
    );
  }

  int id;

  _ike46sel.NotificationKind kind;

  _isc.UuidValue? itemUuid;

  String? itemName;

  _i26ubj99.DriveItemKind? itemKind;

  _itg9e9ms.UserSummary? actor;

  String payload;

  DateTime createdAt;

  DateTime? readAt;

  /// Returns a shallow copy of this [NotificationView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  NotificationView copyWith({
    int? id,
    _ike46sel.NotificationKind? kind,
    _isc.UuidValue? itemUuid = const _isc.$UndefinedUuidValue(),
    String? itemName,
    _i26ubj99.DriveItemKind? itemKind,
    _itg9e9ms.UserSummary? actor = const _UndefinedNotificationView$actor(),
    String? payload,
    DateTime? createdAt,
    DateTime? readAt = const _isc.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'NotificationView',
      'id': id,
      'kind': kind.toJson(),
      if (itemUuid != null) 'itemUuid': itemUuid?.toJson(),
      if (itemName != null) 'itemName': itemName,
      if (itemKind != null) 'itemKind': itemKind?.toJson(),
      if (actor != null) 'actor': actor?.toJson(),
      'payload': payload,
      'createdAt': createdAt.toJson(),
      if (readAt != null) 'readAt': readAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'NotificationView',
      'id': id,
      'kind': kind.toJson(),
      if (itemUuid != null) 'itemUuid': itemUuid?.toJson(),
      if (itemName != null) 'itemName': itemName,
      if (itemKind != null) 'itemKind': itemKind?.toJson(),
      if (actor != null) 'actor': actor?.toJsonForProtocol(),
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

class _UndefinedNotificationView$actor extends _isc.UndefinedSentinel
    implements _itg9e9ms.UserSummary {
  const _UndefinedNotificationView$actor();
}

class _NotificationViewImpl extends NotificationView {
  _NotificationViewImpl({
    required int id,
    required _ike46sel.NotificationKind kind,
    _isc.UuidValue? itemUuid,
    String? itemName,
    _i26ubj99.DriveItemKind? itemKind,
    _itg9e9ms.UserSummary? actor,
    required String payload,
    required DateTime createdAt,
    DateTime? readAt,
  }) : super._(
         id: id,
         kind: kind,
         itemUuid: itemUuid,
         itemName: itemName,
         itemKind: itemKind,
         actor: actor,
         payload: payload,
         createdAt: createdAt,
         readAt: readAt,
       );

  /// Returns a shallow copy of this [NotificationView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  NotificationView copyWith({
    int? id,
    _ike46sel.NotificationKind? kind,
    _isc.UuidValue? itemUuid = const _isc.$UndefinedUuidValue(),
    Object? itemName = _Undefined,
    Object? itemKind = _Undefined,
    _itg9e9ms.UserSummary? actor = const _UndefinedNotificationView$actor(),
    String? payload,
    DateTime? createdAt,
    DateTime? readAt = const _isc.$UndefinedDateTime(),
  }) {
    return NotificationView(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      itemUuid: itemUuid is _isc.UndefinedSentinel ? this.itemUuid : itemUuid,
      itemName: itemName is String? ? itemName : this.itemName,
      itemKind: itemKind is _i26ubj99.DriveItemKind? ? itemKind : this.itemKind,
      actor: actor is _isc.UndefinedSentinel ? this.actor?.copyWith() : actor,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt is _isc.UndefinedSentinel ? this.readAt : readAt,
    );
  }
}
