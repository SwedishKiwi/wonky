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

/// One turn of an assistant thread. `contentJson` keeps the raw API content
/// blocks verbatim (thinking blocks included) for append-only replay.
abstract class AssistantMessage
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  AssistantMessage._({
    this.id,
    required this.threadId,
    required this.role,
    this.contentJson,
    required this.displayText,
    this.toolCallsJson,
    bool? visible,
    bool? replay,
    this.runId,
    this.stopReason,
    required this.createdAt,
  }) : visible = visible ?? true,
       replay = replay ?? true;

  factory AssistantMessage({
    int? id,
    required int threadId,
    required String role,
    String? contentJson,
    required String displayText,
    String? toolCallsJson,
    bool? visible,
    bool? replay,
    String? runId,
    String? stopReason,
    required DateTime createdAt,
  }) = _AssistantMessageImpl;

  factory AssistantMessage.fromJson(Map<String, dynamic> jsonSerialization) {
    return AssistantMessage(
      id: jsonSerialization['id'] as int?,
      threadId: jsonSerialization['threadId'] as int,
      role: jsonSerialization['role'] as String,
      contentJson: jsonSerialization['contentJson'] as String?,
      displayText: jsonSerialization['displayText'] as String,
      toolCallsJson: jsonSerialization['toolCallsJson'] as String?,
      visible: jsonSerialization['visible'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['visible']),
      replay: jsonSerialization['replay'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['replay']),
      runId: jsonSerialization['runId'] as String?,
      stopReason: jsonSerialization['stopReason'] as String?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = AssistantMessageTable();

  static const db = AssistantMessageRepository._();

  @override
  int? id;

  int threadId;

  /// user | assistant
  String role;

  String? contentJson;

  /// Rendered text for the UI (user text / assistant Markdown).
  String displayText;

  /// JSON list of AssistantToolActivity summaries for the UI.
  String? toolCallsJson;

  /// Whether the turn is shown in the panel (tool-result turns are not).
  bool visible;

  /// Whether the turn is replayed to the model (refused turns are not).
  bool replay;

  String? runId;

  String? stopReason;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [AssistantMessage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AssistantMessage copyWith({
    int? id,
    int? threadId,
    String? role,
    String? contentJson,
    String? displayText,
    String? toolCallsJson,
    bool? visible,
    bool? replay,
    String? runId,
    String? stopReason,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AssistantMessage',
      if (id != null) 'id': id,
      'threadId': threadId,
      'role': role,
      if (contentJson != null) 'contentJson': contentJson,
      'displayText': displayText,
      if (toolCallsJson != null) 'toolCallsJson': toolCallsJson,
      'visible': visible,
      'replay': replay,
      if (runId != null) 'runId': runId,
      if (stopReason != null) 'stopReason': stopReason,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AssistantMessage',
      if (id != null) 'id': id,
      'threadId': threadId,
      'role': role,
      'displayText': displayText,
      if (toolCallsJson != null) 'toolCallsJson': toolCallsJson,
      'visible': visible,
      'replay': replay,
      if (runId != null) 'runId': runId,
      if (stopReason != null) 'stopReason': stopReason,
      'createdAt': createdAt.toJson(),
    };
  }

  static AssistantMessageInclude include() {
    return AssistantMessageInclude._();
  }

  static AssistantMessageIncludeList includeList({
    _is.WhereExpressionBuilder<AssistantMessageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AssistantMessageTable>? orderBy,
    _is.OrderByListBuilder<AssistantMessageTable>? orderByList,
    AssistantMessageInclude? include,
  }) {
    return AssistantMessageIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AssistantMessage.t),
      orderByList: orderByList?.call(AssistantMessage.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AssistantMessageImpl extends AssistantMessage {
  _AssistantMessageImpl({
    int? id,
    required int threadId,
    required String role,
    String? contentJson,
    required String displayText,
    String? toolCallsJson,
    bool? visible,
    bool? replay,
    String? runId,
    String? stopReason,
    required DateTime createdAt,
  }) : super._(
         id: id,
         threadId: threadId,
         role: role,
         contentJson: contentJson,
         displayText: displayText,
         toolCallsJson: toolCallsJson,
         visible: visible,
         replay: replay,
         runId: runId,
         stopReason: stopReason,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [AssistantMessage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AssistantMessage copyWith({
    Object? id = _Undefined,
    int? threadId,
    String? role,
    Object? contentJson = _Undefined,
    String? displayText,
    Object? toolCallsJson = _Undefined,
    bool? visible,
    bool? replay,
    Object? runId = _Undefined,
    Object? stopReason = _Undefined,
    DateTime? createdAt,
  }) {
    return AssistantMessage(
      id: id is int? ? id : this.id,
      threadId: threadId ?? this.threadId,
      role: role ?? this.role,
      contentJson: contentJson is String? ? contentJson : this.contentJson,
      displayText: displayText ?? this.displayText,
      toolCallsJson: toolCallsJson is String?
          ? toolCallsJson
          : this.toolCallsJson,
      visible: visible ?? this.visible,
      replay: replay ?? this.replay,
      runId: runId is String? ? runId : this.runId,
      stopReason: stopReason is String? ? stopReason : this.stopReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AssistantMessageUpdateTable
    extends _is.UpdateTable<AssistantMessageTable> {
  AssistantMessageUpdateTable(super.table);

  _is.ColumnValue<int, int> threadId(int value) => _is.ColumnValue(
    table.threadId,
    value,
  );

  _is.ColumnValue<String, String> role(String value) => _is.ColumnValue(
    table.role,
    value,
  );

  _is.ColumnValue<String, String> contentJson(String? value) => _is.ColumnValue(
    table.contentJson,
    value,
  );

  _is.ColumnValue<String, String> displayText(String value) => _is.ColumnValue(
    table.displayText,
    value,
  );

  _is.ColumnValue<String, String> toolCallsJson(String? value) =>
      _is.ColumnValue(
        table.toolCallsJson,
        value,
      );

  _is.ColumnValue<bool, bool> visible(bool value) => _is.ColumnValue(
    table.visible,
    value,
  );

  _is.ColumnValue<bool, bool> replay(bool value) => _is.ColumnValue(
    table.replay,
    value,
  );

  _is.ColumnValue<String, String> runId(String? value) => _is.ColumnValue(
    table.runId,
    value,
  );

  _is.ColumnValue<String, String> stopReason(String? value) => _is.ColumnValue(
    table.stopReason,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class AssistantMessageTable extends _is.Table<int?> {
  AssistantMessageTable({super.tableRelation})
    : super(tableName: 'assistant_message') {
    updateTable = AssistantMessageUpdateTable(this);
    threadId = _is.ColumnInt(
      'threadId',
      this,
    );
    role = _is.ColumnString(
      'role',
      this,
    );
    contentJson = _is.ColumnString(
      'contentJson',
      this,
    );
    displayText = _is.ColumnString(
      'displayText',
      this,
    );
    toolCallsJson = _is.ColumnString(
      'toolCallsJson',
      this,
    );
    visible = _is.ColumnBool(
      'visible',
      this,
      hasDefault: true,
    );
    replay = _is.ColumnBool(
      'replay',
      this,
      hasDefault: true,
    );
    runId = _is.ColumnString(
      'runId',
      this,
    );
    stopReason = _is.ColumnString(
      'stopReason',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final AssistantMessageUpdateTable updateTable;

  late final _is.ColumnInt threadId;

  /// user | assistant
  late final _is.ColumnString role;

  late final _is.ColumnString contentJson;

  /// Rendered text for the UI (user text / assistant Markdown).
  late final _is.ColumnString displayText;

  /// JSON list of AssistantToolActivity summaries for the UI.
  late final _is.ColumnString toolCallsJson;

  /// Whether the turn is shown in the panel (tool-result turns are not).
  late final _is.ColumnBool visible;

  /// Whether the turn is replayed to the model (refused turns are not).
  late final _is.ColumnBool replay;

  late final _is.ColumnString runId;

  late final _is.ColumnString stopReason;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    threadId,
    role,
    contentJson,
    displayText,
    toolCallsJson,
    visible,
    replay,
    runId,
    stopReason,
    createdAt,
  ];
}

class AssistantMessageInclude extends _is.IncludeObject {
  AssistantMessageInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => AssistantMessage.t;
}

class AssistantMessageIncludeList extends _is.IncludeList {
  AssistantMessageIncludeList._({
    _is.WhereExpressionBuilder<AssistantMessageTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AssistantMessage.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => AssistantMessage.t;
}

class AssistantMessageRepository {
  const AssistantMessageRepository._();

  /// Returns a list of [AssistantMessage]s matching the given query parameters.
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
  Future<List<AssistantMessage>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AssistantMessageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AssistantMessageTable>? orderBy,
    _is.OrderByListBuilder<AssistantMessageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AssistantMessage>(
      where: where?.call(AssistantMessage.t),
      orderBy: orderBy?.call(AssistantMessage.t),
      orderByList: orderByList?.call(AssistantMessage.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [AssistantMessage]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `AssistantMessage.t`.
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
  _ida.Stream<List<AssistantMessage>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AssistantMessageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AssistantMessageTable>? orderBy,
    _is.OrderByListBuilder<AssistantMessageTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<AssistantMessage>(
      where: where?.call(AssistantMessage.t),
      orderBy: orderBy?.call(AssistantMessage.t),
      orderByList: orderByList?.call(AssistantMessage.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [AssistantMessage] matching the given query parameters.
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
  Future<AssistantMessage?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AssistantMessageTable>? where,
    int? offset,
    _is.OrderByBuilder<AssistantMessageTable>? orderBy,
    _is.OrderByListBuilder<AssistantMessageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AssistantMessage>(
      where: where?.call(AssistantMessage.t),
      orderBy: orderBy?.call(AssistantMessage.t),
      orderByList: orderByList?.call(AssistantMessage.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AssistantMessage] by its [id] or null if no such row exists.
  Future<AssistantMessage?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AssistantMessage>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AssistantMessage]s in the list and returns the inserted rows.
  ///
  /// The returned [AssistantMessage]s will have their `id` fields set.
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
  Future<List<AssistantMessage>> insert(
    _is.DatabaseSession session,
    List<AssistantMessage> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<AssistantMessage>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [AssistantMessage] and returns the inserted row.
  ///
  /// The returned [AssistantMessage] will have its `id` field set.
  Future<AssistantMessage> insertRow(
    _is.DatabaseSession session,
    AssistantMessage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<AssistantMessage>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [AssistantMessage]s in the list and returns the resulting rows.
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
  /// The returned [AssistantMessage]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AssistantMessage>> upsert(
    _is.DatabaseSession session,
    List<AssistantMessage> rows, {
    required _is.ColumnSelections<AssistantMessageTable> conflictColumns,
    _is.ColumnSelections<AssistantMessageTable>? updateColumns,
    _is.WhereExpressionBuilder<AssistantMessageTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<AssistantMessage>(
      rows,
      conflictColumns: conflictColumns(AssistantMessage.t),
      updateColumns: updateColumns?.call(AssistantMessage.t),
      updateWhere: updateWhere?.call(AssistantMessage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [AssistantMessage] and returns the resulting row.
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
  /// The returned [AssistantMessage] will have its `id` field set.
  Future<AssistantMessage?> upsertRow(
    _is.DatabaseSession session,
    AssistantMessage row, {
    required _is.ColumnSelections<AssistantMessageTable> conflictColumns,
    _is.ColumnSelections<AssistantMessageTable>? updateColumns,
    _is.WhereExpressionBuilder<AssistantMessageTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<AssistantMessage>(
      row,
      conflictColumns: conflictColumns(AssistantMessage.t),
      updateColumns: updateColumns?.call(AssistantMessage.t),
      updateWhere: updateWhere?.call(AssistantMessage.t),
      transaction: transaction,
    );
  }

  /// Updates all [AssistantMessage]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AssistantMessage>> update(
    _is.DatabaseSession session,
    List<AssistantMessage> rows, {
    _is.ColumnSelections<AssistantMessageTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<AssistantMessage>(
      rows,
      columns: columns?.call(AssistantMessage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [AssistantMessage]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AssistantMessage> updateRow(
    _is.DatabaseSession session,
    AssistantMessage row, {
    _is.ColumnSelections<AssistantMessageTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<AssistantMessage>(
      row,
      columns: columns?.call(AssistantMessage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AssistantMessage] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AssistantMessage?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<AssistantMessageUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<AssistantMessage>(
      id,
      columnValues: columnValues(AssistantMessage.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AssistantMessage]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AssistantMessage>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<AssistantMessageUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<AssistantMessageTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AssistantMessageTable>? orderBy,
    _is.OrderByListBuilder<AssistantMessageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<AssistantMessage>(
      columnValues: columnValues(AssistantMessage.t.updateTable),
      where: where(AssistantMessage.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AssistantMessage.t),
      orderByList: orderByList?.call(AssistantMessage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [AssistantMessage]s in the list and returns the deleted rows.
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
  Future<List<AssistantMessage>> delete(
    _is.DatabaseSession session,
    List<AssistantMessage> rows, {
    _is.OrderByBuilder<AssistantMessageTable>? orderBy,
    _is.OrderByListBuilder<AssistantMessageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<AssistantMessage>(
      rows,
      orderBy: orderBy?.call(AssistantMessage.t),
      orderByList: orderByList?.call(AssistantMessage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [AssistantMessage].
  Future<AssistantMessage> deleteRow(
    _is.DatabaseSession session,
    AssistantMessage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AssistantMessage>(
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
  Future<List<AssistantMessage>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AssistantMessageTable> where,
    _is.OrderByBuilder<AssistantMessageTable>? orderBy,
    _is.OrderByListBuilder<AssistantMessageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<AssistantMessage>(
      where: where(AssistantMessage.t),
      orderBy: orderBy?.call(AssistantMessage.t),
      orderByList: orderByList?.call(AssistantMessage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AssistantMessageTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<AssistantMessage>(
      where: where?.call(AssistantMessage.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AssistantMessage] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AssistantMessageTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AssistantMessage>(
      where: where(AssistantMessage.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
