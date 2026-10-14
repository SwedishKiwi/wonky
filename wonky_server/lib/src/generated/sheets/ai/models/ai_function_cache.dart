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

/// Cached results of `=AI(prompt, ranges…)` cells (Sheets 12 §6.8): one
/// row per sha256(model ‖ prompt ‖ canonical JSON of the referenced
/// values). A cell is never recomputed unless its inputs change or the
/// user refreshes it.
abstract class AiFunctionCache
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  AiFunctionCache._({
    this.id,
    required this.key,
    required this.spreadsheetUuid,
    required this.model,
    required this.value,
    this.error,
    required this.createdAt,
    int? hits,
  }) : hits = hits ?? 0;

  factory AiFunctionCache({
    int? id,
    required String key,
    required _is.UuidValue spreadsheetUuid,
    required String model,
    required String value,
    String? error,
    required DateTime createdAt,
    int? hits,
  }) = _AiFunctionCacheImpl;

  factory AiFunctionCache.fromJson(Map<String, dynamic> jsonSerialization) {
    return AiFunctionCache(
      id: jsonSerialization['id'] as int?,
      key: jsonSerialization['key'] as String,
      spreadsheetUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spreadsheetUuid'],
      ),
      model: jsonSerialization['model'] as String,
      value: jsonSerialization['value'] as String,
      error: jsonSerialization['error'] as String?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      hits: jsonSerialization['hits'] as int?,
    );
  }

  static final t = AiFunctionCacheTable();

  static const db = AiFunctionCacheRepository._();

  @override
  int? id;

  String key;

  _is.UuidValue spreadsheetUuid;

  String model;

  String value;

  /// Set when the model failed (`#AI_ERROR!` with this tooltip).
  String? error;

  DateTime createdAt;

  int hits;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [AiFunctionCache]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AiFunctionCache copyWith({
    int? id,
    String? key,
    _is.UuidValue? spreadsheetUuid,
    String? model,
    String? value,
    String? error,
    DateTime? createdAt,
    int? hits,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AiFunctionCache',
      if (id != null) 'id': id,
      'key': key,
      'spreadsheetUuid': spreadsheetUuid.toJson(),
      'model': model,
      'value': value,
      if (error != null) 'error': error,
      'createdAt': createdAt.toJson(),
      'hits': hits,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static AiFunctionCacheInclude include() {
    return AiFunctionCacheInclude._();
  }

  static AiFunctionCacheIncludeList includeList({
    _is.WhereExpressionBuilder<AiFunctionCacheTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiFunctionCacheTable>? orderBy,
    _is.OrderByListBuilder<AiFunctionCacheTable>? orderByList,
    AiFunctionCacheInclude? include,
  }) {
    return AiFunctionCacheIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AiFunctionCache.t),
      orderByList: orderByList?.call(AiFunctionCache.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AiFunctionCacheImpl extends AiFunctionCache {
  _AiFunctionCacheImpl({
    int? id,
    required String key,
    required _is.UuidValue spreadsheetUuid,
    required String model,
    required String value,
    String? error,
    required DateTime createdAt,
    int? hits,
  }) : super._(
         id: id,
         key: key,
         spreadsheetUuid: spreadsheetUuid,
         model: model,
         value: value,
         error: error,
         createdAt: createdAt,
         hits: hits,
       );

  /// Returns a shallow copy of this [AiFunctionCache]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AiFunctionCache copyWith({
    Object? id = _Undefined,
    String? key,
    _is.UuidValue? spreadsheetUuid,
    String? model,
    String? value,
    Object? error = _Undefined,
    DateTime? createdAt,
    int? hits,
  }) {
    return AiFunctionCache(
      id: id is int? ? id : this.id,
      key: key ?? this.key,
      spreadsheetUuid: spreadsheetUuid ?? this.spreadsheetUuid,
      model: model ?? this.model,
      value: value ?? this.value,
      error: error is String? ? error : this.error,
      createdAt: createdAt ?? this.createdAt,
      hits: hits ?? this.hits,
    );
  }
}

class AiFunctionCacheUpdateTable extends _is.UpdateTable<AiFunctionCacheTable> {
  AiFunctionCacheUpdateTable(super.table);

  _is.ColumnValue<String, String> key(String value) => _is.ColumnValue(
    table.key,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> spreadsheetUuid(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.spreadsheetUuid,
    value,
  );

  _is.ColumnValue<String, String> model(String value) => _is.ColumnValue(
    table.model,
    value,
  );

  _is.ColumnValue<String, String> value(String value) => _is.ColumnValue(
    table.value,
    value,
  );

  _is.ColumnValue<String, String> error(String? value) => _is.ColumnValue(
    table.error,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<int, int> hits(int value) => _is.ColumnValue(
    table.hits,
    value,
  );
}

class AiFunctionCacheTable extends _is.Table<int?> {
  AiFunctionCacheTable({super.tableRelation})
    : super(tableName: 'ai_function_cache') {
    updateTable = AiFunctionCacheUpdateTable(this);
    key = _is.ColumnString(
      'key',
      this,
    );
    spreadsheetUuid = _is.ColumnUuid(
      'spreadsheetUuid',
      this,
    );
    model = _is.ColumnString(
      'model',
      this,
    );
    value = _is.ColumnString(
      'value',
      this,
    );
    error = _is.ColumnString(
      'error',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    hits = _is.ColumnInt(
      'hits',
      this,
      hasDefault: true,
    );
  }

  late final AiFunctionCacheUpdateTable updateTable;

  late final _is.ColumnString key;

  late final _is.ColumnUuid spreadsheetUuid;

  late final _is.ColumnString model;

  late final _is.ColumnString value;

  /// Set when the model failed (`#AI_ERROR!` with this tooltip).
  late final _is.ColumnString error;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnInt hits;

  @override
  List<_is.Column> get columns => [
    id,
    key,
    spreadsheetUuid,
    model,
    value,
    error,
    createdAt,
    hits,
  ];
}

class AiFunctionCacheInclude extends _is.IncludeObject {
  AiFunctionCacheInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => AiFunctionCache.t;
}

class AiFunctionCacheIncludeList extends _is.IncludeList {
  AiFunctionCacheIncludeList._({
    _is.WhereExpressionBuilder<AiFunctionCacheTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AiFunctionCache.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => AiFunctionCache.t;
}

class AiFunctionCacheRepository {
  const AiFunctionCacheRepository._();

  /// Returns a list of [AiFunctionCache]s matching the given query parameters.
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
  Future<List<AiFunctionCache>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiFunctionCacheTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiFunctionCacheTable>? orderBy,
    _is.OrderByListBuilder<AiFunctionCacheTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AiFunctionCache>(
      where: where?.call(AiFunctionCache.t),
      orderBy: orderBy?.call(AiFunctionCache.t),
      orderByList: orderByList?.call(AiFunctionCache.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [AiFunctionCache]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `AiFunctionCache.t`.
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
  _ida.Stream<List<AiFunctionCache>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiFunctionCacheTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiFunctionCacheTable>? orderBy,
    _is.OrderByListBuilder<AiFunctionCacheTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<AiFunctionCache>(
      where: where?.call(AiFunctionCache.t),
      orderBy: orderBy?.call(AiFunctionCache.t),
      orderByList: orderByList?.call(AiFunctionCache.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [AiFunctionCache] matching the given query parameters.
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
  Future<AiFunctionCache?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiFunctionCacheTable>? where,
    int? offset,
    _is.OrderByBuilder<AiFunctionCacheTable>? orderBy,
    _is.OrderByListBuilder<AiFunctionCacheTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AiFunctionCache>(
      where: where?.call(AiFunctionCache.t),
      orderBy: orderBy?.call(AiFunctionCache.t),
      orderByList: orderByList?.call(AiFunctionCache.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AiFunctionCache] by its [id] or null if no such row exists.
  Future<AiFunctionCache?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AiFunctionCache>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AiFunctionCache]s in the list and returns the inserted rows.
  ///
  /// The returned [AiFunctionCache]s will have their `id` fields set.
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
  Future<List<AiFunctionCache>> insert(
    _is.DatabaseSession session,
    List<AiFunctionCache> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<AiFunctionCache>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [AiFunctionCache] and returns the inserted row.
  ///
  /// The returned [AiFunctionCache] will have its `id` field set.
  Future<AiFunctionCache> insertRow(
    _is.DatabaseSession session,
    AiFunctionCache row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<AiFunctionCache>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [AiFunctionCache]s in the list and returns the resulting rows.
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
  /// The returned [AiFunctionCache]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AiFunctionCache>> upsert(
    _is.DatabaseSession session,
    List<AiFunctionCache> rows, {
    required _is.ColumnSelections<AiFunctionCacheTable> conflictColumns,
    _is.ColumnSelections<AiFunctionCacheTable>? updateColumns,
    _is.WhereExpressionBuilder<AiFunctionCacheTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<AiFunctionCache>(
      rows,
      conflictColumns: conflictColumns(AiFunctionCache.t),
      updateColumns: updateColumns?.call(AiFunctionCache.t),
      updateWhere: updateWhere?.call(AiFunctionCache.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [AiFunctionCache] and returns the resulting row.
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
  /// The returned [AiFunctionCache] will have its `id` field set.
  Future<AiFunctionCache?> upsertRow(
    _is.DatabaseSession session,
    AiFunctionCache row, {
    required _is.ColumnSelections<AiFunctionCacheTable> conflictColumns,
    _is.ColumnSelections<AiFunctionCacheTable>? updateColumns,
    _is.WhereExpressionBuilder<AiFunctionCacheTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<AiFunctionCache>(
      row,
      conflictColumns: conflictColumns(AiFunctionCache.t),
      updateColumns: updateColumns?.call(AiFunctionCache.t),
      updateWhere: updateWhere?.call(AiFunctionCache.t),
      transaction: transaction,
    );
  }

  /// Updates all [AiFunctionCache]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AiFunctionCache>> update(
    _is.DatabaseSession session,
    List<AiFunctionCache> rows, {
    _is.ColumnSelections<AiFunctionCacheTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<AiFunctionCache>(
      rows,
      columns: columns?.call(AiFunctionCache.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [AiFunctionCache]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AiFunctionCache> updateRow(
    _is.DatabaseSession session,
    AiFunctionCache row, {
    _is.ColumnSelections<AiFunctionCacheTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<AiFunctionCache>(
      row,
      columns: columns?.call(AiFunctionCache.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AiFunctionCache] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AiFunctionCache?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<AiFunctionCacheUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<AiFunctionCache>(
      id,
      columnValues: columnValues(AiFunctionCache.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AiFunctionCache]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AiFunctionCache>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<AiFunctionCacheUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<AiFunctionCacheTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiFunctionCacheTable>? orderBy,
    _is.OrderByListBuilder<AiFunctionCacheTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<AiFunctionCache>(
      columnValues: columnValues(AiFunctionCache.t.updateTable),
      where: where(AiFunctionCache.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AiFunctionCache.t),
      orderByList: orderByList?.call(AiFunctionCache.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [AiFunctionCache]s in the list and returns the deleted rows.
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
  Future<List<AiFunctionCache>> delete(
    _is.DatabaseSession session,
    List<AiFunctionCache> rows, {
    _is.OrderByBuilder<AiFunctionCacheTable>? orderBy,
    _is.OrderByListBuilder<AiFunctionCacheTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<AiFunctionCache>(
      rows,
      orderBy: orderBy?.call(AiFunctionCache.t),
      orderByList: orderByList?.call(AiFunctionCache.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [AiFunctionCache].
  Future<AiFunctionCache> deleteRow(
    _is.DatabaseSession session,
    AiFunctionCache row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AiFunctionCache>(
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
  Future<List<AiFunctionCache>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AiFunctionCacheTable> where,
    _is.OrderByBuilder<AiFunctionCacheTable>? orderBy,
    _is.OrderByListBuilder<AiFunctionCacheTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<AiFunctionCache>(
      where: where(AiFunctionCache.t),
      orderBy: orderBy?.call(AiFunctionCache.t),
      orderByList: orderByList?.call(AiFunctionCache.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiFunctionCacheTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<AiFunctionCache>(
      where: where?.call(AiFunctionCache.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AiFunctionCache] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AiFunctionCacheTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AiFunctionCache>(
      where: where(AiFunctionCache.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
