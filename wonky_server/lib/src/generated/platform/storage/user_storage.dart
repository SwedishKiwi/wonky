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

/// (v2) Storage counters of a user (Drive 03 §4.1). Maintained
/// transactionally by `StorageService`; reconciled nightly from the source
/// rows.
abstract class UserStorage
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  UserStorage._({
    this.id,
    required this.userId,
    int? usedBytes,
    int? reservedBytes,
    int? documentsBytes,
    int? spreadsheetsBytes,
    int? presentationsBytes,
    int? filesBytes,
    int? trashBytes,
    this.quotaBytesOverride,
    this.overQuotaSince,
    this.reconciledAt,
    required this.updatedAt,
  }) : usedBytes = usedBytes ?? 0,
       reservedBytes = reservedBytes ?? 0,
       documentsBytes = documentsBytes ?? 0,
       spreadsheetsBytes = spreadsheetsBytes ?? 0,
       presentationsBytes = presentationsBytes ?? 0,
       filesBytes = filesBytes ?? 0,
       trashBytes = trashBytes ?? 0;

  factory UserStorage({
    int? id,
    required int userId,
    int? usedBytes,
    int? reservedBytes,
    int? documentsBytes,
    int? spreadsheetsBytes,
    int? presentationsBytes,
    int? filesBytes,
    int? trashBytes,
    int? quotaBytesOverride,
    DateTime? overQuotaSince,
    DateTime? reconciledAt,
    required DateTime updatedAt,
  }) = _UserStorageImpl;

  factory UserStorage.fromJson(Map<String, dynamic> jsonSerialization) {
    return UserStorage(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      usedBytes: jsonSerialization['usedBytes'] as int?,
      reservedBytes: jsonSerialization['reservedBytes'] as int?,
      documentsBytes: jsonSerialization['documentsBytes'] as int?,
      spreadsheetsBytes: jsonSerialization['spreadsheetsBytes'] as int?,
      presentationsBytes: jsonSerialization['presentationsBytes'] as int?,
      filesBytes: jsonSerialization['filesBytes'] as int?,
      trashBytes: jsonSerialization['trashBytes'] as int?,
      quotaBytesOverride: jsonSerialization['quotaBytesOverride'] as int?,
      overQuotaSince: jsonSerialization['overQuotaSince'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['overQuotaSince'],
            ),
      reconciledAt: jsonSerialization['reconciledAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['reconciledAt'],
            ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = UserStorageTable();

  static const db = UserStorageRepository._();

  @override
  int? id;

  int userId;

  /// Σ counted size of owned items (incl. trash).
  int usedBytes;

  /// Σ open reservations.
  int reservedBytes;

  int documentsBytes;

  int spreadsheetsBytes;

  int presentationsBytes;

  int filesBytes;

  int trashBytes;

  /// Null = the config default (`wonky.drive.quotaBytesPerUser`).
  int? quotaBytesOverride;

  /// Set/cleared when usedBytes crosses the quota.
  DateTime? overQuotaSince;

  /// Null until the first reconcile/backfill (Drive 03 §9).
  DateTime? reconciledAt;

  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [UserStorage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  UserStorage copyWith({
    int? id,
    int? userId,
    int? usedBytes,
    int? reservedBytes,
    int? documentsBytes,
    int? spreadsheetsBytes,
    int? presentationsBytes,
    int? filesBytes,
    int? trashBytes,
    int? quotaBytesOverride,
    DateTime? overQuotaSince = const _is.$UndefinedDateTime(),
    DateTime? reconciledAt = const _is.$UndefinedDateTime(),
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserStorage',
      if (id != null) 'id': id,
      'userId': userId,
      'usedBytes': usedBytes,
      'reservedBytes': reservedBytes,
      'documentsBytes': documentsBytes,
      'spreadsheetsBytes': spreadsheetsBytes,
      'presentationsBytes': presentationsBytes,
      'filesBytes': filesBytes,
      'trashBytes': trashBytes,
      if (quotaBytesOverride != null) 'quotaBytesOverride': quotaBytesOverride,
      if (overQuotaSince != null) 'overQuotaSince': overQuotaSince?.toJson(),
      if (reconciledAt != null) 'reconciledAt': reconciledAt?.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static UserStorageInclude include() {
    return UserStorageInclude._();
  }

  static UserStorageIncludeList includeList({
    _is.WhereExpressionBuilder<UserStorageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UserStorageTable>? orderBy,
    _is.OrderByListBuilder<UserStorageTable>? orderByList,
    UserStorageInclude? include,
  }) {
    return UserStorageIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UserStorage.t),
      orderByList: orderByList?.call(UserStorage.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserStorageImpl extends UserStorage {
  _UserStorageImpl({
    int? id,
    required int userId,
    int? usedBytes,
    int? reservedBytes,
    int? documentsBytes,
    int? spreadsheetsBytes,
    int? presentationsBytes,
    int? filesBytes,
    int? trashBytes,
    int? quotaBytesOverride,
    DateTime? overQuotaSince,
    DateTime? reconciledAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         userId: userId,
         usedBytes: usedBytes,
         reservedBytes: reservedBytes,
         documentsBytes: documentsBytes,
         spreadsheetsBytes: spreadsheetsBytes,
         presentationsBytes: presentationsBytes,
         filesBytes: filesBytes,
         trashBytes: trashBytes,
         quotaBytesOverride: quotaBytesOverride,
         overQuotaSince: overQuotaSince,
         reconciledAt: reconciledAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [UserStorage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UserStorage copyWith({
    Object? id = _Undefined,
    int? userId,
    int? usedBytes,
    int? reservedBytes,
    int? documentsBytes,
    int? spreadsheetsBytes,
    int? presentationsBytes,
    int? filesBytes,
    int? trashBytes,
    Object? quotaBytesOverride = _Undefined,
    DateTime? overQuotaSince = const _is.$UndefinedDateTime(),
    DateTime? reconciledAt = const _is.$UndefinedDateTime(),
    DateTime? updatedAt,
  }) {
    return UserStorage(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      usedBytes: usedBytes ?? this.usedBytes,
      reservedBytes: reservedBytes ?? this.reservedBytes,
      documentsBytes: documentsBytes ?? this.documentsBytes,
      spreadsheetsBytes: spreadsheetsBytes ?? this.spreadsheetsBytes,
      presentationsBytes: presentationsBytes ?? this.presentationsBytes,
      filesBytes: filesBytes ?? this.filesBytes,
      trashBytes: trashBytes ?? this.trashBytes,
      quotaBytesOverride: quotaBytesOverride is int?
          ? quotaBytesOverride
          : this.quotaBytesOverride,
      overQuotaSince: overQuotaSince is _is.UndefinedSentinel
          ? this.overQuotaSince
          : overQuotaSince,
      reconciledAt: reconciledAt is _is.UndefinedSentinel
          ? this.reconciledAt
          : reconciledAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserStorageUpdateTable extends _is.UpdateTable<UserStorageTable> {
  UserStorageUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<int, int> usedBytes(int value) => _is.ColumnValue(
    table.usedBytes,
    value,
  );

  _is.ColumnValue<int, int> reservedBytes(int value) => _is.ColumnValue(
    table.reservedBytes,
    value,
  );

  _is.ColumnValue<int, int> documentsBytes(int value) => _is.ColumnValue(
    table.documentsBytes,
    value,
  );

  _is.ColumnValue<int, int> spreadsheetsBytes(int value) => _is.ColumnValue(
    table.spreadsheetsBytes,
    value,
  );

  _is.ColumnValue<int, int> presentationsBytes(int value) => _is.ColumnValue(
    table.presentationsBytes,
    value,
  );

  _is.ColumnValue<int, int> filesBytes(int value) => _is.ColumnValue(
    table.filesBytes,
    value,
  );

  _is.ColumnValue<int, int> trashBytes(int value) => _is.ColumnValue(
    table.trashBytes,
    value,
  );

  _is.ColumnValue<int, int> quotaBytesOverride(int? value) => _is.ColumnValue(
    table.quotaBytesOverride,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> overQuotaSince(DateTime? value) =>
      _is.ColumnValue(
        table.overQuotaSince,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> reconciledAt(DateTime? value) =>
      _is.ColumnValue(
        table.reconciledAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class UserStorageTable extends _is.Table<int?> {
  UserStorageTable({super.tableRelation}) : super(tableName: 'user_storage') {
    updateTable = UserStorageUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    usedBytes = _is.ColumnInt(
      'usedBytes',
      this,
      hasDefault: true,
    );
    reservedBytes = _is.ColumnInt(
      'reservedBytes',
      this,
      hasDefault: true,
    );
    documentsBytes = _is.ColumnInt(
      'documentsBytes',
      this,
      hasDefault: true,
    );
    spreadsheetsBytes = _is.ColumnInt(
      'spreadsheetsBytes',
      this,
      hasDefault: true,
    );
    presentationsBytes = _is.ColumnInt(
      'presentationsBytes',
      this,
      hasDefault: true,
    );
    filesBytes = _is.ColumnInt(
      'filesBytes',
      this,
      hasDefault: true,
    );
    trashBytes = _is.ColumnInt(
      'trashBytes',
      this,
      hasDefault: true,
    );
    quotaBytesOverride = _is.ColumnInt(
      'quotaBytesOverride',
      this,
    );
    overQuotaSince = _is.ColumnDateTime(
      'overQuotaSince',
      this,
    );
    reconciledAt = _is.ColumnDateTime(
      'reconciledAt',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final UserStorageUpdateTable updateTable;

  late final _is.ColumnInt userId;

  /// Σ counted size of owned items (incl. trash).
  late final _is.ColumnInt usedBytes;

  /// Σ open reservations.
  late final _is.ColumnInt reservedBytes;

  late final _is.ColumnInt documentsBytes;

  late final _is.ColumnInt spreadsheetsBytes;

  late final _is.ColumnInt presentationsBytes;

  late final _is.ColumnInt filesBytes;

  late final _is.ColumnInt trashBytes;

  /// Null = the config default (`wonky.drive.quotaBytesPerUser`).
  late final _is.ColumnInt quotaBytesOverride;

  /// Set/cleared when usedBytes crosses the quota.
  late final _is.ColumnDateTime overQuotaSince;

  /// Null until the first reconcile/backfill (Drive 03 §9).
  late final _is.ColumnDateTime reconciledAt;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    usedBytes,
    reservedBytes,
    documentsBytes,
    spreadsheetsBytes,
    presentationsBytes,
    filesBytes,
    trashBytes,
    quotaBytesOverride,
    overQuotaSince,
    reconciledAt,
    updatedAt,
  ];
}

class UserStorageInclude extends _is.IncludeObject {
  UserStorageInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => UserStorage.t;
}

class UserStorageIncludeList extends _is.IncludeList {
  UserStorageIncludeList._({
    _is.WhereExpressionBuilder<UserStorageTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UserStorage.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => UserStorage.t;
}

class UserStorageRepository {
  const UserStorageRepository._();

  /// Returns a list of [UserStorage]s matching the given query parameters.
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
  Future<List<UserStorage>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UserStorageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UserStorageTable>? orderBy,
    _is.OrderByListBuilder<UserStorageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UserStorage>(
      where: where?.call(UserStorage.t),
      orderBy: orderBy?.call(UserStorage.t),
      orderByList: orderByList?.call(UserStorage.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [UserStorage]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `UserStorage.t`.
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
  _ida.Stream<List<UserStorage>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UserStorageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UserStorageTable>? orderBy,
    _is.OrderByListBuilder<UserStorageTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<UserStorage>(
      where: where?.call(UserStorage.t),
      orderBy: orderBy?.call(UserStorage.t),
      orderByList: orderByList?.call(UserStorage.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [UserStorage] matching the given query parameters.
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
  Future<UserStorage?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UserStorageTable>? where,
    int? offset,
    _is.OrderByBuilder<UserStorageTable>? orderBy,
    _is.OrderByListBuilder<UserStorageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UserStorage>(
      where: where?.call(UserStorage.t),
      orderBy: orderBy?.call(UserStorage.t),
      orderByList: orderByList?.call(UserStorage.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UserStorage] by its [id] or null if no such row exists.
  Future<UserStorage?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UserStorage>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UserStorage]s in the list and returns the inserted rows.
  ///
  /// The returned [UserStorage]s will have their `id` fields set.
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
  Future<List<UserStorage>> insert(
    _is.DatabaseSession session,
    List<UserStorage> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UserStorage>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UserStorage] and returns the inserted row.
  ///
  /// The returned [UserStorage] will have its `id` field set.
  Future<UserStorage> insertRow(
    _is.DatabaseSession session,
    UserStorage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<UserStorage>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UserStorage]s in the list and returns the resulting rows.
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
  /// The returned [UserStorage]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UserStorage>> upsert(
    _is.DatabaseSession session,
    List<UserStorage> rows, {
    required _is.ColumnSelections<UserStorageTable> conflictColumns,
    _is.ColumnSelections<UserStorageTable>? updateColumns,
    _is.WhereExpressionBuilder<UserStorageTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UserStorage>(
      rows,
      conflictColumns: conflictColumns(UserStorage.t),
      updateColumns: updateColumns?.call(UserStorage.t),
      updateWhere: updateWhere?.call(UserStorage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UserStorage] and returns the resulting row.
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
  /// The returned [UserStorage] will have its `id` field set.
  Future<UserStorage?> upsertRow(
    _is.DatabaseSession session,
    UserStorage row, {
    required _is.ColumnSelections<UserStorageTable> conflictColumns,
    _is.ColumnSelections<UserStorageTable>? updateColumns,
    _is.WhereExpressionBuilder<UserStorageTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UserStorage>(
      row,
      conflictColumns: conflictColumns(UserStorage.t),
      updateColumns: updateColumns?.call(UserStorage.t),
      updateWhere: updateWhere?.call(UserStorage.t),
      transaction: transaction,
    );
  }

  /// Updates all [UserStorage]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UserStorage>> update(
    _is.DatabaseSession session,
    List<UserStorage> rows, {
    _is.ColumnSelections<UserStorageTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UserStorage>(
      rows,
      columns: columns?.call(UserStorage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UserStorage]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UserStorage> updateRow(
    _is.DatabaseSession session,
    UserStorage row, {
    _is.ColumnSelections<UserStorageTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<UserStorage>(
      row,
      columns: columns?.call(UserStorage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UserStorage] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UserStorage?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<UserStorageUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<UserStorage>(
      id,
      columnValues: columnValues(UserStorage.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UserStorage]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UserStorage>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<UserStorageUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<UserStorageTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UserStorageTable>? orderBy,
    _is.OrderByListBuilder<UserStorageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UserStorage>(
      columnValues: columnValues(UserStorage.t.updateTable),
      where: where(UserStorage.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UserStorage.t),
      orderByList: orderByList?.call(UserStorage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UserStorage]s in the list and returns the deleted rows.
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
  Future<List<UserStorage>> delete(
    _is.DatabaseSession session,
    List<UserStorage> rows, {
    _is.OrderByBuilder<UserStorageTable>? orderBy,
    _is.OrderByListBuilder<UserStorageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UserStorage>(
      rows,
      orderBy: orderBy?.call(UserStorage.t),
      orderByList: orderByList?.call(UserStorage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UserStorage].
  Future<UserStorage> deleteRow(
    _is.DatabaseSession session,
    UserStorage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UserStorage>(
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
  Future<List<UserStorage>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UserStorageTable> where,
    _is.OrderByBuilder<UserStorageTable>? orderBy,
    _is.OrderByListBuilder<UserStorageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UserStorage>(
      where: where(UserStorage.t),
      orderBy: orderBy?.call(UserStorage.t),
      orderByList: orderByList?.call(UserStorage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UserStorageTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<UserStorage>(
      where: where?.call(UserStorage.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UserStorage] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UserStorageTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UserStorage>(
      where: where(UserStorage.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
