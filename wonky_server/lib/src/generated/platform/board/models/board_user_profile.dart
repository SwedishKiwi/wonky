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

/// Board-specific data of a user: GitHub login, blocks.
abstract class BoardUserProfile
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  BoardUserProfile._({
    this.id,
    required this.userId,
    this.githubLogin,
    this.blockedAt,
    this.blockedUntil,
    this.blockedReason,
    this.blockedById,
  });

  factory BoardUserProfile({
    int? id,
    required int userId,
    String? githubLogin,
    DateTime? blockedAt,
    DateTime? blockedUntil,
    String? blockedReason,
    int? blockedById,
  }) = _BoardUserProfileImpl;

  factory BoardUserProfile.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardUserProfile(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      githubLogin: jsonSerialization['githubLogin'] as String?,
      blockedAt: jsonSerialization['blockedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['blockedAt']),
      blockedUntil: jsonSerialization['blockedUntil'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['blockedUntil'],
            ),
      blockedReason: jsonSerialization['blockedReason'] as String?,
      blockedById: jsonSerialization['blockedById'] as int?,
    );
  }

  static final t = BoardUserProfileTable();

  static const db = BoardUserProfileRepository._();

  @override
  int? id;

  int userId;

  String? githubLogin;

  DateTime? blockedAt;

  DateTime? blockedUntil;

  String? blockedReason;

  int? blockedById;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [BoardUserProfile]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardUserProfile copyWith({
    int? id,
    int? userId,
    String? githubLogin,
    DateTime? blockedAt = const _is.$UndefinedDateTime(),
    DateTime? blockedUntil = const _is.$UndefinedDateTime(),
    String? blockedReason,
    int? blockedById,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardUserProfile',
      if (id != null) 'id': id,
      'userId': userId,
      if (githubLogin != null) 'githubLogin': githubLogin,
      if (blockedAt != null) 'blockedAt': blockedAt?.toJson(),
      if (blockedUntil != null) 'blockedUntil': blockedUntil?.toJson(),
      if (blockedReason != null) 'blockedReason': blockedReason,
      if (blockedById != null) 'blockedById': blockedById,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardUserProfile',
      if (id != null) 'id': id,
      'userId': userId,
      if (githubLogin != null) 'githubLogin': githubLogin,
      if (blockedAt != null) 'blockedAt': blockedAt?.toJson(),
      if (blockedUntil != null) 'blockedUntil': blockedUntil?.toJson(),
      if (blockedReason != null) 'blockedReason': blockedReason,
      if (blockedById != null) 'blockedById': blockedById,
    };
  }

  static BoardUserProfileInclude include() {
    return BoardUserProfileInclude._();
  }

  static BoardUserProfileIncludeList includeList({
    _is.WhereExpressionBuilder<BoardUserProfileTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardUserProfileTable>? orderBy,
    _is.OrderByListBuilder<BoardUserProfileTable>? orderByList,
    BoardUserProfileInclude? include,
  }) {
    return BoardUserProfileIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardUserProfile.t),
      orderByList: orderByList?.call(BoardUserProfile.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardUserProfileImpl extends BoardUserProfile {
  _BoardUserProfileImpl({
    int? id,
    required int userId,
    String? githubLogin,
    DateTime? blockedAt,
    DateTime? blockedUntil,
    String? blockedReason,
    int? blockedById,
  }) : super._(
         id: id,
         userId: userId,
         githubLogin: githubLogin,
         blockedAt: blockedAt,
         blockedUntil: blockedUntil,
         blockedReason: blockedReason,
         blockedById: blockedById,
       );

  /// Returns a shallow copy of this [BoardUserProfile]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardUserProfile copyWith({
    Object? id = _Undefined,
    int? userId,
    Object? githubLogin = _Undefined,
    DateTime? blockedAt = const _is.$UndefinedDateTime(),
    DateTime? blockedUntil = const _is.$UndefinedDateTime(),
    Object? blockedReason = _Undefined,
    Object? blockedById = _Undefined,
  }) {
    return BoardUserProfile(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      githubLogin: githubLogin is String? ? githubLogin : this.githubLogin,
      blockedAt: blockedAt is _is.UndefinedSentinel
          ? this.blockedAt
          : blockedAt,
      blockedUntil: blockedUntil is _is.UndefinedSentinel
          ? this.blockedUntil
          : blockedUntil,
      blockedReason: blockedReason is String?
          ? blockedReason
          : this.blockedReason,
      blockedById: blockedById is int? ? blockedById : this.blockedById,
    );
  }
}

