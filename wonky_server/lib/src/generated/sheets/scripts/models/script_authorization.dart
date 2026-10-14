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
import 'package:wonky_server/src/generated/protocol.dart' as _il4umwa0;

/// Scopes a user authorized for the script of a spreadsheet (Sheets 09 §11.2).
abstract class ScriptAuthorization
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  ScriptAuthorization._({
    this.id,
    required this.userId,
    required this.spreadsheetUuid,
    required this.scopes,
    required this.grantedAt,
    this.revokedAt,
  });

  factory ScriptAuthorization({
    int? id,
    required int userId,
    required _is.UuidValue spreadsheetUuid,
    required List<String> scopes,
    required DateTime grantedAt,
    DateTime? revokedAt,
  }) = _ScriptAuthorizationImpl;

  factory ScriptAuthorization.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScriptAuthorization(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      spreadsheetUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spreadsheetUuid'],
      ),
      scopes: _il4umwa0.Protocol().deserialize<List<String>>(
        jsonSerialization['scopes'],
      ),
      grantedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['grantedAt'],
      ),
      revokedAt: jsonSerialization['revokedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['revokedAt']),
    );
  }

  static final t = ScriptAuthorizationTable();

  static const db = ScriptAuthorizationRepository._();

  @override
  int? id;

  int userId;

  _is.UuidValue spreadsheetUuid;

  List<String> scopes;

  DateTime grantedAt;

  DateTime? revokedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [ScriptAuthorization]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ScriptAuthorization copyWith({
    int? id,
    int? userId,
    _is.UuidValue? spreadsheetUuid,
    List<String>? scopes,
    DateTime? grantedAt,
    DateTime? revokedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScriptAuthorization',
      if (id != null) 'id': id,
      'userId': userId,
      'spreadsheetUuid': spreadsheetUuid.toJson(),
      'scopes': scopes.toJson(),
      'grantedAt': grantedAt.toJson(),
      if (revokedAt != null) 'revokedAt': revokedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ScriptAuthorizationInclude include() {
    return ScriptAuthorizationInclude._();
  }

  static ScriptAuthorizationIncludeList includeList({
    _is.WhereExpressionBuilder<ScriptAuthorizationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptAuthorizationTable>? orderBy,
    _is.OrderByListBuilder<ScriptAuthorizationTable>? orderByList,
    ScriptAuthorizationInclude? include,
  }) {
    return ScriptAuthorizationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptAuthorization.t),
      orderByList: orderByList?.call(ScriptAuthorization.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ScriptAuthorizationImpl extends ScriptAuthorization {
  _ScriptAuthorizationImpl({
    int? id,
    required int userId,
    required _is.UuidValue spreadsheetUuid,
    required List<String> scopes,
    required DateTime grantedAt,
    DateTime? revokedAt,
  }) : super._(
         id: id,
         userId: userId,
         spreadsheetUuid: spreadsheetUuid,
         scopes: scopes,
         grantedAt: grantedAt,
         revokedAt: revokedAt,
       );

  /// Returns a shallow copy of this [ScriptAuthorization]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ScriptAuthorization copyWith({
    Object? id = _Undefined,
    int? userId,
    _is.UuidValue? spreadsheetUuid,
    List<String>? scopes,
    DateTime? grantedAt,
    DateTime? revokedAt = const _is.$UndefinedDateTime(),
  }) {
    return ScriptAuthorization(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      spreadsheetUuid: spreadsheetUuid ?? this.spreadsheetUuid,
      scopes: scopes ?? this.scopes.map((e0) => e0).toList(),
      grantedAt: grantedAt ?? this.grantedAt,
      revokedAt: revokedAt is _is.UndefinedSentinel
          ? this.revokedAt
          : revokedAt,
    );
  }
}

class ScriptAuthorizationUpdateTable
    extends _is.UpdateTable<ScriptAuthorizationTable> {
  ScriptAuthorizationUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> spreadsheetUuid(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.spreadsheetUuid,
    value,
  );

  _is.ColumnValue<List<String>, List<String>> scopes(List<String> value) =>
      _is.ColumnValue(
        table.scopes,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> grantedAt(DateTime value) =>
      _is.ColumnValue(
        table.grantedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> revokedAt(DateTime? value) =>
      _is.ColumnValue(
        table.revokedAt,
        value,
      );
}

class ScriptAuthorizationTable extends _is.Table<int?> {
  ScriptAuthorizationTable({super.tableRelation})
    : super(tableName: 'script_authorization') {
    updateTable = ScriptAuthorizationUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    spreadsheetUuid = _is.ColumnUuid(
      'spreadsheetUuid',
      this,
    );
    scopes = _is.ColumnSerializable<List<String>>(
      'scopes',
      this,
    );
    grantedAt = _is.ColumnDateTime(
      'grantedAt',
      this,
    );
    revokedAt = _is.ColumnDateTime(
      'revokedAt',
      this,
    );
  }

  late final ScriptAuthorizationUpdateTable updateTable;

  late final _is.ColumnInt userId;

  late final _is.ColumnUuid spreadsheetUuid;

  late final _is.ColumnSerializable<List<String>> scopes;

  late final _is.ColumnDateTime grantedAt;

  late final _is.ColumnDateTime revokedAt;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    spreadsheetUuid,
    scopes,
    grantedAt,
    revokedAt,
  ];
}

class ScriptAuthorizationInclude extends _is.IncludeObject {
  ScriptAuthorizationInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => ScriptAuthorization.t;
}

class ScriptAuthorizationIncludeList extends _is.IncludeList {
  ScriptAuthorizationIncludeList._({
    _is.WhereExpressionBuilder<ScriptAuthorizationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ScriptAuthorization.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => ScriptAuthorization.t;
}

class ScriptAuthorizationRepository {
  const ScriptAuthorizationRepository._();

  /// Returns a list of [ScriptAuthorization]s matching the given query parameters.
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
  Future<List<ScriptAuthorization>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptAuthorizationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptAuthorizationTable>? orderBy,
    _is.OrderByListBuilder<ScriptAuthorizationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ScriptAuthorization>(
      where: where?.call(ScriptAuthorization.t),
      orderBy: orderBy?.call(ScriptAuthorization.t),
      orderByList: orderByList?.call(ScriptAuthorization.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ScriptAuthorization]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ScriptAuthorization.t`.
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
  _ida.Stream<List<ScriptAuthorization>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptAuthorizationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptAuthorizationTable>? orderBy,
    _is.OrderByListBuilder<ScriptAuthorizationTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ScriptAuthorization>(
      where: where?.call(ScriptAuthorization.t),
      orderBy: orderBy?.call(ScriptAuthorization.t),
      orderByList: orderByList?.call(ScriptAuthorization.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ScriptAuthorization] matching the given query parameters.
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
  Future<ScriptAuthorization?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptAuthorizationTable>? where,
    int? offset,
    _is.OrderByBuilder<ScriptAuthorizationTable>? orderBy,
    _is.OrderByListBuilder<ScriptAuthorizationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ScriptAuthorization>(
      where: where?.call(ScriptAuthorization.t),
      orderBy: orderBy?.call(ScriptAuthorization.t),
      orderByList: orderByList?.call(ScriptAuthorization.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ScriptAuthorization] by its [id] or null if no such row exists.
  Future<ScriptAuthorization?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ScriptAuthorization>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ScriptAuthorization]s in the list and returns the inserted rows.
  ///
  /// The returned [ScriptAuthorization]s will have their `id` fields set.
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
  Future<List<ScriptAuthorization>> insert(
    _is.DatabaseSession session,
    List<ScriptAuthorization> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ScriptAuthorization>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ScriptAuthorization] and returns the inserted row.
  ///
  /// The returned [ScriptAuthorization] will have its `id` field set.
  Future<ScriptAuthorization> insertRow(
    _is.DatabaseSession session,
    ScriptAuthorization row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<ScriptAuthorization>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [ScriptAuthorization]s in the list and returns the resulting rows.
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
  /// The returned [ScriptAuthorization]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptAuthorization>> upsert(
    _is.DatabaseSession session,
    List<ScriptAuthorization> rows, {
    required _is.ColumnSelections<ScriptAuthorizationTable> conflictColumns,
    _is.ColumnSelections<ScriptAuthorizationTable>? updateColumns,
    _is.WhereExpressionBuilder<ScriptAuthorizationTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ScriptAuthorization>(
      rows,
      conflictColumns: conflictColumns(ScriptAuthorization.t),
      updateColumns: updateColumns?.call(ScriptAuthorization.t),
      updateWhere: updateWhere?.call(ScriptAuthorization.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ScriptAuthorization] and returns the resulting row.
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
  /// The returned [ScriptAuthorization] will have its `id` field set.
  Future<ScriptAuthorization?> upsertRow(
    _is.DatabaseSession session,
    ScriptAuthorization row, {
    required _is.ColumnSelections<ScriptAuthorizationTable> conflictColumns,
    _is.ColumnSelections<ScriptAuthorizationTable>? updateColumns,
    _is.WhereExpressionBuilder<ScriptAuthorizationTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ScriptAuthorization>(
      row,
      conflictColumns: conflictColumns(ScriptAuthorization.t),
      updateColumns: updateColumns?.call(ScriptAuthorization.t),
      updateWhere: updateWhere?.call(ScriptAuthorization.t),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptAuthorization]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptAuthorization>> update(
    _is.DatabaseSession session,
    List<ScriptAuthorization> rows, {
    _is.ColumnSelections<ScriptAuthorizationTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ScriptAuthorization>(
      rows,
      columns: columns?.call(ScriptAuthorization.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ScriptAuthorization]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ScriptAuthorization> updateRow(
    _is.DatabaseSession session,
    ScriptAuthorization row, {
    _is.ColumnSelections<ScriptAuthorizationTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<ScriptAuthorization>(
      row,
      columns: columns?.call(ScriptAuthorization.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ScriptAuthorization] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ScriptAuthorization?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<ScriptAuthorizationUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<ScriptAuthorization>(
      id,
      columnValues: columnValues(ScriptAuthorization.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptAuthorization]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptAuthorization>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<ScriptAuthorizationUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<ScriptAuthorizationTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptAuthorizationTable>? orderBy,
    _is.OrderByListBuilder<ScriptAuthorizationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ScriptAuthorization>(
      columnValues: columnValues(ScriptAuthorization.t.updateTable),
      where: where(ScriptAuthorization.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptAuthorization.t),
      orderByList: orderByList?.call(ScriptAuthorization.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ScriptAuthorization]s in the list and returns the deleted rows.
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
  Future<List<ScriptAuthorization>> delete(
    _is.DatabaseSession session,
    List<ScriptAuthorization> rows, {
    _is.OrderByBuilder<ScriptAuthorizationTable>? orderBy,
    _is.OrderByListBuilder<ScriptAuthorizationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ScriptAuthorization>(
      rows,
      orderBy: orderBy?.call(ScriptAuthorization.t),
      orderByList: orderByList?.call(ScriptAuthorization.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ScriptAuthorization].
  Future<ScriptAuthorization> deleteRow(
    _is.DatabaseSession session,
    ScriptAuthorization row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ScriptAuthorization>(
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
  Future<List<ScriptAuthorization>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ScriptAuthorizationTable> where,
    _is.OrderByBuilder<ScriptAuthorizationTable>? orderBy,
    _is.OrderByListBuilder<ScriptAuthorizationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ScriptAuthorization>(
      where: where(ScriptAuthorization.t),
      orderBy: orderBy?.call(ScriptAuthorization.t),
      orderByList: orderByList?.call(ScriptAuthorization.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptAuthorizationTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<ScriptAuthorization>(
      where: where?.call(ScriptAuthorization.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ScriptAuthorization] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ScriptAuthorizationTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ScriptAuthorization>(
      where: where(ScriptAuthorization.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
