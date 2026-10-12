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
import '../../platform/presence/presence_state.dart' as _ia3e8v5g;

/// Internal session.messages payload on `presence:<itemUuid>`.
abstract class PresenceBusMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresenceBusMessage._({
    required this.type,
    required this.sessionId,
    this.participant,
    this.state,
    this.cursorJson,
    this.mode,
    this.hints,
    this.target,
    this.replyTo,
    this.noticeKind,
    this.noticePayloadJson,
  });

  factory PresenceBusMessage({
    required String type,
    required String sessionId,
    _iekwkhcm.Participant? participant,
    _ia3e8v5g.PresenceState? state,
    String? cursorJson,
    String? mode,
    List<String>? hints,
    String? target,
    String? replyTo,
    String? noticeKind,
    String? noticePayloadJson,
  }) = _PresenceBusMessageImpl;

  factory PresenceBusMessage.fromJson(Map<String, dynamic> jsonSerialization) {
    return PresenceBusMessage(
      type: jsonSerialization['type'] as String,
      sessionId: jsonSerialization['sessionId'] as String,
      participant: jsonSerialization['participant'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_iekwkhcm.Participant>(
              jsonSerialization['participant'],
            ),
      state: jsonSerialization['state'] == null
          ? null
          : _ia3e8v5g.PresenceState.fromJson(
              (jsonSerialization['state'] as String),
            ),
      cursorJson: jsonSerialization['cursorJson'] as String?,
      mode: jsonSerialization['mode'] as String?,
      hints: jsonSerialization['hints'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<List<String>>(
              jsonSerialization['hints'],
            ),
      target: jsonSerialization['target'] as String?,
      replyTo: jsonSerialization['replyTo'] as String?,
      noticeKind: jsonSerialization['noticeKind'] as String?,
      noticePayloadJson: jsonSerialization['noticePayloadJson'] as String?,
    );
  }

  /// hello, here, update, hints, follow, bye, notice.
  String type;

  String sessionId;

  _iekwkhcm.Participant? participant;

  _ia3e8v5g.PresenceState? state;

  String? cursorJson;

  String? mode;

  List<String>? hints;

  /// follow: the followed session (null = stopped following).
  String? target;

  /// here: the session that said hello.
  String? replyTo;

  String? noticeKind;

  String? noticePayloadJson;

  /// Returns a shallow copy of this [PresenceBusMessage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PresenceBusMessage copyWith({
    String? type,
    String? sessionId,
    _iekwkhcm.Participant? participant =
        const _UndefinedPresenceBusMessage$participant(),
    _ia3e8v5g.PresenceState? state,
    String? cursorJson,
    String? mode,
    List<String>? hints = const _is.$UndefinedList<String>(),
    String? target,
    String? replyTo,
    String? noticeKind,
    String? noticePayloadJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresenceBusMessage',
      'type': type,
      'sessionId': sessionId,
      if (participant != null) 'participant': participant?.toJson(),
      if (state != null) 'state': state?.toJson(),
      if (cursorJson != null) 'cursorJson': cursorJson,
      if (mode != null) 'mode': mode,
      if (hints != null) 'hints': hints?.toJson(),
      if (target != null) 'target': target,
      if (replyTo != null) 'replyTo': replyTo,
      if (noticeKind != null) 'noticeKind': noticeKind,
      if (noticePayloadJson != null) 'noticePayloadJson': noticePayloadJson,
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

class _UndefinedPresenceBusMessage$participant extends _is.UndefinedSentinel
    implements _iekwkhcm.Participant {
  const _UndefinedPresenceBusMessage$participant();
}

class _PresenceBusMessageImpl extends PresenceBusMessage {
  _PresenceBusMessageImpl({
    required String type,
    required String sessionId,
    _iekwkhcm.Participant? participant,
    _ia3e8v5g.PresenceState? state,
    String? cursorJson,
    String? mode,
    List<String>? hints,
    String? target,
    String? replyTo,
    String? noticeKind,
    String? noticePayloadJson,
  }) : super._(
         type: type,
         sessionId: sessionId,
         participant: participant,
         state: state,
         cursorJson: cursorJson,
         mode: mode,
         hints: hints,
         target: target,
         replyTo: replyTo,
         noticeKind: noticeKind,
         noticePayloadJson: noticePayloadJson,
       );

  /// Returns a shallow copy of this [PresenceBusMessage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresenceBusMessage copyWith({
    String? type,
    String? sessionId,
    _iekwkhcm.Participant? participant =
        const _UndefinedPresenceBusMessage$participant(),
    Object? state = _Undefined,
    Object? cursorJson = _Undefined,
    Object? mode = _Undefined,
    List<String>? hints = const _is.$UndefinedList<String>(),
    Object? target = _Undefined,
    Object? replyTo = _Undefined,
    Object? noticeKind = _Undefined,
    Object? noticePayloadJson = _Undefined,
  }) {
    return PresenceBusMessage(
      type: type ?? this.type,
      sessionId: sessionId ?? this.sessionId,
      participant: participant is _is.UndefinedSentinel
          ? this.participant?.copyWith()
          : participant,
      state: state is _ia3e8v5g.PresenceState? ? state : this.state,
      cursorJson: cursorJson is String? ? cursorJson : this.cursorJson,
      mode: mode is String? ? mode : this.mode,
      hints: hints is _is.UndefinedSentinel
          ? this.hints?.map((e0) => e0).toList()
          : hints,
      target: target is String? ? target : this.target,
      replyTo: replyTo is String? ? replyTo : this.replyTo,
      noticeKind: noticeKind is String? ? noticeKind : this.noticeKind,
      noticePayloadJson: noticePayloadJson is String?
          ? noticePayloadJson
          : this.noticePayloadJson,
    );
  }
}
