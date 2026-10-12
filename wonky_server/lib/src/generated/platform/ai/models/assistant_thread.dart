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

/// An assistant conversation of a user, scoped to a file (suite 10 §2).
abstract class AssistantThread
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  AssistantThread._({
    this.id,
    required this.userId,
    this.itemId,
    required this.title,
    this.contextRevision,
    this.contextMarkdown,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AssistantThread({
    int? id,
    required int userId,
    int? itemId,
    required String title,
    int? contextRevision,
    String? contextMarkdown,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AssistantThreadImpl;

  factory AssistantThread.fromJson(Map<String, dynamic> jsonSerialization) {
    return AssistantThread(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      itemId: jsonSerialization['itemId'] as int?,
      title: jsonSerialization['title'] as String,
      contextRevision: jsonSerialization['contextRevision'] as int?,
      contextMarkdown: jsonSerialization['contextMarkdown'] as String?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = AssistantThreadTable();

  static const db = AssistantThreadRepository._();

  @override
  int? id;

  int userId;

  int? itemId;

  String title;

  /// The document revision and Markdown the model last saw (appended as
  /// "document updated" turns when it changes; never rewritten).
  int? contextRevision;

  String? contextMarkdown;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [AssistantThread]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AssistantThread copyWith({
    int? id,
    int? userId,
    int? itemId,
    String? title,
    int? contextRevision,
    String? contextMarkdown,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AssistantThread',
      if (id != null) 'id': id,
      'userId': userId,
      if (itemId != null) 'itemId': itemId,
      'title': title,
      if (contextRevision != null) 'contextRevision': contextRevision,
      if (contextMarkdown != null) 'contextMarkdown': contextMarkdown,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AssistantThread',
      if (id != null) 'id': id,
      'userId': userId,
      if (itemId != null) 'itemId': itemId,
      'title': title,
      if (contextRevision != null) 'contextRevision': contextRevision,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  static AssistantThreadInclude include() {
    return AssistantThreadInclude._();
  }

  static AssistantThreadIncludeList includeList({
    _is.WhereExpressionBuilder<AssistantThreadTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AssistantThreadTable>? orderBy,
    _is.OrderByListBuilder<AssistantThreadTable>? orderByList,
    AssistantThreadInclude? include,
  }) {
    return AssistantThreadIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AssistantThread.t),
      orderByList: orderByList?.call(AssistantThread.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AssistantThreadImpl extends AssistantThread {
  _AssistantThreadImpl({
    int? id,
    required int userId,
    int? itemId,
    required String title,
    int? contextRevision,
    String? contextMarkdown,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         userId: userId,
         itemId: itemId,
         title: title,
         contextRevision: contextRevision,
         contextMarkdown: contextMarkdown,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [AssistantThread]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AssistantThread copyWith({
    Object? id = _Undefined,
    int? userId,
    Object? itemId = _Undefined,
    String? title,
    Object? contextRevision = _Undefined,
    Object? contextMarkdown = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssistantThread(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      itemId: itemId is int? ? itemId : this.itemId,
      title: title ?? this.title,
      contextRevision: contextRevision is int?
          ? contextRevision
          : this.contextRevision,
      contextMarkdown: contextMarkdown is String?
          ? contextMarkdown
          : this.contextMarkdown,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AssistantThreadUpdateTable extends _is.UpdateTable<AssistantThreadTable> {
  AssistantThreadUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<int, int> itemId(int? value) => _is.ColumnValue(
    table.itemId,
    value,
  );

  _is.ColumnValue<String, String> title(String value) => _is.ColumnValue(
    table.title,
    value,
  );

  _is.ColumnValue<int, int> contextRevision(int? value) => _is.ColumnValue(
    table.contextRevision,
    value,
  );

  _is.ColumnValue<String, String> contextMarkdown(String? value) =>
      _is.ColumnValue(
        table.contextMarkdown,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class AssistantThreadTable extends _is.Table<int?> {
  AssistantThreadTable({super.tableRelation})
    : super(tableName: 'assistant_thread') {
    updateTable = AssistantThreadUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    itemId = _is.ColumnInt(
      'itemId',
      this,
    );
    title = _is.ColumnString(
      'title',
      this,
    );
    contextRevision = _is.ColumnInt(
      'contextRevision',
      this,
    );
    contextMarkdown = _is.ColumnString(
      'contextMarkdown',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final AssistantThreadUpdateTable updateTable;

  late final _is.ColumnInt userId;

  late final _is.ColumnInt itemId;

  late final _is.ColumnString title;

  /// The document revision and Markdown the model last saw (appended as
  /// "document updated" turns when it changes; never rewritten).
  late final _is.ColumnInt contextRevision;

  late final _is.ColumnString contextMarkdown;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    itemId,
    title,
    contextRevision,
    contextMarkdown,
    createdAt,
    updatedAt,
  ];
}

class AssistantThreadInclude extends _is.IncludeObject {
  AssistantThreadInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => AssistantThread.t;
}

class AssistantThreadIncludeList extends _is.IncludeList {
  AssistantThreadIncludeList._({
    _is.WhereExpressionBuilder<AssistantThreadTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AssistantThread.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => AssistantThread.t;
}

class AssistantThreadRepository {
  const AssistantThreadRepository._();

  /// Returns a list of [AssistantThread]s matching the given query parameters.
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
  Future<List<AssistantThread>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AssistantThreadTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AssistantThreadTable>? orderBy,
    _is.OrderByListBuilder<AssistantThreadTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AssistantThread>(
      where: where?.call(AssistantThread.t),
      orderBy: orderBy?.call(AssistantThread.t),
      orderByList: orderByList?.call(AssistantThread.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [AssistantThread]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `AssistantThread.t`.
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
  _ida.Stream<List<AssistantThread>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AssistantThreadTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AssistantThreadTable>? orderBy,
    _is.OrderByListBuilder<AssistantThreadTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<AssistantThread>(
      where: where?.call(AssistantThread.t),
      orderBy: orderBy?.call(AssistantThread.t),
      orderByList: orderByList?.call(AssistantThread.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [AssistantThread] matching the given query parameters.
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
  Future<AssistantThread?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AssistantThreadTable>? where,
    int? offset,
    _is.OrderByBuilder<AssistantThreadTable>? orderBy,
    _is.OrderByListBuilder<AssistantThreadTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AssistantThread>(
      where: where?.call(AssistantThread.t),
      orderBy: orderBy?.call(AssistantThread.t),
      orderByList: orderByList?.call(AssistantThread.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AssistantThread] by its [id] or null if no such row exists.
  Future<AssistantThread?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AssistantThread>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AssistantThread]s in the list and returns the inserted rows.
  ///
  /// The returned [AssistantThread]s will have their `id` fields set.
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
  Future<List<AssistantThread>> insert(
    _is.DatabaseSession session,
    List<AssistantThread> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<AssistantThread>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [AssistantThread] and returns the inserted row.
  ///
  /// The returned [AssistantThread] will have its `id` field set.
  Future<AssistantThread> insertRow(
    _is.DatabaseSession session,
    AssistantThread row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<AssistantThread>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [AssistantThread]s in the list and returns the resulting rows.
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
  /// The returned [AssistantThread]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AssistantThread>> upsert(
    _is.DatabaseSession session,
    List<AssistantThread> rows, {
    required _is.ColumnSelections<AssistantThreadTable> conflictColumns,
    _is.ColumnSelections<AssistantThreadTable>? updateColumns,
    _is.WhereExpressionBuilder<AssistantThreadTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<AssistantThread>(
      rows,
      conflictColumns: conflictColumns(AssistantThread.t),
      updateColumns: updateColumns?.call(AssistantThread.t),
      updateWhere: updateWhere?.call(AssistantThread.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [AssistantThread] and returns the resulting row.
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
  /// The returned [AssistantThread] will have its `id` field set.
  Future<AssistantThread?> upsertRow(
    _is.DatabaseSession session,
    AssistantThread row, {
    required _is.ColumnSelections<AssistantThreadTable> conflictColumns,
    _is.ColumnSelections<AssistantThreadTable>? updateColumns,
    _is.WhereExpressionBuilder<AssistantThreadTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<AssistantThread>(
      row,
      conflictColumns: conflictColumns(AssistantThread.t),
      updateColumns: updateColumns?.call(AssistantThread.t),
      updateWhere: updateWhere?.call(AssistantThread.t),
      transaction: transaction,
    );
  }

  /// Updates all [AssistantThread]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AssistantThread>> update(
    _is.DatabaseSession session,
    List<AssistantThread> rows, {
    _is.ColumnSelections<AssistantThreadTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<AssistantThread>(
      rows,
      columns: columns?.call(AssistantThread.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [AssistantThread]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AssistantThread> updateRow(
    _is.DatabaseSession session,
    AssistantThread row, {
    _is.ColumnSelections<AssistantThreadTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<AssistantThread>(
      row,
      columns: columns?.call(AssistantThread.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AssistantThread] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AssistantThread?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<AssistantThreadUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<AssistantThread>(
      id,
      columnValues: columnValues(AssistantThread.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AssistantThread]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AssistantThread>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<AssistantThreadUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<AssistantThreadTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AssistantThreadTable>? orderBy,
    _is.OrderByListBuilder<AssistantThreadTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<AssistantThread>(
      columnValues: columnValues(AssistantThread.t.updateTable),
      where: where(AssistantThread.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AssistantThread.t),
      orderByList: orderByList?.call(AssistantThread.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [AssistantThread]s in the list and returns the deleted rows.
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
  Future<List<AssistantThread>> delete(
    _is.DatabaseSession session,
    List<AssistantThread> rows, {
    _is.OrderByBuilder<AssistantThreadTable>? orderBy,
    _is.OrderByListBuilder<AssistantThreadTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<AssistantThread>(
      rows,
      orderBy: orderBy?.call(AssistantThread.t),
      orderByList: orderByList?.call(AssistantThread.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [AssistantThread].
  Future<AssistantThread> deleteRow(
    _is.DatabaseSession session,
    AssistantThread row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AssistantThread>(
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
  Future<List<AssistantThread>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AssistantThreadTable> where,
    _is.OrderByBuilder<AssistantThreadTable>? orderBy,
    _is.OrderByListBuilder<AssistantThreadTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<AssistantThread>(
      where: where(AssistantThread.t),
      orderBy: orderBy?.call(AssistantThread.t),
      orderByList: orderByList?.call(AssistantThread.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AssistantThreadTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<AssistantThread>(
      where: where?.call(AssistantThread.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AssistantThread] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AssistantThreadTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AssistantThread>(
      where: where(AssistantThread.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
