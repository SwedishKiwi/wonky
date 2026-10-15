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

/// The link of a chart element to a chart in a Wonky Sheets spreadsheet
/// (Slides 02 §3.9, 08). Its id is always SlidesIds.chartLinkId(elementId).
abstract class ChartLink
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  ChartLink._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.elementId,
    this.element,
    required this.spreadsheetItemUuid,
    required this.chartObjectId,
    this.sheetId,
    required this.sourceSpecJson,
    required this.dataSnapshotJson,
    required this.sourceVersion,
    required this.updatedAt,
    required this.updatedBy,
    bool? autoUpdate,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       autoUpdate = autoUpdate ?? false,
       createdAt = createdAt ?? DateTime.now();

  factory ChartLink({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue elementId,
    _i810rwvy.SlideElement? element,
    required _iss.UuidValue spreadsheetItemUuid,
    required _iss.UuidValue chartObjectId,
    String? sheetId,
    required String sourceSpecJson,
    required String dataSnapshotJson,
    required String sourceVersion,
    required DateTime updatedAt,
    required _iss.UuidValue updatedBy,
    bool? autoUpdate,
    DateTime? createdAt,
  }) = _ChartLinkImpl;

  factory ChartLink.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChartLink(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      elementId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['elementId'],
      ),
      element: jsonSerialization['element'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.SlideElement>(
              jsonSerialization['element'],
            ),
      spreadsheetItemUuid: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['spreadsheetItemUuid'],
      ),
      chartObjectId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['chartObjectId'],
      ),
      sheetId: jsonSerialization['sheetId'] as String?,
      sourceSpecJson: jsonSerialization['sourceSpecJson'] as String,
      dataSnapshotJson: jsonSerialization['dataSnapshotJson'] as String,
      sourceVersion: jsonSerialization['sourceVersion'] as String,
      updatedAt: _iss.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      updatedBy: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['updatedBy'],
      ),
      autoUpdate: jsonSerialization['autoUpdate'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['autoUpdate']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = ChartLinkTable();

  static const db = ChartLinkRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue elementId;

  /// The chart element (kind chart).
  _i810rwvy.SlideElement? element;

  /// Drive item of the spreadsheet (cross-space: plain UUID).
  _iss.UuidValue spreadsheetItemUuid;

  /// Sheets EmbeddedObject id.
  _iss.UuidValue chartObjectId;

  /// Sheet of the chart at the last update (08 A-08-2).
  String? sheetId;

  /// The Sheets ChartSpec at the last update ("gz:" prefix when > 32 KB).
  /// Always written together with dataSnapshotJson (P4).
  String sourceSpecJson;

  /// Resolved series/categories at the last update (08 §3.4).
  String dataSnapshotJson;

  /// Opaque version of the source at the last update (08 §5.1).
  String sourceVersion;

  /// When the snapshot was taken.
  DateTime updatedAt;

  _iss.UuidValue updatedBy;

  /// "Update automatically" (08).
  bool autoUpdate;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [ChartLink]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  ChartLink copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? elementId,
    _i810rwvy.SlideElement? element = const _UndefinedChartLink$element(),
    _iss.UuidValue? spreadsheetItemUuid,
    _iss.UuidValue? chartObjectId,
    String? sheetId,
    String? sourceSpecJson,
    String? dataSnapshotJson,
    String? sourceVersion,
    DateTime? updatedAt,
    _iss.UuidValue? updatedBy,
    bool? autoUpdate,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChartLink',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'elementId': elementId.toJson(),
      if (element != null) 'element': element?.toJson(),
      'spreadsheetItemUuid': spreadsheetItemUuid.toJson(),
      'chartObjectId': chartObjectId.toJson(),
      if (sheetId != null) 'sheetId': sheetId,
      'sourceSpecJson': sourceSpecJson,
      'dataSnapshotJson': dataSnapshotJson,
      'sourceVersion': sourceVersion,
      'updatedAt': updatedAt.toJson(),
      'updatedBy': updatedBy.toJson(),
      'autoUpdate': autoUpdate,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChartLink',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'elementId': elementId.toJson(),
      if (element != null) 'element': element?.toJsonForProtocol(),
      'spreadsheetItemUuid': spreadsheetItemUuid.toJson(),
      'chartObjectId': chartObjectId.toJson(),
      if (sheetId != null) 'sheetId': sheetId,
      'sourceSpecJson': sourceSpecJson,
      'dataSnapshotJson': dataSnapshotJson,
      'sourceVersion': sourceVersion,
      'updatedAt': updatedAt.toJson(),
      'updatedBy': updatedBy.toJson(),
      'autoUpdate': autoUpdate,
      'createdAt': createdAt.toJson(),
    };
  }

  static ChartLinkInclude include({_i810rwvy.SlideElementInclude? element}) {
    return ChartLinkInclude._(element: element);
  }

  static ChartLinkIncludeList includeList({
    _isd.WhereExpressionBuilder<ChartLinkTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ChartLinkTable>? orderBy,
    _isd.OrderByListBuilder<ChartLinkTable>? orderByList,
    ChartLinkInclude? include,
  }) {
    return ChartLinkIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChartLink.t),
      orderByList: orderByList?.call(ChartLink.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedChartLink$element extends _iss.UndefinedSentinel
    implements _i810rwvy.SlideElement {
  const _UndefinedChartLink$element();
}

class _ChartLinkImpl extends ChartLink {
  _ChartLinkImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue elementId,
    _i810rwvy.SlideElement? element,
    required _iss.UuidValue spreadsheetItemUuid,
    required _iss.UuidValue chartObjectId,
    String? sheetId,
    required String sourceSpecJson,
    required String dataSnapshotJson,
    required String sourceVersion,
    required DateTime updatedAt,
    required _iss.UuidValue updatedBy,
    bool? autoUpdate,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         elementId: elementId,
         element: element,
         spreadsheetItemUuid: spreadsheetItemUuid,
         chartObjectId: chartObjectId,
         sheetId: sheetId,
         sourceSpecJson: sourceSpecJson,
         dataSnapshotJson: dataSnapshotJson,
         sourceVersion: sourceVersion,
         updatedAt: updatedAt,
         updatedBy: updatedBy,
         autoUpdate: autoUpdate,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ChartLink]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  ChartLink copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? elementId,
    _i810rwvy.SlideElement? element = const _UndefinedChartLink$element(),
    _iss.UuidValue? spreadsheetItemUuid,
    _iss.UuidValue? chartObjectId,
    Object? sheetId = _Undefined,
    String? sourceSpecJson,
    String? dataSnapshotJson,
    String? sourceVersion,
    DateTime? updatedAt,
    _iss.UuidValue? updatedBy,
    bool? autoUpdate,
    DateTime? createdAt,
  }) {
    return ChartLink(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      elementId: elementId ?? this.elementId,
      element: element is _iss.UndefinedSentinel
          ? this.element?.copyWith()
          : element,
      spreadsheetItemUuid: spreadsheetItemUuid ?? this.spreadsheetItemUuid,
      chartObjectId: chartObjectId ?? this.chartObjectId,
      sheetId: sheetId is String? ? sheetId : this.sheetId,
      sourceSpecJson: sourceSpecJson ?? this.sourceSpecJson,
      dataSnapshotJson: dataSnapshotJson ?? this.dataSnapshotJson,
      sourceVersion: sourceVersion ?? this.sourceVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ChartLinkUpdateTable extends _isd.UpdateTable<ChartLinkTable> {
  ChartLinkUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> elementId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.elementId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> spreadsheetItemUuid(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.spreadsheetItemUuid, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> chartObjectId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.chartObjectId, value);

  _isd.ColumnValue<String, String> sheetId(String? value) =>
      _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<String, String> sourceSpecJson(String value) =>
      _isd.ColumnValue(table.sourceSpecJson, value);

  _isd.ColumnValue<String, String> dataSnapshotJson(String value) =>
      _isd.ColumnValue(table.dataSnapshotJson, value);

  _isd.ColumnValue<String, String> sourceVersion(String value) =>
      _isd.ColumnValue(table.sourceVersion, value);

  _isd.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _isd.ColumnValue(table.updatedAt, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> updatedBy(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.updatedBy, value);

  _isd.ColumnValue<bool, bool> autoUpdate(bool value) =>
      _isd.ColumnValue(table.autoUpdate, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class ChartLinkTable extends _isd.Table<_iss.UuidValue> {
  ChartLinkTable({super.tableRelation}) : super(tableName: 'chart_link') {
    updateTable = ChartLinkUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    elementId = _isd.ColumnUuid('elementId', this);
    spreadsheetItemUuid = _isd.ColumnUuid('spreadsheetItemUuid', this);
    chartObjectId = _isd.ColumnUuid('chartObjectId', this);
    sheetId = _isd.ColumnString('sheetId', this);
    sourceSpecJson = _isd.ColumnString('sourceSpecJson', this);
    dataSnapshotJson = _isd.ColumnString('dataSnapshotJson', this);
    sourceVersion = _isd.ColumnString('sourceVersion', this);
    updatedAt = _isd.ColumnDateTime('updatedAt', this);
    updatedBy = _isd.ColumnUuid('updatedBy', this);
    autoUpdate = _isd.ColumnBool('autoUpdate', this, hasDefault: true);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final ChartLinkUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid elementId;

  /// The chart element (kind chart).
  _i810rwvy.SlideElementTable? _element;

  /// Drive item of the spreadsheet (cross-space: plain UUID).
  late final _isd.ColumnUuid spreadsheetItemUuid;

  /// Sheets EmbeddedObject id.
  late final _isd.ColumnUuid chartObjectId;

  /// Sheet of the chart at the last update (08 A-08-2).
  late final _isd.ColumnString sheetId;

  /// The Sheets ChartSpec at the last update ("gz:" prefix when > 32 KB).
  /// Always written together with dataSnapshotJson (P4).
  late final _isd.ColumnString sourceSpecJson;

  /// Resolved series/categories at the last update (08 §3.4).
  late final _isd.ColumnString dataSnapshotJson;

  /// Opaque version of the source at the last update (08 §5.1).
  late final _isd.ColumnString sourceVersion;

  /// When the snapshot was taken.
  late final _isd.ColumnDateTime updatedAt;

  late final _isd.ColumnUuid updatedBy;

  /// "Update automatically" (08).
  late final _isd.ColumnBool autoUpdate;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SlideElementTable get element {
    if (_element != null) return _element!;
    _element = _isd.createRelationTable(
      relationFieldName: 'element',
      field: ChartLink.t.elementId,
      foreignField: _i810rwvy.SlideElement.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SlideElementTable(tableRelation: foreignTableRelation),
    );
    return _element!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    elementId,
    spreadsheetItemUuid,
    chartObjectId,
    sheetId,
    sourceSpecJson,
    dataSnapshotJson,
    sourceVersion,
    updatedAt,
    updatedBy,
    autoUpdate,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'element') {
      return element;
    }
    return null;
  }
}

class ChartLinkInclude extends _isd.IncludeObject {
  ChartLinkInclude._({_i810rwvy.SlideElementInclude? element}) {
    _element = element;
  }

  _i810rwvy.SlideElementInclude? _element;

  @override
  Map<String, _isd.Include?> get includes => {'element': _element};

  @override
  _isd.Table<_iss.UuidValue> get table => ChartLink.t;
}

class ChartLinkIncludeList extends _isd.IncludeList {
  ChartLinkIncludeList._({
    _isd.WhereExpressionBuilder<ChartLinkTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ChartLink.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => ChartLink.t;
}

class ChartLinkRepository {
  const ChartLinkRepository._();

  final attachRow = const ChartLinkAttachRowRepository._();

  /// Returns a list of [ChartLink]s matching the given query parameters.
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
  Future<List<ChartLink>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ChartLinkTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ChartLinkTable>? orderBy,
    _isd.OrderByListBuilder<ChartLinkTable>? orderByList,
    _isd.Transaction? transaction,
    ChartLinkInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ChartLink>(
      where: where?.call(ChartLink.t),
      orderBy: orderBy?.call(ChartLink.t),
      orderByList: orderByList?.call(ChartLink.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ChartLink]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ChartLink.t`.
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
  _ida.Stream<List<ChartLink>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ChartLinkTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ChartLinkTable>? orderBy,
    _isd.OrderByListBuilder<ChartLinkTable>? orderByList,
    ChartLinkInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ChartLink>(
      where: where?.call(ChartLink.t),
      orderBy: orderBy?.call(ChartLink.t),
      orderByList: orderByList?.call(ChartLink.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ChartLink] matching the given query parameters.
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
  Future<ChartLink?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ChartLinkTable>? where,
    int? offset,
    _isd.OrderByBuilder<ChartLinkTable>? orderBy,
    _isd.OrderByListBuilder<ChartLinkTable>? orderByList,
    _isd.Transaction? transaction,
    ChartLinkInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ChartLink>(
      where: where?.call(ChartLink.t),
      orderBy: orderBy?.call(ChartLink.t),
      orderByList: orderByList?.call(ChartLink.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ChartLink] by its [id] or null if no such row exists.
  Future<ChartLink?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    ChartLinkInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ChartLink>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ChartLink]s in the list and returns the inserted rows.
  ///
  /// The returned [ChartLink]s will have their `id` fields set.
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
  Future<List<ChartLink>> insert(
    _isd.DatabaseSession session,
    List<ChartLink> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ChartLink>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ChartLink] and returns the inserted row.
  ///
  /// The returned [ChartLink] will have its `id` field set.
  Future<ChartLink> insertRow(
    _isd.DatabaseSession session,
    ChartLink row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<ChartLink>(row, transaction: transaction);
  }

  /// Upserts all [ChartLink]s in the list and returns the resulting rows.
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
  /// The returned [ChartLink]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ChartLink>> upsert(
    _isd.DatabaseSession session,
    List<ChartLink> rows, {
    required _isd.ColumnSelections<ChartLinkTable> conflictColumns,
    _isd.ColumnSelections<ChartLinkTable>? updateColumns,
    _isd.WhereExpressionBuilder<ChartLinkTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ChartLink>(
      rows,
      conflictColumns: conflictColumns(ChartLink.t),
      updateColumns: updateColumns?.call(ChartLink.t),
      updateWhere: updateWhere?.call(ChartLink.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ChartLink] and returns the resulting row.
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
  /// The returned [ChartLink] will have its `id` field set.
  Future<ChartLink?> upsertRow(
    _isd.DatabaseSession session,
    ChartLink row, {
    required _isd.ColumnSelections<ChartLinkTable> conflictColumns,
    _isd.ColumnSelections<ChartLinkTable>? updateColumns,
    _isd.WhereExpressionBuilder<ChartLinkTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ChartLink>(
      row,
      conflictColumns: conflictColumns(ChartLink.t),
      updateColumns: updateColumns?.call(ChartLink.t),
      updateWhere: updateWhere?.call(ChartLink.t),
      transaction: transaction,
    );
  }

  /// Updates all [ChartLink]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ChartLink>> update(
    _isd.DatabaseSession session,
    List<ChartLink> rows, {
    _isd.ColumnSelections<ChartLinkTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ChartLink>(
      rows,
      columns: columns?.call(ChartLink.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ChartLink]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ChartLink> updateRow(
    _isd.DatabaseSession session,
    ChartLink row, {
    _isd.ColumnSelections<ChartLinkTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<ChartLink>(
      row,
      columns: columns?.call(ChartLink.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ChartLink] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ChartLink?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<ChartLinkUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<ChartLink>(
      id,
      columnValues: columnValues(ChartLink.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ChartLink]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ChartLink>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<ChartLinkUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<ChartLinkTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<ChartLinkTable>? orderBy,
    _isd.OrderByListBuilder<ChartLinkTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ChartLink>(
      columnValues: columnValues(ChartLink.t.updateTable),
      where: where(ChartLink.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChartLink.t),
      orderByList: orderByList?.call(ChartLink.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ChartLink]s in the list and returns the deleted rows.
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
  Future<List<ChartLink>> delete(
    _isd.DatabaseSession session,
    List<ChartLink> rows, {
    _isd.OrderByBuilder<ChartLinkTable>? orderBy,
    _isd.OrderByListBuilder<ChartLinkTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ChartLink>(
      rows,
      orderBy: orderBy?.call(ChartLink.t),
      orderByList: orderByList?.call(ChartLink.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ChartLink].
  Future<ChartLink> deleteRow(
    _isd.DatabaseSession session,
    ChartLink row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ChartLink>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ChartLink>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ChartLinkTable> where,
    _isd.OrderByBuilder<ChartLinkTable>? orderBy,
    _isd.OrderByListBuilder<ChartLinkTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ChartLink>(
      where: where(ChartLink.t),
      orderBy: orderBy?.call(ChartLink.t),
      orderByList: orderByList?.call(ChartLink.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<ChartLinkTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<ChartLink>(
      where: where?.call(ChartLink.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ChartLink] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<ChartLinkTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ChartLink>(
      where: where(ChartLink.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class ChartLinkAttachRowRepository {
  const ChartLinkAttachRowRepository._();

  /// Creates a relation between the given [ChartLink] and [SlideElement]
  /// by setting the [ChartLink]'s foreign key `elementId` to refer to the [SlideElement].
  Future<void> element(
    _isd.DatabaseSession session,
    ChartLink chartLink,
    _i810rwvy.SlideElement element, {
    _isd.Transaction? transaction,
  }) async {
    if (chartLink.id == null) {
      throw ArgumentError.notNull('chartLink.id');
    }
    if (element.id == null) {
      throw ArgumentError.notNull('element.id');
    }

    var $chartLink = chartLink.copyWith(elementId: element.id);
    await session.db.updateRow<ChartLink>(
      $chartLink,
      columns: [ChartLink.t.elementId],
      transaction: transaction,
    );
  }
}
