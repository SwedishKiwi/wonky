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

abstract class NotificationPage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  NotificationPage._({
    required this.items,
    this.nextCursor,
    required this.unreadCount,
  });

  factory NotificationPage({
    required List<_idqc661j.NotificationView> items,
    String? nextCursor,
    required int unreadCount,
  }) = _NotificationPageImpl;

  factory NotificationPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return NotificationPage(
      items: _i8pkqg1o.Protocol().deserialize<List<_idqc661j.NotificationView>>(
        jsonSerialization['items'],
      ),
      nextCursor: jsonSerialization['nextCursor'] as String?,
      unreadCount: jsonSerialization['unreadCount'] as int,
    );
  }

  List<_idqc661j.NotificationView> items;

  String? nextCursor;

  int unreadCount;

  /// Returns a shallow copy of this [NotificationPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  NotificationPage copyWith({
    List<_idqc661j.NotificationView>? items,
    String? nextCursor,
    int? unreadCount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'NotificationPage',
      'items': items.toJson(valueToJson: (v) => v.toJson()),
      if (nextCursor != null) 'nextCursor': nextCursor,
      'unreadCount': unreadCount,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'NotificationPage',
      'items': items.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (nextCursor != null) 'nextCursor': nextCursor,
      'unreadCount': unreadCount,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _NotificationPageImpl extends NotificationPage {
  _NotificationPageImpl({
    required List<_idqc661j.NotificationView> items,
    String? nextCursor,
    required int unreadCount,
  }) : super._(
         items: items,
         nextCursor: nextCursor,
         unreadCount: unreadCount,
       );

  /// Returns a shallow copy of this [NotificationPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  NotificationPage copyWith({
    List<_idqc661j.NotificationView>? items,
    Object? nextCursor = _Undefined,
    int? unreadCount,
  }) {
    return NotificationPage(
      items: items ?? this.items.map((e0) => e0.copyWith()).toList(),
      nextCursor: nextCursor is String? ? nextCursor : this.nextCursor,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
