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

abstract class PresenceUpdated extends _iototaiw.PresenceEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresenceUpdated._({
    required this.sessionId,
    required this.state,
    this.cursorJson,
    this.mode,
  });

  factory PresenceUpdated({
    required String sessionId,
    required _i6muekp2.PresenceState state,
    String? cursorJson,
    String? mode,
  }) = _PresenceUpdatedImpl;

  factory PresenceUpdated.fromJson(Map<String, dynamic> jsonSerialization) {
    return PresenceUpdated(
      sessionId: jsonSerialization['sessionId'] as String,
      state: _i6muekp2.PresenceState.fromJson(
        (jsonSerialization['state'] as String),
      ),
      cursorJson: jsonSerialization['cursorJson'] as String?,
      mode: jsonSerialization['mode'] as String?,
    );
  }

  String sessionId;

  _i6muekp2.PresenceState state;

  String? cursorJson;

  String? mode;

  /// Returns a shallow copy of this [PresenceUpdated]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  PresenceUpdated copyWith({
    String? sessionId,
    _i6muekp2.PresenceState? state,
    String? cursorJson,
    String? mode,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresenceUpdated',
      'sessionId': sessionId,
      'state': state.toJson(),
      if (cursorJson != null) 'cursorJson': cursorJson,
      if (mode != null) 'mode': mode,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresenceUpdated',
      'sessionId': sessionId,
      'state': state.toJson(),
      if (cursorJson != null) 'cursorJson': cursorJson,
      if (mode != null) 'mode': mode,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresenceUpdatedImpl extends PresenceUpdated {
  _PresenceUpdatedImpl({
    required String sessionId,
    required _i6muekp2.PresenceState state,
    String? cursorJson,
    String? mode,
  }) : super._(
         sessionId: sessionId,
         state: state,
         cursorJson: cursorJson,
         mode: mode,
       );

  /// Returns a shallow copy of this [PresenceUpdated]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresenceUpdated copyWith({
    String? sessionId,
    _i6muekp2.PresenceState? state,
    Object? cursorJson = _Undefined,
    Object? mode = _Undefined,
  }) {
    return PresenceUpdated(
      sessionId: sessionId ?? this.sessionId,
      state: state ?? this.state,
      cursorJson: cursorJson is String? ? cursorJson : this.cursorJson,
      mode: mode is String? ? mode : this.mode,
    );
  }
}
