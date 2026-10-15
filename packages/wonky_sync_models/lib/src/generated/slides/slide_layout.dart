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

/// A layout of a master (Slides 02 §3.2, 05 §4). Its content
/// (placeholders, decorations) are SlideElement rows owned by the layout.
abstract class SlideLayout
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  SlideLayout._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.masterId,
    this.master,
    required this.name,
    this.key,
    required this.sortKey,
    this.backgroundJson,
    bool? hideMasterElements,
    bool? hidden,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       hideMasterElements = hideMasterElements ?? false,
       hidden = hidden ?? false,
       createdAt = createdAt ?? DateTime.now();

  factory SlideLayout({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue masterId,
    _i810rwvy.SlideMaster? master,
    required String name,
    String? key,
    required String sortKey,
    String? backgroundJson,
    bool? hideMasterElements,
    bool? hidden,
    DateTime? createdAt,
  }) = _SlideLayoutImpl;

  factory SlideLayout.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlideLayout(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      masterId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['masterId'],
      ),
      master: jsonSerialization['master'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.SlideMaster>(
              jsonSerialization['master'],
            ),
      name: jsonSerialization['name'] as String,
      key: jsonSerialization['key'] as String?,
      sortKey: jsonSerialization['sortKey'] as String,
      backgroundJson: jsonSerialization['backgroundJson'] as String?,
      hideMasterElements: jsonSerialization['hideMasterElements'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(
              jsonSerialization['hideMasterElements'],
            ),
      hidden: jsonSerialization['hidden'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['hidden']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = SlideLayoutTable();

  static const db = SlideLayoutRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue masterId;

  _i810rwvy.SlideMaster? master;

  /// "Title and content".
  String name;

  /// Built-in layout key (05 §4): maps layouts between themes.
  String? key;

  /// Order among the layouts of the master.
  String sortKey;

  /// null = master background.
  String? backgroundJson;

  /// Don't draw the master's non-placeholder elements.
  bool hideMasterElements;

  /// Not offered in the layout picker.
  bool hidden;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [SlideLayout]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  SlideLayout copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? masterId,
    _i810rwvy.SlideMaster? master = const _UndefinedSlideLayout$master(),
    String? name,
    String? key,
    String? sortKey,
    String? backgroundJson,
    bool? hideMasterElements,
    bool? hidden,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlideLayout',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'masterId': masterId.toJson(),
      if (master != null) 'master': master?.toJson(),
      'name': name,
      if (key != null) 'key': key,
      'sortKey': sortKey,
      if (backgroundJson != null) 'backgroundJson': backgroundJson,
      'hideMasterElements': hideMasterElements,
      'hidden': hidden,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlideLayout',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'masterId': masterId.toJson(),
      if (master != null) 'master': master?.toJsonForProtocol(),
      'name': name,
      if (key != null) 'key': key,
      'sortKey': sortKey,
      if (backgroundJson != null) 'backgroundJson': backgroundJson,
      'hideMasterElements': hideMasterElements,
      'hidden': hidden,
      'createdAt': createdAt.toJson(),
    };
  }

  static SlideLayoutInclude include({_i810rwvy.SlideMasterInclude? master}) {
    return SlideLayoutInclude._(master: master);
  }

  static SlideLayoutIncludeList includeList({
    _isd.WhereExpressionBuilder<SlideLayoutTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideLayoutTable>? orderBy,
    _isd.OrderByListBuilder<SlideLayoutTable>? orderByList,
    SlideLayoutInclude? include,
  }) {
    return SlideLayoutIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideLayout.t),
      orderByList: orderByList?.call(SlideLayout.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedSlideLayout$master extends _iss.UndefinedSentinel
    implements _i810rwvy.SlideMaster {
  const _UndefinedSlideLayout$master();
}

class _SlideLayoutImpl extends SlideLayout {
  _SlideLayoutImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue masterId,
    _i810rwvy.SlideMaster? master,
    required String name,
    String? key,
    required String sortKey,
    String? backgroundJson,
    bool? hideMasterElements,
    bool? hidden,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         masterId: masterId,
         master: master,
         name: name,
         key: key,
         sortKey: sortKey,
         backgroundJson: backgroundJson,
         hideMasterElements: hideMasterElements,
         hidden: hidden,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SlideLayout]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  SlideLayout copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? masterId,
    _i810rwvy.SlideMaster? master = const _UndefinedSlideLayout$master(),
    String? name,
    Object? key = _Undefined,
    String? sortKey,
    Object? backgroundJson = _Undefined,
    bool? hideMasterElements,
    bool? hidden,
    DateTime? createdAt,
  }) {
    return SlideLayout(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      masterId: masterId ?? this.masterId,
      master: master is _iss.UndefinedSentinel
          ? this.master?.copyWith()
          : master,
      name: name ?? this.name,
      key: key is String? ? key : this.key,
      sortKey: sortKey ?? this.sortKey,
      backgroundJson: backgroundJson is String?
          ? backgroundJson
          : this.backgroundJson,
      hideMasterElements: hideMasterElements ?? this.hideMasterElements,
      hidden: hidden ?? this.hidden,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SlideLayoutUpdateTable extends _isd.UpdateTable<SlideLayoutTable> {
  SlideLayoutUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> masterId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.masterId, value);

  _isd.ColumnValue<String, String> name(String value) =>
      _isd.ColumnValue(table.name, value);

  _isd.ColumnValue<String, String> key(String? value) =>
      _isd.ColumnValue(table.key, value);

  _isd.ColumnValue<String, String> sortKey(String value) =>
      _isd.ColumnValue(table.sortKey, value);

  _isd.ColumnValue<String, String> backgroundJson(String? value) =>
      _isd.ColumnValue(table.backgroundJson, value);

  _isd.ColumnValue<bool, bool> hideMasterElements(bool value) =>
      _isd.ColumnValue(table.hideMasterElements, value);

  _isd.ColumnValue<bool, bool> hidden(bool value) =>
      _isd.ColumnValue(table.hidden, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class SlideLayoutTable extends _isd.Table<_iss.UuidValue> {
  SlideLayoutTable({super.tableRelation}) : super(tableName: 'slide_layout') {
    updateTable = SlideLayoutUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    masterId = _isd.ColumnUuid('masterId', this);
    name = _isd.ColumnString('name', this);
    key = _isd.ColumnString('key', this);
    sortKey = _isd.ColumnString('sortKey', this);
    backgroundJson = _isd.ColumnString('backgroundJson', this);
    hideMasterElements = _isd.ColumnBool(
      'hideMasterElements',
      this,
      hasDefault: true,
    );
    hidden = _isd.ColumnBool('hidden', this, hasDefault: true);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final SlideLayoutUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid masterId;

  _i810rwvy.SlideMasterTable? _master;

  /// "Title and content".
  late final _isd.ColumnString name;

  /// Built-in layout key (05 §4): maps layouts between themes.
  late final _isd.ColumnString key;

  /// Order among the layouts of the master.
  late final _isd.ColumnString sortKey;

  /// null = master background.
  late final _isd.ColumnString backgroundJson;

  /// Don't draw the master's non-placeholder elements.
  late final _isd.ColumnBool hideMasterElements;

  /// Not offered in the layout picker.
  late final _isd.ColumnBool hidden;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SlideMasterTable get master {
    if (_master != null) return _master!;
    _master = _isd.createRelationTable(
      relationFieldName: 'master',
      field: SlideLayout.t.masterId,
      foreignField: _i810rwvy.SlideMaster.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SlideMasterTable(tableRelation: foreignTableRelation),
    );
    return _master!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    masterId,
    name,
    key,
    sortKey,
    backgroundJson,
    hideMasterElements,
    hidden,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'master') {
      return master;
    }
    return null;
  }
}

class SlideLayoutInclude extends _isd.IncludeObject {
  SlideLayoutInclude._({_i810rwvy.SlideMasterInclude? master}) {
    _master = master;
  }

  _i810rwvy.SlideMasterInclude? _master;

  @override
  Map<String, _isd.Include?> get includes => {'master': _master};

  @override
  _isd.Table<_iss.UuidValue> get table => SlideLayout.t;
}

class SlideLayoutIncludeList extends _isd.IncludeList {
  SlideLayoutIncludeList._({
    _isd.WhereExpressionBuilder<SlideLayoutTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SlideLayout.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => SlideLayout.t;
}

class SlideLayoutRepository {
  const SlideLayoutRepository._();

  final attachRow = const SlideLayoutAttachRowRepository._();

  /// Returns a list of [SlideLayout]s matching the given query parameters.
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
  Future<List<SlideLayout>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideLayoutTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideLayoutTable>? orderBy,
    _isd.OrderByListBuilder<SlideLayoutTable>? orderByList,
    _isd.Transaction? transaction,
    SlideLayoutInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SlideLayout>(
      where: where?.call(SlideLayout.t),
      orderBy: orderBy?.call(SlideLayout.t),
      orderByList: orderByList?.call(SlideLayout.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SlideLayout]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SlideLayout.t`.
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
  _ida.Stream<List<SlideLayout>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideLayoutTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideLayoutTable>? orderBy,
    _isd.OrderByListBuilder<SlideLayoutTable>? orderByList,
    SlideLayoutInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SlideLayout>(
      where: where?.call(SlideLayout.t),
      orderBy: orderBy?.call(SlideLayout.t),
      orderByList: orderByList?.call(SlideLayout.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SlideLayout] matching the given query parameters.
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
  Future<SlideLayout?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideLayoutTable>? where,
    int? offset,
    _isd.OrderByBuilder<SlideLayoutTable>? orderBy,
    _isd.OrderByListBuilder<SlideLayoutTable>? orderByList,
    _isd.Transaction? transaction,
    SlideLayoutInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SlideLayout>(
      where: where?.call(SlideLayout.t),
      orderBy: orderBy?.call(SlideLayout.t),
      orderByList: orderByList?.call(SlideLayout.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SlideLayout] by its [id] or null if no such row exists.
  Future<SlideLayout?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SlideLayoutInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SlideLayout>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SlideLayout]s in the list and returns the inserted rows.
  ///
  /// The returned [SlideLayout]s will have their `id` fields set.
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
  Future<List<SlideLayout>> insert(
    _isd.DatabaseSession session,
    List<SlideLayout> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SlideLayout>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SlideLayout] and returns the inserted row.
  ///
  /// The returned [SlideLayout] will have its `id` field set.
  Future<SlideLayout> insertRow(
    _isd.DatabaseSession session,
    SlideLayout row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SlideLayout>(row, transaction: transaction);
  }

  /// Upserts all [SlideLayout]s in the list and returns the resulting rows.
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
  /// The returned [SlideLayout]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideLayout>> upsert(
    _isd.DatabaseSession session,
    List<SlideLayout> rows, {
    required _isd.ColumnSelections<SlideLayoutTable> conflictColumns,
    _isd.ColumnSelections<SlideLayoutTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideLayoutTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SlideLayout>(
      rows,
      conflictColumns: conflictColumns(SlideLayout.t),
      updateColumns: updateColumns?.call(SlideLayout.t),
      updateWhere: updateWhere?.call(SlideLayout.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SlideLayout] and returns the resulting row.
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
  /// The returned [SlideLayout] will have its `id` field set.
  Future<SlideLayout?> upsertRow(
    _isd.DatabaseSession session,
    SlideLayout row, {
    required _isd.ColumnSelections<SlideLayoutTable> conflictColumns,
    _isd.ColumnSelections<SlideLayoutTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideLayoutTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SlideLayout>(
      row,
      conflictColumns: conflictColumns(SlideLayout.t),
      updateColumns: updateColumns?.call(SlideLayout.t),
      updateWhere: updateWhere?.call(SlideLayout.t),
      transaction: transaction,
    );
  }

  /// Updates all [SlideLayout]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideLayout>> update(
    _isd.DatabaseSession session,
    List<SlideLayout> rows, {
    _isd.ColumnSelections<SlideLayoutTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SlideLayout>(
      rows,
      columns: columns?.call(SlideLayout.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SlideLayout]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SlideLayout> updateRow(
    _isd.DatabaseSession session,
    SlideLayout row, {
    _isd.ColumnSelections<SlideLayoutTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SlideLayout>(
      row,
      columns: columns?.call(SlideLayout.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SlideLayout] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SlideLayout?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SlideLayoutUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SlideLayout>(
      id,
      columnValues: columnValues(SlideLayout.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SlideLayout]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideLayout>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SlideLayoutUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<SlideLayoutTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideLayoutTable>? orderBy,
    _isd.OrderByListBuilder<SlideLayoutTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SlideLayout>(
      columnValues: columnValues(SlideLayout.t.updateTable),
      where: where(SlideLayout.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideLayout.t),
      orderByList: orderByList?.call(SlideLayout.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SlideLayout]s in the list and returns the deleted rows.
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
  Future<List<SlideLayout>> delete(
    _isd.DatabaseSession session,
    List<SlideLayout> rows, {
    _isd.OrderByBuilder<SlideLayoutTable>? orderBy,
    _isd.OrderByListBuilder<SlideLayoutTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SlideLayout>(
      rows,
      orderBy: orderBy?.call(SlideLayout.t),
      orderByList: orderByList?.call(SlideLayout.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SlideLayout].
  Future<SlideLayout> deleteRow(
    _isd.DatabaseSession session,
    SlideLayout row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SlideLayout>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideLayout>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideLayoutTable> where,
    _isd.OrderByBuilder<SlideLayoutTable>? orderBy,
    _isd.OrderByListBuilder<SlideLayoutTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SlideLayout>(
      where: where(SlideLayout.t),
      orderBy: orderBy?.call(SlideLayout.t),
      orderByList: orderByList?.call(SlideLayout.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideLayoutTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SlideLayout>(
      where: where?.call(SlideLayout.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SlideLayout] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideLayoutTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SlideLayout>(
      where: where(SlideLayout.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SlideLayoutAttachRowRepository {
  const SlideLayoutAttachRowRepository._();

  /// Creates a relation between the given [SlideLayout] and [SlideMaster]
  /// by setting the [SlideLayout]'s foreign key `masterId` to refer to the [SlideMaster].
  Future<void> master(
    _isd.DatabaseSession session,
    SlideLayout slideLayout,
    _i810rwvy.SlideMaster master, {
    _isd.Transaction? transaction,
  }) async {
    if (slideLayout.id == null) {
      throw ArgumentError.notNull('slideLayout.id');
    }
    if (master.id == null) {
      throw ArgumentError.notNull('master.id');
    }

    var $slideLayout = slideLayout.copyWith(masterId: master.id);
    await session.db.updateRow<SlideLayout>(
      $slideLayout,
      columns: [SlideLayout.t.masterId],
      transaction: transaction,
    );
  }
}
