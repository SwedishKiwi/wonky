/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;
import 'package:wonky_server/src/generated/protocol.dart' as _il4umwa0;
import '../../platform/presence/participant.dart' as _iekwkhcm;
import '../../write/messages/doc_server_message.dart' as _idq777ra;

/// Internal session.messages payload on `doc:<documentUuid>`.
abstract class DocBusMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DocBusMessage._({
    required this.type,
    this.originSessionId,
    this.op,
    this.cursor,
    this.participant,
    this.sessionId,
    this.meta,
    this.userId,
  });

  factory DocBusMessage({
    required String type,
    String? originSessionId,
    _idq777ra.DocRemoteOp? op,
    _idq777ra.DocRemoteCursor? cursor,
    _iekwkhcm.Participant? participant,
    String? sessionId,
    _idq777ra.DocMetaChanged? meta,
    int? userId,
  }) = _DocBusMessageImpl;

  factory DocBusMessage.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocBusMessage(
      type: jsonSerialization['type'] as String,
      originSessionId: jsonSerialization['originSessionId'] as String?,
      op: jsonSerialization['op'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_idq777ra.DocRemoteOp>(
              jsonSerialization['op'],
            ),
      cursor: jsonSerialization['cursor'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_idq777ra.DocRemoteCursor>(
              jsonSerialization['cursor'],
            ),
      participant: jsonSerialization['participant'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_iekwkhcm.Participant>(
              jsonSerialization['participant'],
            ),
      sessionId: jsonSerialization['sessionId'] as String?,
      meta: jsonSerialization['meta'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_idq777ra.DocMetaChanged>(
              jsonSerialization['meta'],
            ),
      userId: jsonSerialization['userId'] as int?,
    );
  }

  /// op, cursor, joined, left, meta, role, notice.
  String type;

  String? originSessionId;

  _idq777ra.DocRemoteOp? op;

  _idq777ra.DocRemoteCursor? cursor;

  _iekwkhcm.Participant? participant;

  String? sessionId;

  _idq777ra.DocMetaChanged? meta;

  /// For role changes: the affected user (null = re-check everyone).
  int? userId;

  /// Returns a shallow copy of this [DocBusMessage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DocBusMessage copyWith({
    String? type,
    String? originSessionId,
    _idq777ra.DocRemoteOp? op = const _UndefinedDocBusMessage$op(),
    _idq777ra.DocRemoteCursor? cursor = const _UndefinedDocBusMessage$cursor(),
    _iekwkhcm.Participant? participant =
        const _UndefinedDocBusMessage$participant(),
    String? sessionId,
    _idq777ra.DocMetaChanged? meta = const _UndefinedDocBusMessage$meta(),
    int? userId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocBusMessage',
      'type': type,
      if (originSessionId != null) 'originSessionId': originSessionId,
      if (op != null) 'op': op?.toJson(),
      if (cursor != null) 'cursor': cursor?.toJson(),
      if (participant != null) 'participant': participant?.toJson(),
      if (sessionId != null) 'sessionId': sessionId,
      if (meta != null) 'meta': meta?.toJson(),
      if (userId != null) 'userId': userId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedDocBusMessage$op extends _is.UndefinedSentinel
    implements _idq777ra.DocRemoteOp {
  const _UndefinedDocBusMessage$op();
}

class _UndefinedDocBusMessage$cursor extends _is.UndefinedSentinel
    implements _idq777ra.DocRemoteCursor {
  const _UndefinedDocBusMessage$cursor();
}

class _UndefinedDocBusMessage$participant extends _is.UndefinedSentinel
    implements _iekwkhcm.Participant {
  const _UndefinedDocBusMessage$participant();
}

class _UndefinedDocBusMessage$meta extends _is.UndefinedSentinel
    implements _idq777ra.DocMetaChanged {
  const _UndefinedDocBusMessage$meta();
}

class _DocBusMessageImpl extends DocBusMessage {
  _DocBusMessageImpl({
    required String type,
    String? originSessionId,
    _idq777ra.DocRemoteOp? op,
    _idq777ra.DocRemoteCursor? cursor,
    _iekwkhcm.Participant? participant,
    String? sessionId,
    _idq777ra.DocMetaChanged? meta,
    int? userId,
  }) : super._(
         type: type,
         originSessionId: originSessionId,
         op: op,
         cursor: cursor,
         participant: participant,
         sessionId: sessionId,
         meta: meta,
         userId: userId,
       );

  /// Returns a shallow copy of this [DocBusMessage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocBusMessage copyWith({
    String? type,
    Object? originSessionId = _Undefined,
    _idq777ra.DocRemoteOp? op = const _UndefinedDocBusMessage$op(),
    _idq777ra.DocRemoteCursor? cursor = const _UndefinedDocBusMessage$cursor(),
    _iekwkhcm.Participant? participant =
        const _UndefinedDocBusMessage$participant(),
    Object? sessionId = _Undefined,
    _idq777ra.DocMetaChanged? meta = const _UndefinedDocBusMessage$meta(),
    Object? userId = _Undefined,
  }) {
    return DocBusMessage(
      type: type ?? this.type,
      originSessionId: originSessionId is String?
          ? originSessionId
          : this.originSessionId,
      op: op is _is.UndefinedSentinel ? this.op?.copyWith() : op,
      cursor: cursor is _is.UndefinedSentinel
          ? this.cursor?.copyWith()
          : cursor,
      participant: participant is _is.UndefinedSentinel
          ? this.participant?.copyWith()
          : participant,
      sessionId: sessionId is String? ? sessionId : this.sessionId,
      meta: meta is _is.UndefinedSentinel ? this.meta?.copyWith() : meta,
      userId: userId is int? ? userId : this.userId,
    );
  }
}
