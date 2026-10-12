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

/// A conditional formatting rule (Sheets 06 §15).
abstract class ConditionalFormatRule
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  ConditionalFormatRule._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.sheetId,
    this.sheet,
    required this.sortKey,
    required this.rangesJson,
    required this.ruleJson,
    bool? enabled,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       enabled = enabled ?? true,
       createdAt = createdAt ?? DateTime.now();

  factory ConditionalFormatRule({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String sortKey,
    required String rangesJson,
    required String ruleJson,
    bool? enabled,
    DateTime? createdAt,
  }) = _ConditionalFormatRuleImpl;

  factory ConditionalFormatRule.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ConditionalFormatRule(
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
      rangesJson: jsonSerialization['rangesJson'] as String,
      ruleJson: jsonSerialization['ruleJson'] as String,
      enabled: jsonSerialization['enabled'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['enabled']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = ConditionalFormatRuleTable();

  static const db = ConditionalFormatRuleRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue sheetId;

  _i810rwvy.Sheet? sheet;

  /// Priority, first = highest.
  String sortKey;

  /// List of GridRange.
  String rangesJson;

  String ruleJson;

  bool enabled;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [ConditionalFormatRule]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  ConditionalFormatRule copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedConditionalFormatRule$sheet(),
    String? sortKey,
    String? rangesJson,
    String? ruleJson,
    bool? enabled,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ConditionalFormatRule',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJson(),
      'sortKey': sortKey,
      'rangesJson': rangesJson,
      'ruleJson': ruleJson,
      'enabled': enabled,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ConditionalFormatRule',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJsonForProtocol(),
      'sortKey': sortKey,
      'rangesJson': rangesJson,
      'ruleJson': ruleJson,
      'enabled': enabled,
      'createdAt': createdAt.toJson(),
    };
  }

  static ConditionalFormatRuleInclude include({_i810rwvy.SheetInclude? sheet}) {
    return ConditionalFormatRuleInclude._(sheet: sheet);
  }

  static ConditionalFormatRuleIncludeList includeList({
    _isd.WhereExpressionBuilder<ConditionalFormatRuleTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ConditionalFormatRuleTable>? orderBy,
    _isd.OrderByListBuilder<ConditionalFormatRuleTable>? orderByList,
    ConditionalFormatRuleInclude? include,
  }) {
    return ConditionalFormatRuleIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ConditionalFormatRule.t),
      orderByList: orderByList?.call(ConditionalFormatRule.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedConditionalFormatRule$sheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Sheet {
  const _UndefinedConditionalFormatRule$sheet();
}

class _ConditionalFormatRuleImpl extends ConditionalFormatRule {
  _ConditionalFormatRuleImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String sortKey,
    required String rangesJson,
    required String ruleJson,
    bool? enabled,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         sheetId: sheetId,
         sheet: sheet,
         sortKey: sortKey,
         rangesJson: rangesJson,
         ruleJson: ruleJson,
         enabled: enabled,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ConditionalFormatRule]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  ConditionalFormatRule copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedConditionalFormatRule$sheet(),
    String? sortKey,
    String? rangesJson,
    String? ruleJson,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return ConditionalFormatRule(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      sheetId: sheetId ?? this.sheetId,
      sheet: sheet is _iss.UndefinedSentinel ? this.sheet?.copyWith() : sheet,
      sortKey: sortKey ?? this.sortKey,
      rangesJson: rangesJson ?? this.rangesJson,
      ruleJson: ruleJson ?? this.ruleJson,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ConditionalFormatRuleUpdateTable
    extends _isd.UpdateTable<ConditionalFormatRuleTable> {
  ConditionalFormatRuleUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> sheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<String, String> sortKey(String value) =>
      _isd.ColumnValue(table.sortKey, value);

  _isd.ColumnValue<String, String> rangesJson(String value) =>
      _isd.ColumnValue(table.rangesJson, value);

  _isd.ColumnValue<String, String> ruleJson(String value) =>
      _isd.ColumnValue(table.ruleJson, value);

  _isd.ColumnValue<bool, bool> enabled(bool value) =>
      _isd.ColumnValue(table.enabled, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class ConditionalFormatRuleTable extends _isd.Table<_iss.UuidValue> {
  ConditionalFormatRuleTable({super.tableRelation})
    : super(tableName: 'conditional_format_rule') {
    updateTable = ConditionalFormatRuleUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    sheetId = _isd.ColumnUuid('sheetId', this);
    sortKey = _isd.ColumnString('sortKey', this);
    rangesJson = _isd.ColumnString('rangesJson', this);
    ruleJson = _isd.ColumnString('ruleJson', this);
    enabled = _isd.ColumnBool('enabled', this, hasDefault: true);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final ConditionalFormatRuleUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid sheetId;

  _i810rwvy.SheetTable? _sheet;

  /// Priority, first = highest.
  late final _isd.ColumnString sortKey;

  /// List of GridRange.
  late final _isd.ColumnString rangesJson;

  late final _isd.ColumnString ruleJson;

  late final _isd.ColumnBool enabled;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SheetTable get sheet {
    if (_sheet != null) return _sheet!;
    _sheet = _isd.createRelationTable(
      relationFieldName: 'sheet',
      field: ConditionalFormatRule.t.sheetId,
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
    rangesJson,
    ruleJson,
    enabled,
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

class ConditionalFormatRuleInclude extends _isd.IncludeObject {
  ConditionalFormatRuleInclude._({_i810rwvy.SheetInclude? sheet}) {
    _sheet = sheet;
  }

  _i810rwvy.SheetInclude? _sheet;

  @override
  Map<String, _isd.Include?> get includes => {'sheet': _sheet};

  @override
  _isd.Table<_iss.UuidValue> get table => ConditionalFormatRule.t;
}

class ConditionalFormatRuleIncludeList extends _isd.IncludeList {
  ConditionalFormatRuleIncludeList._({
    _isd.WhereExpressionBuilder<ConditionalFormatRuleTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ConditionalFormatRule.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => ConditionalFormatRule.t;
}

class ConditionalFormatRuleRepository {
  const ConditionalFormatRuleRepository._();

  final attachRow = const ConditionalFormatRuleAttachRowRepository._();

  /// Returns a list of [ConditionalFormatRule]s matching the given query parameters.
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
  Future<List<ConditionalFormatRule>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ConditionalFormatRuleTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ConditionalFormatRuleTable>? orderBy,
    _isd.OrderByListBuilder<ConditionalFormatRuleTable>? orderByList,
    _isd.Transaction? transaction,
    ConditionalFormatRuleInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ConditionalFormatRule>(
      where: where?.call(ConditionalFormatRule.t),
      orderBy: orderBy?.call(ConditionalFormatRule.t),
      orderByList: orderByList?.call(ConditionalFormatRule.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ConditionalFormatRule]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ConditionalFormatRule.t`.
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
  _ida.Stream<List<ConditionalFormatRule>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ConditionalFormatRuleTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ConditionalFormatRuleTable>? orderBy,
    _isd.OrderByListBuilder<ConditionalFormatRuleTable>? orderByList,
    ConditionalFormatRuleInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ConditionalFormatRule>(
      where: where?.call(ConditionalFormatRule.t),
      orderBy: orderBy?.call(ConditionalFormatRule.t),
      orderByList: orderByList?.call(ConditionalFormatRule.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ConditionalFormatRule] matching the given query parameters.
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
  Future<ConditionalFormatRule?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ConditionalFormatRuleTable>? where,
    int? offset,
    _isd.OrderByBuilder<ConditionalFormatRuleTable>? orderBy,
    _isd.OrderByListBuilder<ConditionalFormatRuleTable>? orderByList,
    _isd.Transaction? transaction,
    ConditionalFormatRuleInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ConditionalFormatRule>(
      where: where?.call(ConditionalFormatRule.t),
      orderBy: orderBy?.call(ConditionalFormatRule.t),
      orderByList: orderByList?.call(ConditionalFormatRule.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ConditionalFormatRule] by its [id] or null if no such row exists.
  Future<ConditionalFormatRule?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    ConditionalFormatRuleInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ConditionalFormatRule>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ConditionalFormatRule]s in the list and returns the inserted rows.
  ///
  /// The returned [ConditionalFormatRule]s will have their `id` fields set.
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
  Future<List<ConditionalFormatRule>> insert(
    _isd.DatabaseSession session,
    List<ConditionalFormatRule> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ConditionalFormatRule>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ConditionalFormatRule] and returns the inserted row.
  ///
  /// The returned [ConditionalFormatRule] will have its `id` field set.
  Future<ConditionalFormatRule> insertRow(
    _isd.DatabaseSession session,
    ConditionalFormatRule row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<ConditionalFormatRule>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [ConditionalFormatRule]s in the list and returns the resulting rows.
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
  /// The returned [ConditionalFormatRule]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ConditionalFormatRule>> upsert(
    _isd.DatabaseSession session,
    List<ConditionalFormatRule> rows, {
    required _isd.ColumnSelections<ConditionalFormatRuleTable> conflictColumns,
    _isd.ColumnSelections<ConditionalFormatRuleTable>? updateColumns,
    _isd.WhereExpressionBuilder<ConditionalFormatRuleTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ConditionalFormatRule>(
      rows,
      conflictColumns: conflictColumns(ConditionalFormatRule.t),
      updateColumns: updateColumns?.call(ConditionalFormatRule.t),
      updateWhere: updateWhere?.call(ConditionalFormatRule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ConditionalFormatRule] and returns the resulting row.
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
  /// The returned [ConditionalFormatRule] will have its `id` field set.
  Future<ConditionalFormatRule?> upsertRow(
    _isd.DatabaseSession session,
    ConditionalFormatRule row, {
    required _isd.ColumnSelections<ConditionalFormatRuleTable> conflictColumns,
    _isd.ColumnSelections<ConditionalFormatRuleTable>? updateColumns,
    _isd.WhereExpressionBuilder<ConditionalFormatRuleTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ConditionalFormatRule>(
      row,
      conflictColumns: conflictColumns(ConditionalFormatRule.t),
      updateColumns: updateColumns?.call(ConditionalFormatRule.t),
      updateWhere: updateWhere?.call(ConditionalFormatRule.t),
      transaction: transaction,
    );
  }

  /// Updates all [ConditionalFormatRule]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ConditionalFormatRule>> update(
    _isd.DatabaseSession session,
    List<ConditionalFormatRule> rows, {
    _isd.ColumnSelections<ConditionalFormatRuleTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ConditionalFormatRule>(
      rows,
      columns: columns?.call(ConditionalFormatRule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ConditionalFormatRule]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ConditionalFormatRule> updateRow(
    _isd.DatabaseSession session,
    ConditionalFormatRule row, {
    _isd.ColumnSelections<ConditionalFormatRuleTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<ConditionalFormatRule>(
      row,
      columns: columns?.call(ConditionalFormatRule.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ConditionalFormatRule] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ConditionalFormatRule?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<ConditionalFormatRuleUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<ConditionalFormatRule>(
      id,
      columnValues: columnValues(ConditionalFormatRule.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ConditionalFormatRule]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ConditionalFormatRule>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<ConditionalFormatRuleUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<ConditionalFormatRuleTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ConditionalFormatRuleTable>? orderBy,
    _isd.OrderByListBuilder<ConditionalFormatRuleTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ConditionalFormatRule>(
      columnValues: columnValues(ConditionalFormatRule.t.updateTable),
      where: where(ConditionalFormatRule.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ConditionalFormatRule.t),
      orderByList: orderByList?.call(ConditionalFormatRule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ConditionalFormatRule]s in the list and returns the deleted rows.
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
  Future<List<ConditionalFormatRule>> delete(
    _isd.DatabaseSession session,
    List<ConditionalFormatRule> rows, {
    _isd.OrderByBuilder<ConditionalFormatRuleTable>? orderBy,
    _isd.OrderByListBuilder<ConditionalFormatRuleTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ConditionalFormatRule>(
      rows,
      orderBy: orderBy?.call(ConditionalFormatRule.t),
      orderByList: orderByList?.call(ConditionalFormatRule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ConditionalFormatRule].
  Future<ConditionalFormatRule> deleteRow(
    _isd.DatabaseSession session,
    ConditionalFormatRule row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ConditionalFormatRule>(
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
  Future<List<ConditionalFormatRule>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ConditionalFormatRuleTable> where,
    _isd.OrderByBuilder<ConditionalFormatRuleTable>? orderBy,
    _isd.OrderByListBuilder<ConditionalFormatRuleTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ConditionalFormatRule>(
      where: where(ConditionalFormatRule.t),
      orderBy: orderBy?.call(ConditionalFormatRule.t),
      orderByList: orderByList?.call(ConditionalFormatRule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ConditionalFormatRuleTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<ConditionalFormatRule>(
      where: where?.call(ConditionalFormatRule.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ConditionalFormatRule] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ConditionalFormatRuleTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ConditionalFormatRule>(
      where: where(ConditionalFormatRule.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class ConditionalFormatRuleAttachRowRepository {
  const ConditionalFormatRuleAttachRowRepository._();

  /// Creates a relation between the given [ConditionalFormatRule] and [Sheet]
  /// by setting the [ConditionalFormatRule]'s foreign key `sheetId` to refer to the [Sheet].
  Future<void> sheet(
    _isd.DatabaseSession session,
    ConditionalFormatRule conditionalFormatRule,
    _i810rwvy.Sheet sheet, {
    _isd.Transaction? transaction,
  }) async {
    if (conditionalFormatRule.id == null) {
      throw ArgumentError.notNull('conditionalFormatRule.id');
    }
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }

    var $conditionalFormatRule = conditionalFormatRule.copyWith(
      sheetId: sheet.id,
    );
    await session.db.updateRow<ConditionalFormatRule>(
      $conditionalFormatRule,
      columns: [ConditionalFormatRule.t.sheetId],
      transaction: transaction,
    );
  }
}
