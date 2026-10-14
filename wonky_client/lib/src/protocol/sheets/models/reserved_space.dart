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

/// A space reserved for this device by `sheets.reserveSpaces`, so a
/// spreadsheet can be created while offline (suite 12 §2.2). Client-only
/// (local SQLite of the Sheets app); never synced.
abstract class ReservedSpace
    implements _isd.TableRow<int?>, _isc.ProtocolSerialization {
  ReservedSpace._({
    this.id,
    required this.spaceUuid,
    DateTime? reservedAt,
  }) : reservedAt = reservedAt ?? DateTime.now();

  factory ReservedSpace({
    int? id,
    required _isc.UuidValue spaceUuid,
    DateTime? reservedAt,
  }) = _ReservedSpaceImpl;

  factory ReservedSpace.fromJson(Map<String, dynamic> jsonSerialization) {
    return ReservedSpace(
      id: jsonSerialization['id'] as int?,
      spaceUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['spaceUuid'],
      ),
      reservedAt: jsonSerialization['reservedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['reservedAt'],
            ),
    );
  }

  static final t = ReservedSpaceTable();

  static const db = ReservedSpaceRepository._();

  @override
  int? id;

  /// uuidSpaceId of an empty space reserved for this device.
  _isc.UuidValue spaceUuid;

  DateTime reservedAt;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [ReservedSpace]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ReservedSpace copyWith({
    int? id,
    _isc.UuidValue? spaceUuid,
    DateTime? reservedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ReservedSpace',
      if (id != null) 'id': id,
      'spaceUuid': spaceUuid.toJson(),
      'reservedAt': reservedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ReservedSpace',
      if (id != null) 'id': id,
      'spaceUuid': spaceUuid.toJson(),
      'reservedAt': reservedAt.toJson(),
    };
  }

  static ReservedSpaceInclude include() {
    return ReservedSpaceInclude._();
  }

  static ReservedSpaceIncludeList includeList({
    _isd.WhereExpressionBuilder<ReservedSpaceTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ReservedSpaceTable>? orderBy,
    _isd.OrderByListBuilder<ReservedSpaceTable>? orderByList,
    ReservedSpaceInclude? include,
  }) {
    return ReservedSpaceIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ReservedSpace.t),
      orderByList: orderByList?.call(ReservedSpace.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ReservedSpaceImpl extends ReservedSpace {
  _ReservedSpaceImpl({
    int? id,
    required _isc.UuidValue spaceUuid,
    DateTime? reservedAt,
  }) : super._(
         id: id,
         spaceUuid: spaceUuid,
         reservedAt: reservedAt,
       );

  /// Returns a shallow copy of this [ReservedSpace]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ReservedSpace copyWith({
    Object? id = _Undefined,
    _isc.UuidValue? spaceUuid,
    DateTime? reservedAt,
  }) {
    return ReservedSpace(
      id: id is int? ? id : this.id,
      spaceUuid: spaceUuid ?? this.spaceUuid,
      reservedAt: reservedAt ?? this.reservedAt,
    );
  }
}

class ReservedSpaceUpdateTable extends _isd.UpdateTable<ReservedSpaceTable> {
  ReservedSpaceUpdateTable(super.table);

  _isd.ColumnValue<_isc.UuidValue, _isc.UuidValue> spaceUuid(
    _isc.UuidValue value,
  ) => _isd.ColumnValue(
    table.spaceUuid,
    value,
  );

  _isd.ColumnValue<DateTime, DateTime> reservedAt(DateTime value) =>
      _isd.ColumnValue(
        table.reservedAt,
        value,
      );
}

class ReservedSpaceTable extends _isd.Table<int?> {
  ReservedSpaceTable({super.tableRelation})
    : super(tableName: 'reserved_space') {
    updateTable = ReservedSpaceUpdateTable(this);
    spaceUuid = _isd.ColumnUuid(
      'spaceUuid',
      this,
    );
    reservedAt = _isd.ColumnDateTime(
      'reservedAt',
      this,
      hasDefault: true,
    );
  }

  late final ReservedSpaceUpdateTable updateTable;

  /// uuidSpaceId of an empty space reserved for this device.
  late final _isd.ColumnUuid spaceUuid;

  late final _isd.ColumnDateTime reservedAt;

  @override
  List<_isd.Column> get columns => [
    id,
    spaceUuid,
    reservedAt,
  ];
}

class ReservedSpaceInclude extends _isd.IncludeObject {
  ReservedSpaceInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<int?> get table => ReservedSpace.t;
}

