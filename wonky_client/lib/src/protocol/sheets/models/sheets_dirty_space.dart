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

/// A spreadsheet space with local writes that may not have reached the
/// server yet (the pending-change guard of suite 12 §2.3: before syncing,
/// the app calls `sheets.ensureSubscribed` for these). Cleared after a
/// complete sync while still a member. Client-only; never synced.
abstract class SheetsDirtySpace
    implements _isd.TableRow<int?>, _isc.ProtocolSerialization {
  SheetsDirtySpace._({
    this.id,
    required this.spaceUuid,
    DateTime? markedAt,
  }) : markedAt = markedAt ?? DateTime.now();

  factory SheetsDirtySpace({
    int? id,
    required _isc.UuidValue spaceUuid,
    DateTime? markedAt,
  }) = _SheetsDirtySpaceImpl;

  factory SheetsDirtySpace.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsDirtySpace(
      id: jsonSerialization['id'] as int?,
      spaceUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['spaceUuid'],
      ),
      markedAt: jsonSerialization['markedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['markedAt']),
    );
  }

  static final t = SheetsDirtySpaceTable();

  static const db = SheetsDirtySpaceRepository._();

  @override
  int? id;

  _isc.UuidValue spaceUuid;

  DateTime markedAt;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [SheetsDirtySpace]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SheetsDirtySpace copyWith({
    int? id,
    _isc.UuidValue? spaceUuid,
    DateTime? markedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsDirtySpace',
      if (id != null) 'id': id,
      'spaceUuid': spaceUuid.toJson(),
      'markedAt': markedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsDirtySpace',
      if (id != null) 'id': id,
      'spaceUuid': spaceUuid.toJson(),
      'markedAt': markedAt.toJson(),
    };
  }

  static SheetsDirtySpaceInclude include() {
    return SheetsDirtySpaceInclude._();
  }

  static SheetsDirtySpaceIncludeList includeList({
    _isd.WhereExpressionBuilder<SheetsDirtySpaceTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsDirtySpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsDirtySpaceTable>? orderByList,
    SheetsDirtySpaceInclude? include,
  }) {
    return SheetsDirtySpaceIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetsDirtySpace.t),
      orderByList: orderByList?.call(SheetsDirtySpace.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsDirtySpaceImpl extends SheetsDirtySpace {
  _SheetsDirtySpaceImpl({
    int? id,
    required _isc.UuidValue spaceUuid,
    DateTime? markedAt,
  }) : super._(
         id: id,
         spaceUuid: spaceUuid,
         markedAt: markedAt,
       );

  /// Returns a shallow copy of this [SheetsDirtySpace]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SheetsDirtySpace copyWith({
    Object? id = _Undefined,
    _isc.UuidValue? spaceUuid,
    DateTime? markedAt,
  }) {
    return SheetsDirtySpace(
      id: id is int? ? id : this.id,
      spaceUuid: spaceUuid ?? this.spaceUuid,
      markedAt: markedAt ?? this.markedAt,
    );
  }
}

class SheetsDirtySpaceUpdateTable
    extends _isd.UpdateTable<SheetsDirtySpaceTable> {
  SheetsDirtySpaceUpdateTable(super.table);

  _isd.ColumnValue<_isc.UuidValue, _isc.UuidValue> spaceUuid(
    _isc.UuidValue value,
  ) => _isd.ColumnValue(
    table.spaceUuid,
    value,
  );

  _isd.ColumnValue<DateTime, DateTime> markedAt(DateTime value) =>
      _isd.ColumnValue(
        table.markedAt,
        value,
      );
}

class SheetsDirtySpaceTable extends _isd.Table<int?> {
  SheetsDirtySpaceTable({super.tableRelation})
    : super(tableName: 'sheets_dirty_space') {
    updateTable = SheetsDirtySpaceUpdateTable(this);
    spaceUuid = _isd.ColumnUuid(
      'spaceUuid',
      this,
    );
    markedAt = _isd.ColumnDateTime(
      'markedAt',
      this,
      hasDefault: true,
    );
  }

  late final SheetsDirtySpaceUpdateTable updateTable;

  late final _isd.ColumnUuid spaceUuid;

  late final _isd.ColumnDateTime markedAt;

  @override
  List<_isd.Column> get columns => [
    id,
    spaceUuid,
    markedAt,
  ];
}

class SheetsDirtySpaceInclude extends _isd.IncludeObject {
  SheetsDirtySpaceInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<int?> get table => SheetsDirtySpace.t;
}

