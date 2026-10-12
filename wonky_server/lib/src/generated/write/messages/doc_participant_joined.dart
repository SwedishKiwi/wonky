/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'doc_server_message.dart';

abstract class DocParticipantJoined extends _iototaiw.DocServerMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DocParticipantJoined._({required this.participant});

  factory DocParticipantJoined({required _iekwkhcm.Participant participant}) =
      _DocParticipantJoinedImpl;

  factory DocParticipantJoined.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DocParticipantJoined(
      participant: _il4umwa0.Protocol().deserialize<_iekwkhcm.Participant>(
        jsonSerialization['participant'],
      ),
    );
  }

  _iekwkhcm.Participant participant;

  /// Returns a shallow copy of this [DocParticipantJoined]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  DocParticipantJoined copyWith({_iekwkhcm.Participant? participant});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocParticipantJoined',
      'participant': participant.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocParticipantJoined',
      'participant': participant.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _DocParticipantJoinedImpl extends DocParticipantJoined {
  _DocParticipantJoinedImpl({required _iekwkhcm.Participant participant})
    : super._(participant: participant);

  /// Returns a shallow copy of this [DocParticipantJoined]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocParticipantJoined copyWith({_iekwkhcm.Participant? participant}) {
    return DocParticipantJoined(
      participant: participant ?? this.participant.copyWith(),
    );
  }
}
