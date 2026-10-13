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

/// One day of an activity trend (UTC day).
abstract class ActivityTrendPoint
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ActivityTrendPoint._({
    required this.day,
    required this.count,
  });

  factory ActivityTrendPoint({
    required DateTime day,
    required int count,
  }) = _ActivityTrendPointImpl;

  factory ActivityTrendPoint.fromJson(Map<String, dynamic> jsonSerialization) {
    return ActivityTrendPoint(
      day: _isc.DateTimeJsonExtension.fromJson(jsonSerialization['day']),
      count: jsonSerialization['count'] as int,
    );
  }

  DateTime day;

  int count;

  /// Returns a shallow copy of this [ActivityTrendPoint]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ActivityTrendPoint copyWith({
    DateTime? day,
    int? count,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ActivityTrendPoint',
      'day': day.toJson(),
      'count': count,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ActivityTrendPoint',
      'day': day.toJson(),
      'count': count,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _ActivityTrendPointImpl extends ActivityTrendPoint {
  _ActivityTrendPointImpl({
    required DateTime day,
    required int count,
  }) : super._(
         day: day,
         count: count,
       );

  /// Returns a shallow copy of this [ActivityTrendPoint]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ActivityTrendPoint copyWith({
    DateTime? day,
    int? count,
  }) {
    return ActivityTrendPoint(
      day: day ?? this.day,
      count: count ?? this.count,
    );
  }
}
