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

/// Import warnings kept 7 days and shown once to the importing user.
abstract class DocumentImportReport
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  DocumentImportReport._({
    this.id,
    required this.documentId,
    required this.userId,
    required this.warningsJson,
    required this.createdAt,
    this.seenAt,
  });

  factory DocumentImportReport({
    int? id,
    required int documentId,
    required int userId,
    required String warningsJson,
    required DateTime createdAt,
    DateTime? seenAt,
  }) = _DocumentImportReportImpl;

  factory DocumentImportReport.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DocumentImportReport(
      id: jsonSerialization['id'] as int?,
      documentId: jsonSerialization['documentId'] as int,
      userId: jsonSerialization['userId'] as int,
      warningsJson: jsonSerialization['warningsJson'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      seenAt: jsonSerialization['seenAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['seenAt']),
    );
  }

  static final t = DocumentImportReportTable();

  static const db = DocumentImportReportRepository._();

  @override
  int? id;

  int documentId;

  int userId;

  String warningsJson;

  DateTime createdAt;

  DateTime? seenAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [DocumentImportReport]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DocumentImportReport copyWith({
    int? id,
    int? documentId,
    int? userId,
    String? warningsJson,
    DateTime? createdAt,
    DateTime? seenAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocumentImportReport',
      if (id != null) 'id': id,
      'documentId': documentId,
      'userId': userId,
      'warningsJson': warningsJson,
      'createdAt': createdAt.toJson(),
      if (seenAt != null) 'seenAt': seenAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DocumentImportReportInclude include() {
    return DocumentImportReportInclude._();
  }

  static DocumentImportReportIncludeList includeList({
    _is.WhereExpressionBuilder<DocumentImportReportTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocumentImportReportTable>? orderBy,
    _is.OrderByListBuilder<DocumentImportReportTable>? orderByList,
    DocumentImportReportInclude? include,
  }) {
    return DocumentImportReportIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DocumentImportReport.t),
      orderByList: orderByList?.call(DocumentImportReport.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DocumentImportReportImpl extends DocumentImportReport {
  _DocumentImportReportImpl({
    int? id,
    required int documentId,
    required int userId,
    required String warningsJson,
    required DateTime createdAt,
    DateTime? seenAt,
  }) : super._(
         id: id,
         documentId: documentId,
         userId: userId,
         warningsJson: warningsJson,
         createdAt: createdAt,
         seenAt: seenAt,
       );

  /// Returns a shallow copy of this [DocumentImportReport]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocumentImportReport copyWith({
    Object? id = _Undefined,
    int? documentId,
    int? userId,
    String? warningsJson,
    DateTime? createdAt,
    DateTime? seenAt = const _is.$UndefinedDateTime(),
  }) {
    return DocumentImportReport(
      id: id is int? ? id : this.id,
      documentId: documentId ?? this.documentId,
      userId: userId ?? this.userId,
      warningsJson: warningsJson ?? this.warningsJson,
      createdAt: createdAt ?? this.createdAt,
      seenAt: seenAt is _is.UndefinedSentinel ? this.seenAt : seenAt,
    );
  }
}

class DocumentImportReportUpdateTable
    extends _is.UpdateTable<DocumentImportReportTable> {
  DocumentImportReportUpdateTable(super.table);

  _is.ColumnValue<int, int> documentId(int value) => _is.ColumnValue(
    table.documentId,
    value,
  );

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<String, String> warningsJson(String value) => _is.ColumnValue(
    table.warningsJson,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> seenAt(DateTime? value) =>
      _is.ColumnValue(
        table.seenAt,
        value,
      );
}

class DocumentImportReportTable extends _is.Table<int?> {
  DocumentImportReportTable({super.tableRelation})
    : super(tableName: 'document_import_report') {
    updateTable = DocumentImportReportUpdateTable(this);
    documentId = _is.ColumnInt(
      'documentId',
      this,
    );
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    warningsJson = _is.ColumnString(
      'warningsJson',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    seenAt = _is.ColumnDateTime(
      'seenAt',
      this,
    );
  }

  late final DocumentImportReportUpdateTable updateTable;

  late final _is.ColumnInt documentId;

  late final _is.ColumnInt userId;

  late final _is.ColumnString warningsJson;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime seenAt;

  @override
  List<_is.Column> get columns => [
    id,
    documentId,
    userId,
    warningsJson,
    createdAt,
    seenAt,
  ];
}

class DocumentImportReportInclude extends _is.IncludeObject {
  DocumentImportReportInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => DocumentImportReport.t;
}

class DocumentImportReportIncludeList extends _is.IncludeList {
  DocumentImportReportIncludeList._({
    _is.WhereExpressionBuilder<DocumentImportReportTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DocumentImportReport.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => DocumentImportReport.t;
}

class DocumentImportReportRepository {
  const DocumentImportReportRepository._();

  /// Returns a list of [DocumentImportReport]s matching the given query parameters.
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
  Future<List<DocumentImportReport>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocumentImportReportTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocumentImportReportTable>? orderBy,
    _is.OrderByListBuilder<DocumentImportReportTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DocumentImportReport>(
      where: where?.call(DocumentImportReport.t),
      orderBy: orderBy?.call(DocumentImportReport.t),
      orderByList: orderByList?.call(DocumentImportReport.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [DocumentImportReport]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `DocumentImportReport.t`.
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
  _ida.Stream<List<DocumentImportReport>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocumentImportReportTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocumentImportReportTable>? orderBy,
    _is.OrderByListBuilder<DocumentImportReportTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<DocumentImportReport>(
      where: where?.call(DocumentImportReport.t),
      orderBy: orderBy?.call(DocumentImportReport.t),
      orderByList: orderByList?.call(DocumentImportReport.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [DocumentImportReport] matching the given query parameters.
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
  Future<DocumentImportReport?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocumentImportReportTable>? where,
    int? offset,
    _is.OrderByBuilder<DocumentImportReportTable>? orderBy,
    _is.OrderByListBuilder<DocumentImportReportTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DocumentImportReport>(
      where: where?.call(DocumentImportReport.t),
      orderBy: orderBy?.call(DocumentImportReport.t),
      orderByList: orderByList?.call(DocumentImportReport.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DocumentImportReport] by its [id] or null if no such row exists.
  Future<DocumentImportReport?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DocumentImportReport>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DocumentImportReport]s in the list and returns the inserted rows.
  ///
  /// The returned [DocumentImportReport]s will have their `id` fields set.
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
  Future<List<DocumentImportReport>> insert(
    _is.DatabaseSession session,
    List<DocumentImportReport> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DocumentImportReport>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DocumentImportReport] and returns the inserted row.
  ///
  /// The returned [DocumentImportReport] will have its `id` field set.
  Future<DocumentImportReport> insertRow(
    _is.DatabaseSession session,
    DocumentImportReport row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<DocumentImportReport>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [DocumentImportReport]s in the list and returns the resulting rows.
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
  /// The returned [DocumentImportReport]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocumentImportReport>> upsert(
    _is.DatabaseSession session,
    List<DocumentImportReport> rows, {
    required _is.ColumnSelections<DocumentImportReportTable> conflictColumns,
    _is.ColumnSelections<DocumentImportReportTable>? updateColumns,
    _is.WhereExpressionBuilder<DocumentImportReportTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DocumentImportReport>(
      rows,
      conflictColumns: conflictColumns(DocumentImportReport.t),
      updateColumns: updateColumns?.call(DocumentImportReport.t),
      updateWhere: updateWhere?.call(DocumentImportReport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DocumentImportReport] and returns the resulting row.
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
  /// The returned [DocumentImportReport] will have its `id` field set.
  Future<DocumentImportReport?> upsertRow(
    _is.DatabaseSession session,
    DocumentImportReport row, {
    required _is.ColumnSelections<DocumentImportReportTable> conflictColumns,
    _is.ColumnSelections<DocumentImportReportTable>? updateColumns,
    _is.WhereExpressionBuilder<DocumentImportReportTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DocumentImportReport>(
      row,
      conflictColumns: conflictColumns(DocumentImportReport.t),
      updateColumns: updateColumns?.call(DocumentImportReport.t),
      updateWhere: updateWhere?.call(DocumentImportReport.t),
      transaction: transaction,
    );
  }

  /// Updates all [DocumentImportReport]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocumentImportReport>> update(
    _is.DatabaseSession session,
    List<DocumentImportReport> rows, {
    _is.ColumnSelections<DocumentImportReportTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DocumentImportReport>(
      rows,
      columns: columns?.call(DocumentImportReport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DocumentImportReport]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DocumentImportReport> updateRow(
    _is.DatabaseSession session,
    DocumentImportReport row, {
    _is.ColumnSelections<DocumentImportReportTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<DocumentImportReport>(
      row,
      columns: columns?.call(DocumentImportReport.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DocumentImportReport] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DocumentImportReport?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<DocumentImportReportUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<DocumentImportReport>(
      id,
      columnValues: columnValues(DocumentImportReport.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DocumentImportReport]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocumentImportReport>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<DocumentImportReportUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<DocumentImportReportTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocumentImportReportTable>? orderBy,
    _is.OrderByListBuilder<DocumentImportReportTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DocumentImportReport>(
      columnValues: columnValues(DocumentImportReport.t.updateTable),
      where: where(DocumentImportReport.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DocumentImportReport.t),
      orderByList: orderByList?.call(DocumentImportReport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DocumentImportReport]s in the list and returns the deleted rows.
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
  Future<List<DocumentImportReport>> delete(
    _is.DatabaseSession session,
    List<DocumentImportReport> rows, {
    _is.OrderByBuilder<DocumentImportReportTable>? orderBy,
    _is.OrderByListBuilder<DocumentImportReportTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DocumentImportReport>(
      rows,
      orderBy: orderBy?.call(DocumentImportReport.t),
      orderByList: orderByList?.call(DocumentImportReport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DocumentImportReport].
  Future<DocumentImportReport> deleteRow(
    _is.DatabaseSession session,
    DocumentImportReport row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DocumentImportReport>(
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
  Future<List<DocumentImportReport>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DocumentImportReportTable> where,
    _is.OrderByBuilder<DocumentImportReportTable>? orderBy,
    _is.OrderByListBuilder<DocumentImportReportTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DocumentImportReport>(
      where: where(DocumentImportReport.t),
      orderBy: orderBy?.call(DocumentImportReport.t),
      orderByList: orderByList?.call(DocumentImportReport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocumentImportReportTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<DocumentImportReport>(
      where: where?.call(DocumentImportReport.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DocumentImportReport] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DocumentImportReportTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DocumentImportReport>(
      where: where(DocumentImportReport.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
