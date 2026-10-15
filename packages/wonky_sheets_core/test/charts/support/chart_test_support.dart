import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart' hide fail;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

/// Deterministic number formatter for chart tests (independent of the number-format engine):
/// honours fraction digits, `#,##0` grouping, `%` and date tokens (rendered as ISO-like text).
final class TestFormatter implements ChartValueFormatter {
  /// Creates the formatter.
  const TestFormatter();

  @override
  String format(double value, String? numberFormat) {
    if (value.isNaN) return '';
    final p = numberFormat;
    if (p == null || p == 'preset:automatic' || p.isEmpty) {
      return _general(value);
    }
    if (ChartFormats.isDateTime(p)) {
      final d = DateSerial.toYmd(value);
      final t = DateSerial.timeOf(value);
      if (p.contains('h') && !p.contains('y') && !p.contains('d')) {
        return '${t.hour}:${'${t.minute}'.padLeft(2, '0')}';
      }
      if (p == 'yyyy') return '${d.year}';
      if (p.startsWith('mmm yyyy')) {
        return '${d.year}-${'${d.month}'.padLeft(2, '0')}';
      }
      return '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';
    }
    final percent = p.contains('%');
    final v = percent ? value * 100 : value;
    final dot = p.indexOf('.');
    var decimals = 0;
    if (dot >= 0) {
      for (var i = dot + 1; i < p.length && (p[i] == '0' || p[i] == '#'); i++) {
        decimals++;
      }
    }
    var s = v.abs().toStringAsFixed(decimals);
    if (p.contains(',')) {
      final parts = s.split('.');
      final b = StringBuffer();
      for (var i = 0; i < parts[0].length; i++) {
        if (i > 0 && (parts[0].length - i) % 3 == 0) b.write(',');
        b.write(parts[0][i]);
      }
      s = parts.length > 1 ? '$b.${parts[1]}' : '$b';
    }
    return '${v < 0 ? '-' : ''}$s${percent ? '%' : ''}';
  }

  static String _general(double v) {
    if (v == v.truncateToDouble() && v.abs() < 1e15) {
      return v.toInt().toString();
    }
    var s = v.toStringAsPrecision(10);
    if (s.contains('.') && !s.contains('e')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }
}

/// A [CellSource] over a model with scripted hidden rows/columns and computed values.
final class FakeCellSource implements CellSource {
  /// Creates the source.
  FakeCellSource(
    this.model, {
    this.hiddenRows = const {},
    this.filteredRows = const {},
    this.hiddenColumns = const {},
    this.computed = const {},
  }) : _base = ModelCellSource(model);

  final WorkbookModel model;
  final ModelCellSource _base;

  /// User-hidden row indices.
  final Set<int> hiddenRows;

  /// Rows hidden by the basic filter (only when `includeFilter`).
  final Set<int> filteredRows;

  /// User-hidden column indices.
  final Set<int> hiddenColumns;

  /// Computed overlay values by `(row, col)`.
  final Map<(int, int), FValue> computed;

  @override
  FValue valueAt(String sheetId, int row, int col) =>
      computed[(row, col)] ?? _base.valueAt(sheetId, row, col);

  @override
  String? numberFormatAt(String sheetId, int row, int col) =>
      _base.numberFormatAt(sheetId, row, col);

  @override
  bool isHidden(
    String sheetId,
    GridDimension dimension,
    int index, {
    bool includeFilter = true,
  }) {
    if (dimension == GridDimension.columns) {
      return hiddenColumns.contains(index);
    }
    if (hiddenRows.contains(index)) return true;
    return includeFilter && filteredRows.contains(index);
  }
}

/// The id-based range of [a1] in [model] (first sheet by default).
GridRange rangeOf(WorkbookModel model, String a1) {
  final r = model.parseA1(a1, contextSheetId: model.sheets.first.id);
  final s = model.sheet(r.sheetId)!;
  return s.gridRange(
    r.rect,
    wholeRows: r.wholeRows,
    wholeColumns: r.wholeColumns,
  );
}

/// The column id of column [letter] on the first sheet of [model].
String columnKey(WorkbookModel model, String letter) =>
    model.sheets.first.columns.idAt(letter.codeUnitAt(0) - 0x41);

/// Builds a model from row-major [rows] at A1 of `Sheet1`. [columnFormats] maps a column
/// letter to the number format of its non-header cells (row 2 on).
(WorkbookBuilder, WorkbookModel) buildTable(
  List<List<Object?>> rows, {
  int extraRows = 5,
  int extraCols = 3,
  Map<String, String> columnFormats = const {},
}) {
  final b = WorkbookBuilder();
  final cols = rows.fold<int>(0, (m, r) => math.max(m, r.length));
  b.sheet('Sheet1', rows: rows.length + extraRows, cols: cols + extraCols);
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      final v = rows[r][c];
      if (v == null) continue;
      final letter = String.fromCharCode(0x41 + c);
      final f = r > 0 ? columnFormats[letter] : null;
      b.value(
        '$letter${r + 1}',
        v,
        format: f == null ? null : {FormatAttr.numberFormat: f},
      );
    }
  }
  return (b, b.build());
}

