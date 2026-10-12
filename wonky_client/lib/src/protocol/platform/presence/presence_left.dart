/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'presence_event.dart';

abstract class PresenceLeft extends _iototaiw.PresenceEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresenceLeft._({required this.sessionId});

  factory PresenceLeft({required String sessionId}) = _PresenceLeftImpl;

  factory PresenceLeft.fromJson(Map<String, dynamic> jsonSerialization) {
    return PresenceLeft(sessionId: jsonSerialization['sessionId'] as String);
  }

  String sessionId;

  /// Returns a shallow copy of this [PresenceLeft]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  PresenceLeft copyWith({String? sessionId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresenceLeft',
      'sessionId': sessionId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresenceLeft',
      'sessionId': sessionId,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresenceLeftImpl extends PresenceLeft {
  _PresenceLeftImpl({required String sessionId})
    : super._(sessionId: sessionId);

  /// Returns a shallow copy of this [PresenceLeft]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresenceLeft copyWith({String? sessionId}) {
    return PresenceLeft(sessionId: sessionId ?? this.sessionId);
  }
}
