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
import '../../../sheets/ai/models/sheets_ai_preview_cell.dart' as _itedkagj;

/// One mutating tool call recorded in an AI changes preview (Sheets 12
/// §6.3).
abstract class SheetsAiPreviewCall
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SheetsAiPreviewCall._({
    required this.callId,
    required this.toolName,
    required this.label,
    required this.ranges,
    required this.cellsAffected,
    this.structural,
    required this.cells,
  });

  factory SheetsAiPreviewCall({
    required String callId,
    required String toolName,
    required String label,
    required List<String> ranges,
    required int cellsAffected,
    String? structural,
    required List<_itedkagj.SheetsAiPreviewCell> cells,
  }) = _SheetsAiPreviewCallImpl;

  factory SheetsAiPreviewCall.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsAiPreviewCall(
      callId: jsonSerialization['callId'] as String,
      toolName: jsonSerialization['toolName'] as String,
      label: jsonSerialization['label'] as String,
      ranges: _i8pkqg1o.Protocol().deserialize<List<String>>(
        jsonSerialization['ranges'],
      ),
      cellsAffected: jsonSerialization['cellsAffected'] as int,
      structural: jsonSerialization['structural'] as String?,
      cells: _i8pkqg1o.Protocol()
          .deserialize<List<_itedkagj.SheetsAiPreviewCell>>(
            jsonSerialization['cells'],
          ),
    );
  }

  String callId;

  String toolName;

  String label;

  List<String> ranges;

  int cellsAffected;

  /// Structure changes in words ("Insert 3 rows at 5:7").
  String? structural;

  /// Up to 200 changed cells with their values before and after.
  List<_itedkagj.SheetsAiPreviewCell> cells;

  /// Returns a shallow copy of this [SheetsAiPreviewCall]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SheetsAiPreviewCall copyWith({
    String? callId,
    String? toolName,
    String? label,
    List<String>? ranges,
    int? cellsAffected,
    String? structural,
    List<_itedkagj.SheetsAiPreviewCell>? cells,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsAiPreviewCall',
      'callId': callId,
      'toolName': toolName,
      'label': label,
      'ranges': ranges.toJson(),
      'cellsAffected': cellsAffected,
      if (structural != null) 'structural': structural,
      'cells': cells.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsAiPreviewCall',
      'callId': callId,
      'toolName': toolName,
      'label': label,
      'ranges': ranges.toJson(),
      'cellsAffected': cellsAffected,
      if (structural != null) 'structural': structural,
      'cells': cells.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsAiPreviewCallImpl extends SheetsAiPreviewCall {
  _SheetsAiPreviewCallImpl({
    required String callId,
    required String toolName,
    required String label,
    required List<String> ranges,
    required int cellsAffected,
    String? structural,
    required List<_itedkagj.SheetsAiPreviewCell> cells,
  }) : super._(
         callId: callId,
         toolName: toolName,
         label: label,
         ranges: ranges,
         cellsAffected: cellsAffected,
         structural: structural,
         cells: cells,
       );

  /// Returns a shallow copy of this [SheetsAiPreviewCall]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SheetsAiPreviewCall copyWith({
    String? callId,
    String? toolName,
    String? label,
    List<String>? ranges,
    int? cellsAffected,
    Object? structural = _Undefined,
    List<_itedkagj.SheetsAiPreviewCell>? cells,
  }) {
    return SheetsAiPreviewCall(
      callId: callId ?? this.callId,
      toolName: toolName ?? this.toolName,
      label: label ?? this.label,
      ranges: ranges ?? this.ranges.map((e0) => e0).toList(),
      cellsAffected: cellsAffected ?? this.cellsAffected,
      structural: structural is String? ? structural : this.structural,
      cells: cells ?? this.cells.map((e0) => e0.copyWith()).toList(),
    );
  }
}
