import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/common/roles.dart';
import '../../platform/common/time.dart';
import '../../platform/config/wonky_config.dart';
import '../../platform/sharing/access_service.dart';
import '../sync/sync_db.dart';
import 'spreadsheet_factory.dart';

/// Spreadsheet spaces: offline reservations, the active set
/// ("subscriptions") and role mirroring into space membership (suite 12
/// §2.2–2.3, specs/06 §3).
abstract final class SpaceService {
  /// Upper bound of one `reserveSpaces` call.
  static const maxReserveCount = 5;

  /// Unused reservations a user may hold across devices.
  static const maxUnusedReservations = 25;

  /// Subscriptions used within this period are never evicted.
  static const protectedRecency = Duration(days: 30);

  /// Temporary memberships for MCP/script writers.
  static const temporaryMembership = Duration(hours: 1);

  // ---------------------------------------------------------- reservations

  /// Creates up to [count] empty spaces the caller can write to, for creating
  /// spreadsheets offline.
  static Future<List<UuidValue>> reserveSpaces(
    Session session,
    Actor actor,
    int count,
  ) async {
    final requested = count.clamp(0, maxReserveCount);
    if (requested == 0) return const [];
    final unused = await SpaceReservation.db.count(
      session,
      where: (t) => t.userId.equals(actor.userId) & t.usedAt.equals(null),
    );
    if (unused >= maxUnusedReservations) {
      throw Errors.limit(
        'Too many reserved spaces. Create some spreadsheets first.',
      );
    }
    final granted = requested.clamp(0, maxUnusedReservations - unused);
    final now = nowUtc();
    return session.db.transaction((tx) async {
      final spaces = <UuidValue>[];
      for (var i = 0; i < granted; i++) {
        final space = await session.offlineSync.spaces.createFor(
          actor.authUserId,
          transaction: tx,
        );
        await SpaceReservation.db.insertRow(
          session,
          SpaceReservation(
            userId: actor.userId,
            spaceUuid: space,
            createdAt: now,
          ),
          transaction: tx,
        );
        spaces.add(space);
      }
      return spaces;
    });
  }

  /// Marks the reservation of [spaceUuid] as used. Returns false when the
  /// space was not reserved by [actor].
  static Future<bool> useReservation(
    Session session,
    Actor actor,
    UuidValue spaceUuid, {
    Transaction? transaction,
  }) async {
    final reservation = await SpaceReservation.db.findFirstRow(
      session,
      where: (t) => t.spaceUuid.equals(spaceUuid),
      transaction: transaction,
    );
    if (reservation == null || reservation.userId != actor.userId) {
      return false;
    }
    if (reservation.usedAt == null) {
      await SpaceReservation.db.updateRow(
        session,
        reservation.copyWith(usedAt: nowUtc()),
        transaction: transaction,
      );
    }
    return true;
  }

  // --------------------------------------------------------- subscriptions

