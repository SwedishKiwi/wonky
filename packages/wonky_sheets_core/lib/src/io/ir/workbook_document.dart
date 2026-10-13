import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../content/rich_text.dart';
import '../../format/attributes.dart';
import '../../format/theme.dart';
import 'import_warning.dart';
import 'ir_range.dart';
import 'sparse_grid.dart';

/// A cell value of the IR (11 §1.1). Dates are numbers on the Wonky epoch
/// (serial days since 1899-12-30).
sealed class IrValue {
  const IrValue();

  /// From a model [CellValue] (`EmptyValue` → null).
  static IrValue? fromCellValue(CellValue v) => switch (v) {
    EmptyValue() => null,
    NumberValue(:final number) => IrNumber(number),
    TextValue(:final text) => IrText(text),
    BoolValue(:final value) => IrBool(value),
    ErrorValue(:final kind) => IrError(kind),
  };

  /// From decoded literal content (formulas → null).
  static IrValue? fromContent(CellContent? c) => switch (c) {
    null || FormulaContent() => null,
    NumberContent(:final number) => IrNumber(number),
    TextContent(:final text) => IrText(text),
    BoolContent(:final value) => IrBool(value),
    ErrorContent(:final kind) => IrError(kind),
    RichTextContent(:final rich) => IrRich(rich),
  };

  /// The scalar value.
  CellValue toCellValue();

  /// Literal content for this value.
  CellContent toContent();

  /// Plain text (rich text → its text; numbers shortest form).
  String get plainText;
}

/// A number (dates/times included).
final class IrNumber extends IrValue {
  /// Creates a number.
  const IrNumber(this.number);

  /// The value.
  final double number;

  @override
  CellValue toCellValue() => NumberValue(number);

  @override
  CellContent toContent() => NumberContent(number);

  @override
  String get plainText => CellContent.formatNumber(number);

  @override
  bool operator ==(Object other) => other is IrNumber && other.number == number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'IrNumber($number)';
}

/// Text.
final class IrText extends IrValue {
  /// Creates text.
  const IrText(this.text);

  /// The text.
  final String text;

  @override
  CellValue toCellValue() => TextValue(text);

  @override
  CellContent toContent() => TextContent(text);

  @override
  String get plainText => text;

  @override
  bool operator ==(Object other) => other is IrText && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'IrText($text)';
}

/// A boolean.
final class IrBool extends IrValue {
  /// Creates a boolean.
  const IrBool(this.value);

  /// The value.
  final bool value;

  @override
  CellValue toCellValue() => BoolValue(value);

  @override
  CellContent toContent() => BoolContent(value);

  @override
  String get plainText => value ? 'TRUE' : 'FALSE';

  @override
  bool operator ==(Object other) => other is IrBool && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'IrBool($value)';
}

/// An error literal.
final class IrError extends IrValue {
  /// Creates an error.
  const IrError(this.kind);

  /// The kind.
  final CellErrorKind kind;

  @override
  CellValue toCellValue() => ErrorValue(kind);

  @override
  CellContent toContent() => ErrorContent(kind);

  @override
  String get plainText => kind.literal;

  @override
  bool operator ==(Object other) => other is IrError && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'IrError(${kind.literal})';
}

/// Rich text (runs use the [RichRunKeys] format keys).
final class IrRich extends IrValue {
  /// Creates rich text.
  const IrRich(this.rich);

  /// The rich text.
  final RichText rich;

  @override
  CellValue toCellValue() => TextValue(rich.text);

  @override
  CellContent toContent() => RichTextContent(rich);

  @override
  String get plainText => rich.text;

  @override
  bool operator ==(Object other) => other is IrRich && other.rich == rich;

  @override
  int get hashCode => rich.hashCode;

  @override
  String toString() => 'IrRich(${rich.text})';
}

/// Formula kinds of the IR.
enum IrFormulaKind {
  /// A plain formula.
  normal,

