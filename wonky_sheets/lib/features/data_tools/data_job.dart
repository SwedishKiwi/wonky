import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../commands/sheets_command.dart' show WriteDeclined;
import '../sheet_editor/sheet_editor_controller.dart';

/// Long data operations (07 §1.4 `DataJobRunner`): sort, remove
/// duplicates, split, trim, randomize over many rows.
///
/// A job over at least [threshold] rows shows a progress toast ("Sorting
/// 412,000 rows… 37 %", *Cancel*). When the job names its operation
/// ([run]'s `op`), the **compute phase** plans it cooperatively
/// (`SheetsMutationPlanner.steps`: about 12 ms of work per frame, progress
/// from the planner); *Cancel* stops it with nothing changed. The **write
/// phase** then applies the finished plan through the normal path
/// (`SheetEditorController.apply`: write gates, one undo step; the local
/// store writes it in chunks in the background) and can't be cancelled. If
/// the model changes while planning (a remote edit), planning starts over
/// (twice), then falls back to planning while applying. Only one job runs
/// per spreadsheet at a time; a second request waits ("Waiting for the
/// current operation to finish").
abstract final class DataJobs {
  /// Rows from which a job shows its toast.
  static const threshold = 20000;

  /// Work per frame while planning cooperatively.
  static const frameBudget = Duration(milliseconds: 12);

  static final Expando<Future<void>> _running = Expando('DataJobs');

  /// Whether a job of [ed] is running (tests).
  static bool isRunning(SheetEditorController ed) => _running[ed] != null;

  /// The progress of the running job of [ed] (tests, status bar).
  static ValueListenable<double?>? progressOf(SheetEditorController ed) =>
      _progress[ed];
  static final Expando<ValueNotifier<double?>> _progress = Expando(
    'DataJobs.progress',
  );

  /// Cancels the running job of [ed] while it is still planning (tests;
  /// the toast's *Cancel*).
  static void cancel(SheetEditorController ed) => _cancel[ed]?.call();
  static final Expando<void Function()> _cancel = Expando('DataJobs.cancel');

  /// Runs [work] over [rows] rows labelled [label] (e.g. "Sorting 412,000
  /// rows…"). With [op] — the operation [work] applies — the operation is
  /// planned first in cooperative steps with progress and *Cancel*;
  /// cancelling throws [WriteDeclined] (the command ends as cancelled).
  static Future<T> run<T>(
    SheetEditorController ed, {
    required int rows,
    required String label,
    required T Function() work,
    SheetsOperation? op,
  }) async {
    final toasts = ed.services.toasts;
    final previous = _running[ed];
    if (previous != null) {
      final id = toasts.show(ed.l10n.dataJobWaiting);
      await previous;
      toasts.hide(id);
    }
    if (rows < threshold) return work();
    final done = Completer<void>();
    _running[ed] = done.future;
    final progress = ValueNotifier<double?>(op == null ? null : 0);
    final cancellable = ValueNotifier<bool>(op != null);
    var cancelled = false;
    void cancel() {
      if (!cancellable.value) return;
      cancelled = true;
      cancellable.value = false;
    }

    _progress[ed] = progress;
    _cancel[ed] = cancel;
    final id = toasts.showProgress(
      label,
      progress: progress,
      cancelLabel: op == null ? null : ed.l10n.dataJobCancel,
      onCancel: op == null ? null : cancel,
      cancellable: cancellable,
    );
    try {
      // Let the toast paint before any synchronous work.
      await _nextFrame();
      if (op != null) {
        final plan = await _planInSteps(ed, op, progress, () => cancelled);
        if (cancelled) {
          toasts.show(ed.l10n.dataJobCancelled);
          throw const WriteDeclined();
        }
        // No await from here on: the plan matches the model as it is now.
        if (plan != null) SheetsMutationPlanner.offer(op, ed.model, plan);
      }
      cancellable.value = false;
      progress.value = op == null ? null : 1;
      return work();
    } finally {
      toasts.hide(id);
      _running[ed] = null;
      _progress[ed] = null;
      _cancel[ed] = null;
      done.complete();
      progress.dispose();
      cancellable.dispose();
    }
  }

  /// Plans [op] in frame-sized steps; null when cancelled or when the model
  /// kept changing (the caller then plans synchronously).
  static Future<MutationPlan?> _planInSteps(
    SheetEditorController ed,
    SheetsOperation op,
    ValueNotifier<double?> progress,
    bool Function() cancelled,
  ) async {
    var changed = false;
    void onChange(WorkbookChangeBatch _) => changed = true;
    ed.model.addListener(onChange);
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        changed = false;
        final it = const SheetsMutationPlanner()
            .steps(op, ed.model, ed.session.planContext())
            .iterator;
        MutationPlan? plan;
        var more = true;
        while (more) {
          final sw = Stopwatch()..start();
          while (sw.elapsed < frameBudget && (more = it.moveNext())) {
            final x = it.current;
            if (x is double) {
              progress.value = x;
            } else if (x is MutationPlan) {
              plan = x;
            }
          }
          if (!more) break;
          await _nextFrame();
          // Never resume the steps over a changed model.
          if (cancelled() || changed) break;
        }
        if (cancelled()) return null;
        if (!more && !changed) return plan;
        progress.value = 0;
      }
      return null;
    } finally {
      ed.model.removeListener(onChange);
    }
  }

  static Future<void> _nextFrame() async {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
  }
}
