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

/// Result of ScriptEndpoint.compile (Sheets 09 §9.1 step 6).
abstract class ScriptCompileResponse
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ScriptCompileResponse._({
    required this.ok,
    required this.compiled,
    required this.sourceHash,
    this.buildId,
    required this.diagnosticsJson,
    this.exportsJson,
  });

  factory ScriptCompileResponse({
    required bool ok,
    required bool compiled,
    required String sourceHash,
    _isc.UuidValue? buildId,
    required String diagnosticsJson,
    String? exportsJson,
  }) = _ScriptCompileResponseImpl;

  factory ScriptCompileResponse.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ScriptCompileResponse(
      ok: _isc.BoolJsonExtension.fromJson(jsonSerialization['ok']),
      compiled: _isc.BoolJsonExtension.fromJson(jsonSerialization['compiled']),
      sourceHash: jsonSerialization['sourceHash'] as String,
      buildId: jsonSerialization['buildId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['buildId']),
      diagnosticsJson: jsonSerialization['diagnosticsJson'] as String,
      exportsJson: jsonSerialization['exportsJson'] as String?,
    );
  }

  /// Whether the latest sources built without errors.
  bool ok;

  /// False when the build for these sources already existed.
  bool compiled;

  String sourceHash;

  _isc.UuidValue? buildId;

  /// Diagnostics (Sheets 09 §9.2).
  String diagnosticsJson;

  String? exportsJson;

  /// Returns a shallow copy of this [ScriptCompileResponse]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ScriptCompileResponse copyWith({
    bool? ok,
    bool? compiled,
    String? sourceHash,
    _isc.UuidValue? buildId = const _isc.$UndefinedUuidValue(),
    String? diagnosticsJson,
    String? exportsJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScriptCompileResponse',
      'ok': ok,
      'compiled': compiled,
      'sourceHash': sourceHash,
      if (buildId != null) 'buildId': buildId?.toJson(),
      'diagnosticsJson': diagnosticsJson,
      if (exportsJson != null) 'exportsJson': exportsJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ScriptCompileResponse',
      'ok': ok,
      'compiled': compiled,
      'sourceHash': sourceHash,
      if (buildId != null) 'buildId': buildId?.toJson(),
      'diagnosticsJson': diagnosticsJson,
      if (exportsJson != null) 'exportsJson': exportsJson,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ScriptCompileResponseImpl extends ScriptCompileResponse {
  _ScriptCompileResponseImpl({
    required bool ok,
    required bool compiled,
    required String sourceHash,
    _isc.UuidValue? buildId,
    required String diagnosticsJson,
    String? exportsJson,
  }) : super._(
         ok: ok,
         compiled: compiled,
         sourceHash: sourceHash,
         buildId: buildId,
         diagnosticsJson: diagnosticsJson,
         exportsJson: exportsJson,
       );

  /// Returns a shallow copy of this [ScriptCompileResponse]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ScriptCompileResponse copyWith({
    bool? ok,
    bool? compiled,
    String? sourceHash,
    _isc.UuidValue? buildId = const _isc.$UndefinedUuidValue(),
    String? diagnosticsJson,
    Object? exportsJson = _Undefined,
  }) {
    return ScriptCompileResponse(
      ok: ok ?? this.ok,
      compiled: compiled ?? this.compiled,
      sourceHash: sourceHash ?? this.sourceHash,
      buildId: buildId is _isc.UndefinedSentinel ? this.buildId : buildId,
      diagnosticsJson: diagnosticsJson ?? this.diagnosticsJson,
      exportsJson: exportsJson is String? ? exportsJson : this.exportsJson,
    );
  }
}
