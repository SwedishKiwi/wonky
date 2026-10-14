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

/// Spaces whose writes are journaled in [SheetsRowJournal] (the spreadsheets
/// open on this device). Client-only; never synced.
abstract class SheetsJournalSpace
    implements _isd.TableRow<int?>, _isc.ProtocolSerialization {
  SheetsJournalSpace._({
    this.id,
    required this.spaceKey,
  });

  factory SheetsJournalSpace({
    int? id,
    required int spaceKey,
  }) = _SheetsJournalSpaceImpl;

  factory SheetsJournalSpace.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsJournalSpace(
      id: jsonSerialization['id'] as int?,
      spaceKey: jsonSerialization['spaceKey'] as int,
    );
  }

  static final t = SheetsJournalSpaceTable();

  static const db = SheetsJournalSpaceRepository._();

  @override
  int? id;

  /// `offline_sync_spaces.id` (local integer id).
  int spaceKey;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [SheetsJournalSpace]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SheetsJournalSpace copyWith({
    int? id,
    int? spaceKey,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsJournalSpace',
      if (id != null) 'id': id,
      'spaceKey': spaceKey,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsJournalSpace',
      if (id != null) 'id': id,
      'spaceKey': spaceKey,
    };
  }

  static SheetsJournalSpaceInclude include() {
    return SheetsJournalSpaceInclude._();
  }

  static SheetsJournalSpaceIncludeList includeList({
    _isd.WhereExpressionBuilder<SheetsJournalSpaceTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsJournalSpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsJournalSpaceTable>? orderByList,
    SheetsJournalSpaceInclude? include,
  }) {
    return SheetsJournalSpaceIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetsJournalSpace.t),
      orderByList: orderByList?.call(SheetsJournalSpace.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsJournalSpaceImpl extends SheetsJournalSpace {
  _SheetsJournalSpaceImpl({
    int? id,
    required int spaceKey,
  }) : super._(
         id: id,
         spaceKey: spaceKey,
       );

  /// Returns a shallow copy of this [SheetsJournalSpace]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SheetsJournalSpace copyWith({
    Object? id = _Undefined,
    int? spaceKey,
  }) {
    return SheetsJournalSpace(
      id: id is int? ? id : this.id,
      spaceKey: spaceKey ?? this.spaceKey,
    );
  }
}

class SheetsJournalSpaceUpdateTable
    extends _isd.UpdateTable<SheetsJournalSpaceTable> {
  SheetsJournalSpaceUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceKey(int value) => _isd.ColumnValue(
    table.spaceKey,
    value,
  );
}

class SheetsJournalSpaceTable extends _isd.Table<int?> {
  SheetsJournalSpaceTable({super.tableRelation})
    : super(tableName: 'sheets_journal_space') {
    updateTable = SheetsJournalSpaceUpdateTable(this);
    spaceKey = _isd.ColumnInt(
      'spaceKey',
      this,
    );
  }

  late final SheetsJournalSpaceUpdateTable updateTable;

  /// `offline_sync_spaces.id` (local integer id).
  late final _isd.ColumnInt spaceKey;

  @override
  List<_isd.Column> get columns => [
    id,
    spaceKey,
  ];
}

class SheetsJournalSpaceInclude extends _isd.IncludeObject {
  SheetsJournalSpaceInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<int?> get table => SheetsJournalSpace.t;
}

