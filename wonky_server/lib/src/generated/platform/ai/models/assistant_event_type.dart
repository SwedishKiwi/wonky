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

/// Kinds of [AssistantEvent]s streamed by `assistant.chat`.
enum AssistantEventType implements _is.SerializableModel {
  /// First event: the thread (created when new) and the run id.
  started,
  textDelta,

  /// A progress note between tool calls (thinking display "updates").
  progress,
  toolStarted,
  toolFinished,

  /// The destructive guard asks the user (assistant.confirm).
  confirmationRequired,
  usage,

  /// The answer was cut off (max_tokens): the panel offers "Continue".
  maxTokens,
  refusal,
  error,

  /// Last event of a run.
  done;

  static AssistantEventType fromJson(String name) {
    switch (name) {
      case 'started':
        return AssistantEventType.started;
      case 'textDelta':
        return AssistantEventType.textDelta;
      case 'progress':
        return AssistantEventType.progress;
      case 'toolStarted':
        return AssistantEventType.toolStarted;
      case 'toolFinished':
        return AssistantEventType.toolFinished;
      case 'confirmationRequired':
        return AssistantEventType.confirmationRequired;
      case 'usage':
        return AssistantEventType.usage;
      case 'maxTokens':
        return AssistantEventType.maxTokens;
      case 'refusal':
        return AssistantEventType.refusal;
      case 'error':
        return AssistantEventType.error;
      case 'done':
        return AssistantEventType.done;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "AssistantEventType"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
