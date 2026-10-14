import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart';

import '../build/script_exports.dart';
import '../guest/guest_runtime.dart';
import '../host/limits.dart';
import '../host/script_host.dart';
import '../host/services.dart';
import '../host/workbook_access.dart';
import '../protocol/messages.dart';

/// The event object of a trigger invocation (09 §6.10).
sealed class ScriptEvent {
  const ScriptEvent();

  /// Event data for the guest (handles are created in [host]).
  Map<String, Object?> toWire(ScriptHost host);
}

/// `OpenEvent`.
final class OpenEventData extends ScriptEvent {
  /// Creates the event.
  const OpenEventData();

  @override
  Map<String, Object?> toWire(ScriptHost host) => {
    'kind': 'open',
    'user': host.userData(host.context.activeUser),
    'authMode': host.context.authorized ? 'full' : 'limited',
  };
}

/// `EditEvent`.
final class EditEventData extends ScriptEvent {
  /// Creates the event.
  const EditEventData({
    required this.sheetId,
    required this.range,
    this.value,
    this.oldValue,
    this.triggerUid,
    this.offline = false,
    this.coalesced = false,
  });

  /// Sheet of the edited cells.
  final String sheetId;

  /// Bounding box of the changed cells.
  final GridRect range;

  /// New value (single-cell edits).
  final Object? value;

  /// Previous value (single-cell edits).
  final Object? oldValue;

  /// Installable triggers only.
  final String? triggerUid;

  /// Edit was made offline.
  final bool offline;

  /// Several queued edits were merged into this one (installable triggers
  /// with more than 100 queued runs; [range] is their bounding box).
  final bool coalesced;

  @override
  Map<String, Object?> toWire(ScriptHost host) => {
    'kind': 'edit',
    'user': host.userData(host.context.activeUser),
    'range': host.createRangeHandle(sheetId, range),
    'value': value,
    'oldValue': oldValue,
    'triggerUid': triggerUid,
    'offline': offline,
    'coalesced': coalesced,
  };
}

/// `UiEvent`: a button of a script panel was clicked (09 §16.3).
final class UiEventData extends ScriptEvent {
  /// Creates the event.
  const UiEventData({
    required this.panelId,
    required this.values,
    required this.button,
  });

  /// The panel.
  final String panelId;

  /// Input values by component id.
  final Map<String, Object?> values;

  /// Caption of the clicked button.
  final String button;

  @override
  Map<String, Object?> toWire(ScriptHost host) => {
    'kind': 'ui',
    'user': host.userData(host.context.activeUser),
    'values': values,
    'panelId': panelId,
    'button': button,
  };
}

/// `SelectionChangeEvent`.
final class SelectionChangeEventData extends ScriptEvent {
  /// Creates the event.
  const SelectionChangeEventData({required this.sheetId, required this.range});

  /// Sheet of the selection.
  final String sheetId;

  /// Selected range.
  final GridRect range;

  @override
  Map<String, Object?> toWire(ScriptHost host) => {
    'kind': 'selectionChange',
    'user': host.userData(host.context.activeUser),
    'range': host.createRangeHandle(sheetId, range),
  };
}

/// `ChangeEvent`.
final class ChangeEventData extends ScriptEvent {
  /// Creates the event.
  const ChangeEventData(this.changeType);

  /// EDIT, INSERT_ROW, INSERT_COLUMN, REMOVE_ROW, REMOVE_COLUMN, INSERT_GRID,
  /// REMOVE_GRID, FORMAT or OTHER.
  final String changeType;

  @override
  Map<String, Object?> toWire(ScriptHost host) => {
    'kind': 'change',
    'user': host.userData(host.context.activeUser),
    'changeType': changeType,
  };
}

/// `TimeEvent`.
final class TimeEventData extends ScriptEvent {
  /// Creates the event.
  const TimeEventData({
    required this.triggerUid,
    required this.scheduledAt,
    required this.firedAt,
  });

  /// Trigger id.
  final String triggerUid;

  /// When the run was due.
  final DateTime scheduledAt;

  /// When it started.
  final DateTime firedAt;

  @override
  Map<String, Object?> toWire(ScriptHost host) => {
    'kind': 'time',
    'user': host.userData(host.context.activeUser),
    'triggerUid': triggerUid,
    'scheduledAt': scheduledAt,
    'firedAt': firedAt,
  };
}

/// Runs guest requests in some sandbox (inline, isolate, web worker).
abstract interface class ScriptRunner {
  /// Runs [request] in a guest whose calls [host] answers.
  Future<GuestOutcome> runGuest(GuestRequest request, ScriptHost host);

  /// Releases guests.
  Future<void> close();
}

