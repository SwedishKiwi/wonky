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

/// One proposed value of Fill with AI (Sheets 12 §6.6).
abstract class SheetsFillRow
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SheetsFillRow._({
    required this.cell,
    required this.row,
    required this.inputs,
    this.value,
    required this.confidence,
  });

  factory SheetsFillRow({
    required String cell,
    required int row,
    required String inputs,
    String? value,
    required String confidence,
  }) = _SheetsFillRowImpl;

  factory SheetsFillRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsFillRow(
      cell: jsonSerialization['cell'] as String,
      row: jsonSerialization['row'] as int,
      inputs: jsonSerialization['inputs'] as String,
      value: jsonSerialization['value'] as String?,
      confidence: jsonSerialization['confidence'] as String,
    );
  }

  /// The target cell (`Sheet1!C5`).
  String cell;

  /// 1-based row number.
  int row;

  /// A short summary of the row's input columns.
  String inputs;

  /// The proposed value (user-entered text; null = leave empty).
  String? value;

  /// low, medium or high.
  String confidence;

  /// Returns a shallow copy of this [SheetsFillRow]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SheetsFillRow copyWith({
    String? cell,
    int? row,
    String? inputs,
    String? value,
    String? confidence,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsFillRow',
      'cell': cell,
      'row': row,
      'inputs': inputs,
      if (value != null) 'value': value,
      'confidence': confidence,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsFillRow',
      'cell': cell,
      'row': row,
      'inputs': inputs,
      if (value != null) 'value': value,
      'confidence': confidence,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsFillRowImpl extends SheetsFillRow {
  _SheetsFillRowImpl({
    required String cell,
    required int row,
    required String inputs,
    String? value,
    required String confidence,
  }) : super._(
         cell: cell,
         row: row,
         inputs: inputs,
         value: value,
         confidence: confidence,
       );

  /// Returns a shallow copy of this [SheetsFillRow]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SheetsFillRow copyWith({
    String? cell,
    int? row,
    String? inputs,
    Object? value = _Undefined,
    String? confidence,
  }) {
    return SheetsFillRow(
      cell: cell ?? this.cell,
      row: row ?? this.row,
      inputs: inputs ?? this.inputs,
      value: value is String? ? value : this.value,
      confidence: confidence ?? this.confidence,
    );
  }
}
