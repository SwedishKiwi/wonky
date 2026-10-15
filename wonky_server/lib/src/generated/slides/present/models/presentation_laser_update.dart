/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'presentation_update.dart';

/// Laser position in slide units (null = hidden); ≤ 30 Hz.
abstract class PresentationLaserUpdate extends _i26f4ubs.PresentationUpdate
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationLaserUpdate._({
    this.slideId,
    this.x,
    this.y,
  });

  factory PresentationLaserUpdate({
    String? slideId,
    double? x,
    double? y,
  }) = _PresentationLaserUpdateImpl;

  factory PresentationLaserUpdate.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationLaserUpdate(
      slideId: jsonSerialization['slideId'] as String?,
      x: (jsonSerialization['x'] as num?)?.toDouble(),
      y: (jsonSerialization['y'] as num?)?.toDouble(),
    );
  }

  String? slideId;

  double? x;

  double? y;

  /// Returns a shallow copy of this [PresentationLaserUpdate]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  PresentationLaserUpdate copyWith({
    String? slideId,
    double? x,
    double? y,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationLaserUpdate',
      if (slideId != null) 'slideId': slideId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationLaserUpdate',
      if (slideId != null) 'slideId': slideId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresentationLaserUpdateImpl extends PresentationLaserUpdate {
  _PresentationLaserUpdateImpl({
    String? slideId,
    double? x,
    double? y,
  }) : super._(
         slideId: slideId,
         x: x,
         y: y,
       );

  /// Returns a shallow copy of this [PresentationLaserUpdate]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresentationLaserUpdate copyWith({
    Object? slideId = _Undefined,
    Object? x = _Undefined,
    Object? y = _Undefined,
  }) {
    return PresentationLaserUpdate(
      slideId: slideId is String? ? slideId : this.slideId,
      x: x is double? ? x : this.x,
      y: y is double? ? y : this.y,
    );
  }
}