  /// A legacy (CSE) array formula over [IrCell.arrayRef]; Wonky stores it as
  /// `ARRAYFORMULA(...)`.
  array,

  /// An Excel 365 dynamic-array (spilling) formula.
  dynamicArray,
}

/// A cell format of the IR: the Wonky format attributes (without `linkUrl`,
/// links live on [IrCell.link]) plus format-specific extras kept for
/// round-trips (`indent`, `shrinkToFit`, `locked`, …).
final class IrFormat {
  /// Creates a format.
  IrFormat(CellFormat attrs, [Map<String, Object?> extras = const {}])
    : attrs = attrs.has(FormatAttr.linkUrl)
          ? attrs.without(const [FormatAttr.linkUrl])
          : attrs,
      extras = Map.unmodifiable(
        Map.fromEntries(
          extras.entries.where((e) => e.value != null).toList()
            ..sort((a, b) => a.key.compareTo(b.key)),
        ),
      );

  /// The empty format.
  static final IrFormat empty = IrFormat(CellFormat.empty);

  /// Format attributes.
  final CellFormat attrs;

  /// Extra properties (JSON-encodable, sorted keys).
  final Map<String, Object?> extras;

  /// Whether nothing is set.
  bool get isEmpty => attrs.isEmpty && extras.isEmpty;

  /// Attribute value.
  Object? operator [](FormatAttr a) => attrs[a];

  /// Copy with attribute values set (null clears).
  IrFormat withValues(Map<FormatAttr, Object?> values) =>
      IrFormat(attrs.withValues(values), extras);

  /// Copy with other extras.
  IrFormat withExtras(Map<String, Object?> extras) => IrFormat(attrs, extras);

  static const _eq = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is IrFormat &&
      other.attrs == attrs &&
      _eq.equals(other.extras, extras);

  @override
  int get hashCode => Object.hash(attrs, _eq.hash(extras));

  @override
  String toString() =>
      'IrFormat(${attrs.toMap()}${extras.isEmpty ? '' : ', $extras'})';
}

/// The deduplicated format table of a [WorkbookDocument] (like XLSX
/// `cellXfs`). Index 0 is always the empty format.
final class IrFormatTable {
  /// Creates a table holding only the empty format.
  IrFormatTable() {
    _list.add(IrFormat.empty);
    _index[IrFormat.empty] = 0;
  }

  final List<IrFormat> _list = [];
  final Map<IrFormat, int> _index = {};

  /// Interns [f] and returns its index.
  int intern(IrFormat f) {
    if (f.isEmpty) return 0;
    final i = _index[f];
    if (i != null) return i;
    _list.add(f);
    _index[f] = _list.length - 1;
    return _list.length - 1;
  }

  /// Interns a [CellFormat] (no extras).
  int internAttrs(CellFormat f) => f.isEmpty ? 0 : intern(IrFormat(f));

  /// The format at [index] (out of range → empty).
  IrFormat operator [](int index) =>
      index > 0 && index < _list.length ? _list[index] : IrFormat.empty;

  /// Number of formats (incl. the empty one).
  int get length => _list.length;

  /// All formats.
  List<IrFormat> get formats => List.unmodifiable(_list);
}

/// One cell of the IR.
final class IrCell {
  /// Creates a cell.
  const IrCell({
    this.value,
    this.formulaA1,
    this.formulaKind = IrFormulaKind.normal,
    this.arrayRef,
    this.format = 0,
    this.note,
    this.link,
    this.blockedFormulaA1,
  });

  /// Literal value, or the cached result of [formulaA1].
  final IrValue? value;

  /// Wonky A1 formula (canonical en_US separators), without the leading `=`.
  final String? formulaA1;

  /// Formula kind.
  final IrFormulaKind formulaKind;

  /// Spill/array range of array formulas (anchored at this cell).
  final GridRect? arrayRef;

  /// Index into [WorkbookDocument.formats] (0 = no format).
  final int format;

  /// Cell note.
  final String? note;

