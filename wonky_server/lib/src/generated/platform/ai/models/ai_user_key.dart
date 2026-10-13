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
import '../../../platform/ai/models/ai_provider.dart' as _i1k6plh5;

/// A user's own AI provider API key (suite 10 §1 "Keys"). Only used when
/// the server has no key of its own. Server-only: the key is never sent to
/// a client (clients see `AiProviderKeyView`).
abstract class AiUserKey
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  AiUserKey._({
    this.id,
    required this.userId,
    required this.provider,
    required this.apiKey,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiUserKey({
    int? id,
    required int userId,
    required _i1k6plh5.AiProvider provider,
    required String apiKey,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AiUserKeyImpl;

  factory AiUserKey.fromJson(Map<String, dynamic> jsonSerialization) {
    return AiUserKey(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      provider: _i1k6plh5.AiProvider.fromJson(
        (jsonSerialization['provider'] as String),
      ),
      apiKey: jsonSerialization['apiKey'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = AiUserKeyTable();

  static const db = AiUserKeyRepository._();

  @override
  int? id;

  int userId;

  _i1k6plh5.AiProvider provider;

  String apiKey;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [AiUserKey]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AiUserKey copyWith({
    int? id,
    int? userId,
    _i1k6plh5.AiProvider? provider,
    String? apiKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AiUserKey',
      if (id != null) 'id': id,
      'userId': userId,
      'provider': provider.toJson(),
      'apiKey': apiKey,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static AiUserKeyInclude include() {
    return AiUserKeyInclude._();
  }

  static AiUserKeyIncludeList includeList({
    _is.WhereExpressionBuilder<AiUserKeyTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiUserKeyTable>? orderBy,
    _is.OrderByListBuilder<AiUserKeyTable>? orderByList,
    AiUserKeyInclude? include,
  }) {
    return AiUserKeyIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AiUserKey.t),
      orderByList: orderByList?.call(AiUserKey.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AiUserKeyImpl extends AiUserKey {
  _AiUserKeyImpl({
    int? id,
    required int userId,
    required _i1k6plh5.AiProvider provider,
    required String apiKey,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         userId: userId,
         provider: provider,
         apiKey: apiKey,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [AiUserKey]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AiUserKey copyWith({
    Object? id = _Undefined,
    int? userId,
    _i1k6plh5.AiProvider? provider,
    String? apiKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiUserKey(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AiUserKeyUpdateTable extends _is.UpdateTable<AiUserKeyTable> {
  AiUserKeyUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<_i1k6plh5.AiProvider, _i1k6plh5.AiProvider> provider(
    _i1k6plh5.AiProvider value,
  ) => _is.ColumnValue(
    table.provider,
    value,
  );

  _is.ColumnValue<String, String> apiKey(String value) => _is.ColumnValue(
    table.apiKey,
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

class AiUserKeyTable extends _is.Table<int?> {
  AiUserKeyTable({super.tableRelation}) : super(tableName: 'ai_user_key') {
    updateTable = AiUserKeyUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    provider = _is.ColumnEnum(
      'provider',
      this,
      _is.EnumSerialization.byName,
    );
    apiKey = _is.ColumnString(
      'apiKey',
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

  late final AiUserKeyUpdateTable updateTable;

  late final _is.ColumnInt userId;

  late final _is.ColumnEnum<_i1k6plh5.AiProvider> provider;

  late final _is.ColumnString apiKey;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    provider,
    apiKey,
    createdAt,
    updatedAt,
  ];
}

class AiUserKeyInclude extends _is.IncludeObject {
  AiUserKeyInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => AiUserKey.t;
}

class AiUserKeyIncludeList extends _is.IncludeList {
  AiUserKeyIncludeList._({
    _is.WhereExpressionBuilder<AiUserKeyTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AiUserKey.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => AiUserKey.t;
}

class AiUserKeyRepository {
  const AiUserKeyRepository._();

  /// Returns a list of [AiUserKey]s matching the given query parameters.
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
  Future<List<AiUserKey>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiUserKeyTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiUserKeyTable>? orderBy,
    _is.OrderByListBuilder<AiUserKeyTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AiUserKey>(
      where: where?.call(AiUserKey.t),
      orderBy: orderBy?.call(AiUserKey.t),
      orderByList: orderByList?.call(AiUserKey.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [AiUserKey]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `AiUserKey.t`.
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
  _ida.Stream<List<AiUserKey>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiUserKeyTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiUserKeyTable>? orderBy,
    _is.OrderByListBuilder<AiUserKeyTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<AiUserKey>(
      where: where?.call(AiUserKey.t),
      orderBy: orderBy?.call(AiUserKey.t),
      orderByList: orderByList?.call(AiUserKey.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [AiUserKey] matching the given query parameters.
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
  Future<AiUserKey?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiUserKeyTable>? where,
    int? offset,
    _is.OrderByBuilder<AiUserKeyTable>? orderBy,
    _is.OrderByListBuilder<AiUserKeyTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AiUserKey>(
      where: where?.call(AiUserKey.t),
      orderBy: orderBy?.call(AiUserKey.t),
      orderByList: orderByList?.call(AiUserKey.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AiUserKey] by its [id] or null if no such row exists.
  Future<AiUserKey?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AiUserKey>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AiUserKey]s in the list and returns the inserted rows.
  ///
  /// The returned [AiUserKey]s will have their `id` fields set.
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
  Future<List<AiUserKey>> insert(
    _is.DatabaseSession session,
    List<AiUserKey> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<AiUserKey>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [AiUserKey] and returns the inserted row.
  ///
  /// The returned [AiUserKey] will have its `id` field set.
  Future<AiUserKey> insertRow(
    _is.DatabaseSession session,
    AiUserKey row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<AiUserKey>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [AiUserKey]s in the list and returns the resulting rows.
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
  /// The returned [AiUserKey]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AiUserKey>> upsert(
    _is.DatabaseSession session,
    List<AiUserKey> rows, {
    required _is.ColumnSelections<AiUserKeyTable> conflictColumns,
    _is.ColumnSelections<AiUserKeyTable>? updateColumns,
    _is.WhereExpressionBuilder<AiUserKeyTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<AiUserKey>(
      rows,
      conflictColumns: conflictColumns(AiUserKey.t),
      updateColumns: updateColumns?.call(AiUserKey.t),
      updateWhere: updateWhere?.call(AiUserKey.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [AiUserKey] and returns the resulting row.
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
  /// The returned [AiUserKey] will have its `id` field set.
  Future<AiUserKey?> upsertRow(
    _is.DatabaseSession session,
    AiUserKey row, {
    required _is.ColumnSelections<AiUserKeyTable> conflictColumns,
    _is.ColumnSelections<AiUserKeyTable>? updateColumns,
    _is.WhereExpressionBuilder<AiUserKeyTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<AiUserKey>(
      row,
      conflictColumns: conflictColumns(AiUserKey.t),
      updateColumns: updateColumns?.call(AiUserKey.t),
      updateWhere: updateWhere?.call(AiUserKey.t),
      transaction: transaction,
    );
  }

  /// Updates all [AiUserKey]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AiUserKey>> update(
    _is.DatabaseSession session,
    List<AiUserKey> rows, {
    _is.ColumnSelections<AiUserKeyTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<AiUserKey>(
      rows,
      columns: columns?.call(AiUserKey.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [AiUserKey]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AiUserKey> updateRow(
    _is.DatabaseSession session,
    AiUserKey row, {
    _is.ColumnSelections<AiUserKeyTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<AiUserKey>(
      row,
      columns: columns?.call(AiUserKey.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AiUserKey] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AiUserKey?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<AiUserKeyUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<AiUserKey>(
      id,
      columnValues: columnValues(AiUserKey.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AiUserKey]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AiUserKey>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<AiUserKeyUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<AiUserKeyTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiUserKeyTable>? orderBy,
    _is.OrderByListBuilder<AiUserKeyTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<AiUserKey>(
      columnValues: columnValues(AiUserKey.t.updateTable),
      where: where(AiUserKey.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AiUserKey.t),
      orderByList: orderByList?.call(AiUserKey.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [AiUserKey]s in the list and returns the deleted rows.
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
  Future<List<AiUserKey>> delete(
    _is.DatabaseSession session,
    List<AiUserKey> rows, {
    _is.OrderByBuilder<AiUserKeyTable>? orderBy,
    _is.OrderByListBuilder<AiUserKeyTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<AiUserKey>(
      rows,
      orderBy: orderBy?.call(AiUserKey.t),
      orderByList: orderByList?.call(AiUserKey.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [AiUserKey].
  Future<AiUserKey> deleteRow(
    _is.DatabaseSession session,
    AiUserKey row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AiUserKey>(
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
  Future<List<AiUserKey>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AiUserKeyTable> where,
    _is.OrderByBuilder<AiUserKeyTable>? orderBy,
    _is.OrderByListBuilder<AiUserKeyTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<AiUserKey>(
      where: where(AiUserKey.t),
      orderBy: orderBy?.call(AiUserKey.t),
      orderByList: orderByList?.call(AiUserKey.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiUserKeyTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<AiUserKey>(
      where: where?.call(AiUserKey.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AiUserKey] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AiUserKeyTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AiUserKey>(
      where: where(AiUserKey.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
