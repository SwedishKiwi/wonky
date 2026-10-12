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

abstract class DocAck extends _iototaiw.DocServerMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DocAck._({
    required this.clientOpId,
    required this.revision,
  });

  factory DocAck({
    required _is.UuidValue clientOpId,
    required int revision,
  }) = _DocAckImpl;

  factory DocAck.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocAck(
      clientOpId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['clientOpId'],
      ),
      revision: jsonSerialization['revision'] as int,
    );
  }

  _is.UuidValue clientOpId;

  int revision;

  /// Returns a shallow copy of this [DocAck]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  DocAck copyWith({
    _is.UuidValue? clientOpId,
    int? revision,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocAck',
      'clientOpId': clientOpId.toJson(),
      'revision': revision,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocAck',
      'clientOpId': clientOpId.toJson(),
      'revision': revision,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _DocAckImpl extends DocAck {
  _DocAckImpl({
    required _is.UuidValue clientOpId,
    required int revision,
  }) : super._(
         clientOpId: clientOpId,
         revision: revision,
       );

  /// Returns a shallow copy of this [DocAck]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocAck copyWith({
    _is.UuidValue? clientOpId,
    int? revision,
  }) {
    return DocAck(
      clientOpId: clientOpId ?? this.clientOpId,
      revision: revision ?? this.revision,
    );
  }
}
