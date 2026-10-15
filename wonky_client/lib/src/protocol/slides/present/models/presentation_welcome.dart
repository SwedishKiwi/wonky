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

/// The first event after joining.
abstract class PresentationWelcome extends _i26f4ubs.PresentationEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresentationWelcome._({
    required super.serverTimeMs,
    required this.sessionId,
    required this.connectionId,
    required this.role,
    required this.presenterConnected,
    this.presenterDevice,
    this.state,
    this.stateSentAtMs,
  });

  factory PresentationWelcome({
    required int serverTimeMs,
    required String sessionId,
    required String connectionId,
    required _ia2cflib.PresentationRole role,
    required bool presenterConnected,
    String? presenterDevice,
    _i4sa9kmk.PresentationState? state,
    int? stateSentAtMs,
  }) = _PresentationWelcomeImpl;

  factory PresentationWelcome.fromJson(Map<String, dynamic> jsonSerialization) {
    return PresentationWelcome(
      serverTimeMs: jsonSerialization['serverTimeMs'] as int,
      sessionId: jsonSerialization['sessionId'] as String,
      connectionId: jsonSerialization['connectionId'] as String,
      role: _ia2cflib.PresentationRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
      presenterConnected: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['presenterConnected'],
      ),
      presenterDevice: jsonSerialization['presenterDevice'] as String?,
      state: jsonSerialization['state'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_i4sa9kmk.PresentationState>(
              jsonSerialization['state'],
            ),
      stateSentAtMs: jsonSerialization['stateSentAtMs'] as int?,
    );
  }

  String sessionId;

  /// The caller's own connection.
  String connectionId;

  _ia2cflib.PresentationRole role;

  bool presenterConnected;

  /// The presenter's device ("MacBook · Chrome").
  String? presenterDevice;

  /// The latest state (null for a new session).
  _i4sa9kmk.PresentationState? state;

  /// When the state was sent (server epoch ms).
  int? stateSentAtMs;

  /// Returns a shallow copy of this [PresentationWelcome]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  PresentationWelcome copyWith({
    int? serverTimeMs,
    String? sessionId,
    String? connectionId,
    _ia2cflib.PresentationRole? role,
    bool? presenterConnected,
    String? presenterDevice,
    _i4sa9kmk.PresentationState? state =
        const _UndefinedPresentationWelcome$state(),
    int? stateSentAtMs,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationWelcome',
      'serverTimeMs': serverTimeMs,
      'sessionId': sessionId,
      'connectionId': connectionId,
      'role': role.toJson(),
      'presenterConnected': presenterConnected,
      if (presenterDevice != null) 'presenterDevice': presenterDevice,
      if (state != null) 'state': state?.toJson(),
      if (stateSentAtMs != null) 'stateSentAtMs': stateSentAtMs,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationWelcome',
      'serverTimeMs': serverTimeMs,
      'sessionId': sessionId,
      'connectionId': connectionId,
      'role': role.toJson(),
      'presenterConnected': presenterConnected,
      if (presenterDevice != null) 'presenterDevice': presenterDevice,
      if (state != null) 'state': state?.toJsonForProtocol(),
      if (stateSentAtMs != null) 'stateSentAtMs': stateSentAtMs,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresentationWelcomeImpl extends PresentationWelcome {
  _PresentationWelcomeImpl({
    required int serverTimeMs,
    required String sessionId,
    required String connectionId,
    required _ia2cflib.PresentationRole role,
    required bool presenterConnected,
    String? presenterDevice,
    _i4sa9kmk.PresentationState? state,
    int? stateSentAtMs,
  }) : super._(
         serverTimeMs: serverTimeMs,
         sessionId: sessionId,
         connectionId: connectionId,
         role: role,
         presenterConnected: presenterConnected,
         presenterDevice: presenterDevice,
         state: state,
         stateSentAtMs: stateSentAtMs,
       );

  /// Returns a shallow copy of this [PresentationWelcome]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresentationWelcome copyWith({
    int? serverTimeMs,
    String? sessionId,
    String? connectionId,
    _ia2cflib.PresentationRole? role,
    bool? presenterConnected,
    Object? presenterDevice = _Undefined,
    _i4sa9kmk.PresentationState? state =
        const _UndefinedPresentationWelcome$state(),
    Object? stateSentAtMs = _Undefined,
  }) {
    return PresentationWelcome(
      serverTimeMs: serverTimeMs ?? this.serverTimeMs,
      sessionId: sessionId ?? this.sessionId,
      connectionId: connectionId ?? this.connectionId,
      role: role ?? this.role,
      presenterConnected: presenterConnected ?? this.presenterConnected,
      presenterDevice: presenterDevice is String?
          ? presenterDevice
          : this.presenterDevice,
      state: state is _isc.UndefinedSentinel ? this.state?.copyWith() : state,
      stateSentAtMs: stateSentAtMs is int? ? stateSentAtMs : this.stateSentAtMs,
    );
  }
}
