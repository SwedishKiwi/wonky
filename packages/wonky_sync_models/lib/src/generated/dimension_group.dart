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

/// Row/column grouping (outline).
abstract class DimensionGroup
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  DimensionGroup._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.sheetId,
    this.sheet,
    required this.dimension,
    required this.startId,
    required this.endId,
    required this.depth,
    bool? collapsed,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       collapsed = collapsed ?? false,
       createdAt = createdAt ?? DateTime.now();

  factory DimensionGroup({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required _i810rwvy.Dimension dimension,
    required _iss.UuidValue startId,
    required _iss.UuidValue endId,
    required int depth,
    bool? collapsed,
    DateTime? createdAt,
  }) = _DimensionGroupImpl;

  factory DimensionGroup.fromJson(Map<String, dynamic> jsonSerialization) {
    return DimensionGroup(
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
      dimension: _i810rwvy.Dimension.fromJson(
        (jsonSerialization['dimension'] as String),
      ),
      startId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['startId'],
      ),
      endId: _iss.UuidValueJsonExtension.fromJson(jsonSerialization['endId']),
      depth: jsonSerialization['depth'] as int,
      collapsed: jsonSerialization['collapsed'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['collapsed']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = DimensionGroupTable();

  static const db = DimensionGroupRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue sheetId;

  _i810rwvy.Sheet? sheet;

  _i810rwvy.Dimension dimension;

  _iss.UuidValue startId;

  _iss.UuidValue endId;

  /// 1..8.
  int depth;

  bool collapsed;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [DimensionGroup]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  DimensionGroup copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedDimensionGroup$sheet(),
    _i810rwvy.Dimension? dimension,
    _iss.UuidValue? startId,
    _iss.UuidValue? endId,
    int? depth,
    bool? collapsed,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DimensionGroup',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJson(),
      'dimension': dimension.toJson(),
      'startId': startId.toJson(),
      'endId': endId.toJson(),
      'depth': depth,
      'collapsed': collapsed,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DimensionGroup',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJsonForProtocol(),
      'dimension': dimension.toJson(),
      'startId': startId.toJson(),
      'endId': endId.toJson(),
      'depth': depth,
      'collapsed': collapsed,
      'createdAt': createdAt.toJson(),
    };
  }

  static DimensionGroupInclude include({_i810rwvy.SheetInclude? sheet}) {
    return DimensionGroupInclude._(sheet: sheet);
  }

  static DimensionGroupIncludeList includeList({
    _isd.WhereExpressionBuilder<DimensionGroupTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DimensionGroupTable>? orderBy,
    _isd.OrderByListBuilder<DimensionGroupTable>? orderByList,
    DimensionGroupInclude? include,
  }) {
    return DimensionGroupIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DimensionGroup.t),
      orderByList: orderByList?.call(DimensionGroup.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedDimensionGroup$sheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Sheet {
  const _UndefinedDimensionGroup$sheet();
}

class _DimensionGroupImpl extends DimensionGroup {
  _DimensionGroupImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required _i810rwvy.Dimension dimension,
    required _iss.UuidValue startId,
    required _iss.UuidValue endId,
    required int depth,
    bool? collapsed,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         sheetId: sheetId,
         sheet: sheet,
         dimension: dimension,
         startId: startId,
         endId: endId,
         depth: depth,
         collapsed: collapsed,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DimensionGroup]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  DimensionGroup copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedDimensionGroup$sheet(),
    _i810rwvy.Dimension? dimension,
    _iss.UuidValue? startId,
    _iss.UuidValue? endId,
    int? depth,
    bool? collapsed,
    DateTime? createdAt,
  }) {
    return DimensionGroup(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      sheetId: sheetId ?? this.sheetId,
      sheet: sheet is _iss.UndefinedSentinel ? this.sheet?.copyWith() : sheet,
      dimension: dimension ?? this.dimension,
      startId: startId ?? this.startId,
      endId: endId ?? this.endId,
      depth: depth ?? this.depth,
      collapsed: collapsed ?? this.collapsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DimensionGroupUpdateTable extends _isd.UpdateTable<DimensionGroupTable> {
  DimensionGroupUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> sheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<_i810rwvy.Dimension, _i810rwvy.Dimension> dimension(
    _i810rwvy.Dimension value,
  ) => _isd.ColumnValue(table.dimension, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> startId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.startId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> endId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.endId, value);

  _isd.ColumnValue<int, int> depth(int value) =>
      _isd.ColumnValue(table.depth, value);

  _isd.ColumnValue<bool, bool> collapsed(bool value) =>
      _isd.ColumnValue(table.collapsed, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class DimensionGroupTable extends _isd.Table<_iss.UuidValue> {
  DimensionGroupTable({super.tableRelation})
    : super(tableName: 'dimension_group') {
    updateTable = DimensionGroupUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    sheetId = _isd.ColumnUuid('sheetId', this);
    dimension = _isd.ColumnEnum(
      'dimension',
      this,
      _isd.EnumSerialization.byName,
    );
    startId = _isd.ColumnUuid('startId', this);
    endId = _isd.ColumnUuid('endId', this);
    depth = _isd.ColumnInt('depth', this);
    collapsed = _isd.ColumnBool('collapsed', this, hasDefault: true);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final DimensionGroupUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid sheetId;

  _i810rwvy.SheetTable? _sheet;

  late final _isd.ColumnEnum<_i810rwvy.Dimension> dimension;

  late final _isd.ColumnUuid startId;

  late final _isd.ColumnUuid endId;

  /// 1..8.
  late final _isd.ColumnInt depth;

  late final _isd.ColumnBool collapsed;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SheetTable get sheet {
    if (_sheet != null) return _sheet!;
    _sheet = _isd.createRelationTable(
      relationFieldName: 'sheet',
      field: DimensionGroup.t.sheetId,
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
    dimension,
    startId,
    endId,
    depth,
    collapsed,
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

class DimensionGroupInclude extends _isd.IncludeObject {
  DimensionGroupInclude._({_i810rwvy.SheetInclude? sheet}) {
    _sheet = sheet;
  }

  _i810rwvy.SheetInclude? _sheet;

  @override
  Map<String, _isd.Include?> get includes => {'sheet': _sheet};

  @override
  _isd.Table<_iss.UuidValue> get table => DimensionGroup.t;
}

class DimensionGroupIncludeList extends _isd.IncludeList {
  DimensionGroupIncludeList._({
    _isd.WhereExpressionBuilder<DimensionGroupTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DimensionGroup.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => DimensionGroup.t;
}

class DimensionGroupRepository {
  const DimensionGroupRepository._();

  final attachRow = const DimensionGroupAttachRowRepository._();

  /// Returns a list of [DimensionGroup]s matching the given query parameters.
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
  Future<List<DimensionGroup>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DimensionGroupTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DimensionGroupTable>? orderBy,
    _isd.OrderByListBuilder<DimensionGroupTable>? orderByList,
    _isd.Transaction? transaction,
    DimensionGroupInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DimensionGroup>(
      where: where?.call(DimensionGroup.t),
      orderBy: orderBy?.call(DimensionGroup.t),
      orderByList: orderByList?.call(DimensionGroup.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [DimensionGroup]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `DimensionGroup.t`.
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
  _ida.Stream<List<DimensionGroup>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DimensionGroupTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DimensionGroupTable>? orderBy,
    _isd.OrderByListBuilder<DimensionGroupTable>? orderByList,
    DimensionGroupInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<DimensionGroup>(
      where: where?.call(DimensionGroup.t),
      orderBy: orderBy?.call(DimensionGroup.t),
      orderByList: orderByList?.call(DimensionGroup.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [DimensionGroup] matching the given query parameters.
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
  Future<DimensionGroup?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DimensionGroupTable>? where,
    int? offset,
    _isd.OrderByBuilder<DimensionGroupTable>? orderBy,
    _isd.OrderByListBuilder<DimensionGroupTable>? orderByList,
    _isd.Transaction? transaction,
    DimensionGroupInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DimensionGroup>(
      where: where?.call(DimensionGroup.t),
      orderBy: orderBy?.call(DimensionGroup.t),
      orderByList: orderByList?.call(DimensionGroup.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DimensionGroup] by its [id] or null if no such row exists.
  Future<DimensionGroup?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    DimensionGroupInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DimensionGroup>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DimensionGroup]s in the list and returns the inserted rows.
  ///
  /// The returned [DimensionGroup]s will have their `id` fields set.
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
  Future<List<DimensionGroup>> insert(
    _isd.DatabaseSession session,
    List<DimensionGroup> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DimensionGroup>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DimensionGroup] and returns the inserted row.
  ///
  /// The returned [DimensionGroup] will have its `id` field set.
  Future<DimensionGroup> insertRow(
    _isd.DatabaseSession session,
    DimensionGroup row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<DimensionGroup>(row, transaction: transaction);
  }

  /// Upserts all [DimensionGroup]s in the list and returns the resulting rows.
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
  /// The returned [DimensionGroup]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DimensionGroup>> upsert(
    _isd.DatabaseSession session,
    List<DimensionGroup> rows, {
    required _isd.ColumnSelections<DimensionGroupTable> conflictColumns,
    _isd.ColumnSelections<DimensionGroupTable>? updateColumns,
    _isd.WhereExpressionBuilder<DimensionGroupTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DimensionGroup>(
      rows,
      conflictColumns: conflictColumns(DimensionGroup.t),
      updateColumns: updateColumns?.call(DimensionGroup.t),
      updateWhere: updateWhere?.call(DimensionGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DimensionGroup] and returns the resulting row.
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
  /// The returned [DimensionGroup] will have its `id` field set.
  Future<DimensionGroup?> upsertRow(
    _isd.DatabaseSession session,
    DimensionGroup row, {
    required _isd.ColumnSelections<DimensionGroupTable> conflictColumns,
    _isd.ColumnSelections<DimensionGroupTable>? updateColumns,
    _isd.WhereExpressionBuilder<DimensionGroupTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DimensionGroup>(
      row,
      conflictColumns: conflictColumns(DimensionGroup.t),
      updateColumns: updateColumns?.call(DimensionGroup.t),
      updateWhere: updateWhere?.call(DimensionGroup.t),
      transaction: transaction,
    );
  }

  /// Updates all [DimensionGroup]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DimensionGroup>> update(
    _isd.DatabaseSession session,
    List<DimensionGroup> rows, {
    _isd.ColumnSelections<DimensionGroupTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DimensionGroup>(
      rows,
      columns: columns?.call(DimensionGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DimensionGroup]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DimensionGroup> updateRow(
    _isd.DatabaseSession session,
    DimensionGroup row, {
    _isd.ColumnSelections<DimensionGroupTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<DimensionGroup>(
      row,
      columns: columns?.call(DimensionGroup.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DimensionGroup] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DimensionGroup?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<DimensionGroupUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<DimensionGroup>(
      id,
      columnValues: columnValues(DimensionGroup.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DimensionGroup]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DimensionGroup>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<DimensionGroupUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<DimensionGroupTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DimensionGroupTable>? orderBy,
    _isd.OrderByListBuilder<DimensionGroupTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DimensionGroup>(
      columnValues: columnValues(DimensionGroup.t.updateTable),
      where: where(DimensionGroup.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DimensionGroup.t),
      orderByList: orderByList?.call(DimensionGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DimensionGroup]s in the list and returns the deleted rows.
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
  Future<List<DimensionGroup>> delete(
    _isd.DatabaseSession session,
    List<DimensionGroup> rows, {
    _isd.OrderByBuilder<DimensionGroupTable>? orderBy,
    _isd.OrderByListBuilder<DimensionGroupTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DimensionGroup>(
      rows,
      orderBy: orderBy?.call(DimensionGroup.t),
      orderByList: orderByList?.call(DimensionGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DimensionGroup].
  Future<DimensionGroup> deleteRow(
    _isd.DatabaseSession session,
    DimensionGroup row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DimensionGroup>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DimensionGroup>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<DimensionGroupTable> where,
    _isd.OrderByBuilder<DimensionGroupTable>? orderBy,
    _isd.OrderByListBuilder<DimensionGroupTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DimensionGroup>(
      where: where(DimensionGroup.t),
      orderBy: orderBy?.call(DimensionGroup.t),
      orderByList: orderByList?.call(DimensionGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DimensionGroupTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<DimensionGroup>(
      where: where?.call(DimensionGroup.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DimensionGroup] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<DimensionGroupTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DimensionGroup>(
      where: where(DimensionGroup.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class DimensionGroupAttachRowRepository {
  const DimensionGroupAttachRowRepository._();

  /// Creates a relation between the given [DimensionGroup] and [Sheet]
  /// by setting the [DimensionGroup]'s foreign key `sheetId` to refer to the [Sheet].
  Future<void> sheet(
    _isd.DatabaseSession session,
    DimensionGroup dimensionGroup,
    _i810rwvy.Sheet sheet, {
    _isd.Transaction? transaction,
  }) async {
    if (dimensionGroup.id == null) {
      throw ArgumentError.notNull('dimensionGroup.id');
    }
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }

    var $dimensionGroup = dimensionGroup.copyWith(sheetId: sheet.id);
    await session.db.updateRow<DimensionGroup>(
      $dimensionGroup,
      columns: [DimensionGroup.t.sheetId],
      transaction: transaction,
    );
  }
}
