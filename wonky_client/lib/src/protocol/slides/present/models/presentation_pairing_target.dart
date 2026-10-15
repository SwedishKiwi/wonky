/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// What a typed pairing code resolves to (`presentation.resolvePairingCode`,
/// Slides 10 §6.4): the remote route of the session.
abstract class PresentationPairingTarget
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresentationPairingTarget._({
    required this.deckUuid,
    required this.sessionId,
    required this.pairingKey,
  });

  factory PresentationPairingTarget({
    required _isc.UuidValue deckUuid,
    required String sessionId,
    required String pairingKey,
  }) = _PresentationPairingTargetImpl;

  factory PresentationPairingTarget.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationPairingTarget(
      deckUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['deckUuid'],
      ),
      sessionId: jsonSerialization['sessionId'] as String,
      pairingKey: jsonSerialization['pairingKey'] as String,
    );
  }

  _isc.UuidValue deckUuid;

  String sessionId;

  String pairingKey;

  /// Returns a shallow copy of this [PresentationPairingTarget]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PresentationPairingTarget copyWith({
    _isc.UuidValue? deckUuid,
    String? sessionId,
    String? pairingKey,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationPairingTarget',
      'deckUuid': deckUuid.toJson(),
      'sessionId': sessionId,
      'pairingKey': pairingKey,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationPairingTarget',
      'deckUuid': deckUuid.toJson(),
      'sessionId': sessionId,
      'pairingKey': pairingKey,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresentationPairingTargetImpl extends PresentationPairingTarget {
  _PresentationPairingTargetImpl({
    required _isc.UuidValue deckUuid,
    required String sessionId,
    required String pairingKey,
  }) : super._(
         deckUuid: deckUuid,
         sessionId: sessionId,
         pairingKey: pairingKey,
       );

  /// Returns a shallow copy of this [PresentationPairingTarget]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresentationPairingTarget copyWith({
    _isc.UuidValue? deckUuid,
    String? sessionId,
    String? pairingKey,
  }) {
    return PresentationPairingTarget(
      deckUuid: deckUuid ?? this.deckUuid,
      sessionId: sessionId ?? this.sessionId,
      pairingKey: pairingKey ?? this.pairingKey,
    );
  }
}
