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
    final sheet = model.sheet(range.sheetId)!;
    final rect = _clamp(range, sheet.usedRect()?.bottom);
    final n = rect.rowCount - 1;
    final cols = <SourceColumn>[];
    for (var c = rect.left; c <= rect.right; c++) {
      final colId = sheet.columns.tryIdAt(c);
      if (colId == null) continue;
      final h = values.valueAt(sheet.id, rect.top, c).toCellValue();
      final headerText = h.isBlank()
          ? 'Column ${ColumnLetters.fromIndex(c)}'
          : displayText.displayText(
              h,
              values.numberFormatAt(sheet.id, rect.top, c),
            );
      final vs = <CellValue>[];
      final fs = <String?>[];
      final fills = colorAt == null ? null : <String?>[];
      final texts = colorAt == null ? null : <String?>[];
      for (var i = 0; i < n; i++) {
        final r = rect.top + 1 + i;
        vs.add(values.valueAt(sheet.id, r, c).toCellValue());
        fs.add(values.numberFormatAt(sheet.id, r, c));
        if (colorAt != null) {
          final colors = colorAt(r, c);
          fills!.add(colors.fill);
          texts!.add(colors.text);
        }
      }
      cols.add(
        SourceColumn(
          colId: colId,
          header: headerText,
          values: vs,
          formats: fs,
          display: displayText,
          sheetCol: c,
          fillColors: fills,
          textColors: texts,
        ),
      );
    }
    return SourceTable(
      sheetId: sheet.id,
      range: rect,
      columns: cols,
      display: displayText,
      rowMask: rowMask,
    );
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
