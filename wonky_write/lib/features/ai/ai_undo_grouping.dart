import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_write_core/wonky_write_core.dart' show WonkyOt;

import '../document/write_undo.dart';

/// Puts the ops of an AI assistant run, executed on the server on behalf
/// of this app session (`RemoteOp.onBehalfOfSessionId`), on the user's own
/// `write.content` undo stack as **one** step per run (`groupId`),
/// labelled "AI: …" (Write 09 §5.2, suite 08 §3.4).
///
/// Each op's inverse is computed against the local document before the
/// op. While the run's step is the top of the stack, later ops of the run
/// are composed into it (like typing coalescing); the other steps are
/// rebased over the op as for any remote change.
class AiUndoGrouping {
  AiUndoGrouping({
    required this.undo,
    required this.stack,
    required this.nextId,
  });

  final UndoService undo;
  final UndoStackKey stack;
  final String Function() nextId;

  /// Default label until the run finishes.
  static const defaultLabel = 'AI edit';

  /// groupId → undo step id.
  final Map<String, String> _steps = {};

  /// Whether a remote op of [groupId] made for [onBehalfOf] belongs on this
  /// session's ([sessionId]) stack.
  static bool isOwnRun({
    required String? onBehalfOf,
    required String? groupId,
    required String? sessionId,
  }) =>
      onBehalfOf != null &&
      groupId != null &&
      sessionId != null &&
      onBehalfOf == sessionId;

  /// Records [change] (already applied; [before] is the local document
  /// before it) as part of run [groupId].
  void record(Delta change, Delta before, String groupId) {
    final inverse = change.invert(before);
    final steps = undo.undoStepsOf(stack);
    final top = steps.isEmpty ? null : steps.last;
    final stepId = _steps[groupId];
    if (top != null && top.id == stepId && !undo.isApplying) {
      // Rebase every other step over the op, then fold the op into the
      // run's step: undo runs the newest inverse first.
      final rebased = rebaseWriteStacks(
        steps.sublist(0, steps.length - 1),
        undo.redoStepsOf(stack),
        change,
      );
      if (rebased != null) undo.applyRemote(stack, rebased);
      final current = undo.undoStepsOf(stack).last;
      final old = current.entries.whereType<WriteContentUndoEntry>().toList();
      final merged = WriteContentUndoEntry(
        change: old.isEmpty
            ? inverse
            : WonkyOt.compose(inverse, old.first.change),
        select: old.isEmpty ? null : old.first.select,
      );
      undo.replaceLast(
        current.copyWith(
          entries: [
            merged,
            ...current.entries.where((e) => e is! WriteContentUndoEntry),
          ],
        ),
        stack: stack,
      );
      return;
    }
    final rebased = rebaseWriteStacks(
      undo.undoStepsOf(stack),
      undo.redoStepsOf(stack),
      change,
    );
    if (rebased != null) undo.applyRemote(stack, rebased);
    final id = nextId();
    _steps[groupId] = id;
    undo.push(
      UndoStep(
        id: id,
        label: defaultLabel,
        entries: [WriteContentUndoEntry(change: inverse)],
        source: InvocationSource.ai,
      ),
      stack: stack,
    );
  }

  /// Whether run [groupId] has a step on the stack.
  bool hasRun(String groupId) {
    final id = _steps[groupId];
    return id != null && undo.undoStepsOf(stack).any((s) => s.id == id);
  }

  /// Relabels the run's step ("AI: Improve the intro") while it is on top.
  void relabel(String groupId, String summary) {
    final id = _steps[groupId];
    final steps = undo.undoStepsOf(stack);
    if (id == null || steps.isEmpty || steps.last.id != id) return;
    final label = 'AI: ${summary.trim().isEmpty ? 'Edit' : summary.trim()}';
    if (steps.last.label == label) return;
    undo.replaceLast(steps.last.copyWith(label: label), stack: stack);
  }

  /// Undoes run [groupId] when its step is the latest one; false otherwise.
  Future<bool> undoRun(String groupId) async {
    final id = _steps[groupId];
    final steps = undo.undoStepsOf(stack);
    if (id == null || steps.isEmpty || steps.last.id != id) return false;
    await undo.undoTo(id);
    return true;
  }
}
