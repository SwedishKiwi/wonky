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

/// A Write theme (Write 06 §5.1). Built-ins are global rows (ownerId null).
abstract class WriteTheme
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  WriteTheme._({
    this.id,
    _is.UuidValue? uuid,
    this.ownerId,
    required this.isBuiltin,
    this.builtinKey,
    required this.name,
    this.description,
    required this.schemaVersion,
    required this.version,
    required this.json,
    required this.contentHash,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  }) : uuid = uuid ?? const _is.Uuid().v7obj();

  factory WriteTheme({
    int? id,
    _is.UuidValue? uuid,
    int? ownerId,
    required bool isBuiltin,
    String? builtinKey,
    required String name,
    String? description,
    required int schemaVersion,
    required int version,
    required String json,
    required String contentHash,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _WriteThemeImpl;

  factory WriteTheme.fromJson(Map<String, dynamic> jsonSerialization) {
    return WriteTheme(
      id: jsonSerialization['id'] as int?,
      uuid: jsonSerialization['uuid'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      ownerId: jsonSerialization['ownerId'] as int?,
      isBuiltin: _is.BoolJsonExtension.fromJson(jsonSerialization['isBuiltin']),
      builtinKey: jsonSerialization['builtinKey'] as String?,
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String?,
      schemaVersion: jsonSerialization['schemaVersion'] as int,
      version: jsonSerialization['version'] as int,
      json: jsonSerialization['json'] as String,
      contentHash: jsonSerialization['contentHash'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
    );
  }

  static final t = WriteThemeTable();

  static const db = WriteThemeRepository._();

  @override
  int? id;

  /// Built-ins use UUIDv5("wonky-theme:<key>").
  _is.UuidValue uuid;

  int? ownerId;

  bool isBuiltin;

  String? builtinKey;

  String name;

  String? description;

  int schemaVersion;

  /// 1-based, +1 on every save (optimistic concurrency).
  int version;

  /// Canonical WriteThemeData JSON.
  String json;

  /// sha256(json).
  String contentHash;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? deletedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [WriteTheme]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WriteTheme copyWith({
    int? id,
    _is.UuidValue? uuid,
    int? ownerId,
    bool? isBuiltin,
    String? builtinKey,
    String? name,
    String? description,
    int? schemaVersion,
    int? version,
    String? json,
    String? contentHash,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WriteTheme',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      if (ownerId != null) 'ownerId': ownerId,
      'isBuiltin': isBuiltin,
      if (builtinKey != null) 'builtinKey': builtinKey,
      'name': name,
      if (description != null) 'description': description,
      'schemaVersion': schemaVersion,
      'version': version,
      'json': json,
      'contentHash': contentHash,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WriteTheme',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      if (ownerId != null) 'ownerId': ownerId,
      'isBuiltin': isBuiltin,
      if (builtinKey != null) 'builtinKey': builtinKey,
      'name': name,
      if (description != null) 'description': description,
      'schemaVersion': schemaVersion,
      'version': version,
      'json': json,
      'contentHash': contentHash,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  static WriteThemeInclude include() {
    return WriteThemeInclude._();
  }

  static WriteThemeIncludeList includeList({
    _is.WhereExpressionBuilder<WriteThemeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WriteThemeTable>? orderBy,
    _is.OrderByListBuilder<WriteThemeTable>? orderByList,
    WriteThemeInclude? include,
  }) {
    return WriteThemeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WriteTheme.t),
      orderByList: orderByList?.call(WriteTheme.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WriteThemeImpl extends WriteTheme {
  _WriteThemeImpl({
    int? id,
    _is.UuidValue? uuid,
    int? ownerId,
    required bool isBuiltin,
    String? builtinKey,
    required String name,
    String? description,
    required int schemaVersion,
    required int version,
    required String json,
    required String contentHash,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) : super._(
         id: id,
         uuid: uuid,
         ownerId: ownerId,
         isBuiltin: isBuiltin,
         builtinKey: builtinKey,
         name: name,
         description: description,
         schemaVersion: schemaVersion,
         version: version,
         json: json,
         contentHash: contentHash,
         createdAt: createdAt,
         updatedAt: updatedAt,
         deletedAt: deletedAt,
       );

  /// Returns a shallow copy of this [WriteTheme]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WriteTheme copyWith({
    Object? id = _Undefined,
    _is.UuidValue? uuid,
    Object? ownerId = _Undefined,
    bool? isBuiltin,
    Object? builtinKey = _Undefined,
    String? name,
    Object? description = _Undefined,
    int? schemaVersion,
    int? version,
    String? json,
    String? contentHash,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
  }) {
    return WriteTheme(
      id: id is int? ? id : this.id,
      uuid: uuid ?? this.uuid,
      ownerId: ownerId is int? ? ownerId : this.ownerId,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      builtinKey: builtinKey is String? ? builtinKey : this.builtinKey,
      name: name ?? this.name,
      description: description is String? ? description : this.description,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      version: version ?? this.version,
      json: json ?? this.json,
      contentHash: contentHash ?? this.contentHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt is _is.UndefinedSentinel
          ? this.deletedAt
          : deletedAt,
    );
  }
}

class WriteThemeUpdateTable extends _is.UpdateTable<WriteThemeTable> {
  WriteThemeUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> uuid(_is.UuidValue value) =>
      _is.ColumnValue(
        table.uuid,
        value,
      );

  _is.ColumnValue<int, int> ownerId(int? value) => _is.ColumnValue(
    table.ownerId,
    value,
  );

  _is.ColumnValue<bool, bool> isBuiltin(bool value) => _is.ColumnValue(
    table.isBuiltin,
    value,
  );

  _is.ColumnValue<String, String> builtinKey(String? value) => _is.ColumnValue(
    table.builtinKey,
    value,
  );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<String, String> description(String? value) => _is.ColumnValue(
    table.description,
    value,
  );

  _is.ColumnValue<int, int> schemaVersion(int value) => _is.ColumnValue(
    table.schemaVersion,
    value,
  );

  _is.ColumnValue<int, int> version(int value) => _is.ColumnValue(
    table.version,
    value,
  );

  _is.ColumnValue<String, String> json(String value) => _is.ColumnValue(
    table.json,
    value,
  );

  _is.ColumnValue<String, String> contentHash(String value) => _is.ColumnValue(
    table.contentHash,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> deletedAt(DateTime? value) =>
      _is.ColumnValue(
        table.deletedAt,
        value,
      );
}

class WriteThemeTable extends _is.Table<int?> {
  WriteThemeTable({super.tableRelation}) : super(tableName: 'write_theme') {
    updateTable = WriteThemeUpdateTable(this);
    uuid = _is.ColumnUuid(
      'uuid',
      this,
    );
    ownerId = _is.ColumnInt(
      'ownerId',
      this,
    );
    isBuiltin = _is.ColumnBool(
      'isBuiltin',
      this,
    );
    builtinKey = _is.ColumnString(
      'builtinKey',
      this,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
    description = _is.ColumnString(
      'description',
      this,
    );
    schemaVersion = _is.ColumnInt(
      'schemaVersion',
      this,
    );
    version = _is.ColumnInt(
      'version',
      this,
    );
    json = _is.ColumnString(
      'json',
      this,
    );
    contentHash = _is.ColumnString(
      'contentHash',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
    deletedAt = _is.ColumnDateTime(
      'deletedAt',
      this,
    );
  }

  late final WriteThemeUpdateTable updateTable;

  /// Built-ins use UUIDv5("wonky-theme:<key>").
  late final _is.ColumnUuid uuid;

  late final _is.ColumnInt ownerId;

  late final _is.ColumnBool isBuiltin;

  late final _is.ColumnString builtinKey;

  late final _is.ColumnString name;

  late final _is.ColumnString description;

  late final _is.ColumnInt schemaVersion;

  /// 1-based, +1 on every save (optimistic concurrency).
  late final _is.ColumnInt version;

  /// Canonical WriteThemeData JSON.
  late final _is.ColumnString json;

  /// sha256(json).
  late final _is.ColumnString contentHash;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime updatedAt;

  late final _is.ColumnDateTime deletedAt;

  @override
  List<_is.Column> get columns => [
    id,
    uuid,
    ownerId,
    isBuiltin,
    builtinKey,
    name,
    description,
    schemaVersion,
    version,
    json,
    contentHash,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}

class WriteThemeInclude extends _is.IncludeObject {
  WriteThemeInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => WriteTheme.t;
}

class WriteThemeIncludeList extends _is.IncludeList {
  WriteThemeIncludeList._({
    _is.WhereExpressionBuilder<WriteThemeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WriteTheme.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => WriteTheme.t;
}

class WriteThemeRepository {
  const WriteThemeRepository._();

  /// Returns a list of [WriteTheme]s matching the given query parameters.
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
  Future<List<WriteTheme>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WriteThemeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WriteThemeTable>? orderBy,
    _is.OrderByListBuilder<WriteThemeTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WriteTheme>(
      where: where?.call(WriteTheme.t),
      orderBy: orderBy?.call(WriteTheme.t),
      orderByList: orderByList?.call(WriteTheme.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [WriteTheme]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `WriteTheme.t`.
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
  _ida.Stream<List<WriteTheme>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WriteThemeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WriteThemeTable>? orderBy,
    _is.OrderByListBuilder<WriteThemeTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<WriteTheme>(
      where: where?.call(WriteTheme.t),
      orderBy: orderBy?.call(WriteTheme.t),
      orderByList: orderByList?.call(WriteTheme.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [WriteTheme] matching the given query parameters.
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
  Future<WriteTheme?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WriteThemeTable>? where,
    int? offset,
    _is.OrderByBuilder<WriteThemeTable>? orderBy,
    _is.OrderByListBuilder<WriteThemeTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WriteTheme>(
      where: where?.call(WriteTheme.t),
      orderBy: orderBy?.call(WriteTheme.t),
      orderByList: orderByList?.call(WriteTheme.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WriteTheme] by its [id] or null if no such row exists.
  Future<WriteTheme?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WriteTheme>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WriteTheme]s in the list and returns the inserted rows.
  ///
  /// The returned [WriteTheme]s will have their `id` fields set.
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
  Future<List<WriteTheme>> insert(
    _is.DatabaseSession session,
    List<WriteTheme> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<WriteTheme>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [WriteTheme] and returns the inserted row.
  ///
  /// The returned [WriteTheme] will have its `id` field set.
  Future<WriteTheme> insertRow(
    _is.DatabaseSession session,
    WriteTheme row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<WriteTheme>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [WriteTheme]s in the list and returns the resulting rows.
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
  /// The returned [WriteTheme]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WriteTheme>> upsert(
    _is.DatabaseSession session,
    List<WriteTheme> rows, {
    required _is.ColumnSelections<WriteThemeTable> conflictColumns,
    _is.ColumnSelections<WriteThemeTable>? updateColumns,
    _is.WhereExpressionBuilder<WriteThemeTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<WriteTheme>(
      rows,
      conflictColumns: conflictColumns(WriteTheme.t),
      updateColumns: updateColumns?.call(WriteTheme.t),
      updateWhere: updateWhere?.call(WriteTheme.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [WriteTheme] and returns the resulting row.
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
  /// The returned [WriteTheme] will have its `id` field set.
  Future<WriteTheme?> upsertRow(
    _is.DatabaseSession session,
    WriteTheme row, {
    required _is.ColumnSelections<WriteThemeTable> conflictColumns,
    _is.ColumnSelections<WriteThemeTable>? updateColumns,
    _is.WhereExpressionBuilder<WriteThemeTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<WriteTheme>(
      row,
      conflictColumns: conflictColumns(WriteTheme.t),
      updateColumns: updateColumns?.call(WriteTheme.t),
      updateWhere: updateWhere?.call(WriteTheme.t),
      transaction: transaction,
    );
  }

  /// Updates all [WriteTheme]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WriteTheme>> update(
    _is.DatabaseSession session,
    List<WriteTheme> rows, {
    _is.ColumnSelections<WriteThemeTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<WriteTheme>(
      rows,
      columns: columns?.call(WriteTheme.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [WriteTheme]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WriteTheme> updateRow(
    _is.DatabaseSession session,
    WriteTheme row, {
    _is.ColumnSelections<WriteThemeTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<WriteTheme>(
      row,
      columns: columns?.call(WriteTheme.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WriteTheme] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WriteTheme?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<WriteThemeUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<WriteTheme>(
      id,
      columnValues: columnValues(WriteTheme.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WriteTheme]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WriteTheme>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<WriteThemeUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<WriteThemeTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WriteThemeTable>? orderBy,
    _is.OrderByListBuilder<WriteThemeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<WriteTheme>(
      columnValues: columnValues(WriteTheme.t.updateTable),
      where: where(WriteTheme.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WriteTheme.t),
      orderByList: orderByList?.call(WriteTheme.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [WriteTheme]s in the list and returns the deleted rows.
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
  Future<List<WriteTheme>> delete(
    _is.DatabaseSession session,
    List<WriteTheme> rows, {
    _is.OrderByBuilder<WriteThemeTable>? orderBy,
    _is.OrderByListBuilder<WriteThemeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<WriteTheme>(
      rows,
      orderBy: orderBy?.call(WriteTheme.t),
      orderByList: orderByList?.call(WriteTheme.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [WriteTheme].
  Future<WriteTheme> deleteRow(
    _is.DatabaseSession session,
    WriteTheme row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WriteTheme>(
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
  Future<List<WriteTheme>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WriteThemeTable> where,
    _is.OrderByBuilder<WriteThemeTable>? orderBy,
    _is.OrderByListBuilder<WriteThemeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<WriteTheme>(
      where: where(WriteTheme.t),
      orderBy: orderBy?.call(WriteTheme.t),
      orderByList: orderByList?.call(WriteTheme.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WriteThemeTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<WriteTheme>(
      where: where?.call(WriteTheme.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WriteTheme] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WriteThemeTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WriteTheme>(
      where: where(WriteTheme.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
