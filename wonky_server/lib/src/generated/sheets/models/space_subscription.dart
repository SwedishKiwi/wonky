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
import '../../sheets/models/subscription_reason.dart' as _ixa5hb2h;

/// The server-managed active set: membership doubles as subscription.
abstract class SpaceSubscription
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SpaceSubscription._({
    this.id,
    required this.userId,
    required this.spreadsheetItemId,
    required this.spaceUuid,
    _in1d3ohj.SpaceKind? kind,
    required this.reason,
    required this.lastUsedAt,
    bool? pinned,
    this.reasonExpiresAt,
  }) : kind = kind ?? _in1d3ohj.SpaceKind.spreadsheet,
       pinned = pinned ?? false;

  factory SpaceSubscription({
    int? id,
    required int userId,
    required int spreadsheetItemId,
    required _is.UuidValue spaceUuid,
    _in1d3ohj.SpaceKind? kind,
    required _ixa5hb2h.SubscriptionReason reason,
    required DateTime lastUsedAt,
    bool? pinned,
    DateTime? reasonExpiresAt,
  }) = _SpaceSubscriptionImpl;

  factory SpaceSubscription.fromJson(Map<String, dynamic> jsonSerialization) {
    return SpaceSubscription(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      spreadsheetItemId: jsonSerialization['spreadsheetItemId'] as int,
      spaceUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spaceUuid'],
      ),
      kind: jsonSerialization['kind'] == null
          ? null
          : _in1d3ohj.SpaceKind.fromJson((jsonSerialization['kind'] as String)),
      reason: _ixa5hb2h.SubscriptionReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
      lastUsedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['lastUsedAt'],
      ),
      pinned: jsonSerialization['pinned'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['pinned']),
      reasonExpiresAt: jsonSerialization['reasonExpiresAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['reasonExpiresAt'],
            ),
    );
  }

  static final t = SpaceSubscriptionTable();

  static const db = SpaceSubscriptionRepository._();

  @override
  int? id;

  int userId;

  /// The drive item of the space: a spreadsheet, or (v2) a presentation for
  /// [kind] deck (the column keeps its v1 name).
  int spreadsheetItemId;

  _is.UuidValue spaceUuid;

  /// (v2) Space kind; active-set limits apply per kind (suite 12 §2.6).
  _in1d3ohj.SpaceKind kind;

  _ixa5hb2h.SubscriptionReason reason;

  DateTime lastUsedAt;

  bool pinned;

  /// When the temporary mcp/script reason expires.
  DateTime? reasonExpiresAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SpaceSubscription]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SpaceSubscription copyWith({
    int? id,
    int? userId,
    int? spreadsheetItemId,
    _is.UuidValue? spaceUuid,
    _in1d3ohj.SpaceKind? kind,
    _ixa5hb2h.SubscriptionReason? reason,
    DateTime? lastUsedAt,
    bool? pinned,
    DateTime? reasonExpiresAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SpaceSubscription',
      if (id != null) 'id': id,
      'userId': userId,
      'spreadsheetItemId': spreadsheetItemId,
      'spaceUuid': spaceUuid.toJson(),
      'kind': kind.toJson(),
      'reason': reason.toJson(),
      'lastUsedAt': lastUsedAt.toJson(),
      'pinned': pinned,
      if (reasonExpiresAt != null) 'reasonExpiresAt': reasonExpiresAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SpaceSubscriptionInclude include() {
    return SpaceSubscriptionInclude._();
  }

  static SpaceSubscriptionIncludeList includeList({
    _is.WhereExpressionBuilder<SpaceSubscriptionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SpaceSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<SpaceSubscriptionTable>? orderByList,
    SpaceSubscriptionInclude? include,
  }) {
    return SpaceSubscriptionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SpaceSubscription.t),
      orderByList: orderByList?.call(SpaceSubscription.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SpaceSubscriptionImpl extends SpaceSubscription {
  _SpaceSubscriptionImpl({
    int? id,
    required int userId,
    required int spreadsheetItemId,
    required _is.UuidValue spaceUuid,
    _in1d3ohj.SpaceKind? kind,
    required _ixa5hb2h.SubscriptionReason reason,
    required DateTime lastUsedAt,
    bool? pinned,
    DateTime? reasonExpiresAt,
  }) : super._(
         id: id,
         userId: userId,
         spreadsheetItemId: spreadsheetItemId,
         spaceUuid: spaceUuid,
         kind: kind,
         reason: reason,
         lastUsedAt: lastUsedAt,
         pinned: pinned,
         reasonExpiresAt: reasonExpiresAt,
       );

  /// Returns a shallow copy of this [SpaceSubscription]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SpaceSubscription copyWith({
    Object? id = _Undefined,
    int? userId,
    int? spreadsheetItemId,
    _is.UuidValue? spaceUuid,
    _in1d3ohj.SpaceKind? kind,
    _ixa5hb2h.SubscriptionReason? reason,
    DateTime? lastUsedAt,
    bool? pinned,
    DateTime? reasonExpiresAt = const _is.$UndefinedDateTime(),
  }) {
    return SpaceSubscription(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      spreadsheetItemId: spreadsheetItemId ?? this.spreadsheetItemId,
      spaceUuid: spaceUuid ?? this.spaceUuid,
      kind: kind ?? this.kind,
      reason: reason ?? this.reason,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      pinned: pinned ?? this.pinned,
      reasonExpiresAt: reasonExpiresAt is _is.UndefinedSentinel
          ? this.reasonExpiresAt
          : reasonExpiresAt,
    );
  }
}

class SpaceSubscriptionUpdateTable
    extends _is.UpdateTable<SpaceSubscriptionTable> {
  SpaceSubscriptionUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<int, int> spreadsheetItemId(int value) => _is.ColumnValue(
    table.spreadsheetItemId,
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

  _is.ColumnValue<_ixa5hb2h.SubscriptionReason, _ixa5hb2h.SubscriptionReason>
  reason(_ixa5hb2h.SubscriptionReason value) => _is.ColumnValue(
    table.reason,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> lastUsedAt(DateTime value) =>
      _is.ColumnValue(
        table.lastUsedAt,
        value,
      );

  _is.ColumnValue<bool, bool> pinned(bool value) => _is.ColumnValue(
    table.pinned,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> reasonExpiresAt(DateTime? value) =>
      _is.ColumnValue(
        table.reasonExpiresAt,
        value,
      );
}

class SpaceSubscriptionTable extends _is.Table<int?> {
  SpaceSubscriptionTable({super.tableRelation})
    : super(tableName: 'space_subscription') {
    updateTable = SpaceSubscriptionUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    spreadsheetItemId = _is.ColumnInt(
      'spreadsheetItemId',
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
    reason = _is.ColumnEnum(
      'reason',
      this,
      _is.EnumSerialization.byName,
    );
    lastUsedAt = _is.ColumnDateTime(
      'lastUsedAt',
      this,
    );
    pinned = _is.ColumnBool(
      'pinned',
      this,
      hasDefault: true,
    );
    reasonExpiresAt = _is.ColumnDateTime(
      'reasonExpiresAt',
      this,
    );
  }

  late final SpaceSubscriptionUpdateTable updateTable;

  late final _is.ColumnInt userId;

  /// The drive item of the space: a spreadsheet, or (v2) a presentation for
  /// [kind] deck (the column keeps its v1 name).
  late final _is.ColumnInt spreadsheetItemId;

  late final _is.ColumnUuid spaceUuid;

  /// (v2) Space kind; active-set limits apply per kind (suite 12 §2.6).
  late final _is.ColumnEnum<_in1d3ohj.SpaceKind> kind;

  late final _is.ColumnEnum<_ixa5hb2h.SubscriptionReason> reason;

  late final _is.ColumnDateTime lastUsedAt;

  late final _is.ColumnBool pinned;

  /// When the temporary mcp/script reason expires.
  late final _is.ColumnDateTime reasonExpiresAt;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    spreadsheetItemId,
    spaceUuid,
    kind,
    reason,
    lastUsedAt,
    pinned,
    reasonExpiresAt,
  ];
}

class SpaceSubscriptionInclude extends _is.IncludeObject {
  SpaceSubscriptionInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SpaceSubscription.t;
}

class SpaceSubscriptionIncludeList extends _is.IncludeList {
  SpaceSubscriptionIncludeList._({
    _is.WhereExpressionBuilder<SpaceSubscriptionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SpaceSubscription.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SpaceSubscription.t;
}

class SpaceSubscriptionRepository {
  const SpaceSubscriptionRepository._();

  /// Returns a list of [SpaceSubscription]s matching the given query parameters.
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
  Future<List<SpaceSubscription>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SpaceSubscriptionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SpaceSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<SpaceSubscriptionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SpaceSubscription>(
      where: where?.call(SpaceSubscription.t),
      orderBy: orderBy?.call(SpaceSubscription.t),
      orderByList: orderByList?.call(SpaceSubscription.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SpaceSubscription]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SpaceSubscription.t`.
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
  _ida.Stream<List<SpaceSubscription>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SpaceSubscriptionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SpaceSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<SpaceSubscriptionTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SpaceSubscription>(
      where: where?.call(SpaceSubscription.t),
      orderBy: orderBy?.call(SpaceSubscription.t),
      orderByList: orderByList?.call(SpaceSubscription.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SpaceSubscription] matching the given query parameters.
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
  Future<SpaceSubscription?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SpaceSubscriptionTable>? where,
    int? offset,
    _is.OrderByBuilder<SpaceSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<SpaceSubscriptionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SpaceSubscription>(
      where: where?.call(SpaceSubscription.t),
      orderBy: orderBy?.call(SpaceSubscription.t),
      orderByList: orderByList?.call(SpaceSubscription.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SpaceSubscription] by its [id] or null if no such row exists.
  Future<SpaceSubscription?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SpaceSubscription>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SpaceSubscription]s in the list and returns the inserted rows.
  ///
  /// The returned [SpaceSubscription]s will have their `id` fields set.
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
  Future<List<SpaceSubscription>> insert(
    _is.DatabaseSession session,
    List<SpaceSubscription> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SpaceSubscription>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SpaceSubscription] and returns the inserted row.
  ///
  /// The returned [SpaceSubscription] will have its `id` field set.
  Future<SpaceSubscription> insertRow(
    _is.DatabaseSession session,
    SpaceSubscription row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SpaceSubscription>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SpaceSubscription]s in the list and returns the resulting rows.
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
  /// The returned [SpaceSubscription]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SpaceSubscription>> upsert(
    _is.DatabaseSession session,
    List<SpaceSubscription> rows, {
    required _is.ColumnSelections<SpaceSubscriptionTable> conflictColumns,
    _is.ColumnSelections<SpaceSubscriptionTable>? updateColumns,
    _is.WhereExpressionBuilder<SpaceSubscriptionTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SpaceSubscription>(
      rows,
      conflictColumns: conflictColumns(SpaceSubscription.t),
      updateColumns: updateColumns?.call(SpaceSubscription.t),
      updateWhere: updateWhere?.call(SpaceSubscription.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SpaceSubscription] and returns the resulting row.
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
  /// The returned [SpaceSubscription] will have its `id` field set.
  Future<SpaceSubscription?> upsertRow(
    _is.DatabaseSession session,
    SpaceSubscription row, {
    required _is.ColumnSelections<SpaceSubscriptionTable> conflictColumns,
    _is.ColumnSelections<SpaceSubscriptionTable>? updateColumns,
    _is.WhereExpressionBuilder<SpaceSubscriptionTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SpaceSubscription>(
      row,
      conflictColumns: conflictColumns(SpaceSubscription.t),
      updateColumns: updateColumns?.call(SpaceSubscription.t),
      updateWhere: updateWhere?.call(SpaceSubscription.t),
      transaction: transaction,
    );
  }

  /// Updates all [SpaceSubscription]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SpaceSubscription>> update(
    _is.DatabaseSession session,
    List<SpaceSubscription> rows, {
    _is.ColumnSelections<SpaceSubscriptionTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SpaceSubscription>(
      rows,
      columns: columns?.call(SpaceSubscription.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SpaceSubscription]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SpaceSubscription> updateRow(
    _is.DatabaseSession session,
    SpaceSubscription row, {
    _is.ColumnSelections<SpaceSubscriptionTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SpaceSubscription>(
      row,
      columns: columns?.call(SpaceSubscription.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SpaceSubscription] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SpaceSubscription?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SpaceSubscriptionUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SpaceSubscription>(
      id,
      columnValues: columnValues(SpaceSubscription.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SpaceSubscription]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SpaceSubscription>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SpaceSubscriptionUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<SpaceSubscriptionTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SpaceSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<SpaceSubscriptionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SpaceSubscription>(
      columnValues: columnValues(SpaceSubscription.t.updateTable),
      where: where(SpaceSubscription.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SpaceSubscription.t),
      orderByList: orderByList?.call(SpaceSubscription.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SpaceSubscription]s in the list and returns the deleted rows.
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
  Future<List<SpaceSubscription>> delete(
    _is.DatabaseSession session,
    List<SpaceSubscription> rows, {
    _is.OrderByBuilder<SpaceSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<SpaceSubscriptionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SpaceSubscription>(
      rows,
      orderBy: orderBy?.call(SpaceSubscription.t),
      orderByList: orderByList?.call(SpaceSubscription.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SpaceSubscription].
  Future<SpaceSubscription> deleteRow(
    _is.DatabaseSession session,
    SpaceSubscription row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SpaceSubscription>(
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
  Future<List<SpaceSubscription>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SpaceSubscriptionTable> where,
    _is.OrderByBuilder<SpaceSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<SpaceSubscriptionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SpaceSubscription>(
      where: where(SpaceSubscription.t),
      orderBy: orderBy?.call(SpaceSubscription.t),
      orderByList: orderByList?.call(SpaceSubscription.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SpaceSubscriptionTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SpaceSubscription>(
      where: where?.call(SpaceSubscription.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SpaceSubscription] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SpaceSubscriptionTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SpaceSubscription>(
      where: where(SpaceSubscription.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
