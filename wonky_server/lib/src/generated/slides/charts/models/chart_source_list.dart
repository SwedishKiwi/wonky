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
import '../../../slides/charts/models/chart_source_summary.dart' as _ify8edcx;

/// The charts of a spreadsheet (Slides 08 §4.2, §13 `listCharts`).
abstract class ChartSourceList
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ChartSourceList._({
    required this.spreadsheetTitle,
    required this.charts,
    required this.exportAllowed,
  });

  factory ChartSourceList({
    required String spreadsheetTitle,
    required List<_ify8edcx.ChartSourceSummary> charts,
    required bool exportAllowed,
  }) = _ChartSourceListImpl;

  factory ChartSourceList.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChartSourceList(
      spreadsheetTitle: jsonSerialization['spreadsheetTitle'] as String,
      charts: _il4umwa0.Protocol()
          .deserialize<List<_ify8edcx.ChartSourceSummary>>(
            jsonSerialization['charts'],
          ),
      exportAllowed: _is.BoolJsonExtension.fromJson(
        jsonSerialization['exportAllowed'],
      ),
    );
  }

  String spreadsheetTitle;

  List<_ify8edcx.ChartSourceSummary> charts;

  /// Whether the caller may copy charts (editor+, or `nonEditorsCanExport`).
  bool exportAllowed;

  /// Returns a shallow copy of this [ChartSourceList]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ChartSourceList copyWith({
    String? spreadsheetTitle,
    List<_ify8edcx.ChartSourceSummary>? charts,
    bool? exportAllowed,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChartSourceList',
      'spreadsheetTitle': spreadsheetTitle,
      'charts': charts.toJson(valueToJson: (v) => v.toJson()),
      'exportAllowed': exportAllowed,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChartSourceList',
      'spreadsheetTitle': spreadsheetTitle,
      'charts': charts.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'exportAllowed': exportAllowed,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _ChartSourceListImpl extends ChartSourceList {
  _ChartSourceListImpl({
    required String spreadsheetTitle,
    required List<_ify8edcx.ChartSourceSummary> charts,
    required bool exportAllowed,
  }) : super._(
         spreadsheetTitle: spreadsheetTitle,
         charts: charts,
         exportAllowed: exportAllowed,
       );

  /// Returns a shallow copy of this [ChartSourceList]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ChartSourceList copyWith({
    String? spreadsheetTitle,
    List<_ify8edcx.ChartSourceSummary>? charts,
    bool? exportAllowed,
  }) {
    return ChartSourceList(
      spreadsheetTitle: spreadsheetTitle ?? this.spreadsheetTitle,
      charts: charts ?? this.charts.map((e0) => e0.copyWith()).toList(),
      exportAllowed: exportAllowed ?? this.exportAllowed,
    );
  }
}