/// The table of 08 §21 acceptance criterion 1: a header row and 12 months × 3 regions.
WorkbookModel monthlyRevenue() => buildTable([
  ['Month', 'North', 'South', 'East'],
  for (var i = 0; i < 12; i++)
    [
      const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][i],
      10 + i * 3,
      30 - i * 2 + (i % 3) * 4,
      5 + (i * 7) % 11,
    ],
]).$2;

/// Resolves [spec] against [model] with [TestFormatter].
ChartData resolveChart(
  ChartSpec spec,
  WorkbookModel model, {
  CellSource? source,
}) => ChartDataResolver.resolve(
  spec,
  model,
  source ?? ModelCellSource(model),
  fmt: const TestFormatter(),
);

/// A spec over [a1] in [model].
ChartSpec specFor(
  WorkbookModel model,
  String a1, {
  ChartType type = ChartType.column,
  int? headerCount,
  bool switched = false,
  ChartAggregate? aggregate,
  Map<String, Object?> typeOptions = const {},
}) => ChartSpec(
  type: type,
  data: ChartDataSpec(
    ranges: [rangeOf(model, a1).toRef()],
    headerCount: headerCount,
    switchRowsColumns: switched,
    aggregate: aggregate,
  ),
  typeOptions: typeOptions,
);

/// Default size of chart tests (08 §5.2: 600 × 371).
const testChartSize = ChartSize(600, 371);

/// The light export theme of the standard spreadsheet theme.
final testTheme = ChartTheme.from(SpreadsheetTheme.standard, export: true);

/// Lays out [spec] with [data] deterministically ([ApproxTextMeasurer], [TestFormatter]).
ChartLayout layoutChart(
  ChartSpec spec,
  ChartData data, {
  ChartSize size = testChartSize,
  ChartTheme? theme,
  ChartLayoutOptions options = const ChartLayoutOptions(),
}) => ChartLayoutEngine.layoutDetailed(
  spec,
  data,
  size,
  theme ?? testTheme,
  const ApproxTextMeasurer(),
  fmt: const TestFormatter(),
  options: options,
);

/// Resolves and lays out [spec] over [model].
ChartScene sceneOf(
  ChartSpec spec,
  WorkbookModel model, {
  ChartSize size = testChartSize,
  ChartTheme? theme,
  ChartLayoutOptions options = const ChartLayoutOptions(),
}) => layoutChart(
  spec,
  resolveChart(spec, model),
  size: size,
  theme: theme,
  options: options,
).scene;

/// The primitives of [scene] (groups and clips expanded) with [role], optionally only those
/// of type [T] and with [detail].
List<T> primitivesOf<T extends ScenePrimitive>(
  ChartScene scene,
  SceneRole role, {
  String? detail,
}) => [
  for (final p in scene.flattened)
    if (p is T &&
        p.tag?.role == role &&
        (detail == null || p.tag?.detail == detail))
      p,
];

/// Texts of the [SText] primitives of [scene] with [role] (and [detail]), in paint order.
List<String> textsOf(ChartScene scene, SceneRole role, {String? detail}) => [
  for (final t in primitivesOf<SText>(scene, role, detail: detail)) t.text,
];

/// Compares [actual] JSON against the golden file `test/fixtures/charts/<name>.json`
/// (resolved from the package root, where `dart test` runs). Run with `UPDATE_GOLDENS=1` to
/// write or accept goldens; a missing golden fails otherwise.
void expectGoldenJson(String name, Map<String, Object?> actual) =>
    _expectGolden('$name.json', '${_json.convert(actual)}\n');

/// Compares [actual] text against the golden file `test/fixtures/charts/<name>` (see
/// [expectGoldenJson]).
void expectGoldenText(String name, String actual) =>
    _expectGolden(name, actual);

const _json = JsonEncoder.withIndent(' ');

void _expectGolden(String fileName, String actual) {
  final file = File('test/fixtures/charts/$fileName');
  if (Platform.environment['UPDATE_GOLDENS'] == '1') {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(actual);
    return;
  }
  if (!file.existsSync()) {
    fail('Golden ${file.path} is missing (run with UPDATE_GOLDENS=1)');
  }
  expect(
    actual,
    file.readAsStringSync(),
    reason: 'golden $fileName differs (run with UPDATE_GOLDENS=1 to accept)',
  );
}
