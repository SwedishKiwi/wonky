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
import '../../../sheets/scripts/models/script_execution_status.dart'
    as _igympe3c;

/// Server state of an installable trigger (Sheets 09 §8.7.3); the trigger
/// itself is the synced ScriptTrigger row.
abstract class ScriptTriggerState
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  ScriptTriggerState._({
    this.id,
    required this.triggerId,
    required this.spreadsheetUuid,
    this.scheduleJson,
    this.nextRunAt,
    this.lastRunAt,
    this.lastStatus,
    int? consecutiveFailures,
    this.disabledReason,
    this.runningSince,
    this.lastNotifiedAt,
  }) : consecutiveFailures = consecutiveFailures ?? 0;

  factory ScriptTriggerState({
    int? id,
    required _is.UuidValue triggerId,
    required _is.UuidValue spreadsheetUuid,
    String? scheduleJson,
    DateTime? nextRunAt,
    DateTime? lastRunAt,
    _igympe3c.ScriptExecutionStatus? lastStatus,
    int? consecutiveFailures,
    String? disabledReason,
    DateTime? runningSince,
    DateTime? lastNotifiedAt,
  }) = _ScriptTriggerStateImpl;

  factory ScriptTriggerState.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScriptTriggerState(
      id: jsonSerialization['id'] as int?,
      triggerId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['triggerId'],
      ),
      spreadsheetUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spreadsheetUuid'],
      ),
      scheduleJson: jsonSerialization['scheduleJson'] as String?,
      nextRunAt: jsonSerialization['nextRunAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['nextRunAt']),
      lastRunAt: jsonSerialization['lastRunAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['lastRunAt']),
      lastStatus: jsonSerialization['lastStatus'] == null
          ? null
          : _igympe3c.ScriptExecutionStatus.fromJson(
              (jsonSerialization['lastStatus'] as String),
            ),
      consecutiveFailures: jsonSerialization['consecutiveFailures'] as int?,
      disabledReason: jsonSerialization['disabledReason'] as String?,
      runningSince: jsonSerialization['runningSince'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['runningSince'],
            ),
      lastNotifiedAt: jsonSerialization['lastNotifiedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastNotifiedAt'],
            ),
    );
  }

  static final t = ScriptTriggerStateTable();

  static const db = ScriptTriggerStateRepository._();

  @override
  int? id;

  _is.UuidValue triggerId;

  _is.UuidValue spreadsheetUuid;

  /// Signature of the synced row the state was computed from.
  String? scheduleJson;

  DateTime? nextRunAt;

  DateTime? lastRunAt;

  _igympe3c.ScriptExecutionStatus? lastStatus;

  int consecutiveFailures;

  String? disabledReason;

  DateTime? runningSince;

  /// Last scriptFailure notification (daily digest of failures).
  DateTime? lastNotifiedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [ScriptTriggerState]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ScriptTriggerState copyWith({
    int? id,
    _is.UuidValue? triggerId,
    _is.UuidValue? spreadsheetUuid,
    String? scheduleJson,
    DateTime? nextRunAt = const _is.$UndefinedDateTime(),
    DateTime? lastRunAt = const _is.$UndefinedDateTime(),
    _igympe3c.ScriptExecutionStatus? lastStatus,
    int? consecutiveFailures,
    String? disabledReason,
    DateTime? runningSince = const _is.$UndefinedDateTime(),
    DateTime? lastNotifiedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScriptTriggerState',
      if (id != null) 'id': id,
      'triggerId': triggerId.toJson(),
      'spreadsheetUuid': spreadsheetUuid.toJson(),
      if (scheduleJson != null) 'scheduleJson': scheduleJson,
      if (nextRunAt != null) 'nextRunAt': nextRunAt?.toJson(),
      if (lastRunAt != null) 'lastRunAt': lastRunAt?.toJson(),
      if (lastStatus != null) 'lastStatus': lastStatus?.toJson(),
      'consecutiveFailures': consecutiveFailures,
      if (disabledReason != null) 'disabledReason': disabledReason,
      if (runningSince != null) 'runningSince': runningSince?.toJson(),
      if (lastNotifiedAt != null) 'lastNotifiedAt': lastNotifiedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ScriptTriggerStateInclude include() {
    return ScriptTriggerStateInclude._();
  }

  static ScriptTriggerStateIncludeList includeList({
    _is.WhereExpressionBuilder<ScriptTriggerStateTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptTriggerStateTable>? orderBy,
    _is.OrderByListBuilder<ScriptTriggerStateTable>? orderByList,
    ScriptTriggerStateInclude? include,
  }) {
    return ScriptTriggerStateIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptTriggerState.t),
      orderByList: orderByList?.call(ScriptTriggerState.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ScriptTriggerStateImpl extends ScriptTriggerState {
  _ScriptTriggerStateImpl({
    int? id,
    required _is.UuidValue triggerId,
    required _is.UuidValue spreadsheetUuid,
    String? scheduleJson,
    DateTime? nextRunAt,
    DateTime? lastRunAt,
    _igympe3c.ScriptExecutionStatus? lastStatus,
    int? consecutiveFailures,
    String? disabledReason,
    DateTime? runningSince,
    DateTime? lastNotifiedAt,
  }) : super._(
         id: id,
         triggerId: triggerId,
         spreadsheetUuid: spreadsheetUuid,
         scheduleJson: scheduleJson,
         nextRunAt: nextRunAt,
         lastRunAt: lastRunAt,
         lastStatus: lastStatus,
         consecutiveFailures: consecutiveFailures,
         disabledReason: disabledReason,
         runningSince: runningSince,
         lastNotifiedAt: lastNotifiedAt,
       );

  /// Returns a shallow copy of this [ScriptTriggerState]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ScriptTriggerState copyWith({
    Object? id = _Undefined,
    _is.UuidValue? triggerId,
    _is.UuidValue? spreadsheetUuid,
    Object? scheduleJson = _Undefined,
    DateTime? nextRunAt = const _is.$UndefinedDateTime(),
    DateTime? lastRunAt = const _is.$UndefinedDateTime(),
    Object? lastStatus = _Undefined,
    int? consecutiveFailures,
    Object? disabledReason = _Undefined,
    DateTime? runningSince = const _is.$UndefinedDateTime(),
    DateTime? lastNotifiedAt = const _is.$UndefinedDateTime(),
  }) {
    return ScriptTriggerState(
      id: id is int? ? id : this.id,
      triggerId: triggerId ?? this.triggerId,
      spreadsheetUuid: spreadsheetUuid ?? this.spreadsheetUuid,
      scheduleJson: scheduleJson is String? ? scheduleJson : this.scheduleJson,
      nextRunAt: nextRunAt is _is.UndefinedSentinel
          ? this.nextRunAt
          : nextRunAt,
      lastRunAt: lastRunAt is _is.UndefinedSentinel
          ? this.lastRunAt
          : lastRunAt,
      lastStatus: lastStatus is _igympe3c.ScriptExecutionStatus?
          ? lastStatus
          : this.lastStatus,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      disabledReason: disabledReason is String?
          ? disabledReason
          : this.disabledReason,
      runningSince: runningSince is _is.UndefinedSentinel
          ? this.runningSince
          : runningSince,
      lastNotifiedAt: lastNotifiedAt is _is.UndefinedSentinel
          ? this.lastNotifiedAt
          : lastNotifiedAt,
    );
  }
}

class ScriptTriggerStateUpdateTable
    extends _is.UpdateTable<ScriptTriggerStateTable> {
  ScriptTriggerStateUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> triggerId(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.triggerId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> spreadsheetUuid(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.spreadsheetUuid,
    value,
  );

  _is.ColumnValue<String, String> scheduleJson(String? value) =>
      _is.ColumnValue(
        table.scheduleJson,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> nextRunAt(DateTime? value) =>
      _is.ColumnValue(
        table.nextRunAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> lastRunAt(DateTime? value) =>
      _is.ColumnValue(
        table.lastRunAt,
        value,
      );

  _is.ColumnValue<
    _igympe3c.ScriptExecutionStatus,
    _igympe3c.ScriptExecutionStatus
  >
  lastStatus(_igympe3c.ScriptExecutionStatus? value) => _is.ColumnValue(
    table.lastStatus,
    value,
  );

  _is.ColumnValue<int, int> consecutiveFailures(int value) => _is.ColumnValue(
    table.consecutiveFailures,
    value,
  );

  _is.ColumnValue<String, String> disabledReason(String? value) =>
      _is.ColumnValue(
        table.disabledReason,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> runningSince(DateTime? value) =>
      _is.ColumnValue(
        table.runningSince,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> lastNotifiedAt(DateTime? value) =>
      _is.ColumnValue(
        table.lastNotifiedAt,
        value,
      );
}

class ScriptTriggerStateTable extends _is.Table<int?> {
  ScriptTriggerStateTable({super.tableRelation})
    : super(tableName: 'script_trigger_state') {
    updateTable = ScriptTriggerStateUpdateTable(this);
    triggerId = _is.ColumnUuid(
      'triggerId',
      this,
    );
    spreadsheetUuid = _is.ColumnUuid(
      'spreadsheetUuid',
      this,
    );
    scheduleJson = _is.ColumnString(
      'scheduleJson',
      this,
    );
    nextRunAt = _is.ColumnDateTime(
      'nextRunAt',
      this,
    );
    lastRunAt = _is.ColumnDateTime(
      'lastRunAt',
      this,
    );
    lastStatus = _is.ColumnEnum(
      'lastStatus',
      this,
      _is.EnumSerialization.byName,
    );
    consecutiveFailures = _is.ColumnInt(
      'consecutiveFailures',
      this,
      hasDefault: true,
    );
    disabledReason = _is.ColumnString(
      'disabledReason',
      this,
    );
    runningSince = _is.ColumnDateTime(
      'runningSince',
      this,
    );
    lastNotifiedAt = _is.ColumnDateTime(
      'lastNotifiedAt',
      this,
    );
  }

  late final ScriptTriggerStateUpdateTable updateTable;

  late final _is.ColumnUuid triggerId;

  late final _is.ColumnUuid spreadsheetUuid;

  /// Signature of the synced row the state was computed from.
  late final _is.ColumnString scheduleJson;

  late final _is.ColumnDateTime nextRunAt;

  late final _is.ColumnDateTime lastRunAt;

  late final _is.ColumnEnum<_igympe3c.ScriptExecutionStatus> lastStatus;

  late final _is.ColumnInt consecutiveFailures;

  late final _is.ColumnString disabledReason;

  late final _is.ColumnDateTime runningSince;

  /// Last scriptFailure notification (daily digest of failures).
  late final _is.ColumnDateTime lastNotifiedAt;

  @override
  List<_is.Column> get columns => [
    id,
    triggerId,
    spreadsheetUuid,
    scheduleJson,
    nextRunAt,
    lastRunAt,
    lastStatus,
    consecutiveFailures,
    disabledReason,
    runningSince,
    lastNotifiedAt,
  ];
}

class ScriptTriggerStateInclude extends _is.IncludeObject {
  ScriptTriggerStateInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => ScriptTriggerState.t;
}

class ScriptTriggerStateIncludeList extends _is.IncludeList {
  ScriptTriggerStateIncludeList._({
    _is.WhereExpressionBuilder<ScriptTriggerStateTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ScriptTriggerState.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => ScriptTriggerState.t;
}

class ScriptTriggerStateRepository {
  const ScriptTriggerStateRepository._();

  /// Returns a list of [ScriptTriggerState]s matching the given query parameters.
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
  Future<List<ScriptTriggerState>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptTriggerStateTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptTriggerStateTable>? orderBy,
    _is.OrderByListBuilder<ScriptTriggerStateTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ScriptTriggerState>(
      where: where?.call(ScriptTriggerState.t),
      orderBy: orderBy?.call(ScriptTriggerState.t),
      orderByList: orderByList?.call(ScriptTriggerState.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ScriptTriggerState]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ScriptTriggerState.t`.
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
  _ida.Stream<List<ScriptTriggerState>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptTriggerStateTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptTriggerStateTable>? orderBy,
    _is.OrderByListBuilder<ScriptTriggerStateTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ScriptTriggerState>(
      where: where?.call(ScriptTriggerState.t),
      orderBy: orderBy?.call(ScriptTriggerState.t),
      orderByList: orderByList?.call(ScriptTriggerState.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ScriptTriggerState] matching the given query parameters.
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
  Future<ScriptTriggerState?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptTriggerStateTable>? where,
    int? offset,
    _is.OrderByBuilder<ScriptTriggerStateTable>? orderBy,
    _is.OrderByListBuilder<ScriptTriggerStateTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ScriptTriggerState>(
      where: where?.call(ScriptTriggerState.t),
      orderBy: orderBy?.call(ScriptTriggerState.t),
      orderByList: orderByList?.call(ScriptTriggerState.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ScriptTriggerState] by its [id] or null if no such row exists.
  Future<ScriptTriggerState?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ScriptTriggerState>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ScriptTriggerState]s in the list and returns the inserted rows.
  ///
  /// The returned [ScriptTriggerState]s will have their `id` fields set.
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
  Future<List<ScriptTriggerState>> insert(
    _is.DatabaseSession session,
    List<ScriptTriggerState> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ScriptTriggerState>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ScriptTriggerState] and returns the inserted row.
  ///
  /// The returned [ScriptTriggerState] will have its `id` field set.
  Future<ScriptTriggerState> insertRow(
    _is.DatabaseSession session,
    ScriptTriggerState row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<ScriptTriggerState>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [ScriptTriggerState]s in the list and returns the resulting rows.
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
  /// The returned [ScriptTriggerState]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptTriggerState>> upsert(
    _is.DatabaseSession session,
    List<ScriptTriggerState> rows, {
    required _is.ColumnSelections<ScriptTriggerStateTable> conflictColumns,
    _is.ColumnSelections<ScriptTriggerStateTable>? updateColumns,
    _is.WhereExpressionBuilder<ScriptTriggerStateTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ScriptTriggerState>(
      rows,
      conflictColumns: conflictColumns(ScriptTriggerState.t),
      updateColumns: updateColumns?.call(ScriptTriggerState.t),
      updateWhere: updateWhere?.call(ScriptTriggerState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ScriptTriggerState] and returns the resulting row.
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
  /// The returned [ScriptTriggerState] will have its `id` field set.
  Future<ScriptTriggerState?> upsertRow(
    _is.DatabaseSession session,
    ScriptTriggerState row, {
    required _is.ColumnSelections<ScriptTriggerStateTable> conflictColumns,
    _is.ColumnSelections<ScriptTriggerStateTable>? updateColumns,
    _is.WhereExpressionBuilder<ScriptTriggerStateTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ScriptTriggerState>(
      row,
      conflictColumns: conflictColumns(ScriptTriggerState.t),
      updateColumns: updateColumns?.call(ScriptTriggerState.t),
      updateWhere: updateWhere?.call(ScriptTriggerState.t),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptTriggerState]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptTriggerState>> update(
    _is.DatabaseSession session,
    List<ScriptTriggerState> rows, {
    _is.ColumnSelections<ScriptTriggerStateTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ScriptTriggerState>(
      rows,
      columns: columns?.call(ScriptTriggerState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ScriptTriggerState]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ScriptTriggerState> updateRow(
    _is.DatabaseSession session,
    ScriptTriggerState row, {
    _is.ColumnSelections<ScriptTriggerStateTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<ScriptTriggerState>(
      row,
      columns: columns?.call(ScriptTriggerState.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ScriptTriggerState] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ScriptTriggerState?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<ScriptTriggerStateUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<ScriptTriggerState>(
      id,
      columnValues: columnValues(ScriptTriggerState.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptTriggerState]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptTriggerState>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<ScriptTriggerStateUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<ScriptTriggerStateTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ScriptTriggerStateTable>? orderBy,
    _is.OrderByListBuilder<ScriptTriggerStateTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ScriptTriggerState>(
      columnValues: columnValues(ScriptTriggerState.t.updateTable),
      where: where(ScriptTriggerState.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptTriggerState.t),
      orderByList: orderByList?.call(ScriptTriggerState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ScriptTriggerState]s in the list and returns the deleted rows.
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
  Future<List<ScriptTriggerState>> delete(
    _is.DatabaseSession session,
    List<ScriptTriggerState> rows, {
    _is.OrderByBuilder<ScriptTriggerStateTable>? orderBy,
    _is.OrderByListBuilder<ScriptTriggerStateTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ScriptTriggerState>(
      rows,
      orderBy: orderBy?.call(ScriptTriggerState.t),
      orderByList: orderByList?.call(ScriptTriggerState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ScriptTriggerState].
  Future<ScriptTriggerState> deleteRow(
    _is.DatabaseSession session,
    ScriptTriggerState row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ScriptTriggerState>(
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
  Future<List<ScriptTriggerState>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ScriptTriggerStateTable> where,
    _is.OrderByBuilder<ScriptTriggerStateTable>? orderBy,
    _is.OrderByListBuilder<ScriptTriggerStateTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ScriptTriggerState>(
      where: where(ScriptTriggerState.t),
      orderBy: orderBy?.call(ScriptTriggerState.t),
      orderByList: orderByList?.call(ScriptTriggerState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ScriptTriggerStateTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<ScriptTriggerState>(
      where: where?.call(ScriptTriggerState.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ScriptTriggerState] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ScriptTriggerStateTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ScriptTriggerState>(
      where: where(ScriptTriggerState.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