class ReservedSpaceIncludeList extends _isd.IncludeList {
  ReservedSpaceIncludeList._({
    _isd.WhereExpressionBuilder<ReservedSpaceTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ReservedSpace.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => ReservedSpace.t;
}

class ReservedSpaceRepository {
  const ReservedSpaceRepository._();

  /// Returns a list of [ReservedSpace]s matching the given query parameters.
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
  Future<List<ReservedSpace>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ReservedSpaceTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ReservedSpaceTable>? orderBy,
    _isd.OrderByListBuilder<ReservedSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ReservedSpace>(
      where: where?.call(ReservedSpace.t),
      orderBy: orderBy?.call(ReservedSpace.t),
      orderByList: orderByList?.call(ReservedSpace.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ReservedSpace]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ReservedSpace.t`.
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
  _ida.Stream<List<ReservedSpace>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ReservedSpaceTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ReservedSpaceTable>? orderBy,
    _isd.OrderByListBuilder<ReservedSpaceTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ReservedSpace>(
      where: where?.call(ReservedSpace.t),
      orderBy: orderBy?.call(ReservedSpace.t),
      orderByList: orderByList?.call(ReservedSpace.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ReservedSpace] matching the given query parameters.
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
  Future<ReservedSpace?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ReservedSpaceTable>? where,
    int? offset,
    _isd.OrderByBuilder<ReservedSpaceTable>? orderBy,
    _isd.OrderByListBuilder<ReservedSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ReservedSpace>(
      where: where?.call(ReservedSpace.t),
      orderBy: orderBy?.call(ReservedSpace.t),
      orderByList: orderByList?.call(ReservedSpace.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ReservedSpace] by its [id] or null if no such row exists.
  Future<ReservedSpace?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ReservedSpace>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ReservedSpace]s in the list and returns the inserted rows.
  ///
  /// The returned [ReservedSpace]s will have their `id` fields set.
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
  Future<List<ReservedSpace>> insert(
    _isd.DatabaseSession session,
    List<ReservedSpace> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ReservedSpace>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ReservedSpace] and returns the inserted row.
  ///
  /// The returned [ReservedSpace] will have its `id` field set.
  Future<ReservedSpace> insertRow(
    _isd.DatabaseSession session,
    ReservedSpace row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<ReservedSpace>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [ReservedSpace]s in the list and returns the resulting rows.
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
  /// The returned [ReservedSpace]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ReservedSpace>> upsert(
    _isd.DatabaseSession session,
    List<ReservedSpace> rows, {
    required _isd.ColumnSelections<ReservedSpaceTable> conflictColumns,
    _isd.ColumnSelections<ReservedSpaceTable>? updateColumns,
    _isd.WhereExpressionBuilder<ReservedSpaceTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ReservedSpace>(
      rows,
      conflictColumns: conflictColumns(ReservedSpace.t),
      updateColumns: updateColumns?.call(ReservedSpace.t),
      updateWhere: updateWhere?.call(ReservedSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ReservedSpace] and returns the resulting row.
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
  /// The returned [ReservedSpace] will have its `id` field set.
  Future<ReservedSpace?> upsertRow(
    _isd.DatabaseSession session,
    ReservedSpace row, {
    required _isd.ColumnSelections<ReservedSpaceTable> conflictColumns,
    _isd.ColumnSelections<ReservedSpaceTable>? updateColumns,
    _isd.WhereExpressionBuilder<ReservedSpaceTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ReservedSpace>(
      row,
      conflictColumns: conflictColumns(ReservedSpace.t),
      updateColumns: updateColumns?.call(ReservedSpace.t),
      updateWhere: updateWhere?.call(ReservedSpace.t),
      transaction: transaction,
    );
  }

  /// Updates all [ReservedSpace]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ReservedSpace>> update(
    _isd.DatabaseSession session,
    List<ReservedSpace> rows, {
    _isd.ColumnSelections<ReservedSpaceTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ReservedSpace>(
      rows,
      columns: columns?.call(ReservedSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ReservedSpace]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ReservedSpace> updateRow(
    _isd.DatabaseSession session,
    ReservedSpace row, {
    _isd.ColumnSelections<ReservedSpaceTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<ReservedSpace>(
      row,
      columns: columns?.call(ReservedSpace.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ReservedSpace] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ReservedSpace?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<ReservedSpaceUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<ReservedSpace>(
      id,
      columnValues: columnValues(ReservedSpace.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ReservedSpace]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ReservedSpace>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<ReservedSpaceUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<ReservedSpaceTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ReservedSpaceTable>? orderBy,
    _isd.OrderByListBuilder<ReservedSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ReservedSpace>(
      columnValues: columnValues(ReservedSpace.t.updateTable),
      where: where(ReservedSpace.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ReservedSpace.t),
      orderByList: orderByList?.call(ReservedSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ReservedSpace]s in the list and returns the deleted rows.
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
  Future<List<ReservedSpace>> delete(
    _isd.DatabaseSession session,
    List<ReservedSpace> rows, {
    _isd.OrderByBuilder<ReservedSpaceTable>? orderBy,
    _isd.OrderByListBuilder<ReservedSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ReservedSpace>(
      rows,
      orderBy: orderBy?.call(ReservedSpace.t),
      orderByList: orderByList?.call(ReservedSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ReservedSpace].
  Future<ReservedSpace> deleteRow(
    _isd.DatabaseSession session,
    ReservedSpace row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ReservedSpace>(
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
  Future<List<ReservedSpace>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ReservedSpaceTable> where,
    _isd.OrderByBuilder<ReservedSpaceTable>? orderBy,
    _isd.OrderByListBuilder<ReservedSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ReservedSpace>(
      where: where(ReservedSpace.t),
      orderBy: orderBy?.call(ReservedSpace.t),
      orderByList: orderByList?.call(ReservedSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ReservedSpaceTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<ReservedSpace>(
      where: where?.call(ReservedSpace.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ReservedSpace] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ReservedSpaceTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ReservedSpace>(
      where: where(ReservedSpace.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
