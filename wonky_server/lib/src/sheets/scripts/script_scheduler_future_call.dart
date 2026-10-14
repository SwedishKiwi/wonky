import 'package:serverpod/serverpod.dart';

import 'script_jobs.dart';
import 'script_service.dart';
import 'script_triggers.dart';

/// Scheduled script jobs (Sheets 09 §8.7.3, §13.1): the time-driven trigger
/// tick (every minute) and the daily executions pruning.
class ScriptSchedulerFutureCall extends FutureCall {
  /// Every minute: runs due time-driven triggers.
  Future<void> tick(Session session) async {
    try {
      final runs = await ScriptTriggerService.tick(session);
      if (runs > 0) session.log('scripts.tick: $runs');
    } on Exception catch (e, st) {
      session.log(
        'scripts.tick failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
    }
  }

  /// Daily: executions older than 30 days or beyond 10,000 per spreadsheet.
  Future<void> prune(Session session) async {
    try {
      final n = await ScriptService.pruneExecutions(session);
      final jobs = await ScriptJobQueue.prune(session);
      if (n + jobs > 0) session.log('scripts.prune: $n executions, $jobs jobs');
    } on Exception catch (e, st) {
      session.log(
        'scripts.prune failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
    }
  }
}
