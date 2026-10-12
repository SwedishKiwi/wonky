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

/// Sent first after joining: everyone present, including the caller.
abstract class PresenceRoster extends _iototaiw.PresenceEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresenceRoster._({
    required this.sessionId,
    required this.participants,
  });

  factory PresenceRoster({
    required String sessionId,
    required List<_ih83ei55.Participant> participants,
  }) = _PresenceRosterImpl;

  factory PresenceRoster.fromJson(Map<String, dynamic> jsonSerialization) {
    return PresenceRoster(
      sessionId: jsonSerialization['sessionId'] as String,
      participants: _il4umwa0.Protocol()
          .deserialize<List<_ih83ei55.Participant>>(
            jsonSerialization['participants'],
          ),
    );
  }

  /// The caller's own session id.
  String sessionId;

  List<_ih83ei55.Participant> participants;

  /// Returns a shallow copy of this [PresenceRoster]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  PresenceRoster copyWith({
    String? sessionId,
    List<_ih83ei55.Participant>? participants,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresenceRoster',
      'sessionId': sessionId,
      'participants': participants.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresenceRoster',
      'sessionId': sessionId,
      'participants': participants.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresenceRosterImpl extends PresenceRoster {
  _PresenceRosterImpl({
    required String sessionId,
    required List<_ih83ei55.Participant> participants,
  }) : super._(
         sessionId: sessionId,
         participants: participants,
       );

  /// Returns a shallow copy of this [PresenceRoster]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresenceRoster copyWith({
    String? sessionId,
    List<_ih83ei55.Participant>? participants,
  }) {
    return PresenceRoster(
      sessionId: sessionId ?? this.sessionId,
      participants:
          participants ?? this.participants.map((e0) => e0.copyWith()).toList(),
    );
  }
}
