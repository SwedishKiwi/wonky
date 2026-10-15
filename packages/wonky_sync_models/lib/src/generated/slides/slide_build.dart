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

/// One animation step on a slide (Slides 02 §3.7; behavior and effect
/// catalog: 06).
abstract class SlideBuild
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  SlideBuild._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.slideId,
    this.slide,
    required this.elementId,
    this.element,
    required this.kind,
    required this.effect,
    required this.sortKey,
    required this.trigger,
    int? delayMs,
    required this.durationMs,
    required this.easing,
    this.optionsJson,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       delayMs = delayMs ?? 0,
       createdAt = createdAt ?? DateTime.now();

  factory SlideBuild({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue slideId,
    _i810rwvy.Slide? slide,
    required _iss.UuidValue elementId,
    _i810rwvy.SlideElement? element,
    required _i810rwvy.BuildKind kind,
    required String effect,
    required String sortKey,
    required _i810rwvy.BuildTrigger trigger,
    int? delayMs,
    required int durationMs,
    required String easing,
    String? optionsJson,
    DateTime? createdAt,
  }) = _SlideBuildImpl;

  factory SlideBuild.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlideBuild(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      slideId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['slideId'],
      ),
      slide: jsonSerialization['slide'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.Slide>(
              jsonSerialization['slide'],
            ),
      elementId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['elementId'],
      ),
      element: jsonSerialization['element'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.SlideElement>(
              jsonSerialization['element'],
            ),
      kind: _i810rwvy.BuildKind.fromJson((jsonSerialization['kind'] as String)),
      effect: jsonSerialization['effect'] as String,
      sortKey: jsonSerialization['sortKey'] as String,
      trigger: _i810rwvy.BuildTrigger.fromJson(
        (jsonSerialization['trigger'] as String),
      ),
      delayMs: jsonSerialization['delayMs'] as int?,
      durationMs: jsonSerialization['durationMs'] as int,
      easing: jsonSerialization['easing'] as String,
      optionsJson: jsonSerialization['optionsJson'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = SlideBuildTable();

  static const db = SlideBuildRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue slideId;

  _i810rwvy.Slide? slide;

  _iss.UuidValue elementId;

  /// Always set (nullable only by the FK convention).
  _i810rwvy.SlideElement? element;

  _i810rwvy.BuildKind kind;

  /// Effect key, e.g. "fade", "moveIn", "typewriter", "codeHighlight" (06).
  String effect;

  /// Order on the slide.
  String sortKey;

  _i810rwvy.BuildTrigger trigger;

  int delayMs;

  int durationMs;

  /// Easing expression (06 §4.3): "easeOut", "cubic(0.2,0,0,1)", "spring(0.5,0.25)".
  String easing;

  /// Direction, delivery, motion path, step refs ... (06 §2.2, 07, 08).
  String? optionsJson;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [SlideBuild]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  SlideBuild copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? slideId,
    _i810rwvy.Slide? slide = const _UndefinedSlideBuild$slide(),
    _iss.UuidValue? elementId,
    _i810rwvy.SlideElement? element = const _UndefinedSlideBuild$element(),
    _i810rwvy.BuildKind? kind,
    String? effect,
    String? sortKey,
    _i810rwvy.BuildTrigger? trigger,
    int? delayMs,
    int? durationMs,
    String? easing,
    String? optionsJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlideBuild',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'slideId': slideId.toJson(),
      if (slide != null) 'slide': slide?.toJson(),
      'elementId': elementId.toJson(),
      if (element != null) 'element': element?.toJson(),
      'kind': kind.toJson(),
      'effect': effect,
      'sortKey': sortKey,
      'trigger': trigger.toJson(),
      'delayMs': delayMs,
      'durationMs': durationMs,
      'easing': easing,
      if (optionsJson != null) 'optionsJson': optionsJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlideBuild',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'slideId': slideId.toJson(),
      if (slide != null) 'slide': slide?.toJsonForProtocol(),
      'elementId': elementId.toJson(),
      if (element != null) 'element': element?.toJsonForProtocol(),
      'kind': kind.toJson(),
      'effect': effect,
      'sortKey': sortKey,
      'trigger': trigger.toJson(),
      'delayMs': delayMs,
      'durationMs': durationMs,
      'easing': easing,
      if (optionsJson != null) 'optionsJson': optionsJson,
      'createdAt': createdAt.toJson(),
    };
  }

  static SlideBuildInclude include({
    _i810rwvy.SlideInclude? slide,
    _i810rwvy.SlideElementInclude? element,
  }) {
    return SlideBuildInclude._(slide: slide, element: element);
  }

  static SlideBuildIncludeList includeList({
    _isd.WhereExpressionBuilder<SlideBuildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideBuildTable>? orderBy,
    _isd.OrderByListBuilder<SlideBuildTable>? orderByList,
    SlideBuildInclude? include,
  }) {
    return SlideBuildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideBuild.t),
      orderByList: orderByList?.call(SlideBuild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedSlideBuild$slide extends _iss.UndefinedSentinel
    implements _i810rwvy.Slide {
  const _UndefinedSlideBuild$slide();
}

class _UndefinedSlideBuild$element extends _iss.UndefinedSentinel
    implements _i810rwvy.SlideElement {
  const _UndefinedSlideBuild$element();
}

class _SlideBuildImpl extends SlideBuild {
  _SlideBuildImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue slideId,
    _i810rwvy.Slide? slide,
    required _iss.UuidValue elementId,
    _i810rwvy.SlideElement? element,
    required _i810rwvy.BuildKind kind,
    required String effect,
    required String sortKey,
    required _i810rwvy.BuildTrigger trigger,
    int? delayMs,
    required int durationMs,
    required String easing,
    String? optionsJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         slideId: slideId,
         slide: slide,
         elementId: elementId,
         element: element,
         kind: kind,
         effect: effect,
         sortKey: sortKey,
         trigger: trigger,
         delayMs: delayMs,
         durationMs: durationMs,
         easing: easing,
         optionsJson: optionsJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SlideBuild]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  SlideBuild copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? slideId,
    _i810rwvy.Slide? slide = const _UndefinedSlideBuild$slide(),
    _iss.UuidValue? elementId,
    _i810rwvy.SlideElement? element = const _UndefinedSlideBuild$element(),
    _i810rwvy.BuildKind? kind,
    String? effect,
    String? sortKey,
    _i810rwvy.BuildTrigger? trigger,
    int? delayMs,
    int? durationMs,
    String? easing,
    Object? optionsJson = _Undefined,
    DateTime? createdAt,
  }) {
    return SlideBuild(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      slideId: slideId ?? this.slideId,
      slide: slide is _iss.UndefinedSentinel ? this.slide?.copyWith() : slide,
      elementId: elementId ?? this.elementId,
      element: element is _iss.UndefinedSentinel
          ? this.element?.copyWith()
          : element,
      kind: kind ?? this.kind,
      effect: effect ?? this.effect,
      sortKey: sortKey ?? this.sortKey,
      trigger: trigger ?? this.trigger,
      delayMs: delayMs ?? this.delayMs,
      durationMs: durationMs ?? this.durationMs,
      easing: easing ?? this.easing,
      optionsJson: optionsJson is String? ? optionsJson : this.optionsJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SlideBuildUpdateTable extends _isd.UpdateTable<SlideBuildTable> {
  SlideBuildUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> slideId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.slideId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> elementId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.elementId, value);

  _isd.ColumnValue<_i810rwvy.BuildKind, _i810rwvy.BuildKind> kind(
    _i810rwvy.BuildKind value,
  ) => _isd.ColumnValue(table.kind, value);

  _isd.ColumnValue<String, String> effect(String value) =>
      _isd.ColumnValue(table.effect, value);

  _isd.ColumnValue<String, String> sortKey(String value) =>
      _isd.ColumnValue(table.sortKey, value);

  _isd.ColumnValue<_i810rwvy.BuildTrigger, _i810rwvy.BuildTrigger> trigger(
    _i810rwvy.BuildTrigger value,
  ) => _isd.ColumnValue(table.trigger, value);

  _isd.ColumnValue<int, int> delayMs(int value) =>
      _isd.ColumnValue(table.delayMs, value);

  _isd.ColumnValue<int, int> durationMs(int value) =>
      _isd.ColumnValue(table.durationMs, value);

  _isd.ColumnValue<String, String> easing(String value) =>
      _isd.ColumnValue(table.easing, value);

  _isd.ColumnValue<String, String> optionsJson(String? value) =>
      _isd.ColumnValue(table.optionsJson, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class SlideBuildTable extends _isd.Table<_iss.UuidValue> {
  SlideBuildTable({super.tableRelation}) : super(tableName: 'slide_build') {
    updateTable = SlideBuildUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    slideId = _isd.ColumnUuid('slideId', this);
    elementId = _isd.ColumnUuid('elementId', this);
    kind = _isd.ColumnEnum('kind', this, _isd.EnumSerialization.byName);
    effect = _isd.ColumnString('effect', this);
    sortKey = _isd.ColumnString('sortKey', this);
    trigger = _isd.ColumnEnum('trigger', this, _isd.EnumSerialization.byName);
    delayMs = _isd.ColumnInt('delayMs', this, hasDefault: true);
    durationMs = _isd.ColumnInt('durationMs', this);
    easing = _isd.ColumnString('easing', this);
    optionsJson = _isd.ColumnString('optionsJson', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final SlideBuildUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid slideId;

  _i810rwvy.SlideTable? _slide;

  late final _isd.ColumnUuid elementId;

  /// Always set (nullable only by the FK convention).
  _i810rwvy.SlideElementTable? _element;

  late final _isd.ColumnEnum<_i810rwvy.BuildKind> kind;

  /// Effect key, e.g. "fade", "moveIn", "typewriter", "codeHighlight" (06).
  late final _isd.ColumnString effect;

  /// Order on the slide.
  late final _isd.ColumnString sortKey;

  late final _isd.ColumnEnum<_i810rwvy.BuildTrigger> trigger;

  late final _isd.ColumnInt delayMs;

  late final _isd.ColumnInt durationMs;

  /// Easing expression (06 §4.3): "easeOut", "cubic(0.2,0,0,1)", "spring(0.5,0.25)".
  late final _isd.ColumnString easing;

  /// Direction, delivery, motion path, step refs ... (06 §2.2, 07, 08).
  late final _isd.ColumnString optionsJson;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SlideTable get slide {
    if (_slide != null) return _slide!;
    _slide = _isd.createRelationTable(
      relationFieldName: 'slide',
      field: SlideBuild.t.slideId,
      foreignField: _i810rwvy.Slide.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SlideTable(tableRelation: foreignTableRelation),
    );
    return _slide!;
  }

  _i810rwvy.SlideElementTable get element {
    if (_element != null) return _element!;
    _element = _isd.createRelationTable(
      relationFieldName: 'element',
      field: SlideBuild.t.elementId,
      foreignField: _i810rwvy.SlideElement.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SlideElementTable(tableRelation: foreignTableRelation),
    );
    return _element!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    slideId,
    elementId,
    kind,
    effect,
    sortKey,
    trigger,
    delayMs,
    durationMs,
    easing,
    optionsJson,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'slide') {
      return slide;
    }
    if (relationField == 'element') {
      return element;
    }
    return null;
  }
}

class SlideBuildInclude extends _isd.IncludeObject {
  SlideBuildInclude._({
    _i810rwvy.SlideInclude? slide,
    _i810rwvy.SlideElementInclude? element,
  }) {
    _slide = slide;
    _element = element;
  }

  _i810rwvy.SlideInclude? _slide;

  _i810rwvy.SlideElementInclude? _element;

  @override
  Map<String, _isd.Include?> get includes => {
    'slide': _slide,
    'element': _element,
  };

  @override
  _isd.Table<_iss.UuidValue> get table => SlideBuild.t;
}

class SlideBuildIncludeList extends _isd.IncludeList {
  SlideBuildIncludeList._({
    _isd.WhereExpressionBuilder<SlideBuildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SlideBuild.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => SlideBuild.t;
}

class SlideBuildRepository {
  const SlideBuildRepository._();

  final attachRow = const SlideBuildAttachRowRepository._();

  /// Returns a list of [SlideBuild]s matching the given query parameters.
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
  Future<List<SlideBuild>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideBuildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideBuildTable>? orderBy,
    _isd.OrderByListBuilder<SlideBuildTable>? orderByList,
    _isd.Transaction? transaction,
    SlideBuildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SlideBuild>(
      where: where?.call(SlideBuild.t),
      orderBy: orderBy?.call(SlideBuild.t),
      orderByList: orderByList?.call(SlideBuild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SlideBuild]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SlideBuild.t`.
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
  _ida.Stream<List<SlideBuild>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideBuildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideBuildTable>? orderBy,
    _isd.OrderByListBuilder<SlideBuildTable>? orderByList,
    SlideBuildInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SlideBuild>(
      where: where?.call(SlideBuild.t),
      orderBy: orderBy?.call(SlideBuild.t),
      orderByList: orderByList?.call(SlideBuild.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SlideBuild] matching the given query parameters.
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
  Future<SlideBuild?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideBuildTable>? where,
    int? offset,
    _isd.OrderByBuilder<SlideBuildTable>? orderBy,
    _isd.OrderByListBuilder<SlideBuildTable>? orderByList,
    _isd.Transaction? transaction,
    SlideBuildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SlideBuild>(
      where: where?.call(SlideBuild.t),
      orderBy: orderBy?.call(SlideBuild.t),
      orderByList: orderByList?.call(SlideBuild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SlideBuild] by its [id] or null if no such row exists.
  Future<SlideBuild?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SlideBuildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SlideBuild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SlideBuild]s in the list and returns the inserted rows.
  ///
  /// The returned [SlideBuild]s will have their `id` fields set.
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
  Future<List<SlideBuild>> insert(
    _isd.DatabaseSession session,
    List<SlideBuild> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SlideBuild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SlideBuild] and returns the inserted row.
  ///
  /// The returned [SlideBuild] will have its `id` field set.
  Future<SlideBuild> insertRow(
    _isd.DatabaseSession session,
    SlideBuild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SlideBuild>(row, transaction: transaction);
  }

  /// Upserts all [SlideBuild]s in the list and returns the resulting rows.
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
  /// The returned [SlideBuild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideBuild>> upsert(
    _isd.DatabaseSession session,
    List<SlideBuild> rows, {
    required _isd.ColumnSelections<SlideBuildTable> conflictColumns,
    _isd.ColumnSelections<SlideBuildTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideBuildTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SlideBuild>(
      rows,
      conflictColumns: conflictColumns(SlideBuild.t),
      updateColumns: updateColumns?.call(SlideBuild.t),
      updateWhere: updateWhere?.call(SlideBuild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SlideBuild] and returns the resulting row.
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
  /// The returned [SlideBuild] will have its `id` field set.
  Future<SlideBuild?> upsertRow(
    _isd.DatabaseSession session,
    SlideBuild row, {
    required _isd.ColumnSelections<SlideBuildTable> conflictColumns,
    _isd.ColumnSelections<SlideBuildTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideBuildTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SlideBuild>(
      row,
      conflictColumns: conflictColumns(SlideBuild.t),
      updateColumns: updateColumns?.call(SlideBuild.t),
      updateWhere: updateWhere?.call(SlideBuild.t),
      transaction: transaction,
    );
  }

  /// Updates all [SlideBuild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideBuild>> update(
    _isd.DatabaseSession session,
    List<SlideBuild> rows, {
    _isd.ColumnSelections<SlideBuildTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SlideBuild>(
      rows,
      columns: columns?.call(SlideBuild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SlideBuild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SlideBuild> updateRow(
    _isd.DatabaseSession session,
    SlideBuild row, {
    _isd.ColumnSelections<SlideBuildTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SlideBuild>(
      row,
      columns: columns?.call(SlideBuild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SlideBuild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SlideBuild?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SlideBuildUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SlideBuild>(
      id,
      columnValues: columnValues(SlideBuild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SlideBuild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideBuild>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SlideBuildUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<SlideBuildTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideBuildTable>? orderBy,
    _isd.OrderByListBuilder<SlideBuildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SlideBuild>(
      columnValues: columnValues(SlideBuild.t.updateTable),
      where: where(SlideBuild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideBuild.t),
      orderByList: orderByList?.call(SlideBuild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SlideBuild]s in the list and returns the deleted rows.
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
  Future<List<SlideBuild>> delete(
    _isd.DatabaseSession session,
    List<SlideBuild> rows, {
    _isd.OrderByBuilder<SlideBuildTable>? orderBy,
    _isd.OrderByListBuilder<SlideBuildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SlideBuild>(
      rows,
      orderBy: orderBy?.call(SlideBuild.t),
      orderByList: orderByList?.call(SlideBuild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SlideBuild].
  Future<SlideBuild> deleteRow(
    _isd.DatabaseSession session,
    SlideBuild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SlideBuild>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideBuild>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideBuildTable> where,
    _isd.OrderByBuilder<SlideBuildTable>? orderBy,
    _isd.OrderByListBuilder<SlideBuildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SlideBuild>(
      where: where(SlideBuild.t),
      orderBy: orderBy?.call(SlideBuild.t),
      orderByList: orderByList?.call(SlideBuild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideBuildTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SlideBuild>(
      where: where?.call(SlideBuild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SlideBuild] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideBuildTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SlideBuild>(
      where: where(SlideBuild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SlideBuildAttachRowRepository {
  const SlideBuildAttachRowRepository._();

  /// Creates a relation between the given [SlideBuild] and [Slide]
  /// by setting the [SlideBuild]'s foreign key `slideId` to refer to the [Slide].
  Future<void> slide(
    _isd.DatabaseSession session,
    SlideBuild slideBuild,
    _i810rwvy.Slide slide, {
    _isd.Transaction? transaction,
  }) async {
    if (slideBuild.id == null) {
      throw ArgumentError.notNull('slideBuild.id');
    }
    if (slide.id == null) {
      throw ArgumentError.notNull('slide.id');
    }

    var $slideBuild = slideBuild.copyWith(slideId: slide.id);
    await session.db.updateRow<SlideBuild>(
      $slideBuild,
      columns: [SlideBuild.t.slideId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [SlideBuild] and [SlideElement]
  /// by setting the [SlideBuild]'s foreign key `elementId` to refer to the [SlideElement].
  Future<void> element(
    _isd.DatabaseSession session,
    SlideBuild slideBuild,
    _i810rwvy.SlideElement element, {
    _isd.Transaction? transaction,
  }) async {
    if (slideBuild.id == null) {
      throw ArgumentError.notNull('slideBuild.id');
    }
    if (element.id == null) {
      throw ArgumentError.notNull('element.id');
    }

    var $slideBuild = slideBuild.copyWith(elementId: element.id);
    await session.db.updateRow<SlideBuild>(
      $slideBuild,
      columns: [SlideBuild.t.elementId],
      transaction: transaction,
    );
  }
}
