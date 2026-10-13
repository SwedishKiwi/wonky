import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';
import 'package:wonky_sheets_core/src/charts/charts.dart';
import 'package:wonky_sheets_core/src/formula/model/workbook_view.dart';
import 'package:wonky_sheets_core/src/formula/values/dates.dart';
import 'package:wonky_sheets_core/src/formula/values/fvalue.dart';

/// Deterministic number formatter for chart tests (independent of the number-format engine):
/// honours fraction digits, `#,##0` grouping, `%` and date tokens (rendered as ISO-like text).
final class TestFormatter implements ChartValueFormatter {
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

/// A [CellSource] over a model with scripted hidden rows/columns.
final class FakeCellSource implements CellSource {
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
    ranges: [rangeOf(model, a1)],
    headerCount: headerCount,
    switchRowsColumns: switched,
    aggregate: aggregate,
  ),
  typeOptions: typeOptions,
);

/// Compares [actual] JSON against the golden file `test/fixtures/charts/<name>.json`, writing it
/// when `UPDATE_GOLDENS=1` (or when missing).
void expectGoldenJson(String name, Map<String, Object?> actual) {
  final file = File('test/fixtures/charts/$name.json');
  final encoded = '${const JsonEncoder.withIndent(' ').convert(actual)}\n';
  if (Platform.environment['UPDATE_GOLDENS'] == '1' || !file.existsSync()) {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(encoded);
    return;
  }
  expect(
    encoded,
    file.readAsStringSync(),
    reason: 'scene golden $name differs (UPDATE_GOLDENS=1 to accept)',
  );
}
