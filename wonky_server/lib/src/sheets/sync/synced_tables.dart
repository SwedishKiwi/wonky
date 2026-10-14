import 'package:serverpod/serverpod.dart';
import 'package:wonky_sync_models/tables.dart';

/// Generic access to the synced Sheets tables by name (server writes that
/// apply `RowChange`s, snapshots and restores): a thin adapter over the
/// shared codec `package:wonky_sync_models/tables.dart` that the app's
/// `SheetsWriter` uses too (typed ORM calls without knowing the class at
/// the call site).
class SyncedTable {
  const SyncedTable(this.spec);

  final SyncedTableSpec<TableRow<UuidValue>> spec;

  String get name => spec.name;
  Table get table => spec.table;

  /// The ORM object of a JSON map (`toJson` shape: UUIDs and times as
  /// strings).
  TableRow fromJson(Map<String, dynamic> json) => spec.fromColumns(json);

  /// Admin read (hides deleted rows) of the rows with [ids].
  Future<List<TableRow>> findByIds(
    DatabaseSession db,
    Set<UuidValue> ids, {
    Transaction? transaction,
  }) => ids.isEmpty
      ? Future.value(const [])
      : spec.findByIds(db, ids, transaction: transaction);

  /// The column named [name], or null.
  Column? column(String name) => spec.column(name);
}

/// All synced tables by name, in dependency order (parents first).
final Map<String, SyncedTable> syncedTablesByName = {
  for (final s in SyncedTables.all) s.name: SyncedTable(s),
};

SyncedTableSpec<TableRow<UuidValue>> _specOf(TableRow row) {
  final spec = SyncedTables.byName[row.table.tableName];
  if (spec == null) {
    throw ArgumentError('Not a synced table row: ${row.runtimeType}');
  }
  return spec;
}

/// Deletes a synced row with its concrete type, so the offline-sync
/// database records the CRDT tombstone (a `deleteRow` call typed as plain
/// [TableRow] is not CRDT-tracked and fails).
Future<void> deleteSyncedRow(
  DatabaseSession db,
  TableRow row, {
  Transaction? transaction,
}) => _specOf(
  row,
).deleteByIds(db, [row.id as UuidValue], transaction: transaction);

/// Updates [columns] of a synced row with its concrete type (CRDT-tracked
/// field writes naming exactly those columns; see [deleteSyncedRow]).
Future<void> updateSyncedRow(
  DatabaseSession db,
  TableRow row, {
  required List<Column> columns,
  Transaction? transaction,
}) async {
  final spec = _specOf(row);
  final all = spec.toColumns(row);
  await spec.updateColumns(db, row.id as UuidValue, {
    for (final c in columns) c.columnName: all[c.columnName],
  }, transaction: transaction);
}

/// Deletes the rows [ids] of the synced table [table] in CRDT-tracked
/// statements (typed like [deleteSyncedRow]).
Future<void> deleteSyncedRows(
  DatabaseSession db,
  String table,
  Set<UuidValue> ids, {
  Transaction? transaction,
}) async {
  if (ids.isEmpty) return;
  final spec = SyncedTables.byName[table];
  if (spec == null) throw ArgumentError('Not a synced table: $table');
  await spec.deleteByIds(db, ids, transaction: transaction);
}
