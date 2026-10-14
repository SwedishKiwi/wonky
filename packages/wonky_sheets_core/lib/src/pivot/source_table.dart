import 'dart:typed_data';

import '../addressing/column_letters.dart';
import '../addressing/grid_geometry.dart';
import '../content/cell_content.dart';
import '../engine_bridge/value_bridge.dart';
import '../formula/model/workbook_view.dart';
import '../model/grid_range.dart';
import '../model/workbook_model.dart';
import '../rules/conditions/display_text.dart';

/// One source column snapshot.
final class SourceColumn {
  /// Creates a column.
  SourceColumn({
    required this.colId,
    required this.header,
    required this.values,
    required this.formats,
    required DisplayTextProvider display,
    this.sheetCol = 0,
    this.fillColors,
    this.textColors,
  }) : _display = display, // ignore: prefer_initializing_formals
       _texts = List<String?>.filled(values.length, null) {
    for (var i = 0; i < values.length; i++) {
      if (!values[i].isBlank() && formats[i] != null) {
        numberFormat = formats[i];
        break;
      }
    }
  }

  /// Column id.
  final String colId;

  /// Sheet column index at snapshot time.
  final int sheetCol;

  /// Header text ("Column C" for empty headers).
  final String header;

  /// Computed values of the data rows.
  final List<CellValue> values;

  /// Number formats per data row (explicit or hint).
  final List<String?> formats;

  /// Effective fill colors (`#RRGGBB`, null = none) per data row, when the
  /// snapshot was taken with colors (pivot color filters, 07 §3.2).
  final List<String?>? fillColors;

  /// Effective text colors per data row (null = automatic), see
  /// [fillColors].
  final List<String?>? textColors;

  /// The column's number format (first non-empty cell's), inherited by values.
  String? numberFormat;
  final DisplayTextProvider _display;
  final List<String?> _texts;

  /// Replaces data row [i]'s value and number format (incremental pivot
  /// refresh, 07 §7.10).
  void setRow(int i, CellValue value, String? format) {
    values[i] = value;
    formats[i] = format;
    _texts[i] = null;
  }

  /// Display text of [value] with [format] as this column shows it.
  String displayTextOf(CellValue value, String? format) =>
      value.isBlank() ? '' : _display.displayText(value, format);

  /// Display text of data row [i] (cached).
  String displayText(int i) {
    final v = values[i];
    if (v.isBlank()) return '';
    return _texts[i] ??= _display.displayText(v, formats[i]);
  }
}

/// Column snapshots of a pivot source range minus its header (07 §7.4).
final class SourceTable {
  /// Creates a table.
  SourceTable({
    required this.sheetId,
    required this.range,
    required List<SourceColumn> columns,
    required this.display,
    this.rowMask,
  }) : columns = List.unmodifiable(columns),
       _byId = {for (final c in columns) c.colId: c};

  /// Snapshot of [range] (header row included) from computed values.
  /// [rowMask] (1 = excluded, per data row) carries slicer masks.
  /// [colorAt] adds the effective fill and text colors of the data cells
  /// (only needed by color filters).
  factory SourceTable.fromModel(
    WorkbookModel model,
    CellSource values,
    ResolvedRange range,
    DisplayTextProvider displayText, {
    Uint8List? rowMask,
    ({String? fill, String? text}) Function(int row, int col)? colorAt,
  }) {
    final b = SourceTableBuilder(
      model,
      values,
      range,
      displayText,
      rowMask: rowMask,
      colorAt: colorAt,
    );
    while (!b.step(1 << 30)) {}
    return b.build();
  }

  /// A table from literal data rows (MCP, previews, tests): column [colIds]
  /// with [headers], [rows] of values (row-major, short rows padded with
  /// blanks) and optional per-column number formats [columnFormats].
  factory SourceTable.fromRows({
    required List<String> colIds,
    required List<String> headers,
    required List<List<CellValue>> rows,
    required DisplayTextProvider display,
    List<String?>? columnFormats,
    String sheetId = '',
    int top = 0,
    int left = 0,
    Uint8List? rowMask,
  }) {
    final cols = <SourceColumn>[
      for (var c = 0; c < colIds.length; c++)
        SourceColumn(
          colId: colIds[c],
          header: c < headers.length && headers[c].isNotEmpty
              ? headers[c]
              : 'Column ${ColumnLetters.fromIndex(left + c)}',
          values: [for (final r in rows) c < r.length ? r[c] : CellValue.empty],
          formats: List<String?>.filled(
            rows.length,
            columnFormats != null && c < columnFormats.length
                ? columnFormats[c]
                : null,
          ),
          display: display,
          sheetCol: left + c,
        ),
    ];
    return SourceTable(
      sheetId: sheetId,
      range: GridRect(
        top,
        left,
        top + rows.length,
        left + (colIds.isEmpty ? 0 : colIds.length - 1),
      ),
      columns: cols,
      display: display,
      rowMask: rowMask,
    );
  }

  /// Open-ended (whole column) sources are clamped to the used range.
  /// [r]'s rectangle clamped to the last used row for whole columns.
  static GridRect clampToUsed(ResolvedRange r, int? lastUsedRow) =>
      _clamp(r, lastUsedRow);

