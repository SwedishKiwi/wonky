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
import '../../platform/notifications/notification_view.dart' as _idqc661j;

/// A live notification change (`notification.watch`).
abstract class NotificationEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  NotificationEvent._({
    this.notification,
    required this.unreadCount,
  });

  factory NotificationEvent({
    _idqc661j.NotificationView? notification,
    required int unreadCount,
  }) = _NotificationEventImpl;

  factory NotificationEvent.fromJson(Map<String, dynamic> jsonSerialization) {
    return NotificationEvent(
      notification: jsonSerialization['notification'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_idqc661j.NotificationView>(
              jsonSerialization['notification'],
            ),
      unreadCount: jsonSerialization['unreadCount'] as int,
    );
  }

  /// The new notification, or null when only the unread count changed.
  _idqc661j.NotificationView? notification;

  int unreadCount;

  /// Returns a shallow copy of this [NotificationEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  NotificationEvent copyWith({
    _idqc661j.NotificationView? notification =
        const _UndefinedNotificationEvent$notification(),
    int? unreadCount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'NotificationEvent',
      if (notification != null) 'notification': notification?.toJson(),
      'unreadCount': unreadCount,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'NotificationEvent',
      if (notification != null)
        'notification': notification?.toJsonForProtocol(),
      'unreadCount': unreadCount,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _UndefinedNotificationEvent$notification extends _isc.UndefinedSentinel
    implements _idqc661j.NotificationView {
  const _UndefinedNotificationEvent$notification();
}

class _NotificationEventImpl extends NotificationEvent {
  _NotificationEventImpl({
    _idqc661j.NotificationView? notification,
    required int unreadCount,
  }) : super._(
         notification: notification,
         unreadCount: unreadCount,
       );

  /// Returns a shallow copy of this [NotificationEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  NotificationEvent copyWith({
    _idqc661j.NotificationView? notification =
        const _UndefinedNotificationEvent$notification(),
    int? unreadCount,
  }) {
    return NotificationEvent(
      notification: notification is _isc.UndefinedSentinel
          ? this.notification?.copyWith()
          : notification,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
