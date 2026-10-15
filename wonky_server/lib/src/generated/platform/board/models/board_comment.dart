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
import '../../../platform/board/models/board_moderation.dart' as _i04stir2;

/// A comment on a post, or discussion and activity rows on a task.
abstract class BoardComment
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  BoardComment._({
    this.id,
    required this.uuid,
    this.postId,
    this.taskId,
    this.authorId,
    required this.body,
    this.systemEvent,
    required this.moderation,
    this.moderationReason,
    bool? needsCheck,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.removedAt,
  }) : needsCheck = needsCheck ?? false;

  factory BoardComment({
    int? id,
    required _is.UuidValue uuid,
    int? postId,
    int? taskId,
    int? authorId,
    required String body,
    String? systemEvent,
    required _i04stir2.BoardModeration moderation,
    String? moderationReason,
    bool? needsCheck,
    required DateTime createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    DateTime? removedAt,
  }) = _BoardCommentImpl;

  factory BoardComment.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardComment(
      id: jsonSerialization['id'] as int?,
      uuid: _is.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      postId: jsonSerialization['postId'] as int?,
      taskId: jsonSerialization['taskId'] as int?,
      authorId: jsonSerialization['authorId'] as int?,
      body: jsonSerialization['body'] as String,
      systemEvent: jsonSerialization['systemEvent'] as String?,
      moderation: _i04stir2.BoardModeration.fromJson(
        (jsonSerialization['moderation'] as String),
      ),
      moderationReason: jsonSerialization['moderationReason'] as String?,
      needsCheck: jsonSerialization['needsCheck'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['needsCheck']),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      editedAt: jsonSerialization['editedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['editedAt']),
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
      removedAt: jsonSerialization['removedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['removedAt']),
    );
  }

  static final t = BoardCommentTable();

  static const db = BoardCommentRepository._();

  @override
  int? id;

  /// Client-supplied; idempotent create.
  _is.UuidValue uuid;

  int? postId;

  int? taskId;

  /// Null for system rows and deleted users.
  int? authorId;

  /// Markdown, at most 10,000 chars.
  String body;

  /// claimed, released, expired, prLinked, prClosed, done, shipped, merged…
  String? systemEvent;

  _i04stir2.BoardModeration moderation;

  String? moderationReason;

  bool needsCheck;

  DateTime createdAt;

  DateTime? editedAt;

  DateTime? deletedAt;

  DateTime? removedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [BoardComment]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardComment copyWith({
    int? id,
    _is.UuidValue? uuid,
    int? postId,
    int? taskId,
    int? authorId,
    String? body,
    String? systemEvent,
    _i04stir2.BoardModeration? moderation,
    String? moderationReason,
    bool? needsCheck,
    DateTime? createdAt,
    DateTime? editedAt = const _is.$UndefinedDateTime(),
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
    DateTime? removedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardComment',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      if (postId != null) 'postId': postId,
      if (taskId != null) 'taskId': taskId,
      if (authorId != null) 'authorId': authorId,
      'body': body,
      if (systemEvent != null) 'systemEvent': systemEvent,
      'moderation': moderation.toJson(),
      if (moderationReason != null) 'moderationReason': moderationReason,
      'needsCheck': needsCheck,
      'createdAt': createdAt.toJson(),
      if (editedAt != null) 'editedAt': editedAt?.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
      if (removedAt != null) 'removedAt': removedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardComment',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      if (postId != null) 'postId': postId,
      if (taskId != null) 'taskId': taskId,
      if (authorId != null) 'authorId': authorId,
      'body': body,
      if (systemEvent != null) 'systemEvent': systemEvent,
      'moderation': moderation.toJson(),
      if (moderationReason != null) 'moderationReason': moderationReason,
      'needsCheck': needsCheck,
      'createdAt': createdAt.toJson(),
      if (editedAt != null) 'editedAt': editedAt?.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
      if (removedAt != null) 'removedAt': removedAt?.toJson(),
    };
  }

  static BoardCommentInclude include() {
    return BoardCommentInclude._();
  }

  static BoardCommentIncludeList includeList({
    _is.WhereExpressionBuilder<BoardCommentTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardCommentTable>? orderBy,
    _is.OrderByListBuilder<BoardCommentTable>? orderByList,
    BoardCommentInclude? include,
  }) {
    return BoardCommentIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardComment.t),
      orderByList: orderByList?.call(BoardComment.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardCommentImpl extends BoardComment {
  _BoardCommentImpl({
    int? id,
    required _is.UuidValue uuid,
    int? postId,
    int? taskId,
    int? authorId,
    required String body,
    String? systemEvent,
    required _i04stir2.BoardModeration moderation,
    String? moderationReason,
    bool? needsCheck,
    required DateTime createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    DateTime? removedAt,
  }) : super._(
         id: id,
         uuid: uuid,
         postId: postId,
         taskId: taskId,
         authorId: authorId,
         body: body,
         systemEvent: systemEvent,
         moderation: moderation,
         moderationReason: moderationReason,
         needsCheck: needsCheck,
         createdAt: createdAt,
         editedAt: editedAt,
         deletedAt: deletedAt,
         removedAt: removedAt,
       );

  /// Returns a shallow copy of this [BoardComment]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardComment copyWith({
    Object? id = _Undefined,
    _is.UuidValue? uuid,
    Object? postId = _Undefined,
    Object? taskId = _Undefined,
    Object? authorId = _Undefined,
    String? body,
    Object? systemEvent = _Undefined,
    _i04stir2.BoardModeration? moderation,
    Object? moderationReason = _Undefined,
    bool? needsCheck,
    DateTime? createdAt,
    DateTime? editedAt = const _is.$UndefinedDateTime(),
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
    DateTime? removedAt = const _is.$UndefinedDateTime(),
  }) {
    return BoardComment(
      id: id is int? ? id : this.id,
      uuid: uuid ?? this.uuid,
      postId: postId is int? ? postId : this.postId,
      taskId: taskId is int? ? taskId : this.taskId,
      authorId: authorId is int? ? authorId : this.authorId,
      body: body ?? this.body,
      systemEvent: systemEvent is String? ? systemEvent : this.systemEvent,
      moderation: moderation ?? this.moderation,
      moderationReason: moderationReason is String?
          ? moderationReason
          : this.moderationReason,
      needsCheck: needsCheck ?? this.needsCheck,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt is _is.UndefinedSentinel ? this.editedAt : editedAt,
      deletedAt: deletedAt is _is.UndefinedSentinel
          ? this.deletedAt
          : deletedAt,
      removedAt: removedAt is _is.UndefinedSentinel
          ? this.removedAt
          : removedAt,
    );
  }
}

