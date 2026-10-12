/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'ui_bridge_message.dart';

/// Server → app: the request timed out or the agent went away.
abstract class UiBridgeCancel extends _i26f4ubs.UiBridgeMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  UiBridgeCancel._({required this.requestId});

  factory UiBridgeCancel({required String requestId}) = _UiBridgeCancelImpl;

  factory UiBridgeCancel.fromJson(Map<String, dynamic> jsonSerialization) {
    return UiBridgeCancel(requestId: jsonSerialization['requestId'] as String);
  }

  String requestId;

  /// Returns a shallow copy of this [UiBridgeCancel]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  UiBridgeCancel copyWith({String? requestId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UiBridgeCancel',
      'requestId': requestId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UiBridgeCancel',
      'requestId': requestId,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _UiBridgeCancelImpl extends UiBridgeCancel {
  _UiBridgeCancelImpl({required String requestId})
    : super._(requestId: requestId);

  /// Returns a shallow copy of this [UiBridgeCancel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UiBridgeCancel copyWith({String? requestId}) {
    return UiBridgeCancel(requestId: requestId ?? this.requestId);
  }
}
