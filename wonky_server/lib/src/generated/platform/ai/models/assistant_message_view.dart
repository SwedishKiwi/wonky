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

abstract class AssistantMessageView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AssistantMessageView._({
    required this.id,
    required this.role,
    required this.displayText,
    this.toolCallsJson,
    this.runId,
    this.stopReason,
    required this.createdAt,
  });

  factory AssistantMessageView({
    required int id,
    required String role,
    required String displayText,
    String? toolCallsJson,
    String? runId,
    String? stopReason,
    required DateTime createdAt,
  }) = _AssistantMessageViewImpl;

  factory AssistantMessageView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AssistantMessageView(
      id: jsonSerialization['id'] as int,
      role: jsonSerialization['role'] as String,
      displayText: jsonSerialization['displayText'] as String,
      toolCallsJson: jsonSerialization['toolCallsJson'] as String?,
      runId: jsonSerialization['runId'] as String?,
      stopReason: jsonSerialization['stopReason'] as String?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  int id;

  String role;

  String displayText;

  String? toolCallsJson;

  String? runId;

  String? stopReason;

  DateTime createdAt;

  /// Returns a shallow copy of this [AssistantMessageView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AssistantMessageView copyWith({
    int? id,
    String? role,
    String? displayText,
    String? toolCallsJson,
    String? runId,
    String? stopReason,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AssistantMessageView',
      'id': id,
      'role': role,
      'displayText': displayText,
      if (toolCallsJson != null) 'toolCallsJson': toolCallsJson,
      if (runId != null) 'runId': runId,
      if (stopReason != null) 'stopReason': stopReason,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AssistantMessageView',
      'id': id,
      'role': role,
      'displayText': displayText,
      if (toolCallsJson != null) 'toolCallsJson': toolCallsJson,
      if (runId != null) 'runId': runId,
      if (stopReason != null) 'stopReason': stopReason,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AssistantMessageViewImpl extends AssistantMessageView {
  _AssistantMessageViewImpl({
    required int id,
    required String role,
    required String displayText,
    String? toolCallsJson,
    String? runId,
    String? stopReason,
    required DateTime createdAt,
  }) : super._(
         id: id,
         role: role,
         displayText: displayText,
         toolCallsJson: toolCallsJson,
         runId: runId,
         stopReason: stopReason,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [AssistantMessageView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AssistantMessageView copyWith({
    int? id,
    String? role,
    String? displayText,
    Object? toolCallsJson = _Undefined,
    Object? runId = _Undefined,
    Object? stopReason = _Undefined,
    DateTime? createdAt,
  }) {
    return AssistantMessageView(
      id: id ?? this.id,
      role: role ?? this.role,
      displayText: displayText ?? this.displayText,
      toolCallsJson: toolCallsJson is String?
          ? toolCallsJson
          : this.toolCallsJson,
      runId: runId is String? ? runId : this.runId,
      stopReason: stopReason is String? ? stopReason : this.stopReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
