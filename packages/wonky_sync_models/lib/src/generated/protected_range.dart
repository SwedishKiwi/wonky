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

/// Advisory protection of a range or a whole sheet.
abstract class ProtectedRange
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  ProtectedRange._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.sheetId,
    this.sheet,
    this.rangeJson,
    this.exceptRangesJson,
    this.description,
    bool? warningOnly,
    required this.editorsJson,
    required this.createdBy,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       warningOnly = warningOnly ?? false,
       createdAt = createdAt ?? DateTime.now();

  factory ProtectedRange({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    String? rangeJson,
    String? exceptRangesJson,
    String? description,
    bool? warningOnly,
    required String editorsJson,
    required _iss.UuidValue createdBy,
    DateTime? createdAt,
  }) = _ProtectedRangeImpl;

  factory ProtectedRange.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProtectedRange(
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
      rangeJson: jsonSerialization['rangeJson'] as String?,
      exceptRangesJson: jsonSerialization['exceptRangesJson'] as String?,
      description: jsonSerialization['description'] as String?,
      warningOnly: jsonSerialization['warningOnly'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['warningOnly']),
      editorsJson: jsonSerialization['editorsJson'] as String,
      createdBy: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['createdBy'],
      ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = ProtectedRangeTable();

  static const db = ProtectedRangeRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue sheetId;

  _i810rwvy.Sheet? sheet;

  /// Null = whole sheet.
  String? rangeJson;

  /// Unprotected ranges for sheet protection.
  String? exceptRangesJson;

  String? description;

  bool warningOnly;

  /// List of user UUIDs allowed to edit (owner always).
  String editorsJson;

  _iss.UuidValue createdBy;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [ProtectedRange]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  ProtectedRange copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedProtectedRange$sheet(),
    String? rangeJson,
    String? exceptRangesJson,
    String? description,
    bool? warningOnly,
    String? editorsJson,
    _iss.UuidValue? createdBy,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProtectedRange',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJson(),
      if (rangeJson != null) 'rangeJson': rangeJson,
      if (exceptRangesJson != null) 'exceptRangesJson': exceptRangesJson,
      if (description != null) 'description': description,
      'warningOnly': warningOnly,
      'editorsJson': editorsJson,
      'createdBy': createdBy.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ProtectedRange',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJsonForProtocol(),
      if (rangeJson != null) 'rangeJson': rangeJson,
      if (exceptRangesJson != null) 'exceptRangesJson': exceptRangesJson,
      if (description != null) 'description': description,
      'warningOnly': warningOnly,
      'editorsJson': editorsJson,
      'createdBy': createdBy.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static ProtectedRangeInclude include({_i810rwvy.SheetInclude? sheet}) {
    return ProtectedRangeInclude._(sheet: sheet);
  }

  static ProtectedRangeIncludeList includeList({
    _isd.WhereExpressionBuilder<ProtectedRangeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ProtectedRangeTable>? orderBy,
    _isd.OrderByListBuilder<ProtectedRangeTable>? orderByList,
    ProtectedRangeInclude? include,
  }) {
    return ProtectedRangeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ProtectedRange.t),
      orderByList: orderByList?.call(ProtectedRange.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedProtectedRange$sheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Sheet {
  const _UndefinedProtectedRange$sheet();
}

class _ProtectedRangeImpl extends ProtectedRange {
  _ProtectedRangeImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    String? rangeJson,
    String? exceptRangesJson,
    String? description,
    bool? warningOnly,
    required String editorsJson,
    required _iss.UuidValue createdBy,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         sheetId: sheetId,
         sheet: sheet,
         rangeJson: rangeJson,
         exceptRangesJson: exceptRangesJson,
         description: description,
         warningOnly: warningOnly,
         editorsJson: editorsJson,
         createdBy: createdBy,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ProtectedRange]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  ProtectedRange copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedProtectedRange$sheet(),
    Object? rangeJson = _Undefined,
    Object? exceptRangesJson = _Undefined,
    Object? description = _Undefined,
    bool? warningOnly,
    String? editorsJson,
    _iss.UuidValue? createdBy,
    DateTime? createdAt,
  }) {
    return ProtectedRange(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      sheetId: sheetId ?? this.sheetId,
      sheet: sheet is _iss.UndefinedSentinel ? this.sheet?.copyWith() : sheet,
      rangeJson: rangeJson is String? ? rangeJson : this.rangeJson,
      exceptRangesJson: exceptRangesJson is String?
          ? exceptRangesJson
          : this.exceptRangesJson,
      description: description is String? ? description : this.description,
      warningOnly: warningOnly ?? this.warningOnly,
      editorsJson: editorsJson ?? this.editorsJson,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ProtectedRangeUpdateTable extends _isd.UpdateTable<ProtectedRangeTable> {
  ProtectedRangeUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> sheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<String, String> rangeJson(String? value) =>
      _isd.ColumnValue(table.rangeJson, value);

  _isd.ColumnValue<String, String> exceptRangesJson(String? value) =>
      _isd.ColumnValue(table.exceptRangesJson, value);

  _isd.ColumnValue<String, String> description(String? value) =>
      _isd.ColumnValue(table.description, value);

  _isd.ColumnValue<bool, bool> warningOnly(bool value) =>
      _isd.ColumnValue(table.warningOnly, value);

  _isd.ColumnValue<String, String> editorsJson(String value) =>
      _isd.ColumnValue(table.editorsJson, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> createdBy(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.createdBy, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class ProtectedRangeTable extends _isd.Table<_iss.UuidValue> {
  ProtectedRangeTable({super.tableRelation})
    : super(tableName: 'protected_range') {
    updateTable = ProtectedRangeUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    sheetId = _isd.ColumnUuid('sheetId', this);
    rangeJson = _isd.ColumnString('rangeJson', this);
    exceptRangesJson = _isd.ColumnString('exceptRangesJson', this);
    description = _isd.ColumnString('description', this);
    warningOnly = _isd.ColumnBool('warningOnly', this, hasDefault: true);
    editorsJson = _isd.ColumnString('editorsJson', this);
    createdBy = _isd.ColumnUuid('createdBy', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final ProtectedRangeUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid sheetId;

  _i810rwvy.SheetTable? _sheet;

  /// Null = whole sheet.
  late final _isd.ColumnString rangeJson;

  /// Unprotected ranges for sheet protection.
  late final _isd.ColumnString exceptRangesJson;

  late final _isd.ColumnString description;

  late final _isd.ColumnBool warningOnly;

  /// List of user UUIDs allowed to edit (owner always).
  late final _isd.ColumnString editorsJson;

  late final _isd.ColumnUuid createdBy;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SheetTable get sheet {
    if (_sheet != null) return _sheet!;
    _sheet = _isd.createRelationTable(
      relationFieldName: 'sheet',
      field: ProtectedRange.t.sheetId,
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
    exceptRangesJson,
    description,
    warningOnly,
    editorsJson,
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

class ProtectedRangeInclude extends _isd.IncludeObject {
  ProtectedRangeInclude._({_i810rwvy.SheetInclude? sheet}) {
    _sheet = sheet;
  }

  _i810rwvy.SheetInclude? _sheet;

  @override
  Map<String, _isd.Include?> get includes => {'sheet': _sheet};

  @override
  _isd.Table<_iss.UuidValue> get table => ProtectedRange.t;
}

class ProtectedRangeIncludeList extends _isd.IncludeList {
  ProtectedRangeIncludeList._({
    _isd.WhereExpressionBuilder<ProtectedRangeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ProtectedRange.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => ProtectedRange.t;
}

class ProtectedRangeRepository {
  const ProtectedRangeRepository._();

  final attachRow = const ProtectedRangeAttachRowRepository._();

  /// Returns a list of [ProtectedRange]s matching the given query parameters.
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
  Future<List<ProtectedRange>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ProtectedRangeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ProtectedRangeTable>? orderBy,
    _isd.OrderByListBuilder<ProtectedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    ProtectedRangeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ProtectedRange>(
      where: where?.call(ProtectedRange.t),
      orderBy: orderBy?.call(ProtectedRange.t),
      orderByList: orderByList?.call(ProtectedRange.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ProtectedRange]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ProtectedRange.t`.
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
  _ida.Stream<List<ProtectedRange>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ProtectedRangeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ProtectedRangeTable>? orderBy,
    _isd.OrderByListBuilder<ProtectedRangeTable>? orderByList,
    ProtectedRangeInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ProtectedRange>(
      where: where?.call(ProtectedRange.t),
      orderBy: orderBy?.call(ProtectedRange.t),
      orderByList: orderByList?.call(ProtectedRange.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ProtectedRange] matching the given query parameters.
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
  Future<ProtectedRange?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ProtectedRangeTable>? where,
    int? offset,
    _isd.OrderByBuilder<ProtectedRangeTable>? orderBy,
    _isd.OrderByListBuilder<ProtectedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    ProtectedRangeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ProtectedRange>(
      where: where?.call(ProtectedRange.t),
      orderBy: orderBy?.call(ProtectedRange.t),
      orderByList: orderByList?.call(ProtectedRange.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ProtectedRange] by its [id] or null if no such row exists.
  Future<ProtectedRange?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    ProtectedRangeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ProtectedRange>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ProtectedRange]s in the list and returns the inserted rows.
  ///
  /// The returned [ProtectedRange]s will have their `id` fields set.
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
  Future<List<ProtectedRange>> insert(
    _isd.DatabaseSession session,
    List<ProtectedRange> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ProtectedRange>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ProtectedRange] and returns the inserted row.
  ///
  /// The returned [ProtectedRange] will have its `id` field set.
  Future<ProtectedRange> insertRow(
    _isd.DatabaseSession session,
    ProtectedRange row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<ProtectedRange>(row, transaction: transaction);
  }

  /// Upserts all [ProtectedRange]s in the list and returns the resulting rows.
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
  /// The returned [ProtectedRange]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ProtectedRange>> upsert(
    _isd.DatabaseSession session,
    List<ProtectedRange> rows, {
    required _isd.ColumnSelections<ProtectedRangeTable> conflictColumns,
    _isd.ColumnSelections<ProtectedRangeTable>? updateColumns,
    _isd.WhereExpressionBuilder<ProtectedRangeTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ProtectedRange>(
      rows,
      conflictColumns: conflictColumns(ProtectedRange.t),
      updateColumns: updateColumns?.call(ProtectedRange.t),
      updateWhere: updateWhere?.call(ProtectedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ProtectedRange] and returns the resulting row.
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
  /// The returned [ProtectedRange] will have its `id` field set.
  Future<ProtectedRange?> upsertRow(
    _isd.DatabaseSession session,
    ProtectedRange row, {
    required _isd.ColumnSelections<ProtectedRangeTable> conflictColumns,
    _isd.ColumnSelections<ProtectedRangeTable>? updateColumns,
    _isd.WhereExpressionBuilder<ProtectedRangeTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ProtectedRange>(
      row,
      conflictColumns: conflictColumns(ProtectedRange.t),
      updateColumns: updateColumns?.call(ProtectedRange.t),
      updateWhere: updateWhere?.call(ProtectedRange.t),
      transaction: transaction,
    );
  }

  /// Updates all [ProtectedRange]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ProtectedRange>> update(
    _isd.DatabaseSession session,
    List<ProtectedRange> rows, {
    _isd.ColumnSelections<ProtectedRangeTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ProtectedRange>(
      rows,
      columns: columns?.call(ProtectedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ProtectedRange]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ProtectedRange> updateRow(
    _isd.DatabaseSession session,
    ProtectedRange row, {
    _isd.ColumnSelections<ProtectedRangeTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<ProtectedRange>(
      row,
      columns: columns?.call(ProtectedRange.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ProtectedRange] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ProtectedRange?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<ProtectedRangeUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<ProtectedRange>(
      id,
      columnValues: columnValues(ProtectedRange.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ProtectedRange]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ProtectedRange>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<ProtectedRangeUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<ProtectedRangeTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ProtectedRangeTable>? orderBy,
    _isd.OrderByListBuilder<ProtectedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ProtectedRange>(
      columnValues: columnValues(ProtectedRange.t.updateTable),
      where: where(ProtectedRange.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ProtectedRange.t),
      orderByList: orderByList?.call(ProtectedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ProtectedRange]s in the list and returns the deleted rows.
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
  Future<List<ProtectedRange>> delete(
    _isd.DatabaseSession session,
    List<ProtectedRange> rows, {
    _isd.OrderByBuilder<ProtectedRangeTable>? orderBy,
    _isd.OrderByListBuilder<ProtectedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ProtectedRange>(
      rows,
      orderBy: orderBy?.call(ProtectedRange.t),
      orderByList: orderByList?.call(ProtectedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ProtectedRange].
  Future<ProtectedRange> deleteRow(
    _isd.DatabaseSession session,
    ProtectedRange row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ProtectedRange>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ProtectedRange>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ProtectedRangeTable> where,
    _isd.OrderByBuilder<ProtectedRangeTable>? orderBy,
    _isd.OrderByListBuilder<ProtectedRangeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ProtectedRange>(
      where: where(ProtectedRange.t),
      orderBy: orderBy?.call(ProtectedRange.t),
      orderByList: orderByList?.call(ProtectedRange.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ProtectedRangeTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<ProtectedRange>(
      where: where?.call(ProtectedRange.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ProtectedRange] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ProtectedRangeTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ProtectedRange>(
      where: where(ProtectedRange.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class ProtectedRangeAttachRowRepository {
  const ProtectedRangeAttachRowRepository._();

  /// Creates a relation between the given [ProtectedRange] and [Sheet]
  /// by setting the [ProtectedRange]'s foreign key `sheetId` to refer to the [Sheet].
  Future<void> sheet(
    _isd.DatabaseSession session,
    ProtectedRange protectedRange,
    _i810rwvy.Sheet sheet, {
    _isd.Transaction? transaction,
  }) async {
    if (protectedRange.id == null) {
      throw ArgumentError.notNull('protectedRange.id');
    }
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }

    var $protectedRange = protectedRange.copyWith(sheetId: sheet.id);
    await session.db.updateRow<ProtectedRange>(
      $protectedRange,
      columns: [ProtectedRange.t.sheetId],
      transaction: transaction,
    );
  }
}