  /// Grants the caller membership of the spreadsheet's space (role mirrored
  /// from the ACL) and records the subscription.
  static Future<SubscribeResult> subscribe(
    Session session,
    Actor actor,
    UuidValue itemUuid, {
    SubscriptionReason reason = SubscriptionReason.open,
  }) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.viewer,
    );
    final space = _spaceOf(item);
    final existing = await session.offlineSync.spaces.roleOf(
      user: actor.authUserId,
      space: space,
    );
    final wanted = spaceRoleFor(canWrite: role >= Role.editor);
    if (existing != wanted) {
      await session.offlineSync.spaces.grant(
        space: space,
        user: actor.authUserId,
        role: wanted,
      );
    }
    await touchSubscription(session, actor.userId, item, reason: reason);
    return SubscribeResult(
      spaceUuid: space,
      role: role.access,
      canWrite: role >= Role.editor,
      alreadyMember: existing != null,
      stats: await stats(session, space),
    );
  }

  /// Upserts the subscription row of [userId] on [item].
  static Future<void> touchSubscription(
    Session session,
    int userId,
    DriveItem item, {
    SubscriptionReason reason = SubscriptionReason.open,
    Transaction? transaction,
  }) async {
    final space = _spaceOf(item);
    final now = nowUtc();
    final existing = await SpaceSubscription.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId) & t.spaceUuid.equals(space),
      transaction: transaction,
    );
    final temporary =
        reason == SubscriptionReason.mcp || reason == SubscriptionReason.script;
    if (existing == null) {
      await SpaceSubscription.db.insertRow(
        session,
        SpaceSubscription(
          userId: userId,
          spreadsheetItemId: item.id!,
          spaceUuid: space,
          reason: reason,
          lastUsedAt: now,
          reasonExpiresAt: temporary ? now.add(temporaryMembership) : null,
        ),
        transaction: transaction,
      );
      return;
    }
    final keepReason = temporary && !_isTemporary(existing.reason)
        ? existing.reason
        : reason;
    await SpaceSubscription.db.updateRow(
      session,
      existing.copyWith(
        lastUsedAt: now,
        reason: keepReason,
        reasonExpiresAt: _isTemporary(keepReason)
            ? now.add(temporaryMembership)
            : null,
      ),
      transaction: transaction,
    );
  }

  static bool _isTemporary(SubscriptionReason r) =>
      r == SubscriptionReason.mcp || r == SubscriptionReason.script;

  /// Pending-change guard (suite 12 §2.3): re-grants membership of [spaces]
  /// the caller still has access to (or reserved), so unsynced local
  /// changes are not stranded. Returns the spaces the caller is a member of
  /// afterwards.
  static Future<List<UuidValue>> ensureSubscribed(
    Session session,
    Actor actor,
    List<UuidValue> spaces,
  ) async {
    final result = <UuidValue>[];
    for (final space in spaces.toSet().take(200)) {
      final item = await DriveItem.db.findFirstRow(
        session,
        where: (t) =>
            t.contentRef.equals(space) &
            t.kind.equals(DriveItemKind.spreadsheet),
      );
      if (item == null) {
        // A reservation whose spreadsheet is not registered yet.
        final reservation = await SpaceReservation.db.findFirstRow(
          session,
          where: (t) => t.spaceUuid.equals(space),
        );
        if (reservation?.userId == actor.userId) {
          await session.offlineSync.spaces.grant(
            space: space,
            user: actor.authUserId,
            role: OfflineSyncSpaceRole.readWrite,
          );
          result.add(space);
        }
        continue;
      }
      final role = await AccessService.effectiveRole(
        session,
        actor.userId,
        item,
      );
      if (role == null) continue;
      final wanted = spaceRoleFor(canWrite: role >= Role.editor);
      final existing = await session.offlineSync.spaces.roleOf(
        user: actor.authUserId,
        space: space,
      );
      if (existing != wanted) {
        await session.offlineSync.spaces.grant(
          space: space,
          user: actor.authUserId,
          role: wanted,
        );
      }
      await touchSubscription(
        session,
        actor.userId,
        item,
        reason: SubscriptionReason.recent,
      );
      result.add(space);
    }
    return result;
  }

  /// Ends the caller's subscription (membership is removed; pinned
  /// subscriptions are kept).
  static Future<void> unsubscribe(
    Session session,
    Actor actor,
    UuidValue itemUuid,
  ) async {
    final (item, _) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.viewer,
    );
    final space = _spaceOf(item);
    final sub = await SpaceSubscription.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(actor.userId) & t.spaceUuid.equals(space),
    );
    if (sub?.pinned ?? false) return;
    if (sub != null) await SpaceSubscription.db.deleteRow(session, sub);
    if (item.ownerId != actor.userId) {
      await session.offlineSync.spaces.revoke(
        space: space,
        user: actor.authUserId,
      );
    }
  }

  /// Mirrors pinning (`drive.setPinnedOffline`) into the subscription.
  static Future<void> setPinned(
    Session session,
    Actor actor,
    DriveItem item,
    bool pinned,
  ) async {
    if (item.kind != DriveItemKind.spreadsheet || item.contentRef == null) {
      return;
    }
    if (pinned) {
      final role = await AccessService.effectiveRole(
        session,
        actor.userId,
        item,
      );
      if (role == null) return;
      await session.offlineSync.spaces.grant(
        space: item.contentRef!,
        user: actor.authUserId,
        role: spaceRoleFor(canWrite: role >= Role.editor),
      );
      await touchSubscription(
        session,
        actor.userId,
        item,
        reason: SubscriptionReason.pinned,
      );
    }
    await SpaceSubscription.db.updateWhere(
      session,
      columnValues: (t) => [t.pinned(pinned)],
      where: (t) =>
          t.userId.equals(actor.userId) & t.spaceUuid.equals(item.contentRef!),
    );
  }

  // --------------------------------------------------------------- mirror

  /// Re-applies the ACL to every member of [item]'s space: members without
  /// access are revoked, others get the mirrored role.
  static Future<void> mirrorMembership(Session session, DriveItem item) async {
    if (item.kind != DriveItemKind.spreadsheet || item.contentRef == null) {
      return;
    }
    final space = item.contentRef!;
    final members = await session.offlineSync.spaces.members(space);
    if (members.isEmpty) return;
    final profiles = await UserProfile.db.find(
      session,
      where: (t) => t.authUserId.inSet(members.keys.toSet()),
    );
    final byAuth = {for (final p in profiles) p.authUserId: p};
    for (final entry in members.entries) {
      final profile = byAuth[entry.key];
      final role = profile == null
          ? null
          : await AccessService.effectiveRole(session, profile.id!, item);
      if (role == null || item.trashedAt != null && role != Role.owner) {
        await session.offlineSync.spaces.revoke(space: space, user: entry.key);
        if (profile != null) {
          await SpaceSubscription.db.deleteWhere(
            session,
            where: (t) =>
                t.userId.equals(profile.id!) & t.spaceUuid.equals(space),
          );
        }
        continue;
      }
      final wanted = spaceRoleFor(canWrite: role >= Role.editor);
      if (entry.value != wanted) {
        await session.offlineSync.spaces.grant(
          space: space,
          user: entry.key,
          role: wanted,
        );
      }
    }
  }

  /// Makes sure [actor] can write [item]'s space for a server-side write
  /// (MCP, scripts, restores), with a temporary subscription.
  static Future<void> ensureWriter(
    Session session,
    Actor actor,
    DriveItem item, {
    SubscriptionReason reason = SubscriptionReason.mcp,
  }) async {
    final role = await AccessService.requireRole(
      session,
      actor,
      item,
      Role.editor,
    );
    final space = _spaceOf(item);
    final existing = await session.offlineSync.spaces.roleOf(
      user: actor.authUserId,
      space: space,
    );
    if (existing != OfflineSyncSpaceRole.readWrite) {
      await session.offlineSync.spaces.grant(
        space: space,
        user: actor.authUserId,
        role: spaceRoleFor(canWrite: role >= Role.editor),
      );
      await touchSubscription(session, actor.userId, item, reason: reason);
    }
  }

  // ---------------------------------------------------------------- jobs

  /// Daily active-set eviction: beyond `sheets.maxActiveSpacesPerUser`,
  /// least recently used subscriptions are removed, except pinned ones and
  /// ones used within [protectedRecency]. Expired temporary (mcp/script)
  /// memberships are removed too. Returns the number of removals.
  static Future<int> evictInactive(Session session, {DateTime? now}) async {
    final at = now ?? nowUtc();
    var removed = 0;
    final expired = await SpaceSubscription.db.find(
      session,
      where: (t) => t.reasonExpiresAt < at,
    );
    for (final sub in expired) {
      await _removeSubscription(session, sub);
      removed++;
    }
    final limit = WonkyConfig.current.maxActiveSpacesPerUser;
    final heavy = await session.db.unsafeQuery(
      r'SELECT "userId" FROM space_subscription GROUP BY "userId" HAVING count(*) > @limit',
      parameters: QueryParameters.named({'limit': limit}),
    );
    for (final row in heavy) {
      final userId = row[0] as int;
      final subs = await SpaceSubscription.db.find(
        session,
        where: (t) => t.userId.equals(userId),
        orderBy: (t) => t.lastUsedAt.desc(),
      );
      for (final sub in subs.skip(limit)) {
        if (sub.pinned) continue;
        if (sub.lastUsedAt.isAfter(at.subtract(protectedRecency))) continue;
        await _removeSubscription(session, sub);
        removed++;
      }
    }
    return removed;
  }

  static Future<void> _removeSubscription(
    Session session,
    SpaceSubscription sub,
  ) async {
    final profile = await UserProfile.db.findById(session, sub.userId);
    final item = await DriveItem.db.findById(session, sub.spreadsheetItemId);
    await SpaceSubscription.db.deleteRow(session, sub);
    if (profile == null) return;
    // Owners keep their membership: their own spreadsheets always sync.
    if (item != null && item.ownerId == profile.id) return;
    await session.offlineSync.spaces.revoke(
      space: sub.spaceUuid,
      user: profile.authUserId,
    );
  }

  // ---------------------------------------------------------------- stats

  static Future<SpaceStats> stats(Session session, UuidValue space) async {
    final counts = await SpreadsheetFactory.rowCounts(session, space);
    final grid = await _gridCells(session, space);
    return SpaceStats(
      spaceUuid: space,
      rowCounts: counts,
      totalRows: counts.values.fold(0, (a, b) => a + b),
      sheetCount: counts['sheet'] ?? 0,
      cellCount: counts['cell'] ?? 0,
      gridCells: grid,
    );
  }

  static Future<SpaceStats> statsFor(
    Session session,
    Actor actor,
    UuidValue itemUuid,
  ) async {
    final (item, _) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.viewer,
    );
    return stats(session, _spaceOf(item));
  }

  static Future<int> _gridCells(Session session, UuidValue space) async {
    final spaceRow = await OfflineSyncSpace.db.findFirstRow(
      session,
      where: (t) => t.uuidSpaceId.equals(space),
    );
    if (spaceRow == null) return 0;
    Future<Map<String, int>> countBySheet(String table) async {
      final rows = await session.db.unsafeQuery(
        '''
        SELECT d."sheetId", count(*) FROM "$table" d
        JOIN crdt_data_rows r ON r."uuidRowId" = d.id
        JOIN crdt_schema_tables t ON t.id = r."tblId" AND t.name = @table
        WHERE r."spaceId" = @space AND r.visibility <= 2
        GROUP BY d."sheetId"
        ''',
        parameters: QueryParameters.named({
          'space': spaceRow.id,
          'table': table,
        }),
      );
      return {for (final row in rows) '${row[0]}': row[1] as int};
    }

    final rows = await countBySheet('sheet_row');
    final cols = await countBySheet('sheet_column');
    var total = 0;
    rows.forEach((sheet, n) => total += n * (cols[sheet] ?? 0));
    return total;
  }

  static UuidValue _spaceOf(DriveItem item) {
    if (item.kind != DriveItemKind.spreadsheet || item.contentRef == null) {
      throw Errors.invalid('This item is not a spreadsheet.');
    }
    return item.contentRef!;
  }
}
