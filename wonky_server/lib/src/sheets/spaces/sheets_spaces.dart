import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../../platform/common/roles.dart';
import '../../platform/sharing/access_service.dart';
import '../../platform/spaces/space_service.dart';
import 'spreadsheet_factory.dart';

/// The spreadsheet side of [SpaceService] (suite 12 §2.2–2.3): the
/// `sheets.*` space endpoints with [SpaceKind.spreadsheet], and the
/// download statistics of a spreadsheet space.
abstract final class SheetsSpaces {
  static const kind = SpaceKind.spreadsheet;

  static Future<List<UuidValue>> reserveSpaces(
    Session session,
    Actor actor,
    int count,
  ) => SpaceService.reserveSpaces(session, actor, count, kind: kind);

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

  static Future<List<UuidValue>> ensureSubscribed(
    Session session,
    Actor actor,
    List<UuidValue> spaces,
  ) => SpaceService.ensureSubscribed(session, actor, spaces, kind: kind);

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
    return stats(session, SpaceService.spaceOf(item, kind: kind));
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
}