class SheetsJournalSpaceIncludeList extends _isd.IncludeList {
  SheetsJournalSpaceIncludeList._({
    _isd.WhereExpressionBuilder<SheetsJournalSpaceTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SheetsJournalSpace.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => SheetsJournalSpace.t;
}

class SheetsJournalSpaceRepository {
  const SheetsJournalSpaceRepository._();

  /// Returns a list of [SheetsJournalSpace]s matching the given query parameters.
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
  Future<List<SheetsJournalSpace>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsJournalSpaceTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsJournalSpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsJournalSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SheetsJournalSpace>(
      where: where?.call(SheetsJournalSpace.t),
      orderBy: orderBy?.call(SheetsJournalSpace.t),
      orderByList: orderByList?.call(SheetsJournalSpace.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SheetsJournalSpace]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SheetsJournalSpace.t`.
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
  _ida.Stream<List<SheetsJournalSpace>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsJournalSpaceTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsJournalSpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsJournalSpaceTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SheetsJournalSpace>(
      where: where?.call(SheetsJournalSpace.t),
      orderBy: orderBy?.call(SheetsJournalSpace.t),
      orderByList: orderByList?.call(SheetsJournalSpace.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SheetsJournalSpace] matching the given query parameters.
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
  Future<SheetsJournalSpace?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsJournalSpaceTable>? where,
    int? offset,
    _isd.OrderByBuilder<SheetsJournalSpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsJournalSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SheetsJournalSpace>(
      where: where?.call(SheetsJournalSpace.t),
      orderBy: orderBy?.call(SheetsJournalSpace.t),
      orderByList: orderByList?.call(SheetsJournalSpace.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SheetsJournalSpace] by its [id] or null if no such row exists.
  Future<SheetsJournalSpace?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SheetsJournalSpace>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SheetsJournalSpace]s in the list and returns the inserted rows.
  ///
  /// The returned [SheetsJournalSpace]s will have their `id` fields set.
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
  Future<List<SheetsJournalSpace>> insert(
    _isd.DatabaseSession session,
    List<SheetsJournalSpace> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SheetsJournalSpace>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SheetsJournalSpace] and returns the inserted row.
  ///
  /// The returned [SheetsJournalSpace] will have its `id` field set.
  Future<SheetsJournalSpace> insertRow(
    _isd.DatabaseSession session,
    SheetsJournalSpace row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SheetsJournalSpace>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SheetsJournalSpace]s in the list and returns the resulting rows.
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
  /// The returned [SheetsJournalSpace]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsJournalSpace>> upsert(
    _isd.DatabaseSession session,
    List<SheetsJournalSpace> rows, {
    required _isd.ColumnSelections<SheetsJournalSpaceTable> conflictColumns,
    _isd.ColumnSelections<SheetsJournalSpaceTable>? updateColumns,
    _isd.WhereExpressionBuilder<SheetsJournalSpaceTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SheetsJournalSpace>(
      rows,
      conflictColumns: conflictColumns(SheetsJournalSpace.t),
      updateColumns: updateColumns?.call(SheetsJournalSpace.t),
      updateWhere: updateWhere?.call(SheetsJournalSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SheetsJournalSpace] and returns the resulting row.
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
  /// The returned [SheetsJournalSpace] will have its `id` field set.
  Future<SheetsJournalSpace?> upsertRow(
    _isd.DatabaseSession session,
    SheetsJournalSpace row, {
    required _isd.ColumnSelections<SheetsJournalSpaceTable> conflictColumns,
    _isd.ColumnSelections<SheetsJournalSpaceTable>? updateColumns,
    _isd.WhereExpressionBuilder<SheetsJournalSpaceTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SheetsJournalSpace>(
      row,
      conflictColumns: conflictColumns(SheetsJournalSpace.t),
      updateColumns: updateColumns?.call(SheetsJournalSpace.t),
      updateWhere: updateWhere?.call(SheetsJournalSpace.t),
      transaction: transaction,
    );
  }

  /// Updates all [SheetsJournalSpace]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsJournalSpace>> update(
    _isd.DatabaseSession session,
    List<SheetsJournalSpace> rows, {
    _isd.ColumnSelections<SheetsJournalSpaceTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SheetsJournalSpace>(
      rows,
      columns: columns?.call(SheetsJournalSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SheetsJournalSpace]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SheetsJournalSpace> updateRow(
    _isd.DatabaseSession session,
    SheetsJournalSpace row, {
    _isd.ColumnSelections<SheetsJournalSpaceTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SheetsJournalSpace>(
      row,
      columns: columns?.call(SheetsJournalSpace.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SheetsJournalSpace] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SheetsJournalSpace?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<SheetsJournalSpaceUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SheetsJournalSpace>(
      id,
      columnValues: columnValues(SheetsJournalSpace.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SheetsJournalSpace]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsJournalSpace>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SheetsJournalSpaceUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<SheetsJournalSpaceTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsJournalSpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsJournalSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SheetsJournalSpace>(
      columnValues: columnValues(SheetsJournalSpace.t.updateTable),
      where: where(SheetsJournalSpace.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetsJournalSpace.t),
      orderByList: orderByList?.call(SheetsJournalSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SheetsJournalSpace]s in the list and returns the deleted rows.
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
  Future<List<SheetsJournalSpace>> delete(
    _isd.DatabaseSession session,
    List<SheetsJournalSpace> rows, {
    _isd.OrderByBuilder<SheetsJournalSpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsJournalSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SheetsJournalSpace>(
      rows,
      orderBy: orderBy?.call(SheetsJournalSpace.t),
      orderByList: orderByList?.call(SheetsJournalSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SheetsJournalSpace].
  Future<SheetsJournalSpace> deleteRow(
    _isd.DatabaseSession session,
    SheetsJournalSpace row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SheetsJournalSpace>(
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
  Future<List<SheetsJournalSpace>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SheetsJournalSpaceTable> where,
    _isd.OrderByBuilder<SheetsJournalSpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsJournalSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SheetsJournalSpace>(
      where: where(SheetsJournalSpace.t),
      orderBy: orderBy?.call(SheetsJournalSpace.t),
      orderByList: orderByList?.call(SheetsJournalSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsJournalSpaceTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SheetsJournalSpace>(
      where: where?.call(SheetsJournalSpace.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SheetsJournalSpace] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SheetsJournalSpaceTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SheetsJournalSpace>(
      where: where(SheetsJournalSpace.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
