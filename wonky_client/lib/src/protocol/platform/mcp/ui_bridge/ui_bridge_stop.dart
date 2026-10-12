/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'ui_bridge_message.dart';

/// App → server: the user pressed *Stop* on the MCP control pill; pending
/// and new calls to this window fail for [pauseMs].
abstract class UiBridgeStop extends _i26f4ubs.UiBridgeMessage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  UiBridgeStop._({required this.pauseMs});

  factory UiBridgeStop({required int pauseMs}) = _UiBridgeStopImpl;

  factory UiBridgeStop.fromJson(Map<String, dynamic> jsonSerialization) {
    return UiBridgeStop(pauseMs: jsonSerialization['pauseMs'] as int);
  }

  int pauseMs;

  /// Returns a shallow copy of this [UiBridgeStop]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  UiBridgeStop copyWith({int? pauseMs});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UiBridgeStop',
      'pauseMs': pauseMs,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UiBridgeStop',
      'pauseMs': pauseMs,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _UiBridgeStopImpl extends UiBridgeStop {
  _UiBridgeStopImpl({required int pauseMs}) : super._(pauseMs: pauseMs);

  /// Returns a shallow copy of this [UiBridgeStop]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UiBridgeStop copyWith({int? pauseMs}) {
    return UiBridgeStop(pauseMs: pauseMs ?? this.pauseMs);
  }
}
