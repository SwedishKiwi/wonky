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

/// One linked chart to check (Slides 08 §5.2).
abstract class ChartLinkProbe
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ChartLinkProbe._({
    required this.elementId,
    required this.spreadsheetUuid,
    required this.chartObjectId,
    required this.sourceVersion,
  });

  factory ChartLinkProbe({
    required String elementId,
    required _is.UuidValue spreadsheetUuid,
    required String chartObjectId,
    required String sourceVersion,
  }) = _ChartLinkProbeImpl;

  factory ChartLinkProbe.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChartLinkProbe(
      elementId: jsonSerialization['elementId'] as String,
      spreadsheetUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spreadsheetUuid'],
      ),
      chartObjectId: jsonSerialization['chartObjectId'] as String,
      sourceVersion: jsonSerialization['sourceVersion'] as String,
    );
  }

  /// The chart element (echoed back).
  String elementId;

  /// Drive item uuid of the spreadsheet (`ChartLink.spreadsheetItemUuid`).
  _is.UuidValue spreadsheetUuid;

  /// Sheets `EmbeddedObject` id of the chart.
  String chartObjectId;

  /// The snapshot's `sourceVersion` token.
  String sourceVersion;

  /// Returns a shallow copy of this [ChartLinkProbe]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ChartLinkProbe copyWith({
    String? elementId,
    _is.UuidValue? spreadsheetUuid,
    String? chartObjectId,
    String? sourceVersion,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChartLinkProbe',
      'elementId': elementId,
      'spreadsheetUuid': spreadsheetUuid.toJson(),
      'chartObjectId': chartObjectId,
      'sourceVersion': sourceVersion,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChartLinkProbe',
      'elementId': elementId,
      'spreadsheetUuid': spreadsheetUuid.toJson(),
      'chartObjectId': chartObjectId,
      'sourceVersion': sourceVersion,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _ChartLinkProbeImpl extends ChartLinkProbe {
  _ChartLinkProbeImpl({
    required String elementId,
    required _is.UuidValue spreadsheetUuid,
    required String chartObjectId,
    required String sourceVersion,
  }) : super._(
         elementId: elementId,
         spreadsheetUuid: spreadsheetUuid,
         chartObjectId: chartObjectId,
         sourceVersion: sourceVersion,
       );

  /// Returns a shallow copy of this [ChartLinkProbe]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ChartLinkProbe copyWith({
    String? elementId,
    _is.UuidValue? spreadsheetUuid,
    String? chartObjectId,
    String? sourceVersion,
  }) {
    return ChartLinkProbe(
      elementId: elementId ?? this.elementId,
      spreadsheetUuid: spreadsheetUuid ?? this.spreadsheetUuid,
      chartObjectId: chartObjectId ?? this.chartObjectId,
      sourceVersion: sourceVersion ?? this.sourceVersion,
    );
  }
}
