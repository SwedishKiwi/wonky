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

/// Limits clients pre-check (specs/01 §6, Sheets 01 §3).
abstract class ServerLimits
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ServerLimits._({
    required this.maxCellsPerSpreadsheet,
    required this.maxActiveSpacesPerUser,
    required this.maxSheetsPerSpreadsheet,
    required this.maxDocumentChars,
    required this.maxImageUploadBytes,
    required this.maxImportUploadBytes,
    required this.scriptTimeoutMs,
  });

  factory ServerLimits({
    required int maxCellsPerSpreadsheet,
    required int maxActiveSpacesPerUser,
    required int maxSheetsPerSpreadsheet,
    required int maxDocumentChars,
    required int maxImageUploadBytes,
    required int maxImportUploadBytes,
    required int scriptTimeoutMs,
  }) = _ServerLimitsImpl;

  factory ServerLimits.fromJson(Map<String, dynamic> jsonSerialization) {
    return ServerLimits(
      maxCellsPerSpreadsheet:
          jsonSerialization['maxCellsPerSpreadsheet'] as int,
      maxActiveSpacesPerUser:
          jsonSerialization['maxActiveSpacesPerUser'] as int,
      maxSheetsPerSpreadsheet:
          jsonSerialization['maxSheetsPerSpreadsheet'] as int,
      maxDocumentChars: jsonSerialization['maxDocumentChars'] as int,
      maxImageUploadBytes: jsonSerialization['maxImageUploadBytes'] as int,
      maxImportUploadBytes: jsonSerialization['maxImportUploadBytes'] as int,
      scriptTimeoutMs: jsonSerialization['scriptTimeoutMs'] as int,
    );
  }

  int maxCellsPerSpreadsheet;

  int maxActiveSpacesPerUser;

  int maxSheetsPerSpreadsheet;

  int maxDocumentChars;

  int maxImageUploadBytes;

  int maxImportUploadBytes;

  int scriptTimeoutMs;

  /// Returns a shallow copy of this [ServerLimits]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ServerLimits copyWith({
    int? maxCellsPerSpreadsheet,
    int? maxActiveSpacesPerUser,
    int? maxSheetsPerSpreadsheet,
    int? maxDocumentChars,
    int? maxImageUploadBytes,
    int? maxImportUploadBytes,
    int? scriptTimeoutMs,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ServerLimits',
      'maxCellsPerSpreadsheet': maxCellsPerSpreadsheet,
      'maxActiveSpacesPerUser': maxActiveSpacesPerUser,
      'maxSheetsPerSpreadsheet': maxSheetsPerSpreadsheet,
      'maxDocumentChars': maxDocumentChars,
      'maxImageUploadBytes': maxImageUploadBytes,
      'maxImportUploadBytes': maxImportUploadBytes,
      'scriptTimeoutMs': scriptTimeoutMs,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ServerLimits',
      'maxCellsPerSpreadsheet': maxCellsPerSpreadsheet,
      'maxActiveSpacesPerUser': maxActiveSpacesPerUser,
      'maxSheetsPerSpreadsheet': maxSheetsPerSpreadsheet,
      'maxDocumentChars': maxDocumentChars,
      'maxImageUploadBytes': maxImageUploadBytes,
      'maxImportUploadBytes': maxImportUploadBytes,
      'scriptTimeoutMs': scriptTimeoutMs,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _ServerLimitsImpl extends ServerLimits {
  _ServerLimitsImpl({
    required int maxCellsPerSpreadsheet,
    required int maxActiveSpacesPerUser,
    required int maxSheetsPerSpreadsheet,
    required int maxDocumentChars,
    required int maxImageUploadBytes,
    required int maxImportUploadBytes,
    required int scriptTimeoutMs,
  }) : super._(
         maxCellsPerSpreadsheet: maxCellsPerSpreadsheet,
         maxActiveSpacesPerUser: maxActiveSpacesPerUser,
         maxSheetsPerSpreadsheet: maxSheetsPerSpreadsheet,
         maxDocumentChars: maxDocumentChars,
         maxImageUploadBytes: maxImageUploadBytes,
         maxImportUploadBytes: maxImportUploadBytes,
         scriptTimeoutMs: scriptTimeoutMs,
       );

  /// Returns a shallow copy of this [ServerLimits]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ServerLimits copyWith({
    int? maxCellsPerSpreadsheet,
    int? maxActiveSpacesPerUser,
    int? maxSheetsPerSpreadsheet,
    int? maxDocumentChars,
    int? maxImageUploadBytes,
    int? maxImportUploadBytes,
    int? scriptTimeoutMs,
  }) {
    return ServerLimits(
      maxCellsPerSpreadsheet:
          maxCellsPerSpreadsheet ?? this.maxCellsPerSpreadsheet,
      maxActiveSpacesPerUser:
          maxActiveSpacesPerUser ?? this.maxActiveSpacesPerUser,
      maxSheetsPerSpreadsheet:
          maxSheetsPerSpreadsheet ?? this.maxSheetsPerSpreadsheet,
      maxDocumentChars: maxDocumentChars ?? this.maxDocumentChars,
      maxImageUploadBytes: maxImageUploadBytes ?? this.maxImageUploadBytes,
      maxImportUploadBytes: maxImportUploadBytes ?? this.maxImportUploadBytes,
      scriptTimeoutMs: scriptTimeoutMs ?? this.scriptTimeoutMs,
    );
  }
}
