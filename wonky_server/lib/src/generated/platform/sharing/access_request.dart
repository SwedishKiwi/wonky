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
import '../../platform/common/access_role.dart' as _iv7g6vuy;
import '../../platform/sharing/access_request_outcome.dart' as _iy0p00sl;

abstract class AccessRequest
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  AccessRequest._({
    this.id,
    required this.itemId,
    required this.requesterId,
    required this.requestedRole,
    this.message,
    required this.createdAt,
    this.handledAt,
    this.handledById,
    this.outcome,
  });

  factory AccessRequest({
    int? id,
    required int itemId,
    required int requesterId,
    required _iv7g6vuy.AccessRole requestedRole,
    String? message,
    required DateTime createdAt,
    DateTime? handledAt,
    int? handledById,
    _iy0p00sl.AccessRequestOutcome? outcome,
  }) = _AccessRequestImpl;

  factory AccessRequest.fromJson(Map<String, dynamic> jsonSerialization) {
    return AccessRequest(
      id: jsonSerialization['id'] as int?,
      itemId: jsonSerialization['itemId'] as int,
      requesterId: jsonSerialization['requesterId'] as int,
      requestedRole: _iv7g6vuy.AccessRole.fromJson(
        (jsonSerialization['requestedRole'] as String),
      ),
      message: jsonSerialization['message'] as String?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      handledAt: jsonSerialization['handledAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['handledAt']),
      handledById: jsonSerialization['handledById'] as int?,
      outcome: jsonSerialization['outcome'] == null
          ? null
          : _iy0p00sl.AccessRequestOutcome.fromJson(
              (jsonSerialization['outcome'] as String),
            ),
    );
  }

  static final t = AccessRequestTable();

  static const db = AccessRequestRepository._();

  @override
  int? id;

  int itemId;

  int requesterId;

  _iv7g6vuy.AccessRole requestedRole;

  String? message;

  DateTime createdAt;

  DateTime? handledAt;

  int? handledById;

  _iy0p00sl.AccessRequestOutcome? outcome;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [AccessRequest]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AccessRequest copyWith({
    int? id,
    int? itemId,
    int? requesterId,
    _iv7g6vuy.AccessRole? requestedRole,
    String? message,
    DateTime? createdAt,
    DateTime? handledAt = const _is.$UndefinedDateTime(),
    int? handledById,
    _iy0p00sl.AccessRequestOutcome? outcome,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AccessRequest',
      if (id != null) 'id': id,
      'itemId': itemId,
      'requesterId': requesterId,
      'requestedRole': requestedRole.toJson(),
      if (message != null) 'message': message,
      'createdAt': createdAt.toJson(),
      if (handledAt != null) 'handledAt': handledAt?.toJson(),
      if (handledById != null) 'handledById': handledById,
      if (outcome != null) 'outcome': outcome?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AccessRequest',
      if (id != null) 'id': id,
      'itemId': itemId,
      'requesterId': requesterId,
      'requestedRole': requestedRole.toJson(),
      if (message != null) 'message': message,
      'createdAt': createdAt.toJson(),
      if (handledAt != null) 'handledAt': handledAt?.toJson(),
      if (handledById != null) 'handledById': handledById,
      if (outcome != null) 'outcome': outcome?.toJson(),
    };
  }

  static AccessRequestInclude include() {
    return AccessRequestInclude._();
  }

  static AccessRequestIncludeList includeList({
    _is.WhereExpressionBuilder<AccessRequestTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AccessRequestTable>? orderBy,
    _is.OrderByListBuilder<AccessRequestTable>? orderByList,
    AccessRequestInclude? include,
  }) {
    return AccessRequestIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AccessRequest.t),
      orderByList: orderByList?.call(AccessRequest.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AccessRequestImpl extends AccessRequest {
  _AccessRequestImpl({
    int? id,
    required int itemId,
    required int requesterId,
    required _iv7g6vuy.AccessRole requestedRole,
    String? message,
    required DateTime createdAt,
    DateTime? handledAt,
    int? handledById,
    _iy0p00sl.AccessRequestOutcome? outcome,
  }) : super._(
         id: id,
         itemId: itemId,
         requesterId: requesterId,
         requestedRole: requestedRole,
         message: message,
         createdAt: createdAt,
         handledAt: handledAt,
         handledById: handledById,
         outcome: outcome,
       );

  /// Returns a shallow copy of this [AccessRequest]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AccessRequest copyWith({
    Object? id = _Undefined,
    int? itemId,
    int? requesterId,
    _iv7g6vuy.AccessRole? requestedRole,
    Object? message = _Undefined,
    DateTime? createdAt,
    DateTime? handledAt = const _is.$UndefinedDateTime(),
    Object? handledById = _Undefined,
    Object? outcome = _Undefined,
  }) {
    return AccessRequest(
      id: id is int? ? id : this.id,
      itemId: itemId ?? this.itemId,
      requesterId: requesterId ?? this.requesterId,
      requestedRole: requestedRole ?? this.requestedRole,
      message: message is String? ? message : this.message,
      createdAt: createdAt ?? this.createdAt,
      handledAt: handledAt is _is.UndefinedSentinel
          ? this.handledAt
          : handledAt,
      handledById: handledById is int? ? handledById : this.handledById,
      outcome: outcome is _iy0p00sl.AccessRequestOutcome?
          ? outcome
          : this.outcome,
    );
  }
}

