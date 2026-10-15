import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';
import '../../platform/users/user_service.dart';
import '../images/sheets_image_proxy.dart';
import '../sheets_service.dart';
import '../spaces/sheets_spaces.dart';

/// Online-only Sheets operations (suite 12 §2, Sheets 10, 12 §2.5).
class SheetsEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Reserves up to [count] (≤ 5) empty spaces for offline creation.
  Future<List<UuidValue>> reserveSpaces(Session session, int count) async =>
      SheetsSpaces.reserveSpaces(
        session,
        await UserService.actorOf(session),
        count,
      );

  /// Grants membership of the spreadsheet's space (role mirrored from the
  /// ACL) and adds it to the caller's active set.
  Future<SubscribeResult> subscribe(
    Session session,
    UuidValue itemUuid,
  ) async => SheetsSpaces.subscribe(
    session,
    await UserService.actorOf(session),
    itemUuid,
  );

  Future<void> unsubscribe(Session session, UuidValue itemUuid) async =>
      SheetsSpaces.unsubscribe(
        session,
        await UserService.actorOf(session),
        itemUuid,
      );

  /// Pending-change guard: re-grants spaces with unsynced local changes.
  Future<List<UuidValue>> ensureSubscribed(
    Session session,
    List<UuidValue> spaces,
  ) async => SheetsSpaces.ensureSubscribed(
    session,
    await UserService.actorOf(session),
    spaces,
  );

  /// Row counts for download progress.
  Future<SpaceStats> spaceStats(Session session, UuidValue itemUuid) async =>
      SheetsSpaces.statsFor(
        session,
        await UserService.actorOf(session),
        itemUuid,
      );

  /// Named functions of another spreadsheet for *Import function*
  /// (Sheets 07 §9.4): JSON list of `{name, formula, comment, metaJson}`.
  Future<String> namedFunctions(Session session, UuidValue itemUuid) async =>
      SheetsService.namedFunctions(
        session,
        await UserService.actorOf(session),
        itemUuid,
      );

  /// The theme JSON of another spreadsheet for *Import theme* (Sheets 06
  /// §13).
  Future<String> spreadsheetTheme(Session session, UuidValue itemUuid) async =>
      SheetsService.spreadsheetTheme(
        session,
        await UserService.actorOf(session),
        itemUuid,
      );

  /// Undo of a server-side change (`sheets.serverChange`).
  Future<RevertResult> revertChange(
    Session session,
    UuidValue changeId,
  ) async => SheetsService.revertChange(
    session,
    await UserService.actorOf(session),
    changeId,
  );

  /// Redo of a reverted server-side change ([changeId] of the original or of
  /// its revert).
  Future<RevertResult> reapplyChange(
    Session session,
    UuidValue changeId,
  ) async => SheetsService.reapplyChange(
    session,
    await UserService.actorOf(session),
    changeId,
  );

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

  /// Image proxy for `IMAGE("https://…")` cells and images inserted by URL
  /// (08 §10): the bytes of the https image [url] (private addresses are
  /// refused).
  Future<ByteData> fetchImage(
    Session session,
    UuidValue itemUuid,
    String url,
  ) async => SheetsImageProxy.fetch(
    session,
    await UserService.actorOf(session),
    itemUuid,
    url,
  );
}
