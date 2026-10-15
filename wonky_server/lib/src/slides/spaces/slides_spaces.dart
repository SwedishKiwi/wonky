import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides_core/schema.dart' show SlidesTables;

import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../../platform/common/roles.dart';
import '../../platform/sharing/access_service.dart';
import '../../platform/spaces/space_service.dart';
import '../../sheets/spaces/spreadsheet_factory.dart';

/// The deck side of [SpaceService] (Slides 02 §9, suite 12 §2.6): the
/// `slides.*` space endpoints with [SpaceKind.deck] — offline reservations,
/// subscriptions (membership mirrored from the ACL), the pending-change
/// guard — and the download statistics of a deck space.
abstract final class SlidesSpaces {
  static const kind = SpaceKind.deck;

  /// Reserves up to [count] (≤ 5) empty deck spaces for offline creation.
  static Future<List<UuidValue>> reserveSpaces(
    Session session,
    Actor actor,
    int count,
  ) => SpaceService.reserveSpaces(session, actor, count, kind: kind);

  /// Grants membership of the deck's space (readWrite for editors, readOnly
  /// for viewers and commenters) and adds it to the caller's active set.
  static Future<SubscribeResult> subscribe(
    Session session,
    Actor actor,
    UuidValue itemUuid, {
    SubscriptionReason reason = SubscriptionReason.open,
  }) async {
    final grant = await SpaceService.subscribe(
      session,
      actor,
      itemUuid,
      kind: kind,
      reason: reason,
    );
    return SubscribeResult(
      spaceUuid: grant.space,
      role: grant.role.access,
      canWrite: grant.canWrite,
      alreadyMember: grant.alreadyMember,
      stats: await stats(session, grant.space),
    );
  }

  static Future<void> unsubscribe(
    Session session,
    Actor actor,
    UuidValue itemUuid,
  ) => SpaceService.unsubscribe(session, actor, itemUuid, kind: kind);

  /// Pending-change guard: re-grants deck spaces with unsynced local
  /// changes (spreadsheet spaces are skipped).
  static Future<List<UuidValue>> ensureSubscribed(
    Session session,
    Actor actor,
    List<UuidValue> spaces,
  ) => SpaceService.ensureSubscribed(session, actor, spaces, kind: kind);

  // ---------------------------------------------------------------- stats

  /// Visible row counts of a deck space for download progress. The shared
  /// [SpaceStats] has Sheets fields: decks report `sheetCount` = slides and
  /// `cellCount` = elements; `gridCells` is 0.
  static Future<SpaceStats> stats(Session session, UuidValue space) async {
    final counts = await SpreadsheetFactory.rowCounts(session, space);
    return SpaceStats(
      spaceUuid: space,
      rowCounts: counts,
      totalRows: counts.values.fold(0, (a, b) => a + b),
      sheetCount: counts[SlidesTables.slide] ?? 0,
      cellCount: counts[SlidesTables.slideElement] ?? 0,
      gridCells: 0,
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
    return stats(session, SpaceService.spaceOf(item, kind: kind));
  }
}
