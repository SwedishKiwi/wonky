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
import '../../platform/comments/comment_anchor_kind.dart' as _if06qrbr;
import '../../platform/comments/comment_status.dart' as _ifhvdxb2;

/// A comment thread on a drive item (specs/07 §2.1).
abstract class CommentThread
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  CommentThread._({
    this.id,
    required this.uuid,
    required this.itemId,
    required this.anchorKind,
    required this.anchorJson,
    this.quotedText,
    _ifhvdxb2.CommentStatus? status,
    required this.createdById,
    required this.createdAt,
    this.updatedAt,
    this.resolvedById,
    this.resolvedAt,
    this.assigneeId,
    this.statusBeforeOrphan,
    this.orphanReasonJson,
    this.suggestionId,
  }) : status = status ?? _ifhvdxb2.CommentStatus.open;

  factory CommentThread({
    int? id,
    required _is.UuidValue uuid,
    required int itemId,
    required _if06qrbr.CommentAnchorKind anchorKind,
    required String anchorJson,
    String? quotedText,
    _ifhvdxb2.CommentStatus? status,
    required int createdById,
    required DateTime createdAt,
    DateTime? updatedAt,
    int? resolvedById,
    DateTime? resolvedAt,
    int? assigneeId,
    _ifhvdxb2.CommentStatus? statusBeforeOrphan,
    String? orphanReasonJson,
    String? suggestionId,
  }) = _CommentThreadImpl;

  factory CommentThread.fromJson(Map<String, dynamic> jsonSerialization) {
    return CommentThread(
      id: jsonSerialization['id'] as int?,
      uuid: _is.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      itemId: jsonSerialization['itemId'] as int,
      anchorKind: _if06qrbr.CommentAnchorKind.fromJson(
        (jsonSerialization['anchorKind'] as String),
      ),
      anchorJson: jsonSerialization['anchorJson'] as String,
      quotedText: jsonSerialization['quotedText'] as String?,
      status: jsonSerialization['status'] == null
          ? null
          : _ifhvdxb2.CommentStatus.fromJson(
              (jsonSerialization['status'] as String),
            ),
      createdById: jsonSerialization['createdById'] as int,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
      resolvedById: jsonSerialization['resolvedById'] as int?,
      resolvedAt: jsonSerialization['resolvedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['resolvedAt']),
      assigneeId: jsonSerialization['assigneeId'] as int?,
      statusBeforeOrphan: jsonSerialization['statusBeforeOrphan'] == null
          ? null
          : _ifhvdxb2.CommentStatus.fromJson(
              (jsonSerialization['statusBeforeOrphan'] as String),
            ),
      orphanReasonJson: jsonSerialization['orphanReasonJson'] as String?,
      suggestionId: jsonSerialization['suggestionId'] as String?,
    );
  }

  static final t = CommentThreadTable();

  static const db = CommentThreadRepository._();

  @override
  int? id;

  /// Client-supplied (UUIDv7) so offline creation is idempotent. Write
  /// suggestion threads use UUIDv5(documentUuid, "sug:" + id).
  _is.UuidValue uuid;

  int itemId;

  _if06qrbr.CommentAnchorKind anchorKind;

  /// App-specific anchor JSON (Write 08 §1.1, Sheets 10 §3.1).
  String anchorJson;

  /// Snapshot of the anchored text or value at creation (≤ 500 chars).
  String? quotedText;

  _ifhvdxb2.CommentStatus status;

  int createdById;

  DateTime createdAt;

  DateTime? updatedAt;

  int? resolvedById;

  DateTime? resolvedAt;

  int? assigneeId;

  /// Restored when an orphaned anchor comes back.
  _ifhvdxb2.CommentStatus? statusBeforeOrphan;

  /// e.g. {"kind":"rowDeleted","rowId":…}.
  String? orphanReasonJson;

  /// Write suggestion id when this is a suggestion thread.
  String? suggestionId;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [CommentThread]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  CommentThread copyWith({
    int? id,
    _is.UuidValue? uuid,
    int? itemId,
    _if06qrbr.CommentAnchorKind? anchorKind,
    String? anchorJson,
    String? quotedText,
    _ifhvdxb2.CommentStatus? status,
    int? createdById,
    DateTime? createdAt,
    DateTime? updatedAt = const _is.$UndefinedDateTime(),
    int? resolvedById,
    DateTime? resolvedAt = const _is.$UndefinedDateTime(),
    int? assigneeId,
    _ifhvdxb2.CommentStatus? statusBeforeOrphan,
    String? orphanReasonJson,
    String? suggestionId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CommentThread',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      'itemId': itemId,
      'anchorKind': anchorKind.toJson(),
      'anchorJson': anchorJson,
      if (quotedText != null) 'quotedText': quotedText,
      'status': status.toJson(),
      'createdById': createdById,
      'createdAt': createdAt.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      if (resolvedById != null) 'resolvedById': resolvedById,
      if (resolvedAt != null) 'resolvedAt': resolvedAt?.toJson(),
      if (assigneeId != null) 'assigneeId': assigneeId,
      if (statusBeforeOrphan != null)
        'statusBeforeOrphan': statusBeforeOrphan?.toJson(),
      if (orphanReasonJson != null) 'orphanReasonJson': orphanReasonJson,
      if (suggestionId != null) 'suggestionId': suggestionId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CommentThread',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      'itemId': itemId,
      'anchorKind': anchorKind.toJson(),
      'anchorJson': anchorJson,
      if (quotedText != null) 'quotedText': quotedText,
      'status': status.toJson(),
      'createdById': createdById,
      'createdAt': createdAt.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      if (resolvedById != null) 'resolvedById': resolvedById,
      if (resolvedAt != null) 'resolvedAt': resolvedAt?.toJson(),
      if (assigneeId != null) 'assigneeId': assigneeId,
      if (statusBeforeOrphan != null)
        'statusBeforeOrphan': statusBeforeOrphan?.toJson(),
      if (orphanReasonJson != null) 'orphanReasonJson': orphanReasonJson,
      if (suggestionId != null) 'suggestionId': suggestionId,
    };
  }

  static CommentThreadInclude include() {
    return CommentThreadInclude._();
  }

  static CommentThreadIncludeList includeList({
    _is.WhereExpressionBuilder<CommentThreadTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CommentThreadTable>? orderBy,
    _is.OrderByListBuilder<CommentThreadTable>? orderByList,
    CommentThreadInclude? include,
  }) {
    return CommentThreadIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CommentThread.t),
      orderByList: orderByList?.call(CommentThread.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CommentThreadImpl extends CommentThread {
  _CommentThreadImpl({
    int? id,
    required _is.UuidValue uuid,
    required int itemId,
    required _if06qrbr.CommentAnchorKind anchorKind,
    required String anchorJson,
    String? quotedText,
    _ifhvdxb2.CommentStatus? status,
    required int createdById,
    required DateTime createdAt,
    DateTime? updatedAt,
    int? resolvedById,
    DateTime? resolvedAt,
    int? assigneeId,
    _ifhvdxb2.CommentStatus? statusBeforeOrphan,
    String? orphanReasonJson,
    String? suggestionId,
  }) : super._(
         id: id,
         uuid: uuid,
         itemId: itemId,
         anchorKind: anchorKind,
         anchorJson: anchorJson,
         quotedText: quotedText,
         status: status,
         createdById: createdById,
         createdAt: createdAt,
         updatedAt: updatedAt,
         resolvedById: resolvedById,
         resolvedAt: resolvedAt,
         assigneeId: assigneeId,
         statusBeforeOrphan: statusBeforeOrphan,
         orphanReasonJson: orphanReasonJson,
         suggestionId: suggestionId,
       );

  /// Returns a shallow copy of this [CommentThread]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  CommentThread copyWith({
    Object? id = _Undefined,
    _is.UuidValue? uuid,
    int? itemId,
    _if06qrbr.CommentAnchorKind? anchorKind,
    String? anchorJson,
    Object? quotedText = _Undefined,
    _ifhvdxb2.CommentStatus? status,
    int? createdById,
    DateTime? createdAt,
    DateTime? updatedAt = const _is.$UndefinedDateTime(),
    Object? resolvedById = _Undefined,
    DateTime? resolvedAt = const _is.$UndefinedDateTime(),
    Object? assigneeId = _Undefined,
    Object? statusBeforeOrphan = _Undefined,
    Object? orphanReasonJson = _Undefined,
    Object? suggestionId = _Undefined,
  }) {
    return CommentThread(
      id: id is int? ? id : this.id,
      uuid: uuid ?? this.uuid,
      itemId: itemId ?? this.itemId,
      anchorKind: anchorKind ?? this.anchorKind,
      anchorJson: anchorJson ?? this.anchorJson,
      quotedText: quotedText is String? ? quotedText : this.quotedText,
      status: status ?? this.status,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt is _is.UndefinedSentinel
          ? this.updatedAt
          : updatedAt,
      resolvedById: resolvedById is int? ? resolvedById : this.resolvedById,
      resolvedAt: resolvedAt is _is.UndefinedSentinel
          ? this.resolvedAt
          : resolvedAt,
      assigneeId: assigneeId is int? ? assigneeId : this.assigneeId,
      statusBeforeOrphan: statusBeforeOrphan is _ifhvdxb2.CommentStatus?
          ? statusBeforeOrphan
          : this.statusBeforeOrphan,
      orphanReasonJson: orphanReasonJson is String?
          ? orphanReasonJson
          : this.orphanReasonJson,
      suggestionId: suggestionId is String? ? suggestionId : this.suggestionId,
    );
  }
}

