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

/// A saved, named filter view.
abstract class FilterView
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  FilterView._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.sheetId,
    this.sheet,
    required this.name,
    required this.rangeJson,
    required this.criteriaJson,
    this.sortJson,
    required this.createdBy,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory FilterView({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String name,
    required String rangeJson,
    required String criteriaJson,
    String? sortJson,
    required _iss.UuidValue createdBy,
    DateTime? createdAt,
  }) = _FilterViewImpl;

  factory FilterView.fromJson(Map<String, dynamic> jsonSerialization) {
    return FilterView(
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
      name: jsonSerialization['name'] as String,
      rangeJson: jsonSerialization['rangeJson'] as String,
      criteriaJson: jsonSerialization['criteriaJson'] as String,
      sortJson: jsonSerialization['sortJson'] as String?,
      createdBy: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['createdBy'],
      ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = FilterViewTable();

  static const db = FilterViewRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue sheetId;

  _i810rwvy.Sheet? sheet;

  String name;

  String rangeJson;

  String criteriaJson;

  String? sortJson;

  _iss.UuidValue createdBy;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [FilterView]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  FilterView copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedFilterView$sheet(),
    String? name,
    String? rangeJson,
    String? criteriaJson,
    String? sortJson,
    _iss.UuidValue? createdBy,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FilterView',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJson(),
      'name': name,
      'rangeJson': rangeJson,
      'criteriaJson': criteriaJson,
      if (sortJson != null) 'sortJson': sortJson,
      'createdBy': createdBy.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FilterView',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJsonForProtocol(),
      'name': name,
      'rangeJson': rangeJson,
      'criteriaJson': criteriaJson,
      if (sortJson != null) 'sortJson': sortJson,
      'createdBy': createdBy.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static FilterViewInclude include({_i810rwvy.SheetInclude? sheet}) {
    return FilterViewInclude._(sheet: sheet);
  }

  static FilterViewIncludeList includeList({
    _isd.WhereExpressionBuilder<FilterViewTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FilterViewTable>? orderBy,
    _isd.OrderByListBuilder<FilterViewTable>? orderByList,
    FilterViewInclude? include,
  }) {
    return FilterViewIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FilterView.t),
      orderByList: orderByList?.call(FilterView.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedFilterView$sheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Sheet {
  const _UndefinedFilterView$sheet();
}

class _FilterViewImpl extends FilterView {
  _FilterViewImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String name,
    required String rangeJson,
    required String criteriaJson,
    String? sortJson,
    required _iss.UuidValue createdBy,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         sheetId: sheetId,
         sheet: sheet,
         name: name,
         rangeJson: rangeJson,
         criteriaJson: criteriaJson,
         sortJson: sortJson,
         createdBy: createdBy,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [FilterView]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  FilterView copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedFilterView$sheet(),
    String? name,
    String? rangeJson,
    String? criteriaJson,
    Object? sortJson = _Undefined,
    _iss.UuidValue? createdBy,
    DateTime? createdAt,
  }) {
    return FilterView(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      sheetId: sheetId ?? this.sheetId,
      sheet: sheet is _iss.UndefinedSentinel ? this.sheet?.copyWith() : sheet,
      name: name ?? this.name,
      rangeJson: rangeJson ?? this.rangeJson,
      criteriaJson: criteriaJson ?? this.criteriaJson,
      sortJson: sortJson is String? ? sortJson : this.sortJson,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class FilterViewUpdateTable extends _isd.UpdateTable<FilterViewTable> {
  FilterViewUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> sheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<String, String> name(String value) =>
      _isd.ColumnValue(table.name, value);

  _isd.ColumnValue<String, String> rangeJson(String value) =>
      _isd.ColumnValue(table.rangeJson, value);

  _isd.ColumnValue<String, String> criteriaJson(String value) =>
      _isd.ColumnValue(table.criteriaJson, value);

  _isd.ColumnValue<String, String> sortJson(String? value) =>
      _isd.ColumnValue(table.sortJson, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> createdBy(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.createdBy, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class FilterViewTable extends _isd.Table<_iss.UuidValue> {
  FilterViewTable({super.tableRelation}) : super(tableName: 'filter_view') {
    updateTable = FilterViewUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    sheetId = _isd.ColumnUuid('sheetId', this);
    name = _isd.ColumnString('name', this);
    rangeJson = _isd.ColumnString('rangeJson', this);
    criteriaJson = _isd.ColumnString('criteriaJson', this);
    sortJson = _isd.ColumnString('sortJson', this);
    createdBy = _isd.ColumnUuid('createdBy', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final FilterViewUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid sheetId;

  _i810rwvy.SheetTable? _sheet;

  late final _isd.ColumnString name;

  late final _isd.ColumnString rangeJson;

  late final _isd.ColumnString criteriaJson;

  late final _isd.ColumnString sortJson;

  late final _isd.ColumnUuid createdBy;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SheetTable get sheet {
    if (_sheet != null) return _sheet!;
    _sheet = _isd.createRelationTable(
      relationFieldName: 'sheet',
      field: FilterView.t.sheetId,
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
    name,
    rangeJson,
    criteriaJson,
    sortJson,
    createdBy,
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

class FilterViewInclude extends _isd.IncludeObject {
  FilterViewInclude._({_i810rwvy.SheetInclude? sheet}) {
    _sheet = sheet;
  }

  _i810rwvy.SheetInclude? _sheet;

  @override
  Map<String, _isd.Include?> get includes => {'sheet': _sheet};

  @override
  _isd.Table<_iss.UuidValue> get table => FilterView.t;
}

class FilterViewIncludeList extends _isd.IncludeList {
  FilterViewIncludeList._({
    _isd.WhereExpressionBuilder<FilterViewTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FilterView.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => FilterView.t;
}

class FilterViewRepository {
  const FilterViewRepository._();

  final attachRow = const FilterViewAttachRowRepository._();

  /// Returns a list of [FilterView]s matching the given query parameters.
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
  Future<List<FilterView>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FilterViewTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FilterViewTable>? orderBy,
    _isd.OrderByListBuilder<FilterViewTable>? orderByList,
    _isd.Transaction? transaction,
    FilterViewInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FilterView>(
      where: where?.call(FilterView.t),
      orderBy: orderBy?.call(FilterView.t),
      orderByList: orderByList?.call(FilterView.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [FilterView]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `FilterView.t`.
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
  _ida.Stream<List<FilterView>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FilterViewTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FilterViewTable>? orderBy,
    _isd.OrderByListBuilder<FilterViewTable>? orderByList,
    FilterViewInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<FilterView>(
      where: where?.call(FilterView.t),
      orderBy: orderBy?.call(FilterView.t),
      orderByList: orderByList?.call(FilterView.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [FilterView] matching the given query parameters.
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
  Future<FilterView?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FilterViewTable>? where,
    int? offset,
    _isd.OrderByBuilder<FilterViewTable>? orderBy,
    _isd.OrderByListBuilder<FilterViewTable>? orderByList,
    _isd.Transaction? transaction,
    FilterViewInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FilterView>(
      where: where?.call(FilterView.t),
      orderBy: orderBy?.call(FilterView.t),
      orderByList: orderByList?.call(FilterView.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FilterView] by its [id] or null if no such row exists.
  Future<FilterView?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    FilterViewInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FilterView>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FilterView]s in the list and returns the inserted rows.
  ///
  /// The returned [FilterView]s will have their `id` fields set.
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
  Future<List<FilterView>> insert(
    _isd.DatabaseSession session,
    List<FilterView> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FilterView>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FilterView] and returns the inserted row.
  ///
  /// The returned [FilterView] will have its `id` field set.
  Future<FilterView> insertRow(
    _isd.DatabaseSession session,
    FilterView row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<FilterView>(row, transaction: transaction);
  }

  /// Upserts all [FilterView]s in the list and returns the resulting rows.
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
  /// The returned [FilterView]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FilterView>> upsert(
    _isd.DatabaseSession session,
    List<FilterView> rows, {
    required _isd.ColumnSelections<FilterViewTable> conflictColumns,
    _isd.ColumnSelections<FilterViewTable>? updateColumns,
    _isd.WhereExpressionBuilder<FilterViewTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FilterView>(
      rows,
      conflictColumns: conflictColumns(FilterView.t),
      updateColumns: updateColumns?.call(FilterView.t),
      updateWhere: updateWhere?.call(FilterView.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FilterView] and returns the resulting row.
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
  /// The returned [FilterView] will have its `id` field set.
  Future<FilterView?> upsertRow(
    _isd.DatabaseSession session,
    FilterView row, {
    required _isd.ColumnSelections<FilterViewTable> conflictColumns,
    _isd.ColumnSelections<FilterViewTable>? updateColumns,
    _isd.WhereExpressionBuilder<FilterViewTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FilterView>(
      row,
      conflictColumns: conflictColumns(FilterView.t),
      updateColumns: updateColumns?.call(FilterView.t),
      updateWhere: updateWhere?.call(FilterView.t),
      transaction: transaction,
    );
  }

  /// Updates all [FilterView]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FilterView>> update(
    _isd.DatabaseSession session,
    List<FilterView> rows, {
    _isd.ColumnSelections<FilterViewTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FilterView>(
      rows,
      columns: columns?.call(FilterView.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FilterView]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FilterView> updateRow(
    _isd.DatabaseSession session,
    FilterView row, {
    _isd.ColumnSelections<FilterViewTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<FilterView>(
      row,
      columns: columns?.call(FilterView.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FilterView] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FilterView?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<FilterViewUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<FilterView>(
      id,
      columnValues: columnValues(FilterView.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FilterView]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FilterView>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<FilterViewUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<FilterViewTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FilterViewTable>? orderBy,
    _isd.OrderByListBuilder<FilterViewTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FilterView>(
      columnValues: columnValues(FilterView.t.updateTable),
      where: where(FilterView.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FilterView.t),
      orderByList: orderByList?.call(FilterView.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FilterView]s in the list and returns the deleted rows.
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
  Future<List<FilterView>> delete(
    _isd.DatabaseSession session,
    List<FilterView> rows, {
    _isd.OrderByBuilder<FilterViewTable>? orderBy,
    _isd.OrderByListBuilder<FilterViewTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FilterView>(
      rows,
      orderBy: orderBy?.call(FilterView.t),
      orderByList: orderByList?.call(FilterView.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FilterView].
  Future<FilterView> deleteRow(
    _isd.DatabaseSession session,
    FilterView row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FilterView>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FilterView>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FilterViewTable> where,
    _isd.OrderByBuilder<FilterViewTable>? orderBy,
    _isd.OrderByListBuilder<FilterViewTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FilterView>(
      where: where(FilterView.t),
      orderBy: orderBy?.call(FilterView.t),
      orderByList: orderByList?.call(FilterView.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FilterViewTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<FilterView>(
      where: where?.call(FilterView.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FilterView] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FilterViewTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FilterView>(
      where: where(FilterView.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class FilterViewAttachRowRepository {
  const FilterViewAttachRowRepository._();

  /// Creates a relation between the given [FilterView] and [Sheet]
  /// by setting the [FilterView]'s foreign key `sheetId` to refer to the [Sheet].
  Future<void> sheet(
    _isd.DatabaseSession session,
    FilterView filterView,
    _i810rwvy.Sheet sheet, {
    _isd.Transaction? transaction,
  }) async {
    if (filterView.id == null) {
      throw ArgumentError.notNull('filterView.id');
    }
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }

    var $filterView = filterView.copyWith(sheetId: sheet.id);
    await session.db.updateRow<FilterView>(
      $filterView,
      columns: [FilterView.t.sheetId],
      transaction: transaction,
    );
  }
}
