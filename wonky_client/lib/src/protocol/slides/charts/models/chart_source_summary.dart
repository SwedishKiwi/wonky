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

/// One chart of a spreadsheet in the insert dialog (Slides 08 §4.2, §13).
abstract class ChartSourceSummary
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ChartSourceSummary._({
    required this.chartObjectId,
    required this.title,
    required this.type,
    required this.is3D,
    required this.sheetName,
    required this.onChartSheet,
    required this.unsupported,
    this.previewSnapshotJson,
  });

  factory ChartSourceSummary({
    required String chartObjectId,
    required String title,
    required String type,
    required bool is3D,
    required String sheetName,
    required bool onChartSheet,
    required bool unsupported,
    String? previewSnapshotJson,
  }) = _ChartSourceSummaryImpl;

  factory ChartSourceSummary.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChartSourceSummary(
      chartObjectId: jsonSerialization['chartObjectId'] as String,
      title: jsonSerialization['title'] as String,
      type: jsonSerialization['type'] as String,
      is3D: _isc.BoolJsonExtension.fromJson(jsonSerialization['is3D']),
      sheetName: jsonSerialization['sheetName'] as String,
      onChartSheet: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['onChartSheet'],
      ),
      unsupported: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['unsupported'],
      ),
      previewSnapshotJson: jsonSerialization['previewSnapshotJson'] as String?,
    );
  }

  String chartObjectId;

  String title;

  /// Chart type id (`column`, `pie`, …).
  String type;

  bool is3D;

  String sheetName;

  /// The chart has its own chart sheet.
  bool onChartSheet;

  /// Made with a newer version of Wonky Sheets (tile disabled).
  bool unsupported;

  /// `{"sourceSpec", "dataSnapshot"}` downsampled to ≤ 200 points; null
  /// when the caller may not copy data.
  String? previewSnapshotJson;

  /// Returns a shallow copy of this [ChartSourceSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ChartSourceSummary copyWith({
    String? chartObjectId,
    String? title,
    String? type,
    bool? is3D,
    String? sheetName,
    bool? onChartSheet,
    bool? unsupported,
    String? previewSnapshotJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChartSourceSummary',
      'chartObjectId': chartObjectId,
      'title': title,
      'type': type,
      'is3D': is3D,
      'sheetName': sheetName,
      'onChartSheet': onChartSheet,
      'unsupported': unsupported,
      if (previewSnapshotJson != null)
        'previewSnapshotJson': previewSnapshotJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChartSourceSummary',
      'chartObjectId': chartObjectId,
      'title': title,
      'type': type,
      'is3D': is3D,
      'sheetName': sheetName,
      'onChartSheet': onChartSheet,
      'unsupported': unsupported,
      if (previewSnapshotJson != null)
        'previewSnapshotJson': previewSnapshotJson,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ChartSourceSummaryImpl extends ChartSourceSummary {
  _ChartSourceSummaryImpl({
    required String chartObjectId,
    required String title,
    required String type,
    required bool is3D,
    required String sheetName,
    required bool onChartSheet,
    required bool unsupported,
    String? previewSnapshotJson,
  }) : super._(
         chartObjectId: chartObjectId,
         title: title,
         type: type,
         is3D: is3D,
         sheetName: sheetName,
         onChartSheet: onChartSheet,
         unsupported: unsupported,
         previewSnapshotJson: previewSnapshotJson,
       );

  /// Returns a shallow copy of this [ChartSourceSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ChartSourceSummary copyWith({
    String? chartObjectId,
    String? title,
    String? type,
    bool? is3D,
    String? sheetName,
    bool? onChartSheet,
    bool? unsupported,
    Object? previewSnapshotJson = _Undefined,
  }) {
    return ChartSourceSummary(
      chartObjectId: chartObjectId ?? this.chartObjectId,
      title: title ?? this.title,
      type: type ?? this.type,
      is3D: is3D ?? this.is3D,
      sheetName: sheetName ?? this.sheetName,
      onChartSheet: onChartSheet ?? this.onChartSheet,
      unsupported: unsupported ?? this.unsupported,
      previewSnapshotJson: previewSnapshotJson is String?
          ? previewSnapshotJson
          : this.previewSnapshotJson,
    );
  }
}
