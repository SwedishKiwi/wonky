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
import 'package:serverpod/serverpod.dart' as _is;

/// GitHub webhook deliveries already handled (dedupe; purged after 7 days).
abstract class BoardGithubDelivery
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  BoardGithubDelivery._({
    this.id,
    required this.deliveryId,
    required this.event,
    required this.receivedAt,
  });

  factory BoardGithubDelivery({
    int? id,
    required String deliveryId,
    required String event,
    required DateTime receivedAt,
  }) = _BoardGithubDeliveryImpl;

  factory BoardGithubDelivery.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardGithubDelivery(
      id: jsonSerialization['id'] as int?,
      deliveryId: jsonSerialization['deliveryId'] as String,
      event: jsonSerialization['event'] as String,
      receivedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['receivedAt'],
      ),
    );
  }

  static final t = BoardGithubDeliveryTable();

  static const db = BoardGithubDeliveryRepository._();

  @override
  int? id;

  String deliveryId;

  String event;

  DateTime receivedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [BoardGithubDelivery]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardGithubDelivery copyWith({
    int? id,
    String? deliveryId,
    String? event,
    DateTime? receivedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardGithubDelivery',
      if (id != null) 'id': id,
      'deliveryId': deliveryId,
      'event': event,
      'receivedAt': receivedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static BoardGithubDeliveryInclude include() {
    return BoardGithubDeliveryInclude._();
  }

  static BoardGithubDeliveryIncludeList includeList({
    _is.WhereExpressionBuilder<BoardGithubDeliveryTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardGithubDeliveryTable>? orderBy,
    _is.OrderByListBuilder<BoardGithubDeliveryTable>? orderByList,
    BoardGithubDeliveryInclude? include,
  }) {
    return BoardGithubDeliveryIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardGithubDelivery.t),
      orderByList: orderByList?.call(BoardGithubDelivery.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardGithubDeliveryImpl extends BoardGithubDelivery {
  _BoardGithubDeliveryImpl({
    int? id,
    required String deliveryId,
    required String event,
    required DateTime receivedAt,
  }) : super._(
         id: id,
         deliveryId: deliveryId,
         event: event,
         receivedAt: receivedAt,
       );

  /// Returns a shallow copy of this [BoardGithubDelivery]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardGithubDelivery copyWith({
    Object? id = _Undefined,
    String? deliveryId,
    String? event,
    DateTime? receivedAt,
  }) {
    return BoardGithubDelivery(
      id: id is int? ? id : this.id,
      deliveryId: deliveryId ?? this.deliveryId,
      event: event ?? this.event,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }
}

class BoardGithubDeliveryUpdateTable
    extends _is.UpdateTable<BoardGithubDeliveryTable> {
  BoardGithubDeliveryUpdateTable(super.table);

  _is.ColumnValue<String, String> deliveryId(String value) => _is.ColumnValue(
    table.deliveryId,
    value,
  );

  _is.ColumnValue<String, String> event(String value) => _is.ColumnValue(
    table.event,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> receivedAt(DateTime value) =>
      _is.ColumnValue(
        table.receivedAt,
        value,
      );
}

class BoardGithubDeliveryTable extends _is.Table<int?> {
  BoardGithubDeliveryTable({super.tableRelation})
    : super(tableName: 'board_github_delivery') {
    updateTable = BoardGithubDeliveryUpdateTable(this);
    deliveryId = _is.ColumnString(
      'deliveryId',
      this,
    );
    event = _is.ColumnString(
      'event',
      this,
    );
    receivedAt = _is.ColumnDateTime(
      'receivedAt',
      this,
    );
  }

  late final BoardGithubDeliveryUpdateTable updateTable;

  late final _is.ColumnString deliveryId;

  late final _is.ColumnString event;

  late final _is.ColumnDateTime receivedAt;

  @override
  List<_is.Column> get columns => [
    id,
    deliveryId,
    event,
    receivedAt,
  ];
}

class BoardGithubDeliveryInclude extends _is.IncludeObject {
  BoardGithubDeliveryInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => BoardGithubDelivery.t;
}

class BoardGithubDeliveryIncludeList extends _is.IncludeList {
  BoardGithubDeliveryIncludeList._({
    _is.WhereExpressionBuilder<BoardGithubDeliveryTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BoardGithubDelivery.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => BoardGithubDelivery.t;
}

class BoardGithubDeliveryRepository {
  const BoardGithubDeliveryRepository._();

  /// Returns a list of [BoardGithubDelivery]s matching the given query parameters.
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
  Future<List<BoardGithubDelivery>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardGithubDeliveryTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardGithubDeliveryTable>? orderBy,
    _is.OrderByListBuilder<BoardGithubDeliveryTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BoardGithubDelivery>(
      where: where?.call(BoardGithubDelivery.t),
      orderBy: orderBy?.call(BoardGithubDelivery.t),
      orderByList: orderByList?.call(BoardGithubDelivery.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [BoardGithubDelivery]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `BoardGithubDelivery.t`.
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
  _ida.Stream<List<BoardGithubDelivery>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardGithubDeliveryTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardGithubDeliveryTable>? orderBy,
    _is.OrderByListBuilder<BoardGithubDeliveryTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<BoardGithubDelivery>(
      where: where?.call(BoardGithubDelivery.t),
      orderBy: orderBy?.call(BoardGithubDelivery.t),
      orderByList: orderByList?.call(BoardGithubDelivery.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [BoardGithubDelivery] matching the given query parameters.
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
  Future<BoardGithubDelivery?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardGithubDeliveryTable>? where,
    int? offset,
    _is.OrderByBuilder<BoardGithubDeliveryTable>? orderBy,
    _is.OrderByListBuilder<BoardGithubDeliveryTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BoardGithubDelivery>(
      where: where?.call(BoardGithubDelivery.t),
      orderBy: orderBy?.call(BoardGithubDelivery.t),
      orderByList: orderByList?.call(BoardGithubDelivery.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BoardGithubDelivery] by its [id] or null if no such row exists.
  Future<BoardGithubDelivery?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BoardGithubDelivery>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BoardGithubDelivery]s in the list and returns the inserted rows.
  ///
  /// The returned [BoardGithubDelivery]s will have their `id` fields set.
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
  Future<List<BoardGithubDelivery>> insert(
    _is.DatabaseSession session,
    List<BoardGithubDelivery> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BoardGithubDelivery>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BoardGithubDelivery] and returns the inserted row.
  ///
  /// The returned [BoardGithubDelivery] will have its `id` field set.
  Future<BoardGithubDelivery> insertRow(
    _is.DatabaseSession session,
    BoardGithubDelivery row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BoardGithubDelivery>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BoardGithubDelivery]s in the list and returns the resulting rows.
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
  /// The returned [BoardGithubDelivery]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardGithubDelivery>> upsert(
    _is.DatabaseSession session,
    List<BoardGithubDelivery> rows, {
    required _is.ColumnSelections<BoardGithubDeliveryTable> conflictColumns,
    _is.ColumnSelections<BoardGithubDeliveryTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardGithubDeliveryTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BoardGithubDelivery>(
      rows,
      conflictColumns: conflictColumns(BoardGithubDelivery.t),
      updateColumns: updateColumns?.call(BoardGithubDelivery.t),
      updateWhere: updateWhere?.call(BoardGithubDelivery.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BoardGithubDelivery] and returns the resulting row.
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
  /// The returned [BoardGithubDelivery] will have its `id` field set.
  Future<BoardGithubDelivery?> upsertRow(
    _is.DatabaseSession session,
    BoardGithubDelivery row, {
    required _is.ColumnSelections<BoardGithubDeliveryTable> conflictColumns,
    _is.ColumnSelections<BoardGithubDeliveryTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardGithubDeliveryTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BoardGithubDelivery>(
      row,
      conflictColumns: conflictColumns(BoardGithubDelivery.t),
      updateColumns: updateColumns?.call(BoardGithubDelivery.t),
      updateWhere: updateWhere?.call(BoardGithubDelivery.t),
      transaction: transaction,
    );
  }

  /// Updates all [BoardGithubDelivery]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardGithubDelivery>> update(
    _is.DatabaseSession session,
    List<BoardGithubDelivery> rows, {
    _is.ColumnSelections<BoardGithubDeliveryTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BoardGithubDelivery>(
      rows,
      columns: columns?.call(BoardGithubDelivery.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BoardGithubDelivery]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BoardGithubDelivery> updateRow(
    _is.DatabaseSession session,
    BoardGithubDelivery row, {
    _is.ColumnSelections<BoardGithubDeliveryTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BoardGithubDelivery>(
      row,
      columns: columns?.call(BoardGithubDelivery.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BoardGithubDelivery] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BoardGithubDelivery?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BoardGithubDeliveryUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BoardGithubDelivery>(
      id,
      columnValues: columnValues(BoardGithubDelivery.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BoardGithubDelivery]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardGithubDelivery>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BoardGithubDeliveryUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<BoardGithubDeliveryTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardGithubDeliveryTable>? orderBy,
    _is.OrderByListBuilder<BoardGithubDeliveryTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BoardGithubDelivery>(
      columnValues: columnValues(BoardGithubDelivery.t.updateTable),
      where: where(BoardGithubDelivery.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardGithubDelivery.t),
      orderByList: orderByList?.call(BoardGithubDelivery.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BoardGithubDelivery]s in the list and returns the deleted rows.
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
  Future<List<BoardGithubDelivery>> delete(
    _is.DatabaseSession session,
    List<BoardGithubDelivery> rows, {
    _is.OrderByBuilder<BoardGithubDeliveryTable>? orderBy,
    _is.OrderByListBuilder<BoardGithubDeliveryTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BoardGithubDelivery>(
      rows,
      orderBy: orderBy?.call(BoardGithubDelivery.t),
      orderByList: orderByList?.call(BoardGithubDelivery.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BoardGithubDelivery].
  Future<BoardGithubDelivery> deleteRow(
    _is.DatabaseSession session,
    BoardGithubDelivery row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BoardGithubDelivery>(
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
  Future<List<BoardGithubDelivery>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardGithubDeliveryTable> where,
    _is.OrderByBuilder<BoardGithubDeliveryTable>? orderBy,
    _is.OrderByListBuilder<BoardGithubDeliveryTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BoardGithubDelivery>(
      where: where(BoardGithubDelivery.t),
      orderBy: orderBy?.call(BoardGithubDelivery.t),
      orderByList: orderByList?.call(BoardGithubDelivery.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardGithubDeliveryTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BoardGithubDelivery>(
      where: where?.call(BoardGithubDelivery.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BoardGithubDelivery] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardGithubDeliveryTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BoardGithubDelivery>(
      where: where(BoardGithubDelivery.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
