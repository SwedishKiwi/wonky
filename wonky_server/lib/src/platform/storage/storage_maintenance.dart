import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/files.dart' show formatStorageBytes;

import '../common/models.dart';
import '../common/time.dart';
import '../notifications/notification_service.dart';
import 'content_sizes.dart';
import 'storage_counters.dart';
import 'storage_events.dart';

/// A counter that the reconcile found off (Drive 03 §4.3).
class StorageDrift {
  const StorageDrift(this.userId, this.field, this.before, this.after);

  final int userId;
  final String field;
  final int before;
  final int after;

  @override
  String toString() =>
      'storage.drift {userId: $userId, field: $field, '
      'before: $before, after: $after}';
}

/// The storage backfill for existing users (Drive 03 §9) and the nightly
/// reconcile (§4.3).
///
/// - **Backfill** (`StorageFutureCall.backfill`, scheduled at every server
///   start): every user without a reconciled `user_storage` row gets the
///   sizes of their items recomputed (documents from their content,
///   spaces with the estimators, `attachmentBytes` from their ready
///   images), then a reconcile that sets `reconciledAt`. Per-user commits
///   make it resumable; recomputing from the sources makes it idempotent.
///   Users over the quota afterwards get one `storage` notification.
/// - **Reconcile** (nightly): expired reservations are deleted, the
///   [nightlyKinds] (spreadsheets) are re-estimated, then every user's
///   counters are recomputed from `drive_item` and the open reservations;
///   differences above 1 % or 64 KB are logged as `storage.drift`.
///   Re-estimating spreadsheets nightly keeps their sizes on the current
///   estimator (a changed estimator corrects every user by the next
///   night, Drive 03 §11) and catches missed trailing refreshes.
abstract final class StorageMaintenance {
  /// Users per batch of the backfill / reconcile scans.
  static const userBatch = 200;

  /// Items per batch of the backfill's size recompute.
  static const itemBatch = 100;

  /// Kinds whose sizes the nightly reconcile re-estimates (the backfill
  /// re-estimates documents, spreadsheets and presentations).
  static Set<DriveItemKind> nightlyKinds = {DriveItemKind.spreadsheet};

  static const _estimatedKinds = {
    DriveItemKind.document,
    DriveItemKind.spreadsheet,
    DriveItemKind.presentation,
  };

  /// Drift worth logging: more than 1 % or 64 KB.
  static bool significant(int before, int after) {
    final diff = (before - after).abs();
    if (diff == 0) return false;
    if (diff > 64 * 1024) return true;
    final base = after.abs() > before.abs() ? after.abs() : before.abs();
    return diff * 100 > base;
  }

  // ------------------------------------------------------------ backfill

  /// Users without a reconciled row, by id.
  static Future<List<int>> pendingUsers(
    Session session, {
    int limit = userBatch,
    int afterId = 0,
  }) async {
    final rows = await session.db.unsafeQuery(
      r'''
      SELECT p.id FROM user_profile p
      LEFT JOIN user_storage s ON s."userId" = p.id
      WHERE (s.id IS NULL OR s."reconciledAt" IS NULL) AND p.id > @after
      ORDER BY p.id LIMIT @limit
      ''',
      parameters: QueryParameters.named({'after': afterId, 'limit': limit}),
    );
    return [for (final r in rows) r[0] as int];
  }

  /// Backfills every pending user, unless another instance runs the
  /// backfill (cluster advisory lock). Returns the number of users.
  static Future<int> backfillPending(Session session) =>
      _exclusive(session, 'wonky.storageBackfill', () async {
        var count = 0;
        var after = 0;
        while (true) {
          final users = await pendingUsers(session, afterId: after);
          if (users.isEmpty) break;
          for (final u in users) {
            await backfillUser(session, u);
            count++;
          }
          after = users.last;
        }
        return count;
      });

  /// Recomputes the item sizes of [userId] from their content, then
  /// reconciles the user (sets `reconciledAt`). Idempotent.
  static Future<void> backfillUser(Session session, int userId) async {
    final row = await StorageCounters.read(session, userId);
    final wasPending = row == null || row.reconciledAt == null;
    await recomputeItemSizes(session, userId);
    await reconcileUser(session, userId);
    if (wasPending) await _noticeIfOver(session, userId);
  }

  /// Recomputes `sizeBytes` of the owned items of [kinds] (default:
  /// documents, spreadsheets and presentations) and, with [attachments],
  /// `attachmentBytes` of all owned items (raw writes: the reconcile that
  /// follows recounts the counters).
  static Future<void> recomputeItemSizes(
    Session session,
    int userId, {
    Set<DriveItemKind> kinds = _estimatedKinds,
    bool attachments = true,
  }) async {
    if (kinds.isNotEmpty) await _recomputeContentSizes(session, userId, kinds);
    if (!attachments) return;
    await session.db.unsafeExecute(
      r'''
      UPDATE drive_item d SET "attachmentBytes" = x.n
      FROM (
        SELECT i.id, coalesce(sum(f."sizeBytes"), 0)::bigint AS n
        FROM drive_item i
        LEFT JOIN stored_file f ON f."itemId" = i.id
          AND f.kind = 'image' AND f.status = 'ready'
        WHERE i."ownerId" = @u
        GROUP BY i.id
      ) x
      WHERE d.id = x.id AND d."attachmentBytes" <> x.n
      ''',
      parameters: QueryParameters.named({'u': userId}),
    );
  }

