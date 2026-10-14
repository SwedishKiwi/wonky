import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart'
    show UuidValue;

import '../generated/protocol.dart';

/// Generic access to one synced table by name: converts between the generated
/// ORM class and the plain column maps the workbook model and `RowChange`s
/// use (Sheets 02 §6, `wonky_sheets_core` `schema.dart`), and runs typed ORM
/// calls without knowing the class at the call site.
///
/// Column maps hold UUIDs as canonical strings, enums by name, `DateTime`s
/// (UTC) and plain `double`/`int`/`bool`/`String` values. They never contain
/// the engine-managed `spaceId`.
///
/// **Writes always name their columns** (suite 12 §2.1): [updateColumns]
/// passes exactly the given columns as `columnValues`; there is no whole-row
/// update here on purpose.
final class SyncedTableSpec<T extends TableRow<UuidValue>> {
  const SyncedTableSpec._(this.table, this._fromJson);

  /// The generated table.
  final Table<UuidValue> table;
  final T Function(Map<String, dynamic> json) _fromJson;

  /// Table name (`cell`, `sheet_row`, …).
  String get name => table.tableName;

  /// The id column.
  ColumnUuid get idColumn => table.id as ColumnUuid;

  /// The column named [name], or null.
  Column<dynamic>? column(String name) {
    for (final c in table.columns) {
      if (c.columnName == name) return c;
    }
    return null;
  }

  /// The engine-managed space column, excluded from column maps.
  static const spaceIdColumn = 'spaceId';

  /// Column map of [row] (every column, nulls included).
  Map<String, Object?> toColumns(TableRow<dynamic> row) {
    final json = (row.toJson() as Map).cast<String, Object?>();
    return {
      for (final c in table.columns)
        if (c.columnName != spaceIdColumn)
          c.columnName: _fromJsonValue(c, json[c.columnName]),
    };
  }

  /// An ORM object from a column map (missing columns take the model
  /// defaults).
  T fromColumns(Map<String, Object?> columns) => _fromJson({
    for (final e in columns.entries)
      if (e.key != spaceIdColumn) e.key: _toJsonValue(e.value),
  });

  /// `columnValues` for an update of exactly [columns] (`id`/`spaceId`
  /// skipped). Throws [ArgumentError] for unknown columns.
  List<ColumnValue<dynamic, dynamic>> columnValues(Map<String, Object?> columns) => [
    for (final e in columns.entries)
      if (e.key != 'id' && e.key != spaceIdColumn)
        () {
          final c =
              column(e.key) ??
              (throw ArgumentError.value(e.key, 'column', 'Unknown in $name'));
          return ColumnValue(c, toDatabaseValue(c, e.value));
        }(),
  ];

  /// Rows with [ids] visible to [session] (chunked `IN` lists).
  Future<List<T>> findByIds(
    DatabaseSession session,
    Iterable<UuidValue> ids, {
    Transaction? transaction,
  }) async {
    final all = ids.toSet().toList();
    final out = <T>[];
    for (var i = 0; i < all.length; i += chunk) {
      final part = all.sublist(
        i,
        i + chunk > all.length ? all.length : i + chunk,
      );
      out.addAll(
        await session.db.find<T>(
          where: idColumn.inSet(part.toSet()),
          transaction: transaction,
        ),
      );
    }
    return out;
  }

  /// Rows matching [where], ordered by id (paging with [limit]/[offset]).
  Future<List<T>> findWhere(
    DatabaseSession session, {
    Expression<dynamic>? where,
    int? limit,
    int? offset,
    Transaction? transaction,
  }) => session.db.find<T>(
    where: where,
    limit: limit,
    offset: offset,
    orderBy: idColumn,
    transaction: transaction,
  );

  /// Inserts full rows given as column maps (re-inserting a deleted id
  /// revives it).
  Future<void> insertRows(
    DatabaseSession session,
    List<Map<String, Object?>> rows, {
    Transaction? transaction,
  }) async {
    if (rows.isEmpty) return;
    await session.db.insert<T>([
      for (final r in rows) fromColumns(r),
    ], transaction: transaction);
  }

  /// Updates exactly [columns] of row [id]. Returns false when the row is
  /// not visible (deleted meanwhile).
  Future<bool> updateColumns(
    DatabaseSession session,
    UuidValue id,
    Map<String, Object?> columns, {
    Transaction? transaction,
  }) async {
    final values = columnValues(columns);
    if (values.isEmpty) return true;
    final updated = await session.db.updateWhere<T>(
      columnValues: values,
      where: idColumn.equals(id),
      transaction: transaction,
    );
    return updated.isNotEmpty;
  }

