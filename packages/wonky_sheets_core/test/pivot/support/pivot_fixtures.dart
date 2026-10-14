import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/formula/values/dates.dart';
import 'package:wonky_sheets_core/src/pivot/pivot.dart';
import 'package:wonky_sheets_core/src/rules/conditions/display_text.dart';
import 'package:wonky_sheets_core/src/rules/conditions/value_text.dart';

/// Display texts with Automatic rules (number formats ignored).
const DisplayTextProvider plainDisplay = FunctionDisplayText(_plain);
String _plain(CellValue v, String? f) => ValueText.automatic(v);

/// Serial of a date.
double day(int y, int m, int d) => DateSerial.fromYmd(y, m, d).toDouble();

/// Column ids of [salesTable].
const region = 'region';
const product = 'product';
const date = 'date';
const units = 'units';
const revenue = 'rev';

/// The sales fixture:
///
/// | Region | Product | Date       | Units | Revenue |
/// |--------|---------|------------|-------|---------|
/// | East   | Apple   | 2026-01-15 | 10    | 100     |
/// | West   | Apple   | 2026-02-10 | 5     | 50      |
/// | east   | Banana  | 2026-04-01 | 7     | 70      |
/// | West   | Banana  | 2025-12-31 | 3     | 30      |
/// | North  | Apple   | 2026-01-20 | 1     | 10      |
SourceTable salesTable({
  List<List<Object?>> extraRows = const [],
  String? revenueFormat,
}) => SourceTable.fromRows(
  colIds: const [region, product, date, units, revenue],
  headers: const ['Region', 'Product', 'Date', 'Units', 'Revenue'],
  rows: [
    for (final r in [
      ['East', 'Apple', day(2026, 1, 15), 10, 100],
      ['West', 'Apple', day(2026, 2, 10), 5, 50],
      ['east', 'Banana', day(2026, 4, 1), 7, 70],
      ['West', 'Banana', day(2025, 12, 31), 3, 30],
      ['North', 'Apple', day(2026, 1, 20), 1, 10],
      ...extraRows,
    ])
      [for (final v in r) CellValue.from(v)],
  ],
  columnFormats: [null, null, 'yyyy-mm-dd', null, revenueFormat],
  display: plainDisplay,
);

/// A row or column group on [source].
PivotGroupSpec field(
  String source, {
  bool showTotals = true,
  bool ascending = true,
  int? sortByValue,
  bool repeatLabels = false,
  PivotGrouping? grouping,
  String? label,
}) => PivotGroupSpec(
  source,
  showTotals: showTotals,
  ascending: ascending,
  sortByValueIndex: sortByValue,
  repeatLabels: repeatLabels,
  group: grouping,
  label: label,
);

/// Expected table rows: `null` = empty cell, other values via [CellValue.from].
List<List<CellValue>> table(List<List<Object?>> rows) => [
  for (final r in rows) [for (final v in r) CellValue.from(v)],
];