class SheetsDirtySpaceIncludeList extends _isd.IncludeList {
  SheetsDirtySpaceIncludeList._({
    _isd.WhereExpressionBuilder<SheetsDirtySpaceTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SheetsDirtySpace.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => SheetsDirtySpace.t;
}

class SheetsDirtySpaceRepository {
  const SheetsDirtySpaceRepository._();

  /// Returns a list of [SheetsDirtySpace]s matching the given query parameters.
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
  Future<List<SheetsDirtySpace>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsDirtySpaceTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsDirtySpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsDirtySpaceTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SheetsDirtySpace>(
      where: where?.call(SheetsDirtySpace.t),
      orderBy: orderBy?.call(SheetsDirtySpace.t),
      orderByList: orderByList?.call(SheetsDirtySpace.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SheetsDirtySpace]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SheetsDirtySpace.t`.
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
  _ida.Stream<List<SheetsDirtySpace>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsDirtySpaceTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsDirtySpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsDirtySpaceTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SheetsDirtySpace>(
      where: where?.call(SheetsDirtySpace.t),
      orderBy: orderBy?.call(SheetsDirtySpace.t),
      orderByList: orderByList?.call(SheetsDirtySpace.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SheetsDirtySpace] matching the given query parameters.
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
  Future<SheetsDirtySpace?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsDirtySpaceTable>? where,
    int? offset,
    _isd.OrderByBuilder<SheetsDirtySpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsDirtySpaceTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SheetsDirtySpace>(
      where: where?.call(SheetsDirtySpace.t),
      orderBy: orderBy?.call(SheetsDirtySpace.t),
      orderByList: orderByList?.call(SheetsDirtySpace.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SheetsDirtySpace] by its [id] or null if no such row exists.
  Future<SheetsDirtySpace?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SheetsDirtySpace>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SheetsDirtySpace]s in the list and returns the inserted rows.
  ///
  /// The returned [SheetsDirtySpace]s will have their `id` fields set.
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
  Future<List<SheetsDirtySpace>> insert(
    _isd.DatabaseSession session,
    List<SheetsDirtySpace> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SheetsDirtySpace>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SheetsDirtySpace] and returns the inserted row.
  ///
  /// The returned [SheetsDirtySpace] will have its `id` field set.
  Future<SheetsDirtySpace> insertRow(
    _isd.DatabaseSession session,
    SheetsDirtySpace row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SheetsDirtySpace>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SheetsDirtySpace]s in the list and returns the resulting rows.
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
  /// The returned [SheetsDirtySpace]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsDirtySpace>> upsert(
    _isd.DatabaseSession session,
    List<SheetsDirtySpace> rows, {
    required _isd.ColumnSelections<SheetsDirtySpaceTable> conflictColumns,
    _isd.ColumnSelections<SheetsDirtySpaceTable>? updateColumns,
    _isd.WhereExpressionBuilder<SheetsDirtySpaceTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SheetsDirtySpace>(
      rows,
      conflictColumns: conflictColumns(SheetsDirtySpace.t),
      updateColumns: updateColumns?.call(SheetsDirtySpace.t),
      updateWhere: updateWhere?.call(SheetsDirtySpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SheetsDirtySpace] and returns the resulting row.
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
  /// The returned [SheetsDirtySpace] will have its `id` field set.
  Future<SheetsDirtySpace?> upsertRow(
    _isd.DatabaseSession session,
    SheetsDirtySpace row, {
    required _isd.ColumnSelections<SheetsDirtySpaceTable> conflictColumns,
    _isd.ColumnSelections<SheetsDirtySpaceTable>? updateColumns,
    _isd.WhereExpressionBuilder<SheetsDirtySpaceTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SheetsDirtySpace>(
      row,
      conflictColumns: conflictColumns(SheetsDirtySpace.t),
      updateColumns: updateColumns?.call(SheetsDirtySpace.t),
      updateWhere: updateWhere?.call(SheetsDirtySpace.t),
      transaction: transaction,
    );
  }

  /// Updates all [SheetsDirtySpace]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsDirtySpace>> update(
    _isd.DatabaseSession session,
    List<SheetsDirtySpace> rows, {
    _isd.ColumnSelections<SheetsDirtySpaceTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SheetsDirtySpace>(
      rows,
      columns: columns?.call(SheetsDirtySpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SheetsDirtySpace]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SheetsDirtySpace> updateRow(
    _isd.DatabaseSession session,
    SheetsDirtySpace row, {
    _isd.ColumnSelections<SheetsDirtySpaceTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SheetsDirtySpace>(
      row,
      columns: columns?.call(SheetsDirtySpace.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SheetsDirtySpace] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SheetsDirtySpace?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<SheetsDirtySpaceUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SheetsDirtySpace>(
      id,
      columnValues: columnValues(SheetsDirtySpace.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SheetsDirtySpace]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsDirtySpace>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SheetsDirtySpaceUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<SheetsDirtySpaceTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetsDirtySpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsDirtySpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SheetsDirtySpace>(
      columnValues: columnValues(SheetsDirtySpace.t.updateTable),
      where: where(SheetsDirtySpace.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetsDirtySpace.t),
      orderByList: orderByList?.call(SheetsDirtySpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SheetsDirtySpace]s in the list and returns the deleted rows.
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
  Future<List<SheetsDirtySpace>> delete(
    _isd.DatabaseSession session,
    List<SheetsDirtySpace> rows, {
    _isd.OrderByBuilder<SheetsDirtySpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsDirtySpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SheetsDirtySpace>(
      rows,
      orderBy: orderBy?.call(SheetsDirtySpace.t),
      orderByList: orderByList?.call(SheetsDirtySpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SheetsDirtySpace].
  Future<SheetsDirtySpace> deleteRow(
    _isd.DatabaseSession session,
    SheetsDirtySpace row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SheetsDirtySpace>(
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
  Future<List<SheetsDirtySpace>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SheetsDirtySpaceTable> where,
    _isd.OrderByBuilder<SheetsDirtySpaceTable>? orderBy,
    _isd.OrderByListBuilder<SheetsDirtySpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SheetsDirtySpace>(
      where: where(SheetsDirtySpace.t),
      orderBy: orderBy?.call(SheetsDirtySpace.t),
      orderByList: orderByList?.call(SheetsDirtySpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetsDirtySpaceTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SheetsDirtySpace>(
      where: where?.call(SheetsDirtySpace.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SheetsDirtySpace] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SheetsDirtySpaceTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SheetsDirtySpace>(
      where: where(SheetsDirtySpace.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