/// The outcome of an execution, ready for the executions log (09 §13.1).
final class ExecutionResult {
  /// Creates a result.
  const ExecutionResult({
    required this.executionId,
    required this.functionName,
    required this.kind,
    required this.status,
    this.result,
    this.error,
    this.logs = const [],
    required this.startedAt,
    required this.duration,
    required this.counters,
    this.instructions = 0,
    this.bridgeCalls = 0,
    this.applied = const [],
  });

  /// Execution id.
  final String executionId;

  /// Function that ran.
  final String functionName;

  /// Kind of execution.
  final ExecutionKind kind;

  /// Final status.
  final ExecutionStatus status;

  /// Return value.
  final Object? result;

  /// Failure with mapped stack frames.
  final ScriptFailure? error;

  /// Log lines.
  final List<LogEntry> logs;

  /// Start time.
  final DateTime startedAt;

  /// Wall time (including UI waits, see [ExecutionCounters.uiWait]).
  final Duration duration;

  /// Host counters.
  final ExecutionCounters counters;

  /// Approximate interpreter instructions.
  final int instructions;

  /// Host calls made by the guest.
  final int bridgeCalls;

  /// Plans applied to the workbook, in order; the caller persists them.
  final List<AppliedPlan> applied;

  /// Whether the function completed.
  bool get ok => status == ExecutionStatus.completed;

  /// `ScriptExecution.logs`: JSON lines `{t, level, msg}`.
  String get logsJsonLines =>
      logs.map((l) => jsonEncode(l.toJson())).join('\n');
}

/// Runs [functionName] of [program] with [runner], answering calls with
/// [host]; maps stack frames to source lines and collects the result.
Future<ExecutionResult> runScript({
  required ScriptRunner runner,
  required ScriptHost host,
  required ScriptProgram program,
  required String functionName,
  List<Object?> args = const [],
  ScriptEvent? event,
  String? executionId,
  Clock? clock,
}) async {
  final c = clock ?? const Clock();
  final id = executionId ?? const Uuid().v7();
  final started = c.now();
  final watch = Stopwatch()..start();
  final applyStart = host.workbook.applied.length;

  ExecutionResult finish(GuestOutcome outcome) {
    final error = outcome.error;
    return ExecutionResult(
      executionId: id,
      functionName: functionName,
      kind: host.context.kind,
      status: outcome.status,
      result: outcome.result,
      error: error == null ? null : _mapFrames(error, program.exports),
      logs: List.of(host.logs),
      startedAt: started,
      duration: watch.elapsed,
      counters: host.counters,
      instructions: outcome.instructions,
      bridgeCalls: outcome.bridgeCalls,
      applied: host.workbook.applied.sublist(applyStart),
    );
  }

  final fn = program.exports.function(functionName);
  if (fn == null) {
    return finish(
      GuestOutcome(
        status: ExecutionStatus.failed,
        error: ScriptFailure(
          type: 'ScriptException',
          code: 'not_found',
          message:
              'There is no function named "$functionName" in the last '
              'successful build.',
        ),
      ),
    );
  }
  final limits = host.limits;
  final request = GuestRequest(
    buildHash: program.buildHash,
    bytecode: program.bytecode,
    function: functionName,
    args: args,
    event: event?.toWire(host),
    timeoutMs: limits.timeout.inMilliseconds,
    maxBridgedValues: limits.maxBridgedValues,
    maxListLength: limits.maxListLength,
    maxSleepMs: limits.maxSleepMs,
    writeBatchCells: limits.writeBatchCells,
  );
  final GuestOutcome outcome;
  try {
    outcome = await runner.runGuest(request, host);
  } finally {
    host.releaseLocks();
  }
  if (outcome.error != null && outcome.status != ExecutionStatus.completed) {
    host.log(
      ScriptLogLevel.error,
      '${outcome.error!.type}: ${outcome.error!.message}',
    );
  }
  return finish(outcome);
}

ScriptFailure _mapFrames(ScriptFailure f, ScriptExports exports) {
  final frames = <ScriptStackFrame>[];
  for (final fr in f.frames) {
    final lib = fr.library;
    final file = lib?.substring(lib.lastIndexOf('/') + 1);
    final offset = fr.offset;
    if (file != null && offset != null) {
      final pos = exports.position(file, offset);
      if (pos != null) {
        frames.add(fr.withPosition(file, pos.$1, pos.$2));
        continue;
      }
    }
    // Function-level fallback from the exports metadata.
    final info = exports.function(fr.function);
    if (info != null) {
      frames.add(fr.withPosition(info.file, info.line, 1));
    } else {
      frames.add(fr);
    }
  }
  return f.withFrames(frames);
}
