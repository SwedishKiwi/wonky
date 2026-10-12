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

/// Server → app after the hello: the session id the window got.
abstract class UiBridgeWelcome extends _i26f4ubs.UiBridgeMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  UiBridgeWelcome._({required this.sessionId});

  factory UiBridgeWelcome({required String sessionId}) = _UiBridgeWelcomeImpl;

  factory UiBridgeWelcome.fromJson(Map<String, dynamic> jsonSerialization) {
    return UiBridgeWelcome(sessionId: jsonSerialization['sessionId'] as String);
  }

  String sessionId;

  /// Returns a shallow copy of this [UiBridgeWelcome]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  UiBridgeWelcome copyWith({String? sessionId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UiBridgeWelcome',
      'sessionId': sessionId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UiBridgeWelcome',
      'sessionId': sessionId,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _UiBridgeWelcomeImpl extends UiBridgeWelcome {
  _UiBridgeWelcomeImpl({required String sessionId})
    : super._(sessionId: sessionId);

  /// Returns a shallow copy of this [UiBridgeWelcome]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UiBridgeWelcome copyWith({String? sessionId}) {
    return UiBridgeWelcome(sessionId: sessionId ?? this.sessionId);
  }
}
