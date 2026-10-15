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

abstract class PresentationLaserEvent extends _i26f4ubs.PresentationEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresentationLaserEvent._({
    required super.serverTimeMs,
    this.slideId,
    this.x,
    this.y,
  });

  factory PresentationLaserEvent({
    required int serverTimeMs,
    String? slideId,
    double? x,
    double? y,
  }) = _PresentationLaserEventImpl;

  factory PresentationLaserEvent.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationLaserEvent(
      serverTimeMs: jsonSerialization['serverTimeMs'] as int,
      slideId: jsonSerialization['slideId'] as String?,
      x: (jsonSerialization['x'] as num?)?.toDouble(),
      y: (jsonSerialization['y'] as num?)?.toDouble(),
    );
  }

  String? slideId;

  double? x;

  double? y;

  /// Returns a shallow copy of this [PresentationLaserEvent]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  PresentationLaserEvent copyWith({
    int? serverTimeMs,
    String? slideId,
    double? x,
    double? y,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationLaserEvent',
      'serverTimeMs': serverTimeMs,
      if (slideId != null) 'slideId': slideId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationLaserEvent',
      'serverTimeMs': serverTimeMs,
      if (slideId != null) 'slideId': slideId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresentationLaserEventImpl extends PresentationLaserEvent {
  _PresentationLaserEventImpl({
    required int serverTimeMs,
    String? slideId,
    double? x,
    double? y,
  }) : super._(
         serverTimeMs: serverTimeMs,
         slideId: slideId,
         x: x,
         y: y,
       );

  /// Returns a shallow copy of this [PresentationLaserEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresentationLaserEvent copyWith({
    int? serverTimeMs,
    Object? slideId = _Undefined,
    Object? x = _Undefined,
    Object? y = _Undefined,
  }) {
    return PresentationLaserEvent(
      serverTimeMs: serverTimeMs ?? this.serverTimeMs,
      slideId: slideId is String? ? slideId : this.slideId,
      x: x is double? ? x : this.x,
      y: y is double? ? y : this.y,
    );
  }
}
