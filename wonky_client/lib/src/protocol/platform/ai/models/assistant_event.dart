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
import '../../../platform/ai/models/assistant_event_type.dart' as _i3enc09o;

/// An event of an assistant run (not a table; streamed to the client).
abstract class AssistantEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AssistantEvent._({
    required this.type,
    this.threadId,
    this.runId,
    this.text,
    this.toolUseId,
    this.toolName,
    this.toolSummary,
    this.toolError,
    this.changeId,
    this.rangeStart,
    this.rangeLength,
    this.revision,
    this.confirmationId,
    this.error,
    this.errorCode,
    this.messageId,
    this.inputTokens,
    this.outputTokens,
    this.cacheReadTokens,
  });

  factory AssistantEvent({
    required _i3enc09o.AssistantEventType type,
    int? threadId,
    String? runId,
    String? text,
    String? toolUseId,
    String? toolName,
    String? toolSummary,
    bool? toolError,
    String? changeId,
    int? rangeStart,
    int? rangeLength,
    int? revision,
    String? confirmationId,
    String? error,
    String? errorCode,
    int? messageId,
    int? inputTokens,
    int? outputTokens,
    int? cacheReadTokens,
  }) = _AssistantEventImpl;

  factory AssistantEvent.fromJson(Map<String, dynamic> jsonSerialization) {
    return AssistantEvent(
      type: _i3enc09o.AssistantEventType.fromJson(
        (jsonSerialization['type'] as String),
      ),
      threadId: jsonSerialization['threadId'] as int?,
      runId: jsonSerialization['runId'] as String?,
      text: jsonSerialization['text'] as String?,
      toolUseId: jsonSerialization['toolUseId'] as String?,
      toolName: jsonSerialization['toolName'] as String?,
      toolSummary: jsonSerialization['toolSummary'] as String?,
      toolError: jsonSerialization['toolError'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['toolError']),
      changeId: jsonSerialization['changeId'] as String?,
      rangeStart: jsonSerialization['rangeStart'] as int?,
      rangeLength: jsonSerialization['rangeLength'] as int?,
      revision: jsonSerialization['revision'] as int?,
      confirmationId: jsonSerialization['confirmationId'] as String?,
      error: jsonSerialization['error'] as String?,
      errorCode: jsonSerialization['errorCode'] as String?,
      messageId: jsonSerialization['messageId'] as int?,
      inputTokens: jsonSerialization['inputTokens'] as int?,
      outputTokens: jsonSerialization['outputTokens'] as int?,
      cacheReadTokens: jsonSerialization['cacheReadTokens'] as int?,
    );
  }

  _i3enc09o.AssistantEventType type;

  int? threadId;

  String? runId;

  /// textDelta / progress text, or the final display text on done.
  String? text;

  String? toolUseId;

  String? toolName;

  /// Human summary ("Edited 3 paragraphs").
  String? toolSummary;

  /// toolFinished: whether the call failed.
  bool? toolError;

  /// change_id of a mutating tool (changes.revert fallback for Undo).
  String? changeId;

  /// Applied range in the document after the change (Show).
  int? rangeStart;

  int? rangeLength;

  int? revision;

  String? confirmationId;

  String? error;

  String? errorCode;

  int? messageId;

  int? inputTokens;

  int? outputTokens;

  int? cacheReadTokens;

  /// Returns a shallow copy of this [AssistantEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AssistantEvent copyWith({
    _i3enc09o.AssistantEventType? type,
    int? threadId,
    String? runId,
    String? text,
    String? toolUseId,
    String? toolName,
    String? toolSummary,
    bool? toolError,
    String? changeId,
    int? rangeStart,
    int? rangeLength,
    int? revision,
    String? confirmationId,
    String? error,
    String? errorCode,
    int? messageId,
    int? inputTokens,
    int? outputTokens,
    int? cacheReadTokens,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AssistantEvent',
      'type': type.toJson(),
      if (threadId != null) 'threadId': threadId,
      if (runId != null) 'runId': runId,
      if (text != null) 'text': text,
      if (toolUseId != null) 'toolUseId': toolUseId,
      if (toolName != null) 'toolName': toolName,
      if (toolSummary != null) 'toolSummary': toolSummary,
      if (toolError != null) 'toolError': toolError,
      if (changeId != null) 'changeId': changeId,
      if (rangeStart != null) 'rangeStart': rangeStart,
      if (rangeLength != null) 'rangeLength': rangeLength,
      if (revision != null) 'revision': revision,
      if (confirmationId != null) 'confirmationId': confirmationId,
      if (error != null) 'error': error,
      if (errorCode != null) 'errorCode': errorCode,
      if (messageId != null) 'messageId': messageId,
      if (inputTokens != null) 'inputTokens': inputTokens,
      if (outputTokens != null) 'outputTokens': outputTokens,
      if (cacheReadTokens != null) 'cacheReadTokens': cacheReadTokens,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AssistantEvent',
      'type': type.toJson(),
      if (threadId != null) 'threadId': threadId,
      if (runId != null) 'runId': runId,
      if (text != null) 'text': text,
      if (toolUseId != null) 'toolUseId': toolUseId,
      if (toolName != null) 'toolName': toolName,
      if (toolSummary != null) 'toolSummary': toolSummary,
      if (toolError != null) 'toolError': toolError,
      if (changeId != null) 'changeId': changeId,
      if (rangeStart != null) 'rangeStart': rangeStart,
      if (rangeLength != null) 'rangeLength': rangeLength,
      if (revision != null) 'revision': revision,
      if (confirmationId != null) 'confirmationId': confirmationId,
      if (error != null) 'error': error,
      if (errorCode != null) 'errorCode': errorCode,
      if (messageId != null) 'messageId': messageId,
      if (inputTokens != null) 'inputTokens': inputTokens,
      if (outputTokens != null) 'outputTokens': outputTokens,
      if (cacheReadTokens != null) 'cacheReadTokens': cacheReadTokens,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AssistantEventImpl extends AssistantEvent {
  _AssistantEventImpl({
    required _i3enc09o.AssistantEventType type,
    int? threadId,
    String? runId,
    String? text,
    String? toolUseId,
    String? toolName,
    String? toolSummary,
    bool? toolError,
    String? changeId,
    int? rangeStart,
    int? rangeLength,
    int? revision,
    String? confirmationId,
    String? error,
    String? errorCode,
    int? messageId,
    int? inputTokens,
    int? outputTokens,
    int? cacheReadTokens,
  }) : super._(
         type: type,
         threadId: threadId,
         runId: runId,
         text: text,
         toolUseId: toolUseId,
         toolName: toolName,
         toolSummary: toolSummary,
         toolError: toolError,
         changeId: changeId,
         rangeStart: rangeStart,
         rangeLength: rangeLength,
         revision: revision,
         confirmationId: confirmationId,
         error: error,
         errorCode: errorCode,
         messageId: messageId,
         inputTokens: inputTokens,
         outputTokens: outputTokens,
         cacheReadTokens: cacheReadTokens,
       );

  /// Returns a shallow copy of this [AssistantEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AssistantEvent copyWith({
    _i3enc09o.AssistantEventType? type,
    Object? threadId = _Undefined,
    Object? runId = _Undefined,
    Object? text = _Undefined,
    Object? toolUseId = _Undefined,
    Object? toolName = _Undefined,
    Object? toolSummary = _Undefined,
    Object? toolError = _Undefined,
    Object? changeId = _Undefined,
    Object? rangeStart = _Undefined,
    Object? rangeLength = _Undefined,
    Object? revision = _Undefined,
    Object? confirmationId = _Undefined,
    Object? error = _Undefined,
    Object? errorCode = _Undefined,
    Object? messageId = _Undefined,
    Object? inputTokens = _Undefined,
    Object? outputTokens = _Undefined,
    Object? cacheReadTokens = _Undefined,
  }) {
    return AssistantEvent(
      type: type ?? this.type,
      threadId: threadId is int? ? threadId : this.threadId,
      runId: runId is String? ? runId : this.runId,
      text: text is String? ? text : this.text,
      toolUseId: toolUseId is String? ? toolUseId : this.toolUseId,
      toolName: toolName is String? ? toolName : this.toolName,
      toolSummary: toolSummary is String? ? toolSummary : this.toolSummary,
      toolError: toolError is bool? ? toolError : this.toolError,
      changeId: changeId is String? ? changeId : this.changeId,
      rangeStart: rangeStart is int? ? rangeStart : this.rangeStart,
      rangeLength: rangeLength is int? ? rangeLength : this.rangeLength,
      revision: revision is int? ? revision : this.revision,
      confirmationId: confirmationId is String?
          ? confirmationId
          : this.confirmationId,
      error: error is String? ? error : this.error,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
      messageId: messageId is int? ? messageId : this.messageId,
      inputTokens: inputTokens is int? ? inputTokens : this.inputTokens,
      outputTokens: outputTokens is int? ? outputTokens : this.outputTokens,
      cacheReadTokens: cacheReadTokens is int?
          ? cacheReadTokens
          : this.cacheReadTokens,
    );
  }
}
