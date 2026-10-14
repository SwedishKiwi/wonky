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
import '../../../sheets/scripts/models/script_execution_status.dart'
    as _igympe3c;

/// Result of a server-side run (Run on server, MCP sheets.run_function).
abstract class ScriptRunResponse
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ScriptRunResponse._({
    required this.executionId,
    required this.status,
    this.resultJson,
    required this.logs,
    this.errorJson,
    this.changeId,
    required this.cellsWritten,
  });

  factory ScriptRunResponse({
    required _isc.UuidValue executionId,
    required _igympe3c.ScriptExecutionStatus status,
    String? resultJson,
    required String logs,
    String? errorJson,
    _isc.UuidValue? changeId,
    required int cellsWritten,
  }) = _ScriptRunResponseImpl;

  factory ScriptRunResponse.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScriptRunResponse(
      executionId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['executionId'],
      ),
      status: _igympe3c.ScriptExecutionStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      resultJson: jsonSerialization['resultJson'] as String?,
      logs: jsonSerialization['logs'] as String,
      errorJson: jsonSerialization['errorJson'] as String?,
      changeId: jsonSerialization['changeId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['changeId']),
      cellsWritten: jsonSerialization['cellsWritten'] as int,
    );
  }

  _isc.UuidValue executionId;

  _igympe3c.ScriptExecutionStatus status;

  /// The function's return value as JSON.
  String? resultJson;

  /// JSON lines {t, level, msg}.
  String logs;

  /// {type, message, code?, frames[]}.
  String? errorJson;

  _isc.UuidValue? changeId;

  int cellsWritten;

  /// Returns a shallow copy of this [ScriptRunResponse]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ScriptRunResponse copyWith({
    _isc.UuidValue? executionId,
    _igympe3c.ScriptExecutionStatus? status,
    String? resultJson,
    String? logs,
    String? errorJson,
    _isc.UuidValue? changeId = const _isc.$UndefinedUuidValue(),
    int? cellsWritten,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScriptRunResponse',
      'executionId': executionId.toJson(),
      'status': status.toJson(),
      if (resultJson != null) 'resultJson': resultJson,
      'logs': logs,
      if (errorJson != null) 'errorJson': errorJson,
      if (changeId != null) 'changeId': changeId?.toJson(),
      'cellsWritten': cellsWritten,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ScriptRunResponse',
      'executionId': executionId.toJson(),
      'status': status.toJson(),
      if (resultJson != null) 'resultJson': resultJson,
      'logs': logs,
      if (errorJson != null) 'errorJson': errorJson,
      if (changeId != null) 'changeId': changeId?.toJson(),
      'cellsWritten': cellsWritten,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ScriptRunResponseImpl extends ScriptRunResponse {
  _ScriptRunResponseImpl({
    required _isc.UuidValue executionId,
    required _igympe3c.ScriptExecutionStatus status,
    String? resultJson,
    required String logs,
    String? errorJson,
    _isc.UuidValue? changeId,
    required int cellsWritten,
  }) : super._(
         executionId: executionId,
         status: status,
         resultJson: resultJson,
         logs: logs,
         errorJson: errorJson,
         changeId: changeId,
         cellsWritten: cellsWritten,
       );

  /// Returns a shallow copy of this [ScriptRunResponse]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ScriptRunResponse copyWith({
    _isc.UuidValue? executionId,
    _igympe3c.ScriptExecutionStatus? status,
    Object? resultJson = _Undefined,
    String? logs,
    Object? errorJson = _Undefined,
    _isc.UuidValue? changeId = const _isc.$UndefinedUuidValue(),
    int? cellsWritten,
  }) {
    return ScriptRunResponse(
      executionId: executionId ?? this.executionId,
      status: status ?? this.status,
      resultJson: resultJson is String? ? resultJson : this.resultJson,
      logs: logs ?? this.logs,
      errorJson: errorJson is String? ? errorJson : this.errorJson,
      changeId: changeId is _isc.UndefinedSentinel ? this.changeId : changeId,
      cellsWritten: cellsWritten ?? this.cellsWritten,
    );
  }
}
