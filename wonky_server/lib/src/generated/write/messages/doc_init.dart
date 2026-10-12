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

/// First message: a snapshot (client too far behind) or the ops since
/// knownRevision.
abstract class DocInit extends _iototaiw.DocServerMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DocInit._({
    required this.revision,
    this.snapshotJson,
    this.ops,
    required this.meta,
    required this.role,
    required this.sessionId,
    required this.participants,
  });

  factory DocInit({
    required int revision,
    String? snapshotJson,
    List<_ix78fzvl.DocumentOpView>? ops,
    required _i7zr8tvm.DocumentMetaView meta,
    required _iv7g6vuy.AccessRole role,
    required String sessionId,
    required List<_iekwkhcm.Participant> participants,
  }) = _DocInitImpl;

  factory DocInit.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocInit(
      revision: jsonSerialization['revision'] as int,
      snapshotJson: jsonSerialization['snapshotJson'] as String?,
      ops: jsonSerialization['ops'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<List<_ix78fzvl.DocumentOpView>>(
              jsonSerialization['ops'],
            ),
      meta: _il4umwa0.Protocol().deserialize<_i7zr8tvm.DocumentMetaView>(
        jsonSerialization['meta'],
      ),
      role: _iv7g6vuy.AccessRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
      sessionId: jsonSerialization['sessionId'] as String,
      participants: _il4umwa0.Protocol()
          .deserialize<List<_iekwkhcm.Participant>>(
            jsonSerialization['participants'],
          ),
    );
  }

  int revision;

  /// Full document delta at [revision] when ops are not sent.
  String? snapshotJson;

  List<_ix78fzvl.DocumentOpView>? ops;

  _i7zr8tvm.DocumentMetaView meta;

  _iv7g6vuy.AccessRole role;

  /// This connection's session id (used by DocRemoteOp.authorSessionId).
  String sessionId;

  List<_iekwkhcm.Participant> participants;

  /// Returns a shallow copy of this [DocInit]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  DocInit copyWith({
    int? revision,
    String? snapshotJson,
    List<_ix78fzvl.DocumentOpView>? ops =
        const _is.$UndefinedList<_ix78fzvl.DocumentOpView>(),
    _i7zr8tvm.DocumentMetaView? meta,
    _iv7g6vuy.AccessRole? role,
    String? sessionId,
    List<_iekwkhcm.Participant>? participants,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocInit',
      'revision': revision,
      if (snapshotJson != null) 'snapshotJson': snapshotJson,
      if (ops != null) 'ops': ops?.toJson(valueToJson: (v) => v.toJson()),
      'meta': meta.toJson(),
      'role': role.toJson(),
      'sessionId': sessionId,
      'participants': participants.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocInit',
      'revision': revision,
      if (snapshotJson != null) 'snapshotJson': snapshotJson,
      if (ops != null)
        'ops': ops?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'meta': meta.toJsonForProtocol(),
      'role': role.toJson(),
      'sessionId': sessionId,
      'participants': participants.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _DocInitImpl extends DocInit {
  _DocInitImpl({
    required int revision,
    String? snapshotJson,
    List<_ix78fzvl.DocumentOpView>? ops,
    required _i7zr8tvm.DocumentMetaView meta,
    required _iv7g6vuy.AccessRole role,
    required String sessionId,
    required List<_iekwkhcm.Participant> participants,
  }) : super._(
         revision: revision,
         snapshotJson: snapshotJson,
         ops: ops,
         meta: meta,
         role: role,
         sessionId: sessionId,
         participants: participants,
       );

  /// Returns a shallow copy of this [DocInit]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocInit copyWith({
    int? revision,
    Object? snapshotJson = _Undefined,
    List<_ix78fzvl.DocumentOpView>? ops =
        const _is.$UndefinedList<_ix78fzvl.DocumentOpView>(),
    _i7zr8tvm.DocumentMetaView? meta,
    _iv7g6vuy.AccessRole? role,
    String? sessionId,
    List<_iekwkhcm.Participant>? participants,
  }) {
    return DocInit(
      revision: revision ?? this.revision,
      snapshotJson: snapshotJson is String? ? snapshotJson : this.snapshotJson,
      ops: ops is _is.UndefinedSentinel
          ? this.ops?.map((e0) => e0.copyWith()).toList()
          : ops,
      meta: meta ?? this.meta.copyWith(),
      role: role ?? this.role,
      sessionId: sessionId ?? this.sessionId,
      participants:
          participants ?? this.participants.map((e0) => e0.copyWith()).toList(),
    );
  }
}
