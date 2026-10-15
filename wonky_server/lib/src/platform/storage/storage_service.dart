import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import '../config/wonky_config.dart';
import 'db_storage_service.dart';

/// The `reason` values of [QuotaExceededDetails] (Drive 03 §7.1).
abstract final class QuotaReason {
  static const upload = 'upload';
  static const image = 'image';
  static const import = 'import';
  static const convert = 'convert';
  static const copy = 'copy';
  static const template = 'template';
  static const transfer = 'transfer';
  static const restoreVersionCopy = 'restoreVersionCopy';

  static const values = [
    upload,
    image,
    import,
    convert,
    copy,
    template,
    transfer,
    restoreVersionCopy,
  ];
}

/// Storage accounting and quota enforcement (Drive 03 §4.2): the only code
/// that changes `user_storage` and `storage_reservation`. Every source change
/// calls it **in the same database transaction** as the change itself (pass
/// that [Transaction]).
///
/// Methods that check room throw `Errors.quotaExceeded`
/// (`WonkyErrorCode.quotaExceeded` with [QuotaExceededDetails]); the
/// bookkeeping methods never throw for quota reasons.
///
/// The installed implementation is [DbStorageService] (D-9);
/// [PassThroughStorageService] (never refuses, no counters) remains for
/// tests that need to bypass the quota.
///
/// The structural callbacks ([onTrash], [onRestore], [onDelete],
/// [onOwnerChange]) are called **after** the change, in its transaction:
/// they recount the affected owners from `drive_item`.
abstract interface class StorageService {
  /// The installed implementation (tests may replace it, and restore it
  /// with [resetInstance]).
  static StorageService instance = const DbStorageService();

  /// Restores the default [instance].
  static void resetInstance() => instance = const DbStorageService();

  /// Reserves [bytes] of [userId]'s quota for the upload of [fileUuid]
  /// (before any byte is sent; Drive 03 §5). Atomic room check +
  /// reservation; throws `quotaExceeded` when it doesn't fit and
  /// `limitExceeded` beyond `maxPendingUploadsPerUser` open reservations.
  /// [callerUserId] (default [userId]) fills `QuotaExceededDetails.isCaller`
  /// (images added to someone else's item charge the owner).
  Future<void> reserve(
    Session session, {
    required int userId,
    required UuidValue fileUuid,
    int? itemId,
    required int bytes,
    String reason = QuotaReason.upload,
    int? callerUserId,
    Transaction? transaction,
  });

  /// Turns the reservation of [fileUuid] into usage with the [actualBytes]
  /// found in storage and updates the item's `sizeBytes` (files) or
  /// `attachmentBytes` (images). Throws `quotaExceeded` when the actual size
  /// is larger than reserved and no longer fits.
  Future<void> commitReservation(
    Session session,
    UuidValue fileUuid,
    int actualBytes, {
    Transaction? transaction,
  });

  /// Releases the reservation of [fileUuid] (cancel, failure, expiry).
  /// No-op when there is none.
  Future<void> releaseReservation(
    Session session,
    UuidValue fileUuid, {
    Transaction? transaction,
  });

  /// Checks that [bytes] fit [userId]'s quota without reserving (copies,
  /// imports, conversions, template creations, ownership transfer). Inside a
  /// [transaction] it locks the user's row until the transaction ends.
  /// Throws `quotaExceeded`.
  Future<void> checkRoom(
    Session session, {
    required int userId,
    required int bytes,
    required String reason,
    int? callerUserId,
    Transaction? transaction,
  });

  /// Sets an item's counted content size (content estimates: OT size
  /// update, `SheetsSizeEstimator`, Slides estimator). Never throws; may put
  /// the owner over quota.
  Future<void> setItemSize(
    Session session,
    DriveItem item,
    int sizeBytes, {
    Transaction? transaction,
  });

  /// Adds [deltaBytes] (negative to subtract) of images/attachments stored
  /// for [item], charged to its owner. Never throws.
  Future<void> addAttachment(
    Session session,
    DriveItem item,
    int deltaBytes, {
    Transaction? transaction,
  });

  /// Moves the counted size of [items] from their kind counters to
  /// `trashBytes` (usage unchanged). Call after the items were trashed.
  Future<void> onTrash(
    Session session,
    List<DriveItem> items, {
    Transaction? transaction,
  });

  /// Moves the counted size of [items] back from `trashBytes`; never
  /// refused (Drive 03 §9, Q16). Call after the items were restored.
  Future<void> onRestore(
    Session session,
    List<DriveItem> items, {
    Transaction? transaction,
  });

  /// Subtracts the counted size of [items] (delete forever, trash purge,
  /// account deletion). Call after the rows were deleted.
  Future<void> onDelete(
    Session session,
    List<DriveItem> items, {
    Transaction? transaction,
  });

  /// Moves [item]'s counted size (content and attachments) from
  /// [fromUserId] to [toUserId] (ownership transfer, Drive 03 §7.3). Call
  /// [checkRoom] for [toUserId] first and this after the owner changed.
  Future<void> onOwnerChange(
    Session session,
    DriveItem item, {
    required int fromUserId,
    required int toUserId,
    Transaction? transaction,
  });

  /// The usage of [userId] (Drive 03 §3).
  Future<StorageUsage> usage(Session session, int userId);
}

/// The D-1 placeholder, kept for tests that bypass the quota: never
/// refuses, keeps no counters, and computes [usage] from the source rows
/// (the v1 `bytesUsed` plus the v2 breakdown).
class PassThroughStorageService implements StorageService {
  const PassThroughStorageService();

