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

/// A pending ownership transfer; the new owner must accept (specs/06 §4).
abstract class OwnershipTransfer
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  OwnershipTransfer._({
    this.id,
    required this.itemId,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
    this.handledAt,
    this.accepted,
  });

  factory OwnershipTransfer({
    int? id,
    required int itemId,
    required int fromUserId,
    required int toUserId,
    required DateTime createdAt,
    DateTime? handledAt,
    bool? accepted,
  }) = _OwnershipTransferImpl;

  factory OwnershipTransfer.fromJson(Map<String, dynamic> jsonSerialization) {
    return OwnershipTransfer(
      id: jsonSerialization['id'] as int?,
      itemId: jsonSerialization['itemId'] as int,
      fromUserId: jsonSerialization['fromUserId'] as int,
      toUserId: jsonSerialization['toUserId'] as int,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      handledAt: jsonSerialization['handledAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['handledAt']),
      accepted: jsonSerialization['accepted'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['accepted']),
    );
  }

  static final t = OwnershipTransferTable();

  static const db = OwnershipTransferRepository._();

  @override
  int? id;

  int itemId;

  int fromUserId;

  int toUserId;

  DateTime createdAt;

  DateTime? handledAt;

  bool? accepted;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [OwnershipTransfer]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  OwnershipTransfer copyWith({
    int? id,
    int? itemId,
    int? fromUserId,
    int? toUserId,
    DateTime? createdAt,
    DateTime? handledAt = const _is.$UndefinedDateTime(),
    bool? accepted,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'OwnershipTransfer',
      if (id != null) 'id': id,
      'itemId': itemId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'createdAt': createdAt.toJson(),
      if (handledAt != null) 'handledAt': handledAt?.toJson(),
      if (accepted != null) 'accepted': accepted,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'OwnershipTransfer',
      if (id != null) 'id': id,
      'itemId': itemId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'createdAt': createdAt.toJson(),
      if (handledAt != null) 'handledAt': handledAt?.toJson(),
      if (accepted != null) 'accepted': accepted,
    };
  }

  static OwnershipTransferInclude include() {
    return OwnershipTransferInclude._();
  }

  static OwnershipTransferIncludeList includeList({
    _is.WhereExpressionBuilder<OwnershipTransferTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<OwnershipTransferTable>? orderBy,
    _is.OrderByListBuilder<OwnershipTransferTable>? orderByList,
    OwnershipTransferInclude? include,
  }) {
    return OwnershipTransferIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OwnershipTransfer.t),
      orderByList: orderByList?.call(OwnershipTransfer.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OwnershipTransferImpl extends OwnershipTransfer {
  _OwnershipTransferImpl({
    int? id,
    required int itemId,
    required int fromUserId,
    required int toUserId,
    required DateTime createdAt,
    DateTime? handledAt,
    bool? accepted,
  }) : super._(
         id: id,
         itemId: itemId,
         fromUserId: fromUserId,
         toUserId: toUserId,
         createdAt: createdAt,
         handledAt: handledAt,
         accepted: accepted,
       );

  /// Returns a shallow copy of this [OwnershipTransfer]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  OwnershipTransfer copyWith({
    Object? id = _Undefined,
    int? itemId,
    int? fromUserId,
    int? toUserId,
    DateTime? createdAt,
    DateTime? handledAt = const _is.$UndefinedDateTime(),
    Object? accepted = _Undefined,
  }) {
    return OwnershipTransfer(
      id: id is int? ? id : this.id,
      itemId: itemId ?? this.itemId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      createdAt: createdAt ?? this.createdAt,
      handledAt: handledAt is _is.UndefinedSentinel
          ? this.handledAt
          : handledAt,
      accepted: accepted is bool? ? accepted : this.accepted,
    );
  }
}