class AccessRequestUpdateTable extends _is.UpdateTable<AccessRequestTable> {
  AccessRequestUpdateTable(super.table);

  _is.ColumnValue<int, int> itemId(int value) => _is.ColumnValue(
    table.itemId,
    value,
  );

  _is.ColumnValue<int, int> requesterId(int value) => _is.ColumnValue(
    table.requesterId,
    value,
  );

  _is.ColumnValue<_iv7g6vuy.AccessRole, _iv7g6vuy.AccessRole> requestedRole(
    _iv7g6vuy.AccessRole value,
  ) => _is.ColumnValue(
    table.requestedRole,
    value,
  );

  _is.ColumnValue<String, String> message(String? value) => _is.ColumnValue(
    table.message,
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

  _is.ColumnValue<int, int> handledById(int? value) => _is.ColumnValue(
    table.handledById,
    value,
  );

  _is.ColumnValue<
    _iy0p00sl.AccessRequestOutcome,
    _iy0p00sl.AccessRequestOutcome
  >
  outcome(_iy0p00sl.AccessRequestOutcome? value) => _is.ColumnValue(
    table.outcome,
    value,
  );
}

class AccessRequestTable extends _is.Table<int?> {
  AccessRequestTable({super.tableRelation})
    : super(tableName: 'access_request') {
    updateTable = AccessRequestUpdateTable(this);
    itemId = _is.ColumnInt(
      'itemId',
      this,
    );
    requesterId = _is.ColumnInt(
      'requesterId',
      this,
    );
    requestedRole = _is.ColumnEnum(
      'requestedRole',
      this,
      _is.EnumSerialization.byName,
    );
    message = _is.ColumnString(
      'message',
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
    handledById = _is.ColumnInt(
      'handledById',
      this,
    );
    outcome = _is.ColumnEnum(
      'outcome',
      this,
      _is.EnumSerialization.byName,
    );
  }

  late final AccessRequestUpdateTable updateTable;

  late final _is.ColumnInt itemId;

  late final _is.ColumnInt requesterId;

  late final _is.ColumnEnum<_iv7g6vuy.AccessRole> requestedRole;

  late final _is.ColumnString message;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime handledAt;

  late final _is.ColumnInt handledById;

  late final _is.ColumnEnum<_iy0p00sl.AccessRequestOutcome> outcome;

  @override
  List<_is.Column> get columns => [
    id,
    itemId,
    requesterId,
    requestedRole,
    message,
    createdAt,
    handledAt,
    handledById,
    outcome,
  ];
}

class AccessRequestInclude extends _is.IncludeObject {
  AccessRequestInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => AccessRequest.t;
}

class AccessRequestIncludeList extends _is.IncludeList {
  AccessRequestIncludeList._({
    _is.WhereExpressionBuilder<AccessRequestTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AccessRequest.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => AccessRequest.t;
}

class AccessRequestRepository {
  const AccessRequestRepository._();

  /// Returns a list of [AccessRequest]s matching the given query parameters.
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
  Future<List<AccessRequest>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AccessRequestTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AccessRequestTable>? orderBy,
    _is.OrderByListBuilder<AccessRequestTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AccessRequest>(
      where: where?.call(AccessRequest.t),
      orderBy: orderBy?.call(AccessRequest.t),
      orderByList: orderByList?.call(AccessRequest.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [AccessRequest]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `AccessRequest.t`.
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
  _ida.Stream<List<AccessRequest>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AccessRequestTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AccessRequestTable>? orderBy,
    _is.OrderByListBuilder<AccessRequestTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<AccessRequest>(
      where: where?.call(AccessRequest.t),
      orderBy: orderBy?.call(AccessRequest.t),
      orderByList: orderByList?.call(AccessRequest.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [AccessRequest] matching the given query parameters.
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
  Future<AccessRequest?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AccessRequestTable>? where,
    int? offset,
    _is.OrderByBuilder<AccessRequestTable>? orderBy,
    _is.OrderByListBuilder<AccessRequestTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AccessRequest>(
      where: where?.call(AccessRequest.t),
      orderBy: orderBy?.call(AccessRequest.t),
      orderByList: orderByList?.call(AccessRequest.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AccessRequest] by its [id] or null if no such row exists.
  Future<AccessRequest?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AccessRequest>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AccessRequest]s in the list and returns the inserted rows.
  ///
  /// The returned [AccessRequest]s will have their `id` fields set.
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
  Future<List<AccessRequest>> insert(
    _is.DatabaseSession session,
    List<AccessRequest> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<AccessRequest>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [AccessRequest] and returns the inserted row.
  ///
  /// The returned [AccessRequest] will have its `id` field set.
  Future<AccessRequest> insertRow(
    _is.DatabaseSession session,
    AccessRequest row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<AccessRequest>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [AccessRequest]s in the list and returns the resulting rows.
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
  /// The returned [AccessRequest]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AccessRequest>> upsert(
    _is.DatabaseSession session,
    List<AccessRequest> rows, {
    required _is.ColumnSelections<AccessRequestTable> conflictColumns,
    _is.ColumnSelections<AccessRequestTable>? updateColumns,
    _is.WhereExpressionBuilder<AccessRequestTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<AccessRequest>(
      rows,
      conflictColumns: conflictColumns(AccessRequest.t),
      updateColumns: updateColumns?.call(AccessRequest.t),
      updateWhere: updateWhere?.call(AccessRequest.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [AccessRequest] and returns the resulting row.
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
  /// The returned [AccessRequest] will have its `id` field set.
  Future<AccessRequest?> upsertRow(
    _is.DatabaseSession session,
    AccessRequest row, {
    required _is.ColumnSelections<AccessRequestTable> conflictColumns,
    _is.ColumnSelections<AccessRequestTable>? updateColumns,
    _is.WhereExpressionBuilder<AccessRequestTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<AccessRequest>(
      row,
      conflictColumns: conflictColumns(AccessRequest.t),
      updateColumns: updateColumns?.call(AccessRequest.t),
      updateWhere: updateWhere?.call(AccessRequest.t),
      transaction: transaction,
    );
  }

  /// Updates all [AccessRequest]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AccessRequest>> update(
    _is.DatabaseSession session,
    List<AccessRequest> rows, {
    _is.ColumnSelections<AccessRequestTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<AccessRequest>(
      rows,
      columns: columns?.call(AccessRequest.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [AccessRequest]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AccessRequest> updateRow(
    _is.DatabaseSession session,
    AccessRequest row, {
    _is.ColumnSelections<AccessRequestTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<AccessRequest>(
      row,
      columns: columns?.call(AccessRequest.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AccessRequest] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AccessRequest?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<AccessRequestUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<AccessRequest>(
      id,
      columnValues: columnValues(AccessRequest.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AccessRequest]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AccessRequest>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<AccessRequestUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<AccessRequestTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AccessRequestTable>? orderBy,
    _is.OrderByListBuilder<AccessRequestTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<AccessRequest>(
      columnValues: columnValues(AccessRequest.t.updateTable),
      where: where(AccessRequest.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AccessRequest.t),
      orderByList: orderByList?.call(AccessRequest.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [AccessRequest]s in the list and returns the deleted rows.
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
  Future<List<AccessRequest>> delete(
    _is.DatabaseSession session,
    List<AccessRequest> rows, {
    _is.OrderByBuilder<AccessRequestTable>? orderBy,
    _is.OrderByListBuilder<AccessRequestTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<AccessRequest>(
      rows,
      orderBy: orderBy?.call(AccessRequest.t),
      orderByList: orderByList?.call(AccessRequest.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [AccessRequest].
  Future<AccessRequest> deleteRow(
    _is.DatabaseSession session,
    AccessRequest row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AccessRequest>(
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
  Future<List<AccessRequest>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AccessRequestTable> where,
    _is.OrderByBuilder<AccessRequestTable>? orderBy,
    _is.OrderByListBuilder<AccessRequestTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<AccessRequest>(
      where: where(AccessRequest.t),
      orderBy: orderBy?.call(AccessRequest.t),
      orderByList: orderByList?.call(AccessRequest.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AccessRequestTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<AccessRequest>(
      where: where?.call(AccessRequest.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AccessRequest] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AccessRequestTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AccessRequest>(
      where: where(AccessRequest.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
