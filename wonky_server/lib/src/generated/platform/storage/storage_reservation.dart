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

/// (v2) Quota held for an upload that has not completed (Drive 03 §5).
abstract class StorageReservation
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  StorageReservation._({
    this.id,
    required this.userId,
    required this.fileUuid,
    this.itemId,
    required this.bytes,
    required this.createdAt,
    required this.expiresAt,
  });

  factory StorageReservation({
    int? id,
    required int userId,
    required _is.UuidValue fileUuid,
    int? itemId,
    required int bytes,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) = _StorageReservationImpl;

  factory StorageReservation.fromJson(Map<String, dynamic> jsonSerialization) {
    return StorageReservation(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      fileUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['fileUuid'],
      ),
      itemId: jsonSerialization['itemId'] as int?,
      bytes: jsonSerialization['bytes'] as int,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  static final t = StorageReservationTable();

  static const db = StorageReservationRepository._();

  @override
  int? id;

  int userId;

  /// The StoredFile being uploaded.
  _is.UuidValue fileUuid;

  int? itemId;

  int bytes;

  DateTime createdAt;

  /// createdAt + 24 h.
  DateTime expiresAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [StorageReservation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StorageReservation copyWith({
    int? id,
    int? userId,
    _is.UuidValue? fileUuid,
    int? itemId,
    int? bytes,
    DateTime? createdAt,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StorageReservation',
      if (id != null) 'id': id,
      'userId': userId,
      'fileUuid': fileUuid.toJson(),
      if (itemId != null) 'itemId': itemId,
      'bytes': bytes,
      'createdAt': createdAt.toJson(),
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static StorageReservationInclude include() {
    return StorageReservationInclude._();
  }

  static StorageReservationIncludeList includeList({
    _is.WhereExpressionBuilder<StorageReservationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StorageReservationTable>? orderBy,
    _is.OrderByListBuilder<StorageReservationTable>? orderByList,
    StorageReservationInclude? include,
  }) {
    return StorageReservationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StorageReservation.t),
      orderByList: orderByList?.call(StorageReservation.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StorageReservationImpl extends StorageReservation {
  _StorageReservationImpl({
    int? id,
    required int userId,
    required _is.UuidValue fileUuid,
    int? itemId,
    required int bytes,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) : super._(
         id: id,
         userId: userId,
         fileUuid: fileUuid,
         itemId: itemId,
         bytes: bytes,
         createdAt: createdAt,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [StorageReservation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StorageReservation copyWith({
    Object? id = _Undefined,
    int? userId,
    _is.UuidValue? fileUuid,
    Object? itemId = _Undefined,
    int? bytes,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return StorageReservation(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      fileUuid: fileUuid ?? this.fileUuid,
      itemId: itemId is int? ? itemId : this.itemId,
      bytes: bytes ?? this.bytes,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

class StorageReservationUpdateTable
    extends _is.UpdateTable<StorageReservationTable> {
  StorageReservationUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> fileUuid(_is.UuidValue value) =>
      _is.ColumnValue(
        table.fileUuid,
        value,
      );

  _is.ColumnValue<int, int> itemId(int? value) => _is.ColumnValue(
    table.itemId,
    value,
  );

  _is.ColumnValue<int, int> bytes(int value) => _is.ColumnValue(
    table.bytes,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> expiresAt(DateTime value) =>
      _is.ColumnValue(
        table.expiresAt,
        value,
      );
}

class StorageReservationTable extends _is.Table<int?> {
  StorageReservationTable({super.tableRelation})
    : super(tableName: 'storage_reservation') {
    updateTable = StorageReservationUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    fileUuid = _is.ColumnUuid(
      'fileUuid',
      this,
    );
    itemId = _is.ColumnInt(
      'itemId',
      this,
    );
    bytes = _is.ColumnInt(
      'bytes',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    expiresAt = _is.ColumnDateTime(
      'expiresAt',
      this,
    );
  }

  late final StorageReservationUpdateTable updateTable;

  late final _is.ColumnInt userId;

  /// The StoredFile being uploaded.
  late final _is.ColumnUuid fileUuid;

  late final _is.ColumnInt itemId;

  late final _is.ColumnInt bytes;

  late final _is.ColumnDateTime createdAt;

  /// createdAt + 24 h.
  late final _is.ColumnDateTime expiresAt;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    fileUuid,
    itemId,
    bytes,
    createdAt,
    expiresAt,
  ];
}

class StorageReservationInclude extends _is.IncludeObject {
  StorageReservationInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => StorageReservation.t;
}

class StorageReservationIncludeList extends _is.IncludeList {
  StorageReservationIncludeList._({
    _is.WhereExpressionBuilder<StorageReservationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(StorageReservation.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => StorageReservation.t;
}

class StorageReservationRepository {
  const StorageReservationRepository._();

  /// Returns a list of [StorageReservation]s matching the given query parameters.
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
  Future<List<StorageReservation>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StorageReservationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StorageReservationTable>? orderBy,
    _is.OrderByListBuilder<StorageReservationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<StorageReservation>(
      where: where?.call(StorageReservation.t),
      orderBy: orderBy?.call(StorageReservation.t),
      orderByList: orderByList?.call(StorageReservation.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [StorageReservation]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `StorageReservation.t`.
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
  _ida.Stream<List<StorageReservation>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StorageReservationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StorageReservationTable>? orderBy,
    _is.OrderByListBuilder<StorageReservationTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<StorageReservation>(
      where: where?.call(StorageReservation.t),
      orderBy: orderBy?.call(StorageReservation.t),
      orderByList: orderByList?.call(StorageReservation.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [StorageReservation] matching the given query parameters.
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
  Future<StorageReservation?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StorageReservationTable>? where,
    int? offset,
    _is.OrderByBuilder<StorageReservationTable>? orderBy,
    _is.OrderByListBuilder<StorageReservationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<StorageReservation>(
      where: where?.call(StorageReservation.t),
      orderBy: orderBy?.call(StorageReservation.t),
      orderByList: orderByList?.call(StorageReservation.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [StorageReservation] by its [id] or null if no such row exists.
  Future<StorageReservation?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<StorageReservation>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [StorageReservation]s in the list and returns the inserted rows.
  ///
  /// The returned [StorageReservation]s will have their `id` fields set.
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
  Future<List<StorageReservation>> insert(
    _is.DatabaseSession session,
    List<StorageReservation> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<StorageReservation>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [StorageReservation] and returns the inserted row.
  ///
  /// The returned [StorageReservation] will have its `id` field set.
  Future<StorageReservation> insertRow(
    _is.DatabaseSession session,
    StorageReservation row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<StorageReservation>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [StorageReservation]s in the list and returns the resulting rows.
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
  /// The returned [StorageReservation]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StorageReservation>> upsert(
    _is.DatabaseSession session,
    List<StorageReservation> rows, {
    required _is.ColumnSelections<StorageReservationTable> conflictColumns,
    _is.ColumnSelections<StorageReservationTable>? updateColumns,
    _is.WhereExpressionBuilder<StorageReservationTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<StorageReservation>(
      rows,
      conflictColumns: conflictColumns(StorageReservation.t),
      updateColumns: updateColumns?.call(StorageReservation.t),
      updateWhere: updateWhere?.call(StorageReservation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [StorageReservation] and returns the resulting row.
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
  /// The returned [StorageReservation] will have its `id` field set.
  Future<StorageReservation?> upsertRow(
    _is.DatabaseSession session,
    StorageReservation row, {
    required _is.ColumnSelections<StorageReservationTable> conflictColumns,
    _is.ColumnSelections<StorageReservationTable>? updateColumns,
    _is.WhereExpressionBuilder<StorageReservationTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<StorageReservation>(
      row,
      conflictColumns: conflictColumns(StorageReservation.t),
      updateColumns: updateColumns?.call(StorageReservation.t),
      updateWhere: updateWhere?.call(StorageReservation.t),
      transaction: transaction,
    );
  }

  /// Updates all [StorageReservation]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StorageReservation>> update(
    _is.DatabaseSession session,
    List<StorageReservation> rows, {
    _is.ColumnSelections<StorageReservationTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<StorageReservation>(
      rows,
      columns: columns?.call(StorageReservation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [StorageReservation]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<StorageReservation> updateRow(
    _is.DatabaseSession session,
    StorageReservation row, {
    _is.ColumnSelections<StorageReservationTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<StorageReservation>(
      row,
      columns: columns?.call(StorageReservation.t),
      transaction: transaction,
    );
  }

  /// Updates a single [StorageReservation] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<StorageReservation?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<StorageReservationUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<StorageReservation>(
      id,
      columnValues: columnValues(StorageReservation.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [StorageReservation]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StorageReservation>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<StorageReservationUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<StorageReservationTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StorageReservationTable>? orderBy,
    _is.OrderByListBuilder<StorageReservationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<StorageReservation>(
      columnValues: columnValues(StorageReservation.t.updateTable),
      where: where(StorageReservation.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StorageReservation.t),
      orderByList: orderByList?.call(StorageReservation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [StorageReservation]s in the list and returns the deleted rows.
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
  Future<List<StorageReservation>> delete(
    _is.DatabaseSession session,
    List<StorageReservation> rows, {
    _is.OrderByBuilder<StorageReservationTable>? orderBy,
    _is.OrderByListBuilder<StorageReservationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<StorageReservation>(
      rows,
      orderBy: orderBy?.call(StorageReservation.t),
      orderByList: orderByList?.call(StorageReservation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [StorageReservation].
  Future<StorageReservation> deleteRow(
    _is.DatabaseSession session,
    StorageReservation row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<StorageReservation>(
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
  Future<List<StorageReservation>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StorageReservationTable> where,
    _is.OrderByBuilder<StorageReservationTable>? orderBy,
    _is.OrderByListBuilder<StorageReservationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<StorageReservation>(
      where: where(StorageReservation.t),
      orderBy: orderBy?.call(StorageReservation.t),
      orderByList: orderByList?.call(StorageReservation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StorageReservationTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<StorageReservation>(
      where: where?.call(StorageReservation.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [StorageReservation] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StorageReservationTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<StorageReservation>(
      where: where(StorageReservation.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
