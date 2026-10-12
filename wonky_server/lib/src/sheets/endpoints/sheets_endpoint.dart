import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';
import '../../platform/users/user_service.dart';
import '../sheets_service.dart';
import '../spaces/space_service.dart';

/// Online-only Sheets operations (suite 12 §2, Sheets 10, 12 §2.5).
class SheetsEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Reserves up to [count] (≤ 5) empty spaces for offline creation.
  Future<List<UuidValue>> reserveSpaces(Session session, int count) async =>
      SpaceService.reserveSpaces(session, await UserService.actorOf(session), count);

  /// Grants membership of the spreadsheet's space (role mirrored from the
  /// ACL) and adds it to the caller's active set.
  Future<SubscribeResult> subscribe(Session session, UuidValue itemUuid) async =>
      SpaceService.subscribe(session, await UserService.actorOf(session), itemUuid);

  Future<void> unsubscribe(Session session, UuidValue itemUuid) async =>
      SpaceService.unsubscribe(session, await UserService.actorOf(session), itemUuid);

  /// Pending-change guard: re-grants spaces with unsynced local changes.
  Future<List<UuidValue>> ensureSubscribed(
    Session session,
    List<UuidValue> spaces,
  ) async => SpaceService.ensureSubscribed(
    session,
    await UserService.actorOf(session),
    spaces,
  );

  /// Row counts for download progress.
  Future<SpaceStats> spaceStats(Session session, UuidValue itemUuid) async =>
      SpaceService.statsFor(session, await UserService.actorOf(session), itemUuid);

  /// Undo of a server-side change (`sheets.serverChange`).
  Future<RevertResult> revertChange(Session session, UuidValue changeId) async =>
      SheetsService.revertChange(session, await UserService.actorOf(session), changeId);

  /// Redo of a reverted server-side change ([changeId] of the original or of
  /// its revert).
  Future<RevertResult> reapplyChange(Session session, UuidValue changeId) async =>
      SheetsService.reapplyChange(session, await UserService.actorOf(session), changeId);

  Future<CellHistoryPage> cellHistory(
    Session session,
    UuidValue spreadsheetUuid,
    UuidValue sheetId,
    UuidValue rowId,
    UuidValue colId,
    String? cursor,
  ) async => SheetsService.cellHistory(
    session,
    await UserService.actorOf(session),
    spreadsheetUuid,
    sheetId,
    rowId,
    colId,
    cursor: cursor,
  );

  Future<SheetsActivitySummary> activitySummary(
    Session session,
    UuidValue spreadsheetUuid,
    int days,
  ) async => SheetsService.activitySummary(
    session,
    await UserService.actorOf(session),
    spreadsheetUuid,
    days,
  );
}
