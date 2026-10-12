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

/// Per-user view state of a drive item (specs/05 §1). A row also makes a
/// link-shared item appear in "Shared with me" after the first open.
abstract class DriveItemUserState
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  DriveItemUserState._({
    this.id,
    required this.itemId,
    required this.userId,
    bool? starred,
    this.lastOpenedAt,
    this.lastEditedAt,
    bool? pinnedOffline,
    this.shortcutParentId,
    bool? viaLink,
  }) : starred = starred ?? false,
       pinnedOffline = pinnedOffline ?? false,
       viaLink = viaLink ?? false;

  factory DriveItemUserState({
    int? id,
    required int itemId,
    required int userId,
    bool? starred,
    DateTime? lastOpenedAt,
    DateTime? lastEditedAt,
    bool? pinnedOffline,
    int? shortcutParentId,
    bool? viaLink,
  }) = _DriveItemUserStateImpl;

  factory DriveItemUserState.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveItemUserState(
      id: jsonSerialization['id'] as int?,
      itemId: jsonSerialization['itemId'] as int,
      userId: jsonSerialization['userId'] as int,
      starred: jsonSerialization['starred'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['starred']),
      lastOpenedAt: jsonSerialization['lastOpenedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastOpenedAt'],
            ),
      lastEditedAt: jsonSerialization['lastEditedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastEditedAt'],
            ),
      pinnedOffline: jsonSerialization['pinnedOffline'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['pinnedOffline']),
      shortcutParentId: jsonSerialization['shortcutParentId'] as int?,
      viaLink: jsonSerialization['viaLink'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['viaLink']),
    );
  }

  static final t = DriveItemUserStateTable();

  static const db = DriveItemUserStateRepository._();

  @override
  int? id;

  int itemId;

  int userId;

  bool starred;

  DateTime? lastOpenedAt;

  DateTime? lastEditedAt;

  bool pinnedOffline;

  /// "Add shortcut to My Drive" for shared items.
  int? shortcutParentId;

  /// The user opened the item through its share link.
  bool viaLink;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [DriveItemUserState]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DriveItemUserState copyWith({
    int? id,
    int? itemId,
    int? userId,
    bool? starred,
    DateTime? lastOpenedAt = const _is.$UndefinedDateTime(),
    DateTime? lastEditedAt = const _is.$UndefinedDateTime(),
    bool? pinnedOffline,
    int? shortcutParentId,
    bool? viaLink,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveItemUserState',
      if (id != null) 'id': id,
      'itemId': itemId,
      'userId': userId,
      'starred': starred,
      if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt?.toJson(),
      if (lastEditedAt != null) 'lastEditedAt': lastEditedAt?.toJson(),
      'pinnedOffline': pinnedOffline,
      if (shortcutParentId != null) 'shortcutParentId': shortcutParentId,
      'viaLink': viaLink,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveItemUserState',
      if (id != null) 'id': id,
      'itemId': itemId,
      'userId': userId,
      'starred': starred,
      if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt?.toJson(),
      if (lastEditedAt != null) 'lastEditedAt': lastEditedAt?.toJson(),
      'pinnedOffline': pinnedOffline,
      if (shortcutParentId != null) 'shortcutParentId': shortcutParentId,
      'viaLink': viaLink,
    };
  }

  static DriveItemUserStateInclude include() {
    return DriveItemUserStateInclude._();
  }

  static DriveItemUserStateIncludeList includeList({
    _is.WhereExpressionBuilder<DriveItemUserStateTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DriveItemUserStateTable>? orderBy,
    _is.OrderByListBuilder<DriveItemUserStateTable>? orderByList,
    DriveItemUserStateInclude? include,
  }) {
    return DriveItemUserStateIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DriveItemUserState.t),
      orderByList: orderByList?.call(DriveItemUserState.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DriveItemUserStateImpl extends DriveItemUserState {
  _DriveItemUserStateImpl({
    int? id,
    required int itemId,
    required int userId,
    bool? starred,
    DateTime? lastOpenedAt,
    DateTime? lastEditedAt,
    bool? pinnedOffline,
    int? shortcutParentId,
    bool? viaLink,
  }) : super._(
         id: id,
         itemId: itemId,
         userId: userId,
         starred: starred,
         lastOpenedAt: lastOpenedAt,
         lastEditedAt: lastEditedAt,
         pinnedOffline: pinnedOffline,
         shortcutParentId: shortcutParentId,
         viaLink: viaLink,
       );

  /// Returns a shallow copy of this [DriveItemUserState]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DriveItemUserState copyWith({
    Object? id = _Undefined,
    int? itemId,
    int? userId,
    bool? starred,
    DateTime? lastOpenedAt = const _is.$UndefinedDateTime(),
    DateTime? lastEditedAt = const _is.$UndefinedDateTime(),
    bool? pinnedOffline,
    Object? shortcutParentId = _Undefined,
    bool? viaLink,
  }) {
    return DriveItemUserState(
      id: id is int? ? id : this.id,
      itemId: itemId ?? this.itemId,
      userId: userId ?? this.userId,
      starred: starred ?? this.starred,
      lastOpenedAt: lastOpenedAt is _is.UndefinedSentinel
          ? this.lastOpenedAt
          : lastOpenedAt,
      lastEditedAt: lastEditedAt is _is.UndefinedSentinel
          ? this.lastEditedAt
          : lastEditedAt,
      pinnedOffline: pinnedOffline ?? this.pinnedOffline,
      shortcutParentId: shortcutParentId is int?
          ? shortcutParentId
          : this.shortcutParentId,
      viaLink: viaLink ?? this.viaLink,
    );
  }
}

