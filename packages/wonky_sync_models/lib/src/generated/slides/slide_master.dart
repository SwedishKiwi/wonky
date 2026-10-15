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

/// A master of a deck theme (Slides 02 §3.2, 05 §4). Its content
/// (placeholders, decorations) are SlideElement rows owned by the master.
abstract class SlideMaster
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  SlideMaster._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.themeId,
    this.theme,
    required this.name,
    required this.sortKey,
    this.backgroundJson,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory SlideMaster({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue themeId,
    _i810rwvy.DeckTheme? theme,
    required String name,
    required String sortKey,
    String? backgroundJson,
    DateTime? createdAt,
  }) = _SlideMasterImpl;

  factory SlideMaster.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlideMaster(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      themeId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['themeId'],
      ),
      theme: jsonSerialization['theme'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.DeckTheme>(
              jsonSerialization['theme'],
            ),
      name: jsonSerialization['name'] as String,
      sortKey: jsonSerialization['sortKey'] as String,
      backgroundJson: jsonSerialization['backgroundJson'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = SlideMasterTable();

  static const db = SlideMasterRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue themeId;

  _i810rwvy.DeckTheme? theme;

  String name;

  /// Order among the masters of the theme.
  String sortKey;

  /// null = theme background.
  String? backgroundJson;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [SlideMaster]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  SlideMaster copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? themeId,
    _i810rwvy.DeckTheme? theme = const _UndefinedSlideMaster$theme(),
    String? name,
    String? sortKey,
    String? backgroundJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlideMaster',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'themeId': themeId.toJson(),
      if (theme != null) 'theme': theme?.toJson(),
      'name': name,
      'sortKey': sortKey,
      if (backgroundJson != null) 'backgroundJson': backgroundJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlideMaster',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'themeId': themeId.toJson(),
      if (theme != null) 'theme': theme?.toJsonForProtocol(),
      'name': name,
      'sortKey': sortKey,
      if (backgroundJson != null) 'backgroundJson': backgroundJson,
      'createdAt': createdAt.toJson(),
    };
  }

  static SlideMasterInclude include({_i810rwvy.DeckThemeInclude? theme}) {
    return SlideMasterInclude._(theme: theme);
  }

  static SlideMasterIncludeList includeList({
    _isd.WhereExpressionBuilder<SlideMasterTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideMasterTable>? orderBy,
    _isd.OrderByListBuilder<SlideMasterTable>? orderByList,
    SlideMasterInclude? include,
  }) {
    return SlideMasterIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideMaster.t),
      orderByList: orderByList?.call(SlideMaster.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedSlideMaster$theme extends _iss.UndefinedSentinel
    implements _i810rwvy.DeckTheme {
  const _UndefinedSlideMaster$theme();
}

class _SlideMasterImpl extends SlideMaster {
  _SlideMasterImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue themeId,
    _i810rwvy.DeckTheme? theme,
    required String name,
    required String sortKey,
    String? backgroundJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         themeId: themeId,
         theme: theme,
         name: name,
         sortKey: sortKey,
         backgroundJson: backgroundJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SlideMaster]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  SlideMaster copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? themeId,
    _i810rwvy.DeckTheme? theme = const _UndefinedSlideMaster$theme(),
    String? name,
    String? sortKey,
    Object? backgroundJson = _Undefined,
    DateTime? createdAt,
  }) {
    return SlideMaster(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      themeId: themeId ?? this.themeId,
      theme: theme is _iss.UndefinedSentinel ? this.theme?.copyWith() : theme,
      name: name ?? this.name,
      sortKey: sortKey ?? this.sortKey,
      backgroundJson: backgroundJson is String?
          ? backgroundJson
          : this.backgroundJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SlideMasterUpdateTable extends _isd.UpdateTable<SlideMasterTable> {
  SlideMasterUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> themeId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.themeId, value);

  _isd.ColumnValue<String, String> name(String value) =>
      _isd.ColumnValue(table.name, value);

  _isd.ColumnValue<String, String> sortKey(String value) =>
      _isd.ColumnValue(table.sortKey, value);

  _isd.ColumnValue<String, String> backgroundJson(String? value) =>
      _isd.ColumnValue(table.backgroundJson, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class SlideMasterTable extends _isd.Table<_iss.UuidValue> {
  SlideMasterTable({super.tableRelation}) : super(tableName: 'slide_master') {
    updateTable = SlideMasterUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    themeId = _isd.ColumnUuid('themeId', this);
    name = _isd.ColumnString('name', this);
    sortKey = _isd.ColumnString('sortKey', this);
    backgroundJson = _isd.ColumnString('backgroundJson', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final SlideMasterUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid themeId;

  _i810rwvy.DeckThemeTable? _theme;

  late final _isd.ColumnString name;

  /// Order among the masters of the theme.
  late final _isd.ColumnString sortKey;

  /// null = theme background.
  late final _isd.ColumnString backgroundJson;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.DeckThemeTable get theme {
    if (_theme != null) return _theme!;
    _theme = _isd.createRelationTable(
      relationFieldName: 'theme',
      field: SlideMaster.t.themeId,
      foreignField: _i810rwvy.DeckTheme.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.DeckThemeTable(tableRelation: foreignTableRelation),
    );
    return _theme!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    themeId,
    name,
    sortKey,
    backgroundJson,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'theme') {
      return theme;
    }
    return null;
  }
}

class SlideMasterInclude extends _isd.IncludeObject {
  SlideMasterInclude._({_i810rwvy.DeckThemeInclude? theme}) {
    _theme = theme;
  }

  _i810rwvy.DeckThemeInclude? _theme;

  @override
  Map<String, _isd.Include?> get includes => {'theme': _theme};

  @override
  _isd.Table<_iss.UuidValue> get table => SlideMaster.t;
}

class SlideMasterIncludeList extends _isd.IncludeList {
  SlideMasterIncludeList._({
    _isd.WhereExpressionBuilder<SlideMasterTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SlideMaster.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => SlideMaster.t;
}

class SlideMasterRepository {
  const SlideMasterRepository._();

  final attachRow = const SlideMasterAttachRowRepository._();

  /// Returns a list of [SlideMaster]s matching the given query parameters.
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
  Future<List<SlideMaster>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideMasterTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideMasterTable>? orderBy,
    _isd.OrderByListBuilder<SlideMasterTable>? orderByList,
    _isd.Transaction? transaction,
    SlideMasterInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SlideMaster>(
      where: where?.call(SlideMaster.t),
      orderBy: orderBy?.call(SlideMaster.t),
      orderByList: orderByList?.call(SlideMaster.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SlideMaster]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SlideMaster.t`.
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
  _ida.Stream<List<SlideMaster>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideMasterTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideMasterTable>? orderBy,
    _isd.OrderByListBuilder<SlideMasterTable>? orderByList,
    SlideMasterInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SlideMaster>(
      where: where?.call(SlideMaster.t),
      orderBy: orderBy?.call(SlideMaster.t),
      orderByList: orderByList?.call(SlideMaster.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SlideMaster] matching the given query parameters.
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
  Future<SlideMaster?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideMasterTable>? where,
    int? offset,
    _isd.OrderByBuilder<SlideMasterTable>? orderBy,
    _isd.OrderByListBuilder<SlideMasterTable>? orderByList,
    _isd.Transaction? transaction,
    SlideMasterInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SlideMaster>(
      where: where?.call(SlideMaster.t),
      orderBy: orderBy?.call(SlideMaster.t),
      orderByList: orderByList?.call(SlideMaster.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SlideMaster] by its [id] or null if no such row exists.
  Future<SlideMaster?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SlideMasterInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SlideMaster>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SlideMaster]s in the list and returns the inserted rows.
  ///
  /// The returned [SlideMaster]s will have their `id` fields set.
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
  Future<List<SlideMaster>> insert(
    _isd.DatabaseSession session,
    List<SlideMaster> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SlideMaster>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SlideMaster] and returns the inserted row.
  ///
  /// The returned [SlideMaster] will have its `id` field set.
  Future<SlideMaster> insertRow(
    _isd.DatabaseSession session,
    SlideMaster row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SlideMaster>(row, transaction: transaction);
  }

  /// Upserts all [SlideMaster]s in the list and returns the resulting rows.
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
  /// The returned [SlideMaster]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideMaster>> upsert(
    _isd.DatabaseSession session,
    List<SlideMaster> rows, {
    required _isd.ColumnSelections<SlideMasterTable> conflictColumns,
    _isd.ColumnSelections<SlideMasterTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideMasterTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SlideMaster>(
      rows,
      conflictColumns: conflictColumns(SlideMaster.t),
      updateColumns: updateColumns?.call(SlideMaster.t),
      updateWhere: updateWhere?.call(SlideMaster.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SlideMaster] and returns the resulting row.
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
  /// The returned [SlideMaster] will have its `id` field set.
  Future<SlideMaster?> upsertRow(
    _isd.DatabaseSession session,
    SlideMaster row, {
    required _isd.ColumnSelections<SlideMasterTable> conflictColumns,
    _isd.ColumnSelections<SlideMasterTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideMasterTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SlideMaster>(
      row,
      conflictColumns: conflictColumns(SlideMaster.t),
      updateColumns: updateColumns?.call(SlideMaster.t),
      updateWhere: updateWhere?.call(SlideMaster.t),
      transaction: transaction,
    );
  }

  /// Updates all [SlideMaster]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideMaster>> update(
    _isd.DatabaseSession session,
    List<SlideMaster> rows, {
    _isd.ColumnSelections<SlideMasterTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SlideMaster>(
      rows,
      columns: columns?.call(SlideMaster.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SlideMaster]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SlideMaster> updateRow(
    _isd.DatabaseSession session,
    SlideMaster row, {
    _isd.ColumnSelections<SlideMasterTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SlideMaster>(
      row,
      columns: columns?.call(SlideMaster.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SlideMaster] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SlideMaster?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SlideMasterUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SlideMaster>(
      id,
      columnValues: columnValues(SlideMaster.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SlideMaster]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideMaster>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SlideMasterUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<SlideMasterTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideMasterTable>? orderBy,
    _isd.OrderByListBuilder<SlideMasterTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SlideMaster>(
      columnValues: columnValues(SlideMaster.t.updateTable),
      where: where(SlideMaster.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideMaster.t),
      orderByList: orderByList?.call(SlideMaster.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SlideMaster]s in the list and returns the deleted rows.
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
  Future<List<SlideMaster>> delete(
    _isd.DatabaseSession session,
    List<SlideMaster> rows, {
    _isd.OrderByBuilder<SlideMasterTable>? orderBy,
    _isd.OrderByListBuilder<SlideMasterTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SlideMaster>(
      rows,
      orderBy: orderBy?.call(SlideMaster.t),
      orderByList: orderByList?.call(SlideMaster.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SlideMaster].
  Future<SlideMaster> deleteRow(
    _isd.DatabaseSession session,
    SlideMaster row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SlideMaster>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideMaster>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideMasterTable> where,
    _isd.OrderByBuilder<SlideMasterTable>? orderBy,
    _isd.OrderByListBuilder<SlideMasterTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SlideMaster>(
      where: where(SlideMaster.t),
      orderBy: orderBy?.call(SlideMaster.t),
      orderByList: orderByList?.call(SlideMaster.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideMasterTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SlideMaster>(
      where: where?.call(SlideMaster.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SlideMaster] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideMasterTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SlideMaster>(
      where: where(SlideMaster.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SlideMasterAttachRowRepository {
  const SlideMasterAttachRowRepository._();

  /// Creates a relation between the given [SlideMaster] and [DeckTheme]
  /// by setting the [SlideMaster]'s foreign key `themeId` to refer to the [DeckTheme].
  Future<void> theme(
    _isd.DatabaseSession session,
    SlideMaster slideMaster,
    _i810rwvy.DeckTheme theme, {
    _isd.Transaction? transaction,
  }) async {
    if (slideMaster.id == null) {
      throw ArgumentError.notNull('slideMaster.id');
    }
    if (theme.id == null) {
      throw ArgumentError.notNull('theme.id');
    }

    var $slideMaster = slideMaster.copyWith(themeId: theme.id);
    await session.db.updateRow<SlideMaster>(
      $slideMaster,
      columns: [SlideMaster.t.themeId],
      transaction: transaction,
    );
  }
}
