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

abstract class DocumentSnapshot
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  DocumentSnapshot._({
    this.id,
    required this.documentId,
    required this.revision,
    required this.deltaJson,
    required this.compressed,
    required this.createdAt,
  });

  factory DocumentSnapshot({
    int? id,
    required int documentId,
    required int revision,
    required String deltaJson,
    required bool compressed,
    required DateTime createdAt,
  }) = _DocumentSnapshotImpl;

  factory DocumentSnapshot.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocumentSnapshot(
      id: jsonSerialization['id'] as int?,
      documentId: jsonSerialization['documentId'] as int,
      revision: jsonSerialization['revision'] as int,
      deltaJson: jsonSerialization['deltaJson'] as String,
      compressed: _is.BoolJsonExtension.fromJson(
        jsonSerialization['compressed'],
      ),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = DocumentSnapshotTable();

  static const db = DocumentSnapshotRepository._();

  @override
  int? id;

  int documentId;

  int revision;

  /// Full document delta (gzip+base64 when [compressed]).
  String deltaJson;

  bool compressed;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [DocumentSnapshot]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DocumentSnapshot copyWith({
    int? id,
    int? documentId,
    int? revision,
    String? deltaJson,
    bool? compressed,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocumentSnapshot',
      if (id != null) 'id': id,
      'documentId': documentId,
      'revision': revision,
      'deltaJson': deltaJson,
      'compressed': compressed,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocumentSnapshot',
      if (id != null) 'id': id,
      'documentId': documentId,
      'revision': revision,
      'deltaJson': deltaJson,
      'compressed': compressed,
      'createdAt': createdAt.toJson(),
    };
  }

  static DocumentSnapshotInclude include() {
    return DocumentSnapshotInclude._();
  }

  static DocumentSnapshotIncludeList includeList({
    _is.WhereExpressionBuilder<DocumentSnapshotTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocumentSnapshotTable>? orderBy,
    _is.OrderByListBuilder<DocumentSnapshotTable>? orderByList,
    DocumentSnapshotInclude? include,
  }) {
    return DocumentSnapshotIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DocumentSnapshot.t),
      orderByList: orderByList?.call(DocumentSnapshot.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DocumentSnapshotImpl extends DocumentSnapshot {
  _DocumentSnapshotImpl({
    int? id,
    required int documentId,
    required int revision,
    required String deltaJson,
    required bool compressed,
    required DateTime createdAt,
  }) : super._(
         id: id,
         documentId: documentId,
         revision: revision,
         deltaJson: deltaJson,
         compressed: compressed,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DocumentSnapshot]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocumentSnapshot copyWith({
    Object? id = _Undefined,
    int? documentId,
    int? revision,
    String? deltaJson,
    bool? compressed,
    DateTime? createdAt,
  }) {
    return DocumentSnapshot(
      id: id is int? ? id : this.id,
      documentId: documentId ?? this.documentId,
      revision: revision ?? this.revision,
      deltaJson: deltaJson ?? this.deltaJson,
      compressed: compressed ?? this.compressed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DocumentSnapshotUpdateTable
    extends _is.UpdateTable<DocumentSnapshotTable> {
  DocumentSnapshotUpdateTable(super.table);

  _is.ColumnValue<int, int> documentId(int value) => _is.ColumnValue(
    table.documentId,
    value,
  );

  _is.ColumnValue<int, int> revision(int value) => _is.ColumnValue(
    table.revision,
    value,
  );

  _is.ColumnValue<String, String> deltaJson(String value) => _is.ColumnValue(
    table.deltaJson,
    value,
  );

  _is.ColumnValue<bool, bool> compressed(bool value) => _is.ColumnValue(
    table.compressed,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class DocumentSnapshotTable extends _is.Table<int?> {
  DocumentSnapshotTable({super.tableRelation})
    : super(tableName: 'document_snapshot') {
    updateTable = DocumentSnapshotUpdateTable(this);
    documentId = _is.ColumnInt(
      'documentId',
      this,
    );
    revision = _is.ColumnInt(
      'revision',
      this,
    );
    deltaJson = _is.ColumnString(
      'deltaJson',
      this,
    );
    compressed = _is.ColumnBool(
      'compressed',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final DocumentSnapshotUpdateTable updateTable;

  late final _is.ColumnInt documentId;

  late final _is.ColumnInt revision;

  /// Full document delta (gzip+base64 when [compressed]).
  late final _is.ColumnString deltaJson;

  late final _is.ColumnBool compressed;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    documentId,
    revision,
    deltaJson,
    compressed,
    createdAt,
  ];
}

class DocumentSnapshotInclude extends _is.IncludeObject {
  DocumentSnapshotInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => DocumentSnapshot.t;
}

class DocumentSnapshotIncludeList extends _is.IncludeList {
  DocumentSnapshotIncludeList._({
    _is.WhereExpressionBuilder<DocumentSnapshotTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DocumentSnapshot.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => DocumentSnapshot.t;
}

class DocumentSnapshotRepository {
  const DocumentSnapshotRepository._();

  /// Returns a list of [DocumentSnapshot]s matching the given query parameters.
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
  Future<List<DocumentSnapshot>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocumentSnapshotTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocumentSnapshotTable>? orderBy,
    _is.OrderByListBuilder<DocumentSnapshotTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DocumentSnapshot>(
      where: where?.call(DocumentSnapshot.t),
      orderBy: orderBy?.call(DocumentSnapshot.t),
      orderByList: orderByList?.call(DocumentSnapshot.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [DocumentSnapshot]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `DocumentSnapshot.t`.
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
  _ida.Stream<List<DocumentSnapshot>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocumentSnapshotTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocumentSnapshotTable>? orderBy,
    _is.OrderByListBuilder<DocumentSnapshotTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<DocumentSnapshot>(
      where: where?.call(DocumentSnapshot.t),
      orderBy: orderBy?.call(DocumentSnapshot.t),
      orderByList: orderByList?.call(DocumentSnapshot.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [DocumentSnapshot] matching the given query parameters.
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
  Future<DocumentSnapshot?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocumentSnapshotTable>? where,
    int? offset,
    _is.OrderByBuilder<DocumentSnapshotTable>? orderBy,
    _is.OrderByListBuilder<DocumentSnapshotTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DocumentSnapshot>(
      where: where?.call(DocumentSnapshot.t),
      orderBy: orderBy?.call(DocumentSnapshot.t),
      orderByList: orderByList?.call(DocumentSnapshot.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DocumentSnapshot] by its [id] or null if no such row exists.
  Future<DocumentSnapshot?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DocumentSnapshot>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DocumentSnapshot]s in the list and returns the inserted rows.
  ///
  /// The returned [DocumentSnapshot]s will have their `id` fields set.
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
  Future<List<DocumentSnapshot>> insert(
    _is.DatabaseSession session,
    List<DocumentSnapshot> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DocumentSnapshot>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DocumentSnapshot] and returns the inserted row.
  ///
  /// The returned [DocumentSnapshot] will have its `id` field set.
  Future<DocumentSnapshot> insertRow(
    _is.DatabaseSession session,
    DocumentSnapshot row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<DocumentSnapshot>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [DocumentSnapshot]s in the list and returns the resulting rows.
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
  /// The returned [DocumentSnapshot]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocumentSnapshot>> upsert(
    _is.DatabaseSession session,
    List<DocumentSnapshot> rows, {
    required _is.ColumnSelections<DocumentSnapshotTable> conflictColumns,
    _is.ColumnSelections<DocumentSnapshotTable>? updateColumns,
    _is.WhereExpressionBuilder<DocumentSnapshotTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DocumentSnapshot>(
      rows,
      conflictColumns: conflictColumns(DocumentSnapshot.t),
      updateColumns: updateColumns?.call(DocumentSnapshot.t),
      updateWhere: updateWhere?.call(DocumentSnapshot.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DocumentSnapshot] and returns the resulting row.
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
  /// The returned [DocumentSnapshot] will have its `id` field set.
  Future<DocumentSnapshot?> upsertRow(
    _is.DatabaseSession session,
    DocumentSnapshot row, {
    required _is.ColumnSelections<DocumentSnapshotTable> conflictColumns,
    _is.ColumnSelections<DocumentSnapshotTable>? updateColumns,
    _is.WhereExpressionBuilder<DocumentSnapshotTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DocumentSnapshot>(
      row,
      conflictColumns: conflictColumns(DocumentSnapshot.t),
      updateColumns: updateColumns?.call(DocumentSnapshot.t),
      updateWhere: updateWhere?.call(DocumentSnapshot.t),
      transaction: transaction,
    );
  }

  /// Updates all [DocumentSnapshot]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocumentSnapshot>> update(
    _is.DatabaseSession session,
    List<DocumentSnapshot> rows, {
    _is.ColumnSelections<DocumentSnapshotTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DocumentSnapshot>(
      rows,
      columns: columns?.call(DocumentSnapshot.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DocumentSnapshot]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DocumentSnapshot> updateRow(
    _is.DatabaseSession session,
    DocumentSnapshot row, {
    _is.ColumnSelections<DocumentSnapshotTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<DocumentSnapshot>(
      row,
      columns: columns?.call(DocumentSnapshot.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DocumentSnapshot] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DocumentSnapshot?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<DocumentSnapshotUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<DocumentSnapshot>(
      id,
      columnValues: columnValues(DocumentSnapshot.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DocumentSnapshot]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocumentSnapshot>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<DocumentSnapshotUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<DocumentSnapshotTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocumentSnapshotTable>? orderBy,
    _is.OrderByListBuilder<DocumentSnapshotTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DocumentSnapshot>(
      columnValues: columnValues(DocumentSnapshot.t.updateTable),
      where: where(DocumentSnapshot.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DocumentSnapshot.t),
      orderByList: orderByList?.call(DocumentSnapshot.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DocumentSnapshot]s in the list and returns the deleted rows.
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
  Future<List<DocumentSnapshot>> delete(
    _is.DatabaseSession session,
    List<DocumentSnapshot> rows, {
    _is.OrderByBuilder<DocumentSnapshotTable>? orderBy,
    _is.OrderByListBuilder<DocumentSnapshotTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DocumentSnapshot>(
      rows,
      orderBy: orderBy?.call(DocumentSnapshot.t),
      orderByList: orderByList?.call(DocumentSnapshot.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DocumentSnapshot].
  Future<DocumentSnapshot> deleteRow(
    _is.DatabaseSession session,
    DocumentSnapshot row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DocumentSnapshot>(
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
  Future<List<DocumentSnapshot>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DocumentSnapshotTable> where,
    _is.OrderByBuilder<DocumentSnapshotTable>? orderBy,
    _is.OrderByListBuilder<DocumentSnapshotTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DocumentSnapshot>(
      where: where(DocumentSnapshot.t),
      orderBy: orderBy?.call(DocumentSnapshot.t),
      orderByList: orderByList?.call(DocumentSnapshot.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocumentSnapshotTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<DocumentSnapshot>(
      where: where?.call(DocumentSnapshot.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DocumentSnapshot] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DocumentSnapshotTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DocumentSnapshot>(
      where: where(DocumentSnapshot.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
