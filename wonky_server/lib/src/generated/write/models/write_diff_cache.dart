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

abstract class WriteDiffCache
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  WriteDiffCache._({
    this.id,
    required this.documentId,
    required this.fromRevision,
    required this.toRevision,
    required this.json,
    required this.createdAt,
  });

  factory WriteDiffCache({
    int? id,
    required int documentId,
    required int fromRevision,
    required int toRevision,
    required String json,
    required DateTime createdAt,
  }) = _WriteDiffCacheImpl;

  factory WriteDiffCache.fromJson(Map<String, dynamic> jsonSerialization) {
    return WriteDiffCache(
      id: jsonSerialization['id'] as int?,
      documentId: jsonSerialization['documentId'] as int,
      fromRevision: jsonSerialization['fromRevision'] as int,
      toRevision: jsonSerialization['toRevision'] as int,
      json: jsonSerialization['json'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = WriteDiffCacheTable();

  static const db = WriteDiffCacheRepository._();

  @override
  int? id;

  int documentId;

  int fromRevision;

  int toRevision;

  String json;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [WriteDiffCache]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WriteDiffCache copyWith({
    int? id,
    int? documentId,
    int? fromRevision,
    int? toRevision,
    String? json,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WriteDiffCache',
      if (id != null) 'id': id,
      'documentId': documentId,
      'fromRevision': fromRevision,
      'toRevision': toRevision,
      'json': json,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WriteDiffCacheInclude include() {
    return WriteDiffCacheInclude._();
  }

  static WriteDiffCacheIncludeList includeList({
    _is.WhereExpressionBuilder<WriteDiffCacheTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WriteDiffCacheTable>? orderBy,
    _is.OrderByListBuilder<WriteDiffCacheTable>? orderByList,
    WriteDiffCacheInclude? include,
  }) {
    return WriteDiffCacheIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WriteDiffCache.t),
      orderByList: orderByList?.call(WriteDiffCache.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WriteDiffCacheImpl extends WriteDiffCache {
  _WriteDiffCacheImpl({
    int? id,
    required int documentId,
    required int fromRevision,
    required int toRevision,
    required String json,
    required DateTime createdAt,
  }) : super._(
         id: id,
         documentId: documentId,
         fromRevision: fromRevision,
         toRevision: toRevision,
         json: json,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [WriteDiffCache]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WriteDiffCache copyWith({
    Object? id = _Undefined,
    int? documentId,
    int? fromRevision,
    int? toRevision,
    String? json,
    DateTime? createdAt,
  }) {
    return WriteDiffCache(
      id: id is int? ? id : this.id,
      documentId: documentId ?? this.documentId,
      fromRevision: fromRevision ?? this.fromRevision,
      toRevision: toRevision ?? this.toRevision,
      json: json ?? this.json,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WriteDiffCacheUpdateTable extends _is.UpdateTable<WriteDiffCacheTable> {
  WriteDiffCacheUpdateTable(super.table);

  _is.ColumnValue<int, int> documentId(int value) => _is.ColumnValue(
    table.documentId,
    value,
  );

  _is.ColumnValue<int, int> fromRevision(int value) => _is.ColumnValue(
    table.fromRevision,
    value,
  );

  _is.ColumnValue<int, int> toRevision(int value) => _is.ColumnValue(
    table.toRevision,
    value,
  );

  _is.ColumnValue<String, String> json(String value) => _is.ColumnValue(
    table.json,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class WriteDiffCacheTable extends _is.Table<int?> {
  WriteDiffCacheTable({super.tableRelation})
    : super(tableName: 'write_diff_cache') {
    updateTable = WriteDiffCacheUpdateTable(this);
    documentId = _is.ColumnInt(
      'documentId',
      this,
    );
    fromRevision = _is.ColumnInt(
      'fromRevision',
      this,
    );
    toRevision = _is.ColumnInt(
      'toRevision',
      this,
    );
    json = _is.ColumnString(
      'json',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final WriteDiffCacheUpdateTable updateTable;

  late final _is.ColumnInt documentId;

  late final _is.ColumnInt fromRevision;

  late final _is.ColumnInt toRevision;

  late final _is.ColumnString json;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    documentId,
    fromRevision,
    toRevision,
    json,
    createdAt,
  ];
}

class WriteDiffCacheInclude extends _is.IncludeObject {
  WriteDiffCacheInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => WriteDiffCache.t;
}

class WriteDiffCacheIncludeList extends _is.IncludeList {
  WriteDiffCacheIncludeList._({
    _is.WhereExpressionBuilder<WriteDiffCacheTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WriteDiffCache.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => WriteDiffCache.t;
}

class WriteDiffCacheRepository {
  const WriteDiffCacheRepository._();

  /// Returns a list of [WriteDiffCache]s matching the given query parameters.
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
  Future<List<WriteDiffCache>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WriteDiffCacheTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WriteDiffCacheTable>? orderBy,
    _is.OrderByListBuilder<WriteDiffCacheTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WriteDiffCache>(
      where: where?.call(WriteDiffCache.t),
      orderBy: orderBy?.call(WriteDiffCache.t),
      orderByList: orderByList?.call(WriteDiffCache.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [WriteDiffCache]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `WriteDiffCache.t`.
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
  _ida.Stream<List<WriteDiffCache>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WriteDiffCacheTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WriteDiffCacheTable>? orderBy,
    _is.OrderByListBuilder<WriteDiffCacheTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<WriteDiffCache>(
      where: where?.call(WriteDiffCache.t),
      orderBy: orderBy?.call(WriteDiffCache.t),
      orderByList: orderByList?.call(WriteDiffCache.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [WriteDiffCache] matching the given query parameters.
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
  Future<WriteDiffCache?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WriteDiffCacheTable>? where,
    int? offset,
    _is.OrderByBuilder<WriteDiffCacheTable>? orderBy,
    _is.OrderByListBuilder<WriteDiffCacheTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WriteDiffCache>(
      where: where?.call(WriteDiffCache.t),
      orderBy: orderBy?.call(WriteDiffCache.t),
      orderByList: orderByList?.call(WriteDiffCache.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WriteDiffCache] by its [id] or null if no such row exists.
  Future<WriteDiffCache?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WriteDiffCache>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WriteDiffCache]s in the list and returns the inserted rows.
  ///
  /// The returned [WriteDiffCache]s will have their `id` fields set.
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
  Future<List<WriteDiffCache>> insert(
    _is.DatabaseSession session,
    List<WriteDiffCache> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<WriteDiffCache>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [WriteDiffCache] and returns the inserted row.
  ///
  /// The returned [WriteDiffCache] will have its `id` field set.
  Future<WriteDiffCache> insertRow(
    _is.DatabaseSession session,
    WriteDiffCache row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<WriteDiffCache>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [WriteDiffCache]s in the list and returns the resulting rows.
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
  /// The returned [WriteDiffCache]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WriteDiffCache>> upsert(
    _is.DatabaseSession session,
    List<WriteDiffCache> rows, {
    required _is.ColumnSelections<WriteDiffCacheTable> conflictColumns,
    _is.ColumnSelections<WriteDiffCacheTable>? updateColumns,
    _is.WhereExpressionBuilder<WriteDiffCacheTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<WriteDiffCache>(
      rows,
      conflictColumns: conflictColumns(WriteDiffCache.t),
      updateColumns: updateColumns?.call(WriteDiffCache.t),
      updateWhere: updateWhere?.call(WriteDiffCache.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [WriteDiffCache] and returns the resulting row.
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
  /// The returned [WriteDiffCache] will have its `id` field set.
  Future<WriteDiffCache?> upsertRow(
    _is.DatabaseSession session,
    WriteDiffCache row, {
    required _is.ColumnSelections<WriteDiffCacheTable> conflictColumns,
    _is.ColumnSelections<WriteDiffCacheTable>? updateColumns,
    _is.WhereExpressionBuilder<WriteDiffCacheTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<WriteDiffCache>(
      row,
      conflictColumns: conflictColumns(WriteDiffCache.t),
      updateColumns: updateColumns?.call(WriteDiffCache.t),
      updateWhere: updateWhere?.call(WriteDiffCache.t),
      transaction: transaction,
    );
  }

  /// Updates all [WriteDiffCache]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WriteDiffCache>> update(
    _is.DatabaseSession session,
    List<WriteDiffCache> rows, {
    _is.ColumnSelections<WriteDiffCacheTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<WriteDiffCache>(
      rows,
      columns: columns?.call(WriteDiffCache.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [WriteDiffCache]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WriteDiffCache> updateRow(
    _is.DatabaseSession session,
    WriteDiffCache row, {
    _is.ColumnSelections<WriteDiffCacheTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<WriteDiffCache>(
      row,
      columns: columns?.call(WriteDiffCache.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WriteDiffCache] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WriteDiffCache?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<WriteDiffCacheUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<WriteDiffCache>(
      id,
      columnValues: columnValues(WriteDiffCache.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WriteDiffCache]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WriteDiffCache>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<WriteDiffCacheUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<WriteDiffCacheTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WriteDiffCacheTable>? orderBy,
    _is.OrderByListBuilder<WriteDiffCacheTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<WriteDiffCache>(
      columnValues: columnValues(WriteDiffCache.t.updateTable),
      where: where(WriteDiffCache.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WriteDiffCache.t),
      orderByList: orderByList?.call(WriteDiffCache.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [WriteDiffCache]s in the list and returns the deleted rows.
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
  Future<List<WriteDiffCache>> delete(
    _is.DatabaseSession session,
    List<WriteDiffCache> rows, {
    _is.OrderByBuilder<WriteDiffCacheTable>? orderBy,
    _is.OrderByListBuilder<WriteDiffCacheTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<WriteDiffCache>(
      rows,
      orderBy: orderBy?.call(WriteDiffCache.t),
      orderByList: orderByList?.call(WriteDiffCache.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [WriteDiffCache].
  Future<WriteDiffCache> deleteRow(
    _is.DatabaseSession session,
    WriteDiffCache row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WriteDiffCache>(
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
  Future<List<WriteDiffCache>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WriteDiffCacheTable> where,
    _is.OrderByBuilder<WriteDiffCacheTable>? orderBy,
    _is.OrderByListBuilder<WriteDiffCacheTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<WriteDiffCache>(
      where: where(WriteDiffCache.t),
      orderBy: orderBy?.call(WriteDiffCache.t),
      orderByList: orderByList?.call(WriteDiffCache.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WriteDiffCacheTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<WriteDiffCache>(
      where: where?.call(WriteDiffCache.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WriteDiffCache] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WriteDiffCacheTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WriteDiffCache>(
      where: where(WriteDiffCache.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
