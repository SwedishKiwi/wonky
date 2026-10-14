/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:serverpod_database/serverpod_database.dart' as _isd;

/// Local change journal of the Sheets replica (suite 12 §4 U11): SQLite
/// triggers on the synced tables and on `crdt_data_rows` append the
/// (table, row) of every write in a journaled space, so an open spreadsheet
/// patches its in-memory model with only the rows a merge touched.
/// Client-only; never synced. Pruned by the app.
abstract class SheetsRowJournal
    implements _isd.TableRow<int?>, _isc.ProtocolSerialization {
  SheetsRowJournal._({
    this.id,
    required this.spaceKey,
    required this.syncTable,
    required this.rowId,
  });

  factory SheetsRowJournal({
    int? id,
    required int spaceKey,
    required String syncTable,
    required _isc.UuidValue rowId,
  }) = _SheetsRowJournalImpl;

  factory SheetsRowJournal.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsRowJournal(
      id: jsonSerialization['id'] as int?,
      spaceKey: jsonSerialization['spaceKey'] as int,
      syncTable: jsonSerialization['syncTable'] as String,
      rowId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['rowId']),
    );
  }

  static final t = SheetsRowJournalTable();

  static const db = SheetsRowJournalRepository._();

  @override
  int? id;

  /// `offline_sync_spaces.id` (local integer id) of the row's space.
  int spaceKey;

  /// Synced table name (`cell`, `sheet_row`, …).
  String syncTable;

  _isc.UuidValue rowId;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [SheetsRowJournal]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SheetsRowJournal copyWith({
    int? id,
    int? spaceKey,
    String? syncTable,
    _isc.UuidValue? rowId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsRowJournal',
      if (id != null) 'id': id,
      'spaceKey': spaceKey,
      'syncTable': syncTable,
      'rowId': rowId.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsRowJournal',
      if (id != null) 'id': id,
      'spaceKey': spaceKey,
      'syncTable': syncTable,
      'rowId': rowId.toJson(),
    };
  }

  static SheetsRowJournalInclude include() {
    return SheetsRowJournalInclude._();
  }

  static SheetsRowJournalIncludeList includeList({
    _isd.WhereExpressionBuilder<SheetsRowJournalTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsRowJournalTable>? orderBy,
    _isd.OrderByListBuilder<SheetsRowJournalTable>? orderByList,
    SheetsRowJournalInclude? include,
  }) {
    return SheetsRowJournalIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetsRowJournal.t),
      orderByList: orderByList?.call(SheetsRowJournal.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsRowJournalImpl extends SheetsRowJournal {
  _SheetsRowJournalImpl({
    int? id,
    required int spaceKey,
    required String syncTable,
    required _isc.UuidValue rowId,
  }) : super._(
         id: id,
         spaceKey: spaceKey,
         syncTable: syncTable,
         rowId: rowId,
       );

  /// Returns a shallow copy of this [SheetsRowJournal]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SheetsRowJournal copyWith({
    Object? id = _Undefined,
    int? spaceKey,
    String? syncTable,
    _isc.UuidValue? rowId,
  }) {
    return SheetsRowJournal(
      id: id is int? ? id : this.id,
      spaceKey: spaceKey ?? this.spaceKey,
      syncTable: syncTable ?? this.syncTable,
      rowId: rowId ?? this.rowId,
    );
  }
}

class SheetsRowJournalUpdateTable
    extends _isd.UpdateTable<SheetsRowJournalTable> {
  SheetsRowJournalUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceKey(int value) => _isd.ColumnValue(
    table.spaceKey,
    value,
  );

  _isd.ColumnValue<String, String> syncTable(String value) => _isd.ColumnValue(
    table.syncTable,
    value,
  );

  _isd.ColumnValue<_isc.UuidValue, _isc.UuidValue> rowId(
    _isc.UuidValue value,
  ) => _isd.ColumnValue(
    table.rowId,
    value,
  );
}

