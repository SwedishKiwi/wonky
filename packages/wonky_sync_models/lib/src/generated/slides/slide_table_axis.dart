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

/// A row or column of a table element (Slides 02 §3.6), like Sheets'
/// rows/columns so concurrent structure edits merge.
abstract class SlideTableAxis
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  SlideTableAxis._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.elementId,
    this.element,
    required this.dimension,
    required this.sortKey,
    this.size,
    bool? header,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       header = header ?? false,
       createdAt = createdAt ?? DateTime.now();

  factory SlideTableAxis({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue elementId,
    _i810rwvy.SlideElement? element,
    required _i810rwvy.TableDimension dimension,
    required String sortKey,
    double? size,
    bool? header,
    DateTime? createdAt,
  }) = _SlideTableAxisImpl;

  factory SlideTableAxis.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlideTableAxis(
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
      dimension: _i810rwvy.TableDimension.fromJson(
        (jsonSerialization['dimension'] as String),
      ),
      sortKey: jsonSerialization['sortKey'] as String,
      size: (jsonSerialization['size'] as num?)?.toDouble(),
      header: jsonSerialization['header'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['header']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = SlideTableAxisTable();

  static const db = SlideTableAxisRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue elementId;

  /// The table element (kind table).
  _i810rwvy.SlideElement? element;

  _i810rwvy.TableDimension dimension;

  /// Order among the axes of one table and dimension.
  String sortKey;

  /// su; row: min height (rows grow to fit text); null = even split.
  double? size;

  /// Header row / first column styling (05 §2.8).
  bool header;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [SlideTableAxis]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  SlideTableAxis copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? elementId,
    _i810rwvy.SlideElement? element = const _UndefinedSlideTableAxis$element(),
    _i810rwvy.TableDimension? dimension,
    String? sortKey,
    double? size,
    bool? header,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlideTableAxis',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'elementId': elementId.toJson(),
      if (element != null) 'element': element?.toJson(),
      'dimension': dimension.toJson(),
      'sortKey': sortKey,
      if (size != null) 'size': size,
      'header': header,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlideTableAxis',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'elementId': elementId.toJson(),
      if (element != null) 'element': element?.toJsonForProtocol(),
      'dimension': dimension.toJson(),
      'sortKey': sortKey,
      if (size != null) 'size': size,
      'header': header,
      'createdAt': createdAt.toJson(),
    };
  }

  static SlideTableAxisInclude include({
    _i810rwvy.SlideElementInclude? element,
  }) {
    return SlideTableAxisInclude._(element: element);
  }

  static SlideTableAxisIncludeList includeList({
    _isd.WhereExpressionBuilder<SlideTableAxisTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTableAxisTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableAxisTable>? orderByList,
    SlideTableAxisInclude? include,
  }) {
    return SlideTableAxisIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideTableAxis.t),
      orderByList: orderByList?.call(SlideTableAxis.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedSlideTableAxis$element extends _iss.UndefinedSentinel
    implements _i810rwvy.SlideElement {
  const _UndefinedSlideTableAxis$element();
}

class _SlideTableAxisImpl extends SlideTableAxis {
  _SlideTableAxisImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue elementId,
    _i810rwvy.SlideElement? element,
    required _i810rwvy.TableDimension dimension,
    required String sortKey,
    double? size,
    bool? header,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         elementId: elementId,
         element: element,
         dimension: dimension,
         sortKey: sortKey,
         size: size,
         header: header,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SlideTableAxis]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  SlideTableAxis copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? elementId,
    _i810rwvy.SlideElement? element = const _UndefinedSlideTableAxis$element(),
    _i810rwvy.TableDimension? dimension,
    String? sortKey,
    Object? size = _Undefined,
    bool? header,
    DateTime? createdAt,
  }) {
    return SlideTableAxis(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      elementId: elementId ?? this.elementId,
      element: element is _iss.UndefinedSentinel
          ? this.element?.copyWith()
          : element,
      dimension: dimension ?? this.dimension,
      sortKey: sortKey ?? this.sortKey,
      size: size is double? ? size : this.size,
      header: header ?? this.header,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SlideTableAxisUpdateTable extends _isd.UpdateTable<SlideTableAxisTable> {
  SlideTableAxisUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> elementId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.elementId, value);

  _isd.ColumnValue<_i810rwvy.TableDimension, _i810rwvy.TableDimension>
  dimension(_i810rwvy.TableDimension value) =>
      _isd.ColumnValue(table.dimension, value);

  _isd.ColumnValue<String, String> sortKey(String value) =>
      _isd.ColumnValue(table.sortKey, value);

  _isd.ColumnValue<double, double> size(double? value) =>
      _isd.ColumnValue(table.size, value);

  _isd.ColumnValue<bool, bool> header(bool value) =>
      _isd.ColumnValue(table.header, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class SlideTableAxisTable extends _isd.Table<_iss.UuidValue> {
  SlideTableAxisTable({super.tableRelation})
    : super(tableName: 'slide_table_axis') {
    updateTable = SlideTableAxisUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    elementId = _isd.ColumnUuid('elementId', this);
    dimension = _isd.ColumnEnum(
      'dimension',
      this,
      _isd.EnumSerialization.byName,
    );
    sortKey = _isd.ColumnString('sortKey', this);
    size = _isd.ColumnDouble('size', this);
    header = _isd.ColumnBool('header', this, hasDefault: true);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final SlideTableAxisUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid elementId;

  /// The table element (kind table).
  _i810rwvy.SlideElementTable? _element;

  late final _isd.ColumnEnum<_i810rwvy.TableDimension> dimension;

  /// Order among the axes of one table and dimension.
  late final _isd.ColumnString sortKey;

  /// su; row: min height (rows grow to fit text); null = even split.
  late final _isd.ColumnDouble size;

  /// Header row / first column styling (05 §2.8).
  late final _isd.ColumnBool header;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SlideElementTable get element {
    if (_element != null) return _element!;
    _element = _isd.createRelationTable(
      relationFieldName: 'element',
      field: SlideTableAxis.t.elementId,
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
    dimension,
    sortKey,
    size,
    header,
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

class SlideTableAxisInclude extends _isd.IncludeObject {
  SlideTableAxisInclude._({_i810rwvy.SlideElementInclude? element}) {
    _element = element;
  }

  _i810rwvy.SlideElementInclude? _element;

  @override
  Map<String, _isd.Include?> get includes => {'element': _element};

  @override
  _isd.Table<_iss.UuidValue> get table => SlideTableAxis.t;
}

class SlideTableAxisIncludeList extends _isd.IncludeList {
  SlideTableAxisIncludeList._({
    _isd.WhereExpressionBuilder<SlideTableAxisTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SlideTableAxis.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => SlideTableAxis.t;
}

class SlideTableAxisRepository {
  const SlideTableAxisRepository._();

  final attachRow = const SlideTableAxisAttachRowRepository._();

  /// Returns a list of [SlideTableAxis]s matching the given query parameters.
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
  Future<List<SlideTableAxis>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTableAxisTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTableAxisTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableAxisTable>? orderByList,
    _isd.Transaction? transaction,
    SlideTableAxisInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SlideTableAxis>(
      where: where?.call(SlideTableAxis.t),
      orderBy: orderBy?.call(SlideTableAxis.t),
      orderByList: orderByList?.call(SlideTableAxis.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SlideTableAxis]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SlideTableAxis.t`.
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
  _ida.Stream<List<SlideTableAxis>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTableAxisTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTableAxisTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableAxisTable>? orderByList,
    SlideTableAxisInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SlideTableAxis>(
      where: where?.call(SlideTableAxis.t),
      orderBy: orderBy?.call(SlideTableAxis.t),
      orderByList: orderByList?.call(SlideTableAxis.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SlideTableAxis] matching the given query parameters.
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
  Future<SlideTableAxis?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTableAxisTable>? where,
    int? offset,
    _isd.OrderByBuilder<SlideTableAxisTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableAxisTable>? orderByList,
    _isd.Transaction? transaction,
    SlideTableAxisInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SlideTableAxis>(
      where: where?.call(SlideTableAxis.t),
      orderBy: orderBy?.call(SlideTableAxis.t),
      orderByList: orderByList?.call(SlideTableAxis.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SlideTableAxis] by its [id] or null if no such row exists.
  Future<SlideTableAxis?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SlideTableAxisInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SlideTableAxis>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SlideTableAxis]s in the list and returns the inserted rows.
  ///
  /// The returned [SlideTableAxis]s will have their `id` fields set.
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
  Future<List<SlideTableAxis>> insert(
    _isd.DatabaseSession session,
    List<SlideTableAxis> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SlideTableAxis>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SlideTableAxis] and returns the inserted row.
  ///
  /// The returned [SlideTableAxis] will have its `id` field set.
  Future<SlideTableAxis> insertRow(
    _isd.DatabaseSession session,
    SlideTableAxis row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SlideTableAxis>(row, transaction: transaction);
  }

  /// Upserts all [SlideTableAxis]s in the list and returns the resulting rows.
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
  /// The returned [SlideTableAxis]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideTableAxis>> upsert(
    _isd.DatabaseSession session,
    List<SlideTableAxis> rows, {
    required _isd.ColumnSelections<SlideTableAxisTable> conflictColumns,
    _isd.ColumnSelections<SlideTableAxisTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideTableAxisTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SlideTableAxis>(
      rows,
      conflictColumns: conflictColumns(SlideTableAxis.t),
      updateColumns: updateColumns?.call(SlideTableAxis.t),
      updateWhere: updateWhere?.call(SlideTableAxis.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SlideTableAxis] and returns the resulting row.
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
  /// The returned [SlideTableAxis] will have its `id` field set.
  Future<SlideTableAxis?> upsertRow(
    _isd.DatabaseSession session,
    SlideTableAxis row, {
    required _isd.ColumnSelections<SlideTableAxisTable> conflictColumns,
    _isd.ColumnSelections<SlideTableAxisTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideTableAxisTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SlideTableAxis>(
      row,
      conflictColumns: conflictColumns(SlideTableAxis.t),
      updateColumns: updateColumns?.call(SlideTableAxis.t),
      updateWhere: updateWhere?.call(SlideTableAxis.t),
      transaction: transaction,
    );
  }

  /// Updates all [SlideTableAxis]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideTableAxis>> update(
    _isd.DatabaseSession session,
    List<SlideTableAxis> rows, {
    _isd.ColumnSelections<SlideTableAxisTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SlideTableAxis>(
      rows,
      columns: columns?.call(SlideTableAxis.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SlideTableAxis]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SlideTableAxis> updateRow(
    _isd.DatabaseSession session,
    SlideTableAxis row, {
    _isd.ColumnSelections<SlideTableAxisTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SlideTableAxis>(
      row,
      columns: columns?.call(SlideTableAxis.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SlideTableAxis] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SlideTableAxis?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SlideTableAxisUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SlideTableAxis>(
      id,
      columnValues: columnValues(SlideTableAxis.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SlideTableAxis]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideTableAxis>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SlideTableAxisUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<SlideTableAxisTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTableAxisTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableAxisTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SlideTableAxis>(
      columnValues: columnValues(SlideTableAxis.t.updateTable),
      where: where(SlideTableAxis.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideTableAxis.t),
      orderByList: orderByList?.call(SlideTableAxis.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SlideTableAxis]s in the list and returns the deleted rows.
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
  Future<List<SlideTableAxis>> delete(
    _isd.DatabaseSession session,
    List<SlideTableAxis> rows, {
    _isd.OrderByBuilder<SlideTableAxisTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableAxisTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SlideTableAxis>(
      rows,
      orderBy: orderBy?.call(SlideTableAxis.t),
      orderByList: orderByList?.call(SlideTableAxis.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SlideTableAxis].
  Future<SlideTableAxis> deleteRow(
    _isd.DatabaseSession session,
    SlideTableAxis row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SlideTableAxis>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideTableAxis>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideTableAxisTable> where,
    _isd.OrderByBuilder<SlideTableAxisTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableAxisTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SlideTableAxis>(
      where: where(SlideTableAxis.t),
      orderBy: orderBy?.call(SlideTableAxis.t),
      orderByList: orderByList?.call(SlideTableAxis.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTableAxisTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SlideTableAxis>(
      where: where?.call(SlideTableAxis.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SlideTableAxis] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideTableAxisTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SlideTableAxis>(
      where: where(SlideTableAxis.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SlideTableAxisAttachRowRepository {
  const SlideTableAxisAttachRowRepository._();

  /// Creates a relation between the given [SlideTableAxis] and [SlideElement]
  /// by setting the [SlideTableAxis]'s foreign key `elementId` to refer to the [SlideElement].
  Future<void> element(
    _isd.DatabaseSession session,
    SlideTableAxis slideTableAxis,
    _i810rwvy.SlideElement element, {
    _isd.Transaction? transaction,
  }) async {
    if (slideTableAxis.id == null) {
      throw ArgumentError.notNull('slideTableAxis.id');
    }
    if (element.id == null) {
      throw ArgumentError.notNull('element.id');
    }

    var $slideTableAxis = slideTableAxis.copyWith(elementId: element.id);
    await session.db.updateRow<SlideTableAxis>(
      $slideTableAxis,
      columns: [SlideTableAxis.t.elementId],
      transaction: transaction,
    );
  }
}
