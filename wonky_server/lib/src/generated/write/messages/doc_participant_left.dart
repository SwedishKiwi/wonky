/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'doc_server_message.dart';

abstract class DocParticipantLeft extends _iototaiw.DocServerMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DocParticipantLeft._({required this.sessionId});

  factory DocParticipantLeft({required String sessionId}) =
      _DocParticipantLeftImpl;

  factory DocParticipantLeft.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocParticipantLeft(
      sessionId: jsonSerialization['sessionId'] as String,
    );
  }

  String sessionId;

  /// Returns a shallow copy of this [DocParticipantLeft]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  DocParticipantLeft copyWith({String? sessionId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocParticipantLeft',
      'sessionId': sessionId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocParticipantLeft',
      'sessionId': sessionId,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _DocParticipantLeftImpl extends DocParticipantLeft {
  _DocParticipantLeftImpl({required String sessionId})
    : super._(sessionId: sessionId);

  /// Returns a shallow copy of this [DocParticipantLeft]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocParticipantLeft copyWith({String? sessionId}) {
    return DocParticipantLeft(sessionId: sessionId ?? this.sessionId);
  }
}
