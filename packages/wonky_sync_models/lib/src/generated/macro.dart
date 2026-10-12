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

/// A recorded or written macro bound to a function.
abstract class Macro
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  Macro._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.projectId,
    this.project,
    required this.name,
    required this.functionName,
    this.shortcutSlot,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory Macro({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue projectId,
    _i810rwvy.ScriptProject? project,
    required String name,
    required String functionName,
    int? shortcutSlot,
    DateTime? createdAt,
  }) = _MacroImpl;

  factory Macro.fromJson(Map<String, dynamic> jsonSerialization) {
    return Macro(
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
      functionName: jsonSerialization['functionName'] as String,
      shortcutSlot: jsonSerialization['shortcutSlot'] as int?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = MacroTable();

  static const db = MacroRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue projectId;

  _i810rwvy.ScriptProject? project;

  String name;

  String functionName;

  /// 1..10 → Mod+Alt+Shift+<n>.
  int? shortcutSlot;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [Macro]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  Macro copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? projectId,
    _i810rwvy.ScriptProject? project = const _UndefinedMacro$project(),
    String? name,
    String? functionName,
    int? shortcutSlot,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Macro',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'projectId': projectId.toJson(),
      if (project != null) 'project': project?.toJson(),
      'name': name,
      'functionName': functionName,
      if (shortcutSlot != null) 'shortcutSlot': shortcutSlot,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Macro',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'projectId': projectId.toJson(),
      if (project != null) 'project': project?.toJsonForProtocol(),
      'name': name,
      'functionName': functionName,
      if (shortcutSlot != null) 'shortcutSlot': shortcutSlot,
      'createdAt': createdAt.toJson(),
    };
  }

  static MacroInclude include({_i810rwvy.ScriptProjectInclude? project}) {
    return MacroInclude._(project: project);
  }

  static MacroIncludeList includeList({
    _isd.WhereExpressionBuilder<MacroTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<MacroTable>? orderBy,
    _isd.OrderByListBuilder<MacroTable>? orderByList,
    MacroInclude? include,
  }) {
    return MacroIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Macro.t),
      orderByList: orderByList?.call(Macro.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedMacro$project extends _iss.UndefinedSentinel
    implements _i810rwvy.ScriptProject {
  const _UndefinedMacro$project();
}

class _MacroImpl extends Macro {
  _MacroImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue projectId,
    _i810rwvy.ScriptProject? project,
    required String name,
    required String functionName,
    int? shortcutSlot,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         projectId: projectId,
         project: project,
         name: name,
         functionName: functionName,
         shortcutSlot: shortcutSlot,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Macro]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  Macro copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? projectId,
    _i810rwvy.ScriptProject? project = const _UndefinedMacro$project(),
    String? name,
    String? functionName,
    Object? shortcutSlot = _Undefined,
    DateTime? createdAt,
  }) {
    return Macro(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      projectId: projectId ?? this.projectId,
      project: project is _iss.UndefinedSentinel
          ? this.project?.copyWith()
          : project,
      name: name ?? this.name,
      functionName: functionName ?? this.functionName,
      shortcutSlot: shortcutSlot is int? ? shortcutSlot : this.shortcutSlot,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MacroUpdateTable extends _isd.UpdateTable<MacroTable> {
  MacroUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> projectId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.projectId, value);

  _isd.ColumnValue<String, String> name(String value) =>
      _isd.ColumnValue(table.name, value);

  _isd.ColumnValue<String, String> functionName(String value) =>
      _isd.ColumnValue(table.functionName, value);

  _isd.ColumnValue<int, int> shortcutSlot(int? value) =>
      _isd.ColumnValue(table.shortcutSlot, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class MacroTable extends _isd.Table<_iss.UuidValue> {
  MacroTable({super.tableRelation}) : super(tableName: 'macro') {
    updateTable = MacroUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    projectId = _isd.ColumnUuid('projectId', this);
    name = _isd.ColumnString('name', this);
    functionName = _isd.ColumnString('functionName', this);
    shortcutSlot = _isd.ColumnInt('shortcutSlot', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final MacroUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid projectId;

  _i810rwvy.ScriptProjectTable? _project;

  late final _isd.ColumnString name;

  late final _isd.ColumnString functionName;

  /// 1..10 → Mod+Alt+Shift+<n>.
  late final _isd.ColumnInt shortcutSlot;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.ScriptProjectTable get project {
    if (_project != null) return _project!;
    _project = _isd.createRelationTable(
      relationFieldName: 'project',
      field: Macro.t.projectId,
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
    functionName,
    shortcutSlot,
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

class MacroInclude extends _isd.IncludeObject {
  MacroInclude._({_i810rwvy.ScriptProjectInclude? project}) {
    _project = project;
  }

  _i810rwvy.ScriptProjectInclude? _project;

  @override
  Map<String, _isd.Include?> get includes => {'project': _project};

  @override
  _isd.Table<_iss.UuidValue> get table => Macro.t;
}

class MacroIncludeList extends _isd.IncludeList {
  MacroIncludeList._({
    _isd.WhereExpressionBuilder<MacroTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Macro.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => Macro.t;
}

class MacroRepository {
  const MacroRepository._();

  final attachRow = const MacroAttachRowRepository._();

  /// Returns a list of [Macro]s matching the given query parameters.
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
  Future<List<Macro>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<MacroTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<MacroTable>? orderBy,
    _isd.OrderByListBuilder<MacroTable>? orderByList,
    _isd.Transaction? transaction,
    MacroInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Macro>(
      where: where?.call(Macro.t),
      orderBy: orderBy?.call(Macro.t),
      orderByList: orderByList?.call(Macro.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Macro]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Macro.t`.
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
  _ida.Stream<List<Macro>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<MacroTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<MacroTable>? orderBy,
    _isd.OrderByListBuilder<MacroTable>? orderByList,
    MacroInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Macro>(
      where: where?.call(Macro.t),
      orderBy: orderBy?.call(Macro.t),
      orderByList: orderByList?.call(Macro.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Macro] matching the given query parameters.
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
  Future<Macro?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<MacroTable>? where,
    int? offset,
    _isd.OrderByBuilder<MacroTable>? orderBy,
    _isd.OrderByListBuilder<MacroTable>? orderByList,
    _isd.Transaction? transaction,
    MacroInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Macro>(
      where: where?.call(Macro.t),
      orderBy: orderBy?.call(Macro.t),
      orderByList: orderByList?.call(Macro.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Macro] by its [id] or null if no such row exists.
  Future<Macro?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    MacroInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Macro>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Macro]s in the list and returns the inserted rows.
  ///
  /// The returned [Macro]s will have their `id` fields set.
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
  Future<List<Macro>> insert(
    _isd.DatabaseSession session,
    List<Macro> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Macro>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Macro] and returns the inserted row.
  ///
  /// The returned [Macro] will have its `id` field set.
  Future<Macro> insertRow(
    _isd.DatabaseSession session,
    Macro row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<Macro>(row, transaction: transaction);
  }

  /// Upserts all [Macro]s in the list and returns the resulting rows.
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
  /// The returned [Macro]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Macro>> upsert(
    _isd.DatabaseSession session,
    List<Macro> rows, {
    required _isd.ColumnSelections<MacroTable> conflictColumns,
    _isd.ColumnSelections<MacroTable>? updateColumns,
    _isd.WhereExpressionBuilder<MacroTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Macro>(
      rows,
      conflictColumns: conflictColumns(Macro.t),
      updateColumns: updateColumns?.call(Macro.t),
      updateWhere: updateWhere?.call(Macro.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Macro] and returns the resulting row.
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
  /// The returned [Macro] will have its `id` field set.
  Future<Macro?> upsertRow(
    _isd.DatabaseSession session,
    Macro row, {
    required _isd.ColumnSelections<MacroTable> conflictColumns,
    _isd.ColumnSelections<MacroTable>? updateColumns,
    _isd.WhereExpressionBuilder<MacroTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Macro>(
      row,
      conflictColumns: conflictColumns(Macro.t),
      updateColumns: updateColumns?.call(Macro.t),
      updateWhere: updateWhere?.call(Macro.t),
      transaction: transaction,
    );
  }

  /// Updates all [Macro]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Macro>> update(
    _isd.DatabaseSession session,
    List<Macro> rows, {
    _isd.ColumnSelections<MacroTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Macro>(
      rows,
      columns: columns?.call(Macro.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Macro]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Macro> updateRow(
    _isd.DatabaseSession session,
    Macro row, {
    _isd.ColumnSelections<MacroTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<Macro>(
      row,
      columns: columns?.call(Macro.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Macro] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Macro?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<MacroUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<Macro>(
      id,
      columnValues: columnValues(Macro.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Macro]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Macro>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<MacroUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<MacroTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<MacroTable>? orderBy,
    _isd.OrderByListBuilder<MacroTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Macro>(
      columnValues: columnValues(Macro.t.updateTable),
      where: where(Macro.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Macro.t),
      orderByList: orderByList?.call(Macro.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Macro]s in the list and returns the deleted rows.
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
  Future<List<Macro>> delete(
    _isd.DatabaseSession session,
    List<Macro> rows, {
    _isd.OrderByBuilder<MacroTable>? orderBy,
    _isd.OrderByListBuilder<MacroTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Macro>(
      rows,
      orderBy: orderBy?.call(Macro.t),
      orderByList: orderByList?.call(Macro.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Macro].
  Future<Macro> deleteRow(
    _isd.DatabaseSession session,
    Macro row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Macro>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Macro>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<MacroTable> where,
    _isd.OrderByBuilder<MacroTable>? orderBy,
    _isd.OrderByListBuilder<MacroTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Macro>(
      where: where(Macro.t),
      orderBy: orderBy?.call(Macro.t),
      orderByList: orderByList?.call(Macro.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<MacroTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<Macro>(
      where: where?.call(Macro.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Macro] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<MacroTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Macro>(
      where: where(Macro.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class MacroAttachRowRepository {
  const MacroAttachRowRepository._();

  /// Creates a relation between the given [Macro] and [ScriptProject]
  /// by setting the [Macro]'s foreign key `projectId` to refer to the [ScriptProject].
  Future<void> project(
    _isd.DatabaseSession session,
    Macro macro,
    _i810rwvy.ScriptProject project, {
    _isd.Transaction? transaction,
  }) async {
    if (macro.id == null) {
      throw ArgumentError.notNull('macro.id');
    }
    if (project.id == null) {
      throw ArgumentError.notNull('project.id');
    }

    var $macro = macro.copyWith(projectId: project.id);
    await session.db.updateRow<Macro>(
      $macro,
      columns: [Macro.t.projectId],
      transaction: transaction,
    );
  }
}
