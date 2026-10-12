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
import '../../platform/common/access_role.dart' as _iv7g6vuy;

/// Link sharing of an item; one row per item (specs/06 §2.2).
abstract class ShareLink
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  ShareLink._({
    this.id,
    required this.itemId,
    required this.token,
    this.role,
    required this.createdById,
    required this.createdAt,
  });

  factory ShareLink({
    int? id,
    required int itemId,
    required String token,
    _iv7g6vuy.AccessRole? role,
    required int createdById,
    required DateTime createdAt,
  }) = _ShareLinkImpl;

  factory ShareLink.fromJson(Map<String, dynamic> jsonSerialization) {
    return ShareLink(
      id: jsonSerialization['id'] as int?,
      itemId: jsonSerialization['itemId'] as int,
      token: jsonSerialization['token'] as String,
      role: jsonSerialization['role'] == null
          ? null
          : _iv7g6vuy.AccessRole.fromJson(
              (jsonSerialization['role'] as String),
            ),
      createdById: jsonSerialization['createdById'] as int,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = ShareLinkTable();

  static const db = ShareLinkRepository._();

  @override
  int? id;

  int itemId;

  /// 22-char random url-safe token.
  String token;

  /// Null = link sharing off ("Restricted").
  _iv7g6vuy.AccessRole? role;

  int createdById;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [ShareLink]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ShareLink copyWith({
    int? id,
    int? itemId,
    String? token,
    _iv7g6vuy.AccessRole? role,
    int? createdById,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ShareLink',
      if (id != null) 'id': id,
      'itemId': itemId,
      'token': token,
      if (role != null) 'role': role?.toJson(),
      'createdById': createdById,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ShareLink',
      if (id != null) 'id': id,
      'itemId': itemId,
      'token': token,
      if (role != null) 'role': role?.toJson(),
      'createdById': createdById,
      'createdAt': createdAt.toJson(),
    };
  }

  static ShareLinkInclude include() {
    return ShareLinkInclude._();
  }

  static ShareLinkIncludeList includeList({
    _is.WhereExpressionBuilder<ShareLinkTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ShareLinkTable>? orderBy,
    _is.OrderByListBuilder<ShareLinkTable>? orderByList,
    ShareLinkInclude? include,
  }) {
    return ShareLinkIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ShareLink.t),
      orderByList: orderByList?.call(ShareLink.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ShareLinkImpl extends ShareLink {
  _ShareLinkImpl({
    int? id,
    required int itemId,
    required String token,
    _iv7g6vuy.AccessRole? role,
    required int createdById,
    required DateTime createdAt,
  }) : super._(
         id: id,
         itemId: itemId,
         token: token,
         role: role,
         createdById: createdById,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ShareLink]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ShareLink copyWith({
    Object? id = _Undefined,
    int? itemId,
    String? token,
    Object? role = _Undefined,
    int? createdById,
    DateTime? createdAt,
  }) {
    return ShareLink(
      id: id is int? ? id : this.id,
      itemId: itemId ?? this.itemId,
      token: token ?? this.token,
      role: role is _iv7g6vuy.AccessRole? ? role : this.role,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ShareLinkUpdateTable extends _is.UpdateTable<ShareLinkTable> {
  ShareLinkUpdateTable(super.table);

  _is.ColumnValue<int, int> itemId(int value) => _is.ColumnValue(
    table.itemId,
    value,
  );

  _is.ColumnValue<String, String> token(String value) => _is.ColumnValue(
    table.token,
    value,
  );

  _is.ColumnValue<_iv7g6vuy.AccessRole, _iv7g6vuy.AccessRole> role(
    _iv7g6vuy.AccessRole? value,
  ) => _is.ColumnValue(
    table.role,
    value,
  );

  _is.ColumnValue<int, int> createdById(int value) => _is.ColumnValue(
    table.createdById,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class ShareLinkTable extends _is.Table<int?> {
  ShareLinkTable({super.tableRelation}) : super(tableName: 'share_link') {
    updateTable = ShareLinkUpdateTable(this);
    itemId = _is.ColumnInt(
      'itemId',
      this,
    );
    token = _is.ColumnString(
      'token',
      this,
    );
    role = _is.ColumnEnum(
      'role',
      this,
      _is.EnumSerialization.byName,
    );
    createdById = _is.ColumnInt(
      'createdById',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final ShareLinkUpdateTable updateTable;

  late final _is.ColumnInt itemId;

  /// 22-char random url-safe token.
  late final _is.ColumnString token;

  /// Null = link sharing off ("Restricted").
  late final _is.ColumnEnum<_iv7g6vuy.AccessRole> role;

  late final _is.ColumnInt createdById;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    itemId,
    token,
    role,
    createdById,
    createdAt,
  ];
}

class ShareLinkInclude extends _is.IncludeObject {
  ShareLinkInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => ShareLink.t;
}

class ShareLinkIncludeList extends _is.IncludeList {
  ShareLinkIncludeList._({
    _is.WhereExpressionBuilder<ShareLinkTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ShareLink.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => ShareLink.t;
}

class ShareLinkRepository {
  const ShareLinkRepository._();

  /// Returns a list of [ShareLink]s matching the given query parameters.
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
  Future<List<ShareLink>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ShareLinkTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ShareLinkTable>? orderBy,
    _is.OrderByListBuilder<ShareLinkTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ShareLink>(
      where: where?.call(ShareLink.t),
      orderBy: orderBy?.call(ShareLink.t),
      orderByList: orderByList?.call(ShareLink.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ShareLink]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ShareLink.t`.
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
  _ida.Stream<List<ShareLink>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ShareLinkTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ShareLinkTable>? orderBy,
    _is.OrderByListBuilder<ShareLinkTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ShareLink>(
      where: where?.call(ShareLink.t),
      orderBy: orderBy?.call(ShareLink.t),
      orderByList: orderByList?.call(ShareLink.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ShareLink] matching the given query parameters.
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
  Future<ShareLink?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ShareLinkTable>? where,
    int? offset,
    _is.OrderByBuilder<ShareLinkTable>? orderBy,
    _is.OrderByListBuilder<ShareLinkTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ShareLink>(
      where: where?.call(ShareLink.t),
      orderBy: orderBy?.call(ShareLink.t),
      orderByList: orderByList?.call(ShareLink.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ShareLink] by its [id] or null if no such row exists.
  Future<ShareLink?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ShareLink>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ShareLink]s in the list and returns the inserted rows.
  ///
  /// The returned [ShareLink]s will have their `id` fields set.
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
  Future<List<ShareLink>> insert(
    _is.DatabaseSession session,
    List<ShareLink> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ShareLink>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ShareLink] and returns the inserted row.
  ///
  /// The returned [ShareLink] will have its `id` field set.
  Future<ShareLink> insertRow(
    _is.DatabaseSession session,
    ShareLink row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<ShareLink>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [ShareLink]s in the list and returns the resulting rows.
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
  /// The returned [ShareLink]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ShareLink>> upsert(
    _is.DatabaseSession session,
    List<ShareLink> rows, {
    required _is.ColumnSelections<ShareLinkTable> conflictColumns,
    _is.ColumnSelections<ShareLinkTable>? updateColumns,
    _is.WhereExpressionBuilder<ShareLinkTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ShareLink>(
      rows,
      conflictColumns: conflictColumns(ShareLink.t),
      updateColumns: updateColumns?.call(ShareLink.t),
      updateWhere: updateWhere?.call(ShareLink.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ShareLink] and returns the resulting row.
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
  /// The returned [ShareLink] will have its `id` field set.
  Future<ShareLink?> upsertRow(
    _is.DatabaseSession session,
    ShareLink row, {
    required _is.ColumnSelections<ShareLinkTable> conflictColumns,
    _is.ColumnSelections<ShareLinkTable>? updateColumns,
    _is.WhereExpressionBuilder<ShareLinkTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ShareLink>(
      row,
      conflictColumns: conflictColumns(ShareLink.t),
      updateColumns: updateColumns?.call(ShareLink.t),
      updateWhere: updateWhere?.call(ShareLink.t),
      transaction: transaction,
    );
  }

  /// Updates all [ShareLink]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ShareLink>> update(
    _is.DatabaseSession session,
    List<ShareLink> rows, {
    _is.ColumnSelections<ShareLinkTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ShareLink>(
      rows,
      columns: columns?.call(ShareLink.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ShareLink]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ShareLink> updateRow(
    _is.DatabaseSession session,
    ShareLink row, {
    _is.ColumnSelections<ShareLinkTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<ShareLink>(
      row,
      columns: columns?.call(ShareLink.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ShareLink] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ShareLink?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<ShareLinkUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<ShareLink>(
      id,
      columnValues: columnValues(ShareLink.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ShareLink]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ShareLink>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<ShareLinkUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<ShareLinkTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ShareLinkTable>? orderBy,
    _is.OrderByListBuilder<ShareLinkTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ShareLink>(
      columnValues: columnValues(ShareLink.t.updateTable),
      where: where(ShareLink.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ShareLink.t),
      orderByList: orderByList?.call(ShareLink.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ShareLink]s in the list and returns the deleted rows.
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
  Future<List<ShareLink>> delete(
    _is.DatabaseSession session,
    List<ShareLink> rows, {
    _is.OrderByBuilder<ShareLinkTable>? orderBy,
    _is.OrderByListBuilder<ShareLinkTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ShareLink>(
      rows,
      orderBy: orderBy?.call(ShareLink.t),
      orderByList: orderByList?.call(ShareLink.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ShareLink].
  Future<ShareLink> deleteRow(
    _is.DatabaseSession session,
    ShareLink row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ShareLink>(
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
  Future<List<ShareLink>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ShareLinkTable> where,
    _is.OrderByBuilder<ShareLinkTable>? orderBy,
    _is.OrderByListBuilder<ShareLinkTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ShareLink>(
      where: where(ShareLink.t),
      orderBy: orderBy?.call(ShareLink.t),
      orderByList: orderByList?.call(ShareLink.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ShareLinkTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<ShareLink>(
      where: where?.call(ShareLink.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ShareLink] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ShareLinkTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ShareLink>(
      where: where(ShareLink.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
