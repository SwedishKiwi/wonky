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

/// A system notice for everyone on the item, e.g. "Anna restored a version".
abstract class PresenceNotice extends _iototaiw.PresenceEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresenceNotice._({
    required this.kind,
    required this.payloadJson,
  });

  factory PresenceNotice({
    required String kind,
    required String payloadJson,
  }) = _PresenceNoticeImpl;

  factory PresenceNotice.fromJson(Map<String, dynamic> jsonSerialization) {
    return PresenceNotice(
      kind: jsonSerialization['kind'] as String,
      payloadJson: jsonSerialization['payloadJson'] as String,
    );
  }

  String kind;

  String payloadJson;

  /// Returns a shallow copy of this [PresenceNotice]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  PresenceNotice copyWith({
    String? kind,
    String? payloadJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresenceNotice',
      'kind': kind,
      'payloadJson': payloadJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresenceNotice',
      'kind': kind,
      'payloadJson': payloadJson,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresenceNoticeImpl extends PresenceNotice {
  _PresenceNoticeImpl({
    required String kind,
    required String payloadJson,
  }) : super._(
         kind: kind,
         payloadJson: payloadJson,
       );

  /// Returns a shallow copy of this [PresenceNotice]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresenceNotice copyWith({
    String? kind,
    String? payloadJson,
  }) {
    return PresenceNotice(
      kind: kind ?? this.kind,
      payloadJson: payloadJson ?? this.payloadJson,
    );
  }
}
