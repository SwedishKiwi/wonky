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

/// Per Slides version (Slides 09 §4.1, A-09-4): the slide list of the
/// snapshot and who changed what since the previous capture, built from the
/// DeckChangeLog rows consumed in the window (survives change-log pruning).
abstract class SlidesSnapshotIndex
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SlidesSnapshotIndex._({
    this.id,
    required this.itemVersionId,
    required this.slidesJson,
    required this.changesJson,
    required this.authorIds,
  });

  factory SlidesSnapshotIndex({
    int? id,
    required int itemVersionId,
    required String slidesJson,
    required String changesJson,
    required List<int> authorIds,
  }) = _SlidesSnapshotIndexImpl;

  factory SlidesSnapshotIndex.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlidesSnapshotIndex(
      id: jsonSerialization['id'] as int?,
      itemVersionId: jsonSerialization['itemVersionId'] as int,
      slidesJson: jsonSerialization['slidesJson'] as String,
      changesJson: jsonSerialization['changesJson'] as String,
      authorIds: _il4umwa0.Protocol().deserialize<List<int>>(
        jsonSerialization['authorIds'],
      ),
    );
  }

  static final t = SlidesSnapshotIndexTable();

  static const db = SlidesSnapshotIndexRepository._();

  @override
  int? id;

  int itemVersionId;

  /// `[{id, title, group, groupTitle, skipped}]` in presentation order.
  String slidesJson;

  /// `SlidesVersionChanges` JSON: `{v, slides: {id: [userIds]}, elements,
  /// groups, theme, deck, agents, approx}` (latest author last).
  String changesJson;

  List<int> authorIds;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SlidesSnapshotIndex]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SlidesSnapshotIndex copyWith({
    int? id,
    int? itemVersionId,
    String? slidesJson,
    String? changesJson,
    List<int>? authorIds,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlidesSnapshotIndex',
      if (id != null) 'id': id,
      'itemVersionId': itemVersionId,
      'slidesJson': slidesJson,
      'changesJson': changesJson,
      'authorIds': authorIds.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SlidesSnapshotIndexInclude include() {
    return SlidesSnapshotIndexInclude._();
  }

  static SlidesSnapshotIndexIncludeList includeList({
    _is.WhereExpressionBuilder<SlidesSnapshotIndexTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SlidesSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SlidesSnapshotIndexTable>? orderByList,
    SlidesSnapshotIndexInclude? include,
  }) {
    return SlidesSnapshotIndexIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlidesSnapshotIndex.t),
      orderByList: orderByList?.call(SlidesSnapshotIndex.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SlidesSnapshotIndexImpl extends SlidesSnapshotIndex {
  _SlidesSnapshotIndexImpl({
    int? id,
    required int itemVersionId,
    required String slidesJson,
    required String changesJson,
    required List<int> authorIds,
  }) : super._(
         id: id,
         itemVersionId: itemVersionId,
         slidesJson: slidesJson,
         changesJson: changesJson,
         authorIds: authorIds,
       );

  /// Returns a shallow copy of this [SlidesSnapshotIndex]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SlidesSnapshotIndex copyWith({
    Object? id = _Undefined,
    int? itemVersionId,
    String? slidesJson,
    String? changesJson,
    List<int>? authorIds,
  }) {
    return SlidesSnapshotIndex(
      id: id is int? ? id : this.id,
      itemVersionId: itemVersionId ?? this.itemVersionId,
      slidesJson: slidesJson ?? this.slidesJson,
      changesJson: changesJson ?? this.changesJson,
      authorIds: authorIds ?? this.authorIds.map((e0) => e0).toList(),
    );
  }
}

class SlidesSnapshotIndexUpdateTable
    extends _is.UpdateTable<SlidesSnapshotIndexTable> {
  SlidesSnapshotIndexUpdateTable(super.table);

  _is.ColumnValue<int, int> itemVersionId(int value) => _is.ColumnValue(
    table.itemVersionId,
    value,
  );

  _is.ColumnValue<String, String> slidesJson(String value) => _is.ColumnValue(
    table.slidesJson,
    value,
  );

  _is.ColumnValue<String, String> changesJson(String value) => _is.ColumnValue(
    table.changesJson,
    value,
  );

  _is.ColumnValue<List<int>, List<int>> authorIds(List<int> value) =>
      _is.ColumnValue(
        table.authorIds,
        value,
      );
}

class SlidesSnapshotIndexTable extends _is.Table<int?> {
  SlidesSnapshotIndexTable({super.tableRelation})
    : super(tableName: 'slides_snapshot_index') {
    updateTable = SlidesSnapshotIndexUpdateTable(this);
    itemVersionId = _is.ColumnInt(
      'itemVersionId',
      this,
    );
    slidesJson = _is.ColumnString(
      'slidesJson',
      this,
    );
    changesJson = _is.ColumnString(
      'changesJson',
      this,
    );
    authorIds = _is.ColumnSerializable<List<int>>(
      'authorIds',
      this,
    );
  }

  late final SlidesSnapshotIndexUpdateTable updateTable;

  late final _is.ColumnInt itemVersionId;

  /// `[{id, title, group, groupTitle, skipped}]` in presentation order.
  late final _is.ColumnString slidesJson;

  /// `SlidesVersionChanges` JSON: `{v, slides: {id: [userIds]}, elements,
  /// groups, theme, deck, agents, approx}` (latest author last).
  late final _is.ColumnString changesJson;

  late final _is.ColumnSerializable<List<int>> authorIds;

  @override
  List<_is.Column> get columns => [
    id,
    itemVersionId,
    slidesJson,
    changesJson,
    authorIds,
  ];
}

class SlidesSnapshotIndexInclude extends _is.IncludeObject {
  SlidesSnapshotIndexInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SlidesSnapshotIndex.t;
}

class SlidesSnapshotIndexIncludeList extends _is.IncludeList {
  SlidesSnapshotIndexIncludeList._({
    _is.WhereExpressionBuilder<SlidesSnapshotIndexTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SlidesSnapshotIndex.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SlidesSnapshotIndex.t;
}

class SlidesSnapshotIndexRepository {
  const SlidesSnapshotIndexRepository._();

  /// Returns a list of [SlidesSnapshotIndex]s matching the given query parameters.
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
  Future<List<SlidesSnapshotIndex>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SlidesSnapshotIndexTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SlidesSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SlidesSnapshotIndexTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SlidesSnapshotIndex>(
      where: where?.call(SlidesSnapshotIndex.t),
      orderBy: orderBy?.call(SlidesSnapshotIndex.t),
      orderByList: orderByList?.call(SlidesSnapshotIndex.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SlidesSnapshotIndex]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SlidesSnapshotIndex.t`.
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
  _ida.Stream<List<SlidesSnapshotIndex>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SlidesSnapshotIndexTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SlidesSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SlidesSnapshotIndexTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SlidesSnapshotIndex>(
      where: where?.call(SlidesSnapshotIndex.t),
      orderBy: orderBy?.call(SlidesSnapshotIndex.t),
      orderByList: orderByList?.call(SlidesSnapshotIndex.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SlidesSnapshotIndex] matching the given query parameters.
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
  Future<SlidesSnapshotIndex?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SlidesSnapshotIndexTable>? where,
    int? offset,
    _is.OrderByBuilder<SlidesSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SlidesSnapshotIndexTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SlidesSnapshotIndex>(
      where: where?.call(SlidesSnapshotIndex.t),
      orderBy: orderBy?.call(SlidesSnapshotIndex.t),
      orderByList: orderByList?.call(SlidesSnapshotIndex.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SlidesSnapshotIndex] by its [id] or null if no such row exists.
  Future<SlidesSnapshotIndex?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SlidesSnapshotIndex>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SlidesSnapshotIndex]s in the list and returns the inserted rows.
  ///
  /// The returned [SlidesSnapshotIndex]s will have their `id` fields set.
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
  Future<List<SlidesSnapshotIndex>> insert(
    _is.DatabaseSession session,
    List<SlidesSnapshotIndex> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SlidesSnapshotIndex>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SlidesSnapshotIndex] and returns the inserted row.
  ///
  /// The returned [SlidesSnapshotIndex] will have its `id` field set.
  Future<SlidesSnapshotIndex> insertRow(
    _is.DatabaseSession session,
    SlidesSnapshotIndex row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SlidesSnapshotIndex>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SlidesSnapshotIndex]s in the list and returns the resulting rows.
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
  /// The returned [SlidesSnapshotIndex]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlidesSnapshotIndex>> upsert(
    _is.DatabaseSession session,
    List<SlidesSnapshotIndex> rows, {
    required _is.ColumnSelections<SlidesSnapshotIndexTable> conflictColumns,
    _is.ColumnSelections<SlidesSnapshotIndexTable>? updateColumns,
    _is.WhereExpressionBuilder<SlidesSnapshotIndexTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SlidesSnapshotIndex>(
      rows,
      conflictColumns: conflictColumns(SlidesSnapshotIndex.t),
      updateColumns: updateColumns?.call(SlidesSnapshotIndex.t),
      updateWhere: updateWhere?.call(SlidesSnapshotIndex.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SlidesSnapshotIndex] and returns the resulting row.
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
  /// The returned [SlidesSnapshotIndex] will have its `id` field set.
  Future<SlidesSnapshotIndex?> upsertRow(
    _is.DatabaseSession session,
    SlidesSnapshotIndex row, {
    required _is.ColumnSelections<SlidesSnapshotIndexTable> conflictColumns,
    _is.ColumnSelections<SlidesSnapshotIndexTable>? updateColumns,
    _is.WhereExpressionBuilder<SlidesSnapshotIndexTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SlidesSnapshotIndex>(
      row,
      conflictColumns: conflictColumns(SlidesSnapshotIndex.t),
      updateColumns: updateColumns?.call(SlidesSnapshotIndex.t),
      updateWhere: updateWhere?.call(SlidesSnapshotIndex.t),
      transaction: transaction,
    );
  }

  /// Updates all [SlidesSnapshotIndex]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlidesSnapshotIndex>> update(
    _is.DatabaseSession session,
    List<SlidesSnapshotIndex> rows, {
    _is.ColumnSelections<SlidesSnapshotIndexTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SlidesSnapshotIndex>(
      rows,
      columns: columns?.call(SlidesSnapshotIndex.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SlidesSnapshotIndex]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SlidesSnapshotIndex> updateRow(
    _is.DatabaseSession session,
    SlidesSnapshotIndex row, {
    _is.ColumnSelections<SlidesSnapshotIndexTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SlidesSnapshotIndex>(
      row,
      columns: columns?.call(SlidesSnapshotIndex.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SlidesSnapshotIndex] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SlidesSnapshotIndex?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SlidesSnapshotIndexUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SlidesSnapshotIndex>(
      id,
      columnValues: columnValues(SlidesSnapshotIndex.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SlidesSnapshotIndex]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlidesSnapshotIndex>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SlidesSnapshotIndexUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<SlidesSnapshotIndexTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SlidesSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SlidesSnapshotIndexTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SlidesSnapshotIndex>(
      columnValues: columnValues(SlidesSnapshotIndex.t.updateTable),
      where: where(SlidesSnapshotIndex.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlidesSnapshotIndex.t),
      orderByList: orderByList?.call(SlidesSnapshotIndex.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SlidesSnapshotIndex]s in the list and returns the deleted rows.
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
  Future<List<SlidesSnapshotIndex>> delete(
    _is.DatabaseSession session,
    List<SlidesSnapshotIndex> rows, {
    _is.OrderByBuilder<SlidesSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SlidesSnapshotIndexTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SlidesSnapshotIndex>(
      rows,
      orderBy: orderBy?.call(SlidesSnapshotIndex.t),
      orderByList: orderByList?.call(SlidesSnapshotIndex.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SlidesSnapshotIndex].
  Future<SlidesSnapshotIndex> deleteRow(
    _is.DatabaseSession session,
    SlidesSnapshotIndex row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SlidesSnapshotIndex>(
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
  Future<List<SlidesSnapshotIndex>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SlidesSnapshotIndexTable> where,
    _is.OrderByBuilder<SlidesSnapshotIndexTable>? orderBy,
    _is.OrderByListBuilder<SlidesSnapshotIndexTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SlidesSnapshotIndex>(
      where: where(SlidesSnapshotIndex.t),
      orderBy: orderBy?.call(SlidesSnapshotIndex.t),
      orderByList: orderByList?.call(SlidesSnapshotIndex.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SlidesSnapshotIndexTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SlidesSnapshotIndex>(
      where: where?.call(SlidesSnapshotIndex.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SlidesSnapshotIndex] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SlidesSnapshotIndexTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SlidesSnapshotIndex>(
      where: where(SlidesSnapshotIndex.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
