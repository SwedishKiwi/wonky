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

/// One row per undo transaction, written in the same transaction as the
/// change (Sheets 02 §3.7). Consumed by the server after onMergeSuccess.
abstract class ChangeLog
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  ChangeLog._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.spreadsheetId,
    this.spreadsheet,
    required this.userId,
    required this.actorKind,
    required this.sessionId,
    required this.label,
    required this.summaryJson,
    this.detailJson,
    required this.at,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory ChangeLog({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet,
    required _iss.UuidValue userId,
    required _i810rwvy.ActorKind actorKind,
    required String sessionId,
    required String label,
    required String summaryJson,
    String? detailJson,
    required DateTime at,
    DateTime? createdAt,
  }) = _ChangeLogImpl;

  factory ChangeLog.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChangeLog(
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
      userId: _iss.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      actorKind: _i810rwvy.ActorKind.fromJson(
        (jsonSerialization['actorKind'] as String),
      ),
      sessionId: jsonSerialization['sessionId'] as String,
      label: jsonSerialization['label'] as String,
      summaryJson: jsonSerialization['summaryJson'] as String,
      detailJson: jsonSerialization['detailJson'] as String?,
      at: _iss.DateTimeJsonExtension.fromJson(jsonSerialization['at']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = ChangeLogTable();

  static const db = ChangeLogRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue spreadsheetId;

  _i810rwvy.Spreadsheet? spreadsheet;

  /// Auth user UUID of the author.
  _iss.UuidValue userId;

  _i810rwvy.ActorKind actorKind;

  String sessionId;

  /// Undo label, e.g. "Paste".
  String label;

  /// {sheets, ranges, kinds, deleted, revived, structureOverflow}.
  String summaryJson;

  /// Before/after content for at most 200 cells; null if larger.
  String? detailJson;

  DateTime at;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [ChangeLog]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  ChangeLog copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet =
        const _UndefinedChangeLog$spreadsheet(),
    _iss.UuidValue? userId,
    _i810rwvy.ActorKind? actorKind,
    String? sessionId,
    String? label,
    String? summaryJson,
    String? detailJson,
    DateTime? at,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChangeLog',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'spreadsheetId': spreadsheetId.toJson(),
      if (spreadsheet != null) 'spreadsheet': spreadsheet?.toJson(),
      'userId': userId.toJson(),
      'actorKind': actorKind.toJson(),
      'sessionId': sessionId,
      'label': label,
      'summaryJson': summaryJson,
      if (detailJson != null) 'detailJson': detailJson,
      'at': at.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChangeLog',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'spreadsheetId': spreadsheetId.toJson(),
      if (spreadsheet != null) 'spreadsheet': spreadsheet?.toJsonForProtocol(),
      'userId': userId.toJson(),
      'actorKind': actorKind.toJson(),
      'sessionId': sessionId,
      'label': label,
      'summaryJson': summaryJson,
      if (detailJson != null) 'detailJson': detailJson,
      'at': at.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static ChangeLogInclude include({_i810rwvy.SpreadsheetInclude? spreadsheet}) {
    return ChangeLogInclude._(spreadsheet: spreadsheet);
  }

  static ChangeLogIncludeList includeList({
    _isd.WhereExpressionBuilder<ChangeLogTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<ChangeLogTable>? orderByList,
    ChangeLogInclude? include,
  }) {
    return ChangeLogIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChangeLog.t),
      orderByList: orderByList?.call(ChangeLog.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedChangeLog$spreadsheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Spreadsheet {
  const _UndefinedChangeLog$spreadsheet();
}

class _ChangeLogImpl extends ChangeLog {
  _ChangeLogImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet,
    required _iss.UuidValue userId,
    required _i810rwvy.ActorKind actorKind,
    required String sessionId,
    required String label,
    required String summaryJson,
    String? detailJson,
    required DateTime at,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         spreadsheetId: spreadsheetId,
         spreadsheet: spreadsheet,
         userId: userId,
         actorKind: actorKind,
         sessionId: sessionId,
         label: label,
         summaryJson: summaryJson,
         detailJson: detailJson,
         at: at,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ChangeLog]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  ChangeLog copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet =
        const _UndefinedChangeLog$spreadsheet(),
    _iss.UuidValue? userId,
    _i810rwvy.ActorKind? actorKind,
    String? sessionId,
    String? label,
    String? summaryJson,
    Object? detailJson = _Undefined,
    DateTime? at,
    DateTime? createdAt,
  }) {
    return ChangeLog(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      spreadsheet: spreadsheet is _iss.UndefinedSentinel
          ? this.spreadsheet?.copyWith()
          : spreadsheet,
      userId: userId ?? this.userId,
      actorKind: actorKind ?? this.actorKind,
      sessionId: sessionId ?? this.sessionId,
      label: label ?? this.label,
      summaryJson: summaryJson ?? this.summaryJson,
      detailJson: detailJson is String? ? detailJson : this.detailJson,
      at: at ?? this.at,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ChangeLogUpdateTable extends _isd.UpdateTable<ChangeLogTable> {
  ChangeLogUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> spreadsheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.spreadsheetId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> userId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.userId, value);

  _isd.ColumnValue<_i810rwvy.ActorKind, _i810rwvy.ActorKind> actorKind(
    _i810rwvy.ActorKind value,
  ) => _isd.ColumnValue(table.actorKind, value);

  _isd.ColumnValue<String, String> sessionId(String value) =>
      _isd.ColumnValue(table.sessionId, value);

  _isd.ColumnValue<String, String> label(String value) =>
      _isd.ColumnValue(table.label, value);

  _isd.ColumnValue<String, String> summaryJson(String value) =>
      _isd.ColumnValue(table.summaryJson, value);

  _isd.ColumnValue<String, String> detailJson(String? value) =>
      _isd.ColumnValue(table.detailJson, value);

  _isd.ColumnValue<DateTime, DateTime> at(DateTime value) =>
      _isd.ColumnValue(table.at, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class ChangeLogTable extends _isd.Table<_iss.UuidValue> {
  ChangeLogTable({super.tableRelation}) : super(tableName: 'change_log') {
    updateTable = ChangeLogUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    spreadsheetId = _isd.ColumnUuid('spreadsheetId', this);
    userId = _isd.ColumnUuid('userId', this);
    actorKind = _isd.ColumnEnum(
      'actorKind',
      this,
      _isd.EnumSerialization.byName,
    );
    sessionId = _isd.ColumnString('sessionId', this);
    label = _isd.ColumnString('label', this);
    summaryJson = _isd.ColumnString('summaryJson', this);
    detailJson = _isd.ColumnString('detailJson', this);
    at = _isd.ColumnDateTime('at', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final ChangeLogUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid spreadsheetId;

  _i810rwvy.SpreadsheetTable? _spreadsheet;

  /// Auth user UUID of the author.
  late final _isd.ColumnUuid userId;

  late final _isd.ColumnEnum<_i810rwvy.ActorKind> actorKind;

  late final _isd.ColumnString sessionId;

  /// Undo label, e.g. "Paste".
  late final _isd.ColumnString label;

  /// {sheets, ranges, kinds, deleted, revived, structureOverflow}.
  late final _isd.ColumnString summaryJson;

  /// Before/after content for at most 200 cells; null if larger.
  late final _isd.ColumnString detailJson;

  late final _isd.ColumnDateTime at;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SpreadsheetTable get spreadsheet {
    if (_spreadsheet != null) return _spreadsheet!;
    _spreadsheet = _isd.createRelationTable(
      relationFieldName: 'spreadsheet',
      field: ChangeLog.t.spreadsheetId,
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
    userId,
    actorKind,
    sessionId,
    label,
    summaryJson,
    detailJson,
    at,
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

class ChangeLogInclude extends _isd.IncludeObject {
  ChangeLogInclude._({_i810rwvy.SpreadsheetInclude? spreadsheet}) {
    _spreadsheet = spreadsheet;
  }

  _i810rwvy.SpreadsheetInclude? _spreadsheet;

  @override
  Map<String, _isd.Include?> get includes => {'spreadsheet': _spreadsheet};

  @override
  _isd.Table<_iss.UuidValue> get table => ChangeLog.t;
}

class ChangeLogIncludeList extends _isd.IncludeList {
  ChangeLogIncludeList._({
    _isd.WhereExpressionBuilder<ChangeLogTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ChangeLog.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => ChangeLog.t;
}

class ChangeLogRepository {
  const ChangeLogRepository._();

  final attachRow = const ChangeLogAttachRowRepository._();

  /// Returns a list of [ChangeLog]s matching the given query parameters.
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
  Future<List<ChangeLog>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ChangeLogTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<ChangeLogTable>? orderByList,
    _isd.Transaction? transaction,
    ChangeLogInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ChangeLog>(
      where: where?.call(ChangeLog.t),
      orderBy: orderBy?.call(ChangeLog.t),
      orderByList: orderByList?.call(ChangeLog.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ChangeLog]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ChangeLog.t`.
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
  _ida.Stream<List<ChangeLog>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ChangeLogTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<ChangeLogTable>? orderByList,
    ChangeLogInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ChangeLog>(
      where: where?.call(ChangeLog.t),
      orderBy: orderBy?.call(ChangeLog.t),
      orderByList: orderByList?.call(ChangeLog.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ChangeLog] matching the given query parameters.
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
  Future<ChangeLog?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ChangeLogTable>? where,
    int? offset,
    _isd.OrderByBuilder<ChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<ChangeLogTable>? orderByList,
    _isd.Transaction? transaction,
    ChangeLogInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ChangeLog>(
      where: where?.call(ChangeLog.t),
      orderBy: orderBy?.call(ChangeLog.t),
      orderByList: orderByList?.call(ChangeLog.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ChangeLog] by its [id] or null if no such row exists.
  Future<ChangeLog?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    ChangeLogInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ChangeLog>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ChangeLog]s in the list and returns the inserted rows.
  ///
  /// The returned [ChangeLog]s will have their `id` fields set.
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
  Future<List<ChangeLog>> insert(
    _isd.DatabaseSession session,
    List<ChangeLog> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ChangeLog>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ChangeLog] and returns the inserted row.
  ///
  /// The returned [ChangeLog] will have its `id` field set.
  Future<ChangeLog> insertRow(
    _isd.DatabaseSession session,
    ChangeLog row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<ChangeLog>(row, transaction: transaction);
  }

  /// Upserts all [ChangeLog]s in the list and returns the resulting rows.
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
  /// The returned [ChangeLog]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ChangeLog>> upsert(
    _isd.DatabaseSession session,
    List<ChangeLog> rows, {
    required _isd.ColumnSelections<ChangeLogTable> conflictColumns,
    _isd.ColumnSelections<ChangeLogTable>? updateColumns,
    _isd.WhereExpressionBuilder<ChangeLogTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ChangeLog>(
      rows,
      conflictColumns: conflictColumns(ChangeLog.t),
      updateColumns: updateColumns?.call(ChangeLog.t),
      updateWhere: updateWhere?.call(ChangeLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ChangeLog] and returns the resulting row.
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
  /// The returned [ChangeLog] will have its `id` field set.
  Future<ChangeLog?> upsertRow(
    _isd.DatabaseSession session,
    ChangeLog row, {
    required _isd.ColumnSelections<ChangeLogTable> conflictColumns,
    _isd.ColumnSelections<ChangeLogTable>? updateColumns,
    _isd.WhereExpressionBuilder<ChangeLogTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ChangeLog>(
      row,
      conflictColumns: conflictColumns(ChangeLog.t),
      updateColumns: updateColumns?.call(ChangeLog.t),
      updateWhere: updateWhere?.call(ChangeLog.t),
      transaction: transaction,
    );
  }

  /// Updates all [ChangeLog]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ChangeLog>> update(
    _isd.DatabaseSession session,
    List<ChangeLog> rows, {
    _isd.ColumnSelections<ChangeLogTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ChangeLog>(
      rows,
      columns: columns?.call(ChangeLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ChangeLog]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ChangeLog> updateRow(
    _isd.DatabaseSession session,
    ChangeLog row, {
    _isd.ColumnSelections<ChangeLogTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<ChangeLog>(
      row,
      columns: columns?.call(ChangeLog.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ChangeLog] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ChangeLog?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<ChangeLogUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<ChangeLog>(
      id,
      columnValues: columnValues(ChangeLog.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ChangeLog]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ChangeLog>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<ChangeLogUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<ChangeLogTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<ChangeLogTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ChangeLog>(
      columnValues: columnValues(ChangeLog.t.updateTable),
      where: where(ChangeLog.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChangeLog.t),
      orderByList: orderByList?.call(ChangeLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ChangeLog]s in the list and returns the deleted rows.
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
  Future<List<ChangeLog>> delete(
    _isd.DatabaseSession session,
    List<ChangeLog> rows, {
    _isd.OrderByBuilder<ChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<ChangeLogTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ChangeLog>(
      rows,
      orderBy: orderBy?.call(ChangeLog.t),
      orderByList: orderByList?.call(ChangeLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ChangeLog].
  Future<ChangeLog> deleteRow(
    _isd.DatabaseSession session,
    ChangeLog row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ChangeLog>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ChangeLog>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ChangeLogTable> where,
    _isd.OrderByBuilder<ChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<ChangeLogTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ChangeLog>(
      where: where(ChangeLog.t),
      orderBy: orderBy?.call(ChangeLog.t),
      orderByList: orderByList?.call(ChangeLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ChangeLogTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<ChangeLog>(
      where: where?.call(ChangeLog.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ChangeLog] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ChangeLogTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ChangeLog>(
      where: where(ChangeLog.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class ChangeLogAttachRowRepository {
  const ChangeLogAttachRowRepository._();

  /// Creates a relation between the given [ChangeLog] and [Spreadsheet]
  /// by setting the [ChangeLog]'s foreign key `spreadsheetId` to refer to the [Spreadsheet].
  Future<void> spreadsheet(
    _isd.DatabaseSession session,
    ChangeLog changeLog,
    _i810rwvy.Spreadsheet spreadsheet, {
    _isd.Transaction? transaction,
  }) async {
    if (changeLog.id == null) {
      throw ArgumentError.notNull('changeLog.id');
    }
    if (spreadsheet.id == null) {
      throw ArgumentError.notNull('spreadsheet.id');
    }

    var $changeLog = changeLog.copyWith(spreadsheetId: spreadsheet.id);
    await session.db.updateRow<ChangeLog>(
      $changeLog,
      columns: [ChangeLog.t.spreadsheetId],
      transaction: transaction,
    );
  }
}
