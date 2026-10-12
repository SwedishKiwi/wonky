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

/// A non-empty cell. Its id is always SheetsIds.cellId(sheetId, rowId, colId), so
/// concurrent writers of the same cell share one CRDT chain. Every format
/// attribute is its own column (field-level merge).
abstract class Cell
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  Cell._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.sheetId,
    this.sheet,
    required this.rowId,
    this.row,
    required this.columnId,
    this.column,
    this.content,
    this.note,
    this.numberFormat,
    this.fontFamily,
    this.fontSize,
    this.bold,
    this.italic,
    this.underline,
    this.strikethrough,
    this.textColor,
    this.fillColor,
    this.hAlign,
    this.vAlign,
    this.wrap,
    this.rotation,
    this.borderTop,
    this.borderRight,
    this.borderBottom,
    this.borderLeft,
    this.linkUrl,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       createdAt = createdAt ?? DateTime.now();

  factory Cell({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required _iss.UuidValue rowId,
    _i810rwvy.SheetRow? row,
    required _iss.UuidValue columnId,
    _i810rwvy.SheetColumn? column,
    String? content,
    String? note,
    String? numberFormat,
    String? fontFamily,
    double? fontSize,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    String? textColor,
    String? fillColor,
    _i810rwvy.HorizontalAlign? hAlign,
    _i810rwvy.VerticalAlign? vAlign,
    _i810rwvy.WrapStrategy? wrap,
    int? rotation,
    String? borderTop,
    String? borderRight,
    String? borderBottom,
    String? borderLeft,
    String? linkUrl,
    DateTime? createdAt,
  }) = _CellImpl;

  factory Cell.fromJson(Map<String, dynamic> jsonSerialization) {
    return Cell(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      sheetId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['sheetId'],
      ),
      sheet: jsonSerialization['sheet'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.Sheet>(
              jsonSerialization['sheet'],
            ),
      rowId: _iss.UuidValueJsonExtension.fromJson(jsonSerialization['rowId']),
      row: jsonSerialization['row'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.SheetRow>(
              jsonSerialization['row'],
            ),
      columnId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['columnId'],
      ),
      column: jsonSerialization['column'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.SheetColumn>(
              jsonSerialization['column'],
            ),
      content: jsonSerialization['content'] as String?,
      note: jsonSerialization['note'] as String?,
      numberFormat: jsonSerialization['numberFormat'] as String?,
      fontFamily: jsonSerialization['fontFamily'] as String?,
      fontSize: (jsonSerialization['fontSize'] as num?)?.toDouble(),
      bold: jsonSerialization['bold'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['bold']),
      italic: jsonSerialization['italic'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['italic']),
      underline: jsonSerialization['underline'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['underline']),
      strikethrough: jsonSerialization['strikethrough'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['strikethrough']),
      textColor: jsonSerialization['textColor'] as String?,
      fillColor: jsonSerialization['fillColor'] as String?,
      hAlign: jsonSerialization['hAlign'] == null
          ? null
          : _i810rwvy.HorizontalAlign.fromJson(
              (jsonSerialization['hAlign'] as String),
            ),
      vAlign: jsonSerialization['vAlign'] == null
          ? null
          : _i810rwvy.VerticalAlign.fromJson(
              (jsonSerialization['vAlign'] as String),
            ),
      wrap: jsonSerialization['wrap'] == null
          ? null
          : _i810rwvy.WrapStrategy.fromJson(
              (jsonSerialization['wrap'] as String),
            ),
      rotation: jsonSerialization['rotation'] as int?,
      borderTop: jsonSerialization['borderTop'] as String?,
      borderRight: jsonSerialization['borderRight'] as String?,
      borderBottom: jsonSerialization['borderBottom'] as String?,
      borderLeft: jsonSerialization['borderLeft'] as String?,
      linkUrl: jsonSerialization['linkUrl'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = CellTable();

  static const db = CellRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue sheetId;

  _i810rwvy.Sheet? sheet;

  _iss.UuidValue rowId;

  _i810rwvy.SheetRow? row;

  _iss.UuidValue columnId;

  _i810rwvy.SheetColumn? column;

  /// Typed encoding (=, n:, s:, b:, e:, r:); null = no value.
  String? content;

  /// Cell note (not a comment).
  String? note;

  String? numberFormat;

  String? fontFamily;

  double? fontSize;

  bool? bold;

  bool? italic;

  bool? underline;

  bool? strikethrough;

  /// "#RRGGBB" or "theme:accent3".
  String? textColor;

  String? fillColor;

  _i810rwvy.HorizontalAlign? hAlign;

  _i810rwvy.VerticalAlign? vAlign;

  _i810rwvy.WrapStrategy? wrap;

  /// -90..90 degrees; 255 = vertical stacked.
  int? rotation;

  /// "<style>|<color>" or "none".
  String? borderTop;

  String? borderRight;

  String? borderBottom;

  String? borderLeft;

  /// Whole-cell hyperlink.
  String? linkUrl;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [Cell]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  Cell copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedCell$sheet(),
    _iss.UuidValue? rowId,
    _i810rwvy.SheetRow? row = const _UndefinedCell$row(),
    _iss.UuidValue? columnId,
    _i810rwvy.SheetColumn? column = const _UndefinedCell$column(),
    String? content,
    String? note,
    String? numberFormat,
    String? fontFamily,
    double? fontSize,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    String? textColor,
    String? fillColor,
    _i810rwvy.HorizontalAlign? hAlign,
    _i810rwvy.VerticalAlign? vAlign,
    _i810rwvy.WrapStrategy? wrap,
    int? rotation,
    String? borderTop,
    String? borderRight,
    String? borderBottom,
    String? borderLeft,
    String? linkUrl,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Cell',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJson(),
      'rowId': rowId.toJson(),
      if (row != null) 'row': row?.toJson(),
      'columnId': columnId.toJson(),
      if (column != null) 'column': column?.toJson(),
      if (content != null) 'content': content,
      if (note != null) 'note': note,
      if (numberFormat != null) 'numberFormat': numberFormat,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (fontSize != null) 'fontSize': fontSize,
      if (bold != null) 'bold': bold,
      if (italic != null) 'italic': italic,
      if (underline != null) 'underline': underline,
      if (strikethrough != null) 'strikethrough': strikethrough,
      if (textColor != null) 'textColor': textColor,
      if (fillColor != null) 'fillColor': fillColor,
      if (hAlign != null) 'hAlign': hAlign?.toJson(),
      if (vAlign != null) 'vAlign': vAlign?.toJson(),
      if (wrap != null) 'wrap': wrap?.toJson(),
      if (rotation != null) 'rotation': rotation,
      if (borderTop != null) 'borderTop': borderTop,
      if (borderRight != null) 'borderRight': borderRight,
      if (borderBottom != null) 'borderBottom': borderBottom,
      if (borderLeft != null) 'borderLeft': borderLeft,
      if (linkUrl != null) 'linkUrl': linkUrl,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Cell',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'sheetId': sheetId.toJson(),
      if (sheet != null) 'sheet': sheet?.toJsonForProtocol(),
      'rowId': rowId.toJson(),
      if (row != null) 'row': row?.toJsonForProtocol(),
      'columnId': columnId.toJson(),
      if (column != null) 'column': column?.toJsonForProtocol(),
      if (content != null) 'content': content,
      if (note != null) 'note': note,
      if (numberFormat != null) 'numberFormat': numberFormat,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (fontSize != null) 'fontSize': fontSize,
      if (bold != null) 'bold': bold,
      if (italic != null) 'italic': italic,
      if (underline != null) 'underline': underline,
      if (strikethrough != null) 'strikethrough': strikethrough,
      if (textColor != null) 'textColor': textColor,
      if (fillColor != null) 'fillColor': fillColor,
      if (hAlign != null) 'hAlign': hAlign?.toJson(),
      if (vAlign != null) 'vAlign': vAlign?.toJson(),
      if (wrap != null) 'wrap': wrap?.toJson(),
      if (rotation != null) 'rotation': rotation,
      if (borderTop != null) 'borderTop': borderTop,
      if (borderRight != null) 'borderRight': borderRight,
      if (borderBottom != null) 'borderBottom': borderBottom,
      if (borderLeft != null) 'borderLeft': borderLeft,
      if (linkUrl != null) 'linkUrl': linkUrl,
      'createdAt': createdAt.toJson(),
    };
  }

  static CellInclude include({
    _i810rwvy.SheetInclude? sheet,
    _i810rwvy.SheetRowInclude? row,
    _i810rwvy.SheetColumnInclude? column,
  }) {
    return CellInclude._(sheet: sheet, row: row, column: column);
  }

  static CellIncludeList includeList({
    _isd.WhereExpressionBuilder<CellTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CellTable>? orderBy,
    _isd.OrderByListBuilder<CellTable>? orderByList,
    CellInclude? include,
  }) {
    return CellIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Cell.t),
      orderByList: orderByList?.call(Cell.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedCell$sheet extends _iss.UndefinedSentinel
    implements _i810rwvy.Sheet {
  const _UndefinedCell$sheet();
}

class _UndefinedCell$row extends _iss.UndefinedSentinel
    implements _i810rwvy.SheetRow {
  const _UndefinedCell$row();
}

class _UndefinedCell$column extends _iss.UndefinedSentinel
    implements _i810rwvy.SheetColumn {
  const _UndefinedCell$column();
}

class _CellImpl extends Cell {
  _CellImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required _iss.UuidValue sheetId,
    _i810rwvy.Sheet? sheet,
    required _iss.UuidValue rowId,
    _i810rwvy.SheetRow? row,
    required _iss.UuidValue columnId,
    _i810rwvy.SheetColumn? column,
    String? content,
    String? note,
    String? numberFormat,
    String? fontFamily,
    double? fontSize,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    String? textColor,
    String? fillColor,
    _i810rwvy.HorizontalAlign? hAlign,
    _i810rwvy.VerticalAlign? vAlign,
    _i810rwvy.WrapStrategy? wrap,
    int? rotation,
    String? borderTop,
    String? borderRight,
    String? borderBottom,
    String? borderLeft,
    String? linkUrl,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         sheetId: sheetId,
         sheet: sheet,
         rowId: rowId,
         row: row,
         columnId: columnId,
         column: column,
         content: content,
         note: note,
         numberFormat: numberFormat,
         fontFamily: fontFamily,
         fontSize: fontSize,
         bold: bold,
         italic: italic,
         underline: underline,
         strikethrough: strikethrough,
         textColor: textColor,
         fillColor: fillColor,
         hAlign: hAlign,
         vAlign: vAlign,
         wrap: wrap,
         rotation: rotation,
         borderTop: borderTop,
         borderRight: borderRight,
         borderBottom: borderBottom,
         borderLeft: borderLeft,
         linkUrl: linkUrl,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Cell]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  Cell copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? sheetId,
    _i810rwvy.Sheet? sheet = const _UndefinedCell$sheet(),
    _iss.UuidValue? rowId,
    _i810rwvy.SheetRow? row = const _UndefinedCell$row(),
    _iss.UuidValue? columnId,
    _i810rwvy.SheetColumn? column = const _UndefinedCell$column(),
    Object? content = _Undefined,
    Object? note = _Undefined,
    Object? numberFormat = _Undefined,
    Object? fontFamily = _Undefined,
    Object? fontSize = _Undefined,
    Object? bold = _Undefined,
    Object? italic = _Undefined,
    Object? underline = _Undefined,
    Object? strikethrough = _Undefined,
    Object? textColor = _Undefined,
    Object? fillColor = _Undefined,
    Object? hAlign = _Undefined,
    Object? vAlign = _Undefined,
    Object? wrap = _Undefined,
    Object? rotation = _Undefined,
    Object? borderTop = _Undefined,
    Object? borderRight = _Undefined,
    Object? borderBottom = _Undefined,
    Object? borderLeft = _Undefined,
    Object? linkUrl = _Undefined,
    DateTime? createdAt,
  }) {
    return Cell(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      sheetId: sheetId ?? this.sheetId,
      sheet: sheet is _iss.UndefinedSentinel ? this.sheet?.copyWith() : sheet,
      rowId: rowId ?? this.rowId,
      row: row is _iss.UndefinedSentinel ? this.row?.copyWith() : row,
      columnId: columnId ?? this.columnId,
      column: column is _iss.UndefinedSentinel
          ? this.column?.copyWith()
          : column,
      content: content is String? ? content : this.content,
      note: note is String? ? note : this.note,
      numberFormat: numberFormat is String? ? numberFormat : this.numberFormat,
      fontFamily: fontFamily is String? ? fontFamily : this.fontFamily,
      fontSize: fontSize is double? ? fontSize : this.fontSize,
      bold: bold is bool? ? bold : this.bold,
      italic: italic is bool? ? italic : this.italic,
      underline: underline is bool? ? underline : this.underline,
      strikethrough: strikethrough is bool?
          ? strikethrough
          : this.strikethrough,
      textColor: textColor is String? ? textColor : this.textColor,
      fillColor: fillColor is String? ? fillColor : this.fillColor,
      hAlign: hAlign is _i810rwvy.HorizontalAlign? ? hAlign : this.hAlign,
      vAlign: vAlign is _i810rwvy.VerticalAlign? ? vAlign : this.vAlign,
      wrap: wrap is _i810rwvy.WrapStrategy? ? wrap : this.wrap,
      rotation: rotation is int? ? rotation : this.rotation,
      borderTop: borderTop is String? ? borderTop : this.borderTop,
      borderRight: borderRight is String? ? borderRight : this.borderRight,
      borderBottom: borderBottom is String? ? borderBottom : this.borderBottom,
      borderLeft: borderLeft is String? ? borderLeft : this.borderLeft,
      linkUrl: linkUrl is String? ? linkUrl : this.linkUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CellUpdateTable extends _isd.UpdateTable<CellTable> {
  CellUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> sheetId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.sheetId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> rowId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.rowId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> columnId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.columnId, value);

  _isd.ColumnValue<String, String> content(String? value) =>
      _isd.ColumnValue(table.content, value);

  _isd.ColumnValue<String, String> note(String? value) =>
      _isd.ColumnValue(table.note, value);

  _isd.ColumnValue<String, String> numberFormat(String? value) =>
      _isd.ColumnValue(table.numberFormat, value);

  _isd.ColumnValue<String, String> fontFamily(String? value) =>
      _isd.ColumnValue(table.fontFamily, value);

  _isd.ColumnValue<double, double> fontSize(double? value) =>
      _isd.ColumnValue(table.fontSize, value);

  _isd.ColumnValue<bool, bool> bold(bool? value) =>
      _isd.ColumnValue(table.bold, value);

  _isd.ColumnValue<bool, bool> italic(bool? value) =>
      _isd.ColumnValue(table.italic, value);

  _isd.ColumnValue<bool, bool> underline(bool? value) =>
      _isd.ColumnValue(table.underline, value);

  _isd.ColumnValue<bool, bool> strikethrough(bool? value) =>
      _isd.ColumnValue(table.strikethrough, value);

  _isd.ColumnValue<String, String> textColor(String? value) =>
      _isd.ColumnValue(table.textColor, value);

  _isd.ColumnValue<String, String> fillColor(String? value) =>
      _isd.ColumnValue(table.fillColor, value);

  _isd.ColumnValue<_i810rwvy.HorizontalAlign, _i810rwvy.HorizontalAlign> hAlign(
    _i810rwvy.HorizontalAlign? value,
  ) => _isd.ColumnValue(table.hAlign, value);

  _isd.ColumnValue<_i810rwvy.VerticalAlign, _i810rwvy.VerticalAlign> vAlign(
    _i810rwvy.VerticalAlign? value,
  ) => _isd.ColumnValue(table.vAlign, value);

  _isd.ColumnValue<_i810rwvy.WrapStrategy, _i810rwvy.WrapStrategy> wrap(
    _i810rwvy.WrapStrategy? value,
  ) => _isd.ColumnValue(table.wrap, value);

  _isd.ColumnValue<int, int> rotation(int? value) =>
      _isd.ColumnValue(table.rotation, value);

  _isd.ColumnValue<String, String> borderTop(String? value) =>
      _isd.ColumnValue(table.borderTop, value);

  _isd.ColumnValue<String, String> borderRight(String? value) =>
      _isd.ColumnValue(table.borderRight, value);

  _isd.ColumnValue<String, String> borderBottom(String? value) =>
      _isd.ColumnValue(table.borderBottom, value);

  _isd.ColumnValue<String, String> borderLeft(String? value) =>
      _isd.ColumnValue(table.borderLeft, value);

  _isd.ColumnValue<String, String> linkUrl(String? value) =>
      _isd.ColumnValue(table.linkUrl, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class CellTable extends _isd.Table<_iss.UuidValue> {
  CellTable({super.tableRelation}) : super(tableName: 'cell') {
    updateTable = CellUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    sheetId = _isd.ColumnUuid('sheetId', this);
    rowId = _isd.ColumnUuid('rowId', this);
    columnId = _isd.ColumnUuid('columnId', this);
    content = _isd.ColumnString('content', this);
    note = _isd.ColumnString('note', this);
    numberFormat = _isd.ColumnString('numberFormat', this);
    fontFamily = _isd.ColumnString('fontFamily', this);
    fontSize = _isd.ColumnDouble('fontSize', this);
    bold = _isd.ColumnBool('bold', this);
    italic = _isd.ColumnBool('italic', this);
    underline = _isd.ColumnBool('underline', this);
    strikethrough = _isd.ColumnBool('strikethrough', this);
    textColor = _isd.ColumnString('textColor', this);
    fillColor = _isd.ColumnString('fillColor', this);
    hAlign = _isd.ColumnEnum('hAlign', this, _isd.EnumSerialization.byName);
    vAlign = _isd.ColumnEnum('vAlign', this, _isd.EnumSerialization.byName);
    wrap = _isd.ColumnEnum('wrap', this, _isd.EnumSerialization.byName);
    rotation = _isd.ColumnInt('rotation', this);
    borderTop = _isd.ColumnString('borderTop', this);
    borderRight = _isd.ColumnString('borderRight', this);
    borderBottom = _isd.ColumnString('borderBottom', this);
    borderLeft = _isd.ColumnString('borderLeft', this);
    linkUrl = _isd.ColumnString('linkUrl', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final CellUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid sheetId;

  _i810rwvy.SheetTable? _sheet;

  late final _isd.ColumnUuid rowId;

  _i810rwvy.SheetRowTable? _row;

  late final _isd.ColumnUuid columnId;

  _i810rwvy.SheetColumnTable? _column;

  /// Typed encoding (=, n:, s:, b:, e:, r:); null = no value.
  late final _isd.ColumnString content;

  /// Cell note (not a comment).
  late final _isd.ColumnString note;

  late final _isd.ColumnString numberFormat;

  late final _isd.ColumnString fontFamily;

  late final _isd.ColumnDouble fontSize;

  late final _isd.ColumnBool bold;

  late final _isd.ColumnBool italic;

  late final _isd.ColumnBool underline;

  late final _isd.ColumnBool strikethrough;

  /// "#RRGGBB" or "theme:accent3".
  late final _isd.ColumnString textColor;

  late final _isd.ColumnString fillColor;

  late final _isd.ColumnEnum<_i810rwvy.HorizontalAlign> hAlign;

  late final _isd.ColumnEnum<_i810rwvy.VerticalAlign> vAlign;

  late final _isd.ColumnEnum<_i810rwvy.WrapStrategy> wrap;

  /// -90..90 degrees; 255 = vertical stacked.
  late final _isd.ColumnInt rotation;

  /// "<style>|<color>" or "none".
  late final _isd.ColumnString borderTop;

  late final _isd.ColumnString borderRight;

  late final _isd.ColumnString borderBottom;

  late final _isd.ColumnString borderLeft;

  /// Whole-cell hyperlink.
  late final _isd.ColumnString linkUrl;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SheetTable get sheet {
    if (_sheet != null) return _sheet!;
    _sheet = _isd.createRelationTable(
      relationFieldName: 'sheet',
      field: Cell.t.sheetId,
      foreignField: _i810rwvy.Sheet.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SheetTable(tableRelation: foreignTableRelation),
    );
    return _sheet!;
  }

  _i810rwvy.SheetRowTable get row {
    if (_row != null) return _row!;
    _row = _isd.createRelationTable(
      relationFieldName: 'row',
      field: Cell.t.rowId,
      foreignField: _i810rwvy.SheetRow.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SheetRowTable(tableRelation: foreignTableRelation),
    );
    return _row!;
  }

  _i810rwvy.SheetColumnTable get column {
    if (_column != null) return _column!;
    _column = _isd.createRelationTable(
      relationFieldName: 'column',
      field: Cell.t.columnId,
      foreignField: _i810rwvy.SheetColumn.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SheetColumnTable(tableRelation: foreignTableRelation),
    );
    return _column!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    sheetId,
    rowId,
    columnId,
    content,
    note,
    numberFormat,
    fontFamily,
    fontSize,
    bold,
    italic,
    underline,
    strikethrough,
    textColor,
    fillColor,
    hAlign,
    vAlign,
    wrap,
    rotation,
    borderTop,
    borderRight,
    borderBottom,
    borderLeft,
    linkUrl,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'sheet') {
      return sheet;
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

class CellInclude extends _isd.IncludeObject {
  CellInclude._({
    _i810rwvy.SheetInclude? sheet,
    _i810rwvy.SheetRowInclude? row,
    _i810rwvy.SheetColumnInclude? column,
  }) {
    _sheet = sheet;
    _row = row;
    _column = column;
  }

  _i810rwvy.SheetInclude? _sheet;

  _i810rwvy.SheetRowInclude? _row;

  _i810rwvy.SheetColumnInclude? _column;

  @override
  Map<String, _isd.Include?> get includes => {
    'sheet': _sheet,
    'row': _row,
    'column': _column,
  };

  @override
  _isd.Table<_iss.UuidValue> get table => Cell.t;
}

class CellIncludeList extends _isd.IncludeList {
  CellIncludeList._({
    _isd.WhereExpressionBuilder<CellTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Cell.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => Cell.t;
}

class CellRepository {
  const CellRepository._();

  final attachRow = const CellAttachRowRepository._();

  /// Returns a list of [Cell]s matching the given query parameters.
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
  Future<List<Cell>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CellTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CellTable>? orderBy,
    _isd.OrderByListBuilder<CellTable>? orderByList,
    _isd.Transaction? transaction,
    CellInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Cell>(
      where: where?.call(Cell.t),
      orderBy: orderBy?.call(Cell.t),
      orderByList: orderByList?.call(Cell.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Cell]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Cell.t`.
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
  _ida.Stream<List<Cell>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CellTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CellTable>? orderBy,
    _isd.OrderByListBuilder<CellTable>? orderByList,
    CellInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Cell>(
      where: where?.call(Cell.t),
      orderBy: orderBy?.call(Cell.t),
      orderByList: orderByList?.call(Cell.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Cell] matching the given query parameters.
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
  Future<Cell?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CellTable>? where,
    int? offset,
    _isd.OrderByBuilder<CellTable>? orderBy,
    _isd.OrderByListBuilder<CellTable>? orderByList,
    _isd.Transaction? transaction,
    CellInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Cell>(
      where: where?.call(Cell.t),
      orderBy: orderBy?.call(Cell.t),
      orderByList: orderByList?.call(Cell.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Cell] by its [id] or null if no such row exists.
  Future<Cell?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    CellInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Cell>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Cell]s in the list and returns the inserted rows.
  ///
  /// The returned [Cell]s will have their `id` fields set.
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
  Future<List<Cell>> insert(
    _isd.DatabaseSession session,
    List<Cell> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Cell>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Cell] and returns the inserted row.
  ///
  /// The returned [Cell] will have its `id` field set.
  Future<Cell> insertRow(
    _isd.DatabaseSession session,
    Cell row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<Cell>(row, transaction: transaction);
  }

  /// Upserts all [Cell]s in the list and returns the resulting rows.
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
  /// The returned [Cell]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Cell>> upsert(
    _isd.DatabaseSession session,
    List<Cell> rows, {
    required _isd.ColumnSelections<CellTable> conflictColumns,
    _isd.ColumnSelections<CellTable>? updateColumns,
    _isd.WhereExpressionBuilder<CellTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Cell>(
      rows,
      conflictColumns: conflictColumns(Cell.t),
      updateColumns: updateColumns?.call(Cell.t),
      updateWhere: updateWhere?.call(Cell.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Cell] and returns the resulting row.
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
  /// The returned [Cell] will have its `id` field set.
  Future<Cell?> upsertRow(
    _isd.DatabaseSession session,
    Cell row, {
    required _isd.ColumnSelections<CellTable> conflictColumns,
    _isd.ColumnSelections<CellTable>? updateColumns,
    _isd.WhereExpressionBuilder<CellTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Cell>(
      row,
      conflictColumns: conflictColumns(Cell.t),
      updateColumns: updateColumns?.call(Cell.t),
      updateWhere: updateWhere?.call(Cell.t),
      transaction: transaction,
    );
  }

  /// Updates all [Cell]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Cell>> update(
    _isd.DatabaseSession session,
    List<Cell> rows, {
    _isd.ColumnSelections<CellTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Cell>(
      rows,
      columns: columns?.call(Cell.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Cell]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Cell> updateRow(
    _isd.DatabaseSession session,
    Cell row, {
    _isd.ColumnSelections<CellTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<Cell>(
      row,
      columns: columns?.call(Cell.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Cell] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Cell?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<CellUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<Cell>(
      id,
      columnValues: columnValues(Cell.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Cell]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Cell>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<CellUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<CellTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CellTable>? orderBy,
    _isd.OrderByListBuilder<CellTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Cell>(
      columnValues: columnValues(Cell.t.updateTable),
      where: where(Cell.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Cell.t),
      orderByList: orderByList?.call(Cell.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Cell]s in the list and returns the deleted rows.
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
  Future<List<Cell>> delete(
    _isd.DatabaseSession session,
    List<Cell> rows, {
    _isd.OrderByBuilder<CellTable>? orderBy,
    _isd.OrderByListBuilder<CellTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Cell>(
      rows,
      orderBy: orderBy?.call(Cell.t),
      orderByList: orderByList?.call(Cell.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Cell].
  Future<Cell> deleteRow(
    _isd.DatabaseSession session,
    Cell row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Cell>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Cell>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CellTable> where,
    _isd.OrderByBuilder<CellTable>? orderBy,
    _isd.OrderByListBuilder<CellTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Cell>(
      where: where(Cell.t),
      orderBy: orderBy?.call(Cell.t),
      orderByList: orderByList?.call(Cell.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CellTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<Cell>(
      where: where?.call(Cell.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Cell] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CellTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Cell>(
      where: where(Cell.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CellAttachRowRepository {
  const CellAttachRowRepository._();

  /// Creates a relation between the given [Cell] and [Sheet]
  /// by setting the [Cell]'s foreign key `sheetId` to refer to the [Sheet].
  Future<void> sheet(
    _isd.DatabaseSession session,
    Cell cell,
    _i810rwvy.Sheet sheet, {
    _isd.Transaction? transaction,
  }) async {
    if (cell.id == null) {
      throw ArgumentError.notNull('cell.id');
    }
    if (sheet.id == null) {
      throw ArgumentError.notNull('sheet.id');
    }

    var $cell = cell.copyWith(sheetId: sheet.id);
    await session.db.updateRow<Cell>(
      $cell,
      columns: [Cell.t.sheetId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [Cell] and [SheetRow]
  /// by setting the [Cell]'s foreign key `rowId` to refer to the [SheetRow].
  Future<void> row(
    _isd.DatabaseSession session,
    Cell cell,
    _i810rwvy.SheetRow row, {
    _isd.Transaction? transaction,
  }) async {
    if (cell.id == null) {
      throw ArgumentError.notNull('cell.id');
    }
    if (row.id == null) {
      throw ArgumentError.notNull('row.id');
    }

    var $cell = cell.copyWith(rowId: row.id);
    await session.db.updateRow<Cell>(
      $cell,
      columns: [Cell.t.rowId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [Cell] and [SheetColumn]
  /// by setting the [Cell]'s foreign key `columnId` to refer to the [SheetColumn].
  Future<void> column(
    _isd.DatabaseSession session,
    Cell cell,
    _i810rwvy.SheetColumn column, {
    _isd.Transaction? transaction,
  }) async {
    if (cell.id == null) {
      throw ArgumentError.notNull('cell.id');
    }
    if (column.id == null) {
      throw ArgumentError.notNull('column.id');
    }

    var $cell = cell.copyWith(columnId: column.id);
    await session.db.updateRow<Cell>(
      $cell,
      columns: [Cell.t.columnId],
      transaction: transaction,
    );
  }
}
