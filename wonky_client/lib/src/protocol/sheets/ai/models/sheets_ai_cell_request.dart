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

/// One `=AI(prompt, ranges…)` evaluation asked by a client (Sheets 12
/// §6.8).
abstract class SheetsAiCellRequest
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SheetsAiCellRequest._({
    required this.id,
    required this.prompt,
    required this.valuesJson,
  });

  factory SheetsAiCellRequest({
    required String id,
    required String prompt,
    required String valuesJson,
  }) = _SheetsAiCellRequestImpl;

  factory SheetsAiCellRequest.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsAiCellRequest(
      id: jsonSerialization['id'] as String,
      prompt: jsonSerialization['prompt'] as String,
      valuesJson: jsonSerialization['valuesJson'] as String,
    );
  }

  /// The client's id of the call (echoed in the result).
  String id;

  String prompt;

  /// The referenced values as canonical JSON (a list of 2-D arrays).
  String valuesJson;

  /// Returns a shallow copy of this [SheetsAiCellRequest]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SheetsAiCellRequest copyWith({
    String? id,
    String? prompt,
    String? valuesJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsAiCellRequest',
      'id': id,
      'prompt': prompt,
      'valuesJson': valuesJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsAiCellRequest',
      'id': id,
      'prompt': prompt,
      'valuesJson': valuesJson,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _SheetsAiCellRequestImpl extends SheetsAiCellRequest {
  _SheetsAiCellRequestImpl({
    required String id,
    required String prompt,
    required String valuesJson,
  }) : super._(
         id: id,
         prompt: prompt,
         valuesJson: valuesJson,
       );

  /// Returns a shallow copy of this [SheetsAiCellRequest]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SheetsAiCellRequest copyWith({
    String? id,
    String? prompt,
    String? valuesJson,
  }) {
    return SheetsAiCellRequest(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      valuesJson: valuesJson ?? this.valuesJson,
    );
  }
}
