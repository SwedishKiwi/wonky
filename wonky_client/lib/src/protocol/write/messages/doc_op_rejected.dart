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

/// The op was rejected; the client must resync.
abstract class DocOpRejected extends _iototaiw.DocServerMessage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DocOpRejected._({
    required this.clientOpId,
    required this.code,
    required this.message,
  });

  factory DocOpRejected({
    required _isc.UuidValue clientOpId,
    required _i9a4p9z2.DocRejectCode code,
    required String message,
  }) = _DocOpRejectedImpl;

  factory DocOpRejected.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocOpRejected(
      clientOpId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['clientOpId'],
      ),
      code: _i9a4p9z2.DocRejectCode.fromJson(
        (jsonSerialization['code'] as String),
      ),
      message: jsonSerialization['message'] as String,
    );
  }

  _isc.UuidValue clientOpId;

  _i9a4p9z2.DocRejectCode code;

  String message;

  /// Returns a shallow copy of this [DocOpRejected]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  DocOpRejected copyWith({
    _isc.UuidValue? clientOpId,
    _i9a4p9z2.DocRejectCode? code,
    String? message,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocOpRejected',
      'clientOpId': clientOpId.toJson(),
      'code': code.toJson(),
      'message': message,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocOpRejected',
      'clientOpId': clientOpId.toJson(),
      'code': code.toJson(),
      'message': message,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _DocOpRejectedImpl extends DocOpRejected {
  _DocOpRejectedImpl({
    required _isc.UuidValue clientOpId,
    required _i9a4p9z2.DocRejectCode code,
    required String message,
  }) : super._(
         clientOpId: clientOpId,
         code: code,
         message: message,
       );

  /// Returns a shallow copy of this [DocOpRejected]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DocOpRejected copyWith({
    _isc.UuidValue? clientOpId,
    _i9a4p9z2.DocRejectCode? code,
    String? message,
  }) {
    return DocOpRejected(
      clientOpId: clientOpId ?? this.clientOpId,
      code: code ?? this.code,
      message: message ?? this.message,
    );
  }
}
