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

/// A named range, named formula or named function.
abstract class NamedRange
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  NamedRange._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.spreadsheetId,
    this.spreadsheet,
    required this.name,
    this.rangeJson,
    this.formula,
    this.comment,
    this.metaJson,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory NamedRange({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet,
    required String name,
    String? rangeJson,
    String? formula,
    String? comment,
    String? metaJson,
    DateTime? createdAt,
  }) = _NamedRangeImpl;

  factory NamedRange.fromJson(Map<String, dynamic> jsonSerialization) {
    return NamedRange(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      spreadsheetId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['spreadsheetId'],
      ),
      spreadsheet: jsonSerialization['spreadsheet'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.Spreadsheet>(
              jsonSerialization['spreadsheet'],
            ),
      name: jsonSerialization['name'] as String,
      rangeJson: jsonSerialization['rangeJson'] as String?,
      formula: jsonSerialization['formula'] as String?,
      comment: jsonSerialization['comment'] as String?,
      metaJson: jsonSerialization['metaJson'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = NamedRangeTable();

  static const db = NamedRangeRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue spreadsheetId;

  _i810rwvy.Spreadsheet? spreadsheet;

  /// Case-insensitive unique (client-enforced).
  String name;

  /// GridRange, or null when formula is used.
  String? rangeJson;

  /// Named formula / LAMBDA in stored-reference form.
  String? formula;

  String? comment;

  /// {kind, description, params, examples} (Sheets 05 §24 F3).
  String? metaJson;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [NamedRange]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  NamedRange copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet =
        const _UndefinedNamedRange$spreadsheet(),
    String? name,
    String? rangeJson,
    String? formula,
    String? comment,
    String? metaJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'NamedRange',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'spreadsheetId': spreadsheetId.toJson(),
      if (spreadsheet != null) 'spreadsheet': spreadsheet?.toJson(),
      'name': name,
      if (rangeJson != null) 'rangeJson': rangeJson,
      if (formula != null) 'formula': formula,
      if (comment != null) 'comment': comment,
      if (metaJson != null) 'metaJson': metaJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'NamedRange',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'spreadsheetId': spreadsheetId.toJson(),
      if (spreadsheet != null) 'spreadsheet': spreadsheet?.toJsonForProtocol(),
      'name': name,
      if (rangeJson != null) 'rangeJson': rangeJson,
      if (formula != null) 'formula': formula,
      if (comment != null) 'comment': comment,
      if (metaJson != null) 'metaJson': metaJson,
      'createdAt': createdAt.toJson(),
    };
  }

  static NamedRangeInclude include({
    _i810rwvy.SpreadsheetInclude? spreadsheet,
  }) {
    return NamedRangeInclude._(spreadsheet: spreadsheet);
  }

  static NamedRangeIncludeList includeList({
    _isd.WhereExpressionBuilder<NamedRangeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<NamedRangeTable>? orderBy,
    _isd.OrderByListBuilder<NamedRangeTable>? orderByList,
    NamedRangeInclude? include,
  }) {
    return NamedRangeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(NamedRange.t),
      orderByList: orderByList?.call(NamedRange.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedNamedRange$spreadsheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Spreadsheet {
  const _UndefinedNamedRange$spreadsheet();
}

class _NamedRangeImpl extends NamedRange {
  _NamedRangeImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet,
    required String name,
    String? rangeJson,
    String? formula,
    String? comment,
    String? metaJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         spreadsheetId: spreadsheetId,
         spreadsheet: spreadsheet,
         name: name,
         rangeJson: rangeJson,
         formula: formula,
         comment: comment,
         metaJson: metaJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [NamedRange]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  NamedRange copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet =
        const _UndefinedNamedRange$spreadsheet(),
    String? name,
    Object? rangeJson = _Undefined,
    Object? formula = _Undefined,
    Object? comment = _Undefined,
    Object? metaJson = _Undefined,
    DateTime? createdAt,
  }) {
    return NamedRange(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      spreadsheet: spreadsheet is _iss.UndefinedSentinel
          ? this.spreadsheet?.copyWith()
          : spreadsheet,
      name: name ?? this.name,
      rangeJson: rangeJson is String? ? rangeJson : this.rangeJson,
      formula: formula is String? ? formula : this.formula,
      comment: comment is String? ? comment : this.comment,
      metaJson: metaJson is String? ? metaJson : this.metaJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NamedRangeUpdateTable extends _isd.UpdateTable<NamedRangeTable> {
  NamedRangeUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> spreadsheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.spreadsheetId, value);

  _isd.ColumnValue<String, String> name(String value) =>
      _isd.ColumnValue(table.name, value);

  _isd.ColumnValue<String, String> rangeJson(String? value) =>
      _isd.ColumnValue(table.rangeJson, value);

  _isd.ColumnValue<String, String> formula(String? value) =>
      _isd.ColumnValue(table.formula, value);

  _isd.ColumnValue<String, String> comment(String? value) =>
      _isd.ColumnValue(table.comment, value);

  _isd.ColumnValue<String, String> metaJson(String? value) =>
      _isd.ColumnValue(table.metaJson, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class NamedRangeTable extends _isd.Table<_iss.UuidValue> {
  NamedRangeTable({super.tableRelation}) : super(tableName: 'named_range') {
    updateTable = NamedRangeUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    spreadsheetId = _isd.ColumnUuid('spreadsheetId', this);
    name = _isd.ColumnString('name', this);
    rangeJson = _isd.ColumnString('rangeJson', this);
    formula = _isd.ColumnString('formula', this);
    comment = _isd.ColumnString('comment', this);
    metaJson = _isd.ColumnString('metaJson', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final NamedRangeUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid spreadsheetId;

  _i810rwvy.SpreadsheetTable? _spreadsheet;

  /// Case-insensitive unique (client-enforced).
  late final _isd.ColumnString name;

  /// GridRange, or null when formula is used.
  late final _isd.ColumnString rangeJson;

  /// Named formula / LAMBDA in stored-reference form.
  late final _isd.ColumnString formula;

  late final _isd.ColumnString comment;

  /// {kind, description, params, examples} (Sheets 05 §24 F3).
  late final _isd.ColumnString metaJson;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SpreadsheetTable get spreadsheet {
    if (_spreadsheet != null) return _spreadsheet!;
    _spreadsheet = _isd.createRelationTable(
      relationFieldName: 'spreadsheet',
      field: NamedRange.t.spreadsheetId,
      foreignField: _i810rwvy.Spreadsheet.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SpreadsheetTable(tableRelation: foreignTableRelation),
    );
    return _spreadsheet!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    spreadsheetId,
    name,
    rangeJson,
    formula,
    comment,
    metaJson,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'spreadsheet') {
      return spreadsheet;
    }
    return null;
  }
}

class NamedRangeInclude extends _isd.IncludeObject {
  NamedRangeInclude._({_i810rwvy.SpreadsheetInclude? spreadsheet}) {
    _spreadsheet = spreadsheet;
  }

  _i810rwvy.SpreadsheetInclude? _spreadsheet;

  @override
  Map<String, _isd.Include?> get includes => {'spreadsheet': _spreadsheet};

  @override
  _isd.Table<_iss.UuidValue> get table => NamedRange.t;
}

class NamedRangeIncludeList extends _isd.IncludeList {
  NamedRangeIncludeList._({
    _isd.WhereExpressionBuilder<NamedRangeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(NamedRange.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => NamedRange.t;
}

class NamedRangeRepository {
  const NamedRangeRepository._();

  final attachRow = const NamedRangeAttachRowRepository._();

  /// Returns a list of [NamedRange]s matching the given query parameters.
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
  Future<List<NamedRange>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<NamedRangeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<NamedRangeTable>? orderBy,
    _isd.OrderByListBuilder<NamedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    NamedRangeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<NamedRange>(
      where: where?.call(NamedRange.t),
      orderBy: orderBy?.call(NamedRange.t),
      orderByList: orderByList?.call(NamedRange.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [NamedRange]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `NamedRange.t`.
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
  _ida.Stream<List<NamedRange>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<NamedRangeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<NamedRangeTable>? orderBy,
    _isd.OrderByListBuilder<NamedRangeTable>? orderByList,
    NamedRangeInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<NamedRange>(
      where: where?.call(NamedRange.t),
      orderBy: orderBy?.call(NamedRange.t),
      orderByList: orderByList?.call(NamedRange.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [NamedRange] matching the given query parameters.
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
  Future<NamedRange?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<NamedRangeTable>? where,
    int? offset,
    _isd.OrderByBuilder<NamedRangeTable>? orderBy,
    _isd.OrderByListBuilder<NamedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    NamedRangeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<NamedRange>(
      where: where?.call(NamedRange.t),
      orderBy: orderBy?.call(NamedRange.t),
      orderByList: orderByList?.call(NamedRange.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [NamedRange] by its [id] or null if no such row exists.
  Future<NamedRange?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    NamedRangeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<NamedRange>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [NamedRange]s in the list and returns the inserted rows.
  ///
  /// The returned [NamedRange]s will have their `id` fields set.
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
  Future<List<NamedRange>> insert(
    _isd.DatabaseSession session,
    List<NamedRange> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<NamedRange>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [NamedRange] and returns the inserted row.
  ///
  /// The returned [NamedRange] will have its `id` field set.
  Future<NamedRange> insertRow(
    _isd.DatabaseSession session,
    NamedRange row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<NamedRange>(row, transaction: transaction);
  }

  /// Upserts all [NamedRange]s in the list and returns the resulting rows.
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
  /// The returned [NamedRange]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<NamedRange>> upsert(
    _isd.DatabaseSession session,
    List<NamedRange> rows, {
    required _isd.ColumnSelections<NamedRangeTable> conflictColumns,
    _isd.ColumnSelections<NamedRangeTable>? updateColumns,
    _isd.WhereExpressionBuilder<NamedRangeTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<NamedRange>(
      rows,
      conflictColumns: conflictColumns(NamedRange.t),
      updateColumns: updateColumns?.call(NamedRange.t),
      updateWhere: updateWhere?.call(NamedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [NamedRange] and returns the resulting row.
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
  /// The returned [NamedRange] will have its `id` field set.
  Future<NamedRange?> upsertRow(
    _isd.DatabaseSession session,
    NamedRange row, {
    required _isd.ColumnSelections<NamedRangeTable> conflictColumns,
    _isd.ColumnSelections<NamedRangeTable>? updateColumns,
    _isd.WhereExpressionBuilder<NamedRangeTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<NamedRange>(
      row,
      conflictColumns: conflictColumns(NamedRange.t),
      updateColumns: updateColumns?.call(NamedRange.t),
      updateWhere: updateWhere?.call(NamedRange.t),
      transaction: transaction,
    );
  }

  /// Updates all [NamedRange]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<NamedRange>> update(
    _isd.DatabaseSession session,
    List<NamedRange> rows, {
    _isd.ColumnSelections<NamedRangeTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<NamedRange>(
      rows,
      columns: columns?.call(NamedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [NamedRange]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<NamedRange> updateRow(
    _isd.DatabaseSession session,
    NamedRange row, {
    _isd.ColumnSelections<NamedRangeTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<NamedRange>(
      row,
      columns: columns?.call(NamedRange.t),
      transaction: transaction,
    );
  }

  /// Updates a single [NamedRange] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<NamedRange?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<NamedRangeUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<NamedRange>(
      id,
      columnValues: columnValues(NamedRange.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [NamedRange]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<NamedRange>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<NamedRangeUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<NamedRangeTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<NamedRangeTable>? orderBy,
    _isd.OrderByListBuilder<NamedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<NamedRange>(
      columnValues: columnValues(NamedRange.t.updateTable),
      where: where(NamedRange.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(NamedRange.t),
      orderByList: orderByList?.call(NamedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [NamedRange]s in the list and returns the deleted rows.
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
  Future<List<NamedRange>> delete(
    _isd.DatabaseSession session,
    List<NamedRange> rows, {
    _isd.OrderByBuilder<NamedRangeTable>? orderBy,
    _isd.OrderByListBuilder<NamedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<NamedRange>(
      rows,
      orderBy: orderBy?.call(NamedRange.t),
      orderByList: orderByList?.call(NamedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [NamedRange].
  Future<NamedRange> deleteRow(
    _isd.DatabaseSession session,
    NamedRange row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<NamedRange>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<NamedRange>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<NamedRangeTable> where,
    _isd.OrderByBuilder<NamedRangeTable>? orderBy,
    _isd.OrderByListBuilder<NamedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<NamedRange>(
      where: where(NamedRange.t),
      orderBy: orderBy?.call(NamedRange.t),
      orderByList: orderByList?.call(NamedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<NamedRangeTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<NamedRange>(
      where: where?.call(NamedRange.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [NamedRange] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<NamedRangeTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<NamedRange>(
      where: where(NamedRange.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class NamedRangeAttachRowRepository {
  const NamedRangeAttachRowRepository._();

  /// Creates a relation between the given [NamedRange] and [Spreadsheet]
  /// by setting the [NamedRange]'s foreign key `spreadsheetId` to refer to the [Spreadsheet].
  Future<void> spreadsheet(
    _isd.DatabaseSession session,
    NamedRange namedRange,
    _i810rwvy.Spreadsheet spreadsheet, {
    _isd.Transaction? transaction,
  }) async {
    if (namedRange.id == null) {
      throw ArgumentError.notNull('namedRange.id');
    }
    if (spreadsheet.id == null) {
      throw ArgumentError.notNull('spreadsheet.id');
    }

    var $namedRange = namedRange.copyWith(spreadsheetId: spreadsheet.id);
    await session.db.updateRow<NamedRange>(
      $namedRange,
      columns: [NamedRange.t.spreadsheetId],
      transaction: transaction,
    );
  }
}
