import 'dart:convert';

import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

/// Updates columns of an existing row of [table] in [m].
void patchRecord(
  WorkbookModel m,
  String table,
  String id,
  Map<String, Object?> after,
) {
  m.applyChanges([
    RowChange.update(table, id, {for (final k in after.keys) k: null}, after),
  ]);
}

/// Sets sheet columns (frozen rows, print settings, …) of [sheet].
void patchSheet(
  WorkbookModel m,
  WorkbookBuilder b,
  String sheet,
  Map<String, Object?> after,
) => patchRecord(m, SheetsTables.sheet, b.sheetId(sheet), after);

/// Stores [settings] as the print settings of [sheet].
void setPrintSettings(
  WorkbookModel m,
  WorkbookBuilder b,
  String sheet,
  Map<String, Object?> settings,
) => patchSheet(m, b, sheet, {
  SheetCols.printSettingsJson: jsonEncode(settings),
});

/// Hides row [index] of [sheet].
void hideRow(WorkbookModel m, WorkbookBuilder b, String sheet, int index) =>
    patchRecord(m, SheetsTables.sheetRow, b.rowId(index, sheet: sheet), {
      Cols.hidden: true,
    });

/// Sets the height (px) of row [index].
void setRowHeight(
  WorkbookModel m,
  WorkbookBuilder b,
  String sheet,
  int index,
  double px,
) => patchRecord(m, SheetsTables.sheetRow, b.rowId(index, sheet: sheet), {
  DimCols.height: px,
});

/// Sets the width (px) of column [index].
void setColumnWidth(
  WorkbookModel m,
  WorkbookBuilder b,
  String sheet,
  int index,
  double px,
) => patchRecord(m, SheetsTables.sheetColumn, b.colId(index, sheet: sheet), {
  DimCols.width: px,
});

/// Adds a merge over [a1] on [sheet].
void addMergeA1(WorkbookBuilder b, String sheet, String a1) {
  final area = A1Area.tryParse(a1)!;
  final sid = b.sheetId(sheet);
  b.row(SheetsTables.mergedRange, 'merge-$sheet-$a1', {
    Cols.sheetId: sid,
    Cols.rangeJson: GridRange(
      sheetId: sid,
      r1: b.rowId(area.row1!, sheet: sheet),
      r2: b.rowId(area.row2!, sheet: sheet),
      c1: b.colId(area.col1!, sheet: sheet),
      c2: b.colId(area.col2!, sheet: sheet),
    ).encode(),
  });
}

/// Adds an image object anchored at ([row], [col]) of [sheet].
void addImage(
  WorkbookBuilder b,
  String sheet,
  String id, {
  required int row,
  required int col,
  double width = 40,
  double height = 20,
  String kind = 'image',
}) {
  b.row(SheetsTables.embeddedObject, id, {
    Cols.sheetId: b.sheetId(sheet),
    'kind': kind,
    'anchorJson': jsonEncode({
      'rowId': b.rowId(row, sheet: sheet),
      'colId': b.colId(col, sheet: sheet),
      'dx': 2,
      'dy': 3,
      'width': width,
      'height': height,
    }),
    'specJson': '{}',
    'zIndex': 0,
    'altText': 'Picture $id',
  });
}

/// Adds a checkbox validation over [a1] of [sheet].
void addCheckboxes(WorkbookBuilder b, String sheet, String a1) {
  final area = A1Area.tryParse(a1)!;
  final sid = b.sheetId(sheet);
  b.row(SheetsTables.dataValidationRule, 'dv-$sheet-$a1', {
    Cols.sheetId: sid,
    Cols.rangesJson: GridRange.encodeList([
      GridRange(
        sheetId: sid,
        r1: b.rowId(area.row1!, sheet: sheet),
        r2: b.rowId(area.row2!, sheet: sheet),
        c1: b.colId(area.col1!, sheet: sheet),
        c2: b.colId(area.col2!, sheet: sheet),
      ),
    ]),
    'criteriaJson': '{"type":"checkbox"}',
    'strict': false,
    'showDropdown': false,
    'createdAt': DateTime.utc(2026),
  });
}

/// A workbook whose `Sheet1` holds [rows] × [cols] numbers (`r*100+c`) in a
/// grid of 21 px rows and 100 px columns.
(WorkbookBuilder, WorkbookModel) numberGrid({
  int rows = 60,
  int cols = 10,
  int gridRows = 200,
  int gridCols = 26,
  void Function(WorkbookBuilder b)? extra,
}) {
  final b = WorkbookBuilder()..sheet('Sheet1', rows: gridRows, cols: gridCols);
  b.values('A1', [
    for (var r = 0; r < rows; r++) [for (var c = 0; c < cols; c++) r * 100 + c],
  ]);
  extra?.call(b);
  return (b, b.build());
}

/// Page descriptions of a pagination.
List<String> describe(PaginationResult r) => [
  for (final p in r.pages) p.describe(),
];