  /// Whole-cell link: URL, or `#<A1 reference>` for internal links
  /// (`#'Sheet 2'!A1`).
  final String? link;

  /// A formula that was imported disabled (CSV external-data functions,
  /// shown as `#BLOCKED!` until allowed, 11 §4.3).
  final String? blockedFormulaA1;

  /// Whether nothing is set.
  bool get isEmpty =>
      value == null &&
      formulaA1 == null &&
      format == 0 &&
      note == null &&
      link == null;

  /// Copy with changes.
  IrCell copyWith({
    IrValue? value,
    String? formulaA1,
    IrFormulaKind? formulaKind,
    GridRect? arrayRef,
    int? format,
    String? note,
    String? link,
    bool clearValue = false,
    bool clearFormula = false,
    bool clearNote = false,
    bool clearLink = false,
  }) => IrCell(
    value: clearValue ? null : value ?? this.value,
    formulaA1: clearFormula ? null : formulaA1 ?? this.formulaA1,
    formulaKind: clearFormula
        ? IrFormulaKind.normal
        : formulaKind ?? this.formulaKind,
    arrayRef: clearFormula ? null : arrayRef ?? this.arrayRef,
    format: format ?? this.format,
    note: clearNote ? null : note ?? this.note,
    link: clearLink ? null : link ?? this.link,
    blockedFormulaA1: blockedFormulaA1,
  );

  @override
  bool operator ==(Object other) =>
      other is IrCell &&
      other.value == value &&
      other.formulaA1 == formulaA1 &&
      other.formulaKind == formulaKind &&
      other.arrayRef == arrayRef &&
      other.format == format &&
      other.note == note &&
      other.link == link &&
      other.blockedFormulaA1 == blockedFormulaA1;

  @override
  int get hashCode =>
      Object.hash(value, formulaA1, formulaKind, arrayRef, format, note, link);

  @override
  String toString() =>
      'IrCell(${formulaA1 != null ? '=$formulaA1 ' : ''}$value)';
}

/// Row or column properties.
final class IrDim {
  /// Creates properties.
  const IrDim({
    this.size,
    this.hidden = false,
    this.outlineLevel = 0,
    this.collapsed = false,
    this.format = 0,
  });

  /// Height/width in px (null = default/automatic).
  final double? size;

  /// User-hidden.
  final bool hidden;

  /// Outline (group) level 0–8.
  final int outlineLevel;

  /// Whether the group ending at this row/column is collapsed.
  final bool collapsed;

  /// Default format (index into [WorkbookDocument.formats]).
  final int format;

  /// Whether every property is default.
  bool get isDefault =>
      size == null && !hidden && outlineLevel == 0 && !collapsed && format == 0;

  /// Copy with changes.
  IrDim copyWith({
    double? size,
    bool? hidden,
    int? outlineLevel,
    bool? collapsed,
    int? format,
    bool clearSize = false,
  }) => IrDim(
    size: clearSize ? null : size ?? this.size,
    hidden: hidden ?? this.hidden,
    outlineLevel: outlineLevel ?? this.outlineLevel,
    collapsed: collapsed ?? this.collapsed,
    format: format ?? this.format,
  );

  @override
  bool operator ==(Object other) =>
      other is IrDim &&
      other.size == size &&
      other.hidden == hidden &&
      other.outlineLevel == outlineLevel &&
      other.collapsed == collapsed &&
      other.format == format;

  @override
  int get hashCode =>
      Object.hash(size, hidden, outlineLevel, collapsed, format);
}

/// A data validation rule. [criteria] uses the Wonky `criteriaJson` shape
/// (07 §6.1) with formula values in A1 form (`{"v": "=A1>0"}`) and
/// `oneOfRange.range` as A1 text (`"Lists!$A$1:$A$9"`).
final class IrDataValidation {
  /// Creates a rule.
  IrDataValidation({
    required this.ranges,
    required this.criteria,
    this.strict = false,
    this.showDropdown = true,
    this.displayStyle,
    this.helpText,
    Map<String, Object?>? extras,
  }) : extras = extras ?? {};

