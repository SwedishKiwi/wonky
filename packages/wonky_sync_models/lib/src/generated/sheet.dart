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

/// A sheet (tab) of a spreadsheet.
abstract class Sheet
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  Sheet._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.spreadsheetId,
    this.spreadsheet,
    required this.name,
    required this.sortKey,
    _i810rwvy.SheetKind? kind,
    bool? hidden,
    this.tabColor,
    bool? rightToLeft,
    bool? showGridlines,
    int? frozenRows,
    int? frozenColumns,
    double? defaultRowHeight,
    double? defaultColumnWidth,
    this.formatJson,
    this.printSettingsJson,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       kind = kind ?? _i810rwvy.SheetKind.grid,
       hidden = hidden ?? false,
       rightToLeft = rightToLeft ?? false,
       showGridlines = showGridlines ?? true,
       frozenRows = frozenRows ?? 0,
       frozenColumns = frozenColumns ?? 0,
       defaultRowHeight = defaultRowHeight ?? 21.0,
       defaultColumnWidth = defaultColumnWidth ?? 100.0,
       createdAt = createdAt ?? DateTime.now();

  factory Sheet({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet,
    required String name,
    required String sortKey,
    _i810rwvy.SheetKind? kind,
    bool? hidden,
    String? tabColor,
    bool? rightToLeft,
    bool? showGridlines,
    int? frozenRows,
    int? frozenColumns,
    double? defaultRowHeight,
    double? defaultColumnWidth,
    String? formatJson,
    String? printSettingsJson,
    DateTime? createdAt,
  }) = _SheetImpl;

  factory Sheet.fromJson(Map<String, dynamic> jsonSerialization) {
    return Sheet(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      spreadsheetId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['spreadsheetId'],
      ),
      spreadsheet: jsonSerialization['spreadsheet'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.Spreadsheet>(
              jsonSerialization['spreadsheet'],
            ),
      name: jsonSerialization['name'] as String,
      sortKey: jsonSerialization['sortKey'] as String,
      kind: jsonSerialization['kind'] == null
          ? null
          : _i810rwvy.SheetKind.fromJson((jsonSerialization['kind'] as String)),
      hidden: jsonSerialization['hidden'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['hidden']),
      tabColor: jsonSerialization['tabColor'] as String?,
      rightToLeft: jsonSerialization['rightToLeft'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['rightToLeft']),
      showGridlines: jsonSerialization['showGridlines'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['showGridlines']),
      frozenRows: jsonSerialization['frozenRows'] as int?,
      frozenColumns: jsonSerialization['frozenColumns'] as int?,
      defaultRowHeight: (jsonSerialization['defaultRowHeight'] as num?)
          ?.toDouble(),
      defaultColumnWidth: (jsonSerialization['defaultColumnWidth'] as num?)
          ?.toDouble(),
      formatJson: jsonSerialization['formatJson'] as String?,
      printSettingsJson: jsonSerialization['printSettingsJson'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = SheetTable();

  static const db = SheetRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue spreadsheetId;

  _i810rwvy.Spreadsheet? spreadsheet;

  String name;

  /// Fractional index; ties sort by id.
  String sortKey;

  _i810rwvy.SheetKind kind;

  bool hidden;

  String? tabColor;

  bool rightToLeft;

  bool showGridlines;

  /// Count from the top in the current order.
  int frozenRows;

  int frozenColumns;

  /// Pixels at 100% zoom.
  double defaultRowHeight;

  double defaultColumnWidth;

  /// Sheet-level default format.
  String? formatJson;

  /// Print settings (Sheets 11 §7.2); null = defaults.
  String? printSettingsJson;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [Sheet]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  Sheet copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet = const _UndefinedSheet$spreadsheet(),
    String? name,
    String? sortKey,
    _i810rwvy.SheetKind? kind,
    bool? hidden,
    String? tabColor,
    bool? rightToLeft,
    bool? showGridlines,
    int? frozenRows,
    int? frozenColumns,
    double? defaultRowHeight,
    double? defaultColumnWidth,
    String? formatJson,
    String? printSettingsJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Sheet',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'spreadsheetId': spreadsheetId.toJson(),
      if (spreadsheet != null) 'spreadsheet': spreadsheet?.toJson(),
      'name': name,
      'sortKey': sortKey,
      'kind': kind.toJson(),
      'hidden': hidden,
      if (tabColor != null) 'tabColor': tabColor,
      'rightToLeft': rightToLeft,
      'showGridlines': showGridlines,
      'frozenRows': frozenRows,
      'frozenColumns': frozenColumns,
      'defaultRowHeight': defaultRowHeight,
      'defaultColumnWidth': defaultColumnWidth,
      if (formatJson != null) 'formatJson': formatJson,
      if (printSettingsJson != null) 'printSettingsJson': printSettingsJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Sheet',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'spreadsheetId': spreadsheetId.toJson(),
      if (spreadsheet != null) 'spreadsheet': spreadsheet?.toJsonForProtocol(),
      'name': name,
      'sortKey': sortKey,
      'kind': kind.toJson(),
      'hidden': hidden,
      if (tabColor != null) 'tabColor': tabColor,
      'rightToLeft': rightToLeft,
      'showGridlines': showGridlines,
      'frozenRows': frozenRows,
      'frozenColumns': frozenColumns,
      'defaultRowHeight': defaultRowHeight,
      'defaultColumnWidth': defaultColumnWidth,
      if (formatJson != null) 'formatJson': formatJson,
      if (printSettingsJson != null) 'printSettingsJson': printSettingsJson,
      'createdAt': createdAt.toJson(),
    };
  }

  static SheetInclude include({_i810rwvy.SpreadsheetInclude? spreadsheet}) {
    return SheetInclude._(spreadsheet: spreadsheet);
  }

  static SheetIncludeList includeList({
    _isd.WhereExpressionBuilder<SheetTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetTable>? orderBy,
    _isd.OrderByListBuilder<SheetTable>? orderByList,
    SheetInclude? include,
  }) {
    return SheetIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Sheet.t),
      orderByList: orderByList?.call(Sheet.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedSheet$spreadsheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Spreadsheet {
  const _UndefinedSheet$spreadsheet();
}

class _SheetImpl extends Sheet {
  _SheetImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet,
    required String name,
    required String sortKey,
    _i810rwvy.SheetKind? kind,
    bool? hidden,
    String? tabColor,
    bool? rightToLeft,
    bool? showGridlines,
    int? frozenRows,
    int? frozenColumns,
    double? defaultRowHeight,
    double? defaultColumnWidth,
    String? formatJson,
    String? printSettingsJson,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         spreadsheetId: spreadsheetId,
         spreadsheet: spreadsheet,
         name: name,
         sortKey: sortKey,
         kind: kind,
         hidden: hidden,
         tabColor: tabColor,
         rightToLeft: rightToLeft,
         showGridlines: showGridlines,
         frozenRows: frozenRows,
         frozenColumns: frozenColumns,
         defaultRowHeight: defaultRowHeight,
         defaultColumnWidth: defaultColumnWidth,
         formatJson: formatJson,
         printSettingsJson: printSettingsJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Sheet]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  Sheet copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? spreadsheetId,
    _i810rwvy.Spreadsheet? spreadsheet = const _UndefinedSheet$spreadsheet(),
    String? name,
    String? sortKey,
    _i810rwvy.SheetKind? kind,
    bool? hidden,
    Object? tabColor = _Undefined,
    bool? rightToLeft,
    bool? showGridlines,
    int? frozenRows,
    int? frozenColumns,
    double? defaultRowHeight,
    double? defaultColumnWidth,
    Object? formatJson = _Undefined,
    Object? printSettingsJson = _Undefined,
    DateTime? createdAt,
  }) {
    return Sheet(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      spreadsheet: spreadsheet is _iss.UndefinedSentinel
          ? this.spreadsheet?.copyWith()
          : spreadsheet,
      name: name ?? this.name,
      sortKey: sortKey ?? this.sortKey,
      kind: kind ?? this.kind,
      hidden: hidden ?? this.hidden,
      tabColor: tabColor is String? ? tabColor : this.tabColor,
      rightToLeft: rightToLeft ?? this.rightToLeft,
      showGridlines: showGridlines ?? this.showGridlines,
      frozenRows: frozenRows ?? this.frozenRows,
      frozenColumns: frozenColumns ?? this.frozenColumns,
      defaultRowHeight: defaultRowHeight ?? this.defaultRowHeight,
      defaultColumnWidth: defaultColumnWidth ?? this.defaultColumnWidth,
      formatJson: formatJson is String? ? formatJson : this.formatJson,
      printSettingsJson: printSettingsJson is String?
          ? printSettingsJson
          : this.printSettingsJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SheetUpdateTable extends _isd.UpdateTable<SheetTable> {
  SheetUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> spreadsheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.spreadsheetId, value);

  _isd.ColumnValue<String, String> name(String value) =>
      _isd.ColumnValue(table.name, value);

  _isd.ColumnValue<String, String> sortKey(String value) =>
      _isd.ColumnValue(table.sortKey, value);

  _isd.ColumnValue<_i810rwvy.SheetKind, _i810rwvy.SheetKind> kind(
    _i810rwvy.SheetKind value,
  ) => _isd.ColumnValue(table.kind, value);

  _isd.ColumnValue<bool, bool> hidden(bool value) =>
      _isd.ColumnValue(table.hidden, value);

  _isd.ColumnValue<String, String> tabColor(String? value) =>
      _isd.ColumnValue(table.tabColor, value);

  _isd.ColumnValue<bool, bool> rightToLeft(bool value) =>
      _isd.ColumnValue(table.rightToLeft, value);

  _isd.ColumnValue<bool, bool> showGridlines(bool value) =>
      _isd.ColumnValue(table.showGridlines, value);

  _isd.ColumnValue<int, int> frozenRows(int value) =>
      _isd.ColumnValue(table.frozenRows, value);

  _isd.ColumnValue<int, int> frozenColumns(int value) =>
      _isd.ColumnValue(table.frozenColumns, value);

  _isd.ColumnValue<double, double> defaultRowHeight(double value) =>
      _isd.ColumnValue(table.defaultRowHeight, value);

  _isd.ColumnValue<double, double> defaultColumnWidth(double value) =>
      _isd.ColumnValue(table.defaultColumnWidth, value);

  _isd.ColumnValue<String, String> formatJson(String? value) =>
      _isd.ColumnValue(table.formatJson, value);

  _isd.ColumnValue<String, String> printSettingsJson(String? value) =>
      _isd.ColumnValue(table.printSettingsJson, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class SheetTable extends _isd.Table<_iss.UuidValue> {
  SheetTable({super.tableRelation}) : super(tableName: 'sheet') {
    updateTable = SheetUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    spreadsheetId = _isd.ColumnUuid('spreadsheetId', this);
    name = _isd.ColumnString('name', this);
    sortKey = _isd.ColumnString('sortKey', this);
    kind = _isd.ColumnEnum(
      'kind',
      this,
      _isd.EnumSerialization.byName,
      hasDefault: true,
    );
    hidden = _isd.ColumnBool('hidden', this, hasDefault: true);
    tabColor = _isd.ColumnString('tabColor', this);
    rightToLeft = _isd.ColumnBool('rightToLeft', this, hasDefault: true);
    showGridlines = _isd.ColumnBool('showGridlines', this, hasDefault: true);
    frozenRows = _isd.ColumnInt('frozenRows', this, hasDefault: true);
    frozenColumns = _isd.ColumnInt('frozenColumns', this, hasDefault: true);
    defaultRowHeight = _isd.ColumnDouble(
      'defaultRowHeight',
      this,
      hasDefault: true,
    );
    defaultColumnWidth = _isd.ColumnDouble(
      'defaultColumnWidth',
      this,
      hasDefault: true,
    );
    formatJson = _isd.ColumnString('formatJson', this);
    printSettingsJson = _isd.ColumnString('printSettingsJson', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final SheetUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid spreadsheetId;

  _i810rwvy.SpreadsheetTable? _spreadsheet;

  late final _isd.ColumnString name;

  /// Fractional index; ties sort by id.
  late final _isd.ColumnString sortKey;

  late final _isd.ColumnEnum<_i810rwvy.SheetKind> kind;

  late final _isd.ColumnBool hidden;

  late final _isd.ColumnString tabColor;

  late final _isd.ColumnBool rightToLeft;

  late final _isd.ColumnBool showGridlines;

  /// Count from the top in the current order.
  late final _isd.ColumnInt frozenRows;

  late final _isd.ColumnInt frozenColumns;

  /// Pixels at 100% zoom.
  late final _isd.ColumnDouble defaultRowHeight;

  late final _isd.ColumnDouble defaultColumnWidth;

  /// Sheet-level default format.
  late final _isd.ColumnString formatJson;

  /// Print settings (Sheets 11 §7.2); null = defaults.
  late final _isd.ColumnString printSettingsJson;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SpreadsheetTable get spreadsheet {
    if (_spreadsheet != null) return _spreadsheet!;
    _spreadsheet = _isd.createRelationTable(
      relationFieldName: 'spreadsheet',
      field: Sheet.t.spreadsheetId,
      foreignField: _i810rwvy.Spreadsheet.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SpreadsheetTable(tableRelation: foreignTableRelation),
    );
    return _spreadsheet!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    spreadsheetId,
    name,
    sortKey,
    kind,
    hidden,
    tabColor,
    rightToLeft,
    showGridlines,
    frozenRows,
    frozenColumns,
    defaultRowHeight,
    defaultColumnWidth,
    formatJson,
    printSettingsJson,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'spreadsheet') {
      return spreadsheet;
    }
    return null;
  }
}

class SheetInclude extends _isd.IncludeObject {
  SheetInclude._({_i810rwvy.SpreadsheetInclude? spreadsheet}) {
    _spreadsheet = spreadsheet;
  }

  _i810rwvy.SpreadsheetInclude? _spreadsheet;

  @override
  Map<String, _isd.Include?> get includes => {'spreadsheet': _spreadsheet};

  @override
  _isd.Table<_iss.UuidValue> get table => Sheet.t;
}

class SheetIncludeList extends _isd.IncludeList {
  SheetIncludeList._({
    _isd.WhereExpressionBuilder<SheetTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Sheet.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => Sheet.t;
}

class SheetRepository {
  const SheetRepository._();

  final attachRow = const SheetAttachRowRepository._();

  /// Returns a list of [Sheet]s matching the given query parameters.
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
  Future<List<Sheet>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetTable>? orderBy,
    _isd.OrderByListBuilder<SheetTable>? orderByList,
    _isd.Transaction? transaction,
    SheetInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Sheet>(
      where: where?.call(Sheet.t),
      orderBy: orderBy?.call(Sheet.t),
      orderByList: orderByList?.call(Sheet.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Sheet]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Sheet.t`.
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
  _ida.Stream<List<Sheet>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetTable>? orderBy,
    _isd.OrderByListBuilder<SheetTable>? orderByList,
    SheetInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Sheet>(
      where: where?.call(Sheet.t),
      orderBy: orderBy?.call(Sheet.t),
      orderByList: orderByList?.call(Sheet.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Sheet] matching the given query parameters.
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
  Future<Sheet?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetTable>? where,
    int? offset,
    _isd.OrderByBuilder<SheetTable>? orderBy,
    _isd.OrderByListBuilder<SheetTable>? orderByList,
    _isd.Transaction? transaction,
    SheetInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Sheet>(
      where: where?.call(Sheet.t),
      orderBy: orderBy?.call(Sheet.t),
      orderByList: orderByList?.call(Sheet.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Sheet] by its [id] or null if no such row exists.
  Future<Sheet?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SheetInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Sheet>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Sheet]s in the list and returns the inserted rows.
  ///
  /// The returned [Sheet]s will have their `id` fields set.
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
  Future<List<Sheet>> insert(
    _isd.DatabaseSession session,
    List<Sheet> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Sheet>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Sheet] and returns the inserted row.
  ///
  /// The returned [Sheet] will have its `id` field set.
  Future<Sheet> insertRow(
    _isd.DatabaseSession session,
    Sheet row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<Sheet>(row, transaction: transaction);
  }

  /// Upserts all [Sheet]s in the list and returns the resulting rows.
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
  /// The returned [Sheet]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Sheet>> upsert(
    _isd.DatabaseSession session,
    List<Sheet> rows, {
    required _isd.ColumnSelections<SheetTable> conflictColumns,
    _isd.ColumnSelections<SheetTable>? updateColumns,
    _isd.WhereExpressionBuilder<SheetTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Sheet>(
      rows,
      conflictColumns: conflictColumns(Sheet.t),
      updateColumns: updateColumns?.call(Sheet.t),
      updateWhere: updateWhere?.call(Sheet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Sheet] and returns the resulting row.
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
  /// The returned [Sheet] will have its `id` field set.
  Future<Sheet?> upsertRow(
    _isd.DatabaseSession session,
    Sheet row, {
    required _isd.ColumnSelections<SheetTable> conflictColumns,
    _isd.ColumnSelections<SheetTable>? updateColumns,
    _isd.WhereExpressionBuilder<SheetTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Sheet>(
      row,
      conflictColumns: conflictColumns(Sheet.t),
      updateColumns: updateColumns?.call(Sheet.t),
      updateWhere: updateWhere?.call(Sheet.t),
      transaction: transaction,
    );
  }

  /// Updates all [Sheet]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Sheet>> update(
    _isd.DatabaseSession session,
    List<Sheet> rows, {
    _isd.ColumnSelections<SheetTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Sheet>(
      rows,
      columns: columns?.call(Sheet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Sheet]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Sheet> updateRow(
    _isd.DatabaseSession session,
    Sheet row, {
    _isd.ColumnSelections<SheetTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<Sheet>(
      row,
      columns: columns?.call(Sheet.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Sheet] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Sheet?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SheetUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<Sheet>(
      id,
      columnValues: columnValues(Sheet.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Sheet]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Sheet>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SheetUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<SheetTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SheetTable>? orderBy,
    _isd.OrderByListBuilder<SheetTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Sheet>(
      columnValues: columnValues(Sheet.t.updateTable),
      where: where(Sheet.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Sheet.t),
      orderByList: orderByList?.call(Sheet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Sheet]s in the list and returns the deleted rows.
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
  Future<List<Sheet>> delete(
    _isd.DatabaseSession session,
    List<Sheet> rows, {
    _isd.OrderByBuilder<SheetTable>? orderBy,
    _isd.OrderByListBuilder<SheetTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Sheet>(
      rows,
      orderBy: orderBy?.call(Sheet.t),
      orderByList: orderByList?.call(Sheet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Sheet].
  Future<Sheet> deleteRow(
    _isd.DatabaseSession session,
    Sheet row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Sheet>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Sheet>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SheetTable> where,
    _isd.OrderByBuilder<SheetTable>? orderBy,
    _isd.OrderByListBuilder<SheetTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Sheet>(
      where: where(Sheet.t),
      orderBy: orderBy?.call(Sheet.t),
      orderByList: orderByList?.call(Sheet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SheetTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<Sheet>(
      where: where?.call(Sheet.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Sheet] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SheetTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Sheet>(
      where: where(Sheet.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SheetAttachRowRepository {
  const SheetAttachRowRepository._();

  /// Creates a relation between the given [Sheet] and [Spreadsheet]
  /// by setting the [Sheet]'s foreign key `spreadsheetId` to refer to the [Spreadsheet].
  Future<void> spreadsheet(
    _isd.DatabaseSession session,
    Sheet sheet,
    _i810rwvy.Spreadsheet spreadsheet, {
    _isd.Transaction? transaction,
  }) async {
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }
    if (spreadsheet.id == null) {
      throw ArgumentError.notNull('spreadsheet.id');
    }

    var $sheet = sheet.copyWith(spreadsheetId: spreadsheet.id);
    await session.db.updateRow<Sheet>(
      $sheet,
      columns: [Sheet.t.spreadsheetId],
      transaction: transaction,
    );
  }
}
