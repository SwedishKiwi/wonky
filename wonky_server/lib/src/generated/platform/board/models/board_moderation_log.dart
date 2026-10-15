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
import '../../../platform/board/models/board_target_kind.dart' as _is53gw8g;

/// Audit log of admin actions (specs/16 §9.2).
abstract class BoardModerationLog
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  BoardModerationLog._({
    this.id,
    required this.adminId,
    required this.action,
    required this.targetKind,
    required this.targetId,
    this.beforeJson,
    this.afterJson,
    this.reason,
    required this.createdAt,
  });

  factory BoardModerationLog({
    int? id,
    required int adminId,
    required String action,
    required _is53gw8g.BoardTargetKind targetKind,
    required int targetId,
    String? beforeJson,
    String? afterJson,
    String? reason,
    required DateTime createdAt,
  }) = _BoardModerationLogImpl;

  factory BoardModerationLog.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardModerationLog(
      id: jsonSerialization['id'] as int?,
      adminId: jsonSerialization['adminId'] as int,
      action: jsonSerialization['action'] as String,
      targetKind: _is53gw8g.BoardTargetKind.fromJson(
        (jsonSerialization['targetKind'] as String),
      ),
      targetId: jsonSerialization['targetId'] as int,
      beforeJson: jsonSerialization['beforeJson'] as String?,
      afterJson: jsonSerialization['afterJson'] as String?,
      reason: jsonSerialization['reason'] as String?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = BoardModerationLogTable();

  static const db = BoardModerationLogRepository._();

  @override
  int? id;

  int adminId;

  String action;

  _is53gw8g.BoardTargetKind targetKind;

  int targetId;

  String? beforeJson;

  String? afterJson;

  String? reason;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [BoardModerationLog]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardModerationLog copyWith({
    int? id,
    int? adminId,
    String? action,
    _is53gw8g.BoardTargetKind? targetKind,
    int? targetId,
    String? beforeJson,
    String? afterJson,
    String? reason,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardModerationLog',
      if (id != null) 'id': id,
      'adminId': adminId,
      'action': action,
      'targetKind': targetKind.toJson(),
      'targetId': targetId,
      if (beforeJson != null) 'beforeJson': beforeJson,
      if (afterJson != null) 'afterJson': afterJson,
      if (reason != null) 'reason': reason,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static BoardModerationLogInclude include() {
    return BoardModerationLogInclude._();
  }

  static BoardModerationLogIncludeList includeList({
    _is.WhereExpressionBuilder<BoardModerationLogTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardModerationLogTable>? orderBy,
    _is.OrderByListBuilder<BoardModerationLogTable>? orderByList,
    BoardModerationLogInclude? include,
  }) {
    return BoardModerationLogIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardModerationLog.t),
      orderByList: orderByList?.call(BoardModerationLog.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardModerationLogImpl extends BoardModerationLog {
  _BoardModerationLogImpl({
    int? id,
    required int adminId,
    required String action,
    required _is53gw8g.BoardTargetKind targetKind,
    required int targetId,
    String? beforeJson,
    String? afterJson,
    String? reason,
    required DateTime createdAt,
  }) : super._(
         id: id,
         adminId: adminId,
         action: action,
         targetKind: targetKind,
         targetId: targetId,
         beforeJson: beforeJson,
         afterJson: afterJson,
         reason: reason,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [BoardModerationLog]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardModerationLog copyWith({
    Object? id = _Undefined,
    int? adminId,
    String? action,
    _is53gw8g.BoardTargetKind? targetKind,
    int? targetId,
    Object? beforeJson = _Undefined,
    Object? afterJson = _Undefined,
    Object? reason = _Undefined,
    DateTime? createdAt,
  }) {
    return BoardModerationLog(
      id: id is int? ? id : this.id,
      adminId: adminId ?? this.adminId,
      action: action ?? this.action,
      targetKind: targetKind ?? this.targetKind,
      targetId: targetId ?? this.targetId,
      beforeJson: beforeJson is String? ? beforeJson : this.beforeJson,
      afterJson: afterJson is String? ? afterJson : this.afterJson,
      reason: reason is String? ? reason : this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class BoardModerationLogUpdateTable
    extends _is.UpdateTable<BoardModerationLogTable> {
  BoardModerationLogUpdateTable(super.table);

  _is.ColumnValue<int, int> adminId(int value) => _is.ColumnValue(
    table.adminId,
    value,
  );

  _is.ColumnValue<String, String> action(String value) => _is.ColumnValue(
    table.action,
    value,
  );

  _is.ColumnValue<_is53gw8g.BoardTargetKind, _is53gw8g.BoardTargetKind>
  targetKind(_is53gw8g.BoardTargetKind value) => _is.ColumnValue(
    table.targetKind,
    value,
  );

  _is.ColumnValue<int, int> targetId(int value) => _is.ColumnValue(
    table.targetId,
    value,
  );

  _is.ColumnValue<String, String> beforeJson(String? value) => _is.ColumnValue(
    table.beforeJson,
    value,
  );

  _is.ColumnValue<String, String> afterJson(String? value) => _is.ColumnValue(
    table.afterJson,
    value,
  );

  _is.ColumnValue<String, String> reason(String? value) => _is.ColumnValue(
    table.reason,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class BoardModerationLogTable extends _is.Table<int?> {
  BoardModerationLogTable({super.tableRelation})
    : super(tableName: 'board_moderation_log') {
    updateTable = BoardModerationLogUpdateTable(this);
    adminId = _is.ColumnInt(
      'adminId',
      this,
    );
    action = _is.ColumnString(
      'action',
      this,
    );
    targetKind = _is.ColumnEnum(
      'targetKind',
      this,
      _is.EnumSerialization.byName,
    );
    targetId = _is.ColumnInt(
      'targetId',
      this,
    );
    beforeJson = _is.ColumnString(
      'beforeJson',
      this,
    );
    afterJson = _is.ColumnString(
      'afterJson',
      this,
    );
    reason = _is.ColumnString(
      'reason',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final BoardModerationLogUpdateTable updateTable;

  late final _is.ColumnInt adminId;

  late final _is.ColumnString action;

  late final _is.ColumnEnum<_is53gw8g.BoardTargetKind> targetKind;

  late final _is.ColumnInt targetId;

  late final _is.ColumnString beforeJson;

  late final _is.ColumnString afterJson;

  late final _is.ColumnString reason;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    adminId,
    action,
    targetKind,
    targetId,
    beforeJson,
    afterJson,
    reason,
    createdAt,
  ];
}

class BoardModerationLogInclude extends _is.IncludeObject {
  BoardModerationLogInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => BoardModerationLog.t;
}

class BoardModerationLogIncludeList extends _is.IncludeList {
  BoardModerationLogIncludeList._({
    _is.WhereExpressionBuilder<BoardModerationLogTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BoardModerationLog.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => BoardModerationLog.t;
}

class BoardModerationLogRepository {
  const BoardModerationLogRepository._();

  /// Returns a list of [BoardModerationLog]s matching the given query parameters.
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
  Future<List<BoardModerationLog>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardModerationLogTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardModerationLogTable>? orderBy,
    _is.OrderByListBuilder<BoardModerationLogTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BoardModerationLog>(
      where: where?.call(BoardModerationLog.t),
      orderBy: orderBy?.call(BoardModerationLog.t),
      orderByList: orderByList?.call(BoardModerationLog.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [BoardModerationLog]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `BoardModerationLog.t`.
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
  _ida.Stream<List<BoardModerationLog>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardModerationLogTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardModerationLogTable>? orderBy,
    _is.OrderByListBuilder<BoardModerationLogTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<BoardModerationLog>(
      where: where?.call(BoardModerationLog.t),
      orderBy: orderBy?.call(BoardModerationLog.t),
      orderByList: orderByList?.call(BoardModerationLog.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [BoardModerationLog] matching the given query parameters.
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
  Future<BoardModerationLog?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardModerationLogTable>? where,
    int? offset,
    _is.OrderByBuilder<BoardModerationLogTable>? orderBy,
    _is.OrderByListBuilder<BoardModerationLogTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BoardModerationLog>(
      where: where?.call(BoardModerationLog.t),
      orderBy: orderBy?.call(BoardModerationLog.t),
      orderByList: orderByList?.call(BoardModerationLog.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BoardModerationLog] by its [id] or null if no such row exists.
  Future<BoardModerationLog?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BoardModerationLog>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BoardModerationLog]s in the list and returns the inserted rows.
  ///
  /// The returned [BoardModerationLog]s will have their `id` fields set.
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
  Future<List<BoardModerationLog>> insert(
    _is.DatabaseSession session,
    List<BoardModerationLog> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BoardModerationLog>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BoardModerationLog] and returns the inserted row.
  ///
  /// The returned [BoardModerationLog] will have its `id` field set.
  Future<BoardModerationLog> insertRow(
    _is.DatabaseSession session,
    BoardModerationLog row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BoardModerationLog>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BoardModerationLog]s in the list and returns the resulting rows.
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
  /// The returned [BoardModerationLog]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardModerationLog>> upsert(
    _is.DatabaseSession session,
    List<BoardModerationLog> rows, {
    required _is.ColumnSelections<BoardModerationLogTable> conflictColumns,
    _is.ColumnSelections<BoardModerationLogTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardModerationLogTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BoardModerationLog>(
      rows,
      conflictColumns: conflictColumns(BoardModerationLog.t),
      updateColumns: updateColumns?.call(BoardModerationLog.t),
      updateWhere: updateWhere?.call(BoardModerationLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BoardModerationLog] and returns the resulting row.
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
  /// The returned [BoardModerationLog] will have its `id` field set.
  Future<BoardModerationLog?> upsertRow(
    _is.DatabaseSession session,
    BoardModerationLog row, {
    required _is.ColumnSelections<BoardModerationLogTable> conflictColumns,
    _is.ColumnSelections<BoardModerationLogTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardModerationLogTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BoardModerationLog>(
      row,
      conflictColumns: conflictColumns(BoardModerationLog.t),
      updateColumns: updateColumns?.call(BoardModerationLog.t),
      updateWhere: updateWhere?.call(BoardModerationLog.t),
      transaction: transaction,
    );
  }

  /// Updates all [BoardModerationLog]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardModerationLog>> update(
    _is.DatabaseSession session,
    List<BoardModerationLog> rows, {
    _is.ColumnSelections<BoardModerationLogTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BoardModerationLog>(
      rows,
      columns: columns?.call(BoardModerationLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BoardModerationLog]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BoardModerationLog> updateRow(
    _is.DatabaseSession session,
    BoardModerationLog row, {
    _is.ColumnSelections<BoardModerationLogTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BoardModerationLog>(
      row,
      columns: columns?.call(BoardModerationLog.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BoardModerationLog] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BoardModerationLog?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BoardModerationLogUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BoardModerationLog>(
      id,
      columnValues: columnValues(BoardModerationLog.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BoardModerationLog]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardModerationLog>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BoardModerationLogUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<BoardModerationLogTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardModerationLogTable>? orderBy,
    _is.OrderByListBuilder<BoardModerationLogTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BoardModerationLog>(
      columnValues: columnValues(BoardModerationLog.t.updateTable),
      where: where(BoardModerationLog.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardModerationLog.t),
      orderByList: orderByList?.call(BoardModerationLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BoardModerationLog]s in the list and returns the deleted rows.
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
  Future<List<BoardModerationLog>> delete(
    _is.DatabaseSession session,
    List<BoardModerationLog> rows, {
    _is.OrderByBuilder<BoardModerationLogTable>? orderBy,
    _is.OrderByListBuilder<BoardModerationLogTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BoardModerationLog>(
      rows,
      orderBy: orderBy?.call(BoardModerationLog.t),
      orderByList: orderByList?.call(BoardModerationLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BoardModerationLog].
  Future<BoardModerationLog> deleteRow(
    _is.DatabaseSession session,
    BoardModerationLog row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BoardModerationLog>(
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
  Future<List<BoardModerationLog>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardModerationLogTable> where,
    _is.OrderByBuilder<BoardModerationLogTable>? orderBy,
    _is.OrderByListBuilder<BoardModerationLogTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BoardModerationLog>(
      where: where(BoardModerationLog.t),
      orderBy: orderBy?.call(BoardModerationLog.t),
      orderByList: orderByList?.call(BoardModerationLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardModerationLogTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BoardModerationLog>(
      where: where?.call(BoardModerationLog.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BoardModerationLog] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardModerationLogTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BoardModerationLog>(
      where: where(BoardModerationLog.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
