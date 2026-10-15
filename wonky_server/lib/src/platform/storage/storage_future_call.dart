import 'package:serverpod/serverpod.dart';

import 'content_sizes.dart';
import 'storage_maintenance.dart';

/// Storage jobs (Drive 03 §4.3, §9): the backfill scheduled at server
/// start, the nightly reconcile and trailing size estimates of spaces.
class StorageFutureCall extends FutureCall {
  /// Backfill of users without reconciled counters (idempotent,
  /// resumable; serialized across instances).
  Future<void> backfill(Session session) async {
    try {
      final n = await StorageMaintenance.backfillPending(session);
      if (n > 0) session.log('storage.backfill: $n users');
    } on Exception catch (e, st) {
      session.log(
        'storage.backfill failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
    }
  }

  /// Nightly: recomputes every user's counters from the sources.
  Future<void> reconcile(Session session) async {
    try {
      final n = await StorageMaintenance.reconcileAll(session);
      if (n > 0) session.log('storage.reconcile: $n users with drift');
    } on Exception catch (e, st) {
      session.log(
        'storage.reconcile failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
    }
  }

  /// The trailing size estimate of a space item (Drive 03 §2 cadence).
  Future<void> refreshItemSize(Session session, int itemId) =>
      ContentSizes.refreshById(session, itemId);
}
