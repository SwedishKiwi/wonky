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

/// Final status of a script execution (Sheets 09 §13.1).
enum ScriptExecutionStatus implements _isc.SerializableModel {
  queued,
  running,
  completed,
  failed,
  timedOut,
  cancelled,
  quotaExceeded,
  skipped;

  static ScriptExecutionStatus fromJson(String name) {
    switch (name) {
      case 'queued':
        return ScriptExecutionStatus.queued;
      case 'running':
        return ScriptExecutionStatus.running;
      case 'completed':
        return ScriptExecutionStatus.completed;
      case 'failed':
        return ScriptExecutionStatus.failed;
      case 'timedOut':
        return ScriptExecutionStatus.timedOut;
      case 'cancelled':
        return ScriptExecutionStatus.cancelled;
      case 'quotaExceeded':
        return ScriptExecutionStatus.quotaExceeded;
      case 'skipped':
        return ScriptExecutionStatus.skipped;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "ScriptExecutionStatus"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
