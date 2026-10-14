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

/// The value of one `=AI()` call (Sheets 12 §6.8).
abstract class SheetsAiCellResult
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SheetsAiCellResult._({
    required this.id,
    this.value,
    this.error,
    required this.cached,
  });

  factory SheetsAiCellResult({
    required String id,
    String? value,
    String? error,
    required bool cached,
  }) = _SheetsAiCellResultImpl;

  factory SheetsAiCellResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsAiCellResult(
      id: jsonSerialization['id'] as String,
      value: jsonSerialization['value'] as String?,
      error: jsonSerialization['error'] as String?,
      cached: _isc.BoolJsonExtension.fromJson(jsonSerialization['cached']),
    );
  }

  String id;

  /// Text (numbers as text when the prompt asks for a number).
  String? value;

  /// Set on failure: `#AI_ERROR!` with this message as tooltip.
  String? error;

  /// Whether the value came from the cache.
  bool cached;

  /// Returns a shallow copy of this [SheetsAiCellResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SheetsAiCellResult copyWith({
    String? id,
    String? value,
    String? error,
    bool? cached,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsAiCellResult',
      'id': id,
      if (value != null) 'value': value,
      if (error != null) 'error': error,
      'cached': cached,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsAiCellResult',
      'id': id,
      if (value != null) 'value': value,
      if (error != null) 'error': error,
      'cached': cached,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsAiCellResultImpl extends SheetsAiCellResult {
  _SheetsAiCellResultImpl({
    required String id,
    String? value,
    String? error,
    required bool cached,
  }) : super._(
         id: id,
         value: value,
         error: error,
         cached: cached,
       );

  /// Returns a shallow copy of this [SheetsAiCellResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SheetsAiCellResult copyWith({
    String? id,
    Object? value = _Undefined,
    Object? error = _Undefined,
    bool? cached,
  }) {
    return SheetsAiCellResult(
      id: id ?? this.id,
      value: value is String? ? value : this.value,
      error: error is String? ? error : this.error,
      cached: cached ?? this.cached,
    );
  }
}
