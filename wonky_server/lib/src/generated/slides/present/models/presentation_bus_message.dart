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
import '../../../slides/present/models/presentation_role.dart' as _i0s4aueu;
import '../../../slides/present/models/presentation_state.dart' as _iyq83n0r;

/// Internal session.messages payload on `present:<sessionId>` and
/// `present-deck:<deckUuid>` (Slides 10 §6.1).
abstract class PresentationBusMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationBusMessage._({
    required this.type,
    required this.connectionId,
    required this.sessionId,
    required this.deckUuid,
    required this.userId,
    this.role,
    this.deviceLabel,
    this.displayName,
    this.presenterUserId,
    this.presenterConnected,
    this.state,
    this.stateSentAtMs,
    this.slideId,
    this.x,
    this.y,
    this.inkOp,
    this.strokeId,
    this.strokeJson,
    this.command,
    this.argsJson,
    this.sentAtMs,
    this.startedAtMs,
    this.replyTo,
    this.pairingKey,
    this.admitted,
  });

  factory PresentationBusMessage({
    required String type,
    required String connectionId,
    required String sessionId,
    required String deckUuid,
    required int userId,
    _i0s4aueu.PresentationRole? role,
    String? deviceLabel,
    String? displayName,
    int? presenterUserId,
    bool? presenterConnected,
    _iyq83n0r.PresentationState? state,
    int? stateSentAtMs,
    String? slideId,
    double? x,
    double? y,
    String? inkOp,
    String? strokeId,
    String? strokeJson,
    String? command,
    String? argsJson,
    int? sentAtMs,
    int? startedAtMs,
    String? replyTo,
    String? pairingKey,
    bool? admitted,
  }) = _PresentationBusMessageImpl;

  factory PresentationBusMessage.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationBusMessage(
      type: jsonSerialization['type'] as String,
      connectionId: jsonSerialization['connectionId'] as String,
      sessionId: jsonSerialization['sessionId'] as String,
      deckUuid: jsonSerialization['deckUuid'] as String,
      userId: jsonSerialization['userId'] as int,
      role: jsonSerialization['role'] == null
          ? null
          : _i0s4aueu.PresentationRole.fromJson(
              (jsonSerialization['role'] as String),
            ),
      deviceLabel: jsonSerialization['deviceLabel'] as String?,
      displayName: jsonSerialization['displayName'] as String?,
      presenterUserId: jsonSerialization['presenterUserId'] as int?,
      presenterConnected: jsonSerialization['presenterConnected'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['presenterConnected'],
            ),
      state: jsonSerialization['state'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_iyq83n0r.PresentationState>(
              jsonSerialization['state'],
            ),
      stateSentAtMs: jsonSerialization['stateSentAtMs'] as int?,
      slideId: jsonSerialization['slideId'] as String?,
      x: (jsonSerialization['x'] as num?)?.toDouble(),
      y: (jsonSerialization['y'] as num?)?.toDouble(),
      inkOp: jsonSerialization['inkOp'] as String?,
      strokeId: jsonSerialization['strokeId'] as String?,
      strokeJson: jsonSerialization['strokeJson'] as String?,
      command: jsonSerialization['command'] as String?,
      argsJson: jsonSerialization['argsJson'] as String?,
      sentAtMs: jsonSerialization['sentAtMs'] as int?,
      startedAtMs: jsonSerialization['startedAtMs'] as int?,
      replyTo: jsonSerialization['replyTo'] as String?,
      pairingKey: jsonSerialization['pairingKey'] as String?,
      admitted: jsonSerialization['admitted'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['admitted']),
    );
  }

  /// hello, here, who, meta, joined, bye, away, takeover, state, laser, ink,
  /// command, end, find, found, resolve, resolved.
  String type;

  /// The sending connection.
  String connectionId;

  String sessionId;

  String deckUuid;

  int userId;

  _i0s4aueu.PresentationRole? role;

  String? deviceLabel;

  String? displayName;

  /// The session's presenter account (here, meta, found).
  int? presenterUserId;

  bool? presenterConnected;

  _iyq83n0r.PresentationState? state;

  int? stateSentAtMs;

  String? slideId;

  double? x;

  double? y;

  String? inkOp;

  String? strokeId;

  String? strokeJson;

  String? command;

  String? argsJson;

  int? sentAtMs;

  int? startedAtMs;

  /// here/meta/found: the connection (or find request) answered.
  String? replyTo;

  /// Phone remote pairing (SL-41): the key of a remote's hello, of a
  /// resolved code (resolved).
  String? pairingKey;

  /// here: whether the presenter admits the remote of another account.
  bool? admitted;

  /// Returns a shallow copy of this [PresentationBusMessage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PresentationBusMessage copyWith({
    String? type,
    String? connectionId,
    String? sessionId,
    String? deckUuid,
    int? userId,
    _i0s4aueu.PresentationRole? role,
    String? deviceLabel,
    String? displayName,
    int? presenterUserId,
    bool? presenterConnected,
    _iyq83n0r.PresentationState? state =
        const _UndefinedPresentationBusMessage$state(),
    int? stateSentAtMs,
    String? slideId,
    double? x,
    double? y,
    String? inkOp,
    String? strokeId,
    String? strokeJson,
    String? command,
    String? argsJson,
    int? sentAtMs,
    int? startedAtMs,
    String? replyTo,
    String? pairingKey,
    bool? admitted,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationBusMessage',
      'type': type,
      'connectionId': connectionId,
      'sessionId': sessionId,
      'deckUuid': deckUuid,
      'userId': userId,
      if (role != null) 'role': role?.toJson(),
      if (deviceLabel != null) 'deviceLabel': deviceLabel,
      if (displayName != null) 'displayName': displayName,
      if (presenterUserId != null) 'presenterUserId': presenterUserId,
      if (presenterConnected != null) 'presenterConnected': presenterConnected,
      if (state != null) 'state': state?.toJson(),
      if (stateSentAtMs != null) 'stateSentAtMs': stateSentAtMs,
      if (slideId != null) 'slideId': slideId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (inkOp != null) 'inkOp': inkOp,
      if (strokeId != null) 'strokeId': strokeId,
      if (strokeJson != null) 'strokeJson': strokeJson,
      if (command != null) 'command': command,
      if (argsJson != null) 'argsJson': argsJson,
      if (sentAtMs != null) 'sentAtMs': sentAtMs,
      if (startedAtMs != null) 'startedAtMs': startedAtMs,
      if (replyTo != null) 'replyTo': replyTo,
      if (pairingKey != null) 'pairingKey': pairingKey,
      if (admitted != null) 'admitted': admitted,
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