  /// Deletes (tombstones) rows with [ids].
  Future<void> deleteByIds(
    DatabaseSession session,
    Iterable<UuidValue> ids, {
    Transaction? transaction,
  }) async {
    final all = ids.toSet().toList();
    for (var i = 0; i < all.length; i += chunk) {
      final part = all.sublist(
        i,
        i + chunk > all.length ? all.length : i + chunk,
      );
      await session.db.deleteWhere<T>(
        where: idColumn.inSet(part.toSet()),
        transaction: transaction,
      );
    }
  }

  /// Max ids per `IN` list.
  static const chunk = 500;

  /// The database value of a column-map [value] for column [c].
  static Object? toDatabaseValue(Column<dynamic> c, Object? value) {
    if (value == null) return null;
    return switch (c) {
      ColumnUuid() =>
        value is UuidValue ? value : UuidValue.fromString('$value'),
      ColumnDateTime() =>
        value is DateTime ? value.toUtc() : DateTime.parse('$value').toUtc(),
      ColumnDouble() => (value as num).toDouble(),
      ColumnInt() => (value as num).toInt(),
      ColumnEnum() => value is Enum ? value.name : '$value',
      _ => value,
    };
  }

  static Object? _toJsonValue(Object? v) => switch (v) {
    DateTime() => v.toUtc().toIso8601String(),
    UuidValue() => v.uuid,
    Enum() => v.name,
    _ => v,
  };

  static Object? _fromJsonValue(Column<dynamic> c, Object? v) {
    if (v == null) return null;
    return switch (c) {
      ColumnDateTime() =>
        v is DateTime ? v.toUtc() : DateTime.parse('$v').toUtc(),
      ColumnUuid() => v is UuidValue ? v.uuid : '$v',
      ColumnDouble() => (v as num).toDouble(),
      _ => v,
    };
  }
}

SyncedTableSpec<T> _spec<T extends TableRow<UuidValue>>(
  Table<UuidValue> table,
  T Function(Map<String, dynamic>) fromJson,
) => SyncedTableSpec<T>._(table, fromJson);

/// All synced tables of Wonky Sheets (`database: sync`), by name, in
/// dependency order (parents first).
abstract final class SyncedTables {
  /// Specs in dependency order (parents first): apply inserts in this order,
  /// deletes in reverse.
  static final List<SyncedTableSpec<TableRow<UuidValue>>> all = [
    _spec<Spreadsheet>(Spreadsheet.t, Spreadsheet.fromJson),
    _spec<Sheet>(Sheet.t, Sheet.fromJson),
    _spec<SheetRow>(SheetRow.t, SheetRow.fromJson),
    _spec<SheetColumn>(SheetColumn.t, SheetColumn.fromJson),
    _spec<Cell>(Cell.t, Cell.fromJson),
    _spec<MergedRange>(MergedRange.t, MergedRange.fromJson),
    _spec<DimensionGroup>(DimensionGroup.t, DimensionGroup.fromJson),
    _spec<NamedRange>(NamedRange.t, NamedRange.fromJson),
    _spec<ProtectedRange>(ProtectedRange.t, ProtectedRange.fromJson),
    _spec<ConditionalFormatRule>(
      ConditionalFormatRule.t,
      ConditionalFormatRule.fromJson,
    ),
    _spec<DataValidationRule>(
      DataValidationRule.t,
      DataValidationRule.fromJson,
    ),
    _spec<BasicFilter>(BasicFilter.t, BasicFilter.fromJson),
    _spec<FilterView>(FilterView.t, FilterView.fromJson),
    _spec<Banding>(Banding.t, Banding.fromJson),
    _spec<EmbeddedObject>(EmbeddedObject.t, EmbeddedObject.fromJson),
    _spec<PivotTable>(PivotTable.t, PivotTable.fromJson),
    _spec<ScriptProject>(ScriptProject.t, ScriptProject.fromJson),
    _spec<ScriptFile>(ScriptFile.t, ScriptFile.fromJson),
    _spec<ScriptBuild>(ScriptBuild.t, ScriptBuild.fromJson),
    _spec<ScriptTrigger>(ScriptTrigger.t, ScriptTrigger.fromJson),
    _spec<Macro>(Macro.t, Macro.fromJson),
    _spec<ScriptProperty>(ScriptProperty.t, ScriptProperty.fromJson),
    _spec<ChangeLog>(ChangeLog.t, ChangeLog.fromJson),
    _spec<ScriptUserProperty>(
      ScriptUserProperty.t,
      ScriptUserProperty.fromJson,
    ),
  ];

  /// Specs by table name.
  static final Map<String, SyncedTableSpec<TableRow<UuidValue>>> byName = {
    for (final s in all) s.name: s,
  };

  /// The spec of [table]; throws for unknown tables.
  static SyncedTableSpec<TableRow<UuidValue>> of(String table) =>
      byName[table] ?? (throw ArgumentError.value(table, 'table'));
}
