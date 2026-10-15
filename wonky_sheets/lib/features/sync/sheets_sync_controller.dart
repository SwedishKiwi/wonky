import 'package:clock/clock.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show AppSyncController, DeviceRowCap, SyncConnectivity;

import 'sheets_replica.dart';
import 'sheets_writer.dart';
import 'synced_workbook_session.dart';

export 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show NoReservedSpaceException;

/// Connection state for the controller (the shell's `ConnectivityService`
/// in the app, a plain notifier in tests).
typedef SheetsConnectivity = SyncConnectivity;

/// The signed-in user's Sheets sync (suite 12 §2.5): the shared kit's
/// [AppSyncController] on the replica `sheets_<userId>.db` and the custom
/// `sheetsSync.sync` endpoint, hosting the open [SyncedWorkbookSession]s.
///
/// Adds the cell cap of web devices without OPFS ([cellCap]), offline
/// spreadsheet creation ([createLocalSpreadsheet]) and session opening
/// ([openSession]).
class SheetsSyncController
    extends
        AppSyncController<SheetsReplica, SheetsWriter, SyncedWorkbookSession> {
  SheetsSyncController({
    required super.replica,
    required super.remote,
    required super.connectivity,
    super.sessionId,
    super.reservationTarget,
    super.hiddenGrace,
    this.cellCap,
    super.lastOpened,
    super.maintenanceStore,
    super.random,
  }) : super(
         writer: SheetsWriter(replica),
         name: 'sheets',
         rowCap: cellCap == null
             ? null
             : DeviceRowCap(table: SheetsTables.cell, maxRows: cellCap),
       );

  /// Max cells kept on this device (the IndexedDB fallback of the web,
  /// suite 12 intro; null = unlimited). Above it, the spreadsheets opened
  /// least recently leave the active set ([enforceCellCap]).
  final int? cellCap;

  /// Keeps the device under [cellCap] cells (`enforceRowCap`).
  Future<void> enforceCellCap() => enforceRowCap();

  /// Creates a spreadsheet in a usable reserved space (works offline):
  /// writes the `CreateSpreadsheet` plan (spreadsheet row, one sheet of
  /// 1,000 × 26) and returns the space (= spreadsheet id). Throws
  /// `NoReservedSpaceException` without a usable reservation. Registering
  /// it in the drive is the caller's job (`drive.registerSpreadsheet`).
  Future<UuidValue> createLocalSpreadsheet({
    required String title,
    String locale = 'en_US',
    String timeZone = 'UTC',
    String? fontFamily,
    double? fontSize,
  }) => createInReservedSpace((space) async {
    final model = WorkbookModel(spreadsheetId: space.uuid);
    final plan = const SheetsMutationPlanner().plan(
      CreateSpreadsheet(
        spreadsheetId: space.uuid,
        title: title,
        locale: locale,
        timeZone: timeZone,
        fontFamily: fontFamily,
        fontSize: fontSize,
      ),
      model,
      PlanContext(userId: replica.userUuid.uuid, now: clock.now().toUtc()),
    );
    await writer.write(
      spaceId: space,
      changes: plan.changes,
      plan: plan,
      label: plan.label,
      actorKind: 'user',
      sessionId: sessionId,
    );
  });

  /// Opens a session on [spaceUuid] (see [SyncedWorkbookSession.open]).
  SyncedWorkbookSession openSession({
    required UuidValue itemUuid,
    required UuidValue spaceUuid,
    Role role = Role.viewer,
    int maxCells = 1000000,
    ViewportHint? viewport,
  }) => registerSession(
    SyncedWorkbookSession.open(
      this,
      itemUuid: itemUuid,
      spaceUuid: spaceUuid,
      role: role,
      maxCells: maxCells,
      viewport: viewport,
    ),
  );
}
