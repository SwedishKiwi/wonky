/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'presence_event.dart';

/// Ephemeral commit hints relayed from another participant (never echoed).
abstract class PresenceHints extends _iototaiw.PresenceEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresenceHints._({
    required this.sessionId,
    required this.hints,
  });

  factory PresenceHints({
    required String sessionId,
    required List<String> hints,
  }) = _PresenceHintsImpl;

  factory PresenceHints.fromJson(Map<String, dynamic> jsonSerialization) {
    return PresenceHints(
      sessionId: jsonSerialization['sessionId'] as String,
      hints: _il4umwa0.Protocol().deserialize<List<String>>(
        jsonSerialization['hints'],
      ),
    );
  }

  String sessionId;

  List<String> hints;

  /// Returns a shallow copy of this [PresenceHints]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  PresenceHints copyWith({
    String? sessionId,
    List<String>? hints,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresenceHints',
      'sessionId': sessionId,
      'hints': hints.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresenceHints',
      'sessionId': sessionId,
      'hints': hints.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresenceHintsImpl extends PresenceHints {
  _PresenceHintsImpl({
    required String sessionId,
    required List<String> hints,
  }) : super._(
         sessionId: sessionId,
         hints: hints,
       );

  /// Returns a shallow copy of this [PresenceHints]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresenceHints copyWith({
    String? sessionId,
    List<String>? hints,
  }) {
    return PresenceHints(
      sessionId: sessionId ?? this.sessionId,
      hints: hints ?? this.hints.map((e0) => e0).toList(),
    );
  }
}
