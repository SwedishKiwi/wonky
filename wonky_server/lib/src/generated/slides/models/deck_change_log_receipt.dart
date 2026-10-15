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

/// Claims a synced DeckChangeLog row for processing (exactly-once
/// consumption, Slides 02 §8, 09 §5; as SheetsChangeLogReceipt). Rows are
/// claimed (insert, unique on changeLogId) before the consumer plugins run
/// and completed afterwards; a claim that never completed (server crash) is
/// retried after a grace period, skipping the plugins already done.
abstract class DeckChangeLogReceipt
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  DeckChangeLogReceipt._({
    this.id,
    required this.changeLogId,
    required this.deckUuid,
    required this.processedAt,
    this.completedAt,
    required this.doneConsumers,
  });

  factory DeckChangeLogReceipt({
    int? id,
    required _is.UuidValue changeLogId,
    required _is.UuidValue deckUuid,
    required DateTime processedAt,
    DateTime? completedAt,
    required List<String> doneConsumers,
  }) = _DeckChangeLogReceiptImpl;

  factory DeckChangeLogReceipt.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DeckChangeLogReceipt(
      id: jsonSerialization['id'] as int?,
      changeLogId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['changeLogId'],
      ),
      deckUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['deckUuid'],
      ),
      processedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['processedAt'],
      ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      doneConsumers: _il4umwa0.Protocol().deserialize<List<String>>(
        jsonSerialization['doneConsumers'],
      ),
    );
  }

  static final t = DeckChangeLogReceiptTable();

  static const db = DeckChangeLogReceiptRepository._();

  @override
  int? id;

  _is.UuidValue changeLogId;

  _is.UuidValue deckUuid;

  /// When the row was claimed.
  DateTime processedAt;

  /// When every consumer plugin ran; null while processing (or after a crash).
  DateTime? completedAt;

  /// Ids of the plugins that consumed the row (DeckChangeLogConsumer.id):
  /// a re-claimed row only runs the others (exactly once per plugin).
  List<String> doneConsumers;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [DeckChangeLogReceipt]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DeckChangeLogReceipt copyWith({
    int? id,
    _is.UuidValue? changeLogId,
    _is.UuidValue? deckUuid,
    DateTime? processedAt,
    DateTime? completedAt = const _is.$UndefinedDateTime(),
    List<String>? doneConsumers,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DeckChangeLogReceipt',
      if (id != null) 'id': id,
      'changeLogId': changeLogId.toJson(),
      'deckUuid': deckUuid.toJson(),
      'processedAt': processedAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      'doneConsumers': doneConsumers.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DeckChangeLogReceiptInclude include() {
    return DeckChangeLogReceiptInclude._();
  }

  static DeckChangeLogReceiptIncludeList includeList({
    _is.WhereExpressionBuilder<DeckChangeLogReceiptTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DeckChangeLogReceiptTable>? orderBy,
    _is.OrderByListBuilder<DeckChangeLogReceiptTable>? orderByList,
    DeckChangeLogReceiptInclude? include,
  }) {
    return DeckChangeLogReceiptIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DeckChangeLogReceipt.t),
      orderByList: orderByList?.call(DeckChangeLogReceipt.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DeckChangeLogReceiptImpl extends DeckChangeLogReceipt {
  _DeckChangeLogReceiptImpl({
    int? id,
    required _is.UuidValue changeLogId,
    required _is.UuidValue deckUuid,
    required DateTime processedAt,
    DateTime? completedAt,
    required List<String> doneConsumers,
  }) : super._(
         id: id,
         changeLogId: changeLogId,
         deckUuid: deckUuid,
         processedAt: processedAt,
         completedAt: completedAt,
         doneConsumers: doneConsumers,
       );

  /// Returns a shallow copy of this [DeckChangeLogReceipt]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DeckChangeLogReceipt copyWith({
    Object? id = _Undefined,
    _is.UuidValue? changeLogId,
    _is.UuidValue? deckUuid,
    DateTime? processedAt,
    DateTime? completedAt = const _is.$UndefinedDateTime(),
    List<String>? doneConsumers,
  }) {
    return DeckChangeLogReceipt(
      id: id is int? ? id : this.id,
      changeLogId: changeLogId ?? this.changeLogId,
      deckUuid: deckUuid ?? this.deckUuid,
      processedAt: processedAt ?? this.processedAt,
      completedAt: completedAt is _is.UndefinedSentinel
          ? this.completedAt
          : completedAt,
      doneConsumers:
          doneConsumers ?? this.doneConsumers.map((e0) => e0).toList(),
    );
  }
}

class DeckChangeLogReceiptUpdateTable
    extends _is.UpdateTable<DeckChangeLogReceiptTable> {
  DeckChangeLogReceiptUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> changeLogId(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.changeLogId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> deckUuid(_is.UuidValue value) =>
      _is.ColumnValue(
        table.deckUuid,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> processedAt(DateTime value) =>
      _is.ColumnValue(
        table.processedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _is.ColumnValue(
        table.completedAt,
        value,
      );

  _is.ColumnValue<List<String>, List<String>> doneConsumers(
    List<String> value,
  ) => _is.ColumnValue(
    table.doneConsumers,
    value,
  );
}

class DeckChangeLogReceiptTable extends _is.Table<int?> {
  DeckChangeLogReceiptTable({super.tableRelation})
    : super(tableName: 'deck_change_log_receipt') {
    updateTable = DeckChangeLogReceiptUpdateTable(this);
    changeLogId = _is.ColumnUuid(
      'changeLogId',
      this,
    );
    deckUuid = _is.ColumnUuid(
      'deckUuid',
      this,
    );
    processedAt = _is.ColumnDateTime(
      'processedAt',
      this,
    );
    completedAt = _is.ColumnDateTime(
      'completedAt',
      this,
    );
    doneConsumers = _is.ColumnSerializable<List<String>>(
      'doneConsumers',
      this,
    );
  }

  late final DeckChangeLogReceiptUpdateTable updateTable;

  late final _is.ColumnUuid changeLogId;

  late final _is.ColumnUuid deckUuid;

  /// When the row was claimed.
  late final _is.ColumnDateTime processedAt;

  /// When every consumer plugin ran; null while processing (or after a crash).
  late final _is.ColumnDateTime completedAt;

  /// Ids of the plugins that consumed the row (DeckChangeLogConsumer.id):
  /// a re-claimed row only runs the others (exactly once per plugin).
  late final _is.ColumnSerializable<List<String>> doneConsumers;

  @override
  List<_is.Column> get columns => [
    id,
    changeLogId,
    deckUuid,
    processedAt,
    completedAt,
    doneConsumers,
  ];
}

class DeckChangeLogReceiptInclude extends _is.IncludeObject {
  DeckChangeLogReceiptInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => DeckChangeLogReceipt.t;
}

class DeckChangeLogReceiptIncludeList extends _is.IncludeList {
  DeckChangeLogReceiptIncludeList._({
    _is.WhereExpressionBuilder<DeckChangeLogReceiptTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DeckChangeLogReceipt.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => DeckChangeLogReceipt.t;
}

class DeckChangeLogReceiptRepository {
  const DeckChangeLogReceiptRepository._();

  /// Returns a list of [DeckChangeLogReceipt]s matching the given query parameters.
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
  Future<List<DeckChangeLogReceipt>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DeckChangeLogReceiptTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DeckChangeLogReceiptTable>? orderBy,
    _is.OrderByListBuilder<DeckChangeLogReceiptTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DeckChangeLogReceipt>(
      where: where?.call(DeckChangeLogReceipt.t),
      orderBy: orderBy?.call(DeckChangeLogReceipt.t),
      orderByList: orderByList?.call(DeckChangeLogReceipt.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [DeckChangeLogReceipt]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `DeckChangeLogReceipt.t`.
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
  _ida.Stream<List<DeckChangeLogReceipt>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DeckChangeLogReceiptTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DeckChangeLogReceiptTable>? orderBy,
    _is.OrderByListBuilder<DeckChangeLogReceiptTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<DeckChangeLogReceipt>(
      where: where?.call(DeckChangeLogReceipt.t),
      orderBy: orderBy?.call(DeckChangeLogReceipt.t),
      orderByList: orderByList?.call(DeckChangeLogReceipt.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [DeckChangeLogReceipt] matching the given query parameters.
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
  Future<DeckChangeLogReceipt?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DeckChangeLogReceiptTable>? where,
    int? offset,
    _is.OrderByBuilder<DeckChangeLogReceiptTable>? orderBy,
    _is.OrderByListBuilder<DeckChangeLogReceiptTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DeckChangeLogReceipt>(
      where: where?.call(DeckChangeLogReceipt.t),
      orderBy: orderBy?.call(DeckChangeLogReceipt.t),
      orderByList: orderByList?.call(DeckChangeLogReceipt.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DeckChangeLogReceipt] by its [id] or null if no such row exists.
  Future<DeckChangeLogReceipt?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DeckChangeLogReceipt>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DeckChangeLogReceipt]s in the list and returns the inserted rows.
  ///
  /// The returned [DeckChangeLogReceipt]s will have their `id` fields set.
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
  Future<List<DeckChangeLogReceipt>> insert(
    _is.DatabaseSession session,
    List<DeckChangeLogReceipt> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DeckChangeLogReceipt>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DeckChangeLogReceipt] and returns the inserted row.
  ///
  /// The returned [DeckChangeLogReceipt] will have its `id` field set.
  Future<DeckChangeLogReceipt> insertRow(
    _is.DatabaseSession session,
    DeckChangeLogReceipt row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<DeckChangeLogReceipt>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [DeckChangeLogReceipt]s in the list and returns the resulting rows.
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
  /// The returned [DeckChangeLogReceipt]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeckChangeLogReceipt>> upsert(
    _is.DatabaseSession session,
    List<DeckChangeLogReceipt> rows, {
    required _is.ColumnSelections<DeckChangeLogReceiptTable> conflictColumns,
    _is.ColumnSelections<DeckChangeLogReceiptTable>? updateColumns,
    _is.WhereExpressionBuilder<DeckChangeLogReceiptTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DeckChangeLogReceipt>(
      rows,
      conflictColumns: conflictColumns(DeckChangeLogReceipt.t),
      updateColumns: updateColumns?.call(DeckChangeLogReceipt.t),
      updateWhere: updateWhere?.call(DeckChangeLogReceipt.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DeckChangeLogReceipt] and returns the resulting row.
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
  /// The returned [DeckChangeLogReceipt] will have its `id` field set.
  Future<DeckChangeLogReceipt?> upsertRow(
    _is.DatabaseSession session,
    DeckChangeLogReceipt row, {
    required _is.ColumnSelections<DeckChangeLogReceiptTable> conflictColumns,
    _is.ColumnSelections<DeckChangeLogReceiptTable>? updateColumns,
    _is.WhereExpressionBuilder<DeckChangeLogReceiptTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DeckChangeLogReceipt>(
      row,
      conflictColumns: conflictColumns(DeckChangeLogReceipt.t),
      updateColumns: updateColumns?.call(DeckChangeLogReceipt.t),
      updateWhere: updateWhere?.call(DeckChangeLogReceipt.t),
      transaction: transaction,
    );
  }

  /// Updates all [DeckChangeLogReceipt]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeckChangeLogReceipt>> update(
    _is.DatabaseSession session,
    List<DeckChangeLogReceipt> rows, {
    _is.ColumnSelections<DeckChangeLogReceiptTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DeckChangeLogReceipt>(
      rows,
      columns: columns?.call(DeckChangeLogReceipt.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DeckChangeLogReceipt]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DeckChangeLogReceipt> updateRow(
    _is.DatabaseSession session,
    DeckChangeLogReceipt row, {
    _is.ColumnSelections<DeckChangeLogReceiptTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<DeckChangeLogReceipt>(
      row,
      columns: columns?.call(DeckChangeLogReceipt.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DeckChangeLogReceipt] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DeckChangeLogReceipt?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<DeckChangeLogReceiptUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<DeckChangeLogReceipt>(
      id,
      columnValues: columnValues(DeckChangeLogReceipt.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DeckChangeLogReceipt]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeckChangeLogReceipt>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<DeckChangeLogReceiptUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<DeckChangeLogReceiptTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DeckChangeLogReceiptTable>? orderBy,
    _is.OrderByListBuilder<DeckChangeLogReceiptTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DeckChangeLogReceipt>(
      columnValues: columnValues(DeckChangeLogReceipt.t.updateTable),
      where: where(DeckChangeLogReceipt.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DeckChangeLogReceipt.t),
      orderByList: orderByList?.call(DeckChangeLogReceipt.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DeckChangeLogReceipt]s in the list and returns the deleted rows.
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
  Future<List<DeckChangeLogReceipt>> delete(
    _is.DatabaseSession session,
    List<DeckChangeLogReceipt> rows, {
    _is.OrderByBuilder<DeckChangeLogReceiptTable>? orderBy,
    _is.OrderByListBuilder<DeckChangeLogReceiptTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DeckChangeLogReceipt>(
      rows,
      orderBy: orderBy?.call(DeckChangeLogReceipt.t),
      orderByList: orderByList?.call(DeckChangeLogReceipt.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DeckChangeLogReceipt].
  Future<DeckChangeLogReceipt> deleteRow(
    _is.DatabaseSession session,
    DeckChangeLogReceipt row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DeckChangeLogReceipt>(
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
  Future<List<DeckChangeLogReceipt>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DeckChangeLogReceiptTable> where,
    _is.OrderByBuilder<DeckChangeLogReceiptTable>? orderBy,
    _is.OrderByListBuilder<DeckChangeLogReceiptTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DeckChangeLogReceipt>(
      where: where(DeckChangeLogReceipt.t),
      orderBy: orderBy?.call(DeckChangeLogReceipt.t),
      orderByList: orderByList?.call(DeckChangeLogReceipt.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DeckChangeLogReceiptTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<DeckChangeLogReceipt>(
      where: where?.call(DeckChangeLogReceipt.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DeckChangeLogReceipt] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DeckChangeLogReceiptTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DeckChangeLogReceipt>(
      where: where(DeckChangeLogReceipt.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
