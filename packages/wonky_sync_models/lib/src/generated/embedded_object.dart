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

/// A chart, image or slicer floating over the grid (Sheets 08).
abstract class EmbeddedObject
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  EmbeddedObject._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.sheetId,
    this.sheet,
    required this.kind,
    required this.anchorJson,
    required this.specJson,
    int? zIndex,
    this.title,
    this.altText,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       zIndex = zIndex ?? 0,
       createdAt = createdAt ?? DateTime.now();

  factory EmbeddedObject({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required _i810rwvy.EmbeddedObjectKind kind,
    required String anchorJson,
    required String specJson,
    int? zIndex,
    String? title,
    String? altText,
    DateTime? createdAt,
  }) = _EmbeddedObjectImpl;

  factory EmbeddedObject.fromJson(Map<String, dynamic> jsonSerialization) {
    return EmbeddedObject(
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
      kind: _i810rwvy.EmbeddedObjectKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      anchorJson: jsonSerialization['anchorJson'] as String,
      specJson: jsonSerialization['specJson'] as String,
      zIndex: jsonSerialization['zIndex'] as int?,
      title: jsonSerialization['title'] as String?,
      altText: jsonSerialization['altText'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = EmbeddedObjectTable();

  static const db = EmbeddedObjectRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue sheetId;

  _i810rwvy.Sheet? sheet;

  _i810rwvy.EmbeddedObjectKind kind;

  /// {v, rowId, colId, dx, dy, width, height, lockAspect} or {"ownSheet": true}.
  String anchorJson;

  /// ChartSpec / ImageSpec / SlicerSpec, always with "v".
  String specJson;

  int zIndex;

  String? title;

  String? altText;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [EmbeddedObject]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  EmbeddedObject copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedEmbeddedObject$sheet(),
    _i810rwvy.EmbeddedObjectKind? kind,
    String? anchorJson,
    String? specJson,
    int? zIndex,
    String? title,
    String? altText,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EmbeddedObject',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJson(),
      'kind': kind.toJson(),
      'anchorJson': anchorJson,
      'specJson': specJson,
      'zIndex': zIndex,
      if (title != null) 'title': title,
      if (altText != null) 'altText': altText,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'EmbeddedObject',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJsonForProtocol(),
      'kind': kind.toJson(),
      'anchorJson': anchorJson,
      'specJson': specJson,
      'zIndex': zIndex,
      if (title != null) 'title': title,
      if (altText != null) 'altText': altText,
      'createdAt': createdAt.toJson(),
    };
  }

  static EmbeddedObjectInclude include({_i810rwvy.SheetInclude? sheet}) {
    return EmbeddedObjectInclude._(sheet: sheet);
  }

  static EmbeddedObjectIncludeList includeList({
    _isd.WhereExpressionBuilder<EmbeddedObjectTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<EmbeddedObjectTable>? orderBy,
    _isd.OrderByListBuilder<EmbeddedObjectTable>? orderByList,
    EmbeddedObjectInclude? include,
  }) {
    return EmbeddedObjectIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EmbeddedObject.t),
      orderByList: orderByList?.call(EmbeddedObject.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedEmbeddedObject$sheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Sheet {
  const _UndefinedEmbeddedObject$sheet();
}

class _EmbeddedObjectImpl extends EmbeddedObject {
  _EmbeddedObjectImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required _i810rwvy.EmbeddedObjectKind kind,
    required String anchorJson,
    required String specJson,
    int? zIndex,
    String? title,
    String? altText,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         sheetId: sheetId,
         sheet: sheet,
         kind: kind,
         anchorJson: anchorJson,
         specJson: specJson,
         zIndex: zIndex,
         title: title,
         altText: altText,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [EmbeddedObject]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  EmbeddedObject copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedEmbeddedObject$sheet(),
    _i810rwvy.EmbeddedObjectKind? kind,
    String? anchorJson,
    String? specJson,
    int? zIndex,
    Object? title = _Undefined,
    Object? altText = _Undefined,
    DateTime? createdAt,
  }) {
    return EmbeddedObject(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      sheetId: sheetId ?? this.sheetId,
      sheet: sheet is _iss.UndefinedSentinel ? this.sheet?.copyWith() : sheet,
      kind: kind ?? this.kind,
      anchorJson: anchorJson ?? this.anchorJson,
      specJson: specJson ?? this.specJson,
      zIndex: zIndex ?? this.zIndex,
      title: title is String? ? title : this.title,
      altText: altText is String? ? altText : this.altText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class EmbeddedObjectUpdateTable extends _isd.UpdateTable<EmbeddedObjectTable> {
  EmbeddedObjectUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> sheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<_i810rwvy.EmbeddedObjectKind, _i810rwvy.EmbeddedObjectKind>
  kind(_i810rwvy.EmbeddedObjectKind value) =>
      _isd.ColumnValue(table.kind, value);

  _isd.ColumnValue<String, String> anchorJson(String value) =>
      _isd.ColumnValue(table.anchorJson, value);

  _isd.ColumnValue<String, String> specJson(String value) =>
      _isd.ColumnValue(table.specJson, value);

  _isd.ColumnValue<int, int> zIndex(int value) =>
      _isd.ColumnValue(table.zIndex, value);

  _isd.ColumnValue<String, String> title(String? value) =>
      _isd.ColumnValue(table.title, value);

  _isd.ColumnValue<String, String> altText(String? value) =>
      _isd.ColumnValue(table.altText, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class EmbeddedObjectTable extends _isd.Table<_iss.UuidValue> {
  EmbeddedObjectTable({super.tableRelation})
    : super(tableName: 'embedded_object') {
    updateTable = EmbeddedObjectUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    sheetId = _isd.ColumnUuid('sheetId', this);
    kind = _isd.ColumnEnum('kind', this, _isd.EnumSerialization.byName);
    anchorJson = _isd.ColumnString('anchorJson', this);
    specJson = _isd.ColumnString('specJson', this);
    zIndex = _isd.ColumnInt('zIndex', this, hasDefault: true);
    title = _isd.ColumnString('title', this);
    altText = _isd.ColumnString('altText', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final EmbeddedObjectUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid sheetId;

  _i810rwvy.SheetTable? _sheet;

  late final _isd.ColumnEnum<_i810rwvy.EmbeddedObjectKind> kind;

  /// {v, rowId, colId, dx, dy, width, height, lockAspect} or {"ownSheet": true}.
  late final _isd.ColumnString anchorJson;

  /// ChartSpec / ImageSpec / SlicerSpec, always with "v".
  late final _isd.ColumnString specJson;

  late final _isd.ColumnInt zIndex;

  late final _isd.ColumnString title;

  late final _isd.ColumnString altText;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SheetTable get sheet {
    if (_sheet != null) return _sheet!;
    _sheet = _isd.createRelationTable(
      relationFieldName: 'sheet',
      field: EmbeddedObject.t.sheetId,
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
    kind,
    anchorJson,
    specJson,
    zIndex,
    title,
    altText,
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

class EmbeddedObjectInclude extends _isd.IncludeObject {
  EmbeddedObjectInclude._({_i810rwvy.SheetInclude? sheet}) {
    _sheet = sheet;
  }

  _i810rwvy.SheetInclude? _sheet;

  @override
  Map<String, _isd.Include?> get includes => {'sheet': _sheet};

  @override
  _isd.Table<_iss.UuidValue> get table => EmbeddedObject.t;
}

class EmbeddedObjectIncludeList extends _isd.IncludeList {
  EmbeddedObjectIncludeList._({
    _isd.WhereExpressionBuilder<EmbeddedObjectTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(EmbeddedObject.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => EmbeddedObject.t;
}

class EmbeddedObjectRepository {
  const EmbeddedObjectRepository._();

  final attachRow = const EmbeddedObjectAttachRowRepository._();

  /// Returns a list of [EmbeddedObject]s matching the given query parameters.
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
  Future<List<EmbeddedObject>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<EmbeddedObjectTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<EmbeddedObjectTable>? orderBy,
    _isd.OrderByListBuilder<EmbeddedObjectTable>? orderByList,
    _isd.Transaction? transaction,
    EmbeddedObjectInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<EmbeddedObject>(
      where: where?.call(EmbeddedObject.t),
      orderBy: orderBy?.call(EmbeddedObject.t),
      orderByList: orderByList?.call(EmbeddedObject.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [EmbeddedObject]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `EmbeddedObject.t`.
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
  _ida.Stream<List<EmbeddedObject>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<EmbeddedObjectTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<EmbeddedObjectTable>? orderBy,
    _isd.OrderByListBuilder<EmbeddedObjectTable>? orderByList,
    EmbeddedObjectInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<EmbeddedObject>(
      where: where?.call(EmbeddedObject.t),
      orderBy: orderBy?.call(EmbeddedObject.t),
      orderByList: orderByList?.call(EmbeddedObject.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [EmbeddedObject] matching the given query parameters.
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
  Future<EmbeddedObject?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<EmbeddedObjectTable>? where,
    int? offset,
    _isd.OrderByBuilder<EmbeddedObjectTable>? orderBy,
    _isd.OrderByListBuilder<EmbeddedObjectTable>? orderByList,
    _isd.Transaction? transaction,
    EmbeddedObjectInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<EmbeddedObject>(
      where: where?.call(EmbeddedObject.t),
      orderBy: orderBy?.call(EmbeddedObject.t),
      orderByList: orderByList?.call(EmbeddedObject.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [EmbeddedObject] by its [id] or null if no such row exists.
  Future<EmbeddedObject?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    EmbeddedObjectInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<EmbeddedObject>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [EmbeddedObject]s in the list and returns the inserted rows.
  ///
  /// The returned [EmbeddedObject]s will have their `id` fields set.
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
  Future<List<EmbeddedObject>> insert(
    _isd.DatabaseSession session,
    List<EmbeddedObject> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<EmbeddedObject>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [EmbeddedObject] and returns the inserted row.
  ///
  /// The returned [EmbeddedObject] will have its `id` field set.
  Future<EmbeddedObject> insertRow(
    _isd.DatabaseSession session,
    EmbeddedObject row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<EmbeddedObject>(row, transaction: transaction);
  }

  /// Upserts all [EmbeddedObject]s in the list and returns the resulting rows.
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
  /// The returned [EmbeddedObject]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EmbeddedObject>> upsert(
    _isd.DatabaseSession session,
    List<EmbeddedObject> rows, {
    required _isd.ColumnSelections<EmbeddedObjectTable> conflictColumns,
    _isd.ColumnSelections<EmbeddedObjectTable>? updateColumns,
    _isd.WhereExpressionBuilder<EmbeddedObjectTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<EmbeddedObject>(
      rows,
      conflictColumns: conflictColumns(EmbeddedObject.t),
      updateColumns: updateColumns?.call(EmbeddedObject.t),
      updateWhere: updateWhere?.call(EmbeddedObject.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [EmbeddedObject] and returns the resulting row.
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
  /// The returned [EmbeddedObject] will have its `id` field set.
  Future<EmbeddedObject?> upsertRow(
    _isd.DatabaseSession session,
    EmbeddedObject row, {
    required _isd.ColumnSelections<EmbeddedObjectTable> conflictColumns,
    _isd.ColumnSelections<EmbeddedObjectTable>? updateColumns,
    _isd.WhereExpressionBuilder<EmbeddedObjectTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<EmbeddedObject>(
      row,
      conflictColumns: conflictColumns(EmbeddedObject.t),
      updateColumns: updateColumns?.call(EmbeddedObject.t),
      updateWhere: updateWhere?.call(EmbeddedObject.t),
      transaction: transaction,
    );
  }

  /// Updates all [EmbeddedObject]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EmbeddedObject>> update(
    _isd.DatabaseSession session,
    List<EmbeddedObject> rows, {
    _isd.ColumnSelections<EmbeddedObjectTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<EmbeddedObject>(
      rows,
      columns: columns?.call(EmbeddedObject.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [EmbeddedObject]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<EmbeddedObject> updateRow(
    _isd.DatabaseSession session,
    EmbeddedObject row, {
    _isd.ColumnSelections<EmbeddedObjectTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<EmbeddedObject>(
      row,
      columns: columns?.call(EmbeddedObject.t),
      transaction: transaction,
    );
  }

  /// Updates a single [EmbeddedObject] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<EmbeddedObject?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<EmbeddedObjectUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<EmbeddedObject>(
      id,
      columnValues: columnValues(EmbeddedObject.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [EmbeddedObject]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EmbeddedObject>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<EmbeddedObjectUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<EmbeddedObjectTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<EmbeddedObjectTable>? orderBy,
    _isd.OrderByListBuilder<EmbeddedObjectTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<EmbeddedObject>(
      columnValues: columnValues(EmbeddedObject.t.updateTable),
      where: where(EmbeddedObject.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EmbeddedObject.t),
      orderByList: orderByList?.call(EmbeddedObject.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [EmbeddedObject]s in the list and returns the deleted rows.
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
  Future<List<EmbeddedObject>> delete(
    _isd.DatabaseSession session,
    List<EmbeddedObject> rows, {
    _isd.OrderByBuilder<EmbeddedObjectTable>? orderBy,
    _isd.OrderByListBuilder<EmbeddedObjectTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<EmbeddedObject>(
      rows,
      orderBy: orderBy?.call(EmbeddedObject.t),
      orderByList: orderByList?.call(EmbeddedObject.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [EmbeddedObject].
  Future<EmbeddedObject> deleteRow(
    _isd.DatabaseSession session,
    EmbeddedObject row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<EmbeddedObject>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EmbeddedObject>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<EmbeddedObjectTable> where,
    _isd.OrderByBuilder<EmbeddedObjectTable>? orderBy,
    _isd.OrderByListBuilder<EmbeddedObjectTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<EmbeddedObject>(
      where: where(EmbeddedObject.t),
      orderBy: orderBy?.call(EmbeddedObject.t),
      orderByList: orderByList?.call(EmbeddedObject.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<EmbeddedObjectTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<EmbeddedObject>(
      where: where?.call(EmbeddedObject.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [EmbeddedObject] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<EmbeddedObjectTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<EmbeddedObject>(
      where: where(EmbeddedObject.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class EmbeddedObjectAttachRowRepository {
  const EmbeddedObjectAttachRowRepository._();

  /// Creates a relation between the given [EmbeddedObject] and [Sheet]
  /// by setting the [EmbeddedObject]'s foreign key `sheetId` to refer to the [Sheet].
  Future<void> sheet(
    _isd.DatabaseSession session,
    EmbeddedObject embeddedObject,
    _i810rwvy.Sheet sheet, {
    _isd.Transaction? transaction,
  }) async {
    if (embeddedObject.id == null) {
      throw ArgumentError.notNull('embeddedObject.id');
    }
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }

    var $embeddedObject = embeddedObject.copyWith(sheetId: sheet.id);
    await session.db.updateRow<EmbeddedObject>(
      $embeddedObject,
      columns: [EmbeddedObject.t.sheetId],
      transaction: transaction,
    );
  }
}
