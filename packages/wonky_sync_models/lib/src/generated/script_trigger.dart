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

/// An installable script trigger.
abstract class ScriptTrigger
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  ScriptTrigger._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.projectId,
    this.project,
    required this.kind,
    required this.functionName,
    this.scheduleJson,
    required this.runAsUserId,
    bool? enabled,
    this.optionsJson,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       enabled = enabled ?? true,
       createdAt = createdAt ?? DateTime.now();

  factory ScriptTrigger({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue projectId,
    _i810rwvy.ScriptProject? project,
    required _i810rwvy.TriggerKind kind,
    required String functionName,
    String? scheduleJson,
    required _iss.UuidValue runAsUserId,
    bool? enabled,
    String? optionsJson,
    DateTime? createdAt,
  }) = _ScriptTriggerImpl;

  factory ScriptTrigger.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScriptTrigger(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      projectId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['projectId'],
      ),
      project: jsonSerialization['project'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.ScriptProject>(
              jsonSerialization['project'],
            ),
      kind: _i810rwvy.TriggerKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      functionName: jsonSerialization['functionName'] as String,
      scheduleJson: jsonSerialization['scheduleJson'] as String?,
      runAsUserId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['runAsUserId'],
      ),
      enabled: jsonSerialization['enabled'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['enabled']),
      optionsJson: jsonSerialization['optionsJson'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = ScriptTriggerTable();

  static const db = ScriptTriggerRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue projectId;

  _i810rwvy.ScriptProject? project;

  _i810rwvy.TriggerKind kind;

  String functionName;

  String? scheduleJson;

  /// Installer; must keep edit access.
  _iss.UuidValue runAsUserId;

  bool enabled;

  /// {fireForMcp, notify}.
  String? optionsJson;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [ScriptTrigger]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  ScriptTrigger copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? projectId,
    _i810rwvy.ScriptProject? project = const _UndefinedScriptTrigger$project(),
    _i810rwvy.TriggerKind? kind,
    String? functionName,
    String? scheduleJson,
    _iss.UuidValue? runAsUserId,
    bool? enabled,
    String? optionsJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScriptTrigger',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'projectId': projectId.toJson(),
      if (project != null) 'project': project?.toJson(),
      'kind': kind.toJson(),
      'functionName': functionName,
      if (scheduleJson != null) 'scheduleJson': scheduleJson,
      'runAsUserId': runAsUserId.toJson(),
      'enabled': enabled,
      if (optionsJson != null) 'optionsJson': optionsJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ScriptTrigger',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'projectId': projectId.toJson(),
      if (project != null) 'project': project?.toJsonForProtocol(),
      'kind': kind.toJson(),
      'functionName': functionName,
      if (scheduleJson != null) 'scheduleJson': scheduleJson,
      'runAsUserId': runAsUserId.toJson(),
      'enabled': enabled,
      if (optionsJson != null) 'optionsJson': optionsJson,
      'createdAt': createdAt.toJson(),
    };
  }

  static ScriptTriggerInclude include({
    _i810rwvy.ScriptProjectInclude? project,
  }) {
    return ScriptTriggerInclude._(project: project);
  }

  static ScriptTriggerIncludeList includeList({
    _isd.WhereExpressionBuilder<ScriptTriggerTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptTriggerTable>? orderBy,
    _isd.OrderByListBuilder<ScriptTriggerTable>? orderByList,
    ScriptTriggerInclude? include,
  }) {
    return ScriptTriggerIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptTrigger.t),
      orderByList: orderByList?.call(ScriptTrigger.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedScriptTrigger$project extends _iss.UndefinedSentinel
    implements _i810rwvy.ScriptProject {
  const _UndefinedScriptTrigger$project();
}

class _ScriptTriggerImpl extends ScriptTrigger {
  _ScriptTriggerImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue projectId,
    _i810rwvy.ScriptProject? project,
    required _i810rwvy.TriggerKind kind,
    required String functionName,
    String? scheduleJson,
    required _iss.UuidValue runAsUserId,
    bool? enabled,
    String? optionsJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         projectId: projectId,
         project: project,
         kind: kind,
         functionName: functionName,
         scheduleJson: scheduleJson,
         runAsUserId: runAsUserId,
         enabled: enabled,
         optionsJson: optionsJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ScriptTrigger]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  ScriptTrigger copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? projectId,
    _i810rwvy.ScriptProject? project = const _UndefinedScriptTrigger$project(),
    _i810rwvy.TriggerKind? kind,
    String? functionName,
    Object? scheduleJson = _Undefined,
    _iss.UuidValue? runAsUserId,
    bool? enabled,
    Object? optionsJson = _Undefined,
    DateTime? createdAt,
  }) {
    return ScriptTrigger(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      projectId: projectId ?? this.projectId,
      project: project is _iss.UndefinedSentinel
          ? this.project?.copyWith()
          : project,
      kind: kind ?? this.kind,
      functionName: functionName ?? this.functionName,
      scheduleJson: scheduleJson is String? ? scheduleJson : this.scheduleJson,
      runAsUserId: runAsUserId ?? this.runAsUserId,
      enabled: enabled ?? this.enabled,
      optionsJson: optionsJson is String? ? optionsJson : this.optionsJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ScriptTriggerUpdateTable extends _isd.UpdateTable<ScriptTriggerTable> {
  ScriptTriggerUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> projectId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.projectId, value);

  _isd.ColumnValue<_i810rwvy.TriggerKind, _i810rwvy.TriggerKind> kind(
    _i810rwvy.TriggerKind value,
  ) => _isd.ColumnValue(table.kind, value);

  _isd.ColumnValue<String, String> functionName(String value) =>
      _isd.ColumnValue(table.functionName, value);

  _isd.ColumnValue<String, String> scheduleJson(String? value) =>
      _isd.ColumnValue(table.scheduleJson, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> runAsUserId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.runAsUserId, value);

  _isd.ColumnValue<bool, bool> enabled(bool value) =>
      _isd.ColumnValue(table.enabled, value);

  _isd.ColumnValue<String, String> optionsJson(String? value) =>
      _isd.ColumnValue(table.optionsJson, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class ScriptTriggerTable extends _isd.Table<_iss.UuidValue> {
  ScriptTriggerTable({super.tableRelation})
    : super(tableName: 'script_trigger') {
    updateTable = ScriptTriggerUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    projectId = _isd.ColumnUuid('projectId', this);
    kind = _isd.ColumnEnum('kind', this, _isd.EnumSerialization.byName);
    functionName = _isd.ColumnString('functionName', this);
    scheduleJson = _isd.ColumnString('scheduleJson', this);
    runAsUserId = _isd.ColumnUuid('runAsUserId', this);
    enabled = _isd.ColumnBool('enabled', this, hasDefault: true);
    optionsJson = _isd.ColumnString('optionsJson', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final ScriptTriggerUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid projectId;

  _i810rwvy.ScriptProjectTable? _project;

  late final _isd.ColumnEnum<_i810rwvy.TriggerKind> kind;

  late final _isd.ColumnString functionName;

  late final _isd.ColumnString scheduleJson;

  /// Installer; must keep edit access.
  late final _isd.ColumnUuid runAsUserId;

  late final _isd.ColumnBool enabled;

  /// {fireForMcp, notify}.
  late final _isd.ColumnString optionsJson;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.ScriptProjectTable get project {
    if (_project != null) return _project!;
    _project = _isd.createRelationTable(
      relationFieldName: 'project',
      field: ScriptTrigger.t.projectId,
      foreignField: _i810rwvy.ScriptProject.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.ScriptProjectTable(tableRelation: foreignTableRelation),
    );
    return _project!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    projectId,
    kind,
    functionName,
    scheduleJson,
    runAsUserId,
    enabled,
    optionsJson,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'project') {
      return project;
    }
    return null;
  }
}

class ScriptTriggerInclude extends _isd.IncludeObject {
  ScriptTriggerInclude._({_i810rwvy.ScriptProjectInclude? project}) {
    _project = project;
  }

  _i810rwvy.ScriptProjectInclude? _project;

  @override
  Map<String, _isd.Include?> get includes => {'project': _project};

  @override
  _isd.Table<_iss.UuidValue> get table => ScriptTrigger.t;
}

class ScriptTriggerIncludeList extends _isd.IncludeList {
  ScriptTriggerIncludeList._({
    _isd.WhereExpressionBuilder<ScriptTriggerTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ScriptTrigger.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => ScriptTrigger.t;
}

class ScriptTriggerRepository {
  const ScriptTriggerRepository._();

  final attachRow = const ScriptTriggerAttachRowRepository._();

  /// Returns a list of [ScriptTrigger]s matching the given query parameters.
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
  Future<List<ScriptTrigger>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptTriggerTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptTriggerTable>? orderBy,
    _isd.OrderByListBuilder<ScriptTriggerTable>? orderByList,
    _isd.Transaction? transaction,
    ScriptTriggerInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ScriptTrigger>(
      where: where?.call(ScriptTrigger.t),
      orderBy: orderBy?.call(ScriptTrigger.t),
      orderByList: orderByList?.call(ScriptTrigger.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ScriptTrigger]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ScriptTrigger.t`.
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
  _ida.Stream<List<ScriptTrigger>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptTriggerTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptTriggerTable>? orderBy,
    _isd.OrderByListBuilder<ScriptTriggerTable>? orderByList,
    ScriptTriggerInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ScriptTrigger>(
      where: where?.call(ScriptTrigger.t),
      orderBy: orderBy?.call(ScriptTrigger.t),
      orderByList: orderByList?.call(ScriptTrigger.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ScriptTrigger] matching the given query parameters.
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
  Future<ScriptTrigger?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptTriggerTable>? where,
    int? offset,
    _isd.OrderByBuilder<ScriptTriggerTable>? orderBy,
    _isd.OrderByListBuilder<ScriptTriggerTable>? orderByList,
    _isd.Transaction? transaction,
    ScriptTriggerInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ScriptTrigger>(
      where: where?.call(ScriptTrigger.t),
      orderBy: orderBy?.call(ScriptTrigger.t),
      orderByList: orderByList?.call(ScriptTrigger.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ScriptTrigger] by its [id] or null if no such row exists.
  Future<ScriptTrigger?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    ScriptTriggerInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ScriptTrigger>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ScriptTrigger]s in the list and returns the inserted rows.
  ///
  /// The returned [ScriptTrigger]s will have their `id` fields set.
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
  Future<List<ScriptTrigger>> insert(
    _isd.DatabaseSession session,
    List<ScriptTrigger> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ScriptTrigger>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ScriptTrigger] and returns the inserted row.
  ///
  /// The returned [ScriptTrigger] will have its `id` field set.
  Future<ScriptTrigger> insertRow(
    _isd.DatabaseSession session,
    ScriptTrigger row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<ScriptTrigger>(row, transaction: transaction);
  }

  /// Upserts all [ScriptTrigger]s in the list and returns the resulting rows.
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
  /// The returned [ScriptTrigger]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptTrigger>> upsert(
    _isd.DatabaseSession session,
    List<ScriptTrigger> rows, {
    required _isd.ColumnSelections<ScriptTriggerTable> conflictColumns,
    _isd.ColumnSelections<ScriptTriggerTable>? updateColumns,
    _isd.WhereExpressionBuilder<ScriptTriggerTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ScriptTrigger>(
      rows,
      conflictColumns: conflictColumns(ScriptTrigger.t),
      updateColumns: updateColumns?.call(ScriptTrigger.t),
      updateWhere: updateWhere?.call(ScriptTrigger.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ScriptTrigger] and returns the resulting row.
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
  /// The returned [ScriptTrigger] will have its `id` field set.
  Future<ScriptTrigger?> upsertRow(
    _isd.DatabaseSession session,
    ScriptTrigger row, {
    required _isd.ColumnSelections<ScriptTriggerTable> conflictColumns,
    _isd.ColumnSelections<ScriptTriggerTable>? updateColumns,
    _isd.WhereExpressionBuilder<ScriptTriggerTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ScriptTrigger>(
      row,
      conflictColumns: conflictColumns(ScriptTrigger.t),
      updateColumns: updateColumns?.call(ScriptTrigger.t),
      updateWhere: updateWhere?.call(ScriptTrigger.t),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptTrigger]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptTrigger>> update(
    _isd.DatabaseSession session,
    List<ScriptTrigger> rows, {
    _isd.ColumnSelections<ScriptTriggerTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ScriptTrigger>(
      rows,
      columns: columns?.call(ScriptTrigger.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ScriptTrigger]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ScriptTrigger> updateRow(
    _isd.DatabaseSession session,
    ScriptTrigger row, {
    _isd.ColumnSelections<ScriptTriggerTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<ScriptTrigger>(
      row,
      columns: columns?.call(ScriptTrigger.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ScriptTrigger] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ScriptTrigger?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<ScriptTriggerUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<ScriptTrigger>(
      id,
      columnValues: columnValues(ScriptTrigger.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptTrigger]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptTrigger>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<ScriptTriggerUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<ScriptTriggerTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptTriggerTable>? orderBy,
    _isd.OrderByListBuilder<ScriptTriggerTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ScriptTrigger>(
      columnValues: columnValues(ScriptTrigger.t.updateTable),
      where: where(ScriptTrigger.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptTrigger.t),
      orderByList: orderByList?.call(ScriptTrigger.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ScriptTrigger]s in the list and returns the deleted rows.
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
  Future<List<ScriptTrigger>> delete(
    _isd.DatabaseSession session,
    List<ScriptTrigger> rows, {
    _isd.OrderByBuilder<ScriptTriggerTable>? orderBy,
    _isd.OrderByListBuilder<ScriptTriggerTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ScriptTrigger>(
      rows,
      orderBy: orderBy?.call(ScriptTrigger.t),
      orderByList: orderByList?.call(ScriptTrigger.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ScriptTrigger].
  Future<ScriptTrigger> deleteRow(
    _isd.DatabaseSession session,
    ScriptTrigger row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ScriptTrigger>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptTrigger>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ScriptTriggerTable> where,
    _isd.OrderByBuilder<ScriptTriggerTable>? orderBy,
    _isd.OrderByListBuilder<ScriptTriggerTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ScriptTrigger>(
      where: where(ScriptTrigger.t),
      orderBy: orderBy?.call(ScriptTrigger.t),
      orderByList: orderByList?.call(ScriptTrigger.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptTriggerTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<ScriptTrigger>(
      where: where?.call(ScriptTrigger.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ScriptTrigger] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ScriptTriggerTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ScriptTrigger>(
      where: where(ScriptTrigger.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class ScriptTriggerAttachRowRepository {
  const ScriptTriggerAttachRowRepository._();

  /// Creates a relation between the given [ScriptTrigger] and [ScriptProject]
  /// by setting the [ScriptTrigger]'s foreign key `projectId` to refer to the [ScriptProject].
  Future<void> project(
    _isd.DatabaseSession session,
    ScriptTrigger scriptTrigger,
    _i810rwvy.ScriptProject project, {
    _isd.Transaction? transaction,
  }) async {
    if (scriptTrigger.id == null) {
      throw ArgumentError.notNull('scriptTrigger.id');
    }
    if (project.id == null) {
      throw ArgumentError.notNull('project.id');
    }

    var $scriptTrigger = scriptTrigger.copyWith(projectId: project.id);
    await session.db.updateRow<ScriptTrigger>(
      $scriptTrigger,
      columns: [ScriptTrigger.t.projectId],
      transaction: transaction,
    );
  }
}
