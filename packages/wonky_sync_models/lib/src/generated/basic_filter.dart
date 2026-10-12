/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_null_comparison

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;
import 'package:wonky_sync_models/wonky_sync_models.dart' as _i810rwvy;

/// The basic filter of a sheet; id = SheetsIds.basicFilterId(sheetId).
abstract class BasicFilter
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  BasicFilter._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.sheetId,
    this.sheet,
    required this.rangeJson,
    required this.criteriaJson,
    this.sortJson,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory BasicFilter({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String rangeJson,
    required String criteriaJson,
    String? sortJson,
    DateTime? createdAt,
  }) = _BasicFilterImpl;

  factory BasicFilter.fromJson(Map<String, dynamic> jsonSerialization) {
    return BasicFilter(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      sheetId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['sheetId'],
      ),
      sheet: jsonSerialization['sheet'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.Sheet>(
              jsonSerialization['sheet'],
            ),
      rangeJson: jsonSerialization['rangeJson'] as String,
      criteriaJson: jsonSerialization['criteriaJson'] as String,
      sortJson: jsonSerialization['sortJson'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = BasicFilterTable();

  static const db = BasicFilterRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue sheetId;

  _i810rwvy.Sheet? sheet;

  String rangeJson;

  /// {colId: criteria}.
  String criteriaJson;

  /// [{colId, ascending}].
  String? sortJson;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [BasicFilter]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  BasicFilter copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedBasicFilter$sheet(),
    String? rangeJson,
    String? criteriaJson,
    String? sortJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BasicFilter',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJson(),
      'rangeJson': rangeJson,
      'criteriaJson': criteriaJson,
      if (sortJson != null) 'sortJson': sortJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BasicFilter',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJsonForProtocol(),
      'rangeJson': rangeJson,
      'criteriaJson': criteriaJson,
      if (sortJson != null) 'sortJson': sortJson,
      'createdAt': createdAt.toJson(),
    };
  }

  static BasicFilterInclude include({_i810rwvy.SheetInclude? sheet}) {
    return BasicFilterInclude._(sheet: sheet);
  }

  static BasicFilterIncludeList includeList({
    _isd.WhereExpressionBuilder<BasicFilterTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<BasicFilterTable>? orderBy,
    _isd.OrderByListBuilder<BasicFilterTable>? orderByList,
    BasicFilterInclude? include,
  }) {
    return BasicFilterIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BasicFilter.t),
      orderByList: orderByList?.call(BasicFilter.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedBasicFilter$sheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Sheet {
  const _UndefinedBasicFilter$sheet();
}

class _BasicFilterImpl extends BasicFilter {
  _BasicFilterImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String rangeJson,
    required String criteriaJson,
    String? sortJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         sheetId: sheetId,
         sheet: sheet,
         rangeJson: rangeJson,
         criteriaJson: criteriaJson,
         sortJson: sortJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [BasicFilter]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  BasicFilter copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedBasicFilter$sheet(),
    String? rangeJson,
    String? criteriaJson,
    Object? sortJson = _Undefined,
    DateTime? createdAt,
  }) {
    return BasicFilter(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      sheetId: sheetId ?? this.sheetId,
      sheet: sheet is _iss.UndefinedSentinel ? this.sheet?.copyWith() : sheet,
      rangeJson: rangeJson ?? this.rangeJson,
      criteriaJson: criteriaJson ?? this.criteriaJson,
      sortJson: sortJson is String? ? sortJson : this.sortJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class BasicFilterUpdateTable extends _isd.UpdateTable<BasicFilterTable> {
  BasicFilterUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> sheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<String, String> rangeJson(String value) =>
      _isd.ColumnValue(table.rangeJson, value);

  _isd.ColumnValue<String, String> criteriaJson(String value) =>
      _isd.ColumnValue(table.criteriaJson, value);

  _isd.ColumnValue<String, String> sortJson(String? value) =>
      _isd.ColumnValue(table.sortJson, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class BasicFilterTable extends _isd.Table<_iss.UuidValue> {
  BasicFilterTable({super.tableRelation}) : super(tableName: 'basic_filter') {
    updateTable = BasicFilterUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    sheetId = _isd.ColumnUuid('sheetId', this);
    rangeJson = _isd.ColumnString('rangeJson', this);
    criteriaJson = _isd.ColumnString('criteriaJson', this);
    sortJson = _isd.ColumnString('sortJson', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final BasicFilterUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid sheetId;

  _i810rwvy.SheetTable? _sheet;

  late final _isd.ColumnString rangeJson;

  /// {colId: criteria}.
  late final _isd.ColumnString criteriaJson;

  /// [{colId, ascending}].
  late final _isd.ColumnString sortJson;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SheetTable get sheet {
    if (_sheet != null) return _sheet!;
    _sheet = _isd.createRelationTable(
      relationFieldName: 'sheet',
      field: BasicFilter.t.sheetId,
      foreignField: _i810rwvy.Sheet.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SheetTable(tableRelation: foreignTableRelation),
    );
    return _sheet!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    sheetId,
    rangeJson,
    criteriaJson,
    sortJson,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'sheet') {
      return sheet;
    }
    return null;
  }
}

class BasicFilterInclude extends _isd.IncludeObject {
  BasicFilterInclude._({_i810rwvy.SheetInclude? sheet}) {
    _sheet = sheet;
  }

  _i810rwvy.SheetInclude? _sheet;

  @override
  Map<String, _isd.Include?> get includes => {'sheet': _sheet};

  @override
  _isd.Table<_iss.UuidValue> get table => BasicFilter.t;
}

class BasicFilterIncludeList extends _isd.IncludeList {
  BasicFilterIncludeList._({
    _isd.WhereExpressionBuilder<BasicFilterTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BasicFilter.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => BasicFilter.t;
}

class BasicFilterRepository {
  const BasicFilterRepository._();

  final attachRow = const BasicFilterAttachRowRepository._();

  /// Returns a list of [BasicFilter]s matching the given query parameters.
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
  Future<List<BasicFilter>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<BasicFilterTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<BasicFilterTable>? orderBy,
    _isd.OrderByListBuilder<BasicFilterTable>? orderByList,
    _isd.Transaction? transaction,
    BasicFilterInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BasicFilter>(
      where: where?.call(BasicFilter.t),
      orderBy: orderBy?.call(BasicFilter.t),
      orderByList: orderByList?.call(BasicFilter.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [BasicFilter]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `BasicFilter.t`.
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
  _ida.Stream<List<BasicFilter>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<BasicFilterTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<BasicFilterTable>? orderBy,
    _isd.OrderByListBuilder<BasicFilterTable>? orderByList,
    BasicFilterInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<BasicFilter>(
      where: where?.call(BasicFilter.t),
      orderBy: orderBy?.call(BasicFilter.t),
      orderByList: orderByList?.call(BasicFilter.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [BasicFilter] matching the given query parameters.
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
  Future<BasicFilter?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<BasicFilterTable>? where,
    int? offset,
    _isd.OrderByBuilder<BasicFilterTable>? orderBy,
    _isd.OrderByListBuilder<BasicFilterTable>? orderByList,
    _isd.Transaction? transaction,
    BasicFilterInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BasicFilter>(
      where: where?.call(BasicFilter.t),
      orderBy: orderBy?.call(BasicFilter.t),
      orderByList: orderByList?.call(BasicFilter.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BasicFilter] by its [id] or null if no such row exists.
  Future<BasicFilter?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    BasicFilterInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BasicFilter>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BasicFilter]s in the list and returns the inserted rows.
  ///
  /// The returned [BasicFilter]s will have their `id` fields set.
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
  Future<List<BasicFilter>> insert(
    _isd.DatabaseSession session,
    List<BasicFilter> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BasicFilter>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BasicFilter] and returns the inserted row.
  ///
  /// The returned [BasicFilter] will have its `id` field set.
  Future<BasicFilter> insertRow(
    _isd.DatabaseSession session,
    BasicFilter row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<BasicFilter>(row, transaction: transaction);
  }

  /// Upserts all [BasicFilter]s in the list and returns the resulting rows.
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
  /// The returned [BasicFilter]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BasicFilter>> upsert(
    _isd.DatabaseSession session,
    List<BasicFilter> rows, {
    required _isd.ColumnSelections<BasicFilterTable> conflictColumns,
    _isd.ColumnSelections<BasicFilterTable>? updateColumns,
    _isd.WhereExpressionBuilder<BasicFilterTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BasicFilter>(
      rows,
      conflictColumns: conflictColumns(BasicFilter.t),
      updateColumns: updateColumns?.call(BasicFilter.t),
      updateWhere: updateWhere?.call(BasicFilter.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BasicFilter] and returns the resulting row.
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
  /// The returned [BasicFilter] will have its `id` field set.
  Future<BasicFilter?> upsertRow(
    _isd.DatabaseSession session,
    BasicFilter row, {
    required _isd.ColumnSelections<BasicFilterTable> conflictColumns,
    _isd.ColumnSelections<BasicFilterTable>? updateColumns,
    _isd.WhereExpressionBuilder<BasicFilterTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BasicFilter>(
      row,
      conflictColumns: conflictColumns(BasicFilter.t),
      updateColumns: updateColumns?.call(BasicFilter.t),
      updateWhere: updateWhere?.call(BasicFilter.t),
      transaction: transaction,
    );
  }

  /// Updates all [BasicFilter]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BasicFilter>> update(
    _isd.DatabaseSession session,
    List<BasicFilter> rows, {
    _isd.ColumnSelections<BasicFilterTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BasicFilter>(
      rows,
      columns: columns?.call(BasicFilter.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BasicFilter]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BasicFilter> updateRow(
    _isd.DatabaseSession session,
    BasicFilter row, {
    _isd.ColumnSelections<BasicFilterTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<BasicFilter>(
      row,
      columns: columns?.call(BasicFilter.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BasicFilter] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BasicFilter?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<BasicFilterUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<BasicFilter>(
      id,
      columnValues: columnValues(BasicFilter.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BasicFilter]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BasicFilter>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<BasicFilterUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<BasicFilterTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<BasicFilterTable>? orderBy,
    _isd.OrderByListBuilder<BasicFilterTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BasicFilter>(
      columnValues: columnValues(BasicFilter.t.updateTable),
      where: where(BasicFilter.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BasicFilter.t),
      orderByList: orderByList?.call(BasicFilter.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BasicFilter]s in the list and returns the deleted rows.
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
  Future<List<BasicFilter>> delete(
    _isd.DatabaseSession session,
    List<BasicFilter> rows, {
    _isd.OrderByBuilder<BasicFilterTable>? orderBy,
    _isd.OrderByListBuilder<BasicFilterTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BasicFilter>(
      rows,
      orderBy: orderBy?.call(BasicFilter.t),
      orderByList: orderByList?.call(BasicFilter.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BasicFilter].
  Future<BasicFilter> deleteRow(
    _isd.DatabaseSession session,
    BasicFilter row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BasicFilter>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BasicFilter>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<BasicFilterTable> where,
    _isd.OrderByBuilder<BasicFilterTable>? orderBy,
    _isd.OrderByListBuilder<BasicFilterTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BasicFilter>(
      where: where(BasicFilter.t),
      orderBy: orderBy?.call(BasicFilter.t),
      orderByList: orderByList?.call(BasicFilter.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<BasicFilterTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<BasicFilter>(
      where: where?.call(BasicFilter.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BasicFilter] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<BasicFilterTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BasicFilter>(
      where: where(BasicFilter.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class BasicFilterAttachRowRepository {
  const BasicFilterAttachRowRepository._();

  /// Creates a relation between the given [BasicFilter] and [Sheet]
  /// by setting the [BasicFilter]'s foreign key `sheetId` to refer to the [Sheet].
  Future<void> sheet(
    _isd.DatabaseSession session,
    BasicFilter basicFilter,
    _i810rwvy.Sheet sheet, {
    _isd.Transaction? transaction,
  }) async {
    if (basicFilter.id == null) {
      throw ArgumentError.notNull('basicFilter.id');
    }
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }

    var $basicFilter = basicFilter.copyWith(sheetId: sheet.id);
    await session.db.updateRow<BasicFilter>(
      $basicFilter,
      columns: [BasicFilter.t.sheetId],
      transaction: transaction,
    );
  }
}
