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

/// A slide (Slides 02 §3.3). Its position is (groupId, sortKey), always
/// written together (P4, 02 §3.4).
abstract class Slide
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  Slide._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.deckId,
    this.deck,
    required this.sortKey,
    this.groupId,
    this.layoutId,
    this.backgroundJson,
    bool? skipped,
    this.notes,
    this.transitionJson,
    this.hideMasterElements,
    this.timingsJson,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       skipped = skipped ?? false,
       createdAt = createdAt ?? DateTime.now();

  factory Slide({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue deckId,
    _i810rwvy.Deck? deck,
    required String sortKey,
    _iss.UuidValue? groupId,
    _iss.UuidValue? layoutId,
    String? backgroundJson,
    bool? skipped,
    String? notes,
    String? transitionJson,
    bool? hideMasterElements,
    String? timingsJson,
    DateTime? createdAt,
  }) = _SlideImpl;

  factory Slide.fromJson(Map<String, dynamic> jsonSerialization) {
    return Slide(
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
      sortKey: jsonSerialization['sortKey'] as String,
      groupId: jsonSerialization['groupId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['groupId']),
      layoutId: jsonSerialization['layoutId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['layoutId']),
      backgroundJson: jsonSerialization['backgroundJson'] as String?,
      skipped: jsonSerialization['skipped'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['skipped']),
      notes: jsonSerialization['notes'] as String?,
      transitionJson: jsonSerialization['transitionJson'] as String?,
      hideMasterElements: jsonSerialization['hideMasterElements'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(
              jsonSerialization['hideMasterElements'],
            ),
      timingsJson: jsonSerialization['timingsJson'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = SlideTable();

  static const db = SlideRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue deckId;

  _i810rwvy.Deck? deck;

  /// Fractional index in the top-level key space (groupId null) or the
  /// group's key space. Always written together with groupId (P4).
  String sortKey;

  /// SlideGroup id (plain UUID, no FK, 02 §3.4); null = top level.
  _iss.UuidValue? groupId;

  /// SlideLayout id (plain UUID); null/missing = fallback (02 §10).
  _iss.UuidValue? layoutId;

  /// null = layout > master > theme.
  String? backgroundJson;

  /// Not shown when presenting / exported unless included (10 §2.2).
  bool skipped;

  /// Speaker notes, Delta (02 §4.3); null = empty.
  String? notes;

  /// Transition into this slide (06 §7.1); null = deck default.
  String? transitionJson;

  /// null = the layout's setting.
  bool? hideMasterElements;

  /// Rehearsed timings (10 A-10-2): {v, stepsMs, totalMs, rehearsedAt, by}.
  String? timingsJson;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [Slide]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  Slide copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? deckId,
    _i810rwvy.Deck? deck = const _UndefinedSlide$deck(),
    String? sortKey,
    _iss.UuidValue? groupId = const _iss.$UndefinedUuidValue(),
    _iss.UuidValue? layoutId = const _iss.$UndefinedUuidValue(),
    String? backgroundJson,
    bool? skipped,
    String? notes,
    String? transitionJson,
    bool? hideMasterElements,
    String? timingsJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Slide',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'deckId': deckId.toJson(),
      if (deck != null) 'deck': deck?.toJson(),
      'sortKey': sortKey,
      if (groupId != null) 'groupId': groupId?.toJson(),
      if (layoutId != null) 'layoutId': layoutId?.toJson(),
      if (backgroundJson != null) 'backgroundJson': backgroundJson,
      'skipped': skipped,
      if (notes != null) 'notes': notes,
      if (transitionJson != null) 'transitionJson': transitionJson,
      if (hideMasterElements != null) 'hideMasterElements': hideMasterElements,
      if (timingsJson != null) 'timingsJson': timingsJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Slide',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'deckId': deckId.toJson(),
      if (deck != null) 'deck': deck?.toJsonForProtocol(),
      'sortKey': sortKey,
      if (groupId != null) 'groupId': groupId?.toJson(),
      if (layoutId != null) 'layoutId': layoutId?.toJson(),
      if (backgroundJson != null) 'backgroundJson': backgroundJson,
      'skipped': skipped,
      if (notes != null) 'notes': notes,
      if (transitionJson != null) 'transitionJson': transitionJson,
      if (hideMasterElements != null) 'hideMasterElements': hideMasterElements,
      if (timingsJson != null) 'timingsJson': timingsJson,
      'createdAt': createdAt.toJson(),
    };
  }

  static SlideInclude include({_i810rwvy.DeckInclude? deck}) {
    return SlideInclude._(deck: deck);
  }

  static SlideIncludeList includeList({
    _isd.WhereExpressionBuilder<SlideTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTable>? orderBy,
    _isd.OrderByListBuilder<SlideTable>? orderByList,
    SlideInclude? include,
  }) {
    return SlideIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Slide.t),
      orderByList: orderByList?.call(Slide.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedSlide$deck extends _iss.UndefinedSentinel
    implements _i810rwvy.Deck {
  const _UndefinedSlide$deck();
}

class _SlideImpl extends Slide {
  _SlideImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue deckId,
    _i810rwvy.Deck? deck,
    required String sortKey,
    _iss.UuidValue? groupId,
    _iss.UuidValue? layoutId,
    String? backgroundJson,
    bool? skipped,
    String? notes,
    String? transitionJson,
    bool? hideMasterElements,
    String? timingsJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         deckId: deckId,
         deck: deck,
         sortKey: sortKey,
         groupId: groupId,
         layoutId: layoutId,
         backgroundJson: backgroundJson,
         skipped: skipped,
         notes: notes,
         transitionJson: transitionJson,
         hideMasterElements: hideMasterElements,
         timingsJson: timingsJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Slide]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  Slide copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? deckId,
    _i810rwvy.Deck? deck = const _UndefinedSlide$deck(),
    String? sortKey,
    _iss.UuidValue? groupId = const _iss.$UndefinedUuidValue(),
    _iss.UuidValue? layoutId = const _iss.$UndefinedUuidValue(),
    Object? backgroundJson = _Undefined,
    bool? skipped,
    Object? notes = _Undefined,
    Object? transitionJson = _Undefined,
    Object? hideMasterElements = _Undefined,
    Object? timingsJson = _Undefined,
    DateTime? createdAt,
  }) {
    return Slide(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      deckId: deckId ?? this.deckId,
      deck: deck is _iss.UndefinedSentinel ? this.deck?.copyWith() : deck,
      sortKey: sortKey ?? this.sortKey,
      groupId: groupId is _iss.UndefinedSentinel ? this.groupId : groupId,
      layoutId: layoutId is _iss.UndefinedSentinel ? this.layoutId : layoutId,
      backgroundJson: backgroundJson is String?
          ? backgroundJson
          : this.backgroundJson,
      skipped: skipped ?? this.skipped,
      notes: notes is String? ? notes : this.notes,
      transitionJson: transitionJson is String?
          ? transitionJson
          : this.transitionJson,
      hideMasterElements: hideMasterElements is bool?
          ? hideMasterElements
          : this.hideMasterElements,
      timingsJson: timingsJson is String? ? timingsJson : this.timingsJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SlideUpdateTable extends _isd.UpdateTable<SlideTable> {
  SlideUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> deckId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.deckId, value);

  _isd.ColumnValue<String, String> sortKey(String value) =>
      _isd.ColumnValue(table.sortKey, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> groupId(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.groupId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> layoutId(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.layoutId, value);

  _isd.ColumnValue<String, String> backgroundJson(String? value) =>
      _isd.ColumnValue(table.backgroundJson, value);

  _isd.ColumnValue<bool, bool> skipped(bool value) =>
      _isd.ColumnValue(table.skipped, value);

  _isd.ColumnValue<String, String> notes(String? value) =>
      _isd.ColumnValue(table.notes, value);

  _isd.ColumnValue<String, String> transitionJson(String? value) =>
      _isd.ColumnValue(table.transitionJson, value);

  _isd.ColumnValue<bool, bool> hideMasterElements(bool? value) =>
      _isd.ColumnValue(table.hideMasterElements, value);

  _isd.ColumnValue<String, String> timingsJson(String? value) =>
      _isd.ColumnValue(table.timingsJson, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class SlideTable extends _isd.Table<_iss.UuidValue> {
  SlideTable({super.tableRelation}) : super(tableName: 'slide') {
    updateTable = SlideUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    deckId = _isd.ColumnUuid('deckId', this);
    sortKey = _isd.ColumnString('sortKey', this);
    groupId = _isd.ColumnUuid('groupId', this);
    layoutId = _isd.ColumnUuid('layoutId', this);
    backgroundJson = _isd.ColumnString('backgroundJson', this);
    skipped = _isd.ColumnBool('skipped', this, hasDefault: true);
    notes = _isd.ColumnString('notes', this);
    transitionJson = _isd.ColumnString('transitionJson', this);
    hideMasterElements = _isd.ColumnBool('hideMasterElements', this);
    timingsJson = _isd.ColumnString('timingsJson', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final SlideUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid deckId;

  _i810rwvy.DeckTable? _deck;

  /// Fractional index in the top-level key space (groupId null) or the
  /// group's key space. Always written together with groupId (P4).
  late final _isd.ColumnString sortKey;

  /// SlideGroup id (plain UUID, no FK, 02 §3.4); null = top level.
  late final _isd.ColumnUuid groupId;

  /// SlideLayout id (plain UUID); null/missing = fallback (02 §10).
  late final _isd.ColumnUuid layoutId;

  /// null = layout > master > theme.
  late final _isd.ColumnString backgroundJson;

  /// Not shown when presenting / exported unless included (10 §2.2).
  late final _isd.ColumnBool skipped;

  /// Speaker notes, Delta (02 §4.3); null = empty.
  late final _isd.ColumnString notes;

  /// Transition into this slide (06 §7.1); null = deck default.
  late final _isd.ColumnString transitionJson;

  /// null = the layout's setting.
  late final _isd.ColumnBool hideMasterElements;

  /// Rehearsed timings (10 A-10-2): {v, stepsMs, totalMs, rehearsedAt, by}.
  late final _isd.ColumnString timingsJson;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.DeckTable get deck {
    if (_deck != null) return _deck!;
    _deck = _isd.createRelationTable(
      relationFieldName: 'deck',
      field: Slide.t.deckId,
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
    sortKey,
    groupId,
    layoutId,
    backgroundJson,
    skipped,
    notes,
    transitionJson,
    hideMasterElements,
    timingsJson,
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

class SlideInclude extends _isd.IncludeObject {
  SlideInclude._({_i810rwvy.DeckInclude? deck}) {
    _deck = deck;
  }

  _i810rwvy.DeckInclude? _deck;

  @override
  Map<String, _isd.Include?> get includes => {'deck': _deck};

  @override
  _isd.Table<_iss.UuidValue> get table => Slide.t;
}

class SlideIncludeList extends _isd.IncludeList {
  SlideIncludeList._({
    _isd.WhereExpressionBuilder<SlideTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Slide.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => Slide.t;
}

class SlideRepository {
  const SlideRepository._();

  final attachRow = const SlideAttachRowRepository._();

  /// Returns a list of [Slide]s matching the given query parameters.
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
  Future<List<Slide>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTable>? orderBy,
    _isd.OrderByListBuilder<SlideTable>? orderByList,
    _isd.Transaction? transaction,
    SlideInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Slide>(
      where: where?.call(Slide.t),
      orderBy: orderBy?.call(Slide.t),
      orderByList: orderByList?.call(Slide.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Slide]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Slide.t`.
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
  _ida.Stream<List<Slide>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTable>? orderBy,
    _isd.OrderByListBuilder<SlideTable>? orderByList,
    SlideInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Slide>(
      where: where?.call(Slide.t),
      orderBy: orderBy?.call(Slide.t),
      orderByList: orderByList?.call(Slide.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Slide] matching the given query parameters.
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
  Future<Slide?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTable>? where,
    int? offset,
    _isd.OrderByBuilder<SlideTable>? orderBy,
    _isd.OrderByListBuilder<SlideTable>? orderByList,
    _isd.Transaction? transaction,
    SlideInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Slide>(
      where: where?.call(Slide.t),
      orderBy: orderBy?.call(Slide.t),
      orderByList: orderByList?.call(Slide.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Slide] by its [id] or null if no such row exists.
  Future<Slide?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SlideInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Slide>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Slide]s in the list and returns the inserted rows.
  ///
  /// The returned [Slide]s will have their `id` fields set.
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
  Future<List<Slide>> insert(
    _isd.DatabaseSession session,
    List<Slide> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Slide>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Slide] and returns the inserted row.
  ///
  /// The returned [Slide] will have its `id` field set.
  Future<Slide> insertRow(
    _isd.DatabaseSession session,
    Slide row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<Slide>(row, transaction: transaction);
  }

  /// Upserts all [Slide]s in the list and returns the resulting rows.
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
  /// The returned [Slide]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Slide>> upsert(
    _isd.DatabaseSession session,
    List<Slide> rows, {
    required _isd.ColumnSelections<SlideTable> conflictColumns,
    _isd.ColumnSelections<SlideTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Slide>(
      rows,
      conflictColumns: conflictColumns(Slide.t),
      updateColumns: updateColumns?.call(Slide.t),
      updateWhere: updateWhere?.call(Slide.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Slide] and returns the resulting row.
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
  /// The returned [Slide] will have its `id` field set.
  Future<Slide?> upsertRow(
    _isd.DatabaseSession session,
    Slide row, {
    required _isd.ColumnSelections<SlideTable> conflictColumns,
    _isd.ColumnSelections<SlideTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Slide>(
      row,
      conflictColumns: conflictColumns(Slide.t),
      updateColumns: updateColumns?.call(Slide.t),
      updateWhere: updateWhere?.call(Slide.t),
      transaction: transaction,
    );
  }

  /// Updates all [Slide]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Slide>> update(
    _isd.DatabaseSession session,
    List<Slide> rows, {
    _isd.ColumnSelections<SlideTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Slide>(
      rows,
      columns: columns?.call(Slide.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Slide]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Slide> updateRow(
    _isd.DatabaseSession session,
    Slide row, {
    _isd.ColumnSelections<SlideTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<Slide>(
      row,
      columns: columns?.call(Slide.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Slide] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Slide?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SlideUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<Slide>(
      id,
      columnValues: columnValues(Slide.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Slide]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Slide>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SlideUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<SlideTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTable>? orderBy,
    _isd.OrderByListBuilder<SlideTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Slide>(
      columnValues: columnValues(Slide.t.updateTable),
      where: where(Slide.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Slide.t),
      orderByList: orderByList?.call(Slide.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Slide]s in the list and returns the deleted rows.
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
  Future<List<Slide>> delete(
    _isd.DatabaseSession session,
    List<Slide> rows, {
    _isd.OrderByBuilder<SlideTable>? orderBy,
    _isd.OrderByListBuilder<SlideTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Slide>(
      rows,
      orderBy: orderBy?.call(Slide.t),
      orderByList: orderByList?.call(Slide.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Slide].
  Future<Slide> deleteRow(
    _isd.DatabaseSession session,
    Slide row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Slide>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Slide>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideTable> where,
    _isd.OrderByBuilder<SlideTable>? orderBy,
    _isd.OrderByListBuilder<SlideTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Slide>(
      where: where(Slide.t),
      orderBy: orderBy?.call(Slide.t),
      orderByList: orderByList?.call(Slide.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<Slide>(
      where: where?.call(Slide.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Slide] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Slide>(
      where: where(Slide.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SlideAttachRowRepository {
  const SlideAttachRowRepository._();

  /// Creates a relation between the given [Slide] and [Deck]
  /// by setting the [Slide]'s foreign key `deckId` to refer to the [Deck].
  Future<void> deck(
    _isd.DatabaseSession session,
    Slide slide,
    _i810rwvy.Deck deck, {
    _isd.Transaction? transaction,
  }) async {
    if (slide.id == null) {
      throw ArgumentError.notNull('slide.id');
    }
    if (deck.id == null) {
      throw ArgumentError.notNull('deck.id');
    }

    var $slide = slide.copyWith(deckId: deck.id);
    await session.db.updateRow<Slide>(
      $slide,
      columns: [Slide.t.deckId],
      transaction: transaction,
    );
  }
}
