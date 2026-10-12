import 'package:serverpod/serverpod.dart';

import '../../sheets/changelog/change_log_consumer.dart';
import '../../sheets/spaces/space_service.dart';
import '../../sheets/sync/server_sheets_writer.dart';
import '../../write/ot/document_service.dart';
import '../../write/themes/theme_service.dart';
import '../../write/versions/write_history_service.dart';
import '../drive/drive_service.dart';
import '../files/file_service.dart';
import '../notifications/notification_service.dart';
import '../sharing/sharing_service.dart';
import '../versions/version_service.dart';

/// Scheduled jobs (specs/13 §3). Each job is idempotent; schedules are
/// registered at server start (`registerMaintenanceJobs`).
class MaintenanceFutureCall extends FutureCall {
  Future<void> _run(
    Session session,
    String name,
    Future<int> Function() job,
  ) async {
    try {
      final count = await job();
      if (count > 0) session.log('$name: $count');
    } on Exception catch (e, st) {
      session.log('$name failed: $e', level: LogLevel.error, stackTrace: st);
    }
  }

  /// Every minute: version capture policy.
  Future<void> captureVersions(Session session) => _run(
    session,
    'versions.capture',
    () => VersionService.captureDue(session),
  );

  /// Every 15 minutes: notification email digests.
  Future<void> sendDigests(Session session) => _run(
    session,
    'notifications.digest',
    () => NotificationService.sendDigests(session),
  );

  /// Hourly: expired files (imports, exports) and abandoned uploads.
  Future<void> cleanupFiles(Session session) => _run(
    session,
    'files.cleanup',
    () => FileService.cleanupExpired(session),
  );

  /// Daily: trash purge, version thinning, op-log and change-log pruning,
  /// active-set eviction, expired grants, server change records, deleted
  /// themes and the diff cache.
  Future<void> daily(Session session) async {
    await _run(
      session,
      'drive.purgeTrash',
      () => DriveService.purgeExpiredTrash(session),
    );
    await _run(session, 'versions.thin', () => VersionService.thin(session));
    await _run(
      session,
      'write.pruneOps',
      () => DocumentService.pruneOps(session),
    );
    await _run(
      session,
      'sheets.pruneChangeLog',
      () => ChangeLogConsumer.pruneOld(session),
    );
    await _run(
      session,
      'sheets.evictSpaces',
      () => SpaceService.evictInactive(session),
    );
    await _run(
      session,
      'sharing.expiredGrants',
      () => SharingService.removeExpiredGrants(session),
    );
    await _run(
      session,
      'sheets.purgeServerChanges',
      () => ServerSheetsWriter.purgeExpired(session),
    );
    await _run(
      session,
      'write.purgeDeletedThemes',
      () => ThemeService.purgeDeleted(session),
    );
    await _run(
      session,
      'write.purgeDiffCache',
      () => WriteHistoryService.purgeDiffCache(session),
    );
  }
}
