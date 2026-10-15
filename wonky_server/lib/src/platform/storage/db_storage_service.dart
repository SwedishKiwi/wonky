import 'package:serverpod/serverpod.dart';

import '../common/errors.dart';
import '../common/models.dart';
import '../common/time.dart';
import '../config/wonky_config.dart';
import 'storage_counters.dart';
import 'storage_events.dart';
import 'storage_service.dart';

/// The real [StorageService] (Drive 03 §4): counters in `user_storage`,
/// reservations in `storage_reservation`, maintained in the caller's
/// transaction.
///
/// - Room checks and reservations compare `usedBytes + reservedBytes +
///   bytes` with the quota under the user's row lock; the reservation is
///   one conditional `UPDATE`, so parallel uploads can't overshoot.
/// - Content and attachment sizes change by deltas into the item's
///   counter (its kind, or trash).
/// - Structural changes (trash, restore, delete, owner change) recount the
///   affected owners' item-derived counters from `drive_item` in the same
///   transaction (call them **after** the change).
/// - Users whose backfill hasn't finished (`reconciledAt == null`) are
///   never refused (fail open, §9); their usage reports `calculating`.
class DbStorageService implements StorageService {
  const DbStorageService();

  /// How long a reservation holds quota (Drive 03 §5).
  static const reservationLifetime = Duration(hours: 24);

  Future<T> _inTx<T>(
    Session session,
    Transaction? transaction,
    Future<T> Function(Transaction tx) action,
  ) => transaction != null
      ? action(transaction)
      : session.db.transaction(action);

  // ------------------------------------------------------------- refusal

  Future<WonkyException> _refusal(
    Session session, {
    required int userId,
    required UserStorage? row,
    required int bytes,
    required String reason,
    int? callerUserId,
    Transaction? transaction,
  }) async {
    final quota = StorageCounters.quotaOf(row);
    final used = (row?.usedBytes ?? 0) + (row?.reservedBytes ?? 0);
    final profile = await UserProfile.db.findById(
      session,
      userId,
      transaction: transaction,
    );
    return Errors.quotaExceeded(
      QuotaExceededDetails(
        neededBytes: bytes,
        availableBytes: quota - used > 0 ? quota - used : 0,
        quotaBytes: quota,
        chargedUserId: userId,
        chargedUserName: profile?.displayName ?? '',
        isCaller: (callerUserId ?? userId) == userId,
        reason: reason,
      ),
    );
  }