  @override
  Future<void> reserve(
    Session session, {
    required int userId,
    required UuidValue fileUuid,
    int? itemId,
    required int bytes,
    String reason = QuotaReason.upload,
    int? callerUserId,
    Transaction? transaction,
  }) async {}

  @override
  Future<void> commitReservation(
    Session session,
    UuidValue fileUuid,
    int actualBytes, {
    Transaction? transaction,
  }) async {}

  @override
  Future<void> releaseReservation(
    Session session,
    UuidValue fileUuid, {
    Transaction? transaction,
  }) async {}

  @override
  Future<void> checkRoom(
    Session session, {
    required int userId,
    required int bytes,
    required String reason,
    int? callerUserId,
    Transaction? transaction,
  }) async {}

  @override
  Future<void> setItemSize(
    Session session,
    DriveItem item,
    int sizeBytes, {
    Transaction? transaction,
  }) async {
    if (item.id == null || item.sizeBytes == sizeBytes) return;
    await session.db.unsafeExecute(
      'UPDATE drive_item SET "sizeBytes" = @n WHERE id = @id',
      parameters: QueryParameters.named({'n': sizeBytes, 'id': item.id}),
      transaction: transaction,
    );
  }

  @override
  Future<void> addAttachment(
    Session session,
    DriveItem item,
    int deltaBytes, {
    Transaction? transaction,
  }) async {
    if (item.id == null || deltaBytes == 0) return;
    await session.db.unsafeExecute(
      'UPDATE drive_item '
      'SET "attachmentBytes" = greatest(0, "attachmentBytes" + @d) '
      'WHERE id = @id',
      parameters: QueryParameters.named({'d': deltaBytes, 'id': item.id}),
      transaction: transaction,
    );
  }

  @override
  Future<void> onTrash(
    Session session,
    List<DriveItem> items, {
    Transaction? transaction,
  }) async {}

  @override
  Future<void> onRestore(
    Session session,
    List<DriveItem> items, {
    Transaction? transaction,
  }) async {}

  @override
  Future<void> onDelete(
    Session session,
    List<DriveItem> items, {
    Transaction? transaction,
  }) async {}

  @override
  Future<void> onOwnerChange(
    Session session,
    DriveItem item, {
    required int fromUserId,
    required int toUserId,
    Transaction? transaction,
  }) async {}

  @override
  Future<StorageUsage> usage(Session session, int userId) async {
    final config = WonkyConfig.current;
    final rows = await session.db.unsafeQuery(
      r'''
      SELECT
        coalesce(sum("sizeBytes" + "attachmentBytes"), 0)::bigint,
        count(*) FILTER (WHERE "trashedAt" IS NULL AND kind = 'document'),
        count(*) FILTER (WHERE "trashedAt" IS NULL AND kind = 'spreadsheet'),
        count(*) FILTER (WHERE "trashedAt" IS NULL AND kind = 'presentation'),
        count(*) FILTER (WHERE "trashedAt" IS NULL AND kind = 'file'),
        count(*) FILTER (WHERE "trashedAt" IS NULL AND kind = 'folder'),
        coalesce(sum("sizeBytes" + "attachmentBytes")
          FILTER (WHERE "trashedAt" IS NULL AND kind = 'document'), 0)::bigint,
        coalesce(sum("sizeBytes" + "attachmentBytes")
          FILTER (WHERE "trashedAt" IS NULL AND kind = 'spreadsheet'), 0)::bigint,
        coalesce(sum("sizeBytes" + "attachmentBytes")
          FILTER (WHERE "trashedAt" IS NULL AND kind = 'presentation'), 0)::bigint,
        coalesce(sum("sizeBytes" + "attachmentBytes")
          FILTER (WHERE "trashedAt" IS NULL AND kind = 'file'), 0)::bigint,
        coalesce(sum("sizeBytes" + "attachmentBytes")
          FILTER (WHERE "trashedAt" IS NOT NULL), 0)::bigint
      FROM drive_item WHERE "ownerId" = @me
      ''',
      parameters: QueryParameters.named({'me': userId}),
    );
    // v1 meaning of bytesUsed (kept until D-9's counters land): item sizes
    // plus every ready StoredFile except exports and import sources (and
    // the v2 file bytes, already in the items' sizes).
    final legacy = await session.db.unsafeQuery(
      r'''
      SELECT coalesce(sum("sizeBytes"), 0)::bigint
      FROM stored_file WHERE "ownerId" = @me AND status = 'ready'
        AND kind NOT IN ('exportResult', 'importSource', 'driveFile',
                         'preview')
      ''',
      parameters: QueryParameters.named({'me': userId}),
    );
    final r = rows.first;
    final l = legacy.first;
    int at(int i) => r[i] as int;
    final used = at(0) + (l[0] as int);
    final quota = config.quotaBytesPerUser;
    final available = quota - used > 0 ? quota - used : 0;
    return StorageUsage(
      bytesUsed: used,
      documents: at(1),
      spreadsheets: at(2),
      presentations: at(3),
      files: at(4),
      folders: at(5),
      documentsBytes: at(6),
      spreadsheetsBytes: at(7),
      presentationsBytes: at(8),
      filesBytes: at(9),
      trashBytes: at(10),
      quotaBytes: quota,
      reservedBytes: 0,
      availableBytes: available,
      overQuota: used > quota,
      maxFileUploadBytes: available < config.maxFileUploadBytes
          ? available
          : config.maxFileUploadBytes,
      calculating: false,
    );
  }
}
