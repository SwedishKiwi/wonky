import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import '../common/time.dart';
import '../config/wonky_config.dart';

/// The counters of one user computed from the source rows (Drive 03 §4.3):
/// owned `drive_item` sizes by kind and trash state, open reservations.
class StorageTotals {
  const StorageTotals({
    this.documentsBytes = 0,
    this.spreadsheetsBytes = 0,
    this.presentationsBytes = 0,
    this.filesBytes = 0,
    this.trashBytes = 0,
    this.reservedBytes = 0,
  });

  final int documentsBytes;
  final int spreadsheetsBytes;
  final int presentationsBytes;
  final int filesBytes;
  final int trashBytes;
  final int reservedBytes;

  /// Σ counted size of owned items incl. trash.
  int get usedBytes =>
      documentsBytes +
      spreadsheetsBytes +
      presentationsBytes +
      filesBytes +
      trashBytes;

  /// The counters of [row] (for comparisons).
  static StorageTotals ofRow(UserStorage row) => StorageTotals(
    documentsBytes: row.documentsBytes,
    spreadsheetsBytes: row.spreadsheetsBytes,
    presentationsBytes: row.presentationsBytes,
    filesBytes: row.filesBytes,
    trashBytes: row.trashBytes,
    reservedBytes: row.reservedBytes,
  );

  Map<String, int> toMap() => {
    'usedBytes': usedBytes,
    'reservedBytes': reservedBytes,
    'documentsBytes': documentsBytes,
    'spreadsheetsBytes': spreadsheetsBytes,
    'presentationsBytes': presentationsBytes,
    'filesBytes': filesBytes,
    'trashBytes': trashBytes,
  };
}

/// SQL over `user_storage` shared by the storage service, the backfill and
/// the reconcile. Every write locks the user's row, so the incremental
/// deltas, the recounts and the room checks of one user are serialized.
abstract final class StorageCounters {
  /// The counter an item's counted size belongs to (Drive 03 §2): its kind
  /// counter, or `trashBytes` while trashed. Folders count nothing.
  static String? columnOf(DriveItemKind kind, {required bool trashed}) {
    if (kind == DriveItemKind.folder) return null;
    if (trashed) return 'trashBytes';
    return switch (kind) {
      DriveItemKind.document => 'documentsBytes',
      DriveItemKind.spreadsheet => 'spreadsheetsBytes',
      DriveItemKind.presentation => 'presentationsBytes',
      DriveItemKind.file => 'filesBytes',
      DriveItemKind.folder => null,
    };
  }

  static int get defaultQuota => WonkyConfig.current.quotaBytesPerUser;

  /// The quota of [row] (per-user override or the config default).
  static int quotaOf(UserStorage? row) =>
      row?.quotaBytesOverride ?? defaultQuota;

  /// Creates the user's row when missing; true when it was created. A row
  /// created for a [newUser] is reconciled at once (nothing to backfill);
  /// otherwise it stays "calculating" until the backfill (§9).
  static Future<bool> ensureRow(
    Session session,
    int userId, {
    Transaction? transaction,
    bool newUser = false,
  }) async {
    final now = nowUtc();
    final n = await session.db.unsafeExecute(
      r'''
      INSERT INTO user_storage ("userId", "usedBytes", "reservedBytes",
        "documentsBytes", "spreadsheetsBytes", "presentationsBytes",
        "filesBytes", "trashBytes", "reconciledAt", "updatedAt")
      VALUES (@u, 0, 0, 0, 0, 0, 0, 0, @reconciled, @now)
      ON CONFLICT ("userId") DO NOTHING
      ''',
      parameters: QueryParameters.named({
        'u': userId,
        'now': now,
        'reconciled': newUser ? now : null,
      }),
      transaction: transaction,
    );
    return n > 0;
  }

  /// The user's row; [lock] takes `FOR UPDATE` (needs a [transaction]).
  static Future<UserStorage?> read(
    Session session,
    int userId, {
    Transaction? transaction,
    bool lock = false,
  }) => UserStorage.db.findFirstRow(
    session,
    where: (t) => t.userId.equals(userId),
    transaction: transaction,
    lockMode: lock && transaction != null ? LockMode.forUpdate : null,
  );

  /// Adds [delta] to [column] and `usedBytes` of [userId] (creating the
  /// row when missing) and tracks `overQuotaSince`.
  static Future<void> addUsed(
    Session session,
    int userId,
    String column,
    int delta, {
    required Transaction transaction,
  }) async {
    if (delta == 0) return;
    await ensureRow(session, userId, transaction: transaction);
    await session.db.unsafeExecute(
      '''
      UPDATE user_storage SET
        "usedBytes" = "usedBytes" + @d,
        "$column" = "$column" + @d,
        "overQuotaSince" = CASE
          WHEN "usedBytes" + @d > coalesce("quotaBytesOverride", @quota)
          THEN coalesce("overQuotaSince", @now) ELSE NULL END,
        "updatedAt" = @now
      WHERE "userId" = @u
      ''',
      parameters: QueryParameters.named({
        'u': userId,
        'd': delta,
        'quota': defaultQuota,
        'now': nowUtc(),
      }),
      transaction: transaction,
    );
  }

