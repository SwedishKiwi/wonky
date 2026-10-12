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
import '../../platform/feedback/feedback_kind.dart' as _id0rnmad;

/// "Report a problem" submissions and client error reports.
abstract class FeedbackReport
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  FeedbackReport._({
    this.id,
    this.userId,
    required this.kind,
    required this.message,
    required this.app,
    required this.appVersion,
    required this.platform,
    this.route,
    this.stackTrace,
    this.contextJson,
    required this.createdAt,
  });

  factory FeedbackReport({
    int? id,
    int? userId,
    required _id0rnmad.FeedbackKind kind,
    required String message,
    required String app,
    required String appVersion,
    required String platform,
    String? route,
    String? stackTrace,
    String? contextJson,
    required DateTime createdAt,
  }) = _FeedbackReportImpl;

  factory FeedbackReport.fromJson(Map<String, dynamic> jsonSerialization) {
    return FeedbackReport(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int?,
      kind: _id0rnmad.FeedbackKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      message: jsonSerialization['message'] as String,
      app: jsonSerialization['app'] as String,
      appVersion: jsonSerialization['appVersion'] as String,
      platform: jsonSerialization['platform'] as String,
      route: jsonSerialization['route'] as String?,
      stackTrace: jsonSerialization['stackTrace'] as String?,
      contextJson: jsonSerialization['contextJson'] as String?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = FeedbackReportTable();

  static const db = FeedbackReportRepository._();

  @override
  int? id;

  int? userId;

  _id0rnmad.FeedbackKind kind;

  String message;

  String app;

  String appVersion;

  String platform;

  String? route;

  String? stackTrace;

  String? contextJson;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [FeedbackReport]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  FeedbackReport copyWith({
    int? id,
    int? userId,
    _id0rnmad.FeedbackKind? kind,
    String? message,
    String? app,
    String? appVersion,
    String? platform,
    String? route,
    String? stackTrace,
    String? contextJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FeedbackReport',
      if (id != null) 'id': id,
      if (userId != null) 'userId': userId,
      'kind': kind.toJson(),
      'message': message,
      'app': app,
      'appVersion': appVersion,
      'platform': platform,
      if (route != null) 'route': route,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (contextJson != null) 'contextJson': contextJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static FeedbackReportInclude include() {
    return FeedbackReportInclude._();
  }

  static FeedbackReportIncludeList includeList({
    _is.WhereExpressionBuilder<FeedbackReportTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FeedbackReportTable>? orderBy,
    _is.OrderByListBuilder<FeedbackReportTable>? orderByList,
    FeedbackReportInclude? include,
  }) {
    return FeedbackReportIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FeedbackReport.t),
      orderByList: orderByList?.call(FeedbackReport.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FeedbackReportImpl extends FeedbackReport {
  _FeedbackReportImpl({
    int? id,
    int? userId,
    required _id0rnmad.FeedbackKind kind,
    required String message,
    required String app,
    required String appVersion,
    required String platform,
    String? route,
    String? stackTrace,
    String? contextJson,
    required DateTime createdAt,
  }) : super._(
         id: id,
         userId: userId,
         kind: kind,
         message: message,
         app: app,
         appVersion: appVersion,
         platform: platform,
         route: route,
         stackTrace: stackTrace,
         contextJson: contextJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [FeedbackReport]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  FeedbackReport copyWith({
    Object? id = _Undefined,
    Object? userId = _Undefined,
    _id0rnmad.FeedbackKind? kind,
    String? message,
    String? app,
    String? appVersion,
    String? platform,
    Object? route = _Undefined,
    Object? stackTrace = _Undefined,
    Object? contextJson = _Undefined,
    DateTime? createdAt,
  }) {
    return FeedbackReport(
      id: id is int? ? id : this.id,
      userId: userId is int? ? userId : this.userId,
      kind: kind ?? this.kind,
      message: message ?? this.message,
      app: app ?? this.app,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      route: route is String? ? route : this.route,
      stackTrace: stackTrace is String? ? stackTrace : this.stackTrace,
      contextJson: contextJson is String? ? contextJson : this.contextJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class FeedbackReportUpdateTable extends _is.UpdateTable<FeedbackReportTable> {
  FeedbackReportUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int? value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<_id0rnmad.FeedbackKind, _id0rnmad.FeedbackKind> kind(
    _id0rnmad.FeedbackKind value,
  ) => _is.ColumnValue(
    table.kind,
    value,
  );

  _is.ColumnValue<String, String> message(String value) => _is.ColumnValue(
    table.message,
    value,
  );

  _is.ColumnValue<String, String> app(String value) => _is.ColumnValue(
    table.app,
    value,
  );

  _is.ColumnValue<String, String> appVersion(String value) => _is.ColumnValue(
    table.appVersion,
    value,
  );

  _is.ColumnValue<String, String> platform(String value) => _is.ColumnValue(
    table.platform,
    value,
  );

  _is.ColumnValue<String, String> route(String? value) => _is.ColumnValue(
    table.route,
    value,
  );

  _is.ColumnValue<String, String> stackTrace(String? value) => _is.ColumnValue(
    table.stackTrace,
    value,
  );

  _is.ColumnValue<String, String> contextJson(String? value) => _is.ColumnValue(
    table.contextJson,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class FeedbackReportTable extends _is.Table<int?> {
  FeedbackReportTable({super.tableRelation})
    : super(tableName: 'feedback_report') {
    updateTable = FeedbackReportUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    kind = _is.ColumnEnum(
      'kind',
      this,
      _is.EnumSerialization.byName,
    );
    message = _is.ColumnString(
      'message',
      this,
    );
    app = _is.ColumnString(
      'app',
      this,
    );
    appVersion = _is.ColumnString(
      'appVersion',
      this,
    );
    platform = _is.ColumnString(
      'platform',
      this,
    );
    route = _is.ColumnString(
      'route',
      this,
    );
    stackTrace = _is.ColumnString(
      'stackTrace',
      this,
    );
    contextJson = _is.ColumnString(
      'contextJson',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final FeedbackReportUpdateTable updateTable;

  late final _is.ColumnInt userId;

  late final _is.ColumnEnum<_id0rnmad.FeedbackKind> kind;

  late final _is.ColumnString message;

  late final _is.ColumnString app;

  late final _is.ColumnString appVersion;

  late final _is.ColumnString platform;

  late final _is.ColumnString route;

  late final _is.ColumnString stackTrace;

  late final _is.ColumnString contextJson;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    kind,
    message,
    app,
    appVersion,
    platform,
    route,
    stackTrace,
    contextJson,
    createdAt,
  ];
}

class FeedbackReportInclude extends _is.IncludeObject {
  FeedbackReportInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => FeedbackReport.t;
}

class FeedbackReportIncludeList extends _is.IncludeList {
  FeedbackReportIncludeList._({
    _is.WhereExpressionBuilder<FeedbackReportTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FeedbackReport.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => FeedbackReport.t;
}

class FeedbackReportRepository {
  const FeedbackReportRepository._();

  /// Returns a list of [FeedbackReport]s matching the given query parameters.
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
  Future<List<FeedbackReport>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FeedbackReportTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FeedbackReportTable>? orderBy,
    _is.OrderByListBuilder<FeedbackReportTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FeedbackReport>(
      where: where?.call(FeedbackReport.t),
      orderBy: orderBy?.call(FeedbackReport.t),
      orderByList: orderByList?.call(FeedbackReport.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [FeedbackReport]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `FeedbackReport.t`.
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
  _ida.Stream<List<FeedbackReport>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FeedbackReportTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FeedbackReportTable>? orderBy,
    _is.OrderByListBuilder<FeedbackReportTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<FeedbackReport>(
      where: where?.call(FeedbackReport.t),
      orderBy: orderBy?.call(FeedbackReport.t),
      orderByList: orderByList?.call(FeedbackReport.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [FeedbackReport] matching the given query parameters.
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
  Future<FeedbackReport?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FeedbackReportTable>? where,
    int? offset,
    _is.OrderByBuilder<FeedbackReportTable>? orderBy,
    _is.OrderByListBuilder<FeedbackReportTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FeedbackReport>(
      where: where?.call(FeedbackReport.t),
      orderBy: orderBy?.call(FeedbackReport.t),
      orderByList: orderByList?.call(FeedbackReport.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FeedbackReport] by its [id] or null if no such row exists.
  Future<FeedbackReport?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FeedbackReport>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FeedbackReport]s in the list and returns the inserted rows.
  ///
  /// The returned [FeedbackReport]s will have their `id` fields set.
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
  Future<List<FeedbackReport>> insert(
    _is.DatabaseSession session,
    List<FeedbackReport> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FeedbackReport>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FeedbackReport] and returns the inserted row.
  ///
  /// The returned [FeedbackReport] will have its `id` field set.
  Future<FeedbackReport> insertRow(
    _is.DatabaseSession session,
    FeedbackReport row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<FeedbackReport>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FeedbackReport]s in the list and returns the resulting rows.
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
  /// The returned [FeedbackReport]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FeedbackReport>> upsert(
    _is.DatabaseSession session,
    List<FeedbackReport> rows, {
    required _is.ColumnSelections<FeedbackReportTable> conflictColumns,
    _is.ColumnSelections<FeedbackReportTable>? updateColumns,
    _is.WhereExpressionBuilder<FeedbackReportTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FeedbackReport>(
      rows,
      conflictColumns: conflictColumns(FeedbackReport.t),
      updateColumns: updateColumns?.call(FeedbackReport.t),
      updateWhere: updateWhere?.call(FeedbackReport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FeedbackReport] and returns the resulting row.
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
  /// The returned [FeedbackReport] will have its `id` field set.
  Future<FeedbackReport?> upsertRow(
    _is.DatabaseSession session,
    FeedbackReport row, {
    required _is.ColumnSelections<FeedbackReportTable> conflictColumns,
    _is.ColumnSelections<FeedbackReportTable>? updateColumns,
    _is.WhereExpressionBuilder<FeedbackReportTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FeedbackReport>(
      row,
      conflictColumns: conflictColumns(FeedbackReport.t),
      updateColumns: updateColumns?.call(FeedbackReport.t),
      updateWhere: updateWhere?.call(FeedbackReport.t),
      transaction: transaction,
    );
  }

  /// Updates all [FeedbackReport]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FeedbackReport>> update(
    _is.DatabaseSession session,
    List<FeedbackReport> rows, {
    _is.ColumnSelections<FeedbackReportTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FeedbackReport>(
      rows,
      columns: columns?.call(FeedbackReport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FeedbackReport]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FeedbackReport> updateRow(
    _is.DatabaseSession session,
    FeedbackReport row, {
    _is.ColumnSelections<FeedbackReportTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<FeedbackReport>(
      row,
      columns: columns?.call(FeedbackReport.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FeedbackReport] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FeedbackReport?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<FeedbackReportUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<FeedbackReport>(
      id,
      columnValues: columnValues(FeedbackReport.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FeedbackReport]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FeedbackReport>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<FeedbackReportUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<FeedbackReportTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FeedbackReportTable>? orderBy,
    _is.OrderByListBuilder<FeedbackReportTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FeedbackReport>(
      columnValues: columnValues(FeedbackReport.t.updateTable),
      where: where(FeedbackReport.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FeedbackReport.t),
      orderByList: orderByList?.call(FeedbackReport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FeedbackReport]s in the list and returns the deleted rows.
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
  Future<List<FeedbackReport>> delete(
    _is.DatabaseSession session,
    List<FeedbackReport> rows, {
    _is.OrderByBuilder<FeedbackReportTable>? orderBy,
    _is.OrderByListBuilder<FeedbackReportTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FeedbackReport>(
      rows,
      orderBy: orderBy?.call(FeedbackReport.t),
      orderByList: orderByList?.call(FeedbackReport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FeedbackReport].
  Future<FeedbackReport> deleteRow(
    _is.DatabaseSession session,
    FeedbackReport row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FeedbackReport>(
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
  Future<List<FeedbackReport>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<FeedbackReportTable> where,
    _is.OrderByBuilder<FeedbackReportTable>? orderBy,
    _is.OrderByListBuilder<FeedbackReportTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FeedbackReport>(
      where: where(FeedbackReport.t),
      orderBy: orderBy?.call(FeedbackReport.t),
      orderByList: orderByList?.call(FeedbackReport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FeedbackReportTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<FeedbackReport>(
      where: where?.call(FeedbackReport.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FeedbackReport] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<FeedbackReportTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FeedbackReport>(
      where: where(FeedbackReport.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