  /// Ranges; formulas are relative to the top-left cell of the first one.
  final List<IrRange> ranges;
  final Map<String, Object?> criteria;
  final bool strict;
  final bool showDropdown;
  final String? displayStyle;
  final String? helpText;

  /// Format-specific data kept for round-trips (`xlsxType`, `prompt`, …).
  final Map<String, Object?> extras;
}

/// A conditional format rule (06 §15.1 `ruleJson` shape, formulas in A1 form
/// with `=`). Priority = list order in [IrSheet.conditionalFormats].
final class IrConditionalFormat {
  /// Creates a rule.
  IrConditionalFormat({
    required this.ranges,
    required this.rule,
    this.enabled = true,
    Map<String, Object?>? extras,
  }) : extras = extras ?? {};

  final List<IrRange> ranges;
  final Map<String, Object?> rule;
  final bool enabled;

  /// Parts not rendered by Wonky but kept for export (`numberFormat`,
  /// borders of an XLSX dxf, …).
  final Map<String, Object?> extras;
}

/// The basic filter of a sheet. [criteria] is keyed by column offset inside
/// [range] (0 = first column) with the 07 §3.2 criteria shape (conditions
/// in A1 form relative to the first data cell of the column).
final class IrFilter {
  /// Creates a filter.
  IrFilter({
    required this.range,
    Map<int, Map<String, Object?>>? criteria,
    List<Map<String, Object?>>? sort,
  }) : criteria = criteria ?? {},
       sort = sort ?? [];

  final IrRange range;
  final Map<int, Map<String, Object?>> criteria;

  /// `[{"col": offset, "ascending": bool}]`.
  final List<Map<String, Object?>> sort;
}

/// A named range or named formula.
final class IrNamedRange {
  /// Creates a named range.
  const IrNamedRange({
    required this.name,
    this.sheet,
    this.range,
    this.formulaA1,
    this.comment,
    this.hidden = false,
  });

  final String name;

  /// Sheet name of [range].
  final String? sheet;
  final IrRange? range;

  /// Named formula (A1, without `=`), when not a plain range.
  final String? formulaA1;
  final String? comment;
  final bool hidden;
}

/// Position and size of an object over the grid (px at 100 %).
final class IrAnchor {
  /// Creates an anchor.
  const IrAnchor({
    required this.row,
    required this.col,
    this.dx = 0,
    this.dy = 0,
    required this.width,
    required this.height,
  });

  final int row;
  final int col;
  final double dx;
  final double dy;
  final double width;
  final double height;

  /// JSON.
  Map<String, Object?> toJson() => {
    'row': row,
    'col': col,
    'dx': dx,
    'dy': dy,
    'width': width,
    'height': height,
  };
}

/// An image over cells.
final class IrImage {
  /// Creates an image.
  const IrImage({
    this.bytes,
    this.mimeType = 'image/png',
    required this.anchor,
    this.altText,
    this.title,
    this.fileUuid,
    this.name,
  });

  /// Image bytes (PNG/JPEG/GIF); null when only [fileUuid] is known.
  final Uint8List? bytes;
  final String mimeType;
  final IrAnchor anchor;
  final String? altText;
  final String? title;

  /// Stored file of an image read from a model.
  final String? fileUuid;

  /// Original part/file name.
  final String? name;
}

/// A chart over cells (ChartSpec-like map, 08 §20).
final class IrChart {
  /// Creates a chart.
  const IrChart({
    required this.anchor,
    required this.spec,
    this.title,
    this.altText,
  });

  final IrAnchor anchor;
  final Map<String, Object?> spec;
  final String? title;
  final String? altText;
}

/// One sheet of the IR.
final class IrSheet {
  /// Creates an empty sheet.
  IrSheet(this.name);

  /// Sheet name.
  String name;
  bool hidden = false;