  static GridRect _clamp(ResolvedRange r, int? lastUsedRow) {
    final rect = r.rect;
    if (lastUsedRow == null || !r.wholeColumns) return rect;
    final bottom = lastUsedRow < rect.top + 1
        ? rect.top + 1
        : (lastUsedRow < rect.bottom ? lastUsedRow : rect.bottom);
    return GridRect(rect.top, rect.left, bottom, rect.right);
  }

  /// Source sheet.
  final String sheetId;

  /// Source rectangle (header row first).
  final GridRect range;
  final List<SourceColumn> columns;
  final Map<String, SourceColumn> _byId;

  /// Display formatting.
  final DisplayTextProvider display;

  /// Excluded data rows (slicers with `applyToPivotTables`), or null.
  final Uint8List? rowMask;

  /// Number of data rows.
  int get rowCount => columns.isEmpty
      ? (range.rowCount - 1).clamp(0, 1 << 30)
      : columns.first.values.length;

  /// The column with id [colId], or null (fields whose column no longer exists).
  SourceColumn? column(String colId) => _byId[colId];

  /// Index of [colId] within [columns], or -1.
  int indexOf(String colId) => columns.indexWhere((c) => c.colId == colId);

  /// Sheet row of data row [i].
  int sheetRow(int i) => range.top + 1 + i;
}

/// Builds a [SourceTable] snapshot in slices (07 §7.4 step 7: big pivot
/// sources are read across frames instead of in one blocking call):
/// [step] reads up to a number of cells; [build] returns the table once
/// [isDone]. The model must not change between steps (callers restart on
/// changes). [SourceTable.fromModel] is the one-shot form.
final class SourceTableBuilder {
  /// Starts a snapshot of [range] (header row included).
  SourceTableBuilder(
    WorkbookModel model,
    this._values,
    ResolvedRange range,
    this._display, {
    this.rowMask,
    this.colorAt,
  }) {
    final sheet = model.sheet(range.sheetId)!;
    _sheetId = sheet.id;
    rect = SourceTable._clamp(range, sheet.usedRect()?.bottom);
    _n = rect.rowCount - 1;
    for (var c = rect.left; c <= rect.right; c++) {
      final colId = sheet.columns.tryIdAt(c);
      if (colId != null) _cols.add((c, colId));
    }
  }

  final CellSource _values;
  final DisplayTextProvider _display;

  /// Slicer mask of the data rows (1 = excluded).
  final Uint8List? rowMask;

  /// Effective colors of data cells (color filters), or null.
  final ({String? fill, String? text}) Function(int row, int col)? colorAt;

  late final String _sheetId;

  /// The snapshot rectangle (header row first).
  late final GridRect rect;
  late final int _n;
  final List<(int, String)> _cols = [];
  final List<SourceColumn> _done = [];
  int _col = 0;
  int _row = 0;
  List<CellValue> _vs = [];
  List<String?> _fs = [];
  List<String?>? _fills;
  List<String?>? _texts;

  /// Data rows × columns (the cells [step] reads in total).
  int get cellCount => _n * _cols.length;

  /// Whether every column was read.
  bool get isDone => _col >= _cols.length;

  /// Share of the cells read (0–1).
  double get progress => cellCount == 0
      ? 1
      : ((_col * _n + _row) / cellCount).clamp(0.0, 1.0).toDouble();

  /// Reads up to [cells] more cells; returns [isDone].
  bool step(int cells) {
    var budget = cells;
    while (!isDone && budget > 0) {
      final (c, _) = _cols[_col];
      if (_row == 0 && _vs.isEmpty) {
        _fills = colorAt == null ? null : <String?>[];
        _texts = colorAt == null ? null : <String?>[];
      }
      final end = _row + budget < _n ? _row + budget : _n;
      for (var i = _row; i < end; i++) {
        final r = rect.top + 1 + i;
        _vs.add(_values.valueAt(_sheetId, r, c).toCellValue());
        _fs.add(_values.numberFormatAt(_sheetId, r, c));
        final at = colorAt;
        if (at != null) {
          final colors = at(r, c);
          _fills!.add(colors.fill);
          _texts!.add(colors.text);
        }
      }
      budget -= end - _row;
      _row = end;
      if (_row >= _n) _finishColumn();
    }
    return isDone;
  }

  void _finishColumn() {
    final (c, colId) = _cols[_col];
    final h = _values.valueAt(_sheetId, rect.top, c).toCellValue();
    final header = h.isBlank()
        ? 'Column ${ColumnLetters.fromIndex(c)}'
        : _display.displayText(
            h,
            _values.numberFormatAt(_sheetId, rect.top, c),
          );
    _done.add(
      SourceColumn(
        colId: colId,
        header: header,
        values: _vs,
        formats: _fs,
        display: _display,
        sheetCol: c,
        fillColors: _fills,
        textColors: _texts,
      ),
    );
    _vs = [];
    _fs = [];
    _fills = null;
    _texts = null;
    _row = 0;
    _col++;
  }

  /// The finished table (call once [isDone]).
  SourceTable build() {
    assert(isDone, 'the snapshot is not complete');
    return SourceTable(
      sheetId: _sheetId,
      range: rect,
      columns: _done,
      display: _display,
      rowMask: rowMask,
    );
  }
}
