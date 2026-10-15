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

abstract class PresentationInkEvent extends _i26f4ubs.PresentationEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresentationInkEvent._({
    required super.serverTimeMs,
    required this.slideId,
    required this.op,
    this.strokeId,
    this.strokeJson,
  });

  factory PresentationInkEvent({
    required int serverTimeMs,
    required String slideId,
    required String op,
    String? strokeId,
    String? strokeJson,
  }) = _PresentationInkEventImpl;

  factory PresentationInkEvent.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationInkEvent(
      serverTimeMs: jsonSerialization['serverTimeMs'] as int,
      slideId: jsonSerialization['slideId'] as String,
      op: jsonSerialization['op'] as String,
      strokeId: jsonSerialization['strokeId'] as String?,
      strokeJson: jsonSerialization['strokeJson'] as String?,
    );
  }

  String slideId;

  String op;

  String? strokeId;

  String? strokeJson;

  /// Returns a shallow copy of this [PresentationInkEvent]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  PresentationInkEvent copyWith({
    int? serverTimeMs,
    String? slideId,
    String? op,
    String? strokeId,
    String? strokeJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationInkEvent',
      'serverTimeMs': serverTimeMs,
      'slideId': slideId,
      'op': op,
      if (strokeId != null) 'strokeId': strokeId,
      if (strokeJson != null) 'strokeJson': strokeJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationInkEvent',
      'serverTimeMs': serverTimeMs,
      'slideId': slideId,
      'op': op,
      if (strokeId != null) 'strokeId': strokeId,
      if (strokeJson != null) 'strokeJson': strokeJson,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresentationInkEventImpl extends PresentationInkEvent {
  _PresentationInkEventImpl({
    required int serverTimeMs,
    required String slideId,
    required String op,
    String? strokeId,
    String? strokeJson,
  }) : super._(
         serverTimeMs: serverTimeMs,
         slideId: slideId,
         op: op,
         strokeId: strokeId,
         strokeJson: strokeJson,
       );

  /// Returns a shallow copy of this [PresentationInkEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresentationInkEvent copyWith({
    int? serverTimeMs,
    String? slideId,
    String? op,
    Object? strokeId = _Undefined,
    Object? strokeJson = _Undefined,
  }) {
    return PresentationInkEvent(
      serverTimeMs: serverTimeMs ?? this.serverTimeMs,
      slideId: slideId ?? this.slideId,
      op: op ?? this.op,
      strokeId: strokeId is String? ? strokeId : this.strokeId,
      strokeJson: strokeJson is String? ? strokeJson : this.strokeJson,
    );
  }
}
