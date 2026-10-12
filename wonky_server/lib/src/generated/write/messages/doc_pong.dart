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

abstract class DocPong extends _iototaiw.DocServerMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DocPong._({required this.t});

  factory DocPong({required int t}) = _DocPongImpl;

  factory DocPong.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocPong(t: jsonSerialization['t'] as int);
  }

  int t;

  /// Returns a shallow copy of this [DocPong]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  DocPong copyWith({int? t});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocPong',
      't': t,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocPong',
      't': t,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _DocPongImpl extends DocPong {
  _DocPongImpl({required int t}) : super._(t: t);

  /// Returns a shallow copy of this [DocPong]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocPong copyWith({int? t}) {
    return DocPong(t: t ?? this.t);
  }
}
