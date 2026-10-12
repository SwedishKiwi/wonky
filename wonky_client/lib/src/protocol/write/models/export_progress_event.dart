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
import '../../write/models/export_progress_kind.dart' as _iynnwkj9;
import '../../write/models/export_result_view.dart' as _ir23tl9j;

abstract class ExportProgressEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ExportProgressEvent._({
    required this.kind,
    this.phase,
    this.progress,
    this.result,
    this.errorCode,
    this.message,
  });

  factory ExportProgressEvent({
    required _iynnwkj9.ExportProgressKind kind,
    String? phase,
    double? progress,
    _ir23tl9j.ExportResultView? result,
    String? errorCode,
    String? message,
  }) = _ExportProgressEventImpl;

  factory ExportProgressEvent.fromJson(Map<String, dynamic> jsonSerialization) {
    return ExportProgressEvent(
      kind: _iynnwkj9.ExportProgressKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      phase: jsonSerialization['phase'] as String?,
      progress: (jsonSerialization['progress'] as num?)?.toDouble(),
      result: jsonSerialization['result'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_ir23tl9j.ExportResultView>(
              jsonSerialization['result'],
            ),
      errorCode: jsonSerialization['errorCode'] as String?,
      message: jsonSerialization['message'] as String?,
    );
  }

  _iynnwkj9.ExportProgressKind kind;

  /// loading, layout, fonts, images, packaging, uploading.
  String? phase;

  double? progress;

  _ir23tl9j.ExportResultView? result;

  String? errorCode;

  String? message;

  /// Returns a shallow copy of this [ExportProgressEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ExportProgressEvent copyWith({
    _iynnwkj9.ExportProgressKind? kind,
    String? phase,
    double? progress,
    _ir23tl9j.ExportResultView? result =
        const _UndefinedExportProgressEvent$result(),
    String? errorCode,
    String? message,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ExportProgressEvent',
      'kind': kind.toJson(),
      if (phase != null) 'phase': phase,
      if (progress != null) 'progress': progress,
      if (result != null) 'result': result?.toJson(),
      if (errorCode != null) 'errorCode': errorCode,
      if (message != null) 'message': message,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ExportProgressEvent',
      'kind': kind.toJson(),
      if (phase != null) 'phase': phase,
      if (progress != null) 'progress': progress,
      if (result != null) 'result': result?.toJsonForProtocol(),
      if (errorCode != null) 'errorCode': errorCode,
      if (message != null) 'message': message,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedExportProgressEvent$result extends _isc.UndefinedSentinel
    implements _ir23tl9j.ExportResultView {
  const _UndefinedExportProgressEvent$result();
}

class _ExportProgressEventImpl extends ExportProgressEvent {
  _ExportProgressEventImpl({
    required _iynnwkj9.ExportProgressKind kind,
    String? phase,
    double? progress,
    _ir23tl9j.ExportResultView? result,
    String? errorCode,
    String? message,
  }) : super._(
         kind: kind,
         phase: phase,
         progress: progress,
         result: result,
         errorCode: errorCode,
         message: message,
       );

  /// Returns a shallow copy of this [ExportProgressEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ExportProgressEvent copyWith({
    _iynnwkj9.ExportProgressKind? kind,
    Object? phase = _Undefined,
    Object? progress = _Undefined,
    _ir23tl9j.ExportResultView? result =
        const _UndefinedExportProgressEvent$result(),
    Object? errorCode = _Undefined,
    Object? message = _Undefined,
  }) {
    return ExportProgressEvent(
      kind: kind ?? this.kind,
      phase: phase is String? ? phase : this.phase,
      progress: progress is double? ? progress : this.progress,
      result: result is _isc.UndefinedSentinel
          ? this.result?.copyWith()
          : result,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
      message: message is String? ? message : this.message,
    );
  }
}
