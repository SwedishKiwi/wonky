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

/// An ink change: add (strokeJson), remove (strokeId) or clear.
abstract class PresentationInkUpdate extends _i26f4ubs.PresentationUpdate
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationInkUpdate._({
    required this.slideId,
    required this.op,
    this.strokeId,
    this.strokeJson,
  });

  factory PresentationInkUpdate({
    required String slideId,
    required String op,
    String? strokeId,
    String? strokeJson,
  }) = _PresentationInkUpdateImpl;

  factory PresentationInkUpdate.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationInkUpdate(
      slideId: jsonSerialization['slideId'] as String,
      op: jsonSerialization['op'] as String,
      strokeId: jsonSerialization['strokeId'] as String?,
      strokeJson: jsonSerialization['strokeJson'] as String?,
    );
  }

  String slideId;

  /// add, remove or clear.
  String op;

  String? strokeId;

  /// `{id, tool, color, width, points}` (su, quantized 0.5).
  String? strokeJson;

  /// Returns a shallow copy of this [PresentationInkUpdate]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  PresentationInkUpdate copyWith({
    String? slideId,
    String? op,
    String? strokeId,
    String? strokeJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationInkUpdate',
      'slideId': slideId,
      'op': op,
      if (strokeId != null) 'strokeId': strokeId,
      if (strokeJson != null) 'strokeJson': strokeJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationInkUpdate',
      'slideId': slideId,
      'op': op,
      if (strokeId != null) 'strokeId': strokeId,
      if (strokeJson != null) 'strokeJson': strokeJson,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresentationInkUpdateImpl extends PresentationInkUpdate {
  _PresentationInkUpdateImpl({
    required String slideId,
    required String op,
    String? strokeId,
    String? strokeJson,
  }) : super._(
         slideId: slideId,
         op: op,
         strokeId: strokeId,
         strokeJson: strokeJson,
       );

  /// Returns a shallow copy of this [PresentationInkUpdate]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresentationInkUpdate copyWith({
    String? slideId,
    String? op,
    Object? strokeId = _Undefined,
    Object? strokeJson = _Undefined,
  }) {
    return PresentationInkUpdate(
      slideId: slideId ?? this.slideId,
      op: op ?? this.op,
      strokeId: strokeId is String? ? strokeId : this.strokeId,
      strokeJson: strokeJson is String? ? strokeJson : this.strokeJson,
    );
  }
}
