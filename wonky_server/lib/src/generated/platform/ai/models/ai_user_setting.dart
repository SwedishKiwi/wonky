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
import '../../../platform/ai/models/ai_quality.dart' as _i054hihs;

/// Per-user AI settings beyond the opt-out (`UserPreferences.aiEnabled`).
abstract class AiUserSetting
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  AiUserSetting._({
    this.id,
    required this.userId,
    _i054hihs.AiQuality? quality,
    required this.updatedAt,
  }) : quality = quality ?? _i054hihs.AiQuality.best;

  factory AiUserSetting({
    int? id,
    required int userId,
    _i054hihs.AiQuality? quality,
    required DateTime updatedAt,
  }) = _AiUserSettingImpl;

  factory AiUserSetting.fromJson(Map<String, dynamic> jsonSerialization) {
    return AiUserSetting(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      quality: jsonSerialization['quality'] == null
          ? null
          : _i054hihs.AiQuality.fromJson(
              (jsonSerialization['quality'] as String),
            ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = AiUserSettingTable();

  static const db = AiUserSettingRepository._();

  @override
  int? id;

  int userId;

  _i054hihs.AiQuality quality;

  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [AiUserSetting]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AiUserSetting copyWith({
    int? id,
    int? userId,
    _i054hihs.AiQuality? quality,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AiUserSetting',
      if (id != null) 'id': id,
      'userId': userId,
      'quality': quality.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AiUserSetting',
      if (id != null) 'id': id,
      'userId': userId,
      'quality': quality.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  static AiUserSettingInclude include() {
    return AiUserSettingInclude._();
  }

  static AiUserSettingIncludeList includeList({
    _is.WhereExpressionBuilder<AiUserSettingTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiUserSettingTable>? orderBy,
    _is.OrderByListBuilder<AiUserSettingTable>? orderByList,
    AiUserSettingInclude? include,
  }) {
    return AiUserSettingIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AiUserSetting.t),
      orderByList: orderByList?.call(AiUserSetting.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AiUserSettingImpl extends AiUserSetting {
  _AiUserSettingImpl({
    int? id,
    required int userId,
    _i054hihs.AiQuality? quality,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         userId: userId,
         quality: quality,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [AiUserSetting]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AiUserSetting copyWith({
    Object? id = _Undefined,
    int? userId,
    _i054hihs.AiQuality? quality,
    DateTime? updatedAt,
  }) {
    return AiUserSetting(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      quality: quality ?? this.quality,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AiUserSettingUpdateTable extends _is.UpdateTable<AiUserSettingTable> {
  AiUserSettingUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<_i054hihs.AiQuality, _i054hihs.AiQuality> quality(
    _i054hihs.AiQuality value,
  ) => _is.ColumnValue(
    table.quality,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class AiUserSettingTable extends _is.Table<int?> {
  AiUserSettingTable({super.tableRelation})
    : super(tableName: 'ai_user_setting') {
    updateTable = AiUserSettingUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    quality = _is.ColumnEnum(
      'quality',
      this,
      _is.EnumSerialization.byName,
      hasDefault: true,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final AiUserSettingUpdateTable updateTable;

  late final _is.ColumnInt userId;

  late final _is.ColumnEnum<_i054hihs.AiQuality> quality;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    quality,
    updatedAt,
  ];
}

class AiUserSettingInclude extends _is.IncludeObject {
  AiUserSettingInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => AiUserSetting.t;
}

class AiUserSettingIncludeList extends _is.IncludeList {
  AiUserSettingIncludeList._({
    _is.WhereExpressionBuilder<AiUserSettingTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AiUserSetting.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => AiUserSetting.t;
}

class AiUserSettingRepository {
  const AiUserSettingRepository._();

  /// Returns a list of [AiUserSetting]s matching the given query parameters.
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
  Future<List<AiUserSetting>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiUserSettingTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiUserSettingTable>? orderBy,
    _is.OrderByListBuilder<AiUserSettingTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AiUserSetting>(
      where: where?.call(AiUserSetting.t),
      orderBy: orderBy?.call(AiUserSetting.t),
      orderByList: orderByList?.call(AiUserSetting.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [AiUserSetting]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `AiUserSetting.t`.
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
  _ida.Stream<List<AiUserSetting>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiUserSettingTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiUserSettingTable>? orderBy,
    _is.OrderByListBuilder<AiUserSettingTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<AiUserSetting>(
      where: where?.call(AiUserSetting.t),
      orderBy: orderBy?.call(AiUserSetting.t),
      orderByList: orderByList?.call(AiUserSetting.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [AiUserSetting] matching the given query parameters.
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
  Future<AiUserSetting?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiUserSettingTable>? where,
    int? offset,
    _is.OrderByBuilder<AiUserSettingTable>? orderBy,
    _is.OrderByListBuilder<AiUserSettingTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AiUserSetting>(
      where: where?.call(AiUserSetting.t),
      orderBy: orderBy?.call(AiUserSetting.t),
      orderByList: orderByList?.call(AiUserSetting.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AiUserSetting] by its [id] or null if no such row exists.
  Future<AiUserSetting?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AiUserSetting>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AiUserSetting]s in the list and returns the inserted rows.
  ///
  /// The returned [AiUserSetting]s will have their `id` fields set.
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
  Future<List<AiUserSetting>> insert(
    _is.DatabaseSession session,
    List<AiUserSetting> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<AiUserSetting>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [AiUserSetting] and returns the inserted row.
  ///
  /// The returned [AiUserSetting] will have its `id` field set.
  Future<AiUserSetting> insertRow(
    _is.DatabaseSession session,
    AiUserSetting row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<AiUserSetting>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [AiUserSetting]s in the list and returns the resulting rows.
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
  /// The returned [AiUserSetting]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AiUserSetting>> upsert(
    _is.DatabaseSession session,
    List<AiUserSetting> rows, {
    required _is.ColumnSelections<AiUserSettingTable> conflictColumns,
    _is.ColumnSelections<AiUserSettingTable>? updateColumns,
    _is.WhereExpressionBuilder<AiUserSettingTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<AiUserSetting>(
      rows,
      conflictColumns: conflictColumns(AiUserSetting.t),
      updateColumns: updateColumns?.call(AiUserSetting.t),
      updateWhere: updateWhere?.call(AiUserSetting.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [AiUserSetting] and returns the resulting row.
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
  /// The returned [AiUserSetting] will have its `id` field set.
  Future<AiUserSetting?> upsertRow(
    _is.DatabaseSession session,
    AiUserSetting row, {
    required _is.ColumnSelections<AiUserSettingTable> conflictColumns,
    _is.ColumnSelections<AiUserSettingTable>? updateColumns,
    _is.WhereExpressionBuilder<AiUserSettingTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<AiUserSetting>(
      row,
      conflictColumns: conflictColumns(AiUserSetting.t),
      updateColumns: updateColumns?.call(AiUserSetting.t),
      updateWhere: updateWhere?.call(AiUserSetting.t),
      transaction: transaction,
    );
  }

  /// Updates all [AiUserSetting]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AiUserSetting>> update(
    _is.DatabaseSession session,
    List<AiUserSetting> rows, {
    _is.ColumnSelections<AiUserSettingTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<AiUserSetting>(
      rows,
      columns: columns?.call(AiUserSetting.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [AiUserSetting]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AiUserSetting> updateRow(
    _is.DatabaseSession session,
    AiUserSetting row, {
    _is.ColumnSelections<AiUserSettingTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<AiUserSetting>(
      row,
      columns: columns?.call(AiUserSetting.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AiUserSetting] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AiUserSetting?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<AiUserSettingUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<AiUserSetting>(
      id,
      columnValues: columnValues(AiUserSetting.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AiUserSetting]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AiUserSetting>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<AiUserSettingUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<AiUserSettingTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AiUserSettingTable>? orderBy,
    _is.OrderByListBuilder<AiUserSettingTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<AiUserSetting>(
      columnValues: columnValues(AiUserSetting.t.updateTable),
      where: where(AiUserSetting.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AiUserSetting.t),
      orderByList: orderByList?.call(AiUserSetting.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [AiUserSetting]s in the list and returns the deleted rows.
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
  Future<List<AiUserSetting>> delete(
    _is.DatabaseSession session,
    List<AiUserSetting> rows, {
    _is.OrderByBuilder<AiUserSettingTable>? orderBy,
    _is.OrderByListBuilder<AiUserSettingTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<AiUserSetting>(
      rows,
      orderBy: orderBy?.call(AiUserSetting.t),
      orderByList: orderByList?.call(AiUserSetting.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [AiUserSetting].
  Future<AiUserSetting> deleteRow(
    _is.DatabaseSession session,
    AiUserSetting row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AiUserSetting>(
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
  Future<List<AiUserSetting>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AiUserSettingTable> where,
    _is.OrderByBuilder<AiUserSettingTable>? orderBy,
    _is.OrderByListBuilder<AiUserSettingTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<AiUserSetting>(
      where: where(AiUserSetting.t),
      orderBy: orderBy?.call(AiUserSetting.t),
      orderByList: orderByList?.call(AiUserSetting.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AiUserSettingTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<AiUserSetting>(
      where: where?.call(AiUserSetting.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AiUserSetting] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AiUserSettingTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AiUserSetting>(
      where: where(AiUserSetting.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
