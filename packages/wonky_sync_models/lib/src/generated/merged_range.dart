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

/// A merged block of cells.
abstract class MergedRange
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  MergedRange._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.sheetId,
    this.sheet,
    required this.rangeJson,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory MergedRange({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String rangeJson,
    DateTime? createdAt,
  }) = _MergedRangeImpl;

  factory MergedRange.fromJson(Map<String, dynamic> jsonSerialization) {
    return MergedRange(
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
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = MergedRangeTable();

  static const db = MergedRangeRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue sheetId;

  _i810rwvy.Sheet? sheet;

  /// GridRange with all four bounds.
  String rangeJson;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [MergedRange]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  MergedRange copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedMergedRange$sheet(),
    String? rangeJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MergedRange',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJson(),
      'rangeJson': rangeJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MergedRange',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJsonForProtocol(),
      'rangeJson': rangeJson,
      'createdAt': createdAt.toJson(),
    };
  }

  static MergedRangeInclude include({_i810rwvy.SheetInclude? sheet}) {
    return MergedRangeInclude._(sheet: sheet);
  }

  static MergedRangeIncludeList includeList({
    _isd.WhereExpressionBuilder<MergedRangeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<MergedRangeTable>? orderBy,
    _isd.OrderByListBuilder<MergedRangeTable>? orderByList,
    MergedRangeInclude? include,
  }) {
    return MergedRangeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MergedRange.t),
      orderByList: orderByList?.call(MergedRange.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedMergedRange$sheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Sheet {
  const _UndefinedMergedRange$sheet();
}

class _MergedRangeImpl extends MergedRange {
  _MergedRangeImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String rangeJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         sheetId: sheetId,
         sheet: sheet,
         rangeJson: rangeJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [MergedRange]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  MergedRange copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedMergedRange$sheet(),
    String? rangeJson,
    DateTime? createdAt,
  }) {
    return MergedRange(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      sheetId: sheetId ?? this.sheetId,
      sheet: sheet is _iss.UndefinedSentinel ? this.sheet?.copyWith() : sheet,
      rangeJson: rangeJson ?? this.rangeJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MergedRangeUpdateTable extends _isd.UpdateTable<MergedRangeTable> {
  MergedRangeUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> sheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<String, String> rangeJson(String value) =>
      _isd.ColumnValue(table.rangeJson, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class MergedRangeTable extends _isd.Table<_iss.UuidValue> {
  MergedRangeTable({super.tableRelation}) : super(tableName: 'merged_range') {
    updateTable = MergedRangeUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    sheetId = _isd.ColumnUuid('sheetId', this);
    rangeJson = _isd.ColumnString('rangeJson', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final MergedRangeUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid sheetId;

  _i810rwvy.SheetTable? _sheet;

  /// GridRange with all four bounds.
  late final _isd.ColumnString rangeJson;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SheetTable get sheet {
    if (_sheet != null) return _sheet!;
    _sheet = _isd.createRelationTable(
      relationFieldName: 'sheet',
      field: MergedRange.t.sheetId,
      foreignField: _i810rwvy.Sheet.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SheetTable(tableRelation: foreignTableRelation),
    );
    return _sheet!;
  }

  @override
  List<_isd.Column> get columns => [id, spaceId, sheetId, rangeJson, createdAt];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'sheet') {
      return sheet;
    }
    return null;
  }
}

class MergedRangeInclude extends _isd.IncludeObject {
  MergedRangeInclude._({_i810rwvy.SheetInclude? sheet}) {
    _sheet = sheet;
  }

  _i810rwvy.SheetInclude? _sheet;

  @override
  Map<String, _isd.Include?> get includes => {'sheet': _sheet};

  @override
  _isd.Table<_iss.UuidValue> get table => MergedRange.t;
}

class MergedRangeIncludeList extends _isd.IncludeList {
  MergedRangeIncludeList._({
    _isd.WhereExpressionBuilder<MergedRangeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(MergedRange.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => MergedRange.t;
}

class MergedRangeRepository {
  const MergedRangeRepository._();

  final attachRow = const MergedRangeAttachRowRepository._();

  /// Returns a list of [MergedRange]s matching the given query parameters.
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
  Future<List<MergedRange>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<MergedRangeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<MergedRangeTable>? orderBy,
    _isd.OrderByListBuilder<MergedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    MergedRangeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<MergedRange>(
      where: where?.call(MergedRange.t),
      orderBy: orderBy?.call(MergedRange.t),
      orderByList: orderByList?.call(MergedRange.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [MergedRange]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `MergedRange.t`.
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
  _ida.Stream<List<MergedRange>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<MergedRangeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<MergedRangeTable>? orderBy,
    _isd.OrderByListBuilder<MergedRangeTable>? orderByList,
    MergedRangeInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<MergedRange>(
      where: where?.call(MergedRange.t),
      orderBy: orderBy?.call(MergedRange.t),
      orderByList: orderByList?.call(MergedRange.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [MergedRange] matching the given query parameters.
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
  Future<MergedRange?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<MergedRangeTable>? where,
    int? offset,
    _isd.OrderByBuilder<MergedRangeTable>? orderBy,
    _isd.OrderByListBuilder<MergedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    MergedRangeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<MergedRange>(
      where: where?.call(MergedRange.t),
      orderBy: orderBy?.call(MergedRange.t),
      orderByList: orderByList?.call(MergedRange.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [MergedRange] by its [id] or null if no such row exists.
  Future<MergedRange?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    MergedRangeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<MergedRange>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [MergedRange]s in the list and returns the inserted rows.
  ///
  /// The returned [MergedRange]s will have their `id` fields set.
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
  Future<List<MergedRange>> insert(
    _isd.DatabaseSession session,
    List<MergedRange> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<MergedRange>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [MergedRange] and returns the inserted row.
  ///
  /// The returned [MergedRange] will have its `id` field set.
  Future<MergedRange> insertRow(
    _isd.DatabaseSession session,
    MergedRange row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<MergedRange>(row, transaction: transaction);
  }

  /// Upserts all [MergedRange]s in the list and returns the resulting rows.
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
  /// The returned [MergedRange]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MergedRange>> upsert(
    _isd.DatabaseSession session,
    List<MergedRange> rows, {
    required _isd.ColumnSelections<MergedRangeTable> conflictColumns,
    _isd.ColumnSelections<MergedRangeTable>? updateColumns,
    _isd.WhereExpressionBuilder<MergedRangeTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<MergedRange>(
      rows,
      conflictColumns: conflictColumns(MergedRange.t),
      updateColumns: updateColumns?.call(MergedRange.t),
      updateWhere: updateWhere?.call(MergedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [MergedRange] and returns the resulting row.
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
  /// The returned [MergedRange] will have its `id` field set.
  Future<MergedRange?> upsertRow(
    _isd.DatabaseSession session,
    MergedRange row, {
    required _isd.ColumnSelections<MergedRangeTable> conflictColumns,
    _isd.ColumnSelections<MergedRangeTable>? updateColumns,
    _isd.WhereExpressionBuilder<MergedRangeTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<MergedRange>(
      row,
      conflictColumns: conflictColumns(MergedRange.t),
      updateColumns: updateColumns?.call(MergedRange.t),
      updateWhere: updateWhere?.call(MergedRange.t),
      transaction: transaction,
    );
  }

  /// Updates all [MergedRange]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MergedRange>> update(
    _isd.DatabaseSession session,
    List<MergedRange> rows, {
    _isd.ColumnSelections<MergedRangeTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<MergedRange>(
      rows,
      columns: columns?.call(MergedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [MergedRange]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<MergedRange> updateRow(
    _isd.DatabaseSession session,
    MergedRange row, {
    _isd.ColumnSelections<MergedRangeTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<MergedRange>(
      row,
      columns: columns?.call(MergedRange.t),
      transaction: transaction,
    );
  }

  /// Updates a single [MergedRange] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<MergedRange?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<MergedRangeUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<MergedRange>(
      id,
      columnValues: columnValues(MergedRange.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [MergedRange]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MergedRange>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<MergedRangeUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<MergedRangeTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<MergedRangeTable>? orderBy,
    _isd.OrderByListBuilder<MergedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<MergedRange>(
      columnValues: columnValues(MergedRange.t.updateTable),
      where: where(MergedRange.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MergedRange.t),
      orderByList: orderByList?.call(MergedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [MergedRange]s in the list and returns the deleted rows.
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
  Future<List<MergedRange>> delete(
    _isd.DatabaseSession session,
    List<MergedRange> rows, {
    _isd.OrderByBuilder<MergedRangeTable>? orderBy,
    _isd.OrderByListBuilder<MergedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<MergedRange>(
      rows,
      orderBy: orderBy?.call(MergedRange.t),
      orderByList: orderByList?.call(MergedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [MergedRange].
  Future<MergedRange> deleteRow(
    _isd.DatabaseSession session,
    MergedRange row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<MergedRange>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MergedRange>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<MergedRangeTable> where,
    _isd.OrderByBuilder<MergedRangeTable>? orderBy,
    _isd.OrderByListBuilder<MergedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<MergedRange>(
      where: where(MergedRange.t),
      orderBy: orderBy?.call(MergedRange.t),
      orderByList: orderByList?.call(MergedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<MergedRangeTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<MergedRange>(
      where: where?.call(MergedRange.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [MergedRange] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<MergedRangeTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<MergedRange>(
      where: where(MergedRange.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class MergedRangeAttachRowRepository {
  const MergedRangeAttachRowRepository._();

  /// Creates a relation between the given [MergedRange] and [Sheet]
  /// by setting the [MergedRange]'s foreign key `sheetId` to refer to the [Sheet].
  Future<void> sheet(
    _isd.DatabaseSession session,
    MergedRange mergedRange,
    _i810rwvy.Sheet sheet, {
    _isd.Transaction? transaction,
  }) async {
    if (mergedRange.id == null) {
      throw ArgumentError.notNull('mergedRange.id');
    }
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }

    var $mergedRange = mergedRange.copyWith(sheetId: sheet.id);
    await session.db.updateRow<MergedRange>(
      $mergedRange,
      columns: [MergedRange.t.sheetId],
      transaction: transaction,
    );
  }
}
