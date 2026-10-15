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

/// One recorded mutating tool call of an AI changes preview (Slides 11
/// §6.3): its label, the slides it touches and its row changes (JSON list
/// of `RowChange`, applied by the client to a copy of the deck for the
/// before/after thumbnails).
abstract class SlidesAiPreviewCall
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SlidesAiPreviewCall._({
    required this.callId,
    required this.toolName,
    required this.label,
    required this.slideIds,
    required this.changesJson,
  });

  factory SlidesAiPreviewCall({
    required String callId,
    required String toolName,
    required String label,
    required List<String> slideIds,
    required String changesJson,
  }) = _SlidesAiPreviewCallImpl;

  factory SlidesAiPreviewCall.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlidesAiPreviewCall(
      callId: jsonSerialization['callId'] as String,
      toolName: jsonSerialization['toolName'] as String,
      label: jsonSerialization['label'] as String,
      slideIds: _il4umwa0.Protocol().deserialize<List<String>>(
        jsonSerialization['slideIds'],
      ),
      changesJson: jsonSerialization['changesJson'] as String,
    );
  }

  String callId;

  String toolName;

  String label;

  List<String> slideIds;

  String changesJson;

  /// Returns a shallow copy of this [SlidesAiPreviewCall]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SlidesAiPreviewCall copyWith({
    String? callId,
    String? toolName,
    String? label,
    List<String>? slideIds,
    String? changesJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlidesAiPreviewCall',
      'callId': callId,
      'toolName': toolName,
      'label': label,
      'slideIds': slideIds.toJson(),
      'changesJson': changesJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlidesAiPreviewCall',
      'callId': callId,
      'toolName': toolName,
      'label': label,
      'slideIds': slideIds.toJson(),
      'changesJson': changesJson,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _SlidesAiPreviewCallImpl extends SlidesAiPreviewCall {
  _SlidesAiPreviewCallImpl({
    required String callId,
    required String toolName,
    required String label,
    required List<String> slideIds,
    required String changesJson,
  }) : super._(
         callId: callId,
         toolName: toolName,
         label: label,
         slideIds: slideIds,
         changesJson: changesJson,
       );

  /// Returns a shallow copy of this [SlidesAiPreviewCall]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SlidesAiPreviewCall copyWith({
    String? callId,
    String? toolName,
    String? label,
    List<String>? slideIds,
    String? changesJson,
  }) {
    return SlidesAiPreviewCall(
      callId: callId ?? this.callId,
      toolName: toolName ?? this.toolName,
      label: label ?? this.label,
      slideIds: slideIds ?? this.slideIds.map((e0) => e0).toList(),
      changesJson: changesJson ?? this.changesJson,
    );
  }
}
