/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'presentation_event.dart';

/// The devices joined to the session (presenter only).
abstract class PresentationRosterEvent extends _i26f4ubs.PresentationEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationRosterEvent._({
    required super.serverTimeMs,
    required this.participants,
  });

  factory PresentationRosterEvent({
    required int serverTimeMs,
    required List<_ib4fvwj1.PresentationParticipant> participants,
  }) = _PresentationRosterEventImpl;

  factory PresentationRosterEvent.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationRosterEvent(
      serverTimeMs: jsonSerialization['serverTimeMs'] as int,
      participants: _il4umwa0.Protocol()
          .deserialize<List<_ib4fvwj1.PresentationParticipant>>(
            jsonSerialization['participants'],
          ),
    );
  }

  List<_ib4fvwj1.PresentationParticipant> participants;

  /// Returns a shallow copy of this [PresentationRosterEvent]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  PresentationRosterEvent copyWith({
    int? serverTimeMs,
    List<_ib4fvwj1.PresentationParticipant>? participants,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationRosterEvent',
      'serverTimeMs': serverTimeMs,
      'participants': participants.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationRosterEvent',
      'serverTimeMs': serverTimeMs,
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

class _PresentationRosterEventImpl extends PresentationRosterEvent {
  _PresentationRosterEventImpl({
    required int serverTimeMs,
    required List<_ib4fvwj1.PresentationParticipant> participants,
  }) : super._(
         serverTimeMs: serverTimeMs,
         participants: participants,
       );

  /// Returns a shallow copy of this [PresentationRosterEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresentationRosterEvent copyWith({
    int? serverTimeMs,
    List<_ib4fvwj1.PresentationParticipant>? participants,
  }) {
    return PresentationRosterEvent(
      serverTimeMs: serverTimeMs ?? this.serverTimeMs,
      participants:
          participants ?? this.participants.map((e0) => e0.copyWith()).toList(),
    );
  }
}
