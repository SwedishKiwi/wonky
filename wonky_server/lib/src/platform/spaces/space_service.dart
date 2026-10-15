import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import '../../sheets/sync/sync_db.dart';
import '../common/actor.dart';
import '../common/errors.dart';
import '../common/models.dart';
import '../common/time.dart';
import '../config/wonky_config.dart';
import '../sharing/access_service.dart';
import 'space_kinds.dart';

/// The result of [SpaceService.subscribe].
typedef SpaceSubscribeGrant = ({
  UuidValue space,
  Role role,
  bool canWrite,
  bool alreadyMember,
});

/// Offline-sync spaces of every kind (spreadsheets and, v2, decks): offline
/// reservations, the active set ("subscriptions") and role mirroring into
/// space membership (suite 12 §2.2–2.3, §2.6, specs/06 §3). Reservations
/// and subscriptions carry their [SpaceKind]; limits apply per kind.
///
/// The apps' endpoints wrap it (`sheets.*` with [SpaceKind.spreadsheet],
/// v2 `slides.*` with [SpaceKind.deck]); their sync endpoints sync only
/// their kind (`SpaceSync`, patch OS-8).
abstract final class SpaceService {
  /// Upper bound of one `reserveSpaces` call.
  static const maxReserveCount = 5;

  /// Unused reservations a user may hold across devices, per kind.
  static const maxUnusedReservations = 25;

  /// Subscriptions used within this period are never evicted.
  static const protectedRecency = Duration(days: 30);

  /// Temporary memberships for MCP/script writers.
  static const temporaryMembership = Duration(hours: 1);

  /// The active set limit of [kind] (`sheets.maxActiveSpacesPerUser`,
  /// `slides.maxActiveSpacesPerUser`).
  static int maxActiveSpaces(SpaceKind kind) => switch (kind) {
    SpaceKind.spreadsheet => WonkyConfig.current.maxActiveSpacesPerUser,
    SpaceKind.deck => WonkyConfig.current.maxActiveDecksPerUser,
  };

  // ---------------------------------------------------------- reservations

