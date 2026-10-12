/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'presence_event.dart';

/// How many sessions follow the receiving session.
abstract class PresenceFollowerCount extends _iototaiw.PresenceEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresenceFollowerCount._({required this.count});

  factory PresenceFollowerCount({required int count}) =
      _PresenceFollowerCountImpl;

  factory PresenceFollowerCount.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresenceFollowerCount(count: jsonSerialization['count'] as int);
  }

  int count;

  /// Returns a shallow copy of this [PresenceFollowerCount]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  PresenceFollowerCount copyWith({int? count});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresenceFollowerCount',
      'count': count,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresenceFollowerCount',
      'count': count,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresenceFollowerCountImpl extends PresenceFollowerCount {
  _PresenceFollowerCountImpl({required int count}) : super._(count: count);

  /// Returns a shallow copy of this [PresenceFollowerCount]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresenceFollowerCount copyWith({int? count}) {
    return PresenceFollowerCount(count: count ?? this.count);
  }
}
