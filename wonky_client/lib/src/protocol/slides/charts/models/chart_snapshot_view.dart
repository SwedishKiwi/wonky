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

/// A resolved chart snapshot (Slides 08 §3.3–§3.4, §13 `resolveSnapshot`):
/// the column values of a `ChartLink` (plain JSON; the client compresses
/// large values with the `gz:` prefix when it stores them).
abstract class ChartSnapshotView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ChartSnapshotView._({
    required this.spreadsheetUuid,
    required this.chartObjectId,
    this.sheetId,
    required this.sourceSpecJson,
    required this.dataSnapshotJson,
    required this.sourceVersion,
    required this.updatedAt,
    required this.warnings,
  });

  factory ChartSnapshotView({
    required _isc.UuidValue spreadsheetUuid,
    required String chartObjectId,
    String? sheetId,
    required String sourceSpecJson,
    required String dataSnapshotJson,
    required String sourceVersion,
    required DateTime updatedAt,
    required List<String> warnings,
  }) = _ChartSnapshotViewImpl;

  factory ChartSnapshotView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChartSnapshotView(
      spreadsheetUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['spreadsheetUuid'],
      ),
      chartObjectId: jsonSerialization['chartObjectId'] as String,
      sheetId: jsonSerialization['sheetId'] as String?,
      sourceSpecJson: jsonSerialization['sourceSpecJson'] as String,
      dataSnapshotJson: jsonSerialization['dataSnapshotJson'] as String,
      sourceVersion: jsonSerialization['sourceVersion'] as String,
      updatedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      warnings: _i8pkqg1o.Protocol().deserialize<List<String>>(
        jsonSerialization['warnings'],
      ),
    );
  }

  _isc.UuidValue spreadsheetUuid;

  String chartObjectId;

  /// Sheet the chart is on (display only).
  String? sheetId;

  /// The source `ChartSpec` JSON.
  String sourceSpecJson;

  /// `ChartDataSnapshot` JSON: resolved series only, theme, locale, source info.
  String dataSnapshotJson;

  /// `<changeLog>:<specHash>:<dataVersion>` (08 §5.1).
  String sourceVersion;

  /// When the snapshot was resolved (server time).
  DateTime updatedAt;

  /// English data warnings (downsampled, …).
  List<String> warnings;

  /// Returns a shallow copy of this [ChartSnapshotView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ChartSnapshotView copyWith({
    _isc.UuidValue? spreadsheetUuid,
    String? chartObjectId,
    String? sheetId,
    String? sourceSpecJson,
    String? dataSnapshotJson,
    String? sourceVersion,
    DateTime? updatedAt,
    List<String>? warnings,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChartSnapshotView',
      'spreadsheetUuid': spreadsheetUuid.toJson(),
      'chartObjectId': chartObjectId,
      if (sheetId != null) 'sheetId': sheetId,
      'sourceSpecJson': sourceSpecJson,
      'dataSnapshotJson': dataSnapshotJson,
      'sourceVersion': sourceVersion,
      'updatedAt': updatedAt.toJson(),
      'warnings': warnings.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChartSnapshotView',
      'spreadsheetUuid': spreadsheetUuid.toJson(),
      'chartObjectId': chartObjectId,
      if (sheetId != null) 'sheetId': sheetId,
      'sourceSpecJson': sourceSpecJson,
      'dataSnapshotJson': dataSnapshotJson,
      'sourceVersion': sourceVersion,
      'updatedAt': updatedAt.toJson(),
      'warnings': warnings.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ChartSnapshotViewImpl extends ChartSnapshotView {
  _ChartSnapshotViewImpl({
    required _isc.UuidValue spreadsheetUuid,
    required String chartObjectId,
    String? sheetId,
    required String sourceSpecJson,
    required String dataSnapshotJson,
    required String sourceVersion,
    required DateTime updatedAt,
    required List<String> warnings,
  }) : super._(
         spreadsheetUuid: spreadsheetUuid,
         chartObjectId: chartObjectId,
         sheetId: sheetId,
         sourceSpecJson: sourceSpecJson,
         dataSnapshotJson: dataSnapshotJson,
         sourceVersion: sourceVersion,
         updatedAt: updatedAt,
         warnings: warnings,
       );

  /// Returns a shallow copy of this [ChartSnapshotView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ChartSnapshotView copyWith({
    _isc.UuidValue? spreadsheetUuid,
    String? chartObjectId,
    Object? sheetId = _Undefined,
    String? sourceSpecJson,
    String? dataSnapshotJson,
    String? sourceVersion,
    DateTime? updatedAt,
    List<String>? warnings,
  }) {
    return ChartSnapshotView(
      spreadsheetUuid: spreadsheetUuid ?? this.spreadsheetUuid,
      chartObjectId: chartObjectId ?? this.chartObjectId,
      sheetId: sheetId is String? ? sheetId : this.sheetId,
      sourceSpecJson: sourceSpecJson ?? this.sourceSpecJson,
      dataSnapshotJson: dataSnapshotJson ?? this.dataSnapshotJson,
      sourceVersion: sourceVersion ?? this.sourceVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      warnings: warnings ?? this.warnings.map((e0) => e0).toList(),
    );
  }
}
