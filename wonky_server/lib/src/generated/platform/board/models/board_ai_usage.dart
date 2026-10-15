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

/// Daily usage of the board AI (Jev, Gemini), separate from `ai_usage`.
abstract class BoardAiUsage
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  BoardAiUsage._({
    this.id,
    required this.day,
    required this.provider,
    required this.model,
    required this.feature,
    required this.requests,
    required this.inputTokens,
    required this.outputTokens,
  });

  factory BoardAiUsage({
    int? id,
    required String day,
    required String provider,
    required String model,
    required String feature,
    required int requests,
    required int inputTokens,
    required int outputTokens,
  }) = _BoardAiUsageImpl;

  factory BoardAiUsage.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardAiUsage(
      id: jsonSerialization['id'] as int?,
      day: jsonSerialization['day'] as String,
      provider: jsonSerialization['provider'] as String,
      model: jsonSerialization['model'] as String,
      feature: jsonSerialization['feature'] as String,
      requests: jsonSerialization['requests'] as int,
      inputTokens: jsonSerialization['inputTokens'] as int,
      outputTokens: jsonSerialization['outputTokens'] as int,
    );
  }

  static final t = BoardAiUsageTable();

  static const db = BoardAiUsageRepository._();

  @override
  int? id;

  /// yyyy-mm-dd (UTC).
  String day;

  /// jev | gemini
  String provider;

  String model;

  String feature;

  int requests;

  int inputTokens;

  int outputTokens;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [BoardAiUsage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardAiUsage copyWith({
    int? id,
    String? day,
    String? provider,
    String? model,
    String? feature,
    int? requests,
    int? inputTokens,
    int? outputTokens,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardAiUsage',
      if (id != null) 'id': id,
      'day': day,
      'provider': provider,
      'model': model,
      'feature': feature,
      'requests': requests,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static BoardAiUsageInclude include() {
    return BoardAiUsageInclude._();
  }

  static BoardAiUsageIncludeList includeList({
    _is.WhereExpressionBuilder<BoardAiUsageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardAiUsageTable>? orderBy,
    _is.OrderByListBuilder<BoardAiUsageTable>? orderByList,
    BoardAiUsageInclude? include,
  }) {
    return BoardAiUsageIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardAiUsage.t),
      orderByList: orderByList?.call(BoardAiUsage.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardAiUsageImpl extends BoardAiUsage {
  _BoardAiUsageImpl({
    int? id,
    required String day,
    required String provider,
    required String model,
    required String feature,
    required int requests,
    required int inputTokens,
    required int outputTokens,
  }) : super._(
         id: id,
         day: day,
         provider: provider,
         model: model,
         feature: feature,
         requests: requests,
         inputTokens: inputTokens,
         outputTokens: outputTokens,
       );

  /// Returns a shallow copy of this [BoardAiUsage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardAiUsage copyWith({
    Object? id = _Undefined,
    String? day,
    String? provider,
    String? model,
    String? feature,
    int? requests,
    int? inputTokens,
    int? outputTokens,
  }) {
    return BoardAiUsage(
      id: id is int? ? id : this.id,
      day: day ?? this.day,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      feature: feature ?? this.feature,
      requests: requests ?? this.requests,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
    );
  }
}

class BoardAiUsageUpdateTable extends _is.UpdateTable<BoardAiUsageTable> {
  BoardAiUsageUpdateTable(super.table);

  _is.ColumnValue<String, String> day(String value) => _is.ColumnValue(
    table.day,
    value,
  );

  _is.ColumnValue<String, String> provider(String value) => _is.ColumnValue(
    table.provider,
    value,
  );

  _is.ColumnValue<String, String> model(String value) => _is.ColumnValue(
    table.model,
    value,
  );

  _is.ColumnValue<String, String> feature(String value) => _is.ColumnValue(
    table.feature,
    value,
  );

  _is.ColumnValue<int, int> requests(int value) => _is.ColumnValue(
    table.requests,
    value,
  );

  _is.ColumnValue<int, int> inputTokens(int value) => _is.ColumnValue(
    table.inputTokens,
    value,
  );

  _is.ColumnValue<int, int> outputTokens(int value) => _is.ColumnValue(
    table.outputTokens,
    value,
  );
}

class BoardAiUsageTable extends _is.Table<int?> {
  BoardAiUsageTable({super.tableRelation})
    : super(tableName: 'board_ai_usage') {
    updateTable = BoardAiUsageUpdateTable(this);
    day = _is.ColumnString(
      'day',
      this,
    );
    provider = _is.ColumnString(
      'provider',
      this,
    );
    model = _is.ColumnString(
      'model',
      this,
    );
    feature = _is.ColumnString(
      'feature',
      this,
    );
    requests = _is.ColumnInt(
      'requests',
      this,
    );
    inputTokens = _is.ColumnInt(
      'inputTokens',
      this,
    );
    outputTokens = _is.ColumnInt(
      'outputTokens',
      this,
    );
  }

  late final BoardAiUsageUpdateTable updateTable;

  /// yyyy-mm-dd (UTC).
  late final _is.ColumnString day;

  /// jev | gemini
  late final _is.ColumnString provider;

  late final _is.ColumnString model;

  late final _is.ColumnString feature;

  late final _is.ColumnInt requests;

  late final _is.ColumnInt inputTokens;

  late final _is.ColumnInt outputTokens;

  @override
  List<_is.Column> get columns => [
    id,
    day,
    provider,
    model,
    feature,
    requests,
    inputTokens,
    outputTokens,
  ];
}

class BoardAiUsageInclude extends _is.IncludeObject {
  BoardAiUsageInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => BoardAiUsage.t;
}

class BoardAiUsageIncludeList extends _is.IncludeList {
  BoardAiUsageIncludeList._({
    _is.WhereExpressionBuilder<BoardAiUsageTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BoardAiUsage.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => BoardAiUsage.t;
}

class BoardAiUsageRepository {
  const BoardAiUsageRepository._();

  /// Returns a list of [BoardAiUsage]s matching the given query parameters.
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
  Future<List<BoardAiUsage>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardAiUsageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardAiUsageTable>? orderBy,
    _is.OrderByListBuilder<BoardAiUsageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BoardAiUsage>(
      where: where?.call(BoardAiUsage.t),
      orderBy: orderBy?.call(BoardAiUsage.t),
      orderByList: orderByList?.call(BoardAiUsage.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [BoardAiUsage]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `BoardAiUsage.t`.
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
  _ida.Stream<List<BoardAiUsage>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardAiUsageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardAiUsageTable>? orderBy,
    _is.OrderByListBuilder<BoardAiUsageTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<BoardAiUsage>(
      where: where?.call(BoardAiUsage.t),
      orderBy: orderBy?.call(BoardAiUsage.t),
      orderByList: orderByList?.call(BoardAiUsage.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [BoardAiUsage] matching the given query parameters.
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
  Future<BoardAiUsage?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardAiUsageTable>? where,
    int? offset,
    _is.OrderByBuilder<BoardAiUsageTable>? orderBy,
    _is.OrderByListBuilder<BoardAiUsageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BoardAiUsage>(
      where: where?.call(BoardAiUsage.t),
      orderBy: orderBy?.call(BoardAiUsage.t),
      orderByList: orderByList?.call(BoardAiUsage.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BoardAiUsage] by its [id] or null if no such row exists.
  Future<BoardAiUsage?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BoardAiUsage>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BoardAiUsage]s in the list and returns the inserted rows.
  ///
  /// The returned [BoardAiUsage]s will have their `id` fields set.
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
  Future<List<BoardAiUsage>> insert(
    _is.DatabaseSession session,
    List<BoardAiUsage> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BoardAiUsage>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BoardAiUsage] and returns the inserted row.
  ///
  /// The returned [BoardAiUsage] will have its `id` field set.
  Future<BoardAiUsage> insertRow(
    _is.DatabaseSession session,
    BoardAiUsage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BoardAiUsage>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BoardAiUsage]s in the list and returns the resulting rows.
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
  /// The returned [BoardAiUsage]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardAiUsage>> upsert(
    _is.DatabaseSession session,
    List<BoardAiUsage> rows, {
    required _is.ColumnSelections<BoardAiUsageTable> conflictColumns,
    _is.ColumnSelections<BoardAiUsageTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardAiUsageTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BoardAiUsage>(
      rows,
      conflictColumns: conflictColumns(BoardAiUsage.t),
      updateColumns: updateColumns?.call(BoardAiUsage.t),
      updateWhere: updateWhere?.call(BoardAiUsage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BoardAiUsage] and returns the resulting row.
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
  /// The returned [BoardAiUsage] will have its `id` field set.
  Future<BoardAiUsage?> upsertRow(
    _is.DatabaseSession session,
    BoardAiUsage row, {
    required _is.ColumnSelections<BoardAiUsageTable> conflictColumns,
    _is.ColumnSelections<BoardAiUsageTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardAiUsageTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BoardAiUsage>(
      row,
      conflictColumns: conflictColumns(BoardAiUsage.t),
      updateColumns: updateColumns?.call(BoardAiUsage.t),
      updateWhere: updateWhere?.call(BoardAiUsage.t),
      transaction: transaction,
    );
  }

  /// Updates all [BoardAiUsage]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardAiUsage>> update(
    _is.DatabaseSession session,
    List<BoardAiUsage> rows, {
    _is.ColumnSelections<BoardAiUsageTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BoardAiUsage>(
      rows,
      columns: columns?.call(BoardAiUsage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BoardAiUsage]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BoardAiUsage> updateRow(
    _is.DatabaseSession session,
    BoardAiUsage row, {
    _is.ColumnSelections<BoardAiUsageTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BoardAiUsage>(
      row,
      columns: columns?.call(BoardAiUsage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BoardAiUsage] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BoardAiUsage?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BoardAiUsageUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BoardAiUsage>(
      id,
      columnValues: columnValues(BoardAiUsage.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BoardAiUsage]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardAiUsage>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BoardAiUsageUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<BoardAiUsageTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardAiUsageTable>? orderBy,
    _is.OrderByListBuilder<BoardAiUsageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BoardAiUsage>(
      columnValues: columnValues(BoardAiUsage.t.updateTable),
      where: where(BoardAiUsage.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardAiUsage.t),
      orderByList: orderByList?.call(BoardAiUsage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BoardAiUsage]s in the list and returns the deleted rows.
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
  Future<List<BoardAiUsage>> delete(
    _is.DatabaseSession session,
    List<BoardAiUsage> rows, {
    _is.OrderByBuilder<BoardAiUsageTable>? orderBy,
    _is.OrderByListBuilder<BoardAiUsageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BoardAiUsage>(
      rows,
      orderBy: orderBy?.call(BoardAiUsage.t),
      orderByList: orderByList?.call(BoardAiUsage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BoardAiUsage].
  Future<BoardAiUsage> deleteRow(
    _is.DatabaseSession session,
    BoardAiUsage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BoardAiUsage>(
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
  Future<List<BoardAiUsage>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardAiUsageTable> where,
    _is.OrderByBuilder<BoardAiUsageTable>? orderBy,
    _is.OrderByListBuilder<BoardAiUsageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BoardAiUsage>(
      where: where(BoardAiUsage.t),
      orderBy: orderBy?.call(BoardAiUsage.t),
      orderByList: orderByList?.call(BoardAiUsage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardAiUsageTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BoardAiUsage>(
      where: where?.call(BoardAiUsage.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BoardAiUsage] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardAiUsageTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BoardAiUsage>(
      where: where(BoardAiUsage.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
