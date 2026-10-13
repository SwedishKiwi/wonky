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

/// Activity privacy of a user (specs/07 §6). No row = defaults.
abstract class UserActivitySettings
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  UserActivitySettings._({
    this.id,
    required this.userId,
    bool? showViewHistory,
    required this.updatedAt,
  }) : showViewHistory = showViewHistory ?? true;

  factory UserActivitySettings({
    int? id,
    required int userId,
    bool? showViewHistory,
    required DateTime updatedAt,
  }) = _UserActivitySettingsImpl;

  factory UserActivitySettings.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return UserActivitySettings(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      showViewHistory: jsonSerialization['showViewHistory'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['showViewHistory'],
            ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = UserActivitySettingsTable();

  static const db = UserActivitySettingsRepository._();

  @override
  int? id;

  int userId;

  /// "Show my view history": when false the user is left out of viewer
  /// lists (their views still count, anonymously, in the trend charts).
  bool showViewHistory;

  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [UserActivitySettings]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  UserActivitySettings copyWith({
    int? id,
    int? userId,
    bool? showViewHistory,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserActivitySettings',
      if (id != null) 'id': id,
      'userId': userId,
      'showViewHistory': showViewHistory,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static UserActivitySettingsInclude include() {
    return UserActivitySettingsInclude._();
  }

  static UserActivitySettingsIncludeList includeList({
    _is.WhereExpressionBuilder<UserActivitySettingsTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UserActivitySettingsTable>? orderBy,
    _is.OrderByListBuilder<UserActivitySettingsTable>? orderByList,
    UserActivitySettingsInclude? include,
  }) {
    return UserActivitySettingsIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UserActivitySettings.t),
      orderByList: orderByList?.call(UserActivitySettings.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserActivitySettingsImpl extends UserActivitySettings {
  _UserActivitySettingsImpl({
    int? id,
    required int userId,
    bool? showViewHistory,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         userId: userId,
         showViewHistory: showViewHistory,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [UserActivitySettings]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UserActivitySettings copyWith({
    Object? id = _Undefined,
    int? userId,
    bool? showViewHistory,
    DateTime? updatedAt,
  }) {
    return UserActivitySettings(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      showViewHistory: showViewHistory ?? this.showViewHistory,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserActivitySettingsUpdateTable
    extends _is.UpdateTable<UserActivitySettingsTable> {
  UserActivitySettingsUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<bool, bool> showViewHistory(bool value) => _is.ColumnValue(
    table.showViewHistory,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class UserActivitySettingsTable extends _is.Table<int?> {
  UserActivitySettingsTable({super.tableRelation})
    : super(tableName: 'user_activity_settings') {
    updateTable = UserActivitySettingsUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    showViewHistory = _is.ColumnBool(
      'showViewHistory',
      this,
      hasDefault: true,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final UserActivitySettingsUpdateTable updateTable;

  late final _is.ColumnInt userId;

  /// "Show my view history": when false the user is left out of viewer
  /// lists (their views still count, anonymously, in the trend charts).
  late final _is.ColumnBool showViewHistory;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    showViewHistory,
    updatedAt,
  ];
}

class UserActivitySettingsInclude extends _is.IncludeObject {
  UserActivitySettingsInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => UserActivitySettings.t;
}

class UserActivitySettingsIncludeList extends _is.IncludeList {
  UserActivitySettingsIncludeList._({
    _is.WhereExpressionBuilder<UserActivitySettingsTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UserActivitySettings.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => UserActivitySettings.t;
}

class UserActivitySettingsRepository {
  const UserActivitySettingsRepository._();

  /// Returns a list of [UserActivitySettings]s matching the given query parameters.
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
  Future<List<UserActivitySettings>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UserActivitySettingsTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UserActivitySettingsTable>? orderBy,
    _is.OrderByListBuilder<UserActivitySettingsTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UserActivitySettings>(
      where: where?.call(UserActivitySettings.t),
      orderBy: orderBy?.call(UserActivitySettings.t),
      orderByList: orderByList?.call(UserActivitySettings.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [UserActivitySettings]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `UserActivitySettings.t`.
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
  _ida.Stream<List<UserActivitySettings>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UserActivitySettingsTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UserActivitySettingsTable>? orderBy,
    _is.OrderByListBuilder<UserActivitySettingsTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<UserActivitySettings>(
      where: where?.call(UserActivitySettings.t),
      orderBy: orderBy?.call(UserActivitySettings.t),
      orderByList: orderByList?.call(UserActivitySettings.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [UserActivitySettings] matching the given query parameters.
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
  Future<UserActivitySettings?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UserActivitySettingsTable>? where,
    int? offset,
    _is.OrderByBuilder<UserActivitySettingsTable>? orderBy,
    _is.OrderByListBuilder<UserActivitySettingsTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UserActivitySettings>(
      where: where?.call(UserActivitySettings.t),
      orderBy: orderBy?.call(UserActivitySettings.t),
      orderByList: orderByList?.call(UserActivitySettings.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UserActivitySettings] by its [id] or null if no such row exists.
  Future<UserActivitySettings?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UserActivitySettings>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UserActivitySettings]s in the list and returns the inserted rows.
  ///
  /// The returned [UserActivitySettings]s will have their `id` fields set.
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
  Future<List<UserActivitySettings>> insert(
    _is.DatabaseSession session,
    List<UserActivitySettings> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UserActivitySettings>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UserActivitySettings] and returns the inserted row.
  ///
  /// The returned [UserActivitySettings] will have its `id` field set.
  Future<UserActivitySettings> insertRow(
    _is.DatabaseSession session,
    UserActivitySettings row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<UserActivitySettings>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UserActivitySettings]s in the list and returns the resulting rows.
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
  /// The returned [UserActivitySettings]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UserActivitySettings>> upsert(
    _is.DatabaseSession session,
    List<UserActivitySettings> rows, {
    required _is.ColumnSelections<UserActivitySettingsTable> conflictColumns,
    _is.ColumnSelections<UserActivitySettingsTable>? updateColumns,
    _is.WhereExpressionBuilder<UserActivitySettingsTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UserActivitySettings>(
      rows,
      conflictColumns: conflictColumns(UserActivitySettings.t),
      updateColumns: updateColumns?.call(UserActivitySettings.t),
      updateWhere: updateWhere?.call(UserActivitySettings.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UserActivitySettings] and returns the resulting row.
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
  /// The returned [UserActivitySettings] will have its `id` field set.
  Future<UserActivitySettings?> upsertRow(
    _is.DatabaseSession session,
    UserActivitySettings row, {
    required _is.ColumnSelections<UserActivitySettingsTable> conflictColumns,
    _is.ColumnSelections<UserActivitySettingsTable>? updateColumns,
    _is.WhereExpressionBuilder<UserActivitySettingsTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UserActivitySettings>(
      row,
      conflictColumns: conflictColumns(UserActivitySettings.t),
      updateColumns: updateColumns?.call(UserActivitySettings.t),
      updateWhere: updateWhere?.call(UserActivitySettings.t),
      transaction: transaction,
    );
  }

  /// Updates all [UserActivitySettings]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UserActivitySettings>> update(
    _is.DatabaseSession session,
    List<UserActivitySettings> rows, {
    _is.ColumnSelections<UserActivitySettingsTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UserActivitySettings>(
      rows,
      columns: columns?.call(UserActivitySettings.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UserActivitySettings]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UserActivitySettings> updateRow(
    _is.DatabaseSession session,
    UserActivitySettings row, {
    _is.ColumnSelections<UserActivitySettingsTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<UserActivitySettings>(
      row,
      columns: columns?.call(UserActivitySettings.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UserActivitySettings] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UserActivitySettings?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<UserActivitySettingsUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<UserActivitySettings>(
      id,
      columnValues: columnValues(UserActivitySettings.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UserActivitySettings]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UserActivitySettings>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<UserActivitySettingsUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<UserActivitySettingsTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UserActivitySettingsTable>? orderBy,
    _is.OrderByListBuilder<UserActivitySettingsTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UserActivitySettings>(
      columnValues: columnValues(UserActivitySettings.t.updateTable),
      where: where(UserActivitySettings.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UserActivitySettings.t),
      orderByList: orderByList?.call(UserActivitySettings.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UserActivitySettings]s in the list and returns the deleted rows.
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
  Future<List<UserActivitySettings>> delete(
    _is.DatabaseSession session,
    List<UserActivitySettings> rows, {
    _is.OrderByBuilder<UserActivitySettingsTable>? orderBy,
    _is.OrderByListBuilder<UserActivitySettingsTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UserActivitySettings>(
      rows,
      orderBy: orderBy?.call(UserActivitySettings.t),
      orderByList: orderByList?.call(UserActivitySettings.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UserActivitySettings].
  Future<UserActivitySettings> deleteRow(
    _is.DatabaseSession session,
    UserActivitySettings row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UserActivitySettings>(
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
  Future<List<UserActivitySettings>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UserActivitySettingsTable> where,
    _is.OrderByBuilder<UserActivitySettingsTable>? orderBy,
    _is.OrderByListBuilder<UserActivitySettingsTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UserActivitySettings>(
      where: where(UserActivitySettings.t),
      orderBy: orderBy?.call(UserActivitySettings.t),
      orderByList: orderByList?.call(UserActivitySettings.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UserActivitySettingsTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<UserActivitySettings>(
      where: where?.call(UserActivitySettings.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UserActivitySettings] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UserActivitySettingsTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UserActivitySettings>(
      where: where(UserActivitySettings.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
