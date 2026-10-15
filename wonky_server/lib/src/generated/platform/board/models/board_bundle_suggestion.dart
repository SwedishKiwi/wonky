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
import '../../../platform/board/models/board_area.dart' as _iknrpzcb;

/// An AI-suggested group of small posts (specs/16 §9.3).
abstract class BoardBundleSuggestion
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  BoardBundleSuggestion._({
    this.id,
    required this.title,
    required this.rationale,
    this.area,
    required this.postIds,
    required this.state,
    required this.createdAt,
  });

  factory BoardBundleSuggestion({
    int? id,
    required String title,
    required String rationale,
    _iknrpzcb.BoardArea? area,
    required List<int> postIds,
    required String state,
    required DateTime createdAt,
  }) = _BoardBundleSuggestionImpl;

  factory BoardBundleSuggestion.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return BoardBundleSuggestion(
      id: jsonSerialization['id'] as int?,
      title: jsonSerialization['title'] as String,
      rationale: jsonSerialization['rationale'] as String,
      area: jsonSerialization['area'] == null
          ? null
          : _iknrpzcb.BoardArea.fromJson((jsonSerialization['area'] as String)),
      postIds: _il4umwa0.Protocol().deserialize<List<int>>(
        jsonSerialization['postIds'],
      ),
      state: jsonSerialization['state'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = BoardBundleSuggestionTable();

  static const db = BoardBundleSuggestionRepository._();

  @override
  int? id;

  String title;

  String rationale;

  _iknrpzcb.BoardArea? area;

  List<int> postIds;

  /// pending | accepted | dismissed
  String state;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [BoardBundleSuggestion]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardBundleSuggestion copyWith({
    int? id,
    String? title,
    String? rationale,
    _iknrpzcb.BoardArea? area,
    List<int>? postIds,
    String? state,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardBundleSuggestion',
      if (id != null) 'id': id,
      'title': title,
      'rationale': rationale,
      if (area != null) 'area': area?.toJson(),
      'postIds': postIds.toJson(),
      'state': state,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardBundleSuggestion',
      if (id != null) 'id': id,
      'title': title,
      'rationale': rationale,
      if (area != null) 'area': area?.toJson(),
      'postIds': postIds.toJson(),
      'state': state,
      'createdAt': createdAt.toJson(),
    };
  }

  static BoardBundleSuggestionInclude include() {
    return BoardBundleSuggestionInclude._();
  }

  static BoardBundleSuggestionIncludeList includeList({
    _is.WhereExpressionBuilder<BoardBundleSuggestionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardBundleSuggestionTable>? orderBy,
    _is.OrderByListBuilder<BoardBundleSuggestionTable>? orderByList,
    BoardBundleSuggestionInclude? include,
  }) {
    return BoardBundleSuggestionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardBundleSuggestion.t),
      orderByList: orderByList?.call(BoardBundleSuggestion.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardBundleSuggestionImpl extends BoardBundleSuggestion {
  _BoardBundleSuggestionImpl({
    int? id,
    required String title,
    required String rationale,
    _iknrpzcb.BoardArea? area,
    required List<int> postIds,
    required String state,
    required DateTime createdAt,
  }) : super._(
         id: id,
         title: title,
         rationale: rationale,
         area: area,
         postIds: postIds,
         state: state,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [BoardBundleSuggestion]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardBundleSuggestion copyWith({
    Object? id = _Undefined,
    String? title,
    String? rationale,
    Object? area = _Undefined,
    List<int>? postIds,
    String? state,
    DateTime? createdAt,
  }) {
    return BoardBundleSuggestion(
      id: id is int? ? id : this.id,
      title: title ?? this.title,
      rationale: rationale ?? this.rationale,
      area: area is _iknrpzcb.BoardArea? ? area : this.area,
      postIds: postIds ?? this.postIds.map((e0) => e0).toList(),
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class BoardBundleSuggestionUpdateTable
    extends _is.UpdateTable<BoardBundleSuggestionTable> {
  BoardBundleSuggestionUpdateTable(super.table);

  _is.ColumnValue<String, String> title(String value) => _is.ColumnValue(
    table.title,
    value,
  );

  _is.ColumnValue<String, String> rationale(String value) => _is.ColumnValue(
    table.rationale,
    value,
  );

  _is.ColumnValue<_iknrpzcb.BoardArea, _iknrpzcb.BoardArea> area(
    _iknrpzcb.BoardArea? value,
  ) => _is.ColumnValue(
    table.area,
    value,
  );

  _is.ColumnValue<List<int>, List<int>> postIds(List<int> value) =>
      _is.ColumnValue(
        table.postIds,
        value,
      );

  _is.ColumnValue<String, String> state(String value) => _is.ColumnValue(
    table.state,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class BoardBundleSuggestionTable extends _is.Table<int?> {
  BoardBundleSuggestionTable({super.tableRelation})
    : super(tableName: 'board_bundle_suggestion') {
    updateTable = BoardBundleSuggestionUpdateTable(this);
    title = _is.ColumnString(
      'title',
      this,
    );
    rationale = _is.ColumnString(
      'rationale',
      this,
    );
    area = _is.ColumnEnum(
      'area',
      this,
      _is.EnumSerialization.byName,
    );
    postIds = _is.ColumnSerializable<List<int>>(
      'postIds',
      this,
    );
    state = _is.ColumnString(
      'state',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final BoardBundleSuggestionUpdateTable updateTable;

  late final _is.ColumnString title;

  late final _is.ColumnString rationale;

  late final _is.ColumnEnum<_iknrpzcb.BoardArea> area;

  late final _is.ColumnSerializable<List<int>> postIds;

  /// pending | accepted | dismissed
  late final _is.ColumnString state;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    title,
    rationale,
    area,
    postIds,
    state,
    createdAt,
  ];
}

class BoardBundleSuggestionInclude extends _is.IncludeObject {
  BoardBundleSuggestionInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => BoardBundleSuggestion.t;
}

class BoardBundleSuggestionIncludeList extends _is.IncludeList {
  BoardBundleSuggestionIncludeList._({
    _is.WhereExpressionBuilder<BoardBundleSuggestionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BoardBundleSuggestion.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => BoardBundleSuggestion.t;
}

class BoardBundleSuggestionRepository {
  const BoardBundleSuggestionRepository._();

  /// Returns a list of [BoardBundleSuggestion]s matching the given query parameters.
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
  Future<List<BoardBundleSuggestion>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardBundleSuggestionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardBundleSuggestionTable>? orderBy,
    _is.OrderByListBuilder<BoardBundleSuggestionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BoardBundleSuggestion>(
      where: where?.call(BoardBundleSuggestion.t),
      orderBy: orderBy?.call(BoardBundleSuggestion.t),
      orderByList: orderByList?.call(BoardBundleSuggestion.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [BoardBundleSuggestion]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `BoardBundleSuggestion.t`.
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
  _ida.Stream<List<BoardBundleSuggestion>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardBundleSuggestionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardBundleSuggestionTable>? orderBy,
    _is.OrderByListBuilder<BoardBundleSuggestionTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<BoardBundleSuggestion>(
      where: where?.call(BoardBundleSuggestion.t),
      orderBy: orderBy?.call(BoardBundleSuggestion.t),
      orderByList: orderByList?.call(BoardBundleSuggestion.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [BoardBundleSuggestion] matching the given query parameters.
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
  Future<BoardBundleSuggestion?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardBundleSuggestionTable>? where,
    int? offset,
    _is.OrderByBuilder<BoardBundleSuggestionTable>? orderBy,
    _is.OrderByListBuilder<BoardBundleSuggestionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BoardBundleSuggestion>(
      where: where?.call(BoardBundleSuggestion.t),
      orderBy: orderBy?.call(BoardBundleSuggestion.t),
      orderByList: orderByList?.call(BoardBundleSuggestion.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BoardBundleSuggestion] by its [id] or null if no such row exists.
  Future<BoardBundleSuggestion?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BoardBundleSuggestion>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BoardBundleSuggestion]s in the list and returns the inserted rows.
  ///
  /// The returned [BoardBundleSuggestion]s will have their `id` fields set.
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
  Future<List<BoardBundleSuggestion>> insert(
    _is.DatabaseSession session,
    List<BoardBundleSuggestion> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BoardBundleSuggestion>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BoardBundleSuggestion] and returns the inserted row.
  ///
  /// The returned [BoardBundleSuggestion] will have its `id` field set.
  Future<BoardBundleSuggestion> insertRow(
    _is.DatabaseSession session,
    BoardBundleSuggestion row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BoardBundleSuggestion>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BoardBundleSuggestion]s in the list and returns the resulting rows.
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
  /// The returned [BoardBundleSuggestion]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardBundleSuggestion>> upsert(
    _is.DatabaseSession session,
    List<BoardBundleSuggestion> rows, {
    required _is.ColumnSelections<BoardBundleSuggestionTable> conflictColumns,
    _is.ColumnSelections<BoardBundleSuggestionTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardBundleSuggestionTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BoardBundleSuggestion>(
      rows,
      conflictColumns: conflictColumns(BoardBundleSuggestion.t),
      updateColumns: updateColumns?.call(BoardBundleSuggestion.t),
      updateWhere: updateWhere?.call(BoardBundleSuggestion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BoardBundleSuggestion] and returns the resulting row.
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
  /// The returned [BoardBundleSuggestion] will have its `id` field set.
  Future<BoardBundleSuggestion?> upsertRow(
    _is.DatabaseSession session,
    BoardBundleSuggestion row, {
    required _is.ColumnSelections<BoardBundleSuggestionTable> conflictColumns,
    _is.ColumnSelections<BoardBundleSuggestionTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardBundleSuggestionTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BoardBundleSuggestion>(
      row,
      conflictColumns: conflictColumns(BoardBundleSuggestion.t),
      updateColumns: updateColumns?.call(BoardBundleSuggestion.t),
      updateWhere: updateWhere?.call(BoardBundleSuggestion.t),
      transaction: transaction,
    );
  }

  /// Updates all [BoardBundleSuggestion]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardBundleSuggestion>> update(
    _is.DatabaseSession session,
    List<BoardBundleSuggestion> rows, {
    _is.ColumnSelections<BoardBundleSuggestionTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BoardBundleSuggestion>(
      rows,
      columns: columns?.call(BoardBundleSuggestion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BoardBundleSuggestion]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BoardBundleSuggestion> updateRow(
    _is.DatabaseSession session,
    BoardBundleSuggestion row, {
    _is.ColumnSelections<BoardBundleSuggestionTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BoardBundleSuggestion>(
      row,
      columns: columns?.call(BoardBundleSuggestion.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BoardBundleSuggestion] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BoardBundleSuggestion?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BoardBundleSuggestionUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BoardBundleSuggestion>(
      id,
      columnValues: columnValues(BoardBundleSuggestion.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BoardBundleSuggestion]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardBundleSuggestion>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BoardBundleSuggestionUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<BoardBundleSuggestionTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardBundleSuggestionTable>? orderBy,
    _is.OrderByListBuilder<BoardBundleSuggestionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BoardBundleSuggestion>(
      columnValues: columnValues(BoardBundleSuggestion.t.updateTable),
      where: where(BoardBundleSuggestion.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardBundleSuggestion.t),
      orderByList: orderByList?.call(BoardBundleSuggestion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BoardBundleSuggestion]s in the list and returns the deleted rows.
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
  Future<List<BoardBundleSuggestion>> delete(
    _is.DatabaseSession session,
    List<BoardBundleSuggestion> rows, {
    _is.OrderByBuilder<BoardBundleSuggestionTable>? orderBy,
    _is.OrderByListBuilder<BoardBundleSuggestionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BoardBundleSuggestion>(
      rows,
      orderBy: orderBy?.call(BoardBundleSuggestion.t),
      orderByList: orderByList?.call(BoardBundleSuggestion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BoardBundleSuggestion].
  Future<BoardBundleSuggestion> deleteRow(
    _is.DatabaseSession session,
    BoardBundleSuggestion row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BoardBundleSuggestion>(
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
  Future<List<BoardBundleSuggestion>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardBundleSuggestionTable> where,
    _is.OrderByBuilder<BoardBundleSuggestionTable>? orderBy,
    _is.OrderByListBuilder<BoardBundleSuggestionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BoardBundleSuggestion>(
      where: where(BoardBundleSuggestion.t),
      orderBy: orderBy?.call(BoardBundleSuggestion.t),
      orderByList: orderByList?.call(BoardBundleSuggestion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardBundleSuggestionTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BoardBundleSuggestion>(
      where: where?.call(BoardBundleSuggestion.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BoardBundleSuggestion] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardBundleSuggestionTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BoardBundleSuggestion>(
      where: where(BoardBundleSuggestion.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
