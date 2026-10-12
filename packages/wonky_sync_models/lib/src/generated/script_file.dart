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

/// A Dart source file of a script project (whole-file LWW).
abstract class ScriptFile
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  ScriptFile._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.projectId,
    this.project,
    required this.name,
    required this.sortKey,
    required this.source,
    required this.contentHash,
    required this.updatedBy,
    required this.updatedAt,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory ScriptFile({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue projectId,
    _i810rwvy.ScriptProject? project,
    required String name,
    required String sortKey,
    required String source,
    required String contentHash,
    required _iss.UuidValue updatedBy,
    required DateTime updatedAt,
    DateTime? createdAt,
  }) = _ScriptFileImpl;

  factory ScriptFile.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScriptFile(
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
      name: jsonSerialization['name'] as String,
      sortKey: jsonSerialization['sortKey'] as String,
      source: jsonSerialization['source'] as String,
      contentHash: jsonSerialization['contentHash'] as String,
      updatedBy: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['updatedBy'],
      ),
      updatedAt: _iss.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = ScriptFileTable();

  static const db = ScriptFileRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue projectId;

  _i810rwvy.ScriptProject? project;

  String name;

  String sortKey;

  String source;

  /// sha256 hex of source.
  String contentHash;

  _iss.UuidValue updatedBy;

  DateTime updatedAt;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [ScriptFile]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  ScriptFile copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? projectId,
    _i810rwvy.ScriptProject? project = const _UndefinedScriptFile$project(),
    String? name,
    String? sortKey,
    String? source,
    String? contentHash,
    _iss.UuidValue? updatedBy,
    DateTime? updatedAt,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScriptFile',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'projectId': projectId.toJson(),
      if (project != null) 'project': project?.toJson(),
      'name': name,
      'sortKey': sortKey,
      'source': source,
      'contentHash': contentHash,
      'updatedBy': updatedBy.toJson(),
      'updatedAt': updatedAt.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ScriptFile',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'projectId': projectId.toJson(),
      if (project != null) 'project': project?.toJsonForProtocol(),
      'name': name,
      'sortKey': sortKey,
      'source': source,
      'contentHash': contentHash,
      'updatedBy': updatedBy.toJson(),
      'updatedAt': updatedAt.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static ScriptFileInclude include({_i810rwvy.ScriptProjectInclude? project}) {
    return ScriptFileInclude._(project: project);
  }

  static ScriptFileIncludeList includeList({
    _isd.WhereExpressionBuilder<ScriptFileTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptFileTable>? orderBy,
    _isd.OrderByListBuilder<ScriptFileTable>? orderByList,
    ScriptFileInclude? include,
  }) {
    return ScriptFileIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptFile.t),
      orderByList: orderByList?.call(ScriptFile.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedScriptFile$project extends _iss.UndefinedSentinel
    implements _i810rwvy.ScriptProject {
  const _UndefinedScriptFile$project();
}

class _ScriptFileImpl extends ScriptFile {
  _ScriptFileImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue projectId,
    _i810rwvy.ScriptProject? project,
    required String name,
    required String sortKey,
    required String source,
    required String contentHash,
    required _iss.UuidValue updatedBy,
    required DateTime updatedAt,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         projectId: projectId,
         project: project,
         name: name,
         sortKey: sortKey,
         source: source,
         contentHash: contentHash,
         updatedBy: updatedBy,
         updatedAt: updatedAt,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ScriptFile]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  ScriptFile copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? projectId,
    _i810rwvy.ScriptProject? project = const _UndefinedScriptFile$project(),
    String? name,
    String? sortKey,
    String? source,
    String? contentHash,
    _iss.UuidValue? updatedBy,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return ScriptFile(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      projectId: projectId ?? this.projectId,
      project: project is _iss.UndefinedSentinel
          ? this.project?.copyWith()
          : project,
      name: name ?? this.name,
      sortKey: sortKey ?? this.sortKey,
      source: source ?? this.source,
      contentHash: contentHash ?? this.contentHash,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ScriptFileUpdateTable extends _isd.UpdateTable<ScriptFileTable> {
  ScriptFileUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> projectId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.projectId, value);

  _isd.ColumnValue<String, String> name(String value) =>
      _isd.ColumnValue(table.name, value);

  _isd.ColumnValue<String, String> sortKey(String value) =>
      _isd.ColumnValue(table.sortKey, value);

  _isd.ColumnValue<String, String> source(String value) =>
      _isd.ColumnValue(table.source, value);

  _isd.ColumnValue<String, String> contentHash(String value) =>
      _isd.ColumnValue(table.contentHash, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> updatedBy(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.updatedBy, value);

  _isd.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _isd.ColumnValue(table.updatedAt, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class ScriptFileTable extends _isd.Table<_iss.UuidValue> {
  ScriptFileTable({super.tableRelation}) : super(tableName: 'script_file') {
    updateTable = ScriptFileUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    projectId = _isd.ColumnUuid('projectId', this);
    name = _isd.ColumnString('name', this);
    sortKey = _isd.ColumnString('sortKey', this);
    source = _isd.ColumnString('source', this);
    contentHash = _isd.ColumnString('contentHash', this);
    updatedBy = _isd.ColumnUuid('updatedBy', this);
    updatedAt = _isd.ColumnDateTime('updatedAt', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final ScriptFileUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid projectId;

  _i810rwvy.ScriptProjectTable? _project;

  late final _isd.ColumnString name;

  late final _isd.ColumnString sortKey;

  late final _isd.ColumnString source;

  /// sha256 hex of source.
  late final _isd.ColumnString contentHash;

  late final _isd.ColumnUuid updatedBy;

  late final _isd.ColumnDateTime updatedAt;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.ScriptProjectTable get project {
    if (_project != null) return _project!;
    _project = _isd.createRelationTable(
      relationFieldName: 'project',
      field: ScriptFile.t.projectId,
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
    name,
    sortKey,
    source,
    contentHash,
    updatedBy,
    updatedAt,
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

class ScriptFileInclude extends _isd.IncludeObject {
  ScriptFileInclude._({_i810rwvy.ScriptProjectInclude? project}) {
    _project = project;
  }

  _i810rwvy.ScriptProjectInclude? _project;

  @override
  Map<String, _isd.Include?> get includes => {'project': _project};

  @override
  _isd.Table<_iss.UuidValue> get table => ScriptFile.t;
}

class ScriptFileIncludeList extends _isd.IncludeList {
  ScriptFileIncludeList._({
    _isd.WhereExpressionBuilder<ScriptFileTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ScriptFile.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => ScriptFile.t;
}

class ScriptFileRepository {
  const ScriptFileRepository._();

  final attachRow = const ScriptFileAttachRowRepository._();

  /// Returns a list of [ScriptFile]s matching the given query parameters.
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
  Future<List<ScriptFile>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptFileTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptFileTable>? orderBy,
    _isd.OrderByListBuilder<ScriptFileTable>? orderByList,
    _isd.Transaction? transaction,
    ScriptFileInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ScriptFile>(
      where: where?.call(ScriptFile.t),
      orderBy: orderBy?.call(ScriptFile.t),
      orderByList: orderByList?.call(ScriptFile.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ScriptFile]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ScriptFile.t`.
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
  _ida.Stream<List<ScriptFile>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptFileTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptFileTable>? orderBy,
    _isd.OrderByListBuilder<ScriptFileTable>? orderByList,
    ScriptFileInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ScriptFile>(
      where: where?.call(ScriptFile.t),
      orderBy: orderBy?.call(ScriptFile.t),
      orderByList: orderByList?.call(ScriptFile.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ScriptFile] matching the given query parameters.
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
  Future<ScriptFile?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptFileTable>? where,
    int? offset,
    _isd.OrderByBuilder<ScriptFileTable>? orderBy,
    _isd.OrderByListBuilder<ScriptFileTable>? orderByList,
    _isd.Transaction? transaction,
    ScriptFileInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ScriptFile>(
      where: where?.call(ScriptFile.t),
      orderBy: orderBy?.call(ScriptFile.t),
      orderByList: orderByList?.call(ScriptFile.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ScriptFile] by its [id] or null if no such row exists.
  Future<ScriptFile?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    ScriptFileInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ScriptFile>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ScriptFile]s in the list and returns the inserted rows.
  ///
  /// The returned [ScriptFile]s will have their `id` fields set.
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
  Future<List<ScriptFile>> insert(
    _isd.DatabaseSession session,
    List<ScriptFile> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ScriptFile>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ScriptFile] and returns the inserted row.
  ///
  /// The returned [ScriptFile] will have its `id` field set.
  Future<ScriptFile> insertRow(
    _isd.DatabaseSession session,
    ScriptFile row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<ScriptFile>(row, transaction: transaction);
  }

  /// Upserts all [ScriptFile]s in the list and returns the resulting rows.
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
  /// The returned [ScriptFile]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptFile>> upsert(
    _isd.DatabaseSession session,
    List<ScriptFile> rows, {
    required _isd.ColumnSelections<ScriptFileTable> conflictColumns,
    _isd.ColumnSelections<ScriptFileTable>? updateColumns,
    _isd.WhereExpressionBuilder<ScriptFileTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ScriptFile>(
      rows,
      conflictColumns: conflictColumns(ScriptFile.t),
      updateColumns: updateColumns?.call(ScriptFile.t),
      updateWhere: updateWhere?.call(ScriptFile.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ScriptFile] and returns the resulting row.
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
  /// The returned [ScriptFile] will have its `id` field set.
  Future<ScriptFile?> upsertRow(
    _isd.DatabaseSession session,
    ScriptFile row, {
    required _isd.ColumnSelections<ScriptFileTable> conflictColumns,
    _isd.ColumnSelections<ScriptFileTable>? updateColumns,
    _isd.WhereExpressionBuilder<ScriptFileTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ScriptFile>(
      row,
      conflictColumns: conflictColumns(ScriptFile.t),
      updateColumns: updateColumns?.call(ScriptFile.t),
      updateWhere: updateWhere?.call(ScriptFile.t),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptFile]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptFile>> update(
    _isd.DatabaseSession session,
    List<ScriptFile> rows, {
    _isd.ColumnSelections<ScriptFileTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ScriptFile>(
      rows,
      columns: columns?.call(ScriptFile.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ScriptFile]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ScriptFile> updateRow(
    _isd.DatabaseSession session,
    ScriptFile row, {
    _isd.ColumnSelections<ScriptFileTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<ScriptFile>(
      row,
      columns: columns?.call(ScriptFile.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ScriptFile] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ScriptFile?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<ScriptFileUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<ScriptFile>(
      id,
      columnValues: columnValues(ScriptFile.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ScriptFile]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptFile>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<ScriptFileUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<ScriptFileTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ScriptFileTable>? orderBy,
    _isd.OrderByListBuilder<ScriptFileTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ScriptFile>(
      columnValues: columnValues(ScriptFile.t.updateTable),
      where: where(ScriptFile.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScriptFile.t),
      orderByList: orderByList?.call(ScriptFile.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ScriptFile]s in the list and returns the deleted rows.
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
  Future<List<ScriptFile>> delete(
    _isd.DatabaseSession session,
    List<ScriptFile> rows, {
    _isd.OrderByBuilder<ScriptFileTable>? orderBy,
    _isd.OrderByListBuilder<ScriptFileTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ScriptFile>(
      rows,
      orderBy: orderBy?.call(ScriptFile.t),
      orderByList: orderByList?.call(ScriptFile.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ScriptFile].
  Future<ScriptFile> deleteRow(
    _isd.DatabaseSession session,
    ScriptFile row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ScriptFile>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ScriptFile>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ScriptFileTable> where,
    _isd.OrderByBuilder<ScriptFileTable>? orderBy,
    _isd.OrderByListBuilder<ScriptFileTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ScriptFile>(
      where: where(ScriptFile.t),
      orderBy: orderBy?.call(ScriptFile.t),
      orderByList: orderByList?.call(ScriptFile.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ScriptFileTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<ScriptFile>(
      where: where?.call(ScriptFile.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ScriptFile] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ScriptFileTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ScriptFile>(
      where: where(ScriptFile.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class ScriptFileAttachRowRepository {
  const ScriptFileAttachRowRepository._();

  /// Creates a relation between the given [ScriptFile] and [ScriptProject]
  /// by setting the [ScriptFile]'s foreign key `projectId` to refer to the [ScriptProject].
  Future<void> project(
    _isd.DatabaseSession session,
    ScriptFile scriptFile,
    _i810rwvy.ScriptProject project, {
    _isd.Transaction? transaction,
  }) async {
    if (scriptFile.id == null) {
      throw ArgumentError.notNull('scriptFile.id');
    }
    if (project.id == null) {
      throw ArgumentError.notNull('project.id');
    }

    var $scriptFile = scriptFile.copyWith(projectId: project.id);
    await session.db.updateRow<ScriptFile>(
      $scriptFile,
      columns: [ScriptFile.t.projectId],
      transaction: transaction,
    );
  }
}
