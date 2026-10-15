/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'presentation_event.dart';

/// A command of an audience device or remote (presenter only).
abstract class PresentationCommandEvent extends _i26f4ubs.PresentationEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresentationCommandEvent._({
    required super.serverTimeMs,
    required this.command,
    this.argsJson,
    required this.fromConnectionId,
  });

  factory PresentationCommandEvent({
    required int serverTimeMs,
    required String command,
    String? argsJson,
    required String fromConnectionId,
  }) = _PresentationCommandEventImpl;

  factory PresentationCommandEvent.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationCommandEvent(
      serverTimeMs: jsonSerialization['serverTimeMs'] as int,
      command: jsonSerialization['command'] as String,
      argsJson: jsonSerialization['argsJson'] as String?,
      fromConnectionId: jsonSerialization['fromConnectionId'] as String,
    );
  }

  String command;

  String? argsJson;

  String fromConnectionId;

  /// Returns a shallow copy of this [PresentationCommandEvent]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  PresentationCommandEvent copyWith({
    int? serverTimeMs,
    String? command,
    String? argsJson,
    String? fromConnectionId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationCommandEvent',
      'serverTimeMs': serverTimeMs,
      'command': command,
      if (argsJson != null) 'argsJson': argsJson,
      'fromConnectionId': fromConnectionId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationCommandEvent',
      'serverTimeMs': serverTimeMs,
      'command': command,
      if (argsJson != null) 'argsJson': argsJson,
      'fromConnectionId': fromConnectionId,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresentationCommandEventImpl extends PresentationCommandEvent {
  _PresentationCommandEventImpl({
    required int serverTimeMs,
    required String command,
    String? argsJson,
    required String fromConnectionId,
  }) : super._(
         serverTimeMs: serverTimeMs,
         command: command,
         argsJson: argsJson,
         fromConnectionId: fromConnectionId,
       );

  /// Returns a shallow copy of this [PresentationCommandEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresentationCommandEvent copyWith({
    int? serverTimeMs,
    String? command,
    Object? argsJson = _Undefined,
    String? fromConnectionId,
  }) {
    return PresentationCommandEvent(
      serverTimeMs: serverTimeMs ?? this.serverTimeMs,
      command: command ?? this.command,
      argsJson: argsJson is String? ? argsJson : this.argsJson,
      fromConnectionId: fromConnectionId ?? this.fromConnectionId,
    );
  }
}
