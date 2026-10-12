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

abstract class PresenceJoined extends _iototaiw.PresenceEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresenceJoined._({required this.participant});

  factory PresenceJoined({required _ih83ei55.Participant participant}) =
      _PresenceJoinedImpl;

  factory PresenceJoined.fromJson(Map<String, dynamic> jsonSerialization) {
    return PresenceJoined(
      participant: _il4umwa0.Protocol().deserialize<_ih83ei55.Participant>(
        jsonSerialization['participant'],
      ),
    );
  }

  _ih83ei55.Participant participant;

  /// Returns a shallow copy of this [PresenceJoined]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  PresenceJoined copyWith({_ih83ei55.Participant? participant});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresenceJoined',
      'participant': participant.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresenceJoined',
      'participant': participant.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresenceJoinedImpl extends PresenceJoined {
  _PresenceJoinedImpl({required _ih83ei55.Participant participant})
    : super._(participant: participant);

  /// Returns a shallow copy of this [PresenceJoined]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresenceJoined copyWith({_ih83ei55.Participant? participant}) {
    return PresenceJoined(
      participant: participant ?? this.participant.copyWith(),
    );
  }
}
