/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;
import 'package:serverpod/serverpod.dart' as _is;
import '../../../sheets/scripts/models/script_execution_kind.dart' as _i4lfs2qp;
import '../../../sheets/scripts/models/script_execution_status.dart'
    as _igympe3c;

/// A queued server script execution (Sheets 09 §8.5, §8.7.3): installable
/// triggers are enqueued here and run by instances with the worker role
/// (`sheets.scriptWorker`), at most `scriptUserConcurrency` per run-as
/// user and one per trigger at a time.
abstract class ScriptJob
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  ScriptJob._({
    this.id,
    required this.kind,
    required this.spreadsheetUuid,
    required this.itemUuid,
    this.triggerId,
    required this.runAsUserId,
    required this.functionName,
    required this.payloadJson,
    required this.status,
    required this.enqueuedAt,
    this.leaseOwner,
    this.leaseUntil,
    int? attempts,
    int? coalesced,
    this.resultJson,
    this.finishedAt,
  }) : attempts = attempts ?? 0,
       coalesced = coalesced ?? 0;

  factory ScriptJob({
    int? id,
    required _i4lfs2qp.ScriptExecutionKind kind,
    required _is.UuidValue spreadsheetUuid,
    required _is.UuidValue itemUuid,
    _is.UuidValue? triggerId,
    required int runAsUserId,
    required String functionName,
    required String payloadJson,
    required _igympe3c.ScriptExecutionStatus status,
    required DateTime enqueuedAt,
    String? leaseOwner,
    DateTime? leaseUntil,
    int? attempts,
    int? coalesced,
    String? resultJson,
    DateTime? finishedAt,
  }) = _ScriptJobImpl;

  factory ScriptJob.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScriptJob(
      id: jsonSerialization['id'] as int?,
      kind: _i4lfs2qp.ScriptExecutionKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      spreadsheetUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spreadsheetUuid'],
      ),
      itemUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      triggerId: jsonSerialization['triggerId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['triggerId']),
      runAsUserId: jsonSerialization['runAsUserId'] as int,
      functionName: jsonSerialization['functionName'] as String,
      payloadJson: jsonSerialization['payloadJson'] as String,
      status: _igympe3c.ScriptExecutionStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      enqueuedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['enqueuedAt'],
      ),
      leaseOwner: jsonSerialization['leaseOwner'] as String?,
      leaseUntil: jsonSerialization['leaseUntil'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['leaseUntil']),
      attempts: jsonSerialization['attempts'] as int?,
      coalesced: jsonSerialization['coalesced'] as int?,
      resultJson: jsonSerialization['resultJson'] as String?,
      finishedAt: jsonSerialization['finishedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['finishedAt']),
    );
  }

  static final t = ScriptJobTable();

  static const db = ScriptJobRepository._();

  @override
  int? id;

  _i4lfs2qp.ScriptExecutionKind kind;

  /// The spreadsheet space.
  _is.UuidValue spreadsheetUuid;

  /// The drive item of the spreadsheet.
  _is.UuidValue itemUuid;

  _is.UuidValue? triggerId;

  /// Run-as user (UserProfile id).
  int runAsUserId;

  String functionName;

  /// The event (`ScriptJobEvents.encode`).
  String payloadJson;

  /// queued, running, completed, failed, skipped.
  _igympe3c.ScriptExecutionStatus status;

  DateTime enqueuedAt;

  /// Instance that claimed the job.
  String? leaseOwner;

  DateTime? leaseUntil;

  int attempts;

  /// Queued events merged into this one (per-trigger queue cap).
  int coalesced;

  /// `{executionId, status}` of the run.
  String? resultJson;

  DateTime? finishedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [ScriptJob]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ScriptJob copyWith({
    int? id,
    _i4lfs2qp.ScriptExecutionKind? kind,
    _is.UuidValue? spreadsheetUuid,
    _is.UuidValue? itemUuid,
    _is.UuidValue? triggerId = const _is.$UndefinedUuidValue(),
    int? runAsUserId,
    String? functionName,
    String? payloadJson,
    _igympe3c.ScriptExecutionStatus? status,
    DateTime? enqueuedAt,
    String? leaseOwner,
    DateTime? leaseUntil = const _is.$UndefinedDateTime(),
    int? attempts,
    int? coalesced,
    String? resultJson,
    DateTime? finishedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScriptJob',
      if (id != null) 'id': id,
      'kind': kind.toJson(),
      'spreadsheetUuid': spreadsheetUuid.toJson(),
      'itemUuid': itemUuid.toJson(),
      if (triggerId != null) 'triggerId': triggerId?.toJson(),
      'runAsUserId': runAsUserId,
      'functionName': functionName,
      'payloadJson': payloadJson,
      'status': status.toJson(),
      'enqueuedAt': enqueuedAt.toJson(),
      if (leaseOwner != null) 'leaseOwner': leaseOwner,
      if (leaseUntil != null) 'leaseUntil': leaseUntil?.toJson(),
      'attempts': attempts,
      'coalesced': coalesced,
      if (resultJson != null) 'resultJson': resultJson,
      if (finishedAt != null) 'finishedAt': finishedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ScriptJobInclude include() {
    return ScriptJobInclude._();
  }

  static ScriptJobIncludeList includeList({
    _is.WhereExpressionBuilder<ScriptJobTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptJobTable>? orderBy,
    _is.OrderByListBuilder<ScriptJobTable>? orderByList,
    ScriptJobInclude? include,
  }) {
    return ScriptJobIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptJob.t),
      orderByList: orderByList?.call(ScriptJob.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ScriptJobImpl extends ScriptJob {
  _ScriptJobImpl({
    int? id,
    required _i4lfs2qp.ScriptExecutionKind kind,
    required _is.UuidValue spreadsheetUuid,
    required _is.UuidValue itemUuid,
    _is.UuidValue? triggerId,
    required int runAsUserId,
    required String functionName,
    required String payloadJson,
    required _igympe3c.ScriptExecutionStatus status,
    required DateTime enqueuedAt,
    String? leaseOwner,
    DateTime? leaseUntil,
    int? attempts,
    int? coalesced,
    String? resultJson,
    DateTime? finishedAt,
  }) : super._(
         id: id,
         kind: kind,
         spreadsheetUuid: spreadsheetUuid,
         itemUuid: itemUuid,
         triggerId: triggerId,
         runAsUserId: runAsUserId,
         functionName: functionName,
         payloadJson: payloadJson,
         status: status,
         enqueuedAt: enqueuedAt,
         leaseOwner: leaseOwner,
         leaseUntil: leaseUntil,
         attempts: attempts,
         coalesced: coalesced,
         resultJson: resultJson,
         finishedAt: finishedAt,
       );

  /// Returns a shallow copy of this [ScriptJob]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ScriptJob copyWith({
    Object? id = _Undefined,
    _i4lfs2qp.ScriptExecutionKind? kind,
    _is.UuidValue? spreadsheetUuid,
    _is.UuidValue? itemUuid,
    _is.UuidValue? triggerId = const _is.$UndefinedUuidValue(),
    int? runAsUserId,
    String? functionName,
    String? payloadJson,
    _igympe3c.ScriptExecutionStatus? status,
    DateTime? enqueuedAt,
    Object? leaseOwner = _Undefined,
    DateTime? leaseUntil = const _is.$UndefinedDateTime(),
    int? attempts,
    int? coalesced,
    Object? resultJson = _Undefined,
    DateTime? finishedAt = const _is.$UndefinedDateTime(),
  }) {
    return ScriptJob(
      id: id is int? ? id : this.id,
      kind: kind ?? this.kind,
      spreadsheetUuid: spreadsheetUuid ?? this.spreadsheetUuid,
      itemUuid: itemUuid ?? this.itemUuid,
      triggerId: triggerId is _is.UndefinedSentinel
          ? this.triggerId
          : triggerId,
      runAsUserId: runAsUserId ?? this.runAsUserId,
      functionName: functionName ?? this.functionName,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
      leaseOwner: leaseOwner is String? ? leaseOwner : this.leaseOwner,
      leaseUntil: leaseUntil is _is.UndefinedSentinel
          ? this.leaseUntil
          : leaseUntil,
      attempts: attempts ?? this.attempts,
      coalesced: coalesced ?? this.coalesced,
      resultJson: resultJson is String? ? resultJson : this.resultJson,
      finishedAt: finishedAt is _is.UndefinedSentinel
          ? this.finishedAt
          : finishedAt,
    );
  }
}

class ScriptJobUpdateTable extends _is.UpdateTable<ScriptJobTable> {
  ScriptJobUpdateTable(super.table);

  _is.ColumnValue<_i4lfs2qp.ScriptExecutionKind, _i4lfs2qp.ScriptExecutionKind>
  kind(_i4lfs2qp.ScriptExecutionKind value) => _is.ColumnValue(
    table.kind,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> spreadsheetUuid(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.spreadsheetUuid,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> itemUuid(_is.UuidValue value) =>
      _is.ColumnValue(
        table.itemUuid,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> triggerId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.triggerId,
    value,
  );

  _is.ColumnValue<int, int> runAsUserId(int value) => _is.ColumnValue(
    table.runAsUserId,
    value,
  );

  _is.ColumnValue<String, String> functionName(String value) => _is.ColumnValue(
    table.functionName,
    value,
  );

  _is.ColumnValue<String, String> payloadJson(String value) => _is.ColumnValue(
    table.payloadJson,
    value,
  );

  _is.ColumnValue<
    _igympe3c.ScriptExecutionStatus,
    _igympe3c.ScriptExecutionStatus
  >
  status(_igympe3c.ScriptExecutionStatus value) => _is.ColumnValue(
    table.status,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> enqueuedAt(DateTime value) =>
      _is.ColumnValue(
        table.enqueuedAt,
        value,
      );

  _is.ColumnValue<String, String> leaseOwner(String? value) => _is.ColumnValue(
    table.leaseOwner,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> leaseUntil(DateTime? value) =>
      _is.ColumnValue(
        table.leaseUntil,
        value,
      );

  _is.ColumnValue<int, int> attempts(int value) => _is.ColumnValue(
    table.attempts,
    value,
  );

  _is.ColumnValue<int, int> coalesced(int value) => _is.ColumnValue(
    table.coalesced,
    value,
  );

  _is.ColumnValue<String, String> resultJson(String? value) => _is.ColumnValue(
    table.resultJson,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> finishedAt(DateTime? value) =>
      _is.ColumnValue(
        table.finishedAt,
        value,
      );
}

class ScriptJobTable extends _is.Table<int?> {
  ScriptJobTable({super.tableRelation}) : super(tableName: 'script_job') {
    updateTable = ScriptJobUpdateTable(this);
    kind = _is.ColumnEnum(
      'kind',
      this,
      _is.EnumSerialization.byName,
    );
    spreadsheetUuid = _is.ColumnUuid(
      'spreadsheetUuid',
      this,
    );
    itemUuid = _is.ColumnUuid(
      'itemUuid',
      this,
    );
    triggerId = _is.ColumnUuid(
      'triggerId',
      this,
    );
    runAsUserId = _is.ColumnInt(
      'runAsUserId',
      this,
    );
    functionName = _is.ColumnString(
      'functionName',
      this,
    );
    payloadJson = _is.ColumnString(
      'payloadJson',
      this,
    );
    status = _is.ColumnEnum(
      'status',
      this,
      _is.EnumSerialization.byName,
    );
    enqueuedAt = _is.ColumnDateTime(
      'enqueuedAt',
      this,
    );
    leaseOwner = _is.ColumnString(
      'leaseOwner',
      this,
    );
    leaseUntil = _is.ColumnDateTime(
      'leaseUntil',
      this,
    );
    attempts = _is.ColumnInt(
      'attempts',
      this,
      hasDefault: true,
    );
    coalesced = _is.ColumnInt(
      'coalesced',
      this,
      hasDefault: true,
    );
    resultJson = _is.ColumnString(
      'resultJson',
      this,
    );
    finishedAt = _is.ColumnDateTime(
      'finishedAt',
      this,
    );
  }

  late final ScriptJobUpdateTable updateTable;

  late final _is.ColumnEnum<_i4lfs2qp.ScriptExecutionKind> kind;

  /// The spreadsheet space.
  late final _is.ColumnUuid spreadsheetUuid;

  /// The drive item of the spreadsheet.
  late final _is.ColumnUuid itemUuid;

  late final _is.ColumnUuid triggerId;

  /// Run-as user (UserProfile id).
  late final _is.ColumnInt runAsUserId;

  late final _is.ColumnString functionName;

  /// The event (`ScriptJobEvents.encode`).
  late final _is.ColumnString payloadJson;

  /// queued, running, completed, failed, skipped.
  late final _is.ColumnEnum<_igympe3c.ScriptExecutionStatus> status;

  late final _is.ColumnDateTime enqueuedAt;

  /// Instance that claimed the job.
  late final _is.ColumnString leaseOwner;

  late final _is.ColumnDateTime leaseUntil;

  late final _is.ColumnInt attempts;

  /// Queued events merged into this one (per-trigger queue cap).
  late final _is.ColumnInt coalesced;

  /// `{executionId, status}` of the run.
  late final _is.ColumnString resultJson;

  late final _is.ColumnDateTime finishedAt;

  @override
  List<_is.Column> get columns => [
    id,
    kind,
    spreadsheetUuid,
    itemUuid,
    triggerId,
    runAsUserId,
    functionName,
    payloadJson,
    status,
    enqueuedAt,
    leaseOwner,
    leaseUntil,
    attempts,
    coalesced,
    resultJson,
    finishedAt,
  ];
}

class ScriptJobInclude extends _is.IncludeObject {
  ScriptJobInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => ScriptJob.t;
}

class ScriptJobIncludeList extends _is.IncludeList {
  ScriptJobIncludeList._({
    _is.WhereExpressionBuilder<ScriptJobTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ScriptJob.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => ScriptJob.t;
}

class ScriptJobRepository {
  const ScriptJobRepository._();

  /// Returns a list of [ScriptJob]s matching the given query parameters.
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
  Future<List<ScriptJob>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptJobTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptJobTable>? orderBy,
    _is.OrderByListBuilder<ScriptJobTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ScriptJob>(
      where: where?.call(ScriptJob.t),
      orderBy: orderBy?.call(ScriptJob.t),
      orderByList: orderByList?.call(ScriptJob.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ScriptJob]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ScriptJob.t`.
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
  _ida.Stream<List<ScriptJob>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptJobTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptJobTable>? orderBy,
    _is.OrderByListBuilder<ScriptJobTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ScriptJob>(
      where: where?.call(ScriptJob.t),
      orderBy: orderBy?.call(ScriptJob.t),
      orderByList: orderByList?.call(ScriptJob.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ScriptJob] matching the given query parameters.
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
  Future<ScriptJob?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptJobTable>? where,
    int? offset,
    _is.OrderByBuilder<ScriptJobTable>? orderBy,
    _is.OrderByListBuilder<ScriptJobTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ScriptJob>(
      where: where?.call(ScriptJob.t),
      orderBy: orderBy?.call(ScriptJob.t),
      orderByList: orderByList?.call(ScriptJob.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ScriptJob] by its [id] or null if no such row exists.
  Future<ScriptJob?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ScriptJob>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ScriptJob]s in the list and returns the inserted rows.
  ///
  /// The returned [ScriptJob]s will have their `id` fields set.
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
  Future<List<ScriptJob>> insert(
    _is.DatabaseSession session,
    List<ScriptJob> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ScriptJob>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ScriptJob] and returns the inserted row.
  ///
  /// The returned [ScriptJob] will have its `id` field set.
  Future<ScriptJob> insertRow(
    _is.DatabaseSession session,
    ScriptJob row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<ScriptJob>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [ScriptJob]s in the list and returns the resulting rows.
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
  /// The returned [ScriptJob]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptJob>> upsert(
    _is.DatabaseSession session,
    List<ScriptJob> rows, {
    required _is.ColumnSelections<ScriptJobTable> conflictColumns,
    _is.ColumnSelections<ScriptJobTable>? updateColumns,
    _is.WhereExpressionBuilder<ScriptJobTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ScriptJob>(
      rows,
      conflictColumns: conflictColumns(ScriptJob.t),
      updateColumns: updateColumns?.call(ScriptJob.t),
      updateWhere: updateWhere?.call(ScriptJob.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ScriptJob] and returns the resulting row.
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
  /// The returned [ScriptJob] will have its `id` field set.
  Future<ScriptJob?> upsertRow(
    _is.DatabaseSession session,
    ScriptJob row, {
    required _is.ColumnSelections<ScriptJobTable> conflictColumns,
    _is.ColumnSelections<ScriptJobTable>? updateColumns,
    _is.WhereExpressionBuilder<ScriptJobTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ScriptJob>(
      row,
      conflictColumns: conflictColumns(ScriptJob.t),
      updateColumns: updateColumns?.call(ScriptJob.t),
      updateWhere: updateWhere?.call(ScriptJob.t),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptJob]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptJob>> update(
    _is.DatabaseSession session,
    List<ScriptJob> rows, {
    _is.ColumnSelections<ScriptJobTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ScriptJob>(
      rows,
      columns: columns?.call(ScriptJob.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ScriptJob]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ScriptJob> updateRow(
    _is.DatabaseSession session,
    ScriptJob row, {
    _is.ColumnSelections<ScriptJobTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<ScriptJob>(
      row,
      columns: columns?.call(ScriptJob.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ScriptJob] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ScriptJob?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<ScriptJobUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<ScriptJob>(
      id,
      columnValues: columnValues(ScriptJob.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptJob]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptJob>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<ScriptJobUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<ScriptJobTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptJobTable>? orderBy,
    _is.OrderByListBuilder<ScriptJobTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ScriptJob>(
      columnValues: columnValues(ScriptJob.t.updateTable),
      where: where(ScriptJob.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptJob.t),
      orderByList: orderByList?.call(ScriptJob.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ScriptJob]s in the list and returns the deleted rows.
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
  Future<List<ScriptJob>> delete(
    _is.DatabaseSession session,
    List<ScriptJob> rows, {
    _is.OrderByBuilder<ScriptJobTable>? orderBy,
    _is.OrderByListBuilder<ScriptJobTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ScriptJob>(
      rows,
      orderBy: orderBy?.call(ScriptJob.t),
      orderByList: orderByList?.call(ScriptJob.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ScriptJob].
  Future<ScriptJob> deleteRow(
    _is.DatabaseSession session,
    ScriptJob row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ScriptJob>(
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
  Future<List<ScriptJob>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ScriptJobTable> where,
    _is.OrderByBuilder<ScriptJobTable>? orderBy,
    _is.OrderByListBuilder<ScriptJobTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ScriptJob>(
      where: where(ScriptJob.t),
      orderBy: orderBy?.call(ScriptJob.t),
      orderByList: orderByList?.call(ScriptJob.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptJobTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<ScriptJob>(
      where: where?.call(ScriptJob.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ScriptJob] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ScriptJobTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ScriptJob>(
      where: where(ScriptJob.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
