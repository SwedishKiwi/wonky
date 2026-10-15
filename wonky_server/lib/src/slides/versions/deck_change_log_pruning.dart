import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../sheets/sync/sync_db.dart';

/// Daily pruning of the deck change log (Slides 02 §3.10, as Sheets'
/// `ChangeLogConsumer.pruneOld`): rows older than [retention] are deleted
/// with their receipts. Versions keep who changed what in their
/// `SlidesSnapshotIndex` (built at capture), so pruning loses no
/// attribution of captured versions.
abstract final class DeckChangeLogPruning {
  /// How long change-log rows are kept.
  static const retention = Duration(days: 30);

  /// Rows deleted per run.
  static const batch = 2000;

  /// Deletes up to [batch] rows older than [retention]; returns how many.
  static Future<int> pruneOld(Session session, {DateTime? now}) async {
    final cutoff = (now ?? nowUtc()).subtract(retention);
    final db = syncSessionOf(session);
    final old = await DeckChangeLog.db.find(
      db,
      where: (t) => t.at < cutoff,
      limit: batch,
    );
    if (old.isEmpty) return 0;
    final byDeck = <UuidValue, List<DeckChangeLog>>{};
    for (final c in old) {
      byDeck.putIfAbsent(c.deckId, () => []).add(c);
    }
    var pruned = 0;
    for (final entry in byDeck.entries) {
      final item = await DriveItem.db.findFirstRow(
        session,
        where: (t) =>
            t.contentRef.equals(entry.key) &
            t.kind.equals(DriveItemKind.presentation),
      );
      // Rows are deleted as the deck's owner (a member of the space).
      final owner = item == null
          ? null
          : await UserProfile.db.findById(session, item.ownerId);
      if (item == null || owner == null) continue;
      final role = await session.offlineSync.spaces.roleOf(
        user: owner.authUserId,
        space: entry.key,
      );
      if (role != OfflineSyncSpaceRole.readWrite) continue;
      final ids = {for (final c in entry.value) c.id};
      await db.offlineSyncDb.transactionForUser(
        owner.authUserId,
        (tx) => DeckChangeLog.db.deleteWhere(
          db,
          where: (t) => t.id.inSet(ids),
          transaction: tx,
        ),
        spaceId: entry.key,
      );
      await DeckChangeLogReceipt.db.deleteWhere(
        session,
        where: (t) => t.changeLogId.inSet(ids),
      );
      pruned += ids.length;
    }
    return pruned;
  }
}
