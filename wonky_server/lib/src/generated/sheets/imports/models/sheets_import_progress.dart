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
import '../../../sheets/imports/models/sheets_import_status.dart' as _i8aac5e2;

/// Progress of a server import job (`sheetsImport.watchImport`, 11 §3.3).
abstract class SheetsImportProgress
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SheetsImportProgress._({
    required this.jobId,
    required this.status,
    required this.done,
    required this.total,
    required this.queuePosition,
    this.reportJson,
    this.changeId,
    this.sheetIds,
    this.errorCode,
    this.error,
  });

  factory SheetsImportProgress({
    required _is.UuidValue jobId,
    required _i8aac5e2.SheetsImportStatus status,
    required int done,
    required int total,
    required int queuePosition,
    String? reportJson,
    _is.UuidValue? changeId,
    List<String>? sheetIds,
    String? errorCode,
    String? error,
  }) = _SheetsImportProgressImpl;

  factory SheetsImportProgress.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return SheetsImportProgress(
      jobId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['jobId']),
      status: _i8aac5e2.SheetsImportStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      done: jsonSerialization['done'] as int,
      total: jsonSerialization['total'] as int,
      queuePosition: jsonSerialization['queuePosition'] as int,
      reportJson: jsonSerialization['reportJson'] as String?,
      changeId: jsonSerialization['changeId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['changeId']),
      sheetIds: jsonSerialization['sheetIds'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<List<String>>(
              jsonSerialization['sheetIds'],
            ),
      errorCode: jsonSerialization['errorCode'] as String?,
      error: jsonSerialization['error'] as String?,
    );
  }

  _is.UuidValue jobId;

  _i8aac5e2.SheetsImportStatus status;

  /// Cells written so far / in total (`writing`).
  int done;

  int total;

  /// Jobs of the same user ahead of this one (`queued`).
  int queuePosition;

  /// `ImportReport` JSON (`done`).
  String? reportJson;

  /// Undo of the import (`sheets.serverChange`), when done.
  _is.UuidValue? changeId;

  /// Ids of the sheets the import created (`done`).
  List<String>? sheetIds;

  String? errorCode;

  String? error;

  /// Returns a shallow copy of this [SheetsImportProgress]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SheetsImportProgress copyWith({
    _is.UuidValue? jobId,
    _i8aac5e2.SheetsImportStatus? status,
    int? done,
    int? total,
    int? queuePosition,
    String? reportJson,
    _is.UuidValue? changeId = const _is.$UndefinedUuidValue(),
    List<String>? sheetIds = const _is.$UndefinedList<String>(),
    String? errorCode,
    String? error,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsImportProgress',
      'jobId': jobId.toJson(),
      'status': status.toJson(),
      'done': done,
      'total': total,
      'queuePosition': queuePosition,
      if (reportJson != null) 'reportJson': reportJson,
      if (changeId != null) 'changeId': changeId?.toJson(),
      if (sheetIds != null) 'sheetIds': sheetIds?.toJson(),
      if (errorCode != null) 'errorCode': errorCode,
      if (error != null) 'error': error,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsImportProgress',
      'jobId': jobId.toJson(),
      'status': status.toJson(),
      'done': done,
      'total': total,
      'queuePosition': queuePosition,
      if (reportJson != null) 'reportJson': reportJson,
      if (changeId != null) 'changeId': changeId?.toJson(),
      if (sheetIds != null) 'sheetIds': sheetIds?.toJson(),
      if (errorCode != null) 'errorCode': errorCode,
      if (error != null) 'error': error,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsImportProgressImpl extends SheetsImportProgress {
  _SheetsImportProgressImpl({
    required _is.UuidValue jobId,
    required _i8aac5e2.SheetsImportStatus status,
    required int done,
    required int total,
    required int queuePosition,
    String? reportJson,
    _is.UuidValue? changeId,
    List<String>? sheetIds,
    String? errorCode,
    String? error,
  }) : super._(
         jobId: jobId,
         status: status,
         done: done,
         total: total,
         queuePosition: queuePosition,
         reportJson: reportJson,
         changeId: changeId,
         sheetIds: sheetIds,
         errorCode: errorCode,
         error: error,
       );

  /// Returns a shallow copy of this [SheetsImportProgress]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SheetsImportProgress copyWith({
    _is.UuidValue? jobId,
    _i8aac5e2.SheetsImportStatus? status,
    int? done,
    int? total,
    int? queuePosition,
    Object? reportJson = _Undefined,
    _is.UuidValue? changeId = const _is.$UndefinedUuidValue(),
    List<String>? sheetIds = const _is.$UndefinedList<String>(),
    Object? errorCode = _Undefined,
    Object? error = _Undefined,
  }) {
    return SheetsImportProgress(
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      done: done ?? this.done,
      total: total ?? this.total,
      queuePosition: queuePosition ?? this.queuePosition,
      reportJson: reportJson is String? ? reportJson : this.reportJson,
      changeId: changeId is _is.UndefinedSentinel ? this.changeId : changeId,
      sheetIds: sheetIds is _is.UndefinedSentinel
          ? this.sheetIds?.map((e0) => e0).toList()
          : sheetIds,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
      error: error is String? ? error : this.error,
    );
  }
}