  /// Adds [delta] to `reservedBytes` of [userId] (never below 0).
  static Future<void> addReserved(
    Session session,
    int userId,
    int delta, {
    required Transaction transaction,
  }) async {
    if (delta == 0) return;
    await session.db.unsafeExecute(
      r'''
      UPDATE user_storage
      SET "reservedBytes" = greatest(0, "reservedBytes" + @d), "updatedAt" = @now
      WHERE "userId" = @u
      ''',
      parameters: QueryParameters.named({
        'u': userId,
        'd': delta,
        'now': nowUtc(),
      }),
      transaction: transaction,
    );
  }

  /// The item-derived counters of [userId] from `drive_item` (folders and
  /// uploads in progress count 0).
  static Future<StorageTotals> itemTotals(
    Session session,
    int userId, {
    Transaction? transaction,
  }) async {
    final rows = await session.db.unsafeQuery(
      r'''
      SELECT
        coalesce(sum(s) FILTER (WHERE t IS NULL AND kind = 'document'), 0)::bigint,
        coalesce(sum(s) FILTER (WHERE t IS NULL AND kind = 'spreadsheet'), 0)::bigint,
        coalesce(sum(s) FILTER (WHERE t IS NULL AND kind = 'presentation'), 0)::bigint,
        coalesce(sum(s) FILTER (WHERE t IS NULL AND kind = 'file'), 0)::bigint,
        coalesce(sum(s) FILTER (WHERE t IS NOT NULL), 0)::bigint
      FROM (
        SELECT "sizeBytes" + "attachmentBytes" AS s, kind, "trashedAt" AS t
        FROM drive_item WHERE "ownerId" = @u AND kind <> 'folder'
      ) x
      ''',
      parameters: QueryParameters.named({'u': userId}),
      transaction: transaction,
    );
    final r = rows.first;
    return StorageTotals(
      documentsBytes: r[0] as int,
      spreadsheetsBytes: r[1] as int,
      presentationsBytes: r[2] as int,
      filesBytes: r[3] as int,
      trashBytes: r[4] as int,
    );
  }

  /// Σ open (unexpired) reservations of [userId].
  static Future<int> openReservations(
    Session session,
    int userId, {
    Transaction? transaction,
  }) async {
    final rows = await session.db.unsafeQuery(
      r'''
      SELECT coalesce(sum(bytes), 0)::bigint FROM storage_reservation
      WHERE "userId" = @u AND "expiresAt" > @now
      ''',
      parameters: QueryParameters.named({'u': userId, 'now': nowUtc()}),
      transaction: transaction,
    );
    return rows.first[0] as int;
  }

  /// Recounts the item-derived counters of [userIds] from `drive_item`
  /// after a structural change (trash, restore, delete, owner change) in
  /// the same [transaction]: lock the row, aggregate, write.
  static Future<void> recountItems(
    Session session,
    Iterable<int> userIds, {
    required Transaction transaction,
  }) async {
    for (final userId in userIds.toSet().toList()..sort()) {
      await ensureRow(session, userId, transaction: transaction);
      await read(session, userId, transaction: transaction, lock: true);
      final t = await itemTotals(session, userId, transaction: transaction);
      await write(session, userId, t, transaction: transaction);
    }
  }

  /// Writes the item-derived counters [t] (and `reservedBytes` when
  /// [withReserved]) of [userId]; [reconciled] also sets `reconciledAt`.
  static Future<void> write(
    Session session,
    int userId,
    StorageTotals t, {
    required Transaction transaction,
    bool withReserved = false,
    bool reconciled = false,
  }) async {
    final now = nowUtc();
    await session.db.unsafeExecute(
      '''
      UPDATE user_storage SET
        "usedBytes" = @used,
        "documentsBytes" = @docs,
        "spreadsheetsBytes" = @sheets,
        "presentationsBytes" = @decks,
        "filesBytes" = @files,
        "trashBytes" = @trash,
        ${withReserved ? '"reservedBytes" = @reserved,' : ''}
        ${reconciled ? '"reconciledAt" = @now,' : ''}
        "overQuotaSince" = CASE
          WHEN @used > coalesce("quotaBytesOverride", @quota)
          THEN coalesce("overQuotaSince", @now) ELSE NULL END,
        "updatedAt" = @now
      WHERE "userId" = @u
      ''',
      parameters: QueryParameters.named({
        'u': userId,
        'used': t.usedBytes,
        'docs': t.documentsBytes,
        'sheets': t.spreadsheetsBytes,
        'decks': t.presentationsBytes,
        'files': t.filesBytes,
        'trash': t.trashBytes,
        if (withReserved) 'reserved': t.reservedBytes,
        'quota': defaultQuota,
        'now': now,
      }),
      transaction: transaction,
    );
  }
}
