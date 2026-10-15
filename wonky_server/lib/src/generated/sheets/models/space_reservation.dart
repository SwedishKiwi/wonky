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
import '../../sheets/models/space_kind.dart' as _in1d3ohj;

/// An empty space reserved for offline creation of a spreadsheet or (v2) a
/// deck (suite 12 §2.2, §2.6).
abstract class SpaceReservation
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SpaceReservation._({
    this.id,
    required this.userId,
    required this.spaceUuid,
    _in1d3ohj.SpaceKind? kind,
    required this.createdAt,
    this.usedAt,
  }) : kind = kind ?? _in1d3ohj.SpaceKind.spreadsheet;

  factory SpaceReservation({
    int? id,
    required int userId,
    required _is.UuidValue spaceUuid,
    _in1d3ohj.SpaceKind? kind,
    required DateTime createdAt,
    DateTime? usedAt,
  }) = _SpaceReservationImpl;

  factory SpaceReservation.fromJson(Map<String, dynamic> jsonSerialization) {
    return SpaceReservation(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      spaceUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spaceUuid'],
      ),
      kind: jsonSerialization['kind'] == null
          ? null
          : _in1d3ohj.SpaceKind.fromJson((jsonSerialization['kind'] as String)),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      usedAt: jsonSerialization['usedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['usedAt']),
    );
  }

  static final t = SpaceReservationTable();

  static const db = SpaceReservationRepository._();

  @override
  int? id;

  int userId;

  _is.UuidValue spaceUuid;

  /// (v2) The kind of item the space is reserved for.
  _in1d3ohj.SpaceKind kind;

  DateTime createdAt;

  /// Set when a spreadsheet is registered in the space.
  DateTime? usedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SpaceReservation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SpaceReservation copyWith({
    int? id,
    int? userId,
    _is.UuidValue? spaceUuid,
    _in1d3ohj.SpaceKind? kind,
    DateTime? createdAt,
    DateTime? usedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SpaceReservation',
      if (id != null) 'id': id,
      'userId': userId,
      'spaceUuid': spaceUuid.toJson(),
      'kind': kind.toJson(),
      'createdAt': createdAt.toJson(),
      if (usedAt != null) 'usedAt': usedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SpaceReservationInclude include() {
    return SpaceReservationInclude._();
  }

  static SpaceReservationIncludeList includeList({
    _is.WhereExpressionBuilder<SpaceReservationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SpaceReservationTable>? orderBy,
    _is.OrderByListBuilder<SpaceReservationTable>? orderByList,
    SpaceReservationInclude? include,
  }) {
    return SpaceReservationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SpaceReservation.t),
      orderByList: orderByList?.call(SpaceReservation.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SpaceReservationImpl extends SpaceReservation {
  _SpaceReservationImpl({
    int? id,
    required int userId,
    required _is.UuidValue spaceUuid,
    _in1d3ohj.SpaceKind? kind,
    required DateTime createdAt,
    DateTime? usedAt,
  }) : super._(
         id: id,
         userId: userId,
         spaceUuid: spaceUuid,
         kind: kind,
         createdAt: createdAt,
         usedAt: usedAt,
       );

  /// Returns a shallow copy of this [SpaceReservation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SpaceReservation copyWith({
    Object? id = _Undefined,
    int? userId,
    _is.UuidValue? spaceUuid,
    _in1d3ohj.SpaceKind? kind,
    DateTime? createdAt,
    DateTime? usedAt = const _is.$UndefinedDateTime(),
  }) {
    return SpaceReservation(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      spaceUuid: spaceUuid ?? this.spaceUuid,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      usedAt: usedAt is _is.UndefinedSentinel ? this.usedAt : usedAt,
    );
  }
}

class SpaceReservationUpdateTable
    extends _is.UpdateTable<SpaceReservationTable> {
  SpaceReservationUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> spaceUuid(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.spaceUuid,
    value,
  );

  _is.ColumnValue<_in1d3ohj.SpaceKind, _in1d3ohj.SpaceKind> kind(
    _in1d3ohj.SpaceKind value,
  ) => _is.ColumnValue(
    table.kind,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> usedAt(DateTime? value) =>
      _is.ColumnValue(
        table.usedAt,
        value,
      );
}

class SpaceReservationTable extends _is.Table<int?> {
  SpaceReservationTable({super.tableRelation})
    : super(tableName: 'space_reservation') {
    updateTable = SpaceReservationUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    spaceUuid = _is.ColumnUuid(
      'spaceUuid',
      this,
    );
    kind = _is.ColumnEnum(
      'kind',
      this,
      _is.EnumSerialization.byName,
      hasDefault: true,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    usedAt = _is.ColumnDateTime(
      'usedAt',
      this,
    );
  }

  late final SpaceReservationUpdateTable updateTable;

  late final _is.ColumnInt userId;

  late final _is.ColumnUuid spaceUuid;

  /// (v2) The kind of item the space is reserved for.
  late final _is.ColumnEnum<_in1d3ohj.SpaceKind> kind;

  late final _is.ColumnDateTime createdAt;

  /// Set when a spreadsheet is registered in the space.
  late final _is.ColumnDateTime usedAt;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    spaceUuid,
    kind,
    createdAt,
    usedAt,
  ];
}

class SpaceReservationInclude extends _is.IncludeObject {
  SpaceReservationInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SpaceReservation.t;
}

class SpaceReservationIncludeList extends _is.IncludeList {
  SpaceReservationIncludeList._({
    _is.WhereExpressionBuilder<SpaceReservationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SpaceReservation.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SpaceReservation.t;
}

class SpaceReservationRepository {
  const SpaceReservationRepository._();

  /// Returns a list of [SpaceReservation]s matching the given query parameters.
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
  Future<List<SpaceReservation>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SpaceReservationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SpaceReservationTable>? orderBy,
    _is.OrderByListBuilder<SpaceReservationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SpaceReservation>(
      where: where?.call(SpaceReservation.t),
      orderBy: orderBy?.call(SpaceReservation.t),
      orderByList: orderByList?.call(SpaceReservation.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SpaceReservation]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SpaceReservation.t`.
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
  _ida.Stream<List<SpaceReservation>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SpaceReservationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SpaceReservationTable>? orderBy,
    _is.OrderByListBuilder<SpaceReservationTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SpaceReservation>(
      where: where?.call(SpaceReservation.t),
      orderBy: orderBy?.call(SpaceReservation.t),
      orderByList: orderByList?.call(SpaceReservation.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SpaceReservation] matching the given query parameters.
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
  Future<SpaceReservation?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SpaceReservationTable>? where,
    int? offset,
    _is.OrderByBuilder<SpaceReservationTable>? orderBy,
    _is.OrderByListBuilder<SpaceReservationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SpaceReservation>(
      where: where?.call(SpaceReservation.t),
      orderBy: orderBy?.call(SpaceReservation.t),
      orderByList: orderByList?.call(SpaceReservation.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SpaceReservation] by its [id] or null if no such row exists.
  Future<SpaceReservation?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SpaceReservation>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SpaceReservation]s in the list and returns the inserted rows.
  ///
  /// The returned [SpaceReservation]s will have their `id` fields set.
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
  Future<List<SpaceReservation>> insert(
    _is.DatabaseSession session,
    List<SpaceReservation> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SpaceReservation>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SpaceReservation] and returns the inserted row.
  ///
  /// The returned [SpaceReservation] will have its `id` field set.
  Future<SpaceReservation> insertRow(
    _is.DatabaseSession session,
    SpaceReservation row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SpaceReservation>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SpaceReservation]s in the list and returns the resulting rows.
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
  /// The returned [SpaceReservation]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SpaceReservation>> upsert(
    _is.DatabaseSession session,
    List<SpaceReservation> rows, {
    required _is.ColumnSelections<SpaceReservationTable> conflictColumns,
    _is.ColumnSelections<SpaceReservationTable>? updateColumns,
    _is.WhereExpressionBuilder<SpaceReservationTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SpaceReservation>(
      rows,
      conflictColumns: conflictColumns(SpaceReservation.t),
      updateColumns: updateColumns?.call(SpaceReservation.t),
      updateWhere: updateWhere?.call(SpaceReservation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SpaceReservation] and returns the resulting row.
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
  /// The returned [SpaceReservation] will have its `id` field set.
  Future<SpaceReservation?> upsertRow(
    _is.DatabaseSession session,
    SpaceReservation row, {
    required _is.ColumnSelections<SpaceReservationTable> conflictColumns,
    _is.ColumnSelections<SpaceReservationTable>? updateColumns,
    _is.WhereExpressionBuilder<SpaceReservationTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SpaceReservation>(
      row,
      conflictColumns: conflictColumns(SpaceReservation.t),
      updateColumns: updateColumns?.call(SpaceReservation.t),
      updateWhere: updateWhere?.call(SpaceReservation.t),
      transaction: transaction,
    );
  }

  /// Updates all [SpaceReservation]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SpaceReservation>> update(
    _is.DatabaseSession session,
    List<SpaceReservation> rows, {
    _is.ColumnSelections<SpaceReservationTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SpaceReservation>(
      rows,
      columns: columns?.call(SpaceReservation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SpaceReservation]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SpaceReservation> updateRow(
    _is.DatabaseSession session,
    SpaceReservation row, {
    _is.ColumnSelections<SpaceReservationTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SpaceReservation>(
      row,
      columns: columns?.call(SpaceReservation.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SpaceReservation] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SpaceReservation?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SpaceReservationUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SpaceReservation>(
      id,
      columnValues: columnValues(SpaceReservation.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SpaceReservation]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SpaceReservation>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SpaceReservationUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<SpaceReservationTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SpaceReservationTable>? orderBy,
    _is.OrderByListBuilder<SpaceReservationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SpaceReservation>(
      columnValues: columnValues(SpaceReservation.t.updateTable),
      where: where(SpaceReservation.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SpaceReservation.t),
      orderByList: orderByList?.call(SpaceReservation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SpaceReservation]s in the list and returns the deleted rows.
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
  Future<List<SpaceReservation>> delete(
    _is.DatabaseSession session,
    List<SpaceReservation> rows, {
    _is.OrderByBuilder<SpaceReservationTable>? orderBy,
    _is.OrderByListBuilder<SpaceReservationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SpaceReservation>(
      rows,
      orderBy: orderBy?.call(SpaceReservation.t),
      orderByList: orderByList?.call(SpaceReservation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SpaceReservation].
  Future<SpaceReservation> deleteRow(
    _is.DatabaseSession session,
    SpaceReservation row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SpaceReservation>(
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
  Future<List<SpaceReservation>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SpaceReservationTable> where,
    _is.OrderByBuilder<SpaceReservationTable>? orderBy,
    _is.OrderByListBuilder<SpaceReservationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SpaceReservation>(
      where: where(SpaceReservation.t),
      orderBy: orderBy?.call(SpaceReservation.t),
      orderByList: orderByList?.call(SpaceReservation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SpaceReservationTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SpaceReservation>(
      where: where?.call(SpaceReservation.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SpaceReservation] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SpaceReservationTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SpaceReservation>(
      where: where(SpaceReservation.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