class BoardCommentUpdateTable extends _is.UpdateTable<BoardCommentTable> {
  BoardCommentUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> uuid(_is.UuidValue value) =>
      _is.ColumnValue(
        table.uuid,
        value,
      );

  _is.ColumnValue<int, int> postId(int? value) => _is.ColumnValue(
    table.postId,
    value,
  );

  _is.ColumnValue<int, int> taskId(int? value) => _is.ColumnValue(
    table.taskId,
    value,
  );

  _is.ColumnValue<int, int> authorId(int? value) => _is.ColumnValue(
    table.authorId,
    value,
  );

  _is.ColumnValue<String, String> body(String value) => _is.ColumnValue(
    table.body,
    value,
  );

  _is.ColumnValue<String, String> systemEvent(String? value) => _is.ColumnValue(
    table.systemEvent,
    value,
  );

  _is.ColumnValue<_i04stir2.BoardModeration, _i04stir2.BoardModeration>
  moderation(_i04stir2.BoardModeration value) => _is.ColumnValue(
    table.moderation,
    value,
  );

  _is.ColumnValue<String, String> moderationReason(String? value) =>
      _is.ColumnValue(
        table.moderationReason,
        value,
      );

  _is.ColumnValue<bool, bool> needsCheck(bool value) => _is.ColumnValue(
    table.needsCheck,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> editedAt(DateTime? value) =>
      _is.ColumnValue(
        table.editedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> deletedAt(DateTime? value) =>
      _is.ColumnValue(
        table.deletedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> removedAt(DateTime? value) =>
      _is.ColumnValue(
        table.removedAt,
        value,
      );
}

class BoardCommentTable extends _is.Table<int?> {
  BoardCommentTable({super.tableRelation}) : super(tableName: 'board_comment') {
    updateTable = BoardCommentUpdateTable(this);
    uuid = _is.ColumnUuid(
      'uuid',
      this,
    );
    postId = _is.ColumnInt(
      'postId',
      this,
    );
    taskId = _is.ColumnInt(
      'taskId',
      this,
    );
    authorId = _is.ColumnInt(
      'authorId',
      this,
    );
    body = _is.ColumnString(
      'body',
      this,
    );
    systemEvent = _is.ColumnString(
      'systemEvent',
      this,
    );
    moderation = _is.ColumnEnum(
      'moderation',
      this,
      _is.EnumSerialization.byName,
    );
    moderationReason = _is.ColumnString(
      'moderationReason',
      this,
    );
    needsCheck = _is.ColumnBool(
      'needsCheck',
      this,
      hasDefault: true,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    editedAt = _is.ColumnDateTime(
      'editedAt',
      this,
    );
    deletedAt = _is.ColumnDateTime(
      'deletedAt',
      this,
    );
    removedAt = _is.ColumnDateTime(
      'removedAt',
      this,
    );
  }

  late final BoardCommentUpdateTable updateTable;

  /// Client-supplied; idempotent create.
  late final _is.ColumnUuid uuid;

  late final _is.ColumnInt postId;

  late final _is.ColumnInt taskId;

  /// Null for system rows and deleted users.
  late final _is.ColumnInt authorId;

  /// Markdown, at most 10,000 chars.
  late final _is.ColumnString body;

  /// claimed, released, expired, prLinked, prClosed, done, shipped, merged…
  late final _is.ColumnString systemEvent;

  late final _is.ColumnEnum<_i04stir2.BoardModeration> moderation;

  late final _is.ColumnString moderationReason;

  late final _is.ColumnBool needsCheck;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime editedAt;

  late final _is.ColumnDateTime deletedAt;

  late final _is.ColumnDateTime removedAt;

  @override
  List<_is.Column> get columns => [
    id,
    uuid,
    postId,
    taskId,
    authorId,
    body,
    systemEvent,
    moderation,
    moderationReason,
    needsCheck,
    createdAt,
    editedAt,
    deletedAt,
    removedAt,
  ];
}

class BoardCommentInclude extends _is.IncludeObject {
  BoardCommentInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => BoardComment.t;
}

class BoardCommentIncludeList extends _is.IncludeList {
  BoardCommentIncludeList._({
    _is.WhereExpressionBuilder<BoardCommentTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BoardComment.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => BoardComment.t;
}

class BoardCommentRepository {
  const BoardCommentRepository._();

  /// Returns a list of [BoardComment]s matching the given query parameters.
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
  Future<List<BoardComment>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardCommentTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardCommentTable>? orderBy,
    _is.OrderByListBuilder<BoardCommentTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BoardComment>(
      where: where?.call(BoardComment.t),
      orderBy: orderBy?.call(BoardComment.t),
      orderByList: orderByList?.call(BoardComment.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [BoardComment]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `BoardComment.t`.
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
  _ida.Stream<List<BoardComment>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardCommentTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardCommentTable>? orderBy,
    _is.OrderByListBuilder<BoardCommentTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<BoardComment>(
      where: where?.call(BoardComment.t),
      orderBy: orderBy?.call(BoardComment.t),
      orderByList: orderByList?.call(BoardComment.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [BoardComment] matching the given query parameters.
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
  Future<BoardComment?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardCommentTable>? where,
    int? offset,
    _is.OrderByBuilder<BoardCommentTable>? orderBy,
    _is.OrderByListBuilder<BoardCommentTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BoardComment>(
      where: where?.call(BoardComment.t),
      orderBy: orderBy?.call(BoardComment.t),
      orderByList: orderByList?.call(BoardComment.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BoardComment] by its [id] or null if no such row exists.
  Future<BoardComment?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BoardComment>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BoardComment]s in the list and returns the inserted rows.
  ///
  /// The returned [BoardComment]s will have their `id` fields set.
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
  Future<List<BoardComment>> insert(
    _is.DatabaseSession session,
    List<BoardComment> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BoardComment>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BoardComment] and returns the inserted row.
  ///
  /// The returned [BoardComment] will have its `id` field set.
  Future<BoardComment> insertRow(
    _is.DatabaseSession session,
    BoardComment row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BoardComment>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BoardComment]s in the list and returns the resulting rows.
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
  /// The returned [BoardComment]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardComment>> upsert(
    _is.DatabaseSession session,
    List<BoardComment> rows, {
    required _is.ColumnSelections<BoardCommentTable> conflictColumns,
    _is.ColumnSelections<BoardCommentTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardCommentTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BoardComment>(
      rows,
      conflictColumns: conflictColumns(BoardComment.t),
      updateColumns: updateColumns?.call(BoardComment.t),
      updateWhere: updateWhere?.call(BoardComment.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BoardComment] and returns the resulting row.
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
  /// The returned [BoardComment] will have its `id` field set.
  Future<BoardComment?> upsertRow(
    _is.DatabaseSession session,
    BoardComment row, {
    required _is.ColumnSelections<BoardCommentTable> conflictColumns,
    _is.ColumnSelections<BoardCommentTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardCommentTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BoardComment>(
      row,
      conflictColumns: conflictColumns(BoardComment.t),
      updateColumns: updateColumns?.call(BoardComment.t),
      updateWhere: updateWhere?.call(BoardComment.t),
      transaction: transaction,
    );
  }

  /// Updates all [BoardComment]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardComment>> update(
    _is.DatabaseSession session,
    List<BoardComment> rows, {
    _is.ColumnSelections<BoardCommentTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BoardComment>(
      rows,
      columns: columns?.call(BoardComment.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BoardComment]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BoardComment> updateRow(
    _is.DatabaseSession session,
    BoardComment row, {
    _is.ColumnSelections<BoardCommentTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BoardComment>(
      row,
      columns: columns?.call(BoardComment.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BoardComment] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BoardComment?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BoardCommentUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BoardComment>(
      id,
      columnValues: columnValues(BoardComment.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BoardComment]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardComment>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BoardCommentUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<BoardCommentTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardCommentTable>? orderBy,
    _is.OrderByListBuilder<BoardCommentTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BoardComment>(
      columnValues: columnValues(BoardComment.t.updateTable),
      where: where(BoardComment.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardComment.t),
      orderByList: orderByList?.call(BoardComment.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BoardComment]s in the list and returns the deleted rows.
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
  Future<List<BoardComment>> delete(
    _is.DatabaseSession session,
    List<BoardComment> rows, {
    _is.OrderByBuilder<BoardCommentTable>? orderBy,
    _is.OrderByListBuilder<BoardCommentTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BoardComment>(
      rows,
      orderBy: orderBy?.call(BoardComment.t),
      orderByList: orderByList?.call(BoardComment.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BoardComment].
  Future<BoardComment> deleteRow(
    _is.DatabaseSession session,
    BoardComment row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BoardComment>(
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
  Future<List<BoardComment>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardCommentTable> where,
    _is.OrderByBuilder<BoardCommentTable>? orderBy,
    _is.OrderByListBuilder<BoardCommentTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BoardComment>(
      where: where(BoardComment.t),
      orderBy: orderBy?.call(BoardComment.t),
      orderByList: orderByList?.call(BoardComment.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardCommentTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BoardComment>(
      where: where?.call(BoardComment.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BoardComment] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardCommentTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BoardComment>(
      where: where(BoardComment.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