  // --------------------------------------------------------- reservations

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
  }) async {
    if (bytes < 0) throw Errors.invalid('The size is invalid.');
    await _inTx(session, transaction, (tx) async {
      final existing = await StorageReservation.db.findFirstRow(
        session,
        where: (t) => t.fileUuid.equals(fileUuid),
        transaction: tx,
      );
      if (existing != null) return; // idempotent retry
      await StorageCounters.ensureRow(session, userId, transaction: tx);
      final pending = await StorageReservation.db.count(
        session,
        where: (t) => t.userId.equals(userId) & (t.expiresAt > nowUtc()),
        transaction: tx,
      );
      if (pending >= WonkyConfig.current.maxPendingUploadsPerUser) {
        throw Errors.limit(
          'Too many uploads at once. Wait for some to finish.',
        );
      }
      final now = nowUtc();
      final updated = await session.db.unsafeQuery(
        r'''
        UPDATE user_storage
           SET "reservedBytes" = "reservedBytes" + @n, "updatedAt" = @now
         WHERE "userId" = @u
           AND ("reconciledAt" IS NULL
             OR "usedBytes" + "reservedBytes" + @n
                <= coalesce("quotaBytesOverride", @quota))
        RETURNING "usedBytes", "reservedBytes"
        ''',
        parameters: QueryParameters.named({
          'u': userId,
          'n': bytes,
          'quota': StorageCounters.defaultQuota,
          'now': now,
        }),
        transaction: tx,
      );
      if (updated.isEmpty) {
        throw await _refusal(
          session,
          userId: userId,
          row: await StorageCounters.read(session, userId, transaction: tx),
          bytes: bytes,
          reason: reason,
          callerUserId: callerUserId,
          transaction: tx,
        );
      }
      await StorageReservation.db.insertRow(
        session,
        StorageReservation(
          userId: userId,
          fileUuid: fileUuid,
          itemId: itemId,
          bytes: bytes,
          createdAt: now,
          expiresAt: now.add(reservationLifetime),
        ),
        transaction: tx,
      );
    });
    await StorageEvents.changed(session, [userId]);
  }

  @override
  Future<void> commitReservation(
    Session session,
    UuidValue fileUuid,
    int actualBytes, {
    Transaction? transaction,
  }) async {
    final touched = <int>{};
    await _inTx(session, transaction, (tx) async {
      final reservation = await StorageReservation.db.findFirstRow(
        session,
        where: (t) => t.fileUuid.equals(fileUuid),
        transaction: tx,
        lockMode: LockMode.forUpdate,
      );
      final file = await StoredFile.db.findFirstRow(
        session,
        where: (t) => t.fileUuid.equals(fileUuid),
        transaction: tx,
      );
      final itemId = file?.itemId ?? reservation?.itemId;
      final isImage = file?.kind == StoredFileKind.image;
      if (reservation == null) {
        // Already committed (idempotent), or released by expiry: files are
        // set to their exact size (idempotent); images are not charged
        // twice (the backfill/reconcile recompute attachments).
        if (!isImage && itemId != null) {
          touched.addAll(
            await _setColumn(session, itemId, 'sizeBytes', actualBytes, tx),
          );
        }
        return;
      }
      await StorageReservation.db.deleteRow(
        session,
        reservation,
        transaction: tx,
      );
      await StorageCounters.addReserved(
        session,
        reservation.userId,
        -reservation.bytes,
        transaction: tx,
      );
      touched.add(reservation.userId);
      final item = itemId == null
          ? null
          : await DriveItem.db.findById(session, itemId, transaction: tx);
      if (item == null) return;
      final extra = actualBytes - reservation.bytes;
      if (extra > 0) {
        await checkRoom(
          session,
          userId: item.ownerId,
          bytes: extra,
          reason: isImage ? QuotaReason.image : QuotaReason.upload,
          callerUserId: reservation.userId,
          transaction: tx,
        );
      }
      if (isImage) {
        touched.addAll(
          await _addColumn(
            session,
            item.id!,
            'attachmentBytes',
            actualBytes,
            tx,
          ),
        );
      } else {
        touched.addAll(
          await _setColumn(session, item.id!, 'sizeBytes', actualBytes, tx),
        );
      }
    });
    await StorageEvents.changed(session, touched);
  }

  @override
  Future<void> releaseReservation(
    Session session,
    UuidValue fileUuid, {
    Transaction? transaction,
  }) async {
    int? userId;
    await _inTx(session, transaction, (tx) async {
      final reservation = await StorageReservation.db.findFirstRow(
        session,
        where: (t) => t.fileUuid.equals(fileUuid),
        transaction: tx,
        lockMode: LockMode.forUpdate,
      );
      if (reservation == null) return;
      await StorageReservation.db.deleteRow(
        session,
        reservation,
        transaction: tx,
      );
      await StorageCounters.addReserved(
        session,
        reservation.userId,
        -reservation.bytes,
        transaction: tx,
      );
      userId = reservation.userId;
    });
    if (userId != null) await StorageEvents.changed(session, [userId!]);
  }

  // ---------------------------------------------------------- room check

  @override
  Future<void> checkRoom(
    Session session, {
    required int userId,
    required int bytes,
    required String reason,
    int? callerUserId,
    Transaction? transaction,
  }) async {
    if (bytes <= 0) return; // blank items are always allowed
    await StorageCounters.ensureRow(session, userId, transaction: transaction);
    final row = await StorageCounters.read(
      session,
      userId,
      transaction: transaction,
      lock: true,
    );
    if (row == null || row.reconciledAt == null) return; // fail open (§9)
    final quota = StorageCounters.quotaOf(row);
    if (row.usedBytes + row.reservedBytes + bytes <= quota) return;
    throw await _refusal(
      session,
      userId: userId,
      row: row,
      bytes: bytes,
      reason: reason,
      callerUserId: callerUserId,
      transaction: transaction,
    );
  }

  // ------------------------------------------------------------- content

  /// Sets `drive_item.<column>` of [itemId] to [value] and moves the
  /// difference into the owner's counter. Returns the charged owner.
  Future<Set<int>> _setColumn(
    Session session,
    int itemId,
    String column,
    int value,
    Transaction tx,
  ) => _change(session, itemId, column, tx, (old) => value);

  /// Adds [delta] to `drive_item.<column>` (never below 0).
  Future<Set<int>> _addColumn(
    Session session,
    int itemId,
    String column,
    int delta,
    Transaction tx,
  ) => _change(session, itemId, column, tx, (old) {
    final v = old + delta;
    return v < 0 ? 0 : v;
  });

  Future<Set<int>> _change(
    Session session,
    int itemId,
    String column,
    Transaction tx,
    int Function(int old) next,
  ) async {
    final rows = await session.db.unsafeQuery(
      '''
      SELECT "$column", "ownerId", kind, "trashedAt" IS NOT NULL
      FROM drive_item WHERE id = @id FOR UPDATE
      ''',
      parameters: QueryParameters.named({'id': itemId}),
      transaction: tx,
    );
    if (rows.isEmpty) return const {};
    final r = rows.first;
    final old = r[0] as int;
    final ownerId = r[1] as int;
    final kind = DriveItemKind.fromJson('${r[2]}');
    final trashed = r[3] as bool;
    final value = next(old);
    if (value == old) return const {};
    await session.db.unsafeExecute(
      'UPDATE drive_item SET "$column" = @v WHERE id = @id',
      parameters: QueryParameters.named({'v': value, 'id': itemId}),
      transaction: tx,
    );
    final counter = StorageCounters.columnOf(kind, trashed: trashed);
    if (counter == null) return const {};
    await StorageCounters.addUsed(
      session,
      ownerId,
      counter,
      value - old,
      transaction: tx,
    );
    return {ownerId};
  }

  @override
  Future<void> setItemSize(
    Session session,
    DriveItem item,
    int sizeBytes, {
    Transaction? transaction,
  }) async {
    if (item.id == null) return;
    final touched = await _inTx(
      session,
      transaction,
      (tx) => _setColumn(
        session,
        item.id!,
        'sizeBytes',
        sizeBytes < 0 ? 0 : sizeBytes,
        tx,
      ),
    );
    await StorageEvents.changed(session, touched);
  }

  @override
  Future<void> addAttachment(
    Session session,
    DriveItem item,
    int deltaBytes, {
    Transaction? transaction,
  }) async {
    if (item.id == null || deltaBytes == 0) return;
    final touched = await _inTx(
      session,
      transaction,
      (tx) => _addColumn(session, item.id!, 'attachmentBytes', deltaBytes, tx),
    );
    await StorageEvents.changed(session, touched);
  }

  // ---------------------------------------------------------- structure

  Future<void> _recount(
    Session session,
    Set<int> userIds,
    Transaction? transaction,
  ) async {
    if (userIds.isEmpty) return;
    await _inTx(
      session,
      transaction,
      (tx) => StorageCounters.recountItems(session, userIds, transaction: tx),
    );
    await StorageEvents.changed(session, userIds);
  }

  @override
  Future<void> onTrash(
    Session session,
    List<DriveItem> items, {
    Transaction? transaction,
  }) => _recount(session, {for (final i in items) i.ownerId}, transaction);

  @override
  Future<void> onRestore(
    Session session,
    List<DriveItem> items, {
    Transaction? transaction,
  }) => _recount(session, {for (final i in items) i.ownerId}, transaction);

  @override
  Future<void> onDelete(
    Session session,
    List<DriveItem> items, {
    Transaction? transaction,
  }) => _recount(session, {for (final i in items) i.ownerId}, transaction);

  @override
  Future<void> onOwnerChange(
    Session session,
    DriveItem item, {
    required int fromUserId,
    required int toUserId,
    Transaction? transaction,
  }) => _recount(session, {fromUserId, toUserId}, transaction);

  // --------------------------------------------------------------- usage

  @override
  Future<StorageUsage> usage(Session session, int userId) async {
    final config = WonkyConfig.current;
    final row = await StorageCounters.read(session, userId);
    final counts = await session.db.unsafeQuery(
      r'''
      SELECT
        count(*) FILTER (WHERE kind = 'document'),
        count(*) FILTER (WHERE kind = 'spreadsheet'),
        count(*) FILTER (WHERE kind = 'presentation'),
        count(*) FILTER (WHERE kind = 'file'),
        count(*) FILTER (WHERE kind = 'folder')
      FROM drive_item
      WHERE "ownerId" = @u AND "trashedAt" IS NULL
        AND ("uploadState" IS NULL OR "uploadState" = 'ready')
      ''',
      parameters: QueryParameters.named({'u': userId}),
    );
    final c = counts.first;
    final calculating = row == null || row.reconciledAt == null;
    // While calculating, show the best numbers the sources give now.
    final t = calculating
        ? await StorageCounters.itemTotals(session, userId)
        : StorageTotals.ofRow(row);
    final reserved = row?.reservedBytes ?? 0;
    final used = t.usedBytes;
    final quota = StorageCounters.quotaOf(row);
    final free = quota - used - reserved;
    final available = free > 0 ? free : 0;
    return StorageUsage(
      quotaBytes: quota,
      bytesUsed: used,
      reservedBytes: reserved,
      availableBytes: available,
      overQuota: used > quota,
      documentsBytes: t.documentsBytes,
      spreadsheetsBytes: t.spreadsheetsBytes,
      presentationsBytes: t.presentationsBytes,
      filesBytes: t.filesBytes,
      trashBytes: t.trashBytes,
      documents: c[0] as int,
      spreadsheets: c[1] as int,
      presentations: c[2] as int,
      files: c[3] as int,
      folders: c[4] as int,
      maxFileUploadBytes: calculating
          ? config.maxFileUploadBytes
          : (available < config.maxFileUploadBytes
                ? available
                : config.maxFileUploadBytes),
      calculating: calculating,
    );
  }
}
