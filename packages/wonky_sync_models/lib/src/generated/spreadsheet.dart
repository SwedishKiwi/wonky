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
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;
import 'package:wonky_sync_models/wonky_sync_models.dart' as _i810rwvy;

/// A spreadsheet. Its id is always the uuidSpaceId of the space it lives in
/// (one spreadsheet per space, Sheets 02 §3.1).
abstract class Spreadsheet
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  Spreadsheet._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.title,
    required this.locale,
    required this.timeZone,
    _i810rwvy.RecalcMode? recalcMode,
    bool? iterativeCalc,
    int? maxIterations,
    double? convergenceThreshold,
    String? defaultFontFamily,
    double? defaultFontSize,
    required this.themeJson,
    this.displayLanguage,
    required this.createdBy,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       recalcMode = recalcMode ?? _i810rwvy.RecalcMode.onChange,
       iterativeCalc = iterativeCalc ?? false,
       maxIterations = maxIterations ?? 50,
       convergenceThreshold = convergenceThreshold ?? 0.05,
       defaultFontFamily = defaultFontFamily ?? 'Inter',
       defaultFontSize = defaultFontSize ?? 10.0,
       createdAt = createdAt ?? DateTime.now();

  factory Spreadsheet({
    _iss.UuidValue? id,
    int? spaceId,
    required String title,
    required String locale,
    required String timeZone,
    _i810rwvy.RecalcMode? recalcMode,
    bool? iterativeCalc,
    int? maxIterations,
    double? convergenceThreshold,
    String? defaultFontFamily,
    double? defaultFontSize,
    required String themeJson,
    String? displayLanguage,
    required _iss.UuidValue createdBy,
    DateTime? createdAt,
  }) = _SpreadsheetImpl;

  factory Spreadsheet.fromJson(Map<String, dynamic> jsonSerialization) {
    return Spreadsheet(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      title: jsonSerialization['title'] as String,
      locale: jsonSerialization['locale'] as String,
      timeZone: jsonSerialization['timeZone'] as String,
      recalcMode: jsonSerialization['recalcMode'] == null
          ? null
          : _i810rwvy.RecalcMode.fromJson(
              (jsonSerialization['recalcMode'] as String),
            ),
      iterativeCalc: jsonSerialization['iterativeCalc'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['iterativeCalc']),
      maxIterations: jsonSerialization['maxIterations'] as int?,
      convergenceThreshold: (jsonSerialization['convergenceThreshold'] as num?)
          ?.toDouble(),
      defaultFontFamily: jsonSerialization['defaultFontFamily'] as String?,
      defaultFontSize: (jsonSerialization['defaultFontSize'] as num?)
          ?.toDouble(),
      themeJson: jsonSerialization['themeJson'] as String,
      displayLanguage: jsonSerialization['displayLanguage'] as String?,
      createdBy: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['createdBy'],
      ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = SpreadsheetTable();

  static const db = SpreadsheetRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  /// Mirrored to DriveItem.name by the server.
  String title;

  /// Number/date parsing and formatting, function argument separator (e.g. en_US).
  String locale;

  /// IANA time zone.
  String timeZone;

  _i810rwvy.RecalcMode recalcMode;

  bool iterativeCalc;

  int maxIterations;

  double convergenceThreshold;

  String defaultFontFamily;

  double defaultFontSize;

  /// {v, name, fonts: {text}, colors: {...}} (Sheets 06 §13.1).
  String themeJson;

  /// Function name language; null = English (Sheets 04 §15, P2).
  String? displayLanguage;

  /// Auth user UUID of the creator.
  _iss.UuidValue createdBy;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [Spreadsheet]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  Spreadsheet copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    String? title,
    String? locale,
    String? timeZone,
    _i810rwvy.RecalcMode? recalcMode,
    bool? iterativeCalc,
    int? maxIterations,
    double? convergenceThreshold,
    String? defaultFontFamily,
    double? defaultFontSize,
    String? themeJson,
    String? displayLanguage,
    _iss.UuidValue? createdBy,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Spreadsheet',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'title': title,
      'locale': locale,
      'timeZone': timeZone,
      'recalcMode': recalcMode.toJson(),
      'iterativeCalc': iterativeCalc,
      'maxIterations': maxIterations,
      'convergenceThreshold': convergenceThreshold,
      'defaultFontFamily': defaultFontFamily,
      'defaultFontSize': defaultFontSize,
      'themeJson': themeJson,
      if (displayLanguage != null) 'displayLanguage': displayLanguage,
      'createdBy': createdBy.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Spreadsheet',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'title': title,
      'locale': locale,
      'timeZone': timeZone,
      'recalcMode': recalcMode.toJson(),
      'iterativeCalc': iterativeCalc,
      'maxIterations': maxIterations,
      'convergenceThreshold': convergenceThreshold,
      'defaultFontFamily': defaultFontFamily,
      'defaultFontSize': defaultFontSize,
      'themeJson': themeJson,
      if (displayLanguage != null) 'displayLanguage': displayLanguage,
      'createdBy': createdBy.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static SpreadsheetInclude include() {
    return SpreadsheetInclude._();
  }

  static SpreadsheetIncludeList includeList({
    _isd.WhereExpressionBuilder<SpreadsheetTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SpreadsheetTable>? orderBy,
    _isd.OrderByListBuilder<SpreadsheetTable>? orderByList,
    SpreadsheetInclude? include,
  }) {
    return SpreadsheetIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Spreadsheet.t),
      orderByList: orderByList?.call(Spreadsheet.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SpreadsheetImpl extends Spreadsheet {
  _SpreadsheetImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required String title,
    required String locale,
    required String timeZone,
    _i810rwvy.RecalcMode? recalcMode,
    bool? iterativeCalc,
    int? maxIterations,
    double? convergenceThreshold,
    String? defaultFontFamily,
    double? defaultFontSize,
    required String themeJson,
    String? displayLanguage,
    required _iss.UuidValue createdBy,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         title: title,
         locale: locale,
         timeZone: timeZone,
         recalcMode: recalcMode,
         iterativeCalc: iterativeCalc,
         maxIterations: maxIterations,
         convergenceThreshold: convergenceThreshold,
         defaultFontFamily: defaultFontFamily,
         defaultFontSize: defaultFontSize,
         themeJson: themeJson,
         displayLanguage: displayLanguage,
         createdBy: createdBy,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Spreadsheet]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  Spreadsheet copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    String? title,
    String? locale,
    String? timeZone,
    _i810rwvy.RecalcMode? recalcMode,
    bool? iterativeCalc,
    int? maxIterations,
    double? convergenceThreshold,
    String? defaultFontFamily,
    double? defaultFontSize,
    String? themeJson,
    Object? displayLanguage = _Undefined,
    _iss.UuidValue? createdBy,
    DateTime? createdAt,
  }) {
    return Spreadsheet(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      title: title ?? this.title,
      locale: locale ?? this.locale,
      timeZone: timeZone ?? this.timeZone,
      recalcMode: recalcMode ?? this.recalcMode,
      iterativeCalc: iterativeCalc ?? this.iterativeCalc,
      maxIterations: maxIterations ?? this.maxIterations,
      convergenceThreshold: convergenceThreshold ?? this.convergenceThreshold,
      defaultFontFamily: defaultFontFamily ?? this.defaultFontFamily,
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      themeJson: themeJson ?? this.themeJson,
      displayLanguage: displayLanguage is String?
          ? displayLanguage
          : this.displayLanguage,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SpreadsheetUpdateTable extends _isd.UpdateTable<SpreadsheetTable> {
  SpreadsheetUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<String, String> title(String value) =>
      _isd.ColumnValue(table.title, value);

  _isd.ColumnValue<String, String> locale(String value) =>
      _isd.ColumnValue(table.locale, value);

  _isd.ColumnValue<String, String> timeZone(String value) =>
      _isd.ColumnValue(table.timeZone, value);

  _isd.ColumnValue<_i810rwvy.RecalcMode, _i810rwvy.RecalcMode> recalcMode(
    _i810rwvy.RecalcMode value,
  ) => _isd.ColumnValue(table.recalcMode, value);

  _isd.ColumnValue<bool, bool> iterativeCalc(bool value) =>
      _isd.ColumnValue(table.iterativeCalc, value);

  _isd.ColumnValue<int, int> maxIterations(int value) =>
      _isd.ColumnValue(table.maxIterations, value);

  _isd.ColumnValue<double, double> convergenceThreshold(double value) =>
      _isd.ColumnValue(table.convergenceThreshold, value);

  _isd.ColumnValue<String, String> defaultFontFamily(String value) =>
      _isd.ColumnValue(table.defaultFontFamily, value);

  _isd.ColumnValue<double, double> defaultFontSize(double value) =>
      _isd.ColumnValue(table.defaultFontSize, value);

  _isd.ColumnValue<String, String> themeJson(String value) =>
      _isd.ColumnValue(table.themeJson, value);

  _isd.ColumnValue<String, String> displayLanguage(String? value) =>
      _isd.ColumnValue(table.displayLanguage, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> createdBy(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.createdBy, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class SpreadsheetTable extends _isd.Table<_iss.UuidValue> {
  SpreadsheetTable({super.tableRelation}) : super(tableName: 'spreadsheet') {
    updateTable = SpreadsheetUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    title = _isd.ColumnString('title', this);
    locale = _isd.ColumnString('locale', this);
    timeZone = _isd.ColumnString('timeZone', this);
    recalcMode = _isd.ColumnEnum(
      'recalcMode',
      this,
      _isd.EnumSerialization.byName,
      hasDefault: true,
    );
    iterativeCalc = _isd.ColumnBool('iterativeCalc', this, hasDefault: true);
    maxIterations = _isd.ColumnInt('maxIterations', this, hasDefault: true);
    convergenceThreshold = _isd.ColumnDouble(
      'convergenceThreshold',
      this,
      hasDefault: true,
    );
    defaultFontFamily = _isd.ColumnString(
      'defaultFontFamily',
      this,
      hasDefault: true,
    );
    defaultFontSize = _isd.ColumnDouble(
      'defaultFontSize',
      this,
      hasDefault: true,
    );
    themeJson = _isd.ColumnString('themeJson', this);
    displayLanguage = _isd.ColumnString('displayLanguage', this);
    createdBy = _isd.ColumnUuid('createdBy', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final SpreadsheetUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  /// Mirrored to DriveItem.name by the server.
  late final _isd.ColumnString title;

  /// Number/date parsing and formatting, function argument separator (e.g. en_US).
  late final _isd.ColumnString locale;

  /// IANA time zone.
  late final _isd.ColumnString timeZone;

  late final _isd.ColumnEnum<_i810rwvy.RecalcMode> recalcMode;

  late final _isd.ColumnBool iterativeCalc;

  late final _isd.ColumnInt maxIterations;

  late final _isd.ColumnDouble convergenceThreshold;

  late final _isd.ColumnString defaultFontFamily;

  late final _isd.ColumnDouble defaultFontSize;

  /// {v, name, fonts: {text}, colors: {...}} (Sheets 06 §13.1).
  late final _isd.ColumnString themeJson;

  /// Function name language; null = English (Sheets 04 §15, P2).
  late final _isd.ColumnString displayLanguage;

  /// Auth user UUID of the creator.
  late final _isd.ColumnUuid createdBy;

  late final _isd.ColumnDateTime createdAt;

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    title,
    locale,
    timeZone,
    recalcMode,
    iterativeCalc,
    maxIterations,
    convergenceThreshold,
    defaultFontFamily,
    defaultFontSize,
    themeJson,
    displayLanguage,
    createdBy,
    createdAt,
  ];
}

class SpreadsheetInclude extends _isd.IncludeObject {
  SpreadsheetInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<_iss.UuidValue> get table => Spreadsheet.t;
}

class SpreadsheetIncludeList extends _isd.IncludeList {
  SpreadsheetIncludeList._({
    _isd.WhereExpressionBuilder<SpreadsheetTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Spreadsheet.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => Spreadsheet.t;
}

class SpreadsheetRepository {
  const SpreadsheetRepository._();

  /// Returns a list of [Spreadsheet]s matching the given query parameters.
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
  Future<List<Spreadsheet>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SpreadsheetTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SpreadsheetTable>? orderBy,
    _isd.OrderByListBuilder<SpreadsheetTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Spreadsheet>(
      where: where?.call(Spreadsheet.t),
      orderBy: orderBy?.call(Spreadsheet.t),
      orderByList: orderByList?.call(Spreadsheet.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Spreadsheet]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Spreadsheet.t`.
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
  _ida.Stream<List<Spreadsheet>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SpreadsheetTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SpreadsheetTable>? orderBy,
    _isd.OrderByListBuilder<SpreadsheetTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Spreadsheet>(
      where: where?.call(Spreadsheet.t),
      orderBy: orderBy?.call(Spreadsheet.t),
      orderByList: orderByList?.call(Spreadsheet.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Spreadsheet] matching the given query parameters.
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
  Future<Spreadsheet?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SpreadsheetTable>? where,
    int? offset,
    _isd.OrderByBuilder<SpreadsheetTable>? orderBy,
    _isd.OrderByListBuilder<SpreadsheetTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Spreadsheet>(
      where: where?.call(Spreadsheet.t),
      orderBy: orderBy?.call(Spreadsheet.t),
      orderByList: orderByList?.call(Spreadsheet.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Spreadsheet] by its [id] or null if no such row exists.
  Future<Spreadsheet?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Spreadsheet>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Spreadsheet]s in the list and returns the inserted rows.
  ///
  /// The returned [Spreadsheet]s will have their `id` fields set.
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
  Future<List<Spreadsheet>> insert(
    _isd.DatabaseSession session,
    List<Spreadsheet> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Spreadsheet>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Spreadsheet] and returns the inserted row.
  ///
  /// The returned [Spreadsheet] will have its `id` field set.
  Future<Spreadsheet> insertRow(
    _isd.DatabaseSession session,
    Spreadsheet row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<Spreadsheet>(row, transaction: transaction);
  }

  /// Upserts all [Spreadsheet]s in the list and returns the resulting rows.
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
  /// The returned [Spreadsheet]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Spreadsheet>> upsert(
    _isd.DatabaseSession session,
    List<Spreadsheet> rows, {
    required _isd.ColumnSelections<SpreadsheetTable> conflictColumns,
    _isd.ColumnSelections<SpreadsheetTable>? updateColumns,
    _isd.WhereExpressionBuilder<SpreadsheetTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Spreadsheet>(
      rows,
      conflictColumns: conflictColumns(Spreadsheet.t),
      updateColumns: updateColumns?.call(Spreadsheet.t),
      updateWhere: updateWhere?.call(Spreadsheet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Spreadsheet] and returns the resulting row.
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
  /// The returned [Spreadsheet] will have its `id` field set.
  Future<Spreadsheet?> upsertRow(
    _isd.DatabaseSession session,
    Spreadsheet row, {
    required _isd.ColumnSelections<SpreadsheetTable> conflictColumns,
    _isd.ColumnSelections<SpreadsheetTable>? updateColumns,
    _isd.WhereExpressionBuilder<SpreadsheetTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Spreadsheet>(
      row,
      conflictColumns: conflictColumns(Spreadsheet.t),
      updateColumns: updateColumns?.call(Spreadsheet.t),
      updateWhere: updateWhere?.call(Spreadsheet.t),
      transaction: transaction,
    );
  }

  /// Updates all [Spreadsheet]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Spreadsheet>> update(
    _isd.DatabaseSession session,
    List<Spreadsheet> rows, {
    _isd.ColumnSelections<SpreadsheetTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Spreadsheet>(
      rows,
      columns: columns?.call(Spreadsheet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Spreadsheet]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Spreadsheet> updateRow(
    _isd.DatabaseSession session,
    Spreadsheet row, {
    _isd.ColumnSelections<SpreadsheetTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<Spreadsheet>(
      row,
      columns: columns?.call(Spreadsheet.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Spreadsheet] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Spreadsheet?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SpreadsheetUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<Spreadsheet>(
      id,
      columnValues: columnValues(Spreadsheet.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Spreadsheet]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Spreadsheet>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SpreadsheetUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<SpreadsheetTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SpreadsheetTable>? orderBy,
    _isd.OrderByListBuilder<SpreadsheetTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Spreadsheet>(
      columnValues: columnValues(Spreadsheet.t.updateTable),
      where: where(Spreadsheet.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Spreadsheet.t),
      orderByList: orderByList?.call(Spreadsheet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Spreadsheet]s in the list and returns the deleted rows.
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
  Future<List<Spreadsheet>> delete(
    _isd.DatabaseSession session,
    List<Spreadsheet> rows, {
    _isd.OrderByBuilder<SpreadsheetTable>? orderBy,
    _isd.OrderByListBuilder<SpreadsheetTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Spreadsheet>(
      rows,
      orderBy: orderBy?.call(Spreadsheet.t),
      orderByList: orderByList?.call(Spreadsheet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Spreadsheet].
  Future<Spreadsheet> deleteRow(
    _isd.DatabaseSession session,
    Spreadsheet row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Spreadsheet>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Spreadsheet>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SpreadsheetTable> where,
    _isd.OrderByBuilder<SpreadsheetTable>? orderBy,
    _isd.OrderByListBuilder<SpreadsheetTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Spreadsheet>(
      where: where(Spreadsheet.t),
      orderBy: orderBy?.call(Spreadsheet.t),
      orderByList: orderByList?.call(Spreadsheet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SpreadsheetTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<Spreadsheet>(
      where: where?.call(Spreadsheet.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Spreadsheet] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SpreadsheetTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Spreadsheet>(
      where: where(Spreadsheet.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