class _UndefinedPresentationBusMessage$state extends _is.UndefinedSentinel
    implements _iyq83n0r.PresentationState {
  const _UndefinedPresentationBusMessage$state();
}

class _PresentationBusMessageImpl extends PresentationBusMessage {
  _PresentationBusMessageImpl({
    required String type,
    required String connectionId,
    required String sessionId,
    required String deckUuid,
    required int userId,
    _i0s4aueu.PresentationRole? role,
    String? deviceLabel,
    String? displayName,
    int? presenterUserId,
    bool? presenterConnected,
    _iyq83n0r.PresentationState? state,
    int? stateSentAtMs,
    String? slideId,
    double? x,
    double? y,
    String? inkOp,
    String? strokeId,
    String? strokeJson,
    String? command,
    String? argsJson,
    int? sentAtMs,
    int? startedAtMs,
    String? replyTo,
    String? pairingKey,
    bool? admitted,
  }) : super._(
         type: type,
         connectionId: connectionId,
         sessionId: sessionId,
         deckUuid: deckUuid,
         userId: userId,
         role: role,
         deviceLabel: deviceLabel,
         displayName: displayName,
         presenterUserId: presenterUserId,
         presenterConnected: presenterConnected,
         state: state,
         stateSentAtMs: stateSentAtMs,
         slideId: slideId,
         x: x,
         y: y,
         inkOp: inkOp,
         strokeId: strokeId,
         strokeJson: strokeJson,
         command: command,
         argsJson: argsJson,
         sentAtMs: sentAtMs,
         startedAtMs: startedAtMs,
         replyTo: replyTo,
         pairingKey: pairingKey,
         admitted: admitted,
       );

  /// Returns a shallow copy of this [PresentationBusMessage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresentationBusMessage copyWith({
    String? type,
    String? connectionId,
    String? sessionId,
    String? deckUuid,
    int? userId,
    Object? role = _Undefined,
    Object? deviceLabel = _Undefined,
    Object? displayName = _Undefined,
    Object? presenterUserId = _Undefined,
    Object? presenterConnected = _Undefined,
    _iyq83n0r.PresentationState? state =
        const _UndefinedPresentationBusMessage$state(),
    Object? stateSentAtMs = _Undefined,
    Object? slideId = _Undefined,
    Object? x = _Undefined,
    Object? y = _Undefined,
    Object? inkOp = _Undefined,
    Object? strokeId = _Undefined,
    Object? strokeJson = _Undefined,
    Object? command = _Undefined,
    Object? argsJson = _Undefined,
    Object? sentAtMs = _Undefined,
    Object? startedAtMs = _Undefined,
    Object? replyTo = _Undefined,
    Object? pairingKey = _Undefined,
    Object? admitted = _Undefined,
  }) {
    return PresentationBusMessage(
      type: type ?? this.type,
      connectionId: connectionId ?? this.connectionId,
      sessionId: sessionId ?? this.sessionId,
      deckUuid: deckUuid ?? this.deckUuid,
      userId: userId ?? this.userId,
      role: role is _i0s4aueu.PresentationRole? ? role : this.role,
      deviceLabel: deviceLabel is String? ? deviceLabel : this.deviceLabel,
      displayName: displayName is String? ? displayName : this.displayName,
      presenterUserId: presenterUserId is int?
          ? presenterUserId
          : this.presenterUserId,
      presenterConnected: presenterConnected is bool?
          ? presenterConnected
          : this.presenterConnected,
      state: state is _is.UndefinedSentinel ? this.state?.copyWith() : state,
      stateSentAtMs: stateSentAtMs is int? ? stateSentAtMs : this.stateSentAtMs,
      slideId: slideId is String? ? slideId : this.slideId,
      x: x is double? ? x : this.x,
      y: y is double? ? y : this.y,
      inkOp: inkOp is String? ? inkOp : this.inkOp,
      strokeId: strokeId is String? ? strokeId : this.strokeId,
      strokeJson: strokeJson is String? ? strokeJson : this.strokeJson,
      command: command is String? ? command : this.command,
      argsJson: argsJson is String? ? argsJson : this.argsJson,
      sentAtMs: sentAtMs is int? ? sentAtMs : this.sentAtMs,
      startedAtMs: startedAtMs is int? ? startedAtMs : this.startedAtMs,
      replyTo: replyTo is String? ? replyTo : this.replyTo,
      pairingKey: pairingKey is String? ? pairingKey : this.pairingKey,
      admitted: admitted is bool? ? admitted : this.admitted,
    );
  }
}
