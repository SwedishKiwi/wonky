import 'package:wonky_sync_models/ids.dart';

import '../addressing/a1.dart';
import '../content/cell_content.dart';
import '../format/attributes.dart';
import '../model/records.dart';
import '../model/schema.dart';
import '../model/workbook_model.dart';
import '../mutations/row_change.dart';

/// Builds in-memory workbooks for tests (public test helper, specs/15 §2).
///
/// ```dart
/// final wb = WorkbookBuilder()
///   ..sheet('Sheet1', rows: 10, cols: 5)
///   ..set('A1', 'n:1')
///   ..value('B1', 'Hello');
/// final model = wb.build();
/// ```
final class WorkbookBuilder {
  /// Creates a builder with deterministic ids.
  WorkbookBuilder({IdGenerator? ids, String? spreadsheetId, this.locale = 'en_US'})
    : ids = ids ?? SequentialIdGenerator() {
    this.spreadsheetId = spreadsheetId ?? this.ids.newId();
  }

  /// Id generator used for every entity.
  final IdGenerator ids;

  /// Spreadsheet locale.
  final String locale;

  /// The spreadsheet id.
  late final String spreadsheetId;

  final List<RowChange> _rows = [];
  final Map<String, ({String id, List<String> rows, List<String> cols})> _sheets = {};
  String? _current;
  String? _themeJson;

  /// Sets the theme JSON.
  set themeJson(String json) => _themeJson = json;

  /// Adds a sheet with [rows] × [cols] and makes it current.
  String sheet(String name, {int rows = 100, int cols = 26, bool hidden = false, int frozenRows = 0}) {
    final id = ids.newId();
    final sortKeys = FractionalIndex.nBetween(
      _sheets.isEmpty ? null : _lastSheetKey,
      null,
      1,
    );
    _lastSheetKey = sortKeys.single;
    _rows.add(
      RowChange.insert(SheetsTables.sheet, id, {
        Cols.spreadsheetId: spreadsheetId,
        Cols.name: name,
        Cols.sortKey: sortKeys.single,
        SheetCols.kind: SheetKind.grid.name,
        Cols.hidden: hidden,
        SheetCols.showGridlines: true,
        SheetCols.rightToLeft: false,
        SheetCols.frozenRows: frozenRows,
        SheetCols.frozenColumns: 0,
        SheetCols.defaultRowHeight: 21.0,
        SheetCols.defaultColumnWidth: 100.0,
      }),
    );
    final rowIds = <String>[];
    final colIds = <String>[];
    final rk = FractionalIndex.nBetween(null, null, rows);
    for (var i = 0; i < rows; i++) {
      final rid = ids.newId();
      rowIds.add(rid);
      _rows.add(
        RowChange.insert(SheetsTables.sheetRow, rid, {
          Cols.sheetId: id,
          Cols.sortKey: rk[i],
          Cols.hidden: false,
        }),
      );
    }
    final ck = FractionalIndex.nBetween(null, null, cols);
    for (var i = 0; i < cols; i++) {
      final cid = ids.newId();
      colIds.add(cid);
      _rows.add(
        RowChange.insert(SheetsTables.sheetColumn, cid, {
          Cols.sheetId: id,
          Cols.sortKey: ck[i],
          Cols.hidden: false,
        }),
      );
    }
    _sheets[name] = (id: id, rows: rowIds, cols: colIds);
    _current = name;
    return id;
  }

  String? _lastSheetKey;

  /// Switches the current sheet.
  void use(String name) => _current = name;

  /// Id of sheet [name].
  String sheetId(String name) => _sheets[name]!.id;

  /// Row id at [index] of the current (or [sheet]) sheet.
  String rowId(int index, {String? sheet}) => _sheets[sheet ?? _current]!.rows[index];

  /// Column id at [index].
  String colId(int index, {String? sheet}) => _sheets[sheet ?? _current]!.cols[index];

  /// Sets the encoded content of the cell at [a1] (e.g. `n:1`, `s:x`, `=…`).
  void set(String a1, String? content, {Map<FormatAttr, Object?>? format, String? note}) {
    final area = A1Area.tryParse(a1)!;
    final s = _sheets[area.sheet ?? _current]!;
    final rowId = s.rows[area.row1!];
    final colId = s.cols[area.col1!];
    final id = SheetsIds.cellId(s.id, rowId, colId);
    _rows.add(
      RowChange.insert(SheetsTables.cell, id, {
        Cols.sheetId: s.id,
        CellCols.rowId: rowId,
        CellCols.columnId: colId,
        CellCols.content: content,
        CellCols.note: note,
        if (format != null)
          for (final e in format.entries) e.key.column: e.key.toColumnValue(e.value),
      }),
    );
  }

  /// Sets a literal value (num, String, bool) at [a1].
  void value(String a1, Object? v, {Map<FormatAttr, Object?>? format}) =>
      set(a1, CellContent.fromValue(CellValue.from(v))?.encode(), format: format);

  /// Fills a block starting at [topLeft] with literal values (row-major).
  void values(String topLeft, List<List<Object?>> rows) {
    final area = A1Area.tryParse(topLeft)!;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        final v = rows[r][c];
        if (v == null) continue;
        final a = A1Area.cell(area.row1! + r, area.col1! + c, sheet: area.sheet);
        value(a.format(), v);
      }
    }
  }

  /// Adds an arbitrary row.
  void row(String table, String id, Map<String, Object?> columns) =>
      _rows.add(RowChange.insert(table, id, columns));

  /// All rows added so far (spreadsheet row first).
  List<RowChange> get changes => [
    RowChange.insert(SheetsTables.spreadsheet, spreadsheetId, {
      SpreadsheetCols.title: 'Test',
      SpreadsheetCols.locale: locale,
      SpreadsheetCols.timeZone: 'UTC',
      SpreadsheetCols.themeJson: _themeJson ?? '',
      Cols.createdBy: '00000000-0000-4000-8000-0000000000ff',
    }),
    ..._rows,
  ];

  /// Builds the model.
  WorkbookModel build() {
    final m = WorkbookModel(spreadsheetId: spreadsheetId);
    m.applyChanges(changes, silent: true);
    return m;
  }
}

/// Reads a cell's encoded content by A1 (`Sheet1!B2` or `B2` on the first sheet).
String? contentAt(WorkbookModel model, String a1) {
  final r = model.parseA1(a1, contextSheetId: model.sheets.first.id);
  return model.cellAt(r.sheetId, r.rect.top, r.rect.left)?.content;
}

/// Reads a cell record by A1.
CellRecord? cellAtA1(WorkbookModel model, String a1) {
  final r = model.parseA1(a1, contextSheetId: model.sheets.first.id);
  return model.cellAt(r.sheetId, r.rect.top, r.rect.left);
}
