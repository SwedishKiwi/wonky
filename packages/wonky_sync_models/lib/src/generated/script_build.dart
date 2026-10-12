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

/// Compilation result, written by the server; id = SheetsIds.scriptBuildId(projectId).
abstract class ScriptBuild
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  ScriptBuild._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.projectId,
    this.project,
    _i810rwvy.ScriptBuildStatus? status,
    required this.sourceHash,
    this.bytecodeFileUuid,
    required this.diagnosticsJson,
    required this.exportsJson,
    int? apiVersion,
    String? compilerVersion,
    this.requestedBy,
    this.lastGoodSourceHash,
    this.lastGoodBytecodeFileUuid,
    this.lastGoodExportsJson,
    this.lastGoodBuiltAt,
    this.positionsFileUuid,
    required this.builtAt,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       status = status ?? _i810rwvy.ScriptBuildStatus.ok,
       apiVersion = apiVersion ?? 1,
       compilerVersion = compilerVersion ?? '',
       createdAt = createdAt ?? DateTime.now();

  factory ScriptBuild({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue projectId,
    _i810rwvy.ScriptProject? project,
    _i810rwvy.ScriptBuildStatus? status,
    required String sourceHash,
    _iss.UuidValue? bytecodeFileUuid,
    required String diagnosticsJson,
    required String exportsJson,
    int? apiVersion,
    String? compilerVersion,
    _iss.UuidValue? requestedBy,
    String? lastGoodSourceHash,
    _iss.UuidValue? lastGoodBytecodeFileUuid,
    String? lastGoodExportsJson,
    DateTime? lastGoodBuiltAt,
    _iss.UuidValue? positionsFileUuid,
    required DateTime builtAt,
    DateTime? createdAt,
  }) = _ScriptBuildImpl;

  factory ScriptBuild.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScriptBuild(
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
      status: jsonSerialization['status'] == null
          ? null
          : _i810rwvy.ScriptBuildStatus.fromJson(
              (jsonSerialization['status'] as String),
            ),
      sourceHash: jsonSerialization['sourceHash'] as String,
      bytecodeFileUuid: jsonSerialization['bytecodeFileUuid'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['bytecodeFileUuid'],
            ),
      diagnosticsJson: jsonSerialization['diagnosticsJson'] as String,
      exportsJson: jsonSerialization['exportsJson'] as String,
      apiVersion: jsonSerialization['apiVersion'] as int?,
      compilerVersion: jsonSerialization['compilerVersion'] as String?,
      requestedBy: jsonSerialization['requestedBy'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['requestedBy'],
            ),
      lastGoodSourceHash: jsonSerialization['lastGoodSourceHash'] as String?,
      lastGoodBytecodeFileUuid:
          jsonSerialization['lastGoodBytecodeFileUuid'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['lastGoodBytecodeFileUuid'],
            ),
      lastGoodExportsJson: jsonSerialization['lastGoodExportsJson'] as String?,
      lastGoodBuiltAt: jsonSerialization['lastGoodBuiltAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastGoodBuiltAt'],
            ),
      positionsFileUuid: jsonSerialization['positionsFileUuid'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['positionsFileUuid'],
            ),
      builtAt: _iss.DateTimeJsonExtension.fromJson(
        jsonSerialization['builtAt'],
      ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = ScriptBuildTable();

  static const db = ScriptBuildRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue projectId;

  _i810rwvy.ScriptProject? project;

  _i810rwvy.ScriptBuildStatus status;

  String sourceHash;

  /// EVC bytecode in cloud storage (null if errors).
  _iss.UuidValue? bytecodeFileUuid;

  String diagnosticsJson;

  String exportsJson;

  int apiVersion;

  String compilerVersion;

  _iss.UuidValue? requestedBy;

  String? lastGoodSourceHash;

  _iss.UuidValue? lastGoodBytecodeFileUuid;

  String? lastGoodExportsJson;

  DateTime? lastGoodBuiltAt;

  _iss.UuidValue? positionsFileUuid;

  DateTime builtAt;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [ScriptBuild]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  ScriptBuild copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? projectId,
    _i810rwvy.ScriptProject? project = const _UndefinedScriptBuild$project(),
    _i810rwvy.ScriptBuildStatus? status,
    String? sourceHash,
    _iss.UuidValue? bytecodeFileUuid = const _iss.$UndefinedUuidValue(),
    String? diagnosticsJson,
    String? exportsJson,
    int? apiVersion,
    String? compilerVersion,
    _iss.UuidValue? requestedBy = const _iss.$UndefinedUuidValue(),
    String? lastGoodSourceHash,
    _iss.UuidValue? lastGoodBytecodeFileUuid = const _iss.$UndefinedUuidValue(),
    String? lastGoodExportsJson,
    DateTime? lastGoodBuiltAt = const _iss.$UndefinedDateTime(),
    _iss.UuidValue? positionsFileUuid = const _iss.$UndefinedUuidValue(),
    DateTime? builtAt,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScriptBuild',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'projectId': projectId.toJson(),
      if (project != null) 'project': project?.toJson(),
      'status': status.toJson(),
      'sourceHash': sourceHash,
      if (bytecodeFileUuid != null)
        'bytecodeFileUuid': bytecodeFileUuid?.toJson(),
      'diagnosticsJson': diagnosticsJson,
      'exportsJson': exportsJson,
      'apiVersion': apiVersion,
      'compilerVersion': compilerVersion,
      if (requestedBy != null) 'requestedBy': requestedBy?.toJson(),
      if (lastGoodSourceHash != null) 'lastGoodSourceHash': lastGoodSourceHash,
      if (lastGoodBytecodeFileUuid != null)
        'lastGoodBytecodeFileUuid': lastGoodBytecodeFileUuid?.toJson(),
      if (lastGoodExportsJson != null)
        'lastGoodExportsJson': lastGoodExportsJson,
      if (lastGoodBuiltAt != null) 'lastGoodBuiltAt': lastGoodBuiltAt?.toJson(),
      if (positionsFileUuid != null)
        'positionsFileUuid': positionsFileUuid?.toJson(),
      'builtAt': builtAt.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ScriptBuild',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'projectId': projectId.toJson(),
      if (project != null) 'project': project?.toJsonForProtocol(),
      'status': status.toJson(),
      'sourceHash': sourceHash,
      if (bytecodeFileUuid != null)
        'bytecodeFileUuid': bytecodeFileUuid?.toJson(),
      'diagnosticsJson': diagnosticsJson,
      'exportsJson': exportsJson,
      'apiVersion': apiVersion,
      'compilerVersion': compilerVersion,
      if (requestedBy != null) 'requestedBy': requestedBy?.toJson(),
      if (lastGoodSourceHash != null) 'lastGoodSourceHash': lastGoodSourceHash,
      if (lastGoodBytecodeFileUuid != null)
        'lastGoodBytecodeFileUuid': lastGoodBytecodeFileUuid?.toJson(),
      if (lastGoodExportsJson != null)
        'lastGoodExportsJson': lastGoodExportsJson,
      if (lastGoodBuiltAt != null) 'lastGoodBuiltAt': lastGoodBuiltAt?.toJson(),
      if (positionsFileUuid != null)
        'positionsFileUuid': positionsFileUuid?.toJson(),
      'builtAt': builtAt.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static ScriptBuildInclude include({_i810rwvy.ScriptProjectInclude? project}) {
    return ScriptBuildInclude._(project: project);
  }

  static ScriptBuildIncludeList includeList({
    _isd.WhereExpressionBuilder<ScriptBuildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptBuildTable>? orderBy,
    _isd.OrderByListBuilder<ScriptBuildTable>? orderByList,
    ScriptBuildInclude? include,
  }) {
    return ScriptBuildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptBuild.t),
      orderByList: orderByList?.call(ScriptBuild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedScriptBuild$project extends _iss.UndefinedSentinel
    implements _i810rwvy.ScriptProject {
  const _UndefinedScriptBuild$project();
}

class _ScriptBuildImpl extends ScriptBuild {
  _ScriptBuildImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue projectId,
    _i810rwvy.ScriptProject? project,
    _i810rwvy.ScriptBuildStatus? status,
    required String sourceHash,
    _iss.UuidValue? bytecodeFileUuid,
    required String diagnosticsJson,
    required String exportsJson,
    int? apiVersion,
    String? compilerVersion,
    _iss.UuidValue? requestedBy,
    String? lastGoodSourceHash,
    _iss.UuidValue? lastGoodBytecodeFileUuid,
    String? lastGoodExportsJson,
    DateTime? lastGoodBuiltAt,
    _iss.UuidValue? positionsFileUuid,
    required DateTime builtAt,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         projectId: projectId,
         project: project,
         status: status,
         sourceHash: sourceHash,
         bytecodeFileUuid: bytecodeFileUuid,
         diagnosticsJson: diagnosticsJson,
         exportsJson: exportsJson,
         apiVersion: apiVersion,
         compilerVersion: compilerVersion,
         requestedBy: requestedBy,
         lastGoodSourceHash: lastGoodSourceHash,
         lastGoodBytecodeFileUuid: lastGoodBytecodeFileUuid,
         lastGoodExportsJson: lastGoodExportsJson,
         lastGoodBuiltAt: lastGoodBuiltAt,
         positionsFileUuid: positionsFileUuid,
         builtAt: builtAt,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ScriptBuild]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  ScriptBuild copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? projectId,
    _i810rwvy.ScriptProject? project = const _UndefinedScriptBuild$project(),
    _i810rwvy.ScriptBuildStatus? status,
    String? sourceHash,
    _iss.UuidValue? bytecodeFileUuid = const _iss.$UndefinedUuidValue(),
    String? diagnosticsJson,
    String? exportsJson,
    int? apiVersion,
    String? compilerVersion,
    _iss.UuidValue? requestedBy = const _iss.$UndefinedUuidValue(),
    Object? lastGoodSourceHash = _Undefined,
    _iss.UuidValue? lastGoodBytecodeFileUuid = const _iss.$UndefinedUuidValue(),
    Object? lastGoodExportsJson = _Undefined,
    DateTime? lastGoodBuiltAt = const _iss.$UndefinedDateTime(),
    _iss.UuidValue? positionsFileUuid = const _iss.$UndefinedUuidValue(),
    DateTime? builtAt,
    DateTime? createdAt,
  }) {
    return ScriptBuild(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      projectId: projectId ?? this.projectId,
      project: project is _iss.UndefinedSentinel
          ? this.project?.copyWith()
          : project,
      status: status ?? this.status,
      sourceHash: sourceHash ?? this.sourceHash,
      bytecodeFileUuid: bytecodeFileUuid is _iss.UndefinedSentinel
          ? this.bytecodeFileUuid
          : bytecodeFileUuid,
      diagnosticsJson: diagnosticsJson ?? this.diagnosticsJson,
      exportsJson: exportsJson ?? this.exportsJson,
      apiVersion: apiVersion ?? this.apiVersion,
      compilerVersion: compilerVersion ?? this.compilerVersion,
      requestedBy: requestedBy is _iss.UndefinedSentinel
          ? this.requestedBy
          : requestedBy,
      lastGoodSourceHash: lastGoodSourceHash is String?
          ? lastGoodSourceHash
          : this.lastGoodSourceHash,
      lastGoodBytecodeFileUuid:
          lastGoodBytecodeFileUuid is _iss.UndefinedSentinel
          ? this.lastGoodBytecodeFileUuid
          : lastGoodBytecodeFileUuid,
      lastGoodExportsJson: lastGoodExportsJson is String?
          ? lastGoodExportsJson
          : this.lastGoodExportsJson,
      lastGoodBuiltAt: lastGoodBuiltAt is _iss.UndefinedSentinel
          ? this.lastGoodBuiltAt
          : lastGoodBuiltAt,
      positionsFileUuid: positionsFileUuid is _iss.UndefinedSentinel
          ? this.positionsFileUuid
          : positionsFileUuid,
      builtAt: builtAt ?? this.builtAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ScriptBuildUpdateTable extends _isd.UpdateTable<ScriptBuildTable> {
  ScriptBuildUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> projectId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.projectId, value);

  _isd.ColumnValue<_i810rwvy.ScriptBuildStatus, _i810rwvy.ScriptBuildStatus>
  status(_i810rwvy.ScriptBuildStatus value) =>
      _isd.ColumnValue(table.status, value);

  _isd.ColumnValue<String, String> sourceHash(String value) =>
      _isd.ColumnValue(table.sourceHash, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> bytecodeFileUuid(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.bytecodeFileUuid, value);

  _isd.ColumnValue<String, String> diagnosticsJson(String value) =>
      _isd.ColumnValue(table.diagnosticsJson, value);

  _isd.ColumnValue<String, String> exportsJson(String value) =>
      _isd.ColumnValue(table.exportsJson, value);

  _isd.ColumnValue<int, int> apiVersion(int value) =>
      _isd.ColumnValue(table.apiVersion, value);

  _isd.ColumnValue<String, String> compilerVersion(String value) =>
      _isd.ColumnValue(table.compilerVersion, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> requestedBy(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.requestedBy, value);

  _isd.ColumnValue<String, String> lastGoodSourceHash(String? value) =>
      _isd.ColumnValue(table.lastGoodSourceHash, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> lastGoodBytecodeFileUuid(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.lastGoodBytecodeFileUuid, value);

  _isd.ColumnValue<String, String> lastGoodExportsJson(String? value) =>
      _isd.ColumnValue(table.lastGoodExportsJson, value);

  _isd.ColumnValue<DateTime, DateTime> lastGoodBuiltAt(DateTime? value) =>
      _isd.ColumnValue(table.lastGoodBuiltAt, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> positionsFileUuid(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.positionsFileUuid, value);

  _isd.ColumnValue<DateTime, DateTime> builtAt(DateTime value) =>
      _isd.ColumnValue(table.builtAt, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class ScriptBuildTable extends _isd.Table<_iss.UuidValue> {
  ScriptBuildTable({super.tableRelation}) : super(tableName: 'script_build') {
    updateTable = ScriptBuildUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    projectId = _isd.ColumnUuid('projectId', this);
    status = _isd.ColumnEnum(
      'status',
      this,
      _isd.EnumSerialization.byName,
      hasDefault: true,
    );
    sourceHash = _isd.ColumnString('sourceHash', this);
    bytecodeFileUuid = _isd.ColumnUuid('bytecodeFileUuid', this);
    diagnosticsJson = _isd.ColumnString('diagnosticsJson', this);
    exportsJson = _isd.ColumnString('exportsJson', this);
    apiVersion = _isd.ColumnInt('apiVersion', this, hasDefault: true);
    compilerVersion = _isd.ColumnString(
      'compilerVersion',
      this,
      hasDefault: true,
    );
    requestedBy = _isd.ColumnUuid('requestedBy', this);
    lastGoodSourceHash = _isd.ColumnString('lastGoodSourceHash', this);
    lastGoodBytecodeFileUuid = _isd.ColumnUuid(
      'lastGoodBytecodeFileUuid',
      this,
    );
    lastGoodExportsJson = _isd.ColumnString('lastGoodExportsJson', this);
    lastGoodBuiltAt = _isd.ColumnDateTime('lastGoodBuiltAt', this);
    positionsFileUuid = _isd.ColumnUuid('positionsFileUuid', this);
    builtAt = _isd.ColumnDateTime('builtAt', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final ScriptBuildUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid projectId;

  _i810rwvy.ScriptProjectTable? _project;

  late final _isd.ColumnEnum<_i810rwvy.ScriptBuildStatus> status;

  late final _isd.ColumnString sourceHash;

  /// EVC bytecode in cloud storage (null if errors).
  late final _isd.ColumnUuid bytecodeFileUuid;

  late final _isd.ColumnString diagnosticsJson;

  late final _isd.ColumnString exportsJson;

  late final _isd.ColumnInt apiVersion;

  late final _isd.ColumnString compilerVersion;

  late final _isd.ColumnUuid requestedBy;

  late final _isd.ColumnString lastGoodSourceHash;

  late final _isd.ColumnUuid lastGoodBytecodeFileUuid;

  late final _isd.ColumnString lastGoodExportsJson;

  late final _isd.ColumnDateTime lastGoodBuiltAt;

  late final _isd.ColumnUuid positionsFileUuid;

  late final _isd.ColumnDateTime builtAt;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.ScriptProjectTable get project {
    if (_project != null) return _project!;
    _project = _isd.createRelationTable(
      relationFieldName: 'project',
      field: ScriptBuild.t.projectId,
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
    status,
    sourceHash,
    bytecodeFileUuid,
    diagnosticsJson,
    exportsJson,
    apiVersion,
    compilerVersion,
    requestedBy,
    lastGoodSourceHash,
    lastGoodBytecodeFileUuid,
    lastGoodExportsJson,
    lastGoodBuiltAt,
    positionsFileUuid,
    builtAt,
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

class ScriptBuildInclude extends _isd.IncludeObject {
  ScriptBuildInclude._({_i810rwvy.ScriptProjectInclude? project}) {
    _project = project;
  }

  _i810rwvy.ScriptProjectInclude? _project;

  @override
  Map<String, _isd.Include?> get includes => {'project': _project};

  @override
  _isd.Table<_iss.UuidValue> get table => ScriptBuild.t;
}

class ScriptBuildIncludeList extends _isd.IncludeList {
  ScriptBuildIncludeList._({
    _isd.WhereExpressionBuilder<ScriptBuildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ScriptBuild.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => ScriptBuild.t;
}

class ScriptBuildRepository {
  const ScriptBuildRepository._();

  final attachRow = const ScriptBuildAttachRowRepository._();

  /// Returns a list of [ScriptBuild]s matching the given query parameters.
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
  Future<List<ScriptBuild>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptBuildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptBuildTable>? orderBy,
    _isd.OrderByListBuilder<ScriptBuildTable>? orderByList,
    _isd.Transaction? transaction,
    ScriptBuildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ScriptBuild>(
      where: where?.call(ScriptBuild.t),
      orderBy: orderBy?.call(ScriptBuild.t),
      orderByList: orderByList?.call(ScriptBuild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ScriptBuild]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ScriptBuild.t`.
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
  _ida.Stream<List<ScriptBuild>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptBuildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptBuildTable>? orderBy,
    _isd.OrderByListBuilder<ScriptBuildTable>? orderByList,
    ScriptBuildInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ScriptBuild>(
      where: where?.call(ScriptBuild.t),
      orderBy: orderBy?.call(ScriptBuild.t),
      orderByList: orderByList?.call(ScriptBuild.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ScriptBuild] matching the given query parameters.
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
  Future<ScriptBuild?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptBuildTable>? where,
    int? offset,
    _isd.OrderByBuilder<ScriptBuildTable>? orderBy,
    _isd.OrderByListBuilder<ScriptBuildTable>? orderByList,
    _isd.Transaction? transaction,
    ScriptBuildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ScriptBuild>(
      where: where?.call(ScriptBuild.t),
      orderBy: orderBy?.call(ScriptBuild.t),
      orderByList: orderByList?.call(ScriptBuild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ScriptBuild] by its [id] or null if no such row exists.
  Future<ScriptBuild?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    ScriptBuildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ScriptBuild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ScriptBuild]s in the list and returns the inserted rows.
  ///
  /// The returned [ScriptBuild]s will have their `id` fields set.
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
  Future<List<ScriptBuild>> insert(
    _isd.DatabaseSession session,
    List<ScriptBuild> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ScriptBuild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ScriptBuild] and returns the inserted row.
  ///
  /// The returned [ScriptBuild] will have its `id` field set.
  Future<ScriptBuild> insertRow(
    _isd.DatabaseSession session,
    ScriptBuild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<ScriptBuild>(row, transaction: transaction);
  }

  /// Upserts all [ScriptBuild]s in the list and returns the resulting rows.
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
  /// The returned [ScriptBuild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptBuild>> upsert(
    _isd.DatabaseSession session,
    List<ScriptBuild> rows, {
    required _isd.ColumnSelections<ScriptBuildTable> conflictColumns,
    _isd.ColumnSelections<ScriptBuildTable>? updateColumns,
    _isd.WhereExpressionBuilder<ScriptBuildTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ScriptBuild>(
      rows,
      conflictColumns: conflictColumns(ScriptBuild.t),
      updateColumns: updateColumns?.call(ScriptBuild.t),
      updateWhere: updateWhere?.call(ScriptBuild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ScriptBuild] and returns the resulting row.
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
  /// The returned [ScriptBuild] will have its `id` field set.
  Future<ScriptBuild?> upsertRow(
    _isd.DatabaseSession session,
    ScriptBuild row, {
    required _isd.ColumnSelections<ScriptBuildTable> conflictColumns,
    _isd.ColumnSelections<ScriptBuildTable>? updateColumns,
    _isd.WhereExpressionBuilder<ScriptBuildTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ScriptBuild>(
      row,
      conflictColumns: conflictColumns(ScriptBuild.t),
      updateColumns: updateColumns?.call(ScriptBuild.t),
      updateWhere: updateWhere?.call(ScriptBuild.t),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptBuild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptBuild>> update(
    _isd.DatabaseSession session,
    List<ScriptBuild> rows, {
    _isd.ColumnSelections<ScriptBuildTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ScriptBuild>(
      rows,
      columns: columns?.call(ScriptBuild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ScriptBuild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ScriptBuild> updateRow(
    _isd.DatabaseSession session,
    ScriptBuild row, {
    _isd.ColumnSelections<ScriptBuildTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<ScriptBuild>(
      row,
      columns: columns?.call(ScriptBuild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ScriptBuild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ScriptBuild?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<ScriptBuildUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<ScriptBuild>(
      id,
      columnValues: columnValues(ScriptBuild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptBuild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptBuild>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<ScriptBuildUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<ScriptBuildTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptBuildTable>? orderBy,
    _isd.OrderByListBuilder<ScriptBuildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ScriptBuild>(
      columnValues: columnValues(ScriptBuild.t.updateTable),
      where: where(ScriptBuild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptBuild.t),
      orderByList: orderByList?.call(ScriptBuild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ScriptBuild]s in the list and returns the deleted rows.
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
  Future<List<ScriptBuild>> delete(
    _isd.DatabaseSession session,
    List<ScriptBuild> rows, {
    _isd.OrderByBuilder<ScriptBuildTable>? orderBy,
    _isd.OrderByListBuilder<ScriptBuildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ScriptBuild>(
      rows,
      orderBy: orderBy?.call(ScriptBuild.t),
      orderByList: orderByList?.call(ScriptBuild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ScriptBuild].
  Future<ScriptBuild> deleteRow(
    _isd.DatabaseSession session,
    ScriptBuild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ScriptBuild>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptBuild>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ScriptBuildTable> where,
    _isd.OrderByBuilder<ScriptBuildTable>? orderBy,
    _isd.OrderByListBuilder<ScriptBuildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ScriptBuild>(
      where: where(ScriptBuild.t),
      orderBy: orderBy?.call(ScriptBuild.t),
      orderByList: orderByList?.call(ScriptBuild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptBuildTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<ScriptBuild>(
      where: where?.call(ScriptBuild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ScriptBuild] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ScriptBuildTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ScriptBuild>(
      where: where(ScriptBuild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class ScriptBuildAttachRowRepository {
  const ScriptBuildAttachRowRepository._();

  /// Creates a relation between the given [ScriptBuild] and [ScriptProject]
  /// by setting the [ScriptBuild]'s foreign key `projectId` to refer to the [ScriptProject].
  Future<void> project(
    _isd.DatabaseSession session,
    ScriptBuild scriptBuild,
    _i810rwvy.ScriptProject project, {
    _isd.Transaction? transaction,
  }) async {
    if (scriptBuild.id == null) {
      throw ArgumentError.notNull('scriptBuild.id');
    }
    if (project.id == null) {
      throw ArgumentError.notNull('project.id');
    }

    var $scriptBuild = scriptBuild.copyWith(projectId: project.id);
    await session.db.updateRow<ScriptBuild>(
      $scriptBuild,
      columns: [ScriptBuild.t.projectId],
      transaction: transaction,
    );
  }
}
