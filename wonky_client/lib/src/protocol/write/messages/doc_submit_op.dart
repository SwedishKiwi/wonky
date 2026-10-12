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

/// A local change based on [baseRevision].
abstract class DocSubmitOp extends _iototaiw.DocClientMessage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DocSubmitOp._({
    required this.clientOpId,
    required this.baseRevision,
    required this.deltaJson,
    required this.kind,
    this.groupId,
  });

  factory DocSubmitOp({
    required _isc.UuidValue clientOpId,
    required int baseRevision,
    required String deltaJson,
    required _idnphvog.DocumentOpKind kind,
    String? groupId,
  }) = _DocSubmitOpImpl;

  factory DocSubmitOp.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocSubmitOp(
      clientOpId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['clientOpId'],
      ),
      baseRevision: jsonSerialization['baseRevision'] as int,
      deltaJson: jsonSerialization['deltaJson'] as String,
      kind: _idnphvog.DocumentOpKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      groupId: jsonSerialization['groupId'] as String?,
    );
  }

  _isc.UuidValue clientOpId;

  int baseRevision;

  String deltaJson;

  _idnphvog.DocumentOpKind kind;

  /// Groups ops that form one undo step (AI/MCP edits).
  String? groupId;

  /// Returns a shallow copy of this [DocSubmitOp]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  DocSubmitOp copyWith({
    _isc.UuidValue? clientOpId,
    int? baseRevision,
    String? deltaJson,
    _idnphvog.DocumentOpKind? kind,
    String? groupId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocSubmitOp',
      'clientOpId': clientOpId.toJson(),
      'baseRevision': baseRevision,
      'deltaJson': deltaJson,
      'kind': kind.toJson(),
      if (groupId != null) 'groupId': groupId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocSubmitOp',
      'clientOpId': clientOpId.toJson(),
      'baseRevision': baseRevision,
      'deltaJson': deltaJson,
      'kind': kind.toJson(),
      if (groupId != null) 'groupId': groupId,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _DocSubmitOpImpl extends DocSubmitOp {
  _DocSubmitOpImpl({
    required _isc.UuidValue clientOpId,
    required int baseRevision,
    required String deltaJson,
    required _idnphvog.DocumentOpKind kind,
    String? groupId,
  }) : super._(
         clientOpId: clientOpId,
         baseRevision: baseRevision,
         deltaJson: deltaJson,
         kind: kind,
         groupId: groupId,
       );

  /// Returns a shallow copy of this [DocSubmitOp]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DocSubmitOp copyWith({
    _isc.UuidValue? clientOpId,
    int? baseRevision,
    String? deltaJson,
    _idnphvog.DocumentOpKind? kind,
    Object? groupId = _Undefined,
  }) {
    return DocSubmitOp(
      clientOpId: clientOpId ?? this.clientOpId,
      baseRevision: baseRevision ?? this.baseRevision,
      deltaJson: deltaJson ?? this.deltaJson,
      kind: kind ?? this.kind,
      groupId: groupId is String? ? groupId : this.groupId,
    );
  }
}