class BoardUserProfileUpdateTable
    extends _is.UpdateTable<BoardUserProfileTable> {
  BoardUserProfileUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<String, String> githubLogin(String? value) => _is.ColumnValue(
    table.githubLogin,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> blockedAt(DateTime? value) =>
      _is.ColumnValue(
        table.blockedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> blockedUntil(DateTime? value) =>
      _is.ColumnValue(
        table.blockedUntil,
        value,
      );

  _is.ColumnValue<String, String> blockedReason(String? value) =>
      _is.ColumnValue(
        table.blockedReason,
        value,
      );

  _is.ColumnValue<int, int> blockedById(int? value) => _is.ColumnValue(
    table.blockedById,
    value,
  );
}

class BoardUserProfileTable extends _is.Table<int?> {
  BoardUserProfileTable({super.tableRelation})
    : super(tableName: 'board_user_profile') {
    updateTable = BoardUserProfileUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    githubLogin = _is.ColumnString(
      'githubLogin',
      this,
    );
    blockedAt = _is.ColumnDateTime(
      'blockedAt',
      this,
    );
    blockedUntil = _is.ColumnDateTime(
      'blockedUntil',
      this,
    );
    blockedReason = _is.ColumnString(
      'blockedReason',
      this,
    );
    blockedById = _is.ColumnInt(
      'blockedById',
      this,
    );
  }

  late final BoardUserProfileUpdateTable updateTable;

  late final _is.ColumnInt userId;

  late final _is.ColumnString githubLogin;

  late final _is.ColumnDateTime blockedAt;

  late final _is.ColumnDateTime blockedUntil;

  late final _is.ColumnString blockedReason;

  late final _is.ColumnInt blockedById;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    githubLogin,
    blockedAt,
    blockedUntil,
    blockedReason,
    blockedById,
  ];
}

class BoardUserProfileInclude extends _is.IncludeObject {
  BoardUserProfileInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => BoardUserProfile.t;
}

class BoardUserProfileIncludeList extends _is.IncludeList {
  BoardUserProfileIncludeList._({
    _is.WhereExpressionBuilder<BoardUserProfileTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BoardUserProfile.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => BoardUserProfile.t;
}

class BoardUserProfileRepository {
  const BoardUserProfileRepository._();

  /// Returns a list of [BoardUserProfile]s matching the given query parameters.
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
  Future<List<BoardUserProfile>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardUserProfileTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardUserProfileTable>? orderBy,
    _is.OrderByListBuilder<BoardUserProfileTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BoardUserProfile>(
      where: where?.call(BoardUserProfile.t),
      orderBy: orderBy?.call(BoardUserProfile.t),
      orderByList: orderByList?.call(BoardUserProfile.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [BoardUserProfile]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `BoardUserProfile.t`.
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
  _ida.Stream<List<BoardUserProfile>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardUserProfileTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardUserProfileTable>? orderBy,
    _is.OrderByListBuilder<BoardUserProfileTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<BoardUserProfile>(
      where: where?.call(BoardUserProfile.t),
      orderBy: orderBy?.call(BoardUserProfile.t),
      orderByList: orderByList?.call(BoardUserProfile.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [BoardUserProfile] matching the given query parameters.
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
  Future<BoardUserProfile?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardUserProfileTable>? where,
    int? offset,
    _is.OrderByBuilder<BoardUserProfileTable>? orderBy,
    _is.OrderByListBuilder<BoardUserProfileTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BoardUserProfile>(
      where: where?.call(BoardUserProfile.t),
      orderBy: orderBy?.call(BoardUserProfile.t),
      orderByList: orderByList?.call(BoardUserProfile.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BoardUserProfile] by its [id] or null if no such row exists.
  Future<BoardUserProfile?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BoardUserProfile>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BoardUserProfile]s in the list and returns the inserted rows.
  ///
  /// The returned [BoardUserProfile]s will have their `id` fields set.
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
  Future<List<BoardUserProfile>> insert(
    _is.DatabaseSession session,
    List<BoardUserProfile> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BoardUserProfile>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BoardUserProfile] and returns the inserted row.
  ///
  /// The returned [BoardUserProfile] will have its `id` field set.
  Future<BoardUserProfile> insertRow(
    _is.DatabaseSession session,
    BoardUserProfile row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BoardUserProfile>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BoardUserProfile]s in the list and returns the resulting rows.
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
  /// The returned [BoardUserProfile]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardUserProfile>> upsert(
    _is.DatabaseSession session,
    List<BoardUserProfile> rows, {
    required _is.ColumnSelections<BoardUserProfileTable> conflictColumns,
    _is.ColumnSelections<BoardUserProfileTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardUserProfileTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BoardUserProfile>(
      rows,
      conflictColumns: conflictColumns(BoardUserProfile.t),
      updateColumns: updateColumns?.call(BoardUserProfile.t),
      updateWhere: updateWhere?.call(BoardUserProfile.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BoardUserProfile] and returns the resulting row.
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
  /// The returned [BoardUserProfile] will have its `id` field set.
  Future<BoardUserProfile?> upsertRow(
    _is.DatabaseSession session,
    BoardUserProfile row, {
    required _is.ColumnSelections<BoardUserProfileTable> conflictColumns,
    _is.ColumnSelections<BoardUserProfileTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardUserProfileTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BoardUserProfile>(
      row,
      conflictColumns: conflictColumns(BoardUserProfile.t),
      updateColumns: updateColumns?.call(BoardUserProfile.t),
      updateWhere: updateWhere?.call(BoardUserProfile.t),
      transaction: transaction,
    );
  }

  /// Updates all [BoardUserProfile]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardUserProfile>> update(
    _is.DatabaseSession session,
    List<BoardUserProfile> rows, {
    _is.ColumnSelections<BoardUserProfileTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BoardUserProfile>(
      rows,
      columns: columns?.call(BoardUserProfile.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BoardUserProfile]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BoardUserProfile> updateRow(
    _is.DatabaseSession session,
    BoardUserProfile row, {
    _is.ColumnSelections<BoardUserProfileTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BoardUserProfile>(
      row,
      columns: columns?.call(BoardUserProfile.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BoardUserProfile] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BoardUserProfile?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BoardUserProfileUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BoardUserProfile>(
      id,
      columnValues: columnValues(BoardUserProfile.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BoardUserProfile]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardUserProfile>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BoardUserProfileUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<BoardUserProfileTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardUserProfileTable>? orderBy,
    _is.OrderByListBuilder<BoardUserProfileTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BoardUserProfile>(
      columnValues: columnValues(BoardUserProfile.t.updateTable),
      where: where(BoardUserProfile.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardUserProfile.t),
      orderByList: orderByList?.call(BoardUserProfile.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BoardUserProfile]s in the list and returns the deleted rows.
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
  Future<List<BoardUserProfile>> delete(
    _is.DatabaseSession session,
    List<BoardUserProfile> rows, {
    _is.OrderByBuilder<BoardUserProfileTable>? orderBy,
    _is.OrderByListBuilder<BoardUserProfileTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BoardUserProfile>(
      rows,
      orderBy: orderBy?.call(BoardUserProfile.t),
      orderByList: orderByList?.call(BoardUserProfile.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BoardUserProfile].
  Future<BoardUserProfile> deleteRow(
    _is.DatabaseSession session,
    BoardUserProfile row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BoardUserProfile>(
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
  Future<List<BoardUserProfile>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardUserProfileTable> where,
    _is.OrderByBuilder<BoardUserProfileTable>? orderBy,
    _is.OrderByListBuilder<BoardUserProfileTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BoardUserProfile>(
      where: where(BoardUserProfile.t),
      orderBy: orderBy?.call(BoardUserProfile.t),
      orderByList: orderByList?.call(BoardUserProfile.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardUserProfileTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BoardUserProfile>(
      where: where?.call(BoardUserProfile.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BoardUserProfile] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardUserProfileTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BoardUserProfile>(
      where: where(BoardUserProfile.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
