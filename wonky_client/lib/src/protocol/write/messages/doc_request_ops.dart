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

/// Gap fill: the server answers with DocRemoteOp messages.
abstract class DocRequestOps extends _iototaiw.DocClientMessage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DocRequestOps._({
    required this.fromRevision,
    required this.toRevision,
  });

  factory DocRequestOps({
    required int fromRevision,
    required int toRevision,
  }) = _DocRequestOpsImpl;

  factory DocRequestOps.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocRequestOps(
      fromRevision: jsonSerialization['fromRevision'] as int,
      toRevision: jsonSerialization['toRevision'] as int,
    );
  }

  int fromRevision;

  int toRevision;

  /// Returns a shallow copy of this [DocRequestOps]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  DocRequestOps copyWith({
    int? fromRevision,
    int? toRevision,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocRequestOps',
      'fromRevision': fromRevision,
      'toRevision': toRevision,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocRequestOps',
      'fromRevision': fromRevision,
      'toRevision': toRevision,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _DocRequestOpsImpl extends DocRequestOps {
  _DocRequestOpsImpl({
    required int fromRevision,
    required int toRevision,
  }) : super._(
         fromRevision: fromRevision,
         toRevision: toRevision,
       );

  /// Returns a shallow copy of this [DocRequestOps]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DocRequestOps copyWith({
    int? fromRevision,
    int? toRevision,
  }) {
    return DocRequestOps(
      fromRevision: fromRevision ?? this.fromRevision,
      toRevision: toRevision ?? this.toRevision,
    );
  }
}
