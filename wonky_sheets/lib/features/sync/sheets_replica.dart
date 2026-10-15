import 'package:serverpod_database/serverpod_database.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sheets_core/model.dart' show SheetsTables;
import 'package:wonky_sync_kit/tables.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart';
import 'package:wonky_sync_models/tables.dart';

/// Opens the local database of a user (tests pass their own opener).
typedef SheetsReplicaOpener = Future<SheetsReplica> Function(UuidValue user);

/// The change journal of the Sheets replica (suite 12 §4 U11): the shared
/// kit's [ChangeJournal] over the model tables.
typedef SheetsChangeJournal = ChangeJournal;

/// The signed-in user's Sheets replica: `sheets_<userId>.db`, the synced
/// tables plus the local-only tables (`ReservedSpace`, `SheetsDirtySpace`,
/// the change journal), suite 12 §2 and Sheets 02 §4.
///
/// The shared kit's [SyncReplica] over the Sheets tables, plus the cell reads
/// of viewport-first loading. Pure Dart (no Flutter): the app's
/// `SheetsSyncController` owns one, and tests open one on a temporary file.
class SheetsReplica extends SyncReplica {
  SheetsReplica(super.session, {required super.userUuid})
    : super(tables: sheetsTables);

  /// Opens (creating and migrating) the replica at [path].
  static Future<SheetsReplica> open({
    required Client client,
    required String path,
    required UuidValue userUuid,
    bool isDebugMode = false,
  }) async {
    final session = await SyncReplica.openSession(
      client: client,
      path: path,
      userUuid: userUuid,
      isDebugMode: isDebugMode,
    );
    final replica = SheetsReplica(session, userUuid: userUuid);
    await replica.prepare();
    return replica;
  }

  /// The synced tables of Wonky Sheets. The change log and per-user script
  /// properties are not part of the workbook model; a spreadsheet's root
  /// row is its `spreadsheet` row.
  static final SyncTableSet sheetsTables = SyncTableSet(
    SyncedTables.all,
    nonModelTables: const {'change_log', 'script_user_property'},
    rootTable: SheetsTables.spreadsheet,
  );

  /// `sheets_<userId>.db`.
  static String fileNameFor(String userUuid) =>
      SyncReplica.fileName('sheets', userUuid);

  /// Tables loaded into a workbook model.
  static List<AnySyncedTable> get modelTables => sheetsTables.modelTables;

  /// Whether the spreadsheet row of [space] is on the device.
  Future<bool> hasSpreadsheet(UuidValue space) => hasRoot(space);

  /// Visible cells per space on this device (the IndexedDB cell cap, suite
  /// 12 intro).
  Future<Map<UuidValue, int>> cellCountsBySpace() =>
      rowCountsBySpace(SheetsTables.cell);

  /// Max row ids per [loadCells] query.
  static const cellQueryRows = 500;

  /// The cells of the rows [rowIds] of sheet [sheetId] (column maps), read
  /// through the `(sheetId, rowId)` index in queries of [cellQueryRows]
  /// rows.
  Future<List<Map<String, Object?>>> loadCells(
    String sheetId,
    List<String> rowIds,
  ) async {
    final spec = SyncedTables.of(SheetsTables.cell);
    final sheetColumn = spec.column('sheetId')! as ColumnUuid;
    final rowColumn = spec.column('rowId')! as ColumnUuid;
    final sheet = UuidValue.fromString(sheetId);
    final out = <Map<String, Object?>>[];
    for (var i = 0; i < rowIds.length; i += cellQueryRows) {
      final end = i + cellQueryRows > rowIds.length
          ? rowIds.length
          : i + cellQueryRows;
      final rows = await session.db.find<Cell>(
        where:
            sheetColumn.equals(sheet) &
            rowColumn.inSet({
              for (final id in rowIds.sublist(i, end)) UuidValue.fromString(id),
            }),
      );
      for (final r in rows) {
        out.add(spec.toColumns(r));
      }
    }
    return out;
  }
}
