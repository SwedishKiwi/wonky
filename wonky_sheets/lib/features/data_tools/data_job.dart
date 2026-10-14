import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../sheet_editor/sheet_editor_controller.dart';

/// Long data operations (07 §1.4 `DataJobRunner`): sort, remove
/// duplicates, split, trim, randomize over many rows. The planner runs them
/// synchronously, so a job over at least [threshold] rows first shows a
/// progress toast ("Sorting 412,000 rows…") and lets it paint, then runs,
/// then hides it. Only one job runs per spreadsheet at a time; a second
/// request waits for the first ("Waiting for the current operation to
/// finish").
abstract final class DataJobs {
  /// Rows from which a job shows its toast.
  static const threshold = 20000;

  static final Expando<Future<void>> _running = Expando('DataJobs');

  /// Whether a job of [ed] is running (tests).
  static bool isRunning(SheetEditorController ed) => _running[ed] != null;

  /// Runs [work] over [rows] rows labelled [label] (e.g. "Sorting 412,000
  /// rows…").
  static Future<T> run<T>(
    SheetEditorController ed, {
    required int rows,
    required String label,
    required T Function() work,
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
    final id = toasts.show(label, duration: const Duration(minutes: 10));
    try {
      // Let the toast paint before the synchronous work blocks the UI.
      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 16));
      return work();
    } finally {
      toasts.hide(id);
      _running[ed] = null;
      done.complete();
    }
  }
}
