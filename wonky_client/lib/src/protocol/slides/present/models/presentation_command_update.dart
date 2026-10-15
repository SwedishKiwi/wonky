/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'presentation_update.dart';

/// A command for the presenter (next, previous, nextSlide, previousSlide,
/// goTo, blank, timer); the presenter applies it and broadcasts state.
abstract class PresentationCommandUpdate extends _i26f4ubs.PresentationUpdate
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresentationCommandUpdate._({
    required this.command,
    this.argsJson,
  });

  factory PresentationCommandUpdate({
    required String command,
    String? argsJson,
  }) = _PresentationCommandUpdateImpl;

  factory PresentationCommandUpdate.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationCommandUpdate(
      command: jsonSerialization['command'] as String,
      argsJson: jsonSerialization['argsJson'] as String?,
    );
  }

  String command;

  String? argsJson;

  /// Returns a shallow copy of this [PresentationCommandUpdate]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  PresentationCommandUpdate copyWith({
    String? command,
    String? argsJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationCommandUpdate',
      'command': command,
      if (argsJson != null) 'argsJson': argsJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationCommandUpdate',
      'command': command,
      if (argsJson != null) 'argsJson': argsJson,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresentationCommandUpdateImpl extends PresentationCommandUpdate {
  _PresentationCommandUpdateImpl({
    required String command,
    String? argsJson,
  }) : super._(
         command: command,
         argsJson: argsJson,
       );

  /// Returns a shallow copy of this [PresentationCommandUpdate]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresentationCommandUpdate copyWith({
    String? command,
    Object? argsJson = _Undefined,
  }) {
    return PresentationCommandUpdate(
      command: command ?? this.command,
      argsJson: argsJson is String? ? argsJson : this.argsJson,
    );
  }
}
