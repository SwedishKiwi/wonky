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

/// A slide group (section) of the navigator (Slides 02 §3.4, decision D11).
/// Groups share the top-level key space with ungrouped slides.
abstract class SlideGroup
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  SlideGroup._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.deckId,
    this.deck,
    required this.title,
    required this.sortKey,
    this.parentId,
    this.color,
    bool? skipped,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       skipped = skipped ?? false,
       createdAt = createdAt ?? DateTime.now();

  factory SlideGroup({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue deckId,
    _i810rwvy.Deck? deck,
    required String title,
    required String sortKey,
    _iss.UuidValue? parentId,
    String? color,
    bool? skipped,
    DateTime? createdAt,
  }) = _SlideGroupImpl;

  factory SlideGroup.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlideGroup(
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
      title: jsonSerialization['title'] as String,
      sortKey: jsonSerialization['sortKey'] as String,
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
      color: jsonSerialization['color'] as String?,
      skipped: jsonSerialization['skipped'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['skipped']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = SlideGroupTable();

  static const db = SlideGroupRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue deckId;

  _i810rwvy.Deck? deck;

  /// "Intro"; 1-100 characters.
  String title;

  /// Top-level key space (shared with ungrouped slides).
  String sortKey;

  /// Reserved for nested groups (P2, 04 §5.12); always null in v1.
  _iss.UuidValue? parentId;

  /// Palette token: gray, red, orange, amber, green, teal, blue, violet, pink.
  String? color;

  /// Skips all its slides when presenting/exporting.
  bool skipped;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [SlideGroup]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  SlideGroup copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? deckId,
    _i810rwvy.Deck? deck = const _UndefinedSlideGroup$deck(),
    String? title,
    String? sortKey,
    _iss.UuidValue? parentId = const _iss.$UndefinedUuidValue(),
    String? color,
    bool? skipped,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlideGroup',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'deckId': deckId.toJson(),
      if (deck != null) 'deck': deck?.toJson(),
      'title': title,
      'sortKey': sortKey,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (color != null) 'color': color,
      'skipped': skipped,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlideGroup',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'deckId': deckId.toJson(),
      if (deck != null) 'deck': deck?.toJsonForProtocol(),
      'title': title,
      'sortKey': sortKey,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (color != null) 'color': color,
      'skipped': skipped,
      'createdAt': createdAt.toJson(),
    };
  }

  static SlideGroupInclude include({_i810rwvy.DeckInclude? deck}) {
    return SlideGroupInclude._(deck: deck);
  }

  static SlideGroupIncludeList includeList({
    _isd.WhereExpressionBuilder<SlideGroupTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideGroupTable>? orderBy,
    _isd.OrderByListBuilder<SlideGroupTable>? orderByList,
    SlideGroupInclude? include,
  }) {
    return SlideGroupIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideGroup.t),
      orderByList: orderByList?.call(SlideGroup.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedSlideGroup$deck extends _iss.UndefinedSentinel
    implements _i810rwvy.Deck {
  const _UndefinedSlideGroup$deck();
}

class _SlideGroupImpl extends SlideGroup {
  _SlideGroupImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue deckId,
    _i810rwvy.Deck? deck,
    required String title,
    required String sortKey,
    _iss.UuidValue? parentId,
    String? color,
    bool? skipped,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         deckId: deckId,
         deck: deck,
         title: title,
         sortKey: sortKey,
         parentId: parentId,
         color: color,
         skipped: skipped,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SlideGroup]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  SlideGroup copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? deckId,
    _i810rwvy.Deck? deck = const _UndefinedSlideGroup$deck(),
    String? title,
    String? sortKey,
    _iss.UuidValue? parentId = const _iss.$UndefinedUuidValue(),
    Object? color = _Undefined,
    bool? skipped,
    DateTime? createdAt,
  }) {
    return SlideGroup(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      deckId: deckId ?? this.deckId,
      deck: deck is _iss.UndefinedSentinel ? this.deck?.copyWith() : deck,
      title: title ?? this.title,
      sortKey: sortKey ?? this.sortKey,
      parentId: parentId is _iss.UndefinedSentinel ? this.parentId : parentId,
      color: color is String? ? color : this.color,
      skipped: skipped ?? this.skipped,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SlideGroupUpdateTable extends _isd.UpdateTable<SlideGroupTable> {
  SlideGroupUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> deckId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.deckId, value);

  _isd.ColumnValue<String, String> title(String value) =>
      _isd.ColumnValue(table.title, value);

  _isd.ColumnValue<String, String> sortKey(String value) =>
      _isd.ColumnValue(table.sortKey, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> parentId(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.parentId, value);

  _isd.ColumnValue<String, String> color(String? value) =>
      _isd.ColumnValue(table.color, value);

  _isd.ColumnValue<bool, bool> skipped(bool value) =>
      _isd.ColumnValue(table.skipped, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class SlideGroupTable extends _isd.Table<_iss.UuidValue> {
  SlideGroupTable({super.tableRelation}) : super(tableName: 'slide_group') {
    updateTable = SlideGroupUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    deckId = _isd.ColumnUuid('deckId', this);
    title = _isd.ColumnString('title', this);
    sortKey = _isd.ColumnString('sortKey', this);
    parentId = _isd.ColumnUuid('parentId', this);
    color = _isd.ColumnString('color', this);
    skipped = _isd.ColumnBool('skipped', this, hasDefault: true);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final SlideGroupUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid deckId;

  _i810rwvy.DeckTable? _deck;

  /// "Intro"; 1-100 characters.
  late final _isd.ColumnString title;

  /// Top-level key space (shared with ungrouped slides).
  late final _isd.ColumnString sortKey;

  /// Reserved for nested groups (P2, 04 §5.12); always null in v1.
  late final _isd.ColumnUuid parentId;

  /// Palette token: gray, red, orange, amber, green, teal, blue, violet, pink.
  late final _isd.ColumnString color;

  /// Skips all its slides when presenting/exporting.
  late final _isd.ColumnBool skipped;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.DeckTable get deck {
    if (_deck != null) return _deck!;
    _deck = _isd.createRelationTable(
      relationFieldName: 'deck',
      field: SlideGroup.t.deckId,
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
    title,
    sortKey,
    parentId,
    color,
    skipped,
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

class SlideGroupInclude extends _isd.IncludeObject {
  SlideGroupInclude._({_i810rwvy.DeckInclude? deck}) {
    _deck = deck;
  }

  _i810rwvy.DeckInclude? _deck;

  @override
  Map<String, _isd.Include?> get includes => {'deck': _deck};

  @override
  _isd.Table<_iss.UuidValue> get table => SlideGroup.t;
}

class SlideGroupIncludeList extends _isd.IncludeList {
  SlideGroupIncludeList._({
    _isd.WhereExpressionBuilder<SlideGroupTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SlideGroup.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => SlideGroup.t;
}

class SlideGroupRepository {
  const SlideGroupRepository._();

  final attachRow = const SlideGroupAttachRowRepository._();

  /// Returns a list of [SlideGroup]s matching the given query parameters.
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
  Future<List<SlideGroup>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideGroupTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideGroupTable>? orderBy,
    _isd.OrderByListBuilder<SlideGroupTable>? orderByList,
    _isd.Transaction? transaction,
    SlideGroupInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SlideGroup>(
      where: where?.call(SlideGroup.t),
      orderBy: orderBy?.call(SlideGroup.t),
      orderByList: orderByList?.call(SlideGroup.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SlideGroup]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SlideGroup.t`.
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
  _ida.Stream<List<SlideGroup>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideGroupTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideGroupTable>? orderBy,
    _isd.OrderByListBuilder<SlideGroupTable>? orderByList,
    SlideGroupInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SlideGroup>(
      where: where?.call(SlideGroup.t),
      orderBy: orderBy?.call(SlideGroup.t),
      orderByList: orderByList?.call(SlideGroup.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SlideGroup] matching the given query parameters.
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
  Future<SlideGroup?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideGroupTable>? where,
    int? offset,
    _isd.OrderByBuilder<SlideGroupTable>? orderBy,
    _isd.OrderByListBuilder<SlideGroupTable>? orderByList,
    _isd.Transaction? transaction,
    SlideGroupInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SlideGroup>(
      where: where?.call(SlideGroup.t),
      orderBy: orderBy?.call(SlideGroup.t),
      orderByList: orderByList?.call(SlideGroup.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SlideGroup] by its [id] or null if no such row exists.
  Future<SlideGroup?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SlideGroupInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SlideGroup>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SlideGroup]s in the list and returns the inserted rows.
  ///
  /// The returned [SlideGroup]s will have their `id` fields set.
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
  Future<List<SlideGroup>> insert(
    _isd.DatabaseSession session,
    List<SlideGroup> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SlideGroup>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SlideGroup] and returns the inserted row.
  ///
  /// The returned [SlideGroup] will have its `id` field set.
  Future<SlideGroup> insertRow(
    _isd.DatabaseSession session,
    SlideGroup row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SlideGroup>(row, transaction: transaction);
  }

  /// Upserts all [SlideGroup]s in the list and returns the resulting rows.
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
  /// The returned [SlideGroup]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideGroup>> upsert(
    _isd.DatabaseSession session,
    List<SlideGroup> rows, {
    required _isd.ColumnSelections<SlideGroupTable> conflictColumns,
    _isd.ColumnSelections<SlideGroupTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideGroupTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SlideGroup>(
      rows,
      conflictColumns: conflictColumns(SlideGroup.t),
      updateColumns: updateColumns?.call(SlideGroup.t),
      updateWhere: updateWhere?.call(SlideGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SlideGroup] and returns the resulting row.
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
  /// The returned [SlideGroup] will have its `id` field set.
  Future<SlideGroup?> upsertRow(
    _isd.DatabaseSession session,
    SlideGroup row, {
    required _isd.ColumnSelections<SlideGroupTable> conflictColumns,
    _isd.ColumnSelections<SlideGroupTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideGroupTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SlideGroup>(
      row,
      conflictColumns: conflictColumns(SlideGroup.t),
      updateColumns: updateColumns?.call(SlideGroup.t),
      updateWhere: updateWhere?.call(SlideGroup.t),
      transaction: transaction,
    );
  }

  /// Updates all [SlideGroup]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideGroup>> update(
    _isd.DatabaseSession session,
    List<SlideGroup> rows, {
    _isd.ColumnSelections<SlideGroupTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SlideGroup>(
      rows,
      columns: columns?.call(SlideGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SlideGroup]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SlideGroup> updateRow(
    _isd.DatabaseSession session,
    SlideGroup row, {
    _isd.ColumnSelections<SlideGroupTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SlideGroup>(
      row,
      columns: columns?.call(SlideGroup.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SlideGroup] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SlideGroup?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SlideGroupUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SlideGroup>(
      id,
      columnValues: columnValues(SlideGroup.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SlideGroup]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideGroup>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SlideGroupUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<SlideGroupTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideGroupTable>? orderBy,
    _isd.OrderByListBuilder<SlideGroupTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SlideGroup>(
      columnValues: columnValues(SlideGroup.t.updateTable),
      where: where(SlideGroup.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideGroup.t),
      orderByList: orderByList?.call(SlideGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SlideGroup]s in the list and returns the deleted rows.
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
  Future<List<SlideGroup>> delete(
    _isd.DatabaseSession session,
    List<SlideGroup> rows, {
    _isd.OrderByBuilder<SlideGroupTable>? orderBy,
    _isd.OrderByListBuilder<SlideGroupTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SlideGroup>(
      rows,
      orderBy: orderBy?.call(SlideGroup.t),
      orderByList: orderByList?.call(SlideGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SlideGroup].
  Future<SlideGroup> deleteRow(
    _isd.DatabaseSession session,
    SlideGroup row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SlideGroup>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideGroup>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideGroupTable> where,
    _isd.OrderByBuilder<SlideGroupTable>? orderBy,
    _isd.OrderByListBuilder<SlideGroupTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SlideGroup>(
      where: where(SlideGroup.t),
      orderBy: orderBy?.call(SlideGroup.t),
      orderByList: orderByList?.call(SlideGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideGroupTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SlideGroup>(
      where: where?.call(SlideGroup.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SlideGroup] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideGroupTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SlideGroup>(
      where: where(SlideGroup.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SlideGroupAttachRowRepository {
  const SlideGroupAttachRowRepository._();

  /// Creates a relation between the given [SlideGroup] and [Deck]
  /// by setting the [SlideGroup]'s foreign key `deckId` to refer to the [Deck].
  Future<void> deck(
    _isd.DatabaseSession session,
    SlideGroup slideGroup,
    _i810rwvy.Deck deck, {
    _isd.Transaction? transaction,
  }) async {
    if (slideGroup.id == null) {
      throw ArgumentError.notNull('slideGroup.id');
    }
    if (deck.id == null) {
      throw ArgumentError.notNull('deck.id');
    }

    var $slideGroup = slideGroup.copyWith(deckId: deck.id);
    await session.db.updateRow<SlideGroup>(
      $slideGroup,
      columns: [SlideGroup.t.deckId],
      transaction: transaction,
    );
  }
}