  /// `#RRGGBB` or `theme:<key>`.
  String? tabColor;
  bool rtl = false;
  bool showGridlines = true;
  int frozenRows = 0;
  int frozenColumns = 0;

  /// Default sizes in px (null = Wonky defaults).
  double? defaultRowHeight;
  double? defaultColumnWidth;

  /// Row properties.
  final SparseAxis<IrDim> rows = SparseAxis();

  /// Column properties.
  final SparseAxis<IrDim> columns = SparseAxis();

  /// Cells.
  final SparseGrid<IrCell> cells = SparseGrid();

  final List<GridRect> merges = [];
  final List<IrDataValidation> validations = [];

  /// Conditional formats, highest priority first.
  final List<IrConditionalFormat> conditionalFormats = [];
  IrFilter? autoFilter;
  final List<IrImage> images = [];
  final List<IrChart> charts = [];

  /// Print settings in the 11 §7.2 shape with index-based `repeatRows`
  /// (`{"start": i, "end": j}`), `pageBreaks` (`{"rows": [i], "cols": [j]}`,
  /// break before these indices) and `printArea` (A1 text).
  Map<String, Object?>? print;

  /// Number of used rows (last row with a cell, merge, or non-default row
  /// properties + 1).
  int get usedRows {
    var m = cells.maxRow;
    for (final g in merges) {
      if (g.bottom > m) m = g.bottom;
    }
    for (final e in rows.entries) {
      if (!e.value.isDefault && e.key > m) m = e.key;
    }
    return m + 1;
  }

  /// Number of used columns (see [usedRows]).
  int get usedColumns {
    var m = cells.maxCol;
    for (final g in merges) {
      if (g.right > m) m = g.right;
    }
    for (final e in columns.entries) {
      if (!e.value.isDefault && e.key > m) m = e.key;
    }
    return m + 1;
  }
}

/// Workbook-level theme of the IR (Wonky keys `text`, `background`,
/// `accent1`…`accent6`, `link`).
final class IrTheme {
  /// Creates a theme.
  const IrTheme({
    this.name,
    this.textFont,
    this.headingFont,
    this.colors = const {},
  });

  final String? name;
  final String? textFont;
  final String? headingFont;
  final Map<String, String> colors;

  /// As a [SpreadsheetTheme] (missing colors from the standard theme).
  SpreadsheetTheme toSpreadsheetTheme() => SpreadsheetTheme(
    name: name ?? 'Imported',
    textFont: textFont ?? SpreadsheetTheme.standard.textFont,
    colors: {...SpreadsheetTheme.standard.colors, ...colors},
  );

  /// From a [SpreadsheetTheme].
  static IrTheme fromSpreadsheetTheme(SpreadsheetTheme t) =>
      IrTheme(name: t.name, textFont: t.textFont, colors: Map.of(t.colors));
}

/// The format-neutral intermediate representation of a workbook (11 §1.1).
final class WorkbookDocument {
  /// Creates an empty document.
  WorkbookDocument({this.title, this.locale, this.timeZone});

  String? title;
  String? locale;
  String? timeZone;

  /// Whether the source used the 1904 date system (values in the IR are
  /// already converted to the Wonky epoch).
  bool date1904 = false;
  IrTheme? theme;

  /// Default cell font of the source (Excel `fonts[0]`), if any.
  String? defaultFontFamily;
  double? defaultFontSize;

  final List<IrSheet> sheets = [];
  final List<IrNamedRange> namedRanges = [];

  /// Deduplicated formats referenced by cells/rows/columns.
  final IrFormatTable formats = IrFormatTable();

  /// Warnings accumulated during import/export.
  final ImportWarnings warnings = ImportWarnings();

  /// Sheet by name (case-insensitive) or null.
  IrSheet? sheetByName(String name) {
    final l = name.toLowerCase();
    for (final s in sheets) {
      if (s.name.toLowerCase() == l) return s;
    }
    return null;
  }

  /// The format of a cell.
  IrFormat formatOf(IrCell c) => formats[c.format];
}
