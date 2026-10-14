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

/// Daily script usage per user (Sheets 09 §10); day = UTC date.
abstract class ScriptQuotaUsage
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  ScriptQuotaUsage._({
    this.id,
    required this.userId,
    required this.day,
    int? serverRuntimeMs,
    int? clientRuntimeMs,
    int? urlFetchCalls,
    int? urlFetchBytes,
    int? triggerRuns,
  }) : serverRuntimeMs = serverRuntimeMs ?? 0,
       clientRuntimeMs = clientRuntimeMs ?? 0,
       urlFetchCalls = urlFetchCalls ?? 0,
       urlFetchBytes = urlFetchBytes ?? 0,
       triggerRuns = triggerRuns ?? 0;

  factory ScriptQuotaUsage({
    int? id,
    required int userId,
    required DateTime day,
    int? serverRuntimeMs,
    int? clientRuntimeMs,
    int? urlFetchCalls,
    int? urlFetchBytes,
    int? triggerRuns,
  }) = _ScriptQuotaUsageImpl;

  factory ScriptQuotaUsage.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScriptQuotaUsage(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      day: _is.DateTimeJsonExtension.fromJson(jsonSerialization['day']),
      serverRuntimeMs: jsonSerialization['serverRuntimeMs'] as int?,
      clientRuntimeMs: jsonSerialization['clientRuntimeMs'] as int?,
      urlFetchCalls: jsonSerialization['urlFetchCalls'] as int?,
      urlFetchBytes: jsonSerialization['urlFetchBytes'] as int?,
      triggerRuns: jsonSerialization['triggerRuns'] as int?,
    );
  }

  static final t = ScriptQuotaUsageTable();

  static const db = ScriptQuotaUsageRepository._();

  @override
  int? id;

  int userId;

  DateTime day;

  int serverRuntimeMs;

  int clientRuntimeMs;

  int urlFetchCalls;

  int urlFetchBytes;

  int triggerRuns;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [ScriptQuotaUsage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ScriptQuotaUsage copyWith({
    int? id,
    int? userId,
    DateTime? day,
    int? serverRuntimeMs,
    int? clientRuntimeMs,
    int? urlFetchCalls,
    int? urlFetchBytes,
    int? triggerRuns,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScriptQuotaUsage',
      if (id != null) 'id': id,
      'userId': userId,
      'day': day.toJson(),
      'serverRuntimeMs': serverRuntimeMs,
      'clientRuntimeMs': clientRuntimeMs,
      'urlFetchCalls': urlFetchCalls,
      'urlFetchBytes': urlFetchBytes,
      'triggerRuns': triggerRuns,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ScriptQuotaUsageInclude include() {
    return ScriptQuotaUsageInclude._();
  }

  static ScriptQuotaUsageIncludeList includeList({
    _is.WhereExpressionBuilder<ScriptQuotaUsageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptQuotaUsageTable>? orderBy,
    _is.OrderByListBuilder<ScriptQuotaUsageTable>? orderByList,
    ScriptQuotaUsageInclude? include,
  }) {
    return ScriptQuotaUsageIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptQuotaUsage.t),
      orderByList: orderByList?.call(ScriptQuotaUsage.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ScriptQuotaUsageImpl extends ScriptQuotaUsage {
  _ScriptQuotaUsageImpl({
    int? id,
    required int userId,
    required DateTime day,
    int? serverRuntimeMs,
    int? clientRuntimeMs,
    int? urlFetchCalls,
    int? urlFetchBytes,
    int? triggerRuns,
  }) : super._(
         id: id,
         userId: userId,
         day: day,
         serverRuntimeMs: serverRuntimeMs,
         clientRuntimeMs: clientRuntimeMs,
         urlFetchCalls: urlFetchCalls,
         urlFetchBytes: urlFetchBytes,
         triggerRuns: triggerRuns,
       );

  /// Returns a shallow copy of this [ScriptQuotaUsage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ScriptQuotaUsage copyWith({
    Object? id = _Undefined,
    int? userId,
    DateTime? day,
    int? serverRuntimeMs,
    int? clientRuntimeMs,
    int? urlFetchCalls,
    int? urlFetchBytes,
    int? triggerRuns,
  }) {
    return ScriptQuotaUsage(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      day: day ?? this.day,
      serverRuntimeMs: serverRuntimeMs ?? this.serverRuntimeMs,
      clientRuntimeMs: clientRuntimeMs ?? this.clientRuntimeMs,
      urlFetchCalls: urlFetchCalls ?? this.urlFetchCalls,
      urlFetchBytes: urlFetchBytes ?? this.urlFetchBytes,
      triggerRuns: triggerRuns ?? this.triggerRuns,
    );
  }
}

class ScriptQuotaUsageUpdateTable
    extends _is.UpdateTable<ScriptQuotaUsageTable> {
  ScriptQuotaUsageUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> day(DateTime value) => _is.ColumnValue(
    table.day,
    value,
  );

  _is.ColumnValue<int, int> serverRuntimeMs(int value) => _is.ColumnValue(
    table.serverRuntimeMs,
    value,
  );

  _is.ColumnValue<int, int> clientRuntimeMs(int value) => _is.ColumnValue(
    table.clientRuntimeMs,
    value,
  );

  _is.ColumnValue<int, int> urlFetchCalls(int value) => _is.ColumnValue(
    table.urlFetchCalls,
    value,
  );

  _is.ColumnValue<int, int> urlFetchBytes(int value) => _is.ColumnValue(
    table.urlFetchBytes,
    value,
  );

  _is.ColumnValue<int, int> triggerRuns(int value) => _is.ColumnValue(
    table.triggerRuns,
    value,
  );
}

class ScriptQuotaUsageTable extends _is.Table<int?> {
  ScriptQuotaUsageTable({super.tableRelation})
    : super(tableName: 'script_quota_usage') {
    updateTable = ScriptQuotaUsageUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    day = _is.ColumnDateTime(
      'day',
      this,
    );
    serverRuntimeMs = _is.ColumnInt(
      'serverRuntimeMs',
      this,
      hasDefault: true,
    );
    clientRuntimeMs = _is.ColumnInt(
      'clientRuntimeMs',
      this,
      hasDefault: true,
    );
    urlFetchCalls = _is.ColumnInt(
      'urlFetchCalls',
      this,
      hasDefault: true,
    );
    urlFetchBytes = _is.ColumnInt(
      'urlFetchBytes',
      this,
      hasDefault: true,
    );
    triggerRuns = _is.ColumnInt(
      'triggerRuns',
      this,
      hasDefault: true,
    );
  }

  late final ScriptQuotaUsageUpdateTable updateTable;

  late final _is.ColumnInt userId;

  late final _is.ColumnDateTime day;

  late final _is.ColumnInt serverRuntimeMs;

  late final _is.ColumnInt clientRuntimeMs;

  late final _is.ColumnInt urlFetchCalls;

  late final _is.ColumnInt urlFetchBytes;

  late final _is.ColumnInt triggerRuns;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    day,
    serverRuntimeMs,
    clientRuntimeMs,
    urlFetchCalls,
    urlFetchBytes,
    triggerRuns,
  ];
}

class ScriptQuotaUsageInclude extends _is.IncludeObject {
  ScriptQuotaUsageInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => ScriptQuotaUsage.t;
}

class ScriptQuotaUsageIncludeList extends _is.IncludeList {
  ScriptQuotaUsageIncludeList._({
    _is.WhereExpressionBuilder<ScriptQuotaUsageTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ScriptQuotaUsage.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => ScriptQuotaUsage.t;
}

class ScriptQuotaUsageRepository {
  const ScriptQuotaUsageRepository._();

  /// Returns a list of [ScriptQuotaUsage]s matching the given query parameters.
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
  Future<List<ScriptQuotaUsage>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptQuotaUsageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptQuotaUsageTable>? orderBy,
    _is.OrderByListBuilder<ScriptQuotaUsageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ScriptQuotaUsage>(
      where: where?.call(ScriptQuotaUsage.t),
      orderBy: orderBy?.call(ScriptQuotaUsage.t),
      orderByList: orderByList?.call(ScriptQuotaUsage.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ScriptQuotaUsage]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ScriptQuotaUsage.t`.
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
  _ida.Stream<List<ScriptQuotaUsage>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptQuotaUsageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptQuotaUsageTable>? orderBy,
    _is.OrderByListBuilder<ScriptQuotaUsageTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ScriptQuotaUsage>(
      where: where?.call(ScriptQuotaUsage.t),
      orderBy: orderBy?.call(ScriptQuotaUsage.t),
      orderByList: orderByList?.call(ScriptQuotaUsage.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ScriptQuotaUsage] matching the given query parameters.
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
  Future<ScriptQuotaUsage?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptQuotaUsageTable>? where,
    int? offset,
    _is.OrderByBuilder<ScriptQuotaUsageTable>? orderBy,
    _is.OrderByListBuilder<ScriptQuotaUsageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ScriptQuotaUsage>(
      where: where?.call(ScriptQuotaUsage.t),
      orderBy: orderBy?.call(ScriptQuotaUsage.t),
      orderByList: orderByList?.call(ScriptQuotaUsage.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ScriptQuotaUsage] by its [id] or null if no such row exists.
  Future<ScriptQuotaUsage?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ScriptQuotaUsage>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ScriptQuotaUsage]s in the list and returns the inserted rows.
  ///
  /// The returned [ScriptQuotaUsage]s will have their `id` fields set.
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
  Future<List<ScriptQuotaUsage>> insert(
    _is.DatabaseSession session,
    List<ScriptQuotaUsage> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ScriptQuotaUsage>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ScriptQuotaUsage] and returns the inserted row.
  ///
  /// The returned [ScriptQuotaUsage] will have its `id` field set.
  Future<ScriptQuotaUsage> insertRow(
    _is.DatabaseSession session,
    ScriptQuotaUsage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<ScriptQuotaUsage>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [ScriptQuotaUsage]s in the list and returns the resulting rows.
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
  /// The returned [ScriptQuotaUsage]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptQuotaUsage>> upsert(
    _is.DatabaseSession session,
    List<ScriptQuotaUsage> rows, {
    required _is.ColumnSelections<ScriptQuotaUsageTable> conflictColumns,
    _is.ColumnSelections<ScriptQuotaUsageTable>? updateColumns,
    _is.WhereExpressionBuilder<ScriptQuotaUsageTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ScriptQuotaUsage>(
      rows,
      conflictColumns: conflictColumns(ScriptQuotaUsage.t),
      updateColumns: updateColumns?.call(ScriptQuotaUsage.t),
      updateWhere: updateWhere?.call(ScriptQuotaUsage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ScriptQuotaUsage] and returns the resulting row.
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
  /// The returned [ScriptQuotaUsage] will have its `id` field set.
  Future<ScriptQuotaUsage?> upsertRow(
    _is.DatabaseSession session,
    ScriptQuotaUsage row, {
    required _is.ColumnSelections<ScriptQuotaUsageTable> conflictColumns,
    _is.ColumnSelections<ScriptQuotaUsageTable>? updateColumns,
    _is.WhereExpressionBuilder<ScriptQuotaUsageTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ScriptQuotaUsage>(
      row,
      conflictColumns: conflictColumns(ScriptQuotaUsage.t),
      updateColumns: updateColumns?.call(ScriptQuotaUsage.t),
      updateWhere: updateWhere?.call(ScriptQuotaUsage.t),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptQuotaUsage]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptQuotaUsage>> update(
    _is.DatabaseSession session,
    List<ScriptQuotaUsage> rows, {
    _is.ColumnSelections<ScriptQuotaUsageTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ScriptQuotaUsage>(
      rows,
      columns: columns?.call(ScriptQuotaUsage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ScriptQuotaUsage]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ScriptQuotaUsage> updateRow(
    _is.DatabaseSession session,
    ScriptQuotaUsage row, {
    _is.ColumnSelections<ScriptQuotaUsageTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<ScriptQuotaUsage>(
      row,
      columns: columns?.call(ScriptQuotaUsage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ScriptQuotaUsage] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ScriptQuotaUsage?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<ScriptQuotaUsageUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<ScriptQuotaUsage>(
      id,
      columnValues: columnValues(ScriptQuotaUsage.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptQuotaUsage]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptQuotaUsage>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<ScriptQuotaUsageUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<ScriptQuotaUsageTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptQuotaUsageTable>? orderBy,
    _is.OrderByListBuilder<ScriptQuotaUsageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ScriptQuotaUsage>(
      columnValues: columnValues(ScriptQuotaUsage.t.updateTable),
      where: where(ScriptQuotaUsage.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptQuotaUsage.t),
      orderByList: orderByList?.call(ScriptQuotaUsage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ScriptQuotaUsage]s in the list and returns the deleted rows.
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
  Future<List<ScriptQuotaUsage>> delete(
    _is.DatabaseSession session,
    List<ScriptQuotaUsage> rows, {
    _is.OrderByBuilder<ScriptQuotaUsageTable>? orderBy,
    _is.OrderByListBuilder<ScriptQuotaUsageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ScriptQuotaUsage>(
      rows,
      orderBy: orderBy?.call(ScriptQuotaUsage.t),
      orderByList: orderByList?.call(ScriptQuotaUsage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ScriptQuotaUsage].
  Future<ScriptQuotaUsage> deleteRow(
    _is.DatabaseSession session,
    ScriptQuotaUsage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ScriptQuotaUsage>(
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
  Future<List<ScriptQuotaUsage>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ScriptQuotaUsageTable> where,
    _is.OrderByBuilder<ScriptQuotaUsageTable>? orderBy,
    _is.OrderByListBuilder<ScriptQuotaUsageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ScriptQuotaUsage>(
      where: where(ScriptQuotaUsage.t),
      orderBy: orderBy?.call(ScriptQuotaUsage.t),
      orderByList: orderByList?.call(ScriptQuotaUsage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptQuotaUsageTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<ScriptQuotaUsage>(
      where: where?.call(ScriptQuotaUsage.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ScriptQuotaUsage] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ScriptQuotaUsageTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ScriptQuotaUsage>(
      where: where(ScriptQuotaUsage.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
