/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_null_comparison

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;
import 'package:wonky_sync_models/wonky_sync_models.dart' as _i810rwvy;

/// One row per undo transaction, written in the same transaction as the
/// change (Slides 02 §3.10, P9). Consumed by the server after onMergeSuccess.
abstract class DeckChangeLog
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  DeckChangeLog._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.deckId,
    this.deck,
    required this.userId,
    required this.actorKind,
    required this.sessionId,
    required this.label,
    required this.summaryJson,
    this.detailJson,
    required this.at,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory DeckChangeLog({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue deckId,
    _i810rwvy.Deck? deck,
    required _iss.UuidValue userId,
    required _i810rwvy.ActorKind actorKind,
    required String sessionId,
    required String label,
    required String summaryJson,
    String? detailJson,
    required DateTime at,
    DateTime? createdAt,
  }) = _DeckChangeLogImpl;

  factory DeckChangeLog.fromJson(Map<String, dynamic> jsonSerialization) {
    return DeckChangeLog(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      deckId: _iss.UuidValueJsonExtension.fromJson(jsonSerialization['deckId']),
      deck: jsonSerialization['deck'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.Deck>(
              jsonSerialization['deck'],
            ),
      userId: _iss.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      actorKind: _i810rwvy.ActorKind.fromJson(
        (jsonSerialization['actorKind'] as String),
      ),
      sessionId: jsonSerialization['sessionId'] as String,
      label: jsonSerialization['label'] as String,
      summaryJson: jsonSerialization['summaryJson'] as String,
      detailJson: jsonSerialization['detailJson'] as String?,
      at: _iss.DateTimeJsonExtension.fromJson(jsonSerialization['at']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = DeckChangeLogTable();

  static const db = DeckChangeLogRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue deckId;

  _i810rwvy.Deck? deck;

  /// Auth user UUID of the author.
  _iss.UuidValue userId;

  _i810rwvy.ActorKind actorKind;

  String sessionId;

  /// Undo label ("Move 3 slides", "Typing"); "MCP:"/"AI:" prefixes (11 A-11-3).
  String label;

  /// {v, kinds, slides, elements, deleted, revived, chartLinks} (02 §3.10.1).
  String summaryJson;

  /// Text before/after for at most 20 bodies of 2,000 characters; else null.
  String? detailJson;

  DateTime at;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [DeckChangeLog]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  DeckChangeLog copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? deckId,
    _i810rwvy.Deck? deck = const _UndefinedDeckChangeLog$deck(),
    _iss.UuidValue? userId,
    _i810rwvy.ActorKind? actorKind,
    String? sessionId,
    String? label,
    String? summaryJson,
    String? detailJson,
    DateTime? at,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DeckChangeLog',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'deckId': deckId.toJson(),
      if (deck != null) 'deck': deck?.toJson(),
      'userId': userId.toJson(),
      'actorKind': actorKind.toJson(),
      'sessionId': sessionId,
      'label': label,
      'summaryJson': summaryJson,
      if (detailJson != null) 'detailJson': detailJson,
      'at': at.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DeckChangeLog',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'deckId': deckId.toJson(),
      if (deck != null) 'deck': deck?.toJsonForProtocol(),
      'userId': userId.toJson(),
      'actorKind': actorKind.toJson(),
      'sessionId': sessionId,
      'label': label,
      'summaryJson': summaryJson,
      if (detailJson != null) 'detailJson': detailJson,
      'at': at.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static DeckChangeLogInclude include({_i810rwvy.DeckInclude? deck}) {
    return DeckChangeLogInclude._(deck: deck);
  }

  static DeckChangeLogIncludeList includeList({
    _isd.WhereExpressionBuilder<DeckChangeLogTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DeckChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<DeckChangeLogTable>? orderByList,
    DeckChangeLogInclude? include,
  }) {
    return DeckChangeLogIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DeckChangeLog.t),
      orderByList: orderByList?.call(DeckChangeLog.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedDeckChangeLog$deck extends _iss.UndefinedSentinel
    implements _i810rwvy.Deck {
  const _UndefinedDeckChangeLog$deck();
}

class _DeckChangeLogImpl extends DeckChangeLog {
  _DeckChangeLogImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue deckId,
    _i810rwvy.Deck? deck,
    required _iss.UuidValue userId,
    required _i810rwvy.ActorKind actorKind,
    required String sessionId,
    required String label,
    required String summaryJson,
    String? detailJson,
    required DateTime at,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         deckId: deckId,
         deck: deck,
         userId: userId,
         actorKind: actorKind,
         sessionId: sessionId,
         label: label,
         summaryJson: summaryJson,
         detailJson: detailJson,
         at: at,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DeckChangeLog]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  DeckChangeLog copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? deckId,
    _i810rwvy.Deck? deck = const _UndefinedDeckChangeLog$deck(),
    _iss.UuidValue? userId,
    _i810rwvy.ActorKind? actorKind,
    String? sessionId,
    String? label,
    String? summaryJson,
    Object? detailJson = _Undefined,
    DateTime? at,
    DateTime? createdAt,
  }) {
    return DeckChangeLog(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      deckId: deckId ?? this.deckId,
      deck: deck is _iss.UndefinedSentinel ? this.deck?.copyWith() : deck,
      userId: userId ?? this.userId,
      actorKind: actorKind ?? this.actorKind,
      sessionId: sessionId ?? this.sessionId,
      label: label ?? this.label,
      summaryJson: summaryJson ?? this.summaryJson,
      detailJson: detailJson is String? ? detailJson : this.detailJson,
      at: at ?? this.at,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DeckChangeLogUpdateTable extends _isd.UpdateTable<DeckChangeLogTable> {
  DeckChangeLogUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> deckId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.deckId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> userId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.userId, value);

  _isd.ColumnValue<_i810rwvy.ActorKind, _i810rwvy.ActorKind> actorKind(
    _i810rwvy.ActorKind value,
  ) => _isd.ColumnValue(table.actorKind, value);

  _isd.ColumnValue<String, String> sessionId(String value) =>
      _isd.ColumnValue(table.sessionId, value);

  _isd.ColumnValue<String, String> label(String value) =>
      _isd.ColumnValue(table.label, value);

  _isd.ColumnValue<String, String> summaryJson(String value) =>
      _isd.ColumnValue(table.summaryJson, value);

  _isd.ColumnValue<String, String> detailJson(String? value) =>
      _isd.ColumnValue(table.detailJson, value);

  _isd.ColumnValue<DateTime, DateTime> at(DateTime value) =>
      _isd.ColumnValue(table.at, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class DeckChangeLogTable extends _isd.Table<_iss.UuidValue> {
  DeckChangeLogTable({super.tableRelation})
    : super(tableName: 'deck_change_log') {
    updateTable = DeckChangeLogUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    deckId = _isd.ColumnUuid('deckId', this);
    userId = _isd.ColumnUuid('userId', this);
    actorKind = _isd.ColumnEnum(
      'actorKind',
      this,
      _isd.EnumSerialization.byName,
    );
    sessionId = _isd.ColumnString('sessionId', this);
    label = _isd.ColumnString('label', this);
    summaryJson = _isd.ColumnString('summaryJson', this);
    detailJson = _isd.ColumnString('detailJson', this);
    at = _isd.ColumnDateTime('at', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final DeckChangeLogUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid deckId;

  _i810rwvy.DeckTable? _deck;

  /// Auth user UUID of the author.
  late final _isd.ColumnUuid userId;

  late final _isd.ColumnEnum<_i810rwvy.ActorKind> actorKind;

  late final _isd.ColumnString sessionId;

  /// Undo label ("Move 3 slides", "Typing"); "MCP:"/"AI:" prefixes (11 A-11-3).
  late final _isd.ColumnString label;

  /// {v, kinds, slides, elements, deleted, revived, chartLinks} (02 §3.10.1).
  late final _isd.ColumnString summaryJson;

  /// Text before/after for at most 20 bodies of 2,000 characters; else null.
  late final _isd.ColumnString detailJson;

  late final _isd.ColumnDateTime at;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.DeckTable get deck {
    if (_deck != null) return _deck!;
    _deck = _isd.createRelationTable(
      relationFieldName: 'deck',
      field: DeckChangeLog.t.deckId,
      foreignField: _i810rwvy.Deck.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.DeckTable(tableRelation: foreignTableRelation),
    );
    return _deck!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    deckId,
    userId,
    actorKind,
    sessionId,
    label,
    summaryJson,
    detailJson,
    at,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'deck') {
      return deck;
    }
    return null;
  }
}

class DeckChangeLogInclude extends _isd.IncludeObject {
  DeckChangeLogInclude._({_i810rwvy.DeckInclude? deck}) {
    _deck = deck;
  }

  _i810rwvy.DeckInclude? _deck;

  @override
  Map<String, _isd.Include?> get includes => {'deck': _deck};

  @override
  _isd.Table<_iss.UuidValue> get table => DeckChangeLog.t;
}

class DeckChangeLogIncludeList extends _isd.IncludeList {
  DeckChangeLogIncludeList._({
    _isd.WhereExpressionBuilder<DeckChangeLogTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DeckChangeLog.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => DeckChangeLog.t;
}

class DeckChangeLogRepository {
  const DeckChangeLogRepository._();

  final attachRow = const DeckChangeLogAttachRowRepository._();

  /// Returns a list of [DeckChangeLog]s matching the given query parameters.
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
  Future<List<DeckChangeLog>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DeckChangeLogTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DeckChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<DeckChangeLogTable>? orderByList,
    _isd.Transaction? transaction,
    DeckChangeLogInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DeckChangeLog>(
      where: where?.call(DeckChangeLog.t),
      orderBy: orderBy?.call(DeckChangeLog.t),
      orderByList: orderByList?.call(DeckChangeLog.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [DeckChangeLog]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `DeckChangeLog.t`.
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
  _ida.Stream<List<DeckChangeLog>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DeckChangeLogTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DeckChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<DeckChangeLogTable>? orderByList,
    DeckChangeLogInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<DeckChangeLog>(
      where: where?.call(DeckChangeLog.t),
      orderBy: orderBy?.call(DeckChangeLog.t),
      orderByList: orderByList?.call(DeckChangeLog.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [DeckChangeLog] matching the given query parameters.
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
  Future<DeckChangeLog?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DeckChangeLogTable>? where,
    int? offset,
    _isd.OrderByBuilder<DeckChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<DeckChangeLogTable>? orderByList,
    _isd.Transaction? transaction,
    DeckChangeLogInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DeckChangeLog>(
      where: where?.call(DeckChangeLog.t),
      orderBy: orderBy?.call(DeckChangeLog.t),
      orderByList: orderByList?.call(DeckChangeLog.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DeckChangeLog] by its [id] or null if no such row exists.
  Future<DeckChangeLog?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    DeckChangeLogInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DeckChangeLog>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DeckChangeLog]s in the list and returns the inserted rows.
  ///
  /// The returned [DeckChangeLog]s will have their `id` fields set.
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
  Future<List<DeckChangeLog>> insert(
    _isd.DatabaseSession session,
    List<DeckChangeLog> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DeckChangeLog>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DeckChangeLog] and returns the inserted row.
  ///
  /// The returned [DeckChangeLog] will have its `id` field set.
  Future<DeckChangeLog> insertRow(
    _isd.DatabaseSession session,
    DeckChangeLog row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<DeckChangeLog>(row, transaction: transaction);
  }

  /// Upserts all [DeckChangeLog]s in the list and returns the resulting rows.
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
  /// The returned [DeckChangeLog]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeckChangeLog>> upsert(
    _isd.DatabaseSession session,
    List<DeckChangeLog> rows, {
    required _isd.ColumnSelections<DeckChangeLogTable> conflictColumns,
    _isd.ColumnSelections<DeckChangeLogTable>? updateColumns,
    _isd.WhereExpressionBuilder<DeckChangeLogTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DeckChangeLog>(
      rows,
      conflictColumns: conflictColumns(DeckChangeLog.t),
      updateColumns: updateColumns?.call(DeckChangeLog.t),
      updateWhere: updateWhere?.call(DeckChangeLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DeckChangeLog] and returns the resulting row.
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
  /// The returned [DeckChangeLog] will have its `id` field set.
  Future<DeckChangeLog?> upsertRow(
    _isd.DatabaseSession session,
    DeckChangeLog row, {
    required _isd.ColumnSelections<DeckChangeLogTable> conflictColumns,
    _isd.ColumnSelections<DeckChangeLogTable>? updateColumns,
    _isd.WhereExpressionBuilder<DeckChangeLogTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DeckChangeLog>(
      row,
      conflictColumns: conflictColumns(DeckChangeLog.t),
      updateColumns: updateColumns?.call(DeckChangeLog.t),
      updateWhere: updateWhere?.call(DeckChangeLog.t),
      transaction: transaction,
    );
  }

  /// Updates all [DeckChangeLog]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeckChangeLog>> update(
    _isd.DatabaseSession session,
    List<DeckChangeLog> rows, {
    _isd.ColumnSelections<DeckChangeLogTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DeckChangeLog>(
      rows,
      columns: columns?.call(DeckChangeLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DeckChangeLog]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DeckChangeLog> updateRow(
    _isd.DatabaseSession session,
    DeckChangeLog row, {
    _isd.ColumnSelections<DeckChangeLogTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<DeckChangeLog>(
      row,
      columns: columns?.call(DeckChangeLog.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DeckChangeLog] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DeckChangeLog?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<DeckChangeLogUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<DeckChangeLog>(
      id,
      columnValues: columnValues(DeckChangeLog.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DeckChangeLog]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeckChangeLog>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<DeckChangeLogUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<DeckChangeLogTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DeckChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<DeckChangeLogTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DeckChangeLog>(
      columnValues: columnValues(DeckChangeLog.t.updateTable),
      where: where(DeckChangeLog.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DeckChangeLog.t),
      orderByList: orderByList?.call(DeckChangeLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DeckChangeLog]s in the list and returns the deleted rows.
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
  Future<List<DeckChangeLog>> delete(
    _isd.DatabaseSession session,
    List<DeckChangeLog> rows, {
    _isd.OrderByBuilder<DeckChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<DeckChangeLogTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DeckChangeLog>(
      rows,
      orderBy: orderBy?.call(DeckChangeLog.t),
      orderByList: orderByList?.call(DeckChangeLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DeckChangeLog].
  Future<DeckChangeLog> deleteRow(
    _isd.DatabaseSession session,
    DeckChangeLog row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DeckChangeLog>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeckChangeLog>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<DeckChangeLogTable> where,
    _isd.OrderByBuilder<DeckChangeLogTable>? orderBy,
    _isd.OrderByListBuilder<DeckChangeLogTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DeckChangeLog>(
      where: where(DeckChangeLog.t),
      orderBy: orderBy?.call(DeckChangeLog.t),
      orderByList: orderByList?.call(DeckChangeLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DeckChangeLogTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<DeckChangeLog>(
      where: where?.call(DeckChangeLog.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DeckChangeLog] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<DeckChangeLogTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DeckChangeLog>(
      where: where(DeckChangeLog.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class DeckChangeLogAttachRowRepository {
  const DeckChangeLogAttachRowRepository._();

  /// Creates a relation between the given [DeckChangeLog] and [Deck]
  /// by setting the [DeckChangeLog]'s foreign key `deckId` to refer to the [Deck].
  Future<void> deck(
    _isd.DatabaseSession session,
    DeckChangeLog deckChangeLog,
    _i810rwvy.Deck deck, {
    _isd.Transaction? transaction,
  }) async {
    if (deckChangeLog.id == null) {
      throw ArgumentError.notNull('deckChangeLog.id');
    }
    if (deck.id == null) {
      throw ArgumentError.notNull('deck.id');
    }

    var $deckChangeLog = deckChangeLog.copyWith(deckId: deck.id);
    await session.db.updateRow<DeckChangeLog>(
      $deckChangeLog,
      columns: [DeckChangeLog.t.deckId],
      transaction: transaction,
    );
  }
}