class SheetsRowJournalTable extends _isd.Table<int?> {
  SheetsRowJournalTable({super.tableRelation})
    : super(tableName: 'sheets_row_journal') {
    updateTable = SheetsRowJournalUpdateTable(this);
    spaceKey = _isd.ColumnInt(
      'spaceKey',
      this,
    );
    syncTable = _isd.ColumnString(
      'syncTable',
      this,
    );
    rowId = _isd.ColumnUuid(
      'rowId',
      this,
    );
  }

  late final SheetsRowJournalUpdateTable updateTable;

  /// `offline_sync_spaces.id` (local integer id) of the row's space.
  late final _isd.ColumnInt spaceKey;

  /// Synced table name (`cell`, `sheet_row`, …).
  late final _isd.ColumnString syncTable;

  late final _isd.ColumnUuid rowId;

  @override
  List<_isd.Column> get columns => [
    id,
    spaceKey,
    syncTable,
    rowId,
  ];
}

class SheetsRowJournalInclude extends _isd.IncludeObject {
  SheetsRowJournalInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<int?> get table => SheetsRowJournal.t;
}

class SheetsRowJournalIncludeList extends _isd.IncludeList {
  SheetsRowJournalIncludeList._({
    _isd.WhereExpressionBuilder<SheetsRowJournalTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SheetsRowJournal.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => SheetsRowJournal.t;
}

class SheetsRowJournalRepository {
  const SheetsRowJournalRepository._();

  /// Returns a list of [SheetsRowJournal]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<SheetsRowJournal>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsRowJournalTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsRowJournalTable>? orderBy,
    _isd.OrderByListBuilder<SheetsRowJournalTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SheetsRowJournal>(
      where: where?.call(SheetsRowJournal.t),
      orderBy: orderBy?.call(SheetsRowJournal.t),
      orderByList: orderByList?.call(SheetsRowJournal.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SheetsRowJournal]s matching the given query parameters every time the
  /// source tables are modified.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// Use [throttle] to specify the minimum interval between queries. It can
  /// also be set to `null`, in which case the stream will only be throttled
  /// when its subscription is paused.
  ///
  /// Source tables are collected from the queried table, [where], [orderBy],
  /// [orderByList], and the [include] graph. [alsoTriggerOnTables] is added
  /// to that set. Pass [Table] instances such as `SheetsRowJournal.t`.
  ///
  /// Raw [Expression] SQL is not inspected. Tables referenced only in raw
  /// SQL must be passed via [alsoTriggerOnTables].
  ///
  /// The stream always reads committed state and never joins an ambient
  /// [Transaction]. Emissions for a write fire after that write commits.
  ///
  /// Currently only supported on SQLite. Calling this method on PostgreSQL
  /// throws an [UnsupportedError].
  ///
  /// ```dart
  /// var subscription = Persons.db.watch(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// ).listen((persons) {
  ///   // Handle the latest matching rows.
  /// });
  /// ```
  _ida.Stream<List<SheetsRowJournal>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsRowJournalTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsRowJournalTable>? orderBy,
    _isd.OrderByListBuilder<SheetsRowJournalTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SheetsRowJournal>(
      where: where?.call(SheetsRowJournal.t),
      orderBy: orderBy?.call(SheetsRowJournal.t),
      orderByList: orderByList?.call(SheetsRowJournal.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SheetsRowJournal] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<SheetsRowJournal?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsRowJournalTable>? where,
    int? offset,
    _isd.OrderByBuilder<SheetsRowJournalTable>? orderBy,
    _isd.OrderByListBuilder<SheetsRowJournalTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SheetsRowJournal>(
      where: where?.call(SheetsRowJournal.t),
      orderBy: orderBy?.call(SheetsRowJournal.t),
      orderByList: orderByList?.call(SheetsRowJournal.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SheetsRowJournal] by its [id] or null if no such row exists.
  Future<SheetsRowJournal?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SheetsRowJournal>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SheetsRowJournal]s in the list and returns the inserted rows.
  ///
  /// The returned [SheetsRowJournal]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsRowJournal>> insert(
    _isd.DatabaseSession session,
    List<SheetsRowJournal> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SheetsRowJournal>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SheetsRowJournal] and returns the inserted row.
  ///
  /// The returned [SheetsRowJournal] will have its `id` field set.
  Future<SheetsRowJournal> insertRow(
    _isd.DatabaseSession session,
    SheetsRowJournal row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SheetsRowJournal>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SheetsRowJournal]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [SheetsRowJournal]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsRowJournal>> upsert(
    _isd.DatabaseSession session,
    List<SheetsRowJournal> rows, {
    required _isd.ColumnSelections<SheetsRowJournalTable> conflictColumns,
    _isd.ColumnSelections<SheetsRowJournalTable>? updateColumns,
    _isd.WhereExpressionBuilder<SheetsRowJournalTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SheetsRowJournal>(
      rows,
      conflictColumns: conflictColumns(SheetsRowJournal.t),
      updateColumns: updateColumns?.call(SheetsRowJournal.t),
      updateWhere: updateWhere?.call(SheetsRowJournal.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SheetsRowJournal] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [SheetsRowJournal] will have its `id` field set.
  Future<SheetsRowJournal?> upsertRow(
    _isd.DatabaseSession session,
    SheetsRowJournal row, {
    required _isd.ColumnSelections<SheetsRowJournalTable> conflictColumns,
    _isd.ColumnSelections<SheetsRowJournalTable>? updateColumns,
    _isd.WhereExpressionBuilder<SheetsRowJournalTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SheetsRowJournal>(
      row,
      conflictColumns: conflictColumns(SheetsRowJournal.t),
      updateColumns: updateColumns?.call(SheetsRowJournal.t),
      updateWhere: updateWhere?.call(SheetsRowJournal.t),
      transaction: transaction,
    );
  }

  /// Updates all [SheetsRowJournal]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsRowJournal>> update(
    _isd.DatabaseSession session,
    List<SheetsRowJournal> rows, {
    _isd.ColumnSelections<SheetsRowJournalTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SheetsRowJournal>(
      rows,
      columns: columns?.call(SheetsRowJournal.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SheetsRowJournal]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SheetsRowJournal> updateRow(
    _isd.DatabaseSession session,
    SheetsRowJournal row, {
    _isd.ColumnSelections<SheetsRowJournalTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SheetsRowJournal>(
      row,
      columns: columns?.call(SheetsRowJournal.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SheetsRowJournal] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SheetsRowJournal?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<SheetsRowJournalUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SheetsRowJournal>(
      id,
      columnValues: columnValues(SheetsRowJournal.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SheetsRowJournal]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsRowJournal>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SheetsRowJournalUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<SheetsRowJournalTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsRowJournalTable>? orderBy,
    _isd.OrderByListBuilder<SheetsRowJournalTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SheetsRowJournal>(
      columnValues: columnValues(SheetsRowJournal.t.updateTable),
      where: where(SheetsRowJournal.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetsRowJournal.t),
      orderByList: orderByList?.call(SheetsRowJournal.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SheetsRowJournal]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsRowJournal>> delete(
    _isd.DatabaseSession session,
    List<SheetsRowJournal> rows, {
    _isd.OrderByBuilder<SheetsRowJournalTable>? orderBy,
    _isd.OrderByListBuilder<SheetsRowJournalTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SheetsRowJournal>(
      rows,
      orderBy: orderBy?.call(SheetsRowJournal.t),
      orderByList: orderByList?.call(SheetsRowJournal.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SheetsRowJournal].
  Future<SheetsRowJournal> deleteRow(
    _isd.DatabaseSession session,
    SheetsRowJournal row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SheetsRowJournal>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsRowJournal>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SheetsRowJournalTable> where,
    _isd.OrderByBuilder<SheetsRowJournalTable>? orderBy,
    _isd.OrderByListBuilder<SheetsRowJournalTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SheetsRowJournal>(
      where: where(SheetsRowJournal.t),
      orderBy: orderBy?.call(SheetsRowJournal.t),
      orderByList: orderByList?.call(SheetsRowJournal.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsRowJournalTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SheetsRowJournal>(
      where: where?.call(SheetsRowJournal.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SheetsRowJournal] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SheetsRowJournalTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SheetsRowJournal>(
      where: where(SheetsRowJournal.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
