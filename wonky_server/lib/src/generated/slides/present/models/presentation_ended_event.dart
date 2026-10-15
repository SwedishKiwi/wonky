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

/// The session is over for this connection; the stream closes after it.
/// Reasons: ended (by the presenter), expired (presenter gone 30 s),
/// takenOver (another presenter connection), presenterActive (a presenter
/// join without takeOver while one is connected), notFound.
abstract class PresentationEndedEvent extends _i26f4ubs.PresentationEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationEndedEvent._({
    required super.serverTimeMs,
    required this.reason,
  });

  factory PresentationEndedEvent({
    required int serverTimeMs,
    required String reason,
  }) = _PresentationEndedEventImpl;

  factory PresentationEndedEvent.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationEndedEvent(
      serverTimeMs: jsonSerialization['serverTimeMs'] as int,
      reason: jsonSerialization['reason'] as String,
    );
  }

  String reason;

  /// Returns a shallow copy of this [PresentationEndedEvent]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  PresentationEndedEvent copyWith({
    int? serverTimeMs,
    String? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationEndedEvent',
      'serverTimeMs': serverTimeMs,
      'reason': reason,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationEndedEvent',
      'serverTimeMs': serverTimeMs,
      'reason': reason,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresentationEndedEventImpl extends PresentationEndedEvent {
  _PresentationEndedEventImpl({
    required int serverTimeMs,
    required String reason,
  }) : super._(
         serverTimeMs: serverTimeMs,
         reason: reason,
       );

  /// Returns a shallow copy of this [PresentationEndedEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresentationEndedEvent copyWith({
    int? serverTimeMs,
    String? reason,
  }) {
    return PresentationEndedEvent(
      serverTimeMs: serverTimeMs ?? this.serverTimeMs,
      reason: reason ?? this.reason,
    );
  }
}
