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

/// Per Sheets version: sheet list, changed ranges and authors (Sheets 10 §5.1.2).
abstract class SheetsSnapshotIndex
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SheetsSnapshotIndex._({
    this.id,
    required this.itemVersionId,
    required this.sheetsJson,
    required this.changedRangesJson,
    required this.authorIds,
    this.diffFileId,
  });

  factory SheetsSnapshotIndex({
    int? id,
    required int itemVersionId,
    required String sheetsJson,
    required String changedRangesJson,
    required List<int> authorIds,
    _is.UuidValue? diffFileId,
  }) = _SheetsSnapshotIndexImpl;

  factory SheetsSnapshotIndex.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsSnapshotIndex(
      id: jsonSerialization['id'] as int?,
      itemVersionId: jsonSerialization['itemVersionId'] as int,
      sheetsJson: jsonSerialization['sheetsJson'] as String,
      changedRangesJson: jsonSerialization['changedRangesJson'] as String,
      authorIds: _il4umwa0.Protocol().deserialize<List<int>>(
        jsonSerialization['authorIds'],
      ),
      diffFileId: jsonSerialization['diffFileId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['diffFileId'],
            ),
    );
  }

  static final t = SheetsSnapshotIndexTable();

  static const db = SheetsSnapshotIndexRepository._();

  @override
  int? id;

  int itemVersionId;

  String sheetsJson;

  String changedRangesJson;

  List<int> authorIds;

  _is.UuidValue? diffFileId;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SheetsSnapshotIndex]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SheetsSnapshotIndex copyWith({
    int? id,
    int? itemVersionId,
    String? sheetsJson,
    String? changedRangesJson,
    List<int>? authorIds,
    _is.UuidValue? diffFileId = const _is.$UndefinedUuidValue(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsSnapshotIndex',
      if (id != null) 'id': id,
      'itemVersionId': itemVersionId,
      'sheetsJson': sheetsJson,
      'changedRangesJson': changedRangesJson,
      'authorIds': authorIds.toJson(),
      if (diffFileId != null) 'diffFileId': diffFileId?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SheetsSnapshotIndexInclude include() {
    return SheetsSnapshotIndexInclude._();
  }

  static SheetsSnapshotIndexIncludeList includeList({
    _is.WhereExpressionBuilder<SheetsSnapshotIndexTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SheetsSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SheetsSnapshotIndexTable>? orderByList,
    SheetsSnapshotIndexInclude? include,
  }) {
    return SheetsSnapshotIndexIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetsSnapshotIndex.t),
      orderByList: orderByList?.call(SheetsSnapshotIndex.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsSnapshotIndexImpl extends SheetsSnapshotIndex {
  _SheetsSnapshotIndexImpl({
    int? id,
    required int itemVersionId,
    required String sheetsJson,
    required String changedRangesJson,
    required List<int> authorIds,
    _is.UuidValue? diffFileId,
  }) : super._(
         id: id,
         itemVersionId: itemVersionId,
         sheetsJson: sheetsJson,
         changedRangesJson: changedRangesJson,
         authorIds: authorIds,
         diffFileId: diffFileId,
       );

  /// Returns a shallow copy of this [SheetsSnapshotIndex]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SheetsSnapshotIndex copyWith({
    Object? id = _Undefined,
    int? itemVersionId,
    String? sheetsJson,
    String? changedRangesJson,
    List<int>? authorIds,
    _is.UuidValue? diffFileId = const _is.$UndefinedUuidValue(),
  }) {
    return SheetsSnapshotIndex(
      id: id is int? ? id : this.id,
      itemVersionId: itemVersionId ?? this.itemVersionId,
      sheetsJson: sheetsJson ?? this.sheetsJson,
      changedRangesJson: changedRangesJson ?? this.changedRangesJson,
      authorIds: authorIds ?? this.authorIds.map((e0) => e0).toList(),
      diffFileId: diffFileId is _is.UndefinedSentinel
          ? this.diffFileId
          : diffFileId,
    );
  }
}

class SheetsSnapshotIndexUpdateTable
    extends _is.UpdateTable<SheetsSnapshotIndexTable> {
  SheetsSnapshotIndexUpdateTable(super.table);

  _is.ColumnValue<int, int> itemVersionId(int value) => _is.ColumnValue(
    table.itemVersionId,
    value,
  );

  _is.ColumnValue<String, String> sheetsJson(String value) => _is.ColumnValue(
    table.sheetsJson,
    value,
  );

  _is.ColumnValue<String, String> changedRangesJson(String value) =>
      _is.ColumnValue(
        table.changedRangesJson,
        value,
      );

  _is.ColumnValue<List<int>, List<int>> authorIds(List<int> value) =>
      _is.ColumnValue(
        table.authorIds,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> diffFileId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.diffFileId,
    value,
  );
}

class SheetsSnapshotIndexTable extends _is.Table<int?> {
  SheetsSnapshotIndexTable({super.tableRelation})
    : super(tableName: 'sheets_snapshot_index') {
    updateTable = SheetsSnapshotIndexUpdateTable(this);
    itemVersionId = _is.ColumnInt(
      'itemVersionId',
      this,
    );
    sheetsJson = _is.ColumnString(
      'sheetsJson',
      this,
    );
    changedRangesJson = _is.ColumnString(
      'changedRangesJson',
      this,
    );
    authorIds = _is.ColumnSerializable<List<int>>(
      'authorIds',
      this,
    );
    diffFileId = _is.ColumnUuid(
      'diffFileId',
      this,
    );
  }

  late final SheetsSnapshotIndexUpdateTable updateTable;

  late final _is.ColumnInt itemVersionId;

  late final _is.ColumnString sheetsJson;

  late final _is.ColumnString changedRangesJson;

  late final _is.ColumnSerializable<List<int>> authorIds;

  late final _is.ColumnUuid diffFileId;

  @override
  List<_is.Column> get columns => [
    id,
    itemVersionId,
    sheetsJson,
    changedRangesJson,
    authorIds,
    diffFileId,
  ];
}

class SheetsSnapshotIndexInclude extends _is.IncludeObject {
  SheetsSnapshotIndexInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SheetsSnapshotIndex.t;
}

class SheetsSnapshotIndexIncludeList extends _is.IncludeList {
  SheetsSnapshotIndexIncludeList._({
    _is.WhereExpressionBuilder<SheetsSnapshotIndexTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SheetsSnapshotIndex.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SheetsSnapshotIndex.t;
}

class SheetsSnapshotIndexRepository {
  const SheetsSnapshotIndexRepository._();

  /// Returns a list of [SheetsSnapshotIndex]s matching the given query parameters.
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
  Future<List<SheetsSnapshotIndex>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SheetsSnapshotIndexTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SheetsSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SheetsSnapshotIndexTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SheetsSnapshotIndex>(
      where: where?.call(SheetsSnapshotIndex.t),
      orderBy: orderBy?.call(SheetsSnapshotIndex.t),
      orderByList: orderByList?.call(SheetsSnapshotIndex.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SheetsSnapshotIndex]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SheetsSnapshotIndex.t`.
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
  _ida.Stream<List<SheetsSnapshotIndex>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SheetsSnapshotIndexTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SheetsSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SheetsSnapshotIndexTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SheetsSnapshotIndex>(
      where: where?.call(SheetsSnapshotIndex.t),
      orderBy: orderBy?.call(SheetsSnapshotIndex.t),
      orderByList: orderByList?.call(SheetsSnapshotIndex.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SheetsSnapshotIndex] matching the given query parameters.
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
  Future<SheetsSnapshotIndex?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SheetsSnapshotIndexTable>? where,
    int? offset,
    _is.OrderByBuilder<SheetsSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SheetsSnapshotIndexTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SheetsSnapshotIndex>(
      where: where?.call(SheetsSnapshotIndex.t),
      orderBy: orderBy?.call(SheetsSnapshotIndex.t),
      orderByList: orderByList?.call(SheetsSnapshotIndex.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SheetsSnapshotIndex] by its [id] or null if no such row exists.
  Future<SheetsSnapshotIndex?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SheetsSnapshotIndex>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SheetsSnapshotIndex]s in the list and returns the inserted rows.
  ///
  /// The returned [SheetsSnapshotIndex]s will have their `id` fields set.
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
  Future<List<SheetsSnapshotIndex>> insert(
    _is.DatabaseSession session,
    List<SheetsSnapshotIndex> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SheetsSnapshotIndex>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SheetsSnapshotIndex] and returns the inserted row.
  ///
  /// The returned [SheetsSnapshotIndex] will have its `id` field set.
  Future<SheetsSnapshotIndex> insertRow(
    _is.DatabaseSession session,
    SheetsSnapshotIndex row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SheetsSnapshotIndex>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SheetsSnapshotIndex]s in the list and returns the resulting rows.
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
  /// The returned [SheetsSnapshotIndex]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsSnapshotIndex>> upsert(
    _is.DatabaseSession session,
    List<SheetsSnapshotIndex> rows, {
    required _is.ColumnSelections<SheetsSnapshotIndexTable> conflictColumns,
    _is.ColumnSelections<SheetsSnapshotIndexTable>? updateColumns,
    _is.WhereExpressionBuilder<SheetsSnapshotIndexTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SheetsSnapshotIndex>(
      rows,
      conflictColumns: conflictColumns(SheetsSnapshotIndex.t),
      updateColumns: updateColumns?.call(SheetsSnapshotIndex.t),
      updateWhere: updateWhere?.call(SheetsSnapshotIndex.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SheetsSnapshotIndex] and returns the resulting row.
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
  /// The returned [SheetsSnapshotIndex] will have its `id` field set.
  Future<SheetsSnapshotIndex?> upsertRow(
    _is.DatabaseSession session,
    SheetsSnapshotIndex row, {
    required _is.ColumnSelections<SheetsSnapshotIndexTable> conflictColumns,
    _is.ColumnSelections<SheetsSnapshotIndexTable>? updateColumns,
    _is.WhereExpressionBuilder<SheetsSnapshotIndexTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SheetsSnapshotIndex>(
      row,
      conflictColumns: conflictColumns(SheetsSnapshotIndex.t),
      updateColumns: updateColumns?.call(SheetsSnapshotIndex.t),
      updateWhere: updateWhere?.call(SheetsSnapshotIndex.t),
      transaction: transaction,
    );
  }

  /// Updates all [SheetsSnapshotIndex]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsSnapshotIndex>> update(
    _is.DatabaseSession session,
    List<SheetsSnapshotIndex> rows, {
    _is.ColumnSelections<SheetsSnapshotIndexTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SheetsSnapshotIndex>(
      rows,
      columns: columns?.call(SheetsSnapshotIndex.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SheetsSnapshotIndex]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SheetsSnapshotIndex> updateRow(
    _is.DatabaseSession session,
    SheetsSnapshotIndex row, {
    _is.ColumnSelections<SheetsSnapshotIndexTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SheetsSnapshotIndex>(
      row,
      columns: columns?.call(SheetsSnapshotIndex.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SheetsSnapshotIndex] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SheetsSnapshotIndex?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SheetsSnapshotIndexUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SheetsSnapshotIndex>(
      id,
      columnValues: columnValues(SheetsSnapshotIndex.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SheetsSnapshotIndex]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsSnapshotIndex>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SheetsSnapshotIndexUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<SheetsSnapshotIndexTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SheetsSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SheetsSnapshotIndexTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SheetsSnapshotIndex>(
      columnValues: columnValues(SheetsSnapshotIndex.t.updateTable),
      where: where(SheetsSnapshotIndex.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetsSnapshotIndex.t),
      orderByList: orderByList?.call(SheetsSnapshotIndex.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SheetsSnapshotIndex]s in the list and returns the deleted rows.
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
  Future<List<SheetsSnapshotIndex>> delete(
    _is.DatabaseSession session,
    List<SheetsSnapshotIndex> rows, {
    _is.OrderByBuilder<SheetsSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SheetsSnapshotIndexTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SheetsSnapshotIndex>(
      rows,
      orderBy: orderBy?.call(SheetsSnapshotIndex.t),
      orderByList: orderByList?.call(SheetsSnapshotIndex.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SheetsSnapshotIndex].
  Future<SheetsSnapshotIndex> deleteRow(
    _is.DatabaseSession session,
    SheetsSnapshotIndex row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SheetsSnapshotIndex>(
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
  Future<List<SheetsSnapshotIndex>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SheetsSnapshotIndexTable> where,
    _is.OrderByBuilder<SheetsSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SheetsSnapshotIndexTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SheetsSnapshotIndex>(
      where: where(SheetsSnapshotIndex.t),
      orderBy: orderBy?.call(SheetsSnapshotIndex.t),
      orderByList: orderByList?.call(SheetsSnapshotIndex.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SheetsSnapshotIndexTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SheetsSnapshotIndex>(
      where: where?.call(SheetsSnapshotIndex.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SheetsSnapshotIndex] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SheetsSnapshotIndexTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SheetsSnapshotIndex>(
      where: where(SheetsSnapshotIndex.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