class CommentThreadUpdateTable extends _is.UpdateTable<CommentThreadTable> {
  CommentThreadUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> uuid(_is.UuidValue value) =>
      _is.ColumnValue(
        table.uuid,
        value,
      );

  _is.ColumnValue<int, int> itemId(int value) => _is.ColumnValue(
    table.itemId,
    value,
  );

  _is.ColumnValue<_if06qrbr.CommentAnchorKind, _if06qrbr.CommentAnchorKind>
  anchorKind(_if06qrbr.CommentAnchorKind value) => _is.ColumnValue(
    table.anchorKind,
    value,
  );

  _is.ColumnValue<String, String> anchorJson(String value) => _is.ColumnValue(
    table.anchorJson,
    value,
  );

  _is.ColumnValue<String, String> quotedText(String? value) => _is.ColumnValue(
    table.quotedText,
    value,
  );

  _is.ColumnValue<_ifhvdxb2.CommentStatus, _ifhvdxb2.CommentStatus> status(
    _ifhvdxb2.CommentStatus value,
  ) => _is.ColumnValue(
    table.status,
    value,
  );

  _is.ColumnValue<int, int> createdById(int value) => _is.ColumnValue(
    table.createdById,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime? value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );

  _is.ColumnValue<int, int> resolvedById(int? value) => _is.ColumnValue(
    table.resolvedById,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> resolvedAt(DateTime? value) =>
      _is.ColumnValue(
        table.resolvedAt,
        value,
      );

  _is.ColumnValue<int, int> assigneeId(int? value) => _is.ColumnValue(
    table.assigneeId,
    value,
  );

  _is.ColumnValue<_ifhvdxb2.CommentStatus, _ifhvdxb2.CommentStatus>
  statusBeforeOrphan(_ifhvdxb2.CommentStatus? value) => _is.ColumnValue(
    table.statusBeforeOrphan,
    value,
  );

  _is.ColumnValue<String, String> orphanReasonJson(String? value) =>
      _is.ColumnValue(
        table.orphanReasonJson,
        value,
      );

  _is.ColumnValue<String, String> suggestionId(String? value) =>
      _is.ColumnValue(
        table.suggestionId,
        value,
      );
}

class CommentThreadTable extends _is.Table<int?> {
  CommentThreadTable({super.tableRelation})
    : super(tableName: 'comment_thread') {
    updateTable = CommentThreadUpdateTable(this);
    uuid = _is.ColumnUuid(
      'uuid',
      this,
    );
    itemId = _is.ColumnInt(
      'itemId',
      this,
    );
    anchorKind = _is.ColumnEnum(
      'anchorKind',
      this,
      _is.EnumSerialization.byName,
    );
    anchorJson = _is.ColumnString(
      'anchorJson',
      this,
    );
    quotedText = _is.ColumnString(
      'quotedText',
      this,
    );
    status = _is.ColumnEnum(
      'status',
      this,
      _is.EnumSerialization.byName,
      hasDefault: true,
    );
    createdById = _is.ColumnInt(
      'createdById',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
    resolvedById = _is.ColumnInt(
      'resolvedById',
      this,
    );
    resolvedAt = _is.ColumnDateTime(
      'resolvedAt',
      this,
    );
    assigneeId = _is.ColumnInt(
      'assigneeId',
      this,
    );
    statusBeforeOrphan = _is.ColumnEnum(
      'statusBeforeOrphan',
      this,
      _is.EnumSerialization.byName,
    );
    orphanReasonJson = _is.ColumnString(
      'orphanReasonJson',
      this,
    );
    suggestionId = _is.ColumnString(
      'suggestionId',
      this,
    );
  }

  late final CommentThreadUpdateTable updateTable;

  /// Client-supplied (UUIDv7) so offline creation is idempotent. Write
  /// suggestion threads use UUIDv5(documentUuid, "sug:" + id).
  late final _is.ColumnUuid uuid;

  late final _is.ColumnInt itemId;

  late final _is.ColumnEnum<_if06qrbr.CommentAnchorKind> anchorKind;

  /// App-specific anchor JSON (Write 08 §1.1, Sheets 10 §3.1).
  late final _is.ColumnString anchorJson;

  /// Snapshot of the anchored text or value at creation (≤ 500 chars).
  late final _is.ColumnString quotedText;

  late final _is.ColumnEnum<_ifhvdxb2.CommentStatus> status;

  late final _is.ColumnInt createdById;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime updatedAt;

  late final _is.ColumnInt resolvedById;

  late final _is.ColumnDateTime resolvedAt;

  late final _is.ColumnInt assigneeId;

  /// Restored when an orphaned anchor comes back.
  late final _is.ColumnEnum<_ifhvdxb2.CommentStatus> statusBeforeOrphan;

  /// e.g. {"kind":"rowDeleted","rowId":…}.
  late final _is.ColumnString orphanReasonJson;

  /// Write suggestion id when this is a suggestion thread.
  late final _is.ColumnString suggestionId;

  @override
  List<_is.Column> get columns => [
    id,
    uuid,
    itemId,
    anchorKind,
    anchorJson,
    quotedText,
    status,
    createdById,
    createdAt,
    updatedAt,
    resolvedById,
    resolvedAt,
    assigneeId,
    statusBeforeOrphan,
    orphanReasonJson,
    suggestionId,
  ];
}

class CommentThreadInclude extends _is.IncludeObject {
  CommentThreadInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => CommentThread.t;
}

class CommentThreadIncludeList extends _is.IncludeList {
  CommentThreadIncludeList._({
    _is.WhereExpressionBuilder<CommentThreadTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CommentThread.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => CommentThread.t;
}

class CommentThreadRepository {
  const CommentThreadRepository._();

  /// Returns a list of [CommentThread]s matching the given query parameters.
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
  Future<List<CommentThread>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CommentThreadTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CommentThreadTable>? orderBy,
    _is.OrderByListBuilder<CommentThreadTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CommentThread>(
      where: where?.call(CommentThread.t),
      orderBy: orderBy?.call(CommentThread.t),
      orderByList: orderByList?.call(CommentThread.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [CommentThread]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `CommentThread.t`.
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
  _ida.Stream<List<CommentThread>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CommentThreadTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CommentThreadTable>? orderBy,
    _is.OrderByListBuilder<CommentThreadTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<CommentThread>(
      where: where?.call(CommentThread.t),
      orderBy: orderBy?.call(CommentThread.t),
      orderByList: orderByList?.call(CommentThread.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [CommentThread] matching the given query parameters.
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
  Future<CommentThread?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CommentThreadTable>? where,
    int? offset,
    _is.OrderByBuilder<CommentThreadTable>? orderBy,
    _is.OrderByListBuilder<CommentThreadTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CommentThread>(
      where: where?.call(CommentThread.t),
      orderBy: orderBy?.call(CommentThread.t),
      orderByList: orderByList?.call(CommentThread.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CommentThread] by its [id] or null if no such row exists.
  Future<CommentThread?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CommentThread>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CommentThread]s in the list and returns the inserted rows.
  ///
  /// The returned [CommentThread]s will have their `id` fields set.
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
  Future<List<CommentThread>> insert(
    _is.DatabaseSession session,
    List<CommentThread> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CommentThread>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CommentThread] and returns the inserted row.
  ///
  /// The returned [CommentThread] will have its `id` field set.
  Future<CommentThread> insertRow(
    _is.DatabaseSession session,
    CommentThread row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<CommentThread>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CommentThread]s in the list and returns the resulting rows.
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
  /// The returned [CommentThread]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CommentThread>> upsert(
    _is.DatabaseSession session,
    List<CommentThread> rows, {
    required _is.ColumnSelections<CommentThreadTable> conflictColumns,
    _is.ColumnSelections<CommentThreadTable>? updateColumns,
    _is.WhereExpressionBuilder<CommentThreadTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CommentThread>(
      rows,
      conflictColumns: conflictColumns(CommentThread.t),
      updateColumns: updateColumns?.call(CommentThread.t),
      updateWhere: updateWhere?.call(CommentThread.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CommentThread] and returns the resulting row.
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
  /// The returned [CommentThread] will have its `id` field set.
  Future<CommentThread?> upsertRow(
    _is.DatabaseSession session,
    CommentThread row, {
    required _is.ColumnSelections<CommentThreadTable> conflictColumns,
    _is.ColumnSelections<CommentThreadTable>? updateColumns,
    _is.WhereExpressionBuilder<CommentThreadTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CommentThread>(
      row,
      conflictColumns: conflictColumns(CommentThread.t),
      updateColumns: updateColumns?.call(CommentThread.t),
      updateWhere: updateWhere?.call(CommentThread.t),
      transaction: transaction,
    );
  }

  /// Updates all [CommentThread]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CommentThread>> update(
    _is.DatabaseSession session,
    List<CommentThread> rows, {
    _is.ColumnSelections<CommentThreadTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CommentThread>(
      rows,
      columns: columns?.call(CommentThread.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CommentThread]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CommentThread> updateRow(
    _is.DatabaseSession session,
    CommentThread row, {
    _is.ColumnSelections<CommentThreadTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<CommentThread>(
      row,
      columns: columns?.call(CommentThread.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CommentThread] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CommentThread?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<CommentThreadUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<CommentThread>(
      id,
      columnValues: columnValues(CommentThread.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CommentThread]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CommentThread>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<CommentThreadUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<CommentThreadTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CommentThreadTable>? orderBy,
    _is.OrderByListBuilder<CommentThreadTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CommentThread>(
      columnValues: columnValues(CommentThread.t.updateTable),
      where: where(CommentThread.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CommentThread.t),
      orderByList: orderByList?.call(CommentThread.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CommentThread]s in the list and returns the deleted rows.
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
  Future<List<CommentThread>> delete(
    _is.DatabaseSession session,
    List<CommentThread> rows, {
    _is.OrderByBuilder<CommentThreadTable>? orderBy,
    _is.OrderByListBuilder<CommentThreadTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CommentThread>(
      rows,
      orderBy: orderBy?.call(CommentThread.t),
      orderByList: orderByList?.call(CommentThread.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CommentThread].
  Future<CommentThread> deleteRow(
    _is.DatabaseSession session,
    CommentThread row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CommentThread>(
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
  Future<List<CommentThread>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<CommentThreadTable> where,
    _is.OrderByBuilder<CommentThreadTable>? orderBy,
    _is.OrderByListBuilder<CommentThreadTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CommentThread>(
      where: where(CommentThread.t),
      orderBy: orderBy?.call(CommentThread.t),
      orderByList: orderByList?.call(CommentThread.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CommentThreadTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<CommentThread>(
      where: where?.call(CommentThread.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CommentThread] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<CommentThreadTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CommentThread>(
      where: where(CommentThread.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