class OwnershipTransferUpdateTable
    extends _is.UpdateTable<OwnershipTransferTable> {
  OwnershipTransferUpdateTable(super.table);

  _is.ColumnValue<int, int> itemId(int value) => _is.ColumnValue(
    table.itemId,
    value,
  );

  _is.ColumnValue<int, int> fromUserId(int value) => _is.ColumnValue(
    table.fromUserId,
    value,
  );

  _is.ColumnValue<int, int> toUserId(int value) => _is.ColumnValue(
    table.toUserId,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> handledAt(DateTime? value) =>
      _is.ColumnValue(
        table.handledAt,
        value,
      );

  _is.ColumnValue<bool, bool> accepted(bool? value) => _is.ColumnValue(
    table.accepted,
    value,
  );
}

class OwnershipTransferTable extends _is.Table<int?> {
  OwnershipTransferTable({super.tableRelation})
    : super(tableName: 'ownership_transfer') {
    updateTable = OwnershipTransferUpdateTable(this);
    itemId = _is.ColumnInt(
      'itemId',
      this,
    );
    fromUserId = _is.ColumnInt(
      'fromUserId',
      this,
    );
    toUserId = _is.ColumnInt(
      'toUserId',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    handledAt = _is.ColumnDateTime(
      'handledAt',
      this,
    );
    accepted = _is.ColumnBool(
      'accepted',
      this,
    );
  }

  late final OwnershipTransferUpdateTable updateTable;

  late final _is.ColumnInt itemId;

  late final _is.ColumnInt fromUserId;

  late final _is.ColumnInt toUserId;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime handledAt;

  late final _is.ColumnBool accepted;

  @override
  List<_is.Column> get columns => [
    id,
    itemId,
    fromUserId,
    toUserId,
    createdAt,
    handledAt,
    accepted,
  ];
}

class OwnershipTransferInclude extends _is.IncludeObject {
  OwnershipTransferInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => OwnershipTransfer.t;
}

class OwnershipTransferIncludeList extends _is.IncludeList {
  OwnershipTransferIncludeList._({
    _is.WhereExpressionBuilder<OwnershipTransferTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(OwnershipTransfer.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => OwnershipTransfer.t;
}

class OwnershipTransferRepository {
  const OwnershipTransferRepository._();

  /// Returns a list of [OwnershipTransfer]s matching the given query parameters.
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
  Future<List<OwnershipTransfer>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<OwnershipTransferTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<OwnershipTransferTable>? orderBy,
    _is.OrderByListBuilder<OwnershipTransferTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<OwnershipTransfer>(
      where: where?.call(OwnershipTransfer.t),
      orderBy: orderBy?.call(OwnershipTransfer.t),
      orderByList: orderByList?.call(OwnershipTransfer.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [OwnershipTransfer]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `OwnershipTransfer.t`.
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
  _ida.Stream<List<OwnershipTransfer>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<OwnershipTransferTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<OwnershipTransferTable>? orderBy,
    _is.OrderByListBuilder<OwnershipTransferTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<OwnershipTransfer>(
      where: where?.call(OwnershipTransfer.t),
      orderBy: orderBy?.call(OwnershipTransfer.t),
      orderByList: orderByList?.call(OwnershipTransfer.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [OwnershipTransfer] matching the given query parameters.
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
  Future<OwnershipTransfer?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<OwnershipTransferTable>? where,
    int? offset,
    _is.OrderByBuilder<OwnershipTransferTable>? orderBy,
    _is.OrderByListBuilder<OwnershipTransferTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<OwnershipTransfer>(
      where: where?.call(OwnershipTransfer.t),
      orderBy: orderBy?.call(OwnershipTransfer.t),
      orderByList: orderByList?.call(OwnershipTransfer.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [OwnershipTransfer] by its [id] or null if no such row exists.
  Future<OwnershipTransfer?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<OwnershipTransfer>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [OwnershipTransfer]s in the list and returns the inserted rows.
  ///
  /// The returned [OwnershipTransfer]s will have their `id` fields set.
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
  Future<List<OwnershipTransfer>> insert(
    _is.DatabaseSession session,
    List<OwnershipTransfer> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<OwnershipTransfer>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [OwnershipTransfer] and returns the inserted row.
  ///
  /// The returned [OwnershipTransfer] will have its `id` field set.
  Future<OwnershipTransfer> insertRow(
    _is.DatabaseSession session,
    OwnershipTransfer row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<OwnershipTransfer>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [OwnershipTransfer]s in the list and returns the resulting rows.
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
  /// The returned [OwnershipTransfer]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OwnershipTransfer>> upsert(
    _is.DatabaseSession session,
    List<OwnershipTransfer> rows, {
    required _is.ColumnSelections<OwnershipTransferTable> conflictColumns,
    _is.ColumnSelections<OwnershipTransferTable>? updateColumns,
    _is.WhereExpressionBuilder<OwnershipTransferTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<OwnershipTransfer>(
      rows,
      conflictColumns: conflictColumns(OwnershipTransfer.t),
      updateColumns: updateColumns?.call(OwnershipTransfer.t),
      updateWhere: updateWhere?.call(OwnershipTransfer.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [OwnershipTransfer] and returns the resulting row.
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
  /// The returned [OwnershipTransfer] will have its `id` field set.
  Future<OwnershipTransfer?> upsertRow(
    _is.DatabaseSession session,
    OwnershipTransfer row, {
    required _is.ColumnSelections<OwnershipTransferTable> conflictColumns,
    _is.ColumnSelections<OwnershipTransferTable>? updateColumns,
    _is.WhereExpressionBuilder<OwnershipTransferTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<OwnershipTransfer>(
      row,
      conflictColumns: conflictColumns(OwnershipTransfer.t),
      updateColumns: updateColumns?.call(OwnershipTransfer.t),
      updateWhere: updateWhere?.call(OwnershipTransfer.t),
      transaction: transaction,
    );
  }

  /// Updates all [OwnershipTransfer]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OwnershipTransfer>> update(
    _is.DatabaseSession session,
    List<OwnershipTransfer> rows, {
    _is.ColumnSelections<OwnershipTransferTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<OwnershipTransfer>(
      rows,
      columns: columns?.call(OwnershipTransfer.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [OwnershipTransfer]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<OwnershipTransfer> updateRow(
    _is.DatabaseSession session,
    OwnershipTransfer row, {
    _is.ColumnSelections<OwnershipTransferTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<OwnershipTransfer>(
      row,
      columns: columns?.call(OwnershipTransfer.t),
      transaction: transaction,
    );
  }

  /// Updates a single [OwnershipTransfer] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<OwnershipTransfer?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<OwnershipTransferUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<OwnershipTransfer>(
      id,
      columnValues: columnValues(OwnershipTransfer.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [OwnershipTransfer]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OwnershipTransfer>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<OwnershipTransferUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<OwnershipTransferTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<OwnershipTransferTable>? orderBy,
    _is.OrderByListBuilder<OwnershipTransferTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<OwnershipTransfer>(
      columnValues: columnValues(OwnershipTransfer.t.updateTable),
      where: where(OwnershipTransfer.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OwnershipTransfer.t),
      orderByList: orderByList?.call(OwnershipTransfer.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [OwnershipTransfer]s in the list and returns the deleted rows.
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
  Future<List<OwnershipTransfer>> delete(
    _is.DatabaseSession session,
    List<OwnershipTransfer> rows, {
    _is.OrderByBuilder<OwnershipTransferTable>? orderBy,
    _is.OrderByListBuilder<OwnershipTransferTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<OwnershipTransfer>(
      rows,
      orderBy: orderBy?.call(OwnershipTransfer.t),
      orderByList: orderByList?.call(OwnershipTransfer.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [OwnershipTransfer].
  Future<OwnershipTransfer> deleteRow(
    _is.DatabaseSession session,
    OwnershipTransfer row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<OwnershipTransfer>(
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
  Future<List<OwnershipTransfer>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<OwnershipTransferTable> where,
    _is.OrderByBuilder<OwnershipTransferTable>? orderBy,
    _is.OrderByListBuilder<OwnershipTransferTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<OwnershipTransfer>(
      where: where(OwnershipTransfer.t),
      orderBy: orderBy?.call(OwnershipTransfer.t),
      orderByList: orderByList?.call(OwnershipTransfer.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<OwnershipTransferTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<OwnershipTransfer>(
      where: where?.call(OwnershipTransfer.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [OwnershipTransfer] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<OwnershipTransferTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<OwnershipTransfer>(
      where: where(OwnershipTransfer.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
