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
import '../../../slides/present/models/presentation_role.dart' as _i0s4aueu;

/// How a client joins a presentation session (Slides 10 §6.1).
abstract class PresentationJoin
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresentationJoin._({
    this.sessionId,
    required this.role,
    this.pairingKey,
    required this.deviceLabel,
    this.takeOver,
  });

  factory PresentationJoin({
    String? sessionId,
    required _i0s4aueu.PresentationRole role,
    String? pairingKey,
    required String deviceLabel,
    bool? takeOver,
  }) = _PresentationJoinImpl;

  factory PresentationJoin.fromJson(Map<String, dynamic> jsonSerialization) {
    return PresentationJoin(
      sessionId: jsonSerialization['sessionId'] as String?,
      role: _i0s4aueu.PresentationRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
      pairingKey: jsonSerialization['pairingKey'] as String?,
      deviceLabel: jsonSerialization['deviceLabel'] as String,
      takeOver: jsonSerialization['takeOver'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['takeOver']),
    );
  }

  /// The session to join; null for a presenter starting a new session.
  String? sessionId;

  _i0s4aueu.PresentationRole role;

  /// Pairing key of a phone remote of another account (P1, SL-41).
  String? pairingKey;

  /// "MacBook · Chrome" (shown to the presenter).
  String deviceLabel;

  /// A presenter rejoining a session whose presenter is still connected
  /// elsewhere takes it over (after "Take over the presentation?").
  bool? takeOver;

  /// Returns a shallow copy of this [PresentationJoin]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PresentationJoin copyWith({
    String? sessionId,
    _i0s4aueu.PresentationRole? role,
    String? pairingKey,
    String? deviceLabel,
    bool? takeOver,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationJoin',
      if (sessionId != null) 'sessionId': sessionId,
      'role': role.toJson(),
      if (pairingKey != null) 'pairingKey': pairingKey,
      'deviceLabel': deviceLabel,
      if (takeOver != null) 'takeOver': takeOver,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationJoin',
      if (sessionId != null) 'sessionId': sessionId,
      'role': role.toJson(),
      if (pairingKey != null) 'pairingKey': pairingKey,
      'deviceLabel': deviceLabel,
      if (takeOver != null) 'takeOver': takeOver,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PresentationJoinImpl extends PresentationJoin {
  _PresentationJoinImpl({
    String? sessionId,
    required _i0s4aueu.PresentationRole role,
    String? pairingKey,
    required String deviceLabel,
    bool? takeOver,
  }) : super._(
         sessionId: sessionId,
         role: role,
         pairingKey: pairingKey,
         deviceLabel: deviceLabel,
         takeOver: takeOver,
       );

  /// Returns a shallow copy of this [PresentationJoin]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresentationJoin copyWith({
    Object? sessionId = _Undefined,
    _i0s4aueu.PresentationRole? role,
    Object? pairingKey = _Undefined,
    String? deviceLabel,
    Object? takeOver = _Undefined,
  }) {
    return PresentationJoin(
      sessionId: sessionId is String? ? sessionId : this.sessionId,
      role: role ?? this.role,
      pairingKey: pairingKey is String? ? pairingKey : this.pairingKey,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      takeOver: takeOver is bool? ? takeOver : this.takeOver,
    );
  }
}
