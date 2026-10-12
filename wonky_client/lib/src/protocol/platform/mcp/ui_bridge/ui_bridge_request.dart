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

/// Server → app: run a `ui.*` tool.
abstract class UiBridgeRequest extends _i26f4ubs.UiBridgeMessage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  UiBridgeRequest._({
    required this.requestId,
    required this.tool,
    required this.argsJson,
    this.agentName,
    required this.timeoutMs,
  });

  factory UiBridgeRequest({
    required String requestId,
    required String tool,
    required String argsJson,
    String? agentName,
    required int timeoutMs,
  }) = _UiBridgeRequestImpl;

  factory UiBridgeRequest.fromJson(Map<String, dynamic> jsonSerialization) {
    return UiBridgeRequest(
      requestId: jsonSerialization['requestId'] as String,
      tool: jsonSerialization['tool'] as String,
      argsJson: jsonSerialization['argsJson'] as String,
      agentName: jsonSerialization['agentName'] as String?,
      timeoutMs: jsonSerialization['timeoutMs'] as int,
    );
  }

  String requestId;

  String tool;

  String argsJson;

  /// Name of the MCP client (shown in the control pill).
  String? agentName;

  int timeoutMs;

  /// Returns a shallow copy of this [UiBridgeRequest]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  UiBridgeRequest copyWith({
    String? requestId,
    String? tool,
    String? argsJson,
    String? agentName,
    int? timeoutMs,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UiBridgeRequest',
      'requestId': requestId,
      'tool': tool,
      'argsJson': argsJson,
      if (agentName != null) 'agentName': agentName,
      'timeoutMs': timeoutMs,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UiBridgeRequest',
      'requestId': requestId,
      'tool': tool,
      'argsJson': argsJson,
      if (agentName != null) 'agentName': agentName,
      'timeoutMs': timeoutMs,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _UiBridgeRequestImpl extends UiBridgeRequest {
  _UiBridgeRequestImpl({
    required String requestId,
    required String tool,
    required String argsJson,
    String? agentName,
    required int timeoutMs,
  }) : super._(
         requestId: requestId,
         tool: tool,
         argsJson: argsJson,
         agentName: agentName,
         timeoutMs: timeoutMs,
       );

  /// Returns a shallow copy of this [UiBridgeRequest]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UiBridgeRequest copyWith({
    String? requestId,
    String? tool,
    String? argsJson,
    Object? agentName = _Undefined,
    int? timeoutMs,
  }) {
    return UiBridgeRequest(
      requestId: requestId ?? this.requestId,
      tool: tool ?? this.tool,
      argsJson: argsJson ?? this.argsJson,
      agentName: agentName is String? ? agentName : this.agentName,
      timeoutMs: timeoutMs ?? this.timeoutMs,
    );
  }
}
