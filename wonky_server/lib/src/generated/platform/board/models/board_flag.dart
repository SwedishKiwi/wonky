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
import '../../../platform/board/models/board_flag_reason.dart' as _ienu5u16;

/// A user's flag on a post or comment (specs/16 §7.5).
abstract class BoardFlag
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  BoardFlag._({
    this.id,
    this.postId,
    this.commentId,
    required this.userId,
    required this.reason,
    this.note,
    required this.createdAt,
  });

  factory BoardFlag({
    int? id,
    int? postId,
    int? commentId,
    required int userId,
    required _ienu5u16.BoardFlagReason reason,
    String? note,
    required DateTime createdAt,
  }) = _BoardFlagImpl;

  factory BoardFlag.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardFlag(
      id: jsonSerialization['id'] as int?,
      postId: jsonSerialization['postId'] as int?,
      commentId: jsonSerialization['commentId'] as int?,
      userId: jsonSerialization['userId'] as int,
      reason: _ienu5u16.BoardFlagReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
      note: jsonSerialization['note'] as String?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = BoardFlagTable();

  static const db = BoardFlagRepository._();

  @override
  int? id;

  int? postId;

  int? commentId;

  int userId;

  _ienu5u16.BoardFlagReason reason;

  String? note;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [BoardFlag]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardFlag copyWith({
    int? id,
    int? postId,
    int? commentId,
    int? userId,
    _ienu5u16.BoardFlagReason? reason,
    String? note,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardFlag',
      if (id != null) 'id': id,
      if (postId != null) 'postId': postId,
      if (commentId != null) 'commentId': commentId,
      'userId': userId,
      'reason': reason.toJson(),
      if (note != null) 'note': note,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardFlag',
      if (id != null) 'id': id,
      if (postId != null) 'postId': postId,
      if (commentId != null) 'commentId': commentId,
      'userId': userId,
      'reason': reason.toJson(),
      if (note != null) 'note': note,
      'createdAt': createdAt.toJson(),
    };
  }

  static BoardFlagInclude include() {
    return BoardFlagInclude._();
  }

  static BoardFlagIncludeList includeList({
    _is.WhereExpressionBuilder<BoardFlagTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardFlagTable>? orderBy,
    _is.OrderByListBuilder<BoardFlagTable>? orderByList,
    BoardFlagInclude? include,
  }) {
    return BoardFlagIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardFlag.t),
      orderByList: orderByList?.call(BoardFlag.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardFlagImpl extends BoardFlag {
  _BoardFlagImpl({
    int? id,
    int? postId,
    int? commentId,
    required int userId,
    required _ienu5u16.BoardFlagReason reason,
    String? note,
    required DateTime createdAt,
  }) : super._(
         id: id,
         postId: postId,
         commentId: commentId,
         userId: userId,
         reason: reason,
         note: note,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [BoardFlag]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardFlag copyWith({
    Object? id = _Undefined,
    Object? postId = _Undefined,
    Object? commentId = _Undefined,
    int? userId,
    _ienu5u16.BoardFlagReason? reason,
    Object? note = _Undefined,
    DateTime? createdAt,
  }) {
    return BoardFlag(
      id: id is int? ? id : this.id,
      postId: postId is int? ? postId : this.postId,
      commentId: commentId is int? ? commentId : this.commentId,
      userId: userId ?? this.userId,
      reason: reason ?? this.reason,
      note: note is String? ? note : this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class BoardFlagUpdateTable extends _is.UpdateTable<BoardFlagTable> {
  BoardFlagUpdateTable(super.table);

  _is.ColumnValue<int, int> postId(int? value) => _is.ColumnValue(
    table.postId,
    value,
  );

  _is.ColumnValue<int, int> commentId(int? value) => _is.ColumnValue(
    table.commentId,
    value,
  );

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<_ienu5u16.BoardFlagReason, _ienu5u16.BoardFlagReason> reason(
    _ienu5u16.BoardFlagReason value,
  ) => _is.ColumnValue(
    table.reason,
    value,
  );

  _is.ColumnValue<String, String> note(String? value) => _is.ColumnValue(
    table.note,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class BoardFlagTable extends _is.Table<int?> {
  BoardFlagTable({super.tableRelation}) : super(tableName: 'board_flag') {
    updateTable = BoardFlagUpdateTable(this);
    postId = _is.ColumnInt(
      'postId',
      this,
    );
    commentId = _is.ColumnInt(
      'commentId',
      this,
    );
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    reason = _is.ColumnEnum(
      'reason',
      this,
      _is.EnumSerialization.byName,
    );
    note = _is.ColumnString(
      'note',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final BoardFlagUpdateTable updateTable;

  late final _is.ColumnInt postId;

  late final _is.ColumnInt commentId;

  late final _is.ColumnInt userId;

  late final _is.ColumnEnum<_ienu5u16.BoardFlagReason> reason;

  late final _is.ColumnString note;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    postId,
    commentId,
    userId,
    reason,
    note,
    createdAt,
  ];
}

class BoardFlagInclude extends _is.IncludeObject {
  BoardFlagInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => BoardFlag.t;
}

class BoardFlagIncludeList extends _is.IncludeList {
  BoardFlagIncludeList._({
    _is.WhereExpressionBuilder<BoardFlagTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BoardFlag.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => BoardFlag.t;
}

class BoardFlagRepository {
  const BoardFlagRepository._();

  /// Returns a list of [BoardFlag]s matching the given query parameters.
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
  Future<List<BoardFlag>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardFlagTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardFlagTable>? orderBy,
    _is.OrderByListBuilder<BoardFlagTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BoardFlag>(
      where: where?.call(BoardFlag.t),
      orderBy: orderBy?.call(BoardFlag.t),
      orderByList: orderByList?.call(BoardFlag.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [BoardFlag]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `BoardFlag.t`.
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
  _ida.Stream<List<BoardFlag>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardFlagTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardFlagTable>? orderBy,
    _is.OrderByListBuilder<BoardFlagTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<BoardFlag>(
      where: where?.call(BoardFlag.t),
      orderBy: orderBy?.call(BoardFlag.t),
      orderByList: orderByList?.call(BoardFlag.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [BoardFlag] matching the given query parameters.
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
  Future<BoardFlag?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardFlagTable>? where,
    int? offset,
    _is.OrderByBuilder<BoardFlagTable>? orderBy,
    _is.OrderByListBuilder<BoardFlagTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BoardFlag>(
      where: where?.call(BoardFlag.t),
      orderBy: orderBy?.call(BoardFlag.t),
      orderByList: orderByList?.call(BoardFlag.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BoardFlag] by its [id] or null if no such row exists.
  Future<BoardFlag?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BoardFlag>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BoardFlag]s in the list and returns the inserted rows.
  ///
  /// The returned [BoardFlag]s will have their `id` fields set.
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
  Future<List<BoardFlag>> insert(
    _is.DatabaseSession session,
    List<BoardFlag> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BoardFlag>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BoardFlag] and returns the inserted row.
  ///
  /// The returned [BoardFlag] will have its `id` field set.
  Future<BoardFlag> insertRow(
    _is.DatabaseSession session,
    BoardFlag row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BoardFlag>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BoardFlag]s in the list and returns the resulting rows.
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
  /// The returned [BoardFlag]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardFlag>> upsert(
    _is.DatabaseSession session,
    List<BoardFlag> rows, {
    required _is.ColumnSelections<BoardFlagTable> conflictColumns,
    _is.ColumnSelections<BoardFlagTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardFlagTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BoardFlag>(
      rows,
      conflictColumns: conflictColumns(BoardFlag.t),
      updateColumns: updateColumns?.call(BoardFlag.t),
      updateWhere: updateWhere?.call(BoardFlag.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BoardFlag] and returns the resulting row.
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
  /// The returned [BoardFlag] will have its `id` field set.
  Future<BoardFlag?> upsertRow(
    _is.DatabaseSession session,
    BoardFlag row, {
    required _is.ColumnSelections<BoardFlagTable> conflictColumns,
    _is.ColumnSelections<BoardFlagTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardFlagTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BoardFlag>(
      row,
      conflictColumns: conflictColumns(BoardFlag.t),
      updateColumns: updateColumns?.call(BoardFlag.t),
      updateWhere: updateWhere?.call(BoardFlag.t),
      transaction: transaction,
    );
  }

  /// Updates all [BoardFlag]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardFlag>> update(
    _is.DatabaseSession session,
    List<BoardFlag> rows, {
    _is.ColumnSelections<BoardFlagTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BoardFlag>(
      rows,
      columns: columns?.call(BoardFlag.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BoardFlag]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BoardFlag> updateRow(
    _is.DatabaseSession session,
    BoardFlag row, {
    _is.ColumnSelections<BoardFlagTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BoardFlag>(
      row,
      columns: columns?.call(BoardFlag.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BoardFlag] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BoardFlag?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BoardFlagUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BoardFlag>(
      id,
      columnValues: columnValues(BoardFlag.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BoardFlag]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardFlag>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BoardFlagUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<BoardFlagTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardFlagTable>? orderBy,
    _is.OrderByListBuilder<BoardFlagTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BoardFlag>(
      columnValues: columnValues(BoardFlag.t.updateTable),
      where: where(BoardFlag.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardFlag.t),
      orderByList: orderByList?.call(BoardFlag.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BoardFlag]s in the list and returns the deleted rows.
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
  Future<List<BoardFlag>> delete(
    _is.DatabaseSession session,
    List<BoardFlag> rows, {
    _is.OrderByBuilder<BoardFlagTable>? orderBy,
    _is.OrderByListBuilder<BoardFlagTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BoardFlag>(
      rows,
      orderBy: orderBy?.call(BoardFlag.t),
      orderByList: orderByList?.call(BoardFlag.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BoardFlag].
  Future<BoardFlag> deleteRow(
    _is.DatabaseSession session,
    BoardFlag row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BoardFlag>(
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
  Future<List<BoardFlag>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardFlagTable> where,
    _is.OrderByBuilder<BoardFlagTable>? orderBy,
    _is.OrderByListBuilder<BoardFlagTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BoardFlag>(
      where: where(BoardFlag.t),
      orderBy: orderBy?.call(BoardFlag.t),
      orderByList: orderByList?.call(BoardFlag.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardFlagTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BoardFlag>(
      where: where?.call(BoardFlag.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BoardFlag] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardFlagTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BoardFlag>(
      where: where(BoardFlag.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