  /// Creates up to [count] empty spaces of [kind] the caller can write to,
  /// for creating items offline.
  static Future<List<UuidValue>> reserveSpaces(
    Session session,
    Actor actor,
    int count, {
    SpaceKind kind = SpaceKind.spreadsheet,
  }) async {
    final requested = count.clamp(0, maxReserveCount);
    if (requested == 0) return const [];
    final unused = await SpaceReservation.db.count(
      session,
      where: (t) =>
          t.userId.equals(actor.userId) &
          t.usedAt.equals(null) &
          t.kind.equals(kind),
    );
    if (unused >= maxUnusedReservations) {
      throw Errors.limit(
        'Too many reserved spaces. Create some '
        '${SpaceKinds.nounOf(kind)}s first.',
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
            kind: kind,
            createdAt: now,
          ),
          transaction: tx,
        );
        spaces.add(space);
      }
      return spaces;
    });
  }

  /// Creates a space of [kind] for a server-side creation (templates,
  /// copies, imports, MCP) with the caller as its member, and records its
  /// kind from birth (a used reservation), so a sync endpoint of another
  /// kind never sees it — not even before its drive item exists.
  static Future<UuidValue> createSpace(
    Session session,
    Actor actor, {
    required SpaceKind kind,
    Transaction? transaction,
  }) async {
    Future<UuidValue> create(Transaction tx) async {
      final space = await session.offlineSync.spaces.createFor(
        actor.authUserId,
        transaction: tx,
      );
      final now = nowUtc();
      await SpaceReservation.db.insertRow(
        session,
        SpaceReservation(
          userId: actor.userId,
          spaceUuid: space,
          kind: kind,
          createdAt: now,
          usedAt: now,
        ),
        transaction: tx,
      );
      return space;
    }

    if (transaction != null) return create(transaction);
    return session.db.transaction(create);
  }

  /// Marks the reservation of [spaceUuid] as used by an item of [kind].
  /// Returns false when the space was not reserved by [actor]; throws when
  /// it was reserved for another kind of item.
  static Future<bool> useReservation(
    Session session,
    Actor actor,
    UuidValue spaceUuid, {
    SpaceKind kind = SpaceKind.spreadsheet,
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
    if (reservation.kind != kind) {
      throw Errors.invalid(
        'This space is reserved for a '
        '${SpaceKinds.nounOf(reservation.kind)}.',
      );
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

  /// Grants the caller membership of the item's space (role mirrored from
  /// the ACL) and records the subscription. The item must hold a space of
  /// [kind].
  static Future<SpaceSubscribeGrant> subscribe(
    Session session,
    Actor actor,
    UuidValue itemUuid, {
    required SpaceKind kind,
    SubscriptionReason reason = SubscriptionReason.open,
  }) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.viewer,
    );
    final space = spaceOf(item, kind: kind);
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
    return (
      space: space,
      role: role,
      canWrite: role >= Role.editor,
      alreadyMember: existing != null,
    );
  }

  /// Upserts the subscription row of [userId] on [item] (its kind follows
  /// the item).
  static Future<void> touchSubscription(
    Session session,
    int userId,
    DriveItem item, {
    SubscriptionReason reason = SubscriptionReason.open,
    Transaction? transaction,
  }) async {
    final space = spaceOf(item);
    final kind = SpaceKinds.ofItem(item)!;
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
          kind: kind,
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
        kind: kind,
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
  /// of [kind] the caller still has access to (or reserved), so unsynced
  /// local changes are not stranded. Returns the spaces the caller is a
  /// member of afterwards. Spaces of another kind are skipped.
  static Future<List<UuidValue>> ensureSubscribed(
    Session session,
    Actor actor,
    List<UuidValue> spaces, {
    SpaceKind kind = SpaceKind.spreadsheet,
  }) async {
    final result = <UuidValue>[];
    final itemKind = SpaceKinds.itemKindOf(kind);
    for (final space in spaces.toSet().take(200)) {
      final item = await DriveItem.db.findFirstRow(
        session,
        where: (t) => t.contentRef.equals(space) & t.kind.equals(itemKind),
      );
      if (item == null) {
        // A reservation whose item is not registered yet.
        final reservation = await SpaceReservation.db.findFirstRow(
          session,
          where: (t) => t.spaceUuid.equals(space),
        );
        if (reservation?.userId == actor.userId && reservation?.kind == kind) {
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

  /// Ends the caller's subscription of an item of [kind] (membership is
  /// removed; pinned subscriptions are kept).
  static Future<void> unsubscribe(
    Session session,
    Actor actor,
    UuidValue itemUuid, {
    required SpaceKind kind,
  }) async {
    final (item, _) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.viewer,
    );
    final space = spaceOf(item, kind: kind);
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
    if (SpaceKinds.ofItem(item) == null) return;
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
    if (SpaceKinds.ofItem(item) == null) return;
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
    final space = spaceOf(item);
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

  /// Daily active-set eviction, per kind: beyond [maxActiveSpaces] of a
  /// kind, least recently used subscriptions of that kind are removed,
  /// except pinned ones and ones used within [protectedRecency]. Expired
  /// temporary (mcp/script) memberships are removed too. Returns the number
  /// of removals.
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
    for (final kind in SpaceKind.values) {
      final limit = maxActiveSpaces(kind);
      final heavy = await session.db.unsafeQuery(
        r'SELECT "userId" FROM space_subscription WHERE "kind" = @kind '
        r'GROUP BY "userId" HAVING count(*) > @limit',
        parameters: QueryParameters.named({'kind': kind.name, 'limit': limit}),
      );
      for (final row in heavy) {
        final userId = row[0] as int;
        final subs = await SpaceSubscription.db.find(
          session,
          where: (t) => t.userId.equals(userId) & t.kind.equals(kind),
          orderBy: (t) => t.lastUsedAt.desc(),
        );
        for (final sub in subs.skip(limit)) {
          if (sub.pinned) continue;
          if (sub.lastUsedAt.isAfter(at.subtract(protectedRecency))) continue;
          await _removeSubscription(session, sub);
          removed++;
        }
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
    // Owners keep their membership: their own items always sync.
    if (item != null && item.ownerId == profile.id) return;
    await session.offlineSync.spaces.revoke(
      space: sub.spaceUuid,
      user: profile.authUserId,
    );
  }

  // --------------------------------------------------------------- items

  /// The space of [item]; throws when it has none or (with [kind]) holds a
  /// space of another kind.
  static UuidValue spaceOf(DriveItem item, {SpaceKind? kind}) {
    final itemKind = SpaceKinds.ofItem(item);
    if (itemKind == null || kind != null && itemKind != kind) {
      throw Errors.invalid(
        'This item is not a '
        '${SpaceKinds.nounOf(kind ?? SpaceKind.spreadsheet)}.',
      );
    }
    return item.contentRef!;
  }
}