  static Future<void> _recomputeContentSizes(
    Session session,
    int userId,
    Set<DriveItemKind> kinds,
  ) async {
    var after = 0;
    while (true) {
      final items = await DriveItem.db.find(
        session,
        where: (t) =>
            t.ownerId.equals(userId) & (t.id > after) & t.kind.inSet(kinds),
        orderBy: (t) => t.id,
        limit: itemBatch,
      );
      if (items.isEmpty) break;
      for (final item in items) {
        int? size;
        try {
          size = await ContentSizes.estimate(session, item);
        } on Exception catch (e) {
          session.log(
            'storage: size of item ${item.id} failed: $e',
            level: LogLevel.warning,
          );
        }
        if (size == null || size == item.sizeBytes) continue;
        await session.db.unsafeExecute(
          'UPDATE drive_item SET "sizeBytes" = @n WHERE id = @id',
          parameters: QueryParameters.named({'n': size, 'id': item.id}),
        );
      }
      after = items.last.id!;
    }
  }

  static Future<void> _noticeIfOver(Session session, int userId) async {
    final row = await StorageCounters.read(session, userId);
    if (row == null) return;
    final quota = StorageCounters.quotaOf(row);
    if (row.usedBytes <= quota) return;
    final already = await UserNotification.db.count(
      session,
      where: (t) =>
          t.userId.equals(userId) & t.kind.equals(NotificationKind.storage),
    );
    if (already > 0) return;
    await NotificationService.notify(
      session,
      userId: userId,
      kind: NotificationKind.storage,
      payload: {
        'reason': 'overQuotaAfterBackfill',
        'message': overQuotaMessage(usedBytes: row.usedBytes, quota: quota),
        'usedBytes': row.usedBytes,
        'quotaBytes': quota,
        'link': '/drive/storage',
      },
    );
  }

  /// The text of the over-quota notice (Drive 03 §9.3).
  static String overQuotaMessage({required int usedBytes, required int quota}) {
    const mb = 1024 * 1024;
    final quotaText = quota % mb == 0
        ? '${quota ~/ mb} MB'
        : formatStorageBytes(quota);
    return 'Wonky Work now includes $quotaText of storage per person. '
        "You're using ${formatStorageBytes(usedBytes)} — you can keep "
        'editing, but free up space to upload or copy files again.';
  }

  // ----------------------------------------------------------- reconcile

  /// Recomputes every counter of [userId] from the sources and sets
  /// `reconciledAt`; returns the drifts that were corrected (logged when
  /// [significant]).
  static Future<List<StorageDrift>> reconcileUser(
    Session session,
    int userId,
  ) async {
    final drifts = <StorageDrift>[];
    await session.db.transaction((tx) async {
      await StorageCounters.ensureRow(session, userId, transaction: tx);
      final row = await StorageCounters.read(
        session,
        userId,
        transaction: tx,
        lock: true,
      );
      await session.db.unsafeExecute(
        r'''
        DELETE FROM storage_reservation
        WHERE "userId" = @u AND "expiresAt" <= @now
        ''',
        parameters: QueryParameters.named({'u': userId, 'now': nowUtc()}),
        transaction: tx,
      );
      final items = await StorageCounters.itemTotals(
        session,
        userId,
        transaction: tx,
      );
      final totals = StorageTotals(
        documentsBytes: items.documentsBytes,
        spreadsheetsBytes: items.spreadsheetsBytes,
        presentationsBytes: items.presentationsBytes,
        filesBytes: items.filesBytes,
        trashBytes: items.trashBytes,
        reservedBytes: await StorageCounters.openReservations(
          session,
          userId,
          transaction: tx,
        ),
      );
      if (row != null && row.reconciledAt != null) {
        final before = StorageTotals.ofRow(row).toMap()
          ..['usedBytes'] = row.usedBytes;
        totals.toMap().forEach((field, after) {
          final b = before[field]!;
          if (b != after) drifts.add(StorageDrift(userId, field, b, after));
        });
      }
      await StorageCounters.write(
        session,
        userId,
        totals,
        transaction: tx,
        withReserved: true,
        reconciled: true,
      );
    });
    for (final d in drifts) {
      if (significant(d.before, d.after)) {
        session.log('$d', level: LogLevel.warning);
      }
    }
    if (drifts.isNotEmpty) await StorageEvents.changed(session, [userId]);
    return drifts;
  }

  /// The nightly reconcile: every user, in batches; users still pending
  /// are backfilled. Returns the number of users with drift.
  static Future<int> reconcileAll(Session session) =>
      _exclusive(session, 'wonky.storageReconcile', () async {
        var drifted = 0;
        var after = 0;
        while (true) {
          final rows = await session.db.unsafeQuery(
            r'''
            SELECT p.id, s."reconciledAt" IS NOT NULL
            FROM user_profile p
            LEFT JOIN user_storage s ON s."userId" = p.id
            WHERE p.id > @after ORDER BY p.id LIMIT @limit
            ''',
            parameters: QueryParameters.named({
              'after': after,
              'limit': userBatch,
            }),
          );
          if (rows.isEmpty) break;
          for (final r in rows) {
            final userId = r[0] as int;
            if (r[1] as bool) {
              await recomputeItemSizes(
                session,
                userId,
                kinds: nightlyKinds,
                attachments: false,
              );
              final d = await reconcileUser(session, userId);
              if (d.isNotEmpty) drifted++;
            } else {
              await backfillUser(session, userId);
            }
          }
          after = rows.last[0] as int;
        }
        return drifted;
      });

  /// Runs [action] unless another instance holds [lock] (a transaction-
  /// scoped advisory lock held for the duration); returns 0 when skipped.
  static Future<int> _exclusive(
    Session session,
    String lock,
    Future<int> Function() action,
  ) => session.db.transaction((tx) async {
    final got = await session.db.unsafeQuery(
      'SELECT pg_try_advisory_xact_lock(hashtext(@name))',
      parameters: QueryParameters.named({'name': lock}),
      transaction: tx,
    );
    if (got.first[0] != true) return 0;
    return action();
  });
}
