/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'doc_client_message.dart';

abstract class DocPing extends _iototaiw.DocClientMessage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DocPing._({required this.t});

  factory DocPing({required int t}) = _DocPingImpl;

  factory DocPing.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocPing(t: jsonSerialization['t'] as int);
  }

  int t;

  /// Returns a shallow copy of this [DocPing]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  DocPing copyWith({int? t});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocPing',
      't': t,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocPing',
      't': t,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _DocPingImpl extends DocPing {
  _DocPingImpl({required int t}) : super._(t: t);

  /// Returns a shallow copy of this [DocPing]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DocPing copyWith({int? t}) {
    return DocPing(t: t ?? this.t);
  }
}
