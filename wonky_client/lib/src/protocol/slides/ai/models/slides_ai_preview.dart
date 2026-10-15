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
import 'package:wonky_client/src/protocol/protocol.dart' as _i8pkqg1o;
import '../../../slides/ai/models/slides_ai_preview_call.dart' as _iovquy9j;

/// The AI changes preview of a Suggest-mode assistant run (Slides 11
/// §6.3): the recorded tool calls the user applies or discards.
abstract class SlidesAiPreview
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SlidesAiPreview._({
    required this.previewId,
    required this.itemUuid,
    required this.calls,
    required this.expiresAt,
  });

  factory SlidesAiPreview({
    required String previewId,
    required _isc.UuidValue itemUuid,
    required List<_iovquy9j.SlidesAiPreviewCall> calls,
    required DateTime expiresAt,
  }) = _SlidesAiPreviewImpl;

  factory SlidesAiPreview.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlidesAiPreview(
      previewId: jsonSerialization['previewId'] as String,
      itemUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      calls: _i8pkqg1o.Protocol()
          .deserialize<List<_iovquy9j.SlidesAiPreviewCall>>(
            jsonSerialization['calls'],
          ),
      expiresAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  String previewId;

  _isc.UuidValue itemUuid;

  List<_iovquy9j.SlidesAiPreviewCall> calls;

  DateTime expiresAt;

  /// Returns a shallow copy of this [SlidesAiPreview]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SlidesAiPreview copyWith({
    String? previewId,
    _isc.UuidValue? itemUuid,
    List<_iovquy9j.SlidesAiPreviewCall>? calls,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlidesAiPreview',
      'previewId': previewId,
      'itemUuid': itemUuid.toJson(),
      'calls': calls.toJson(valueToJson: (v) => v.toJson()),
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlidesAiPreview',
      'previewId': previewId,
      'itemUuid': itemUuid.toJson(),
      'calls': calls.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _SlidesAiPreviewImpl extends SlidesAiPreview {
  _SlidesAiPreviewImpl({
    required String previewId,
    required _isc.UuidValue itemUuid,
    required List<_iovquy9j.SlidesAiPreviewCall> calls,
    required DateTime expiresAt,
  }) : super._(
         previewId: previewId,
         itemUuid: itemUuid,
         calls: calls,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [SlidesAiPreview]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SlidesAiPreview copyWith({
    String? previewId,
    _isc.UuidValue? itemUuid,
    List<_iovquy9j.SlidesAiPreviewCall>? calls,
    DateTime? expiresAt,
  }) {
    return SlidesAiPreview(
      previewId: previewId ?? this.previewId,
      itemUuid: itemUuid ?? this.itemUuid,
      calls: calls ?? this.calls.map((e0) => e0.copyWith()).toList(),
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
