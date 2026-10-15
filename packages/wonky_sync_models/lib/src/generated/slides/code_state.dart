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

/// One version of a code element's source (Slides 02 §3.8, 07 §3.2). Every
/// state, including the first, is a row; a code element has at least one.
abstract class CodeState
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  CodeState._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.elementId,
    this.element,
    required this.sortKey,
    this.label,
    required this.code,
    this.language,
    this.title,
    this.highlight,
    this.annotationsJson,
    this.transitionJson,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory CodeState({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue elementId,
    _i810rwvy.SlideElement? element,
    required String sortKey,
    String? label,
    required String code,
    String? language,
    String? title,
    String? highlight,
    String? annotationsJson,
    String? transitionJson,
    DateTime? createdAt,
  }) = _CodeStateImpl;

  factory CodeState.fromJson(Map<String, dynamic> jsonSerialization) {
    return CodeState(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      elementId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['elementId'],
      ),
      element: jsonSerialization['element'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.SlideElement>(
              jsonSerialization['element'],
            ),
      sortKey: jsonSerialization['sortKey'] as String,
      label: jsonSerialization['label'] as String?,
      code: jsonSerialization['code'] as String,
      language: jsonSerialization['language'] as String?,
      title: jsonSerialization['title'] as String?,
      highlight: jsonSerialization['highlight'] as String?,
      annotationsJson: jsonSerialization['annotationsJson'] as String?,
      transitionJson: jsonSerialization['transitionJson'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = CodeStateTable();

  static const db = CodeStateRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue elementId;

  /// The code element (kind code).
  _i810rwvy.SlideElement? element;

  String sortKey;

  /// "Add caching".
  String? label;

  /// Full source of this state (whole-value LWW).
  String code;

  /// null = the element's language (07 A-07-2).
  String? language;

  /// null = the element's title.
  String? title;

  /// Line-highlight steps, e.g. "1-3 | 5" (07 §4.1).
  String? highlight;

  /// Per-step callouts (07 §4.4).
  String? annotationsJson;

  /// How this state is reached from the previous one (07 §5.3).
  String? transitionJson;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [CodeState]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  CodeState copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? elementId,
    _i810rwvy.SlideElement? element = const _UndefinedCodeState$element(),
    String? sortKey,
    String? label,
    String? code,
    String? language,
    String? title,
    String? highlight,
    String? annotationsJson,
    String? transitionJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CodeState',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'elementId': elementId.toJson(),
      if (element != null) 'element': element?.toJson(),
      'sortKey': sortKey,
      if (label != null) 'label': label,
      'code': code,
      if (language != null) 'language': language,
      if (title != null) 'title': title,
      if (highlight != null) 'highlight': highlight,
      if (annotationsJson != null) 'annotationsJson': annotationsJson,
      if (transitionJson != null) 'transitionJson': transitionJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CodeState',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'elementId': elementId.toJson(),
      if (element != null) 'element': element?.toJsonForProtocol(),
      'sortKey': sortKey,
      if (label != null) 'label': label,
      'code': code,
      if (language != null) 'language': language,
      if (title != null) 'title': title,
      if (highlight != null) 'highlight': highlight,
      if (annotationsJson != null) 'annotationsJson': annotationsJson,
      if (transitionJson != null) 'transitionJson': transitionJson,
      'createdAt': createdAt.toJson(),
    };
  }

  static CodeStateInclude include({_i810rwvy.SlideElementInclude? element}) {
    return CodeStateInclude._(element: element);
  }

  static CodeStateIncludeList includeList({
    _isd.WhereExpressionBuilder<CodeStateTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CodeStateTable>? orderBy,
    _isd.OrderByListBuilder<CodeStateTable>? orderByList,
    CodeStateInclude? include,
  }) {
    return CodeStateIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CodeState.t),
      orderByList: orderByList?.call(CodeState.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedCodeState$element extends _iss.UndefinedSentinel
    implements _i810rwvy.SlideElement {
  const _UndefinedCodeState$element();
}

class _CodeStateImpl extends CodeState {
  _CodeStateImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue elementId,
    _i810rwvy.SlideElement? element,
    required String sortKey,
    String? label,
    required String code,
    String? language,
    String? title,
    String? highlight,
    String? annotationsJson,
    String? transitionJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         elementId: elementId,
         element: element,
         sortKey: sortKey,
         label: label,
         code: code,
         language: language,
         title: title,
         highlight: highlight,
         annotationsJson: annotationsJson,
         transitionJson: transitionJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [CodeState]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  CodeState copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? elementId,
    _i810rwvy.SlideElement? element = const _UndefinedCodeState$element(),
    String? sortKey,
    Object? label = _Undefined,
    String? code,
    Object? language = _Undefined,
    Object? title = _Undefined,
    Object? highlight = _Undefined,
    Object? annotationsJson = _Undefined,
    Object? transitionJson = _Undefined,
    DateTime? createdAt,
  }) {
    return CodeState(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      elementId: elementId ?? this.elementId,
      element: element is _iss.UndefinedSentinel
          ? this.element?.copyWith()
          : element,
      sortKey: sortKey ?? this.sortKey,
      label: label is String? ? label : this.label,
      code: code ?? this.code,
      language: language is String? ? language : this.language,
      title: title is String? ? title : this.title,
      highlight: highlight is String? ? highlight : this.highlight,
      annotationsJson: annotationsJson is String?
          ? annotationsJson
          : this.annotationsJson,
      transitionJson: transitionJson is String?
          ? transitionJson
          : this.transitionJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CodeStateUpdateTable extends _isd.UpdateTable<CodeStateTable> {
  CodeStateUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> elementId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.elementId, value);

  _isd.ColumnValue<String, String> sortKey(String value) =>
      _isd.ColumnValue(table.sortKey, value);

  _isd.ColumnValue<String, String> label(String? value) =>
      _isd.ColumnValue(table.label, value);

  _isd.ColumnValue<String, String> code(String value) =>
      _isd.ColumnValue(table.code, value);

  _isd.ColumnValue<String, String> language(String? value) =>
      _isd.ColumnValue(table.language, value);

  _isd.ColumnValue<String, String> title(String? value) =>
      _isd.ColumnValue(table.title, value);

  _isd.ColumnValue<String, String> highlight(String? value) =>
      _isd.ColumnValue(table.highlight, value);

  _isd.ColumnValue<String, String> annotationsJson(String? value) =>
      _isd.ColumnValue(table.annotationsJson, value);

  _isd.ColumnValue<String, String> transitionJson(String? value) =>
      _isd.ColumnValue(table.transitionJson, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class CodeStateTable extends _isd.Table<_iss.UuidValue> {
  CodeStateTable({super.tableRelation}) : super(tableName: 'code_state') {
    updateTable = CodeStateUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    elementId = _isd.ColumnUuid('elementId', this);
    sortKey = _isd.ColumnString('sortKey', this);
    label = _isd.ColumnString('label', this);
    code = _isd.ColumnString('code', this);
    language = _isd.ColumnString('language', this);
    title = _isd.ColumnString('title', this);
    highlight = _isd.ColumnString('highlight', this);
    annotationsJson = _isd.ColumnString('annotationsJson', this);
    transitionJson = _isd.ColumnString('transitionJson', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final CodeStateUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid elementId;

  /// The code element (kind code).
  _i810rwvy.SlideElementTable? _element;

  late final _isd.ColumnString sortKey;

  /// "Add caching".
  late final _isd.ColumnString label;

  /// Full source of this state (whole-value LWW).
  late final _isd.ColumnString code;

  /// null = the element's language (07 A-07-2).
  late final _isd.ColumnString language;

  /// null = the element's title.
  late final _isd.ColumnString title;

  /// Line-highlight steps, e.g. "1-3 | 5" (07 §4.1).
  late final _isd.ColumnString highlight;

  /// Per-step callouts (07 §4.4).
  late final _isd.ColumnString annotationsJson;

  /// How this state is reached from the previous one (07 §5.3).
  late final _isd.ColumnString transitionJson;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SlideElementTable get element {
    if (_element != null) return _element!;
    _element = _isd.createRelationTable(
      relationFieldName: 'element',
      field: CodeState.t.elementId,
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
    elementId,
    sortKey,
    label,
    code,
    language,
    title,
    highlight,
    annotationsJson,
    transitionJson,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'element') {
      return element;
    }
    return null;
  }
}

class CodeStateInclude extends _isd.IncludeObject {
  CodeStateInclude._({_i810rwvy.SlideElementInclude? element}) {
    _element = element;
  }

  _i810rwvy.SlideElementInclude? _element;

  @override
  Map<String, _isd.Include?> get includes => {'element': _element};

  @override
  _isd.Table<_iss.UuidValue> get table => CodeState.t;
}

class CodeStateIncludeList extends _isd.IncludeList {
  CodeStateIncludeList._({
    _isd.WhereExpressionBuilder<CodeStateTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CodeState.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => CodeState.t;
}

class CodeStateRepository {
  const CodeStateRepository._();

  final attachRow = const CodeStateAttachRowRepository._();

  /// Returns a list of [CodeState]s matching the given query parameters.
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
  Future<List<CodeState>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CodeStateTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CodeStateTable>? orderBy,
    _isd.OrderByListBuilder<CodeStateTable>? orderByList,
    _isd.Transaction? transaction,
    CodeStateInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CodeState>(
      where: where?.call(CodeState.t),
      orderBy: orderBy?.call(CodeState.t),
      orderByList: orderByList?.call(CodeState.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [CodeState]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `CodeState.t`.
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
  _ida.Stream<List<CodeState>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CodeStateTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CodeStateTable>? orderBy,
    _isd.OrderByListBuilder<CodeStateTable>? orderByList,
    CodeStateInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<CodeState>(
      where: where?.call(CodeState.t),
      orderBy: orderBy?.call(CodeState.t),
      orderByList: orderByList?.call(CodeState.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [CodeState] matching the given query parameters.
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
  Future<CodeState?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CodeStateTable>? where,
    int? offset,
    _isd.OrderByBuilder<CodeStateTable>? orderBy,
    _isd.OrderByListBuilder<CodeStateTable>? orderByList,
    _isd.Transaction? transaction,
    CodeStateInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CodeState>(
      where: where?.call(CodeState.t),
      orderBy: orderBy?.call(CodeState.t),
      orderByList: orderByList?.call(CodeState.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CodeState] by its [id] or null if no such row exists.
  Future<CodeState?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    CodeStateInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CodeState>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CodeState]s in the list and returns the inserted rows.
  ///
  /// The returned [CodeState]s will have their `id` fields set.
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
  Future<List<CodeState>> insert(
    _isd.DatabaseSession session,
    List<CodeState> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CodeState>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CodeState] and returns the inserted row.
  ///
  /// The returned [CodeState] will have its `id` field set.
  Future<CodeState> insertRow(
    _isd.DatabaseSession session,
    CodeState row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<CodeState>(row, transaction: transaction);
  }

  /// Upserts all [CodeState]s in the list and returns the resulting rows.
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
  /// The returned [CodeState]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CodeState>> upsert(
    _isd.DatabaseSession session,
    List<CodeState> rows, {
    required _isd.ColumnSelections<CodeStateTable> conflictColumns,
    _isd.ColumnSelections<CodeStateTable>? updateColumns,
    _isd.WhereExpressionBuilder<CodeStateTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CodeState>(
      rows,
      conflictColumns: conflictColumns(CodeState.t),
      updateColumns: updateColumns?.call(CodeState.t),
      updateWhere: updateWhere?.call(CodeState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CodeState] and returns the resulting row.
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
  /// The returned [CodeState] will have its `id` field set.
  Future<CodeState?> upsertRow(
    _isd.DatabaseSession session,
    CodeState row, {
    required _isd.ColumnSelections<CodeStateTable> conflictColumns,
    _isd.ColumnSelections<CodeStateTable>? updateColumns,
    _isd.WhereExpressionBuilder<CodeStateTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CodeState>(
      row,
      conflictColumns: conflictColumns(CodeState.t),
      updateColumns: updateColumns?.call(CodeState.t),
      updateWhere: updateWhere?.call(CodeState.t),
      transaction: transaction,
    );
  }

  /// Updates all [CodeState]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CodeState>> update(
    _isd.DatabaseSession session,
    List<CodeState> rows, {
    _isd.ColumnSelections<CodeStateTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CodeState>(
      rows,
      columns: columns?.call(CodeState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CodeState]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CodeState> updateRow(
    _isd.DatabaseSession session,
    CodeState row, {
    _isd.ColumnSelections<CodeStateTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<CodeState>(
      row,
      columns: columns?.call(CodeState.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CodeState] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CodeState?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<CodeStateUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<CodeState>(
      id,
      columnValues: columnValues(CodeState.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CodeState]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CodeState>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<CodeStateUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<CodeStateTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CodeStateTable>? orderBy,
    _isd.OrderByListBuilder<CodeStateTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CodeState>(
      columnValues: columnValues(CodeState.t.updateTable),
      where: where(CodeState.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CodeState.t),
      orderByList: orderByList?.call(CodeState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CodeState]s in the list and returns the deleted rows.
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
  Future<List<CodeState>> delete(
    _isd.DatabaseSession session,
    List<CodeState> rows, {
    _isd.OrderByBuilder<CodeStateTable>? orderBy,
    _isd.OrderByListBuilder<CodeStateTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CodeState>(
      rows,
      orderBy: orderBy?.call(CodeState.t),
      orderByList: orderByList?.call(CodeState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CodeState].
  Future<CodeState> deleteRow(
    _isd.DatabaseSession session,
    CodeState row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CodeState>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CodeState>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CodeStateTable> where,
    _isd.OrderByBuilder<CodeStateTable>? orderBy,
    _isd.OrderByListBuilder<CodeStateTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CodeState>(
      where: where(CodeState.t),
      orderBy: orderBy?.call(CodeState.t),
      orderByList: orderByList?.call(CodeState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CodeStateTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<CodeState>(
      where: where?.call(CodeState.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CodeState] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CodeStateTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CodeState>(
      where: where(CodeState.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CodeStateAttachRowRepository {
  const CodeStateAttachRowRepository._();

  /// Creates a relation between the given [CodeState] and [SlideElement]
  /// by setting the [CodeState]'s foreign key `elementId` to refer to the [SlideElement].
  Future<void> element(
    _isd.DatabaseSession session,
    CodeState codeState,
    _i810rwvy.SlideElement element, {
    _isd.Transaction? transaction,
  }) async {
    if (codeState.id == null) {
      throw ArgumentError.notNull('codeState.id');
    }
    if (element.id == null) {
      throw ArgumentError.notNull('element.id');
    }

    var $codeState = codeState.copyWith(elementId: element.id);
    await session.db.updateRow<CodeState>(
      $codeState,
      columns: [CodeState.t.elementId],
      transaction: transaction,
    );
  }
}
