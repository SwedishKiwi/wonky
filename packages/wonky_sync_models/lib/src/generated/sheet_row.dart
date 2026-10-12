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

/// A row entity with a stable id, ordered by sortKey (Sheets 02 §3.2).
abstract class SheetRow
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  SheetRow._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.sheetId,
    this.sheet,
    required this.sortKey,
    this.height,
    bool? hidden,
    this.formatJson,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       hidden = hidden ?? false,
       createdAt = createdAt ?? DateTime.now();

  factory SheetRow({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String sortKey,
    double? height,
    bool? hidden,
    String? formatJson,
    DateTime? createdAt,
  }) = _SheetRowImpl;

  factory SheetRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetRow(
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
      sortKey: jsonSerialization['sortKey'] as String,
      height: (jsonSerialization['height'] as num?)?.toDouble(),
      hidden: jsonSerialization['hidden'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['hidden']),
      formatJson: jsonSerialization['formatJson'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = SheetRowTable();

  static const db = SheetRowRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue sheetId;

  _i810rwvy.Sheet? sheet;

  String sortKey;

  /// Null = default/auto-fit.
  double? height;

  /// User-hidden; filter-hidden is computed.
  bool hidden;

  /// Row default format.
  String? formatJson;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [SheetRow]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  SheetRow copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedSheetRow$sheet(),
    String? sortKey,
    double? height,
    bool? hidden,
    String? formatJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetRow',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJson(),
      'sortKey': sortKey,
      if (height != null) 'height': height,
      'hidden': hidden,
      if (formatJson != null) 'formatJson': formatJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetRow',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJsonForProtocol(),
      'sortKey': sortKey,
      if (height != null) 'height': height,
      'hidden': hidden,
      if (formatJson != null) 'formatJson': formatJson,
      'createdAt': createdAt.toJson(),
    };
  }

  static SheetRowInclude include({_i810rwvy.SheetInclude? sheet}) {
    return SheetRowInclude._(sheet: sheet);
  }

  static SheetRowIncludeList includeList({
    _isd.WhereExpressionBuilder<SheetRowTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetRowTable>? orderBy,
    _isd.OrderByListBuilder<SheetRowTable>? orderByList,
    SheetRowInclude? include,
  }) {
    return SheetRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetRow.t),
      orderByList: orderByList?.call(SheetRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedSheetRow$sheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Sheet {
  const _UndefinedSheetRow$sheet();
}

class _SheetRowImpl extends SheetRow {
  _SheetRowImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String sortKey,
    double? height,
    bool? hidden,
    String? formatJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         sheetId: sheetId,
         sheet: sheet,
         sortKey: sortKey,
         height: height,
         hidden: hidden,
         formatJson: formatJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SheetRow]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  SheetRow copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedSheetRow$sheet(),
    String? sortKey,
    Object? height = _Undefined,
    bool? hidden,
    Object? formatJson = _Undefined,
    DateTime? createdAt,
  }) {
    return SheetRow(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      sheetId: sheetId ?? this.sheetId,
      sheet: sheet is _iss.UndefinedSentinel ? this.sheet?.copyWith() : sheet,
      sortKey: sortKey ?? this.sortKey,
      height: height is double? ? height : this.height,
      hidden: hidden ?? this.hidden,
      formatJson: formatJson is String? ? formatJson : this.formatJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SheetRowUpdateTable extends _isd.UpdateTable<SheetRowTable> {
  SheetRowUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> sheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<String, String> sortKey(String value) =>
      _isd.ColumnValue(table.sortKey, value);

  _isd.ColumnValue<double, double> height(double? value) =>
      _isd.ColumnValue(table.height, value);

  _isd.ColumnValue<bool, bool> hidden(bool value) =>
      _isd.ColumnValue(table.hidden, value);

  _isd.ColumnValue<String, String> formatJson(String? value) =>
      _isd.ColumnValue(table.formatJson, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class SheetRowTable extends _isd.Table<_iss.UuidValue> {
  SheetRowTable({super.tableRelation}) : super(tableName: 'sheet_row') {
    updateTable = SheetRowUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    sheetId = _isd.ColumnUuid('sheetId', this);
    sortKey = _isd.ColumnString('sortKey', this);
    height = _isd.ColumnDouble('height', this);
    hidden = _isd.ColumnBool('hidden', this, hasDefault: true);
    formatJson = _isd.ColumnString('formatJson', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final SheetRowUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid sheetId;

  _i810rwvy.SheetTable? _sheet;

  late final _isd.ColumnString sortKey;

  /// Null = default/auto-fit.
  late final _isd.ColumnDouble height;

  /// User-hidden; filter-hidden is computed.
  late final _isd.ColumnBool hidden;

  /// Row default format.
  late final _isd.ColumnString formatJson;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SheetTable get sheet {
    if (_sheet != null) return _sheet!;
    _sheet = _isd.createRelationTable(
      relationFieldName: 'sheet',
      field: SheetRow.t.sheetId,
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
    sortKey,
    height,
    hidden,
    formatJson,
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

class SheetRowInclude extends _isd.IncludeObject {
  SheetRowInclude._({_i810rwvy.SheetInclude? sheet}) {
    _sheet = sheet;
  }

  _i810rwvy.SheetInclude? _sheet;

  @override
  Map<String, _isd.Include?> get includes => {'sheet': _sheet};

  @override
  _isd.Table<_iss.UuidValue> get table => SheetRow.t;
}

class SheetRowIncludeList extends _isd.IncludeList {
  SheetRowIncludeList._({
    _isd.WhereExpressionBuilder<SheetRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SheetRow.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => SheetRow.t;
}

class SheetRowRepository {
  const SheetRowRepository._();

  final attachRow = const SheetRowAttachRowRepository._();

  /// Returns a list of [SheetRow]s matching the given query parameters.
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
  Future<List<SheetRow>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetRowTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetRowTable>? orderBy,
    _isd.OrderByListBuilder<SheetRowTable>? orderByList,
    _isd.Transaction? transaction,
    SheetRowInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SheetRow>(
      where: where?.call(SheetRow.t),
      orderBy: orderBy?.call(SheetRow.t),
      orderByList: orderByList?.call(SheetRow.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SheetRow]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SheetRow.t`.
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
  _ida.Stream<List<SheetRow>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetRowTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetRowTable>? orderBy,
    _isd.OrderByListBuilder<SheetRowTable>? orderByList,
    SheetRowInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SheetRow>(
      where: where?.call(SheetRow.t),
      orderBy: orderBy?.call(SheetRow.t),
      orderByList: orderByList?.call(SheetRow.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SheetRow] matching the given query parameters.
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
  Future<SheetRow?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetRowTable>? where,
    int? offset,
    _isd.OrderByBuilder<SheetRowTable>? orderBy,
    _isd.OrderByListBuilder<SheetRowTable>? orderByList,
    _isd.Transaction? transaction,
    SheetRowInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SheetRow>(
      where: where?.call(SheetRow.t),
      orderBy: orderBy?.call(SheetRow.t),
      orderByList: orderByList?.call(SheetRow.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SheetRow] by its [id] or null if no such row exists.
  Future<SheetRow?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SheetRowInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SheetRow>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SheetRow]s in the list and returns the inserted rows.
  ///
  /// The returned [SheetRow]s will have their `id` fields set.
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
  Future<List<SheetRow>> insert(
    _isd.DatabaseSession session,
    List<SheetRow> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SheetRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SheetRow] and returns the inserted row.
  ///
  /// The returned [SheetRow] will have its `id` field set.
  Future<SheetRow> insertRow(
    _isd.DatabaseSession session,
    SheetRow row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SheetRow>(row, transaction: transaction);
  }

  /// Upserts all [SheetRow]s in the list and returns the resulting rows.
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
  /// The returned [SheetRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetRow>> upsert(
    _isd.DatabaseSession session,
    List<SheetRow> rows, {
    required _isd.ColumnSelections<SheetRowTable> conflictColumns,
    _isd.ColumnSelections<SheetRowTable>? updateColumns,
    _isd.WhereExpressionBuilder<SheetRowTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SheetRow>(
      rows,
      conflictColumns: conflictColumns(SheetRow.t),
      updateColumns: updateColumns?.call(SheetRow.t),
      updateWhere: updateWhere?.call(SheetRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SheetRow] and returns the resulting row.
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
  /// The returned [SheetRow] will have its `id` field set.
  Future<SheetRow?> upsertRow(
    _isd.DatabaseSession session,
    SheetRow row, {
    required _isd.ColumnSelections<SheetRowTable> conflictColumns,
    _isd.ColumnSelections<SheetRowTable>? updateColumns,
    _isd.WhereExpressionBuilder<SheetRowTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SheetRow>(
      row,
      conflictColumns: conflictColumns(SheetRow.t),
      updateColumns: updateColumns?.call(SheetRow.t),
      updateWhere: updateWhere?.call(SheetRow.t),
      transaction: transaction,
    );
  }

  /// Updates all [SheetRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetRow>> update(
    _isd.DatabaseSession session,
    List<SheetRow> rows, {
    _isd.ColumnSelections<SheetRowTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SheetRow>(
      rows,
      columns: columns?.call(SheetRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SheetRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SheetRow> updateRow(
    _isd.DatabaseSession session,
    SheetRow row, {
    _isd.ColumnSelections<SheetRowTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SheetRow>(
      row,
      columns: columns?.call(SheetRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SheetRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SheetRow?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SheetRowUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SheetRow>(
      id,
      columnValues: columnValues(SheetRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SheetRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetRow>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SheetRowUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<SheetRowTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetRowTable>? orderBy,
    _isd.OrderByListBuilder<SheetRowTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SheetRow>(
      columnValues: columnValues(SheetRow.t.updateTable),
      where: where(SheetRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetRow.t),
      orderByList: orderByList?.call(SheetRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SheetRow]s in the list and returns the deleted rows.
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
  Future<List<SheetRow>> delete(
    _isd.DatabaseSession session,
    List<SheetRow> rows, {
    _isd.OrderByBuilder<SheetRowTable>? orderBy,
    _isd.OrderByListBuilder<SheetRowTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SheetRow>(
      rows,
      orderBy: orderBy?.call(SheetRow.t),
      orderByList: orderByList?.call(SheetRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SheetRow].
  Future<SheetRow> deleteRow(
    _isd.DatabaseSession session,
    SheetRow row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SheetRow>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetRow>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SheetRowTable> where,
    _isd.OrderByBuilder<SheetRowTable>? orderBy,
    _isd.OrderByListBuilder<SheetRowTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SheetRow>(
      where: where(SheetRow.t),
      orderBy: orderBy?.call(SheetRow.t),
      orderByList: orderByList?.call(SheetRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetRowTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SheetRow>(
      where: where?.call(SheetRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SheetRow] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SheetRowTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SheetRow>(
      where: where(SheetRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SheetRowAttachRowRepository {
  const SheetRowAttachRowRepository._();

  /// Creates a relation between the given [SheetRow] and [Sheet]
  /// by setting the [SheetRow]'s foreign key `sheetId` to refer to the [Sheet].
  Future<void> sheet(
    _isd.DatabaseSession session,
    SheetRow sheetRow,
    _i810rwvy.Sheet sheet, {
    _isd.Transaction? transaction,
  }) async {
    if (sheetRow.id == null) {
      throw ArgumentError.notNull('sheetRow.id');
    }
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }

    var $sheetRow = sheetRow.copyWith(sheetId: sheet.id);
    await session.db.updateRow<SheetRow>(
      $sheetRow,
      columns: [SheetRow.t.sheetId],
      transaction: transaction,
    );
  }
}
