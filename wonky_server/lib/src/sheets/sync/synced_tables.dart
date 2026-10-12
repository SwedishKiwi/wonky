import 'package:serverpod/serverpod.dart';
import 'package:wonky_sheets_core/model.dart' show SheetsTables;

import '../../platform/common/models.dart';

/// Generic access to the synced Sheets tables by name (server writes that
/// apply `RowChange`s, snapshots and restores).
class SyncedTable {
  const SyncedTable(this.name, this.table, this.fromJson, this.findByIds);

  final String name;
  final Table table;
  final TableRow Function(Map<String, dynamic> json) fromJson;

  /// Admin read (hides deleted rows) of the rows with [ids].
  final Future<List<TableRow>> Function(DatabaseSession db, Set<UuidValue> ids)
  findByIds;

  /// The column named [name], or null.
  Column? column(String name) =>
      table.columns.where((c) => c.columnName == name).firstOrNull;
}

Future<List<TableRow>> _find<T extends TableRow>(
  DatabaseSession db,
  Table table,
  Set<UuidValue> ids,
) async {
  if (ids.isEmpty) return const [];
  final idColumn = table.id as ColumnUuid;
  return db.db.find<T>(where: idColumn.inSet(ids));
}

/// All synced tables by name, in dependency order (parents first).
final Map<String, SyncedTable> syncedTablesByName = {
  for (final t in <SyncedTable>[
    SyncedTable(
      SheetsTables.spreadsheet,
      Spreadsheet.t,
      Spreadsheet.fromJson,
      (db, ids) => _find<Spreadsheet>(db, Spreadsheet.t, ids),
    ),
    SyncedTable(
      SheetsTables.sheet,
      Sheet.t,
      Sheet.fromJson,
      (db, ids) => _find<Sheet>(db, Sheet.t, ids),
    ),
    SyncedTable(
      SheetsTables.sheetRow,
      SheetRow.t,
      SheetRow.fromJson,
      (db, ids) => _find<SheetRow>(db, SheetRow.t, ids),
    ),
    SyncedTable(
      SheetsTables.sheetColumn,
      SheetColumn.t,
      SheetColumn.fromJson,
      (db, ids) => _find<SheetColumn>(db, SheetColumn.t, ids),
    ),
    SyncedTable(
      SheetsTables.cell,
      Cell.t,
      Cell.fromJson,
      (db, ids) => _find<Cell>(db, Cell.t, ids),
    ),
    SyncedTable(
      SheetsTables.mergedRange,
      MergedRange.t,
      MergedRange.fromJson,
      (db, ids) => _find<MergedRange>(db, MergedRange.t, ids),
    ),
    SyncedTable(
      SheetsTables.dimensionGroup,
      DimensionGroup.t,
      DimensionGroup.fromJson,
      (db, ids) => _find<DimensionGroup>(db, DimensionGroup.t, ids),
    ),
    SyncedTable(
      SheetsTables.namedRange,
      NamedRange.t,
      NamedRange.fromJson,
      (db, ids) => _find<NamedRange>(db, NamedRange.t, ids),
    ),
    SyncedTable(
      SheetsTables.protectedRange,
      ProtectedRange.t,
      ProtectedRange.fromJson,
      (db, ids) => _find<ProtectedRange>(db, ProtectedRange.t, ids),
    ),
    SyncedTable(
      SheetsTables.conditionalFormatRule,
      ConditionalFormatRule.t,
      ConditionalFormatRule.fromJson,
      (db, ids) =>
          _find<ConditionalFormatRule>(db, ConditionalFormatRule.t, ids),
    ),
    SyncedTable(
      SheetsTables.dataValidationRule,
      DataValidationRule.t,
      DataValidationRule.fromJson,
      (db, ids) => _find<DataValidationRule>(db, DataValidationRule.t, ids),
    ),
    SyncedTable(
      SheetsTables.basicFilter,
      BasicFilter.t,
      BasicFilter.fromJson,
      (db, ids) => _find<BasicFilter>(db, BasicFilter.t, ids),
    ),
    SyncedTable(
      SheetsTables.filterView,
      FilterView.t,
      FilterView.fromJson,
      (db, ids) => _find<FilterView>(db, FilterView.t, ids),
    ),
    SyncedTable(
      SheetsTables.banding,
      Banding.t,
      Banding.fromJson,
      (db, ids) => _find<Banding>(db, Banding.t, ids),
    ),
    SyncedTable(
      SheetsTables.embeddedObject,
      EmbeddedObject.t,
      EmbeddedObject.fromJson,
      (db, ids) => _find<EmbeddedObject>(db, EmbeddedObject.t, ids),
    ),
    SyncedTable(
      SheetsTables.pivotTable,
      PivotTable.t,
      PivotTable.fromJson,
      (db, ids) => _find<PivotTable>(db, PivotTable.t, ids),
    ),
    SyncedTable(
      SheetsTables.scriptProject,
      ScriptProject.t,
      ScriptProject.fromJson,
      (db, ids) => _find<ScriptProject>(db, ScriptProject.t, ids),
    ),
    SyncedTable(
      SheetsTables.scriptFile,
      ScriptFile.t,
      ScriptFile.fromJson,
      (db, ids) => _find<ScriptFile>(db, ScriptFile.t, ids),
    ),
    SyncedTable(
      SheetsTables.scriptBuild,
      ScriptBuild.t,
      ScriptBuild.fromJson,
      (db, ids) => _find<ScriptBuild>(db, ScriptBuild.t, ids),
    ),
    SyncedTable(
      SheetsTables.scriptTrigger,
      ScriptTrigger.t,
      ScriptTrigger.fromJson,
      (db, ids) => _find<ScriptTrigger>(db, ScriptTrigger.t, ids),
    ),
    SyncedTable(
      SheetsTables.macro,
      Macro.t,
      Macro.fromJson,
      (db, ids) => _find<Macro>(db, Macro.t, ids),
    ),
    SyncedTable(
      SheetsTables.scriptProperty,
      ScriptProperty.t,
      ScriptProperty.fromJson,
      (db, ids) => _find<ScriptProperty>(db, ScriptProperty.t, ids),
    ),
    SyncedTable(
      SheetsTables.changeLog,
      ChangeLog.t,
      ChangeLog.fromJson,
      (db, ids) => _find<ChangeLog>(db, ChangeLog.t, ids),
    ),
  ])
    t.name: t,
};