class DriveItemUserStateUpdateTable
    extends _is.UpdateTable<DriveItemUserStateTable> {
  DriveItemUserStateUpdateTable(super.table);

  _is.ColumnValue<int, int> itemId(int value) => _is.ColumnValue(
    table.itemId,
    value,
  );

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<bool, bool> starred(bool value) => _is.ColumnValue(
    table.starred,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> lastOpenedAt(DateTime? value) =>
      _is.ColumnValue(
        table.lastOpenedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> lastEditedAt(DateTime? value) =>
      _is.ColumnValue(
        table.lastEditedAt,
        value,
      );

  _is.ColumnValue<bool, bool> pinnedOffline(bool value) => _is.ColumnValue(
    table.pinnedOffline,
    value,
  );

  _is.ColumnValue<int, int> shortcutParentId(int? value) => _is.ColumnValue(
    table.shortcutParentId,
    value,
  );

  _is.ColumnValue<bool, bool> viaLink(bool value) => _is.ColumnValue(
    table.viaLink,
    value,
  );
}

class DriveItemUserStateTable extends _is.Table<int?> {
  DriveItemUserStateTable({super.tableRelation})
    : super(tableName: 'drive_item_user_state') {
    updateTable = DriveItemUserStateUpdateTable(this);
    itemId = _is.ColumnInt(
      'itemId',
      this,
    );
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    starred = _is.ColumnBool(
      'starred',
      this,
      hasDefault: true,
    );
    lastOpenedAt = _is.ColumnDateTime(
      'lastOpenedAt',
      this,
    );
    lastEditedAt = _is.ColumnDateTime(
      'lastEditedAt',
      this,
    );
    pinnedOffline = _is.ColumnBool(
      'pinnedOffline',
      this,
      hasDefault: true,
    );
    shortcutParentId = _is.ColumnInt(
      'shortcutParentId',
      this,
    );
    viaLink = _is.ColumnBool(
      'viaLink',
      this,
      hasDefault: true,
    );
  }

  late final DriveItemUserStateUpdateTable updateTable;

  late final _is.ColumnInt itemId;

  late final _is.ColumnInt userId;

  late final _is.ColumnBool starred;

  late final _is.ColumnDateTime lastOpenedAt;

  late final _is.ColumnDateTime lastEditedAt;

  late final _is.ColumnBool pinnedOffline;

  /// "Add shortcut to My Drive" for shared items.
  late final _is.ColumnInt shortcutParentId;

  /// The user opened the item through its share link.
  late final _is.ColumnBool viaLink;

  @override
  List<_is.Column> get columns => [
    id,
    itemId,
    userId,
    starred,
    lastOpenedAt,
    lastEditedAt,
    pinnedOffline,
    shortcutParentId,
    viaLink,
  ];
}

class DriveItemUserStateInclude extends _is.IncludeObject {
  DriveItemUserStateInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => DriveItemUserState.t;
}

class DriveItemUserStateIncludeList extends _is.IncludeList {
  DriveItemUserStateIncludeList._({
    _is.WhereExpressionBuilder<DriveItemUserStateTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DriveItemUserState.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => DriveItemUserState.t;
}

class DriveItemUserStateRepository {
  const DriveItemUserStateRepository._();

  /// Returns a list of [DriveItemUserState]s matching the given query parameters.
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
  Future<List<DriveItemUserState>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DriveItemUserStateTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DriveItemUserStateTable>? orderBy,
    _is.OrderByListBuilder<DriveItemUserStateTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DriveItemUserState>(
      where: where?.call(DriveItemUserState.t),
      orderBy: orderBy?.call(DriveItemUserState.t),
      orderByList: orderByList?.call(DriveItemUserState.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [DriveItemUserState]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `DriveItemUserState.t`.
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
  _ida.Stream<List<DriveItemUserState>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DriveItemUserStateTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DriveItemUserStateTable>? orderBy,
    _is.OrderByListBuilder<DriveItemUserStateTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<DriveItemUserState>(
      where: where?.call(DriveItemUserState.t),
      orderBy: orderBy?.call(DriveItemUserState.t),
      orderByList: orderByList?.call(DriveItemUserState.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [DriveItemUserState] matching the given query parameters.
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
  Future<DriveItemUserState?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DriveItemUserStateTable>? where,
    int? offset,
    _is.OrderByBuilder<DriveItemUserStateTable>? orderBy,
    _is.OrderByListBuilder<DriveItemUserStateTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DriveItemUserState>(
      where: where?.call(DriveItemUserState.t),
      orderBy: orderBy?.call(DriveItemUserState.t),
      orderByList: orderByList?.call(DriveItemUserState.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DriveItemUserState] by its [id] or null if no such row exists.
  Future<DriveItemUserState?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DriveItemUserState>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DriveItemUserState]s in the list and returns the inserted rows.
  ///
  /// The returned [DriveItemUserState]s will have their `id` fields set.
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
  Future<List<DriveItemUserState>> insert(
    _is.DatabaseSession session,
    List<DriveItemUserState> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DriveItemUserState>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DriveItemUserState] and returns the inserted row.
  ///
  /// The returned [DriveItemUserState] will have its `id` field set.
  Future<DriveItemUserState> insertRow(
    _is.DatabaseSession session,
    DriveItemUserState row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<DriveItemUserState>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [DriveItemUserState]s in the list and returns the resulting rows.
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
  /// The returned [DriveItemUserState]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DriveItemUserState>> upsert(
    _is.DatabaseSession session,
    List<DriveItemUserState> rows, {
    required _is.ColumnSelections<DriveItemUserStateTable> conflictColumns,
    _is.ColumnSelections<DriveItemUserStateTable>? updateColumns,
    _is.WhereExpressionBuilder<DriveItemUserStateTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DriveItemUserState>(
      rows,
      conflictColumns: conflictColumns(DriveItemUserState.t),
      updateColumns: updateColumns?.call(DriveItemUserState.t),
      updateWhere: updateWhere?.call(DriveItemUserState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DriveItemUserState] and returns the resulting row.
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
  /// The returned [DriveItemUserState] will have its `id` field set.
  Future<DriveItemUserState?> upsertRow(
    _is.DatabaseSession session,
    DriveItemUserState row, {
    required _is.ColumnSelections<DriveItemUserStateTable> conflictColumns,
    _is.ColumnSelections<DriveItemUserStateTable>? updateColumns,
    _is.WhereExpressionBuilder<DriveItemUserStateTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DriveItemUserState>(
      row,
      conflictColumns: conflictColumns(DriveItemUserState.t),
      updateColumns: updateColumns?.call(DriveItemUserState.t),
      updateWhere: updateWhere?.call(DriveItemUserState.t),
      transaction: transaction,
    );
  }

  /// Updates all [DriveItemUserState]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DriveItemUserState>> update(
    _is.DatabaseSession session,
    List<DriveItemUserState> rows, {
    _is.ColumnSelections<DriveItemUserStateTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DriveItemUserState>(
      rows,
      columns: columns?.call(DriveItemUserState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DriveItemUserState]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DriveItemUserState> updateRow(
    _is.DatabaseSession session,
    DriveItemUserState row, {
    _is.ColumnSelections<DriveItemUserStateTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<DriveItemUserState>(
      row,
      columns: columns?.call(DriveItemUserState.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DriveItemUserState] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DriveItemUserState?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<DriveItemUserStateUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<DriveItemUserState>(
      id,
      columnValues: columnValues(DriveItemUserState.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DriveItemUserState]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DriveItemUserState>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<DriveItemUserStateUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<DriveItemUserStateTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DriveItemUserStateTable>? orderBy,
    _is.OrderByListBuilder<DriveItemUserStateTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DriveItemUserState>(
      columnValues: columnValues(DriveItemUserState.t.updateTable),
      where: where(DriveItemUserState.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DriveItemUserState.t),
      orderByList: orderByList?.call(DriveItemUserState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DriveItemUserState]s in the list and returns the deleted rows.
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
  Future<List<DriveItemUserState>> delete(
    _is.DatabaseSession session,
    List<DriveItemUserState> rows, {
    _is.OrderByBuilder<DriveItemUserStateTable>? orderBy,
    _is.OrderByListBuilder<DriveItemUserStateTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DriveItemUserState>(
      rows,
      orderBy: orderBy?.call(DriveItemUserState.t),
      orderByList: orderByList?.call(DriveItemUserState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DriveItemUserState].
  Future<DriveItemUserState> deleteRow(
    _is.DatabaseSession session,
    DriveItemUserState row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DriveItemUserState>(
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
  Future<List<DriveItemUserState>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DriveItemUserStateTable> where,
    _is.OrderByBuilder<DriveItemUserStateTable>? orderBy,
    _is.OrderByListBuilder<DriveItemUserStateTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DriveItemUserState>(
      where: where(DriveItemUserState.t),
      orderBy: orderBy?.call(DriveItemUserState.t),
      orderByList: orderByList?.call(DriveItemUserState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DriveItemUserStateTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<DriveItemUserState>(
      where: where?.call(DriveItemUserState.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DriveItemUserState] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DriveItemUserStateTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DriveItemUserState>(
      where: where(DriveItemUserState.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
