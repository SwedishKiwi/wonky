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

/// The presenter's connection dropped (grace period running) or is back.
abstract class PresentationPresenterEvent extends _i26f4ubs.PresentationEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresentationPresenterEvent._({
    required super.serverTimeMs,
    required this.connected,
  });

  factory PresentationPresenterEvent({
    required int serverTimeMs,
    required bool connected,
  }) = _PresentationPresenterEventImpl;

  factory PresentationPresenterEvent.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationPresenterEvent(
      serverTimeMs: jsonSerialization['serverTimeMs'] as int,
      connected: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['connected'],
      ),
    );
  }

  bool connected;

  /// Returns a shallow copy of this [PresentationPresenterEvent]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  PresentationPresenterEvent copyWith({
    int? serverTimeMs,
    bool? connected,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationPresenterEvent',
      'serverTimeMs': serverTimeMs,
      'connected': connected,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationPresenterEvent',
      'serverTimeMs': serverTimeMs,
      'connected': connected,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresentationPresenterEventImpl extends PresentationPresenterEvent {
  _PresentationPresenterEventImpl({
    required int serverTimeMs,
    required bool connected,
  }) : super._(
         serverTimeMs: serverTimeMs,
         connected: connected,
       );

  /// Returns a shallow copy of this [PresentationPresenterEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresentationPresenterEvent copyWith({
    int? serverTimeMs,
    bool? connected,
  }) {
    return PresentationPresenterEvent(
      serverTimeMs: serverTimeMs ?? this.serverTimeMs,
      connected: connected ?? this.connected,
    );
  }
}
