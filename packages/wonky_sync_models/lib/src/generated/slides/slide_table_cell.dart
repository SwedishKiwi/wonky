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

/// A non-empty table cell (Slides 02 §3.6). Its id is always
/// SlidesIds.tableCellId(elementId, rowId, columnId), so concurrent writers of
/// the same cell share one row (per-column merge). Exists iff a field is set.
abstract class SlideTableCell
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  SlideTableCell._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.elementId,
    this.element,
    required this.rowId,
    this.row,
    required this.columnId,
    this.column,
    this.text,
    this.fill,
    this.borderTop,
    this.borderRight,
    this.borderBottom,
    this.borderLeft,
    this.vAlign,
    this.padding,
    this.rowSpan,
    this.colSpan,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory SlideTableCell({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue elementId,
    _i810rwvy.SlideElement? element,
    required _iss.UuidValue rowId,
    _i810rwvy.SlideTableAxis? row,
    required _iss.UuidValue columnId,
    _i810rwvy.SlideTableAxis? column,
    String? text,
    String? fill,
    String? borderTop,
    String? borderRight,
    String? borderBottom,
    String? borderLeft,
    String? vAlign,
    String? padding,
    int? rowSpan,
    int? colSpan,
    DateTime? createdAt,
  }) = _SlideTableCellImpl;

  factory SlideTableCell.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlideTableCell(
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
      rowId: _iss.UuidValueJsonExtension.fromJson(jsonSerialization['rowId']),
      row: jsonSerialization['row'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.SlideTableAxis>(
              jsonSerialization['row'],
            ),
      columnId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['columnId'],
      ),
      column: jsonSerialization['column'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.SlideTableAxis>(
              jsonSerialization['column'],
            ),
      text: jsonSerialization['text'] as String?,
      fill: jsonSerialization['fill'] as String?,
      borderTop: jsonSerialization['borderTop'] as String?,
      borderRight: jsonSerialization['borderRight'] as String?,
      borderBottom: jsonSerialization['borderBottom'] as String?,
      borderLeft: jsonSerialization['borderLeft'] as String?,
      vAlign: jsonSerialization['vAlign'] as String?,
      padding: jsonSerialization['padding'] as String?,
      rowSpan: jsonSerialization['rowSpan'] as int?,
      colSpan: jsonSerialization['colSpan'] as int?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = SlideTableCellTable();

  static const db = SlideTableCellRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue elementId;

  _i810rwvy.SlideElement? element;

  _iss.UuidValue rowId;

  _i810rwvy.SlideTableAxis? row;

  _iss.UuidValue columnId;

  _i810rwvy.SlideTableAxis? column;

  /// Rich text Delta (02 §4).
  String? text;

  /// ColorRef.
  String? fill;

  /// "<width>|<style>|<ColorRef>", style: solid, dashed, dotted, none.
  String? borderTop;

  String? borderRight;

  String? borderBottom;

  String? borderLeft;

  /// top, middle, bottom.
  String? vAlign;

  /// "t,r,b,l" in su.
  String? padding;

  /// Merge origin only; null = 1.
  int? rowSpan;

  int? colSpan;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [SlideTableCell]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  SlideTableCell copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? elementId,
    _i810rwvy.SlideElement? element = const _UndefinedSlideTableCell$element(),
    _iss.UuidValue? rowId,
    _i810rwvy.SlideTableAxis? row = const _UndefinedSlideTableCell$row(),
    _iss.UuidValue? columnId,
    _i810rwvy.SlideTableAxis? column = const _UndefinedSlideTableCell$row(),
    String? text,
    String? fill,
    String? borderTop,
    String? borderRight,
    String? borderBottom,
    String? borderLeft,
    String? vAlign,
    String? padding,
    int? rowSpan,
    int? colSpan,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlideTableCell',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'elementId': elementId.toJson(),
      if (element != null) 'element': element?.toJson(),
      'rowId': rowId.toJson(),
      if (row != null) 'row': row?.toJson(),
      'columnId': columnId.toJson(),
      if (column != null) 'column': column?.toJson(),
      if (text != null) 'text': text,
      if (fill != null) 'fill': fill,
      if (borderTop != null) 'borderTop': borderTop,
      if (borderRight != null) 'borderRight': borderRight,
      if (borderBottom != null) 'borderBottom': borderBottom,
      if (borderLeft != null) 'borderLeft': borderLeft,
      if (vAlign != null) 'vAlign': vAlign,
      if (padding != null) 'padding': padding,
      if (rowSpan != null) 'rowSpan': rowSpan,
      if (colSpan != null) 'colSpan': colSpan,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlideTableCell',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'elementId': elementId.toJson(),
      if (element != null) 'element': element?.toJsonForProtocol(),
      'rowId': rowId.toJson(),
      if (row != null) 'row': row?.toJsonForProtocol(),
      'columnId': columnId.toJson(),
      if (column != null) 'column': column?.toJsonForProtocol(),
      if (text != null) 'text': text,
      if (fill != null) 'fill': fill,
      if (borderTop != null) 'borderTop': borderTop,
      if (borderRight != null) 'borderRight': borderRight,
      if (borderBottom != null) 'borderBottom': borderBottom,
      if (borderLeft != null) 'borderLeft': borderLeft,
      if (vAlign != null) 'vAlign': vAlign,
      if (padding != null) 'padding': padding,
      if (rowSpan != null) 'rowSpan': rowSpan,
      if (colSpan != null) 'colSpan': colSpan,
      'createdAt': createdAt.toJson(),
    };
  }

  static SlideTableCellInclude include({
    _i810rwvy.SlideElementInclude? element,
    _i810rwvy.SlideTableAxisInclude? row,
    _i810rwvy.SlideTableAxisInclude? column,
  }) {
    return SlideTableCellInclude._(element: element, row: row, column: column);
  }

  static SlideTableCellIncludeList includeList({
    _isd.WhereExpressionBuilder<SlideTableCellTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTableCellTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableCellTable>? orderByList,
    SlideTableCellInclude? include,
  }) {
    return SlideTableCellIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideTableCell.t),
      orderByList: orderByList?.call(SlideTableCell.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedSlideTableCell$element extends _iss.UndefinedSentinel
    implements _i810rwvy.SlideElement {
  const _UndefinedSlideTableCell$element();
}

class _UndefinedSlideTableCell$row extends _iss.UndefinedSentinel
    implements _i810rwvy.SlideTableAxis {
  const _UndefinedSlideTableCell$row();
}

class _SlideTableCellImpl extends SlideTableCell {
  _SlideTableCellImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue elementId,
    _i810rwvy.SlideElement? element,
    required _iss.UuidValue rowId,
    _i810rwvy.SlideTableAxis? row,
    required _iss.UuidValue columnId,
    _i810rwvy.SlideTableAxis? column,
    String? text,
    String? fill,
    String? borderTop,
    String? borderRight,
    String? borderBottom,
    String? borderLeft,
    String? vAlign,
    String? padding,
    int? rowSpan,
    int? colSpan,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         elementId: elementId,
         element: element,
         rowId: rowId,
         row: row,
         columnId: columnId,
         column: column,
         text: text,
         fill: fill,
         borderTop: borderTop,
         borderRight: borderRight,
         borderBottom: borderBottom,
         borderLeft: borderLeft,
         vAlign: vAlign,
         padding: padding,
         rowSpan: rowSpan,
         colSpan: colSpan,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SlideTableCell]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  SlideTableCell copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? elementId,
    _i810rwvy.SlideElement? element = const _UndefinedSlideTableCell$element(),
    _iss.UuidValue? rowId,
    _i810rwvy.SlideTableAxis? row = const _UndefinedSlideTableCell$row(),
    _iss.UuidValue? columnId,
    _i810rwvy.SlideTableAxis? column = const _UndefinedSlideTableCell$row(),
    Object? text = _Undefined,
    Object? fill = _Undefined,
    Object? borderTop = _Undefined,
    Object? borderRight = _Undefined,
    Object? borderBottom = _Undefined,
    Object? borderLeft = _Undefined,
    Object? vAlign = _Undefined,
    Object? padding = _Undefined,
    Object? rowSpan = _Undefined,
    Object? colSpan = _Undefined,
    DateTime? createdAt,
  }) {
    return SlideTableCell(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      elementId: elementId ?? this.elementId,
      element: element is _iss.UndefinedSentinel
          ? this.element?.copyWith()
          : element,
      rowId: rowId ?? this.rowId,
      row: row is _iss.UndefinedSentinel ? this.row?.copyWith() : row,
      columnId: columnId ?? this.columnId,
      column: column is _iss.UndefinedSentinel
          ? this.column?.copyWith()
          : column,
      text: text is String? ? text : this.text,
      fill: fill is String? ? fill : this.fill,
      borderTop: borderTop is String? ? borderTop : this.borderTop,
      borderRight: borderRight is String? ? borderRight : this.borderRight,
      borderBottom: borderBottom is String? ? borderBottom : this.borderBottom,
      borderLeft: borderLeft is String? ? borderLeft : this.borderLeft,
      vAlign: vAlign is String? ? vAlign : this.vAlign,
      padding: padding is String? ? padding : this.padding,
      rowSpan: rowSpan is int? ? rowSpan : this.rowSpan,
      colSpan: colSpan is int? ? colSpan : this.colSpan,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SlideTableCellUpdateTable extends _isd.UpdateTable<SlideTableCellTable> {
  SlideTableCellUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> elementId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.elementId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> rowId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.rowId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> columnId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.columnId, value);

  _isd.ColumnValue<String, String> text(String? value) =>
      _isd.ColumnValue(table.text, value);

  _isd.ColumnValue<String, String> fill(String? value) =>
      _isd.ColumnValue(table.fill, value);

  _isd.ColumnValue<String, String> borderTop(String? value) =>
      _isd.ColumnValue(table.borderTop, value);

  _isd.ColumnValue<String, String> borderRight(String? value) =>
      _isd.ColumnValue(table.borderRight, value);

  _isd.ColumnValue<String, String> borderBottom(String? value) =>
      _isd.ColumnValue(table.borderBottom, value);

  _isd.ColumnValue<String, String> borderLeft(String? value) =>
      _isd.ColumnValue(table.borderLeft, value);

  _isd.ColumnValue<String, String> vAlign(String? value) =>
      _isd.ColumnValue(table.vAlign, value);

  _isd.ColumnValue<String, String> padding(String? value) =>
      _isd.ColumnValue(table.padding, value);

  _isd.ColumnValue<int, int> rowSpan(int? value) =>
      _isd.ColumnValue(table.rowSpan, value);

  _isd.ColumnValue<int, int> colSpan(int? value) =>
      _isd.ColumnValue(table.colSpan, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class SlideTableCellTable extends _isd.Table<_iss.UuidValue> {
  SlideTableCellTable({super.tableRelation})
    : super(tableName: 'slide_table_cell') {
    updateTable = SlideTableCellUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    elementId = _isd.ColumnUuid('elementId', this);
    rowId = _isd.ColumnUuid('rowId', this);
    columnId = _isd.ColumnUuid('columnId', this);
    text = _isd.ColumnString('text', this);
    fill = _isd.ColumnString('fill', this);
    borderTop = _isd.ColumnString('borderTop', this);
    borderRight = _isd.ColumnString('borderRight', this);
    borderBottom = _isd.ColumnString('borderBottom', this);
    borderLeft = _isd.ColumnString('borderLeft', this);
    vAlign = _isd.ColumnString('vAlign', this);
    padding = _isd.ColumnString('padding', this);
    rowSpan = _isd.ColumnInt('rowSpan', this);
    colSpan = _isd.ColumnInt('colSpan', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final SlideTableCellUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid elementId;

  _i810rwvy.SlideElementTable? _element;

  late final _isd.ColumnUuid rowId;

  _i810rwvy.SlideTableAxisTable? _row;

  late final _isd.ColumnUuid columnId;

  _i810rwvy.SlideTableAxisTable? _column;

  /// Rich text Delta (02 §4).
  late final _isd.ColumnString text;

  /// ColorRef.
  late final _isd.ColumnString fill;

  /// "<width>|<style>|<ColorRef>", style: solid, dashed, dotted, none.
  late final _isd.ColumnString borderTop;

  late final _isd.ColumnString borderRight;

  late final _isd.ColumnString borderBottom;

  late final _isd.ColumnString borderLeft;

  /// top, middle, bottom.
  late final _isd.ColumnString vAlign;

  /// "t,r,b,l" in su.
  late final _isd.ColumnString padding;

  /// Merge origin only; null = 1.
  late final _isd.ColumnInt rowSpan;

  late final _isd.ColumnInt colSpan;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SlideElementTable get element {
    if (_element != null) return _element!;
    _element = _isd.createRelationTable(
      relationFieldName: 'element',
      field: SlideTableCell.t.elementId,
      foreignField: _i810rwvy.SlideElement.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SlideElementTable(tableRelation: foreignTableRelation),
    );
    return _element!;
  }

  _i810rwvy.SlideTableAxisTable get row {
    if (_row != null) return _row!;
    _row = _isd.createRelationTable(
      relationFieldName: 'row',
      field: SlideTableCell.t.rowId,
      foreignField: _i810rwvy.SlideTableAxis.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SlideTableAxisTable(tableRelation: foreignTableRelation),
    );
    return _row!;
  }

  _i810rwvy.SlideTableAxisTable get column {
    if (_column != null) return _column!;
    _column = _isd.createRelationTable(
      relationFieldName: 'column',
      field: SlideTableCell.t.columnId,
      foreignField: _i810rwvy.SlideTableAxis.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SlideTableAxisTable(tableRelation: foreignTableRelation),
    );
    return _column!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    elementId,
    rowId,
    columnId,
    text,
    fill,
    borderTop,
    borderRight,
    borderBottom,
    borderLeft,
    vAlign,
    padding,
    rowSpan,
    colSpan,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'element') {
      return element;
    }
    if (relationField == 'row') {
      return row;
    }
    if (relationField == 'column') {
      return column;
    }
    return null;
  }
}

class SlideTableCellInclude extends _isd.IncludeObject {
  SlideTableCellInclude._({
    _i810rwvy.SlideElementInclude? element,
    _i810rwvy.SlideTableAxisInclude? row,
    _i810rwvy.SlideTableAxisInclude? column,
  }) {
    _element = element;
    _row = row;
    _column = column;
  }

  _i810rwvy.SlideElementInclude? _element;

  _i810rwvy.SlideTableAxisInclude? _row;

  _i810rwvy.SlideTableAxisInclude? _column;

  @override
  Map<String, _isd.Include?> get includes => {
    'element': _element,
    'row': _row,
    'column': _column,
  };

  @override
  _isd.Table<_iss.UuidValue> get table => SlideTableCell.t;
}

class SlideTableCellIncludeList extends _isd.IncludeList {
  SlideTableCellIncludeList._({
    _isd.WhereExpressionBuilder<SlideTableCellTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SlideTableCell.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => SlideTableCell.t;
}

class SlideTableCellRepository {
  const SlideTableCellRepository._();

  final attachRow = const SlideTableCellAttachRowRepository._();

  /// Returns a list of [SlideTableCell]s matching the given query parameters.
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
  Future<List<SlideTableCell>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTableCellTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTableCellTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableCellTable>? orderByList,
    _isd.Transaction? transaction,
    SlideTableCellInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SlideTableCell>(
      where: where?.call(SlideTableCell.t),
      orderBy: orderBy?.call(SlideTableCell.t),
      orderByList: orderByList?.call(SlideTableCell.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SlideTableCell]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SlideTableCell.t`.
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
  _ida.Stream<List<SlideTableCell>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTableCellTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTableCellTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableCellTable>? orderByList,
    SlideTableCellInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SlideTableCell>(
      where: where?.call(SlideTableCell.t),
      orderBy: orderBy?.call(SlideTableCell.t),
      orderByList: orderByList?.call(SlideTableCell.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SlideTableCell] matching the given query parameters.
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
  Future<SlideTableCell?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTableCellTable>? where,
    int? offset,
    _isd.OrderByBuilder<SlideTableCellTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableCellTable>? orderByList,
    _isd.Transaction? transaction,
    SlideTableCellInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SlideTableCell>(
      where: where?.call(SlideTableCell.t),
      orderBy: orderBy?.call(SlideTableCell.t),
      orderByList: orderByList?.call(SlideTableCell.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SlideTableCell] by its [id] or null if no such row exists.
  Future<SlideTableCell?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SlideTableCellInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SlideTableCell>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SlideTableCell]s in the list and returns the inserted rows.
  ///
  /// The returned [SlideTableCell]s will have their `id` fields set.
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
  Future<List<SlideTableCell>> insert(
    _isd.DatabaseSession session,
    List<SlideTableCell> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SlideTableCell>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SlideTableCell] and returns the inserted row.
  ///
  /// The returned [SlideTableCell] will have its `id` field set.
  Future<SlideTableCell> insertRow(
    _isd.DatabaseSession session,
    SlideTableCell row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SlideTableCell>(row, transaction: transaction);
  }

  /// Upserts all [SlideTableCell]s in the list and returns the resulting rows.
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
  /// The returned [SlideTableCell]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideTableCell>> upsert(
    _isd.DatabaseSession session,
    List<SlideTableCell> rows, {
    required _isd.ColumnSelections<SlideTableCellTable> conflictColumns,
    _isd.ColumnSelections<SlideTableCellTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideTableCellTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SlideTableCell>(
      rows,
      conflictColumns: conflictColumns(SlideTableCell.t),
      updateColumns: updateColumns?.call(SlideTableCell.t),
      updateWhere: updateWhere?.call(SlideTableCell.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SlideTableCell] and returns the resulting row.
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
  /// The returned [SlideTableCell] will have its `id` field set.
  Future<SlideTableCell?> upsertRow(
    _isd.DatabaseSession session,
    SlideTableCell row, {
    required _isd.ColumnSelections<SlideTableCellTable> conflictColumns,
    _isd.ColumnSelections<SlideTableCellTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideTableCellTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SlideTableCell>(
      row,
      conflictColumns: conflictColumns(SlideTableCell.t),
      updateColumns: updateColumns?.call(SlideTableCell.t),
      updateWhere: updateWhere?.call(SlideTableCell.t),
      transaction: transaction,
    );
  }

  /// Updates all [SlideTableCell]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideTableCell>> update(
    _isd.DatabaseSession session,
    List<SlideTableCell> rows, {
    _isd.ColumnSelections<SlideTableCellTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SlideTableCell>(
      rows,
      columns: columns?.call(SlideTableCell.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SlideTableCell]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SlideTableCell> updateRow(
    _isd.DatabaseSession session,
    SlideTableCell row, {
    _isd.ColumnSelections<SlideTableCellTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SlideTableCell>(
      row,
      columns: columns?.call(SlideTableCell.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SlideTableCell] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SlideTableCell?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SlideTableCellUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SlideTableCell>(
      id,
      columnValues: columnValues(SlideTableCell.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SlideTableCell]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideTableCell>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SlideTableCellUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<SlideTableCellTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideTableCellTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableCellTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SlideTableCell>(
      columnValues: columnValues(SlideTableCell.t.updateTable),
      where: where(SlideTableCell.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideTableCell.t),
      orderByList: orderByList?.call(SlideTableCell.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SlideTableCell]s in the list and returns the deleted rows.
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
  Future<List<SlideTableCell>> delete(
    _isd.DatabaseSession session,
    List<SlideTableCell> rows, {
    _isd.OrderByBuilder<SlideTableCellTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableCellTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SlideTableCell>(
      rows,
      orderBy: orderBy?.call(SlideTableCell.t),
      orderByList: orderByList?.call(SlideTableCell.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SlideTableCell].
  Future<SlideTableCell> deleteRow(
    _isd.DatabaseSession session,
    SlideTableCell row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SlideTableCell>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideTableCell>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideTableCellTable> where,
    _isd.OrderByBuilder<SlideTableCellTable>? orderBy,
    _isd.OrderByListBuilder<SlideTableCellTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SlideTableCell>(
      where: where(SlideTableCell.t),
      orderBy: orderBy?.call(SlideTableCell.t),
      orderByList: orderByList?.call(SlideTableCell.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideTableCellTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SlideTableCell>(
      where: where?.call(SlideTableCell.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SlideTableCell] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideTableCellTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SlideTableCell>(
      where: where(SlideTableCell.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SlideTableCellAttachRowRepository {
  const SlideTableCellAttachRowRepository._();

  /// Creates a relation between the given [SlideTableCell] and [SlideElement]
  /// by setting the [SlideTableCell]'s foreign key `elementId` to refer to the [SlideElement].
  Future<void> element(
    _isd.DatabaseSession session,
    SlideTableCell slideTableCell,
    _i810rwvy.SlideElement element, {
    _isd.Transaction? transaction,
  }) async {
    if (slideTableCell.id == null) {
      throw ArgumentError.notNull('slideTableCell.id');
    }
    if (element.id == null) {
      throw ArgumentError.notNull('element.id');
    }

    var $slideTableCell = slideTableCell.copyWith(elementId: element.id);
    await session.db.updateRow<SlideTableCell>(
      $slideTableCell,
      columns: [SlideTableCell.t.elementId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [SlideTableCell] and [SlideTableAxis]
  /// by setting the [SlideTableCell]'s foreign key `rowId` to refer to the [SlideTableAxis].
  Future<void> row(
    _isd.DatabaseSession session,
    SlideTableCell slideTableCell,
    _i810rwvy.SlideTableAxis row, {
    _isd.Transaction? transaction,
  }) async {
    if (slideTableCell.id == null) {
      throw ArgumentError.notNull('slideTableCell.id');
    }
    if (row.id == null) {
      throw ArgumentError.notNull('row.id');
    }

    var $slideTableCell = slideTableCell.copyWith(rowId: row.id);
    await session.db.updateRow<SlideTableCell>(
      $slideTableCell,
      columns: [SlideTableCell.t.rowId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [SlideTableCell] and [SlideTableAxis]
  /// by setting the [SlideTableCell]'s foreign key `columnId` to refer to the [SlideTableAxis].
  Future<void> column(
    _isd.DatabaseSession session,
    SlideTableCell slideTableCell,
    _i810rwvy.SlideTableAxis column, {
    _isd.Transaction? transaction,
  }) async {
    if (slideTableCell.id == null) {
      throw ArgumentError.notNull('slideTableCell.id');
    }
    if (column.id == null) {
      throw ArgumentError.notNull('column.id');
    }

    var $slideTableCell = slideTableCell.copyWith(columnId: column.id);
    await session.db.updateRow<SlideTableCell>(
      $slideTableCell,
      columns: [SlideTableCell.t.columnId],
      transaction: transaction,
    );
  }
}
