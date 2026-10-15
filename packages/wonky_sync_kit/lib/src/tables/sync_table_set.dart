import 'package:serverpod_database/serverpod_database.dart' show TableRow;
import 'package:serverpod_serialization/serverpod_serialization.dart'
    show UuidValue;
import 'package:wonky_sync_models/tables.dart';

/// A synced table spec of any table.
typedef AnySyncedTable = SyncedTableSpec<TableRow<UuidValue>>;

/// The synced tables of one app (`database: sync`), in dependency order:
/// Sheets' workbook tables, Slides' deck tables. The shared client pieces
/// (replica, writer, journal, recovery) are table-agnostic and take a set.
final class SyncTableSet {
  /// Creates the set. [all] is in dependency order (parents first): inserts
  /// apply in this order, deletes in reverse. [nonModelTables] are synced
  /// but not part of the in-memory model (change logs, per-user rows): the
  /// replica doesn't load them into a model and the change journal doesn't
  /// track them.
  SyncTableSet(
    List<AnySyncedTable> all, {
    Set<String> nonModelTables = const {},
    this.rootTable,
  }) : all = List.unmodifiable(all),
       byName = Map.unmodifiable({for (final s in all) s.name: s}),
       _ranks = {for (final (i, s) in all.indexed) s.name: i},
       modelTables = List.unmodifiable([
         for (final s in all)
           if (!nonModelTables.contains(s.name)) s,
       ]) {
    final root = rootTable;
    if (root != null && !byName.containsKey(root)) {
      throw ArgumentError.value(root, 'rootTable', 'Not in the set');
    }
  }

  /// Specs in dependency order (parents first).
  final List<AnySyncedTable> all;

  /// Specs by table name.
  final Map<String, AnySyncedTable> byName;

  /// The tables loaded into an in-memory model, in dependency order.
  final List<AnySyncedTable> modelTables;

  /// The table whose row id is the space id (`spreadsheet`, `deck`): its
  /// row marks a file as present on the device.
  final String? rootTable;

  /// Names of [modelTables].
  Set<String> get modelTableNames => {for (final s in modelTables) s.name};

  /// The spec of [table]; throws for unknown tables.
  AnySyncedTable of(String table) =>
      byName[table] ?? (throw ArgumentError.value(table, 'table'));

  /// Dependency rank of [table] (unknown tables last).
  int rank(String table) => _ranks[table] ?? all.length;

  final Map<String, int> _ranks;
}
