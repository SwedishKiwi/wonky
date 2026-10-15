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

abstract class PresentationStateEvent extends _i26f4ubs.PresentationEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationStateEvent._({
    required super.serverTimeMs,
    required this.state,
  });

  factory PresentationStateEvent({
    required int serverTimeMs,
    required _i4sa9kmk.PresentationState state,
  }) = _PresentationStateEventImpl;

  factory PresentationStateEvent.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationStateEvent(
      serverTimeMs: jsonSerialization['serverTimeMs'] as int,
      state: _il4umwa0.Protocol().deserialize<_i4sa9kmk.PresentationState>(
        jsonSerialization['state'],
      ),
    );
  }

  _i4sa9kmk.PresentationState state;

  /// Returns a shallow copy of this [PresentationStateEvent]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  PresentationStateEvent copyWith({
    int? serverTimeMs,
    _i4sa9kmk.PresentationState? state,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationStateEvent',
      'serverTimeMs': serverTimeMs,
      'state': state.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationStateEvent',
      'serverTimeMs': serverTimeMs,
      'state': state.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresentationStateEventImpl extends PresentationStateEvent {
  _PresentationStateEventImpl({
    required int serverTimeMs,
    required _i4sa9kmk.PresentationState state,
  }) : super._(
         serverTimeMs: serverTimeMs,
         state: state,
       );

  /// Returns a shallow copy of this [PresentationStateEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresentationStateEvent copyWith({
    int? serverTimeMs,
    _i4sa9kmk.PresentationState? state,
  }) {
    return PresentationStateEvent(
      serverTimeMs: serverTimeMs ?? this.serverTimeMs,
      state: state ?? this.state.copyWith(),
    );
  }
}
