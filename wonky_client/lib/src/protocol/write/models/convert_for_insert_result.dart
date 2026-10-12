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
import '../../platform/drive/import_warning_view.dart' as _ibijl4o7;

abstract class ConvertForInsertResult
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ConvertForInsertResult._({
    required this.deltaJson,
    required this.warnings,
  });

  factory ConvertForInsertResult({
    required String deltaJson,
    required List<_ibijl4o7.ImportWarningView> warnings,
  }) = _ConvertForInsertResultImpl;

  factory ConvertForInsertResult.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ConvertForInsertResult(
      deltaJson: jsonSerialization['deltaJson'] as String,
      warnings: _i8pkqg1o.Protocol()
          .deserialize<List<_ibijl4o7.ImportWarningView>>(
            jsonSerialization['warnings'],
          ),
    );
  }

  String deltaJson;

  List<_ibijl4o7.ImportWarningView> warnings;

  /// Returns a shallow copy of this [ConvertForInsertResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ConvertForInsertResult copyWith({
    String? deltaJson,
    List<_ibijl4o7.ImportWarningView>? warnings,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ConvertForInsertResult',
      'deltaJson': deltaJson,
      'warnings': warnings.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ConvertForInsertResult',
      'deltaJson': deltaJson,
      'warnings': warnings.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _ConvertForInsertResultImpl extends ConvertForInsertResult {
  _ConvertForInsertResultImpl({
    required String deltaJson,
    required List<_ibijl4o7.ImportWarningView> warnings,
  }) : super._(
         deltaJson: deltaJson,
         warnings: warnings,
       );

  /// Returns a shallow copy of this [ConvertForInsertResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ConvertForInsertResult copyWith({
    String? deltaJson,
    List<_ibijl4o7.ImportWarningView>? warnings,
  }) {
    return ConvertForInsertResult(
      deltaJson: deltaJson ?? this.deltaJson,
      warnings: warnings ?? this.warnings.map((e0) => e0.copyWith()).toList(),
    );
  }
}
