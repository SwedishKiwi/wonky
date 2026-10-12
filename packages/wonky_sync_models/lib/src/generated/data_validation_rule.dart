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

/// A data validation rule (Sheets 07 §6).
abstract class DataValidationRule
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  DataValidationRule._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.sheetId,
    this.sheet,
    required this.rangesJson,
    required this.criteriaJson,
    bool? strict,
    bool? showDropdown,
    this.displayStyle,
    this.helpText,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       strict = strict ?? false,
       showDropdown = showDropdown ?? true,
       createdAt = createdAt ?? DateTime.now();

  factory DataValidationRule({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String rangesJson,
    required String criteriaJson,
    bool? strict,
    bool? showDropdown,
    String? displayStyle,
    String? helpText,
    DateTime? createdAt,
  }) = _DataValidationRuleImpl;

  factory DataValidationRule.fromJson(Map<String, dynamic> jsonSerialization) {
    return DataValidationRule(
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
      rangesJson: jsonSerialization['rangesJson'] as String,
      criteriaJson: jsonSerialization['criteriaJson'] as String,
      strict: jsonSerialization['strict'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['strict']),
      showDropdown: jsonSerialization['showDropdown'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['showDropdown']),
      displayStyle: jsonSerialization['displayStyle'] as String?,
      helpText: jsonSerialization['helpText'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = DataValidationRuleTable();

  static const db = DataValidationRuleRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue sheetId;

  _i810rwvy.Sheet? sheet;

  String rangesJson;

  String criteriaJson;

  /// Reject invalid input instead of warning.
  bool strict;

  bool showDropdown;

  /// chip, arrow or plainText.
  String? displayStyle;

  String? helpText;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [DataValidationRule]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  DataValidationRule copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedDataValidationRule$sheet(),
    String? rangesJson,
    String? criteriaJson,
    bool? strict,
    bool? showDropdown,
    String? displayStyle,
    String? helpText,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DataValidationRule',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJson(),
      'rangesJson': rangesJson,
      'criteriaJson': criteriaJson,
      'strict': strict,
      'showDropdown': showDropdown,
      if (displayStyle != null) 'displayStyle': displayStyle,
      if (helpText != null) 'helpText': helpText,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DataValidationRule',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJsonForProtocol(),
      'rangesJson': rangesJson,
      'criteriaJson': criteriaJson,
      'strict': strict,
      'showDropdown': showDropdown,
      if (displayStyle != null) 'displayStyle': displayStyle,
      if (helpText != null) 'helpText': helpText,
      'createdAt': createdAt.toJson(),
    };
  }

  static DataValidationRuleInclude include({_i810rwvy.SheetInclude? sheet}) {
    return DataValidationRuleInclude._(sheet: sheet);
  }

  static DataValidationRuleIncludeList includeList({
    _isd.WhereExpressionBuilder<DataValidationRuleTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DataValidationRuleTable>? orderBy,
    _isd.OrderByListBuilder<DataValidationRuleTable>? orderByList,
    DataValidationRuleInclude? include,
  }) {
    return DataValidationRuleIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DataValidationRule.t),
      orderByList: orderByList?.call(DataValidationRule.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedDataValidationRule$sheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Sheet {
  const _UndefinedDataValidationRule$sheet();
}

class _DataValidationRuleImpl extends DataValidationRule {
  _DataValidationRuleImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required String rangesJson,
    required String criteriaJson,
    bool? strict,
    bool? showDropdown,
    String? displayStyle,
    String? helpText,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         sheetId: sheetId,
         sheet: sheet,
         rangesJson: rangesJson,
         criteriaJson: criteriaJson,
         strict: strict,
         showDropdown: showDropdown,
         displayStyle: displayStyle,
         helpText: helpText,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DataValidationRule]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  DataValidationRule copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedDataValidationRule$sheet(),
    String? rangesJson,
    String? criteriaJson,
    bool? strict,
    bool? showDropdown,
    Object? displayStyle = _Undefined,
    Object? helpText = _Undefined,
    DateTime? createdAt,
  }) {
    return DataValidationRule(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      sheetId: sheetId ?? this.sheetId,
      sheet: sheet is _iss.UndefinedSentinel ? this.sheet?.copyWith() : sheet,
      rangesJson: rangesJson ?? this.rangesJson,
      criteriaJson: criteriaJson ?? this.criteriaJson,
      strict: strict ?? this.strict,
      showDropdown: showDropdown ?? this.showDropdown,
      displayStyle: displayStyle is String? ? displayStyle : this.displayStyle,
      helpText: helpText is String? ? helpText : this.helpText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DataValidationRuleUpdateTable
    extends _isd.UpdateTable<DataValidationRuleTable> {
  DataValidationRuleUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> sheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<String, String> rangesJson(String value) =>
      _isd.ColumnValue(table.rangesJson, value);

  _isd.ColumnValue<String, String> criteriaJson(String value) =>
      _isd.ColumnValue(table.criteriaJson, value);

  _isd.ColumnValue<bool, bool> strict(bool value) =>
      _isd.ColumnValue(table.strict, value);

  _isd.ColumnValue<bool, bool> showDropdown(bool value) =>
      _isd.ColumnValue(table.showDropdown, value);

  _isd.ColumnValue<String, String> displayStyle(String? value) =>
      _isd.ColumnValue(table.displayStyle, value);

  _isd.ColumnValue<String, String> helpText(String? value) =>
      _isd.ColumnValue(table.helpText, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class DataValidationRuleTable extends _isd.Table<_iss.UuidValue> {
  DataValidationRuleTable({super.tableRelation})
    : super(tableName: 'data_validation_rule') {
    updateTable = DataValidationRuleUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    sheetId = _isd.ColumnUuid('sheetId', this);
    rangesJson = _isd.ColumnString('rangesJson', this);
    criteriaJson = _isd.ColumnString('criteriaJson', this);
    strict = _isd.ColumnBool('strict', this, hasDefault: true);
    showDropdown = _isd.ColumnBool('showDropdown', this, hasDefault: true);
    displayStyle = _isd.ColumnString('displayStyle', this);
    helpText = _isd.ColumnString('helpText', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final DataValidationRuleUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid sheetId;

  _i810rwvy.SheetTable? _sheet;

  late final _isd.ColumnString rangesJson;

  late final _isd.ColumnString criteriaJson;

  /// Reject invalid input instead of warning.
  late final _isd.ColumnBool strict;

  late final _isd.ColumnBool showDropdown;

  /// chip, arrow or plainText.
  late final _isd.ColumnString displayStyle;

  late final _isd.ColumnString helpText;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SheetTable get sheet {
    if (_sheet != null) return _sheet!;
    _sheet = _isd.createRelationTable(
      relationFieldName: 'sheet',
      field: DataValidationRule.t.sheetId,
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
    rangesJson,
    criteriaJson,
    strict,
    showDropdown,
    displayStyle,
    helpText,
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

class DataValidationRuleInclude extends _isd.IncludeObject {
  DataValidationRuleInclude._({_i810rwvy.SheetInclude? sheet}) {
    _sheet = sheet;
  }

  _i810rwvy.SheetInclude? _sheet;

  @override
  Map<String, _isd.Include?> get includes => {'sheet': _sheet};

  @override
  _isd.Table<_iss.UuidValue> get table => DataValidationRule.t;
}

class DataValidationRuleIncludeList extends _isd.IncludeList {
  DataValidationRuleIncludeList._({
    _isd.WhereExpressionBuilder<DataValidationRuleTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DataValidationRule.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => DataValidationRule.t;
}

class DataValidationRuleRepository {
  const DataValidationRuleRepository._();

  final attachRow = const DataValidationRuleAttachRowRepository._();

  /// Returns a list of [DataValidationRule]s matching the given query parameters.
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
  Future<List<DataValidationRule>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DataValidationRuleTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DataValidationRuleTable>? orderBy,
    _isd.OrderByListBuilder<DataValidationRuleTable>? orderByList,
    _isd.Transaction? transaction,
    DataValidationRuleInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DataValidationRule>(
      where: where?.call(DataValidationRule.t),
      orderBy: orderBy?.call(DataValidationRule.t),
      orderByList: orderByList?.call(DataValidationRule.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [DataValidationRule]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `DataValidationRule.t`.
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
  _ida.Stream<List<DataValidationRule>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DataValidationRuleTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DataValidationRuleTable>? orderBy,
    _isd.OrderByListBuilder<DataValidationRuleTable>? orderByList,
    DataValidationRuleInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<DataValidationRule>(
      where: where?.call(DataValidationRule.t),
      orderBy: orderBy?.call(DataValidationRule.t),
      orderByList: orderByList?.call(DataValidationRule.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [DataValidationRule] matching the given query parameters.
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
  Future<DataValidationRule?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DataValidationRuleTable>? where,
    int? offset,
    _isd.OrderByBuilder<DataValidationRuleTable>? orderBy,
    _isd.OrderByListBuilder<DataValidationRuleTable>? orderByList,
    _isd.Transaction? transaction,
    DataValidationRuleInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DataValidationRule>(
      where: where?.call(DataValidationRule.t),
      orderBy: orderBy?.call(DataValidationRule.t),
      orderByList: orderByList?.call(DataValidationRule.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DataValidationRule] by its [id] or null if no such row exists.
  Future<DataValidationRule?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    DataValidationRuleInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DataValidationRule>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DataValidationRule]s in the list and returns the inserted rows.
  ///
  /// The returned [DataValidationRule]s will have their `id` fields set.
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
  Future<List<DataValidationRule>> insert(
    _isd.DatabaseSession session,
    List<DataValidationRule> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DataValidationRule>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DataValidationRule] and returns the inserted row.
  ///
  /// The returned [DataValidationRule] will have its `id` field set.
  Future<DataValidationRule> insertRow(
    _isd.DatabaseSession session,
    DataValidationRule row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<DataValidationRule>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [DataValidationRule]s in the list and returns the resulting rows.
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
  /// The returned [DataValidationRule]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DataValidationRule>> upsert(
    _isd.DatabaseSession session,
    List<DataValidationRule> rows, {
    required _isd.ColumnSelections<DataValidationRuleTable> conflictColumns,
    _isd.ColumnSelections<DataValidationRuleTable>? updateColumns,
    _isd.WhereExpressionBuilder<DataValidationRuleTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DataValidationRule>(
      rows,
      conflictColumns: conflictColumns(DataValidationRule.t),
      updateColumns: updateColumns?.call(DataValidationRule.t),
      updateWhere: updateWhere?.call(DataValidationRule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DataValidationRule] and returns the resulting row.
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
  /// The returned [DataValidationRule] will have its `id` field set.
  Future<DataValidationRule?> upsertRow(
    _isd.DatabaseSession session,
    DataValidationRule row, {
    required _isd.ColumnSelections<DataValidationRuleTable> conflictColumns,
    _isd.ColumnSelections<DataValidationRuleTable>? updateColumns,
    _isd.WhereExpressionBuilder<DataValidationRuleTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DataValidationRule>(
      row,
      conflictColumns: conflictColumns(DataValidationRule.t),
      updateColumns: updateColumns?.call(DataValidationRule.t),
      updateWhere: updateWhere?.call(DataValidationRule.t),
      transaction: transaction,
    );
  }

  /// Updates all [DataValidationRule]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DataValidationRule>> update(
    _isd.DatabaseSession session,
    List<DataValidationRule> rows, {
    _isd.ColumnSelections<DataValidationRuleTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DataValidationRule>(
      rows,
      columns: columns?.call(DataValidationRule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DataValidationRule]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DataValidationRule> updateRow(
    _isd.DatabaseSession session,
    DataValidationRule row, {
    _isd.ColumnSelections<DataValidationRuleTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<DataValidationRule>(
      row,
      columns: columns?.call(DataValidationRule.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DataValidationRule] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DataValidationRule?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<DataValidationRuleUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<DataValidationRule>(
      id,
      columnValues: columnValues(DataValidationRule.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DataValidationRule]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DataValidationRule>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<DataValidationRuleUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<DataValidationRuleTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DataValidationRuleTable>? orderBy,
    _isd.OrderByListBuilder<DataValidationRuleTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DataValidationRule>(
      columnValues: columnValues(DataValidationRule.t.updateTable),
      where: where(DataValidationRule.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DataValidationRule.t),
      orderByList: orderByList?.call(DataValidationRule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DataValidationRule]s in the list and returns the deleted rows.
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
  Future<List<DataValidationRule>> delete(
    _isd.DatabaseSession session,
    List<DataValidationRule> rows, {
    _isd.OrderByBuilder<DataValidationRuleTable>? orderBy,
    _isd.OrderByListBuilder<DataValidationRuleTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DataValidationRule>(
      rows,
      orderBy: orderBy?.call(DataValidationRule.t),
      orderByList: orderByList?.call(DataValidationRule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DataValidationRule].
  Future<DataValidationRule> deleteRow(
    _isd.DatabaseSession session,
    DataValidationRule row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DataValidationRule>(
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
  Future<List<DataValidationRule>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<DataValidationRuleTable> where,
    _isd.OrderByBuilder<DataValidationRuleTable>? orderBy,
    _isd.OrderByListBuilder<DataValidationRuleTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DataValidationRule>(
      where: where(DataValidationRule.t),
      orderBy: orderBy?.call(DataValidationRule.t),
      orderByList: orderByList?.call(DataValidationRule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DataValidationRuleTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<DataValidationRule>(
      where: where?.call(DataValidationRule.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DataValidationRule] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<DataValidationRuleTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DataValidationRule>(
      where: where(DataValidationRule.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class DataValidationRuleAttachRowRepository {
  const DataValidationRuleAttachRowRepository._();

  /// Creates a relation between the given [DataValidationRule] and [Sheet]
  /// by setting the [DataValidationRule]'s foreign key `sheetId` to refer to the [Sheet].
  Future<void> sheet(
    _isd.DatabaseSession session,
    DataValidationRule dataValidationRule,
    _i810rwvy.Sheet sheet, {
    _isd.Transaction? transaction,
  }) async {
    if (dataValidationRule.id == null) {
      throw ArgumentError.notNull('dataValidationRule.id');
    }
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }

    var $dataValidationRule = dataValidationRule.copyWith(sheetId: sheet.id);
    await session.db.updateRow<DataValidationRule>(
      $dataValidationRule,
      columns: [DataValidationRule.t.sheetId],
      transaction: transaction,
    );
  }
}
