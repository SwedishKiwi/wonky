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

/// Internal session.messages payload on `notifications:<userId>`.
abstract class NotificationSignal
    implements _is.SerializableModel, _is.ProtocolSerialization {
  NotificationSignal._({this.notificationId});

  factory NotificationSignal({int? notificationId}) = _NotificationSignalImpl;

  factory NotificationSignal.fromJson(Map<String, dynamic> jsonSerialization) {
    return NotificationSignal(
      notificationId: jsonSerialization['notificationId'] as int?,
    );
  }

  int? notificationId;

  /// Returns a shallow copy of this [NotificationSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  NotificationSignal copyWith({int? notificationId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'NotificationSignal',
      if (notificationId != null) 'notificationId': notificationId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _NotificationSignalImpl extends NotificationSignal {
  _NotificationSignalImpl({int? notificationId})
    : super._(notificationId: notificationId);

  /// Returns a shallow copy of this [NotificationSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  NotificationSignal copyWith({Object? notificationId = _Undefined}) {
    return NotificationSignal(
      notificationId: notificationId is int?
          ? notificationId
          : this.notificationId,
    );
  }
}
