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

/// A pivot table; its output is computed locally, never stored as cells.
abstract class PivotTable
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  PivotTable._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.sheetId,
    this.sheet,
    required this.anchorRowId,
    required this.anchorColId,
    required this.sourceRangeJson,
    required this.specJson,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory PivotTable({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required _iss.UuidValue anchorRowId,
    required _iss.UuidValue anchorColId,
    required String sourceRangeJson,
    required String specJson,
    DateTime? createdAt,
  }) = _PivotTableImpl;

  factory PivotTable.fromJson(Map<String, dynamic> jsonSerialization) {
    return PivotTable(
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
      anchorRowId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['anchorRowId'],
      ),
      anchorColId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['anchorColId'],
      ),
      sourceRangeJson: jsonSerialization['sourceRangeJson'] as String,
      specJson: jsonSerialization['specJson'] as String,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = PivotTableTable();

  static const db = PivotTableRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue sheetId;

  /// Sheet that displays the pivot.
  _i810rwvy.Sheet? sheet;

  _iss.UuidValue anchorRowId;

  _iss.UuidValue anchorColId;

  String sourceRangeJson;

  /// PivotSpec v1 (Sheets 07 §7.1).
  String specJson;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [PivotTable]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  PivotTable copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedPivotTable$sheet(),
    _iss.UuidValue? anchorRowId,
    _iss.UuidValue? anchorColId,
    String? sourceRangeJson,
    String? specJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PivotTable',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJson(),
      'anchorRowId': anchorRowId.toJson(),
      'anchorColId': anchorColId.toJson(),
      'sourceRangeJson': sourceRangeJson,
      'specJson': specJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PivotTable',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJsonForProtocol(),
      'anchorRowId': anchorRowId.toJson(),
      'anchorColId': anchorColId.toJson(),
      'sourceRangeJson': sourceRangeJson,
      'specJson': specJson,
      'createdAt': createdAt.toJson(),
    };
  }

  static PivotTableInclude include({_i810rwvy.SheetInclude? sheet}) {
    return PivotTableInclude._(sheet: sheet);
  }

  static PivotTableIncludeList includeList({
    _isd.WhereExpressionBuilder<PivotTableTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<PivotTableTable>? orderBy,
    _isd.OrderByListBuilder<PivotTableTable>? orderByList,
    PivotTableInclude? include,
  }) {
    return PivotTableIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PivotTable.t),
      orderByList: orderByList?.call(PivotTable.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedPivotTable$sheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Sheet {
  const _UndefinedPivotTable$sheet();
}

class _PivotTableImpl extends PivotTable {
  _PivotTableImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required _iss.UuidValue anchorRowId,
    required _iss.UuidValue anchorColId,
    required String sourceRangeJson,
    required String specJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         sheetId: sheetId,
         sheet: sheet,
         anchorRowId: anchorRowId,
         anchorColId: anchorColId,
         sourceRangeJson: sourceRangeJson,
         specJson: specJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [PivotTable]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  PivotTable copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedPivotTable$sheet(),
    _iss.UuidValue? anchorRowId,
    _iss.UuidValue? anchorColId,
    String? sourceRangeJson,
    String? specJson,
    DateTime? createdAt,
  }) {
    return PivotTable(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      sheetId: sheetId ?? this.sheetId,
      sheet: sheet is _iss.UndefinedSentinel ? this.sheet?.copyWith() : sheet,
      anchorRowId: anchorRowId ?? this.anchorRowId,
      anchorColId: anchorColId ?? this.anchorColId,
      sourceRangeJson: sourceRangeJson ?? this.sourceRangeJson,
      specJson: specJson ?? this.specJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PivotTableUpdateTable extends _isd.UpdateTable<PivotTableTable> {
  PivotTableUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> sheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> anchorRowId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.anchorRowId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> anchorColId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.anchorColId, value);

  _isd.ColumnValue<String, String> sourceRangeJson(String value) =>
      _isd.ColumnValue(table.sourceRangeJson, value);

  _isd.ColumnValue<String, String> specJson(String value) =>
      _isd.ColumnValue(table.specJson, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class PivotTableTable extends _isd.Table<_iss.UuidValue> {
  PivotTableTable({super.tableRelation}) : super(tableName: 'pivot_table') {
    updateTable = PivotTableUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    sheetId = _isd.ColumnUuid('sheetId', this);
    anchorRowId = _isd.ColumnUuid('anchorRowId', this);
    anchorColId = _isd.ColumnUuid('anchorColId', this);
    sourceRangeJson = _isd.ColumnString('sourceRangeJson', this);
    specJson = _isd.ColumnString('specJson', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final PivotTableUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid sheetId;

  /// Sheet that displays the pivot.
  _i810rwvy.SheetTable? _sheet;

  late final _isd.ColumnUuid anchorRowId;

  late final _isd.ColumnUuid anchorColId;

  late final _isd.ColumnString sourceRangeJson;

  /// PivotSpec v1 (Sheets 07 §7.1).
  late final _isd.ColumnString specJson;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SheetTable get sheet {
    if (_sheet != null) return _sheet!;
    _sheet = _isd.createRelationTable(
      relationFieldName: 'sheet',
      field: PivotTable.t.sheetId,
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
    anchorRowId,
    anchorColId,
    sourceRangeJson,
    specJson,
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

class PivotTableInclude extends _isd.IncludeObject {
  PivotTableInclude._({_i810rwvy.SheetInclude? sheet}) {
    _sheet = sheet;
  }

  _i810rwvy.SheetInclude? _sheet;

  @override
  Map<String, _isd.Include?> get includes => {'sheet': _sheet};

  @override
  _isd.Table<_iss.UuidValue> get table => PivotTable.t;
}

class PivotTableIncludeList extends _isd.IncludeList {
  PivotTableIncludeList._({
    _isd.WhereExpressionBuilder<PivotTableTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(PivotTable.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => PivotTable.t;
}

class PivotTableRepository {
  const PivotTableRepository._();

  final attachRow = const PivotTableAttachRowRepository._();

  /// Returns a list of [PivotTable]s matching the given query parameters.
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
  Future<List<PivotTable>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<PivotTableTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<PivotTableTable>? orderBy,
    _isd.OrderByListBuilder<PivotTableTable>? orderByList,
    _isd.Transaction? transaction,
    PivotTableInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<PivotTable>(
      where: where?.call(PivotTable.t),
      orderBy: orderBy?.call(PivotTable.t),
      orderByList: orderByList?.call(PivotTable.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [PivotTable]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `PivotTable.t`.
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
  _ida.Stream<List<PivotTable>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<PivotTableTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<PivotTableTable>? orderBy,
    _isd.OrderByListBuilder<PivotTableTable>? orderByList,
    PivotTableInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<PivotTable>(
      where: where?.call(PivotTable.t),
      orderBy: orderBy?.call(PivotTable.t),
      orderByList: orderByList?.call(PivotTable.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [PivotTable] matching the given query parameters.
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
  Future<PivotTable?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<PivotTableTable>? where,
    int? offset,
    _isd.OrderByBuilder<PivotTableTable>? orderBy,
    _isd.OrderByListBuilder<PivotTableTable>? orderByList,
    _isd.Transaction? transaction,
    PivotTableInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<PivotTable>(
      where: where?.call(PivotTable.t),
      orderBy: orderBy?.call(PivotTable.t),
      orderByList: orderByList?.call(PivotTable.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [PivotTable] by its [id] or null if no such row exists.
  Future<PivotTable?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    PivotTableInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<PivotTable>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [PivotTable]s in the list and returns the inserted rows.
  ///
  /// The returned [PivotTable]s will have their `id` fields set.
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
  Future<List<PivotTable>> insert(
    _isd.DatabaseSession session,
    List<PivotTable> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<PivotTable>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [PivotTable] and returns the inserted row.
  ///
  /// The returned [PivotTable] will have its `id` field set.
  Future<PivotTable> insertRow(
    _isd.DatabaseSession session,
    PivotTable row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<PivotTable>(row, transaction: transaction);
  }

  /// Upserts all [PivotTable]s in the list and returns the resulting rows.
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
  /// The returned [PivotTable]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PivotTable>> upsert(
    _isd.DatabaseSession session,
    List<PivotTable> rows, {
    required _isd.ColumnSelections<PivotTableTable> conflictColumns,
    _isd.ColumnSelections<PivotTableTable>? updateColumns,
    _isd.WhereExpressionBuilder<PivotTableTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<PivotTable>(
      rows,
      conflictColumns: conflictColumns(PivotTable.t),
      updateColumns: updateColumns?.call(PivotTable.t),
      updateWhere: updateWhere?.call(PivotTable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [PivotTable] and returns the resulting row.
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
  /// The returned [PivotTable] will have its `id` field set.
  Future<PivotTable?> upsertRow(
    _isd.DatabaseSession session,
    PivotTable row, {
    required _isd.ColumnSelections<PivotTableTable> conflictColumns,
    _isd.ColumnSelections<PivotTableTable>? updateColumns,
    _isd.WhereExpressionBuilder<PivotTableTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<PivotTable>(
      row,
      conflictColumns: conflictColumns(PivotTable.t),
      updateColumns: updateColumns?.call(PivotTable.t),
      updateWhere: updateWhere?.call(PivotTable.t),
      transaction: transaction,
    );
  }

  /// Updates all [PivotTable]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PivotTable>> update(
    _isd.DatabaseSession session,
    List<PivotTable> rows, {
    _isd.ColumnSelections<PivotTableTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<PivotTable>(
      rows,
      columns: columns?.call(PivotTable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [PivotTable]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<PivotTable> updateRow(
    _isd.DatabaseSession session,
    PivotTable row, {
    _isd.ColumnSelections<PivotTableTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<PivotTable>(
      row,
      columns: columns?.call(PivotTable.t),
      transaction: transaction,
    );
  }

  /// Updates a single [PivotTable] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<PivotTable?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<PivotTableUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<PivotTable>(
      id,
      columnValues: columnValues(PivotTable.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [PivotTable]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PivotTable>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<PivotTableUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<PivotTableTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<PivotTableTable>? orderBy,
    _isd.OrderByListBuilder<PivotTableTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<PivotTable>(
      columnValues: columnValues(PivotTable.t.updateTable),
      where: where(PivotTable.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PivotTable.t),
      orderByList: orderByList?.call(PivotTable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [PivotTable]s in the list and returns the deleted rows.
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
  Future<List<PivotTable>> delete(
    _isd.DatabaseSession session,
    List<PivotTable> rows, {
    _isd.OrderByBuilder<PivotTableTable>? orderBy,
    _isd.OrderByListBuilder<PivotTableTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<PivotTable>(
      rows,
      orderBy: orderBy?.call(PivotTable.t),
      orderByList: orderByList?.call(PivotTable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [PivotTable].
  Future<PivotTable> deleteRow(
    _isd.DatabaseSession session,
    PivotTable row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<PivotTable>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PivotTable>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<PivotTableTable> where,
    _isd.OrderByBuilder<PivotTableTable>? orderBy,
    _isd.OrderByListBuilder<PivotTableTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<PivotTable>(
      where: where(PivotTable.t),
      orderBy: orderBy?.call(PivotTable.t),
      orderByList: orderByList?.call(PivotTable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<PivotTableTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<PivotTable>(
      where: where?.call(PivotTable.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [PivotTable] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<PivotTableTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<PivotTable>(
      where: where(PivotTable.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class PivotTableAttachRowRepository {
  const PivotTableAttachRowRepository._();

  /// Creates a relation between the given [PivotTable] and [Sheet]
  /// by setting the [PivotTable]'s foreign key `sheetId` to refer to the [Sheet].
  Future<void> sheet(
    _isd.DatabaseSession session,
    PivotTable pivotTable,
    _i810rwvy.Sheet sheet, {
    _isd.Transaction? transaction,
  }) async {
    if (pivotTable.id == null) {
      throw ArgumentError.notNull('pivotTable.id');
    }
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }

    var $pivotTable = pivotTable.copyWith(sheetId: sheet.id);
    await session.db.updateRow<PivotTable>(
      $pivotTable,
      columns: [PivotTable.t.sheetId],
      transaction: transaction,
    );
  }
}
