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
import 'package:serverpod/serverpod.dart' as _is;
import 'package:wonky_server/src/generated/protocol.dart' as _il4umwa0;
import '../../../sheets/ai/models/sheets_ai_preview_call.dart' as _ienypvob;

/// The AI changes preview of an assistant run in Suggest mode (Sheets 12
/// §6.3): recorded tool calls that the user applies or discards.
abstract class SheetsAiPreview
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SheetsAiPreview._({
    required this.previewId,
    required this.itemUuid,
    required this.calls,
    required this.expiresAt,
  });

  factory SheetsAiPreview({
    required String previewId,
    required _is.UuidValue itemUuid,
    required List<_ienypvob.SheetsAiPreviewCall> calls,
    required DateTime expiresAt,
  }) = _SheetsAiPreviewImpl;

  factory SheetsAiPreview.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsAiPreview(
      previewId: jsonSerialization['previewId'] as String,
      itemUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      calls: _il4umwa0.Protocol()
          .deserialize<List<_ienypvob.SheetsAiPreviewCall>>(
            jsonSerialization['calls'],
          ),
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  String previewId;

  _is.UuidValue itemUuid;

  List<_ienypvob.SheetsAiPreviewCall> calls;

  DateTime expiresAt;

  /// Returns a shallow copy of this [SheetsAiPreview]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SheetsAiPreview copyWith({
    String? previewId,
    _is.UuidValue? itemUuid,
    List<_ienypvob.SheetsAiPreviewCall>? calls,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsAiPreview',
      'previewId': previewId,
      'itemUuid': itemUuid.toJson(),
      'calls': calls.toJson(valueToJson: (v) => v.toJson()),
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsAiPreview',
      'previewId': previewId,
      'itemUuid': itemUuid.toJson(),
      'calls': calls.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _SheetsAiPreviewImpl extends SheetsAiPreview {
  _SheetsAiPreviewImpl({
    required String previewId,
    required _is.UuidValue itemUuid,
    required List<_ienypvob.SheetsAiPreviewCall> calls,
    required DateTime expiresAt,
  }) : super._(
         previewId: previewId,
         itemUuid: itemUuid,
         calls: calls,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [SheetsAiPreview]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SheetsAiPreview copyWith({
    String? previewId,
    _is.UuidValue? itemUuid,
    List<_ienypvob.SheetsAiPreviewCall>? calls,
    DateTime? expiresAt,
  }) {
    return SheetsAiPreview(
      previewId: previewId ?? this.previewId,
      itemUuid: itemUuid ?? this.itemUuid,
      calls: calls ?? this.calls.map((e0) => e0.copyWith()).toList(),
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
