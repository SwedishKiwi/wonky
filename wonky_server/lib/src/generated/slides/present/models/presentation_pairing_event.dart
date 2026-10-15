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

/// A pairing key for a phone remote (presenter only; Slides 10 §6.4): the
/// QR link carries `pairingKey`, the phone may type `code` instead. Single
/// use, valid until `expiresAtMs` (server epoch ms, 10 min).
abstract class PresentationPairingEvent extends _i26f4ubs.PresentationEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationPairingEvent._({
    required super.serverTimeMs,
    required this.pairingKey,
    required this.code,
    required this.expiresAtMs,
  });

  factory PresentationPairingEvent({
    required int serverTimeMs,
    required String pairingKey,
    required String code,
    required int expiresAtMs,
  }) = _PresentationPairingEventImpl;

  factory PresentationPairingEvent.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationPairingEvent(
      serverTimeMs: jsonSerialization['serverTimeMs'] as int,
      pairingKey: jsonSerialization['pairingKey'] as String,
      code: jsonSerialization['code'] as String,
      expiresAtMs: jsonSerialization['expiresAtMs'] as int,
    );
  }

  String pairingKey;

  /// Six digits.
  String code;

  int expiresAtMs;

  /// Returns a shallow copy of this [PresentationPairingEvent]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  PresentationPairingEvent copyWith({
    int? serverTimeMs,
    String? pairingKey,
    String? code,
    int? expiresAtMs,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationPairingEvent',
      'serverTimeMs': serverTimeMs,
      'pairingKey': pairingKey,
      'code': code,
      'expiresAtMs': expiresAtMs,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationPairingEvent',
      'serverTimeMs': serverTimeMs,
      'pairingKey': pairingKey,
      'code': code,
      'expiresAtMs': expiresAtMs,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresentationPairingEventImpl extends PresentationPairingEvent {
  _PresentationPairingEventImpl({
    required int serverTimeMs,
    required String pairingKey,
    required String code,
    required int expiresAtMs,
  }) : super._(
         serverTimeMs: serverTimeMs,
         pairingKey: pairingKey,
         code: code,
         expiresAtMs: expiresAtMs,
       );

  /// Returns a shallow copy of this [PresentationPairingEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresentationPairingEvent copyWith({
    int? serverTimeMs,
    String? pairingKey,
    String? code,
    int? expiresAtMs,
  }) {
    return PresentationPairingEvent(
      serverTimeMs: serverTimeMs ?? this.serverTimeMs,
      pairingKey: pairingKey ?? this.pairingKey,
      code: code ?? this.code,
      expiresAtMs: expiresAtMs ?? this.expiresAtMs,
    );
  }
}
