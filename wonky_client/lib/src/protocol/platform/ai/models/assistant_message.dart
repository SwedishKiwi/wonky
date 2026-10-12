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
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// One turn of an assistant thread. `contentJson` keeps the raw API content
/// blocks verbatim (thinking blocks included) for append-only replay.
abstract class AssistantMessage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AssistantMessage._({
    this.id,
    required this.threadId,
    required this.role,
    required this.displayText,
    this.toolCallsJson,
    bool? visible,
    bool? replay,
    this.runId,
    this.stopReason,
    required this.createdAt,
  }) : visible = visible ?? true,
       replay = replay ?? true;

  factory AssistantMessage({
    int? id,
    required int threadId,
    required String role,
    required String displayText,
    String? toolCallsJson,
    bool? visible,
    bool? replay,
    String? runId,
    String? stopReason,
    required DateTime createdAt,
  }) = _AssistantMessageImpl;

  factory AssistantMessage.fromJson(Map<String, dynamic> jsonSerialization) {
    return AssistantMessage(
      id: jsonSerialization['id'] as int?,
      threadId: jsonSerialization['threadId'] as int,
      role: jsonSerialization['role'] as String,
      displayText: jsonSerialization['displayText'] as String,
      toolCallsJson: jsonSerialization['toolCallsJson'] as String?,
      visible: jsonSerialization['visible'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['visible']),
      replay: jsonSerialization['replay'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['replay']),
      runId: jsonSerialization['runId'] as String?,
      stopReason: jsonSerialization['stopReason'] as String?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int threadId;

  /// user | assistant
  String role;

  /// Rendered text for the UI (user text / assistant Markdown).
  String displayText;

  /// JSON list of AssistantToolActivity summaries for the UI.
  String? toolCallsJson;

  /// Whether the turn is shown in the panel (tool-result turns are not).
  bool visible;

  /// Whether the turn is replayed to the model (refused turns are not).
  bool replay;

  String? runId;

  String? stopReason;

  DateTime createdAt;

  /// Returns a shallow copy of this [AssistantMessage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AssistantMessage copyWith({
    int? id,
    int? threadId,
    String? role,
    String? displayText,
    String? toolCallsJson,
    bool? visible,
    bool? replay,
    String? runId,
    String? stopReason,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AssistantMessage',
      if (id != null) 'id': id,
      'threadId': threadId,
      'role': role,
      'displayText': displayText,
      if (toolCallsJson != null) 'toolCallsJson': toolCallsJson,
      'visible': visible,
      'replay': replay,
      if (runId != null) 'runId': runId,
      if (stopReason != null) 'stopReason': stopReason,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AssistantMessage',
      if (id != null) 'id': id,
      'threadId': threadId,
      'role': role,
      'displayText': displayText,
      if (toolCallsJson != null) 'toolCallsJson': toolCallsJson,
      'visible': visible,
      'replay': replay,
      if (runId != null) 'runId': runId,
      if (stopReason != null) 'stopReason': stopReason,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AssistantMessageImpl extends AssistantMessage {
  _AssistantMessageImpl({
    int? id,
    required int threadId,
    required String role,
    required String displayText,
    String? toolCallsJson,
    bool? visible,
    bool? replay,
    String? runId,
    String? stopReason,
    required DateTime createdAt,
  }) : super._(
         id: id,
         threadId: threadId,
         role: role,
         displayText: displayText,
         toolCallsJson: toolCallsJson,
         visible: visible,
         replay: replay,
         runId: runId,
         stopReason: stopReason,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [AssistantMessage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AssistantMessage copyWith({
    Object? id = _Undefined,
    int? threadId,
    String? role,
    String? displayText,
    Object? toolCallsJson = _Undefined,
    bool? visible,
    bool? replay,
    Object? runId = _Undefined,
    Object? stopReason = _Undefined,
    DateTime? createdAt,
  }) {
    return AssistantMessage(
      id: id is int? ? id : this.id,
      threadId: threadId ?? this.threadId,
      role: role ?? this.role,
      displayText: displayText ?? this.displayText,
      toolCallsJson: toolCallsJson is String?
          ? toolCallsJson
          : this.toolCallsJson,
      visible: visible ?? this.visible,
      replay: replay ?? this.replay,
      runId: runId is String? ? runId : this.runId,
      stopReason: stopReason is String? ? stopReason : this.stopReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
