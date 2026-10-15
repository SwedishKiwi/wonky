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
import '../../../slides/charts/models/chart_link_state.dart' as _ixmehz0p;

/// The result of checking one link (Slides 08 §5.2).
abstract class ChartLinkStatus
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ChartLinkStatus._({
    required this.elementId,
    required this.status,
    this.newVersion,
    this.summary,
  });

  factory ChartLinkStatus({
    required String elementId,
    required _ixmehz0p.ChartLinkState status,
    String? newVersion,
    String? summary,
  }) = _ChartLinkStatusImpl;

  factory ChartLinkStatus.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChartLinkStatus(
      elementId: jsonSerialization['elementId'] as String,
      status: _ixmehz0p.ChartLinkState.fromJson(
        (jsonSerialization['status'] as String),
      ),
      newVersion: jsonSerialization['newVersion'] as String?,
      summary: jsonSerialization['summary'] as String?,
    );
  }

  String elementId;

  _ixmehz0p.ChartLinkState status;

  /// The current token: `upToDate` with a newer change log (store it as a
  /// maintenance write) or `changed`.
  String? newVersion;

  /// "Data changed", "Chart style changed" or "Data and style changed".
  String? summary;

  /// Returns a shallow copy of this [ChartLinkStatus]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ChartLinkStatus copyWith({
    String? elementId,
    _ixmehz0p.ChartLinkState? status,
    String? newVersion,
    String? summary,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChartLinkStatus',
      'elementId': elementId,
      'status': status.toJson(),
      if (newVersion != null) 'newVersion': newVersion,
      if (summary != null) 'summary': summary,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChartLinkStatus',
      'elementId': elementId,
      'status': status.toJson(),
      if (newVersion != null) 'newVersion': newVersion,
      if (summary != null) 'summary': summary,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ChartLinkStatusImpl extends ChartLinkStatus {
  _ChartLinkStatusImpl({
    required String elementId,
    required _ixmehz0p.ChartLinkState status,
    String? newVersion,
    String? summary,
  }) : super._(
         elementId: elementId,
         status: status,
         newVersion: newVersion,
         summary: summary,
       );

  /// Returns a shallow copy of this [ChartLinkStatus]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ChartLinkStatus copyWith({
    String? elementId,
    _ixmehz0p.ChartLinkState? status,
    Object? newVersion = _Undefined,
    Object? summary = _Undefined,
  }) {
    return ChartLinkStatus(
      elementId: elementId ?? this.elementId,
      status: status ?? this.status,
      newVersion: newVersion is String? ? newVersion : this.newVersion,
      summary: summary is String? ? summary : this.summary,
    );
  }
}
