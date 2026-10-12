import '../../addressing/a1.dart';
import '../../addressing/grid_geometry.dart';
import '../codec/formula_codec.dart';
import '../eval/runtime_services.dart';
import '../external/external_data.dart';
import '../model/memory_workbook.dart';
import '../model/workbook_view.dart';
import '../parser/formula_locale.dart';
import '../recalc/engine_types.dart';
import '../recalc/formula_engine.dart';
import '../values/coercion.dart';
import '../values/errors.dart';
import '../values/fvalue.dart';

/// A small spreadsheet harness for tests (engine + in-memory workbook): set cells with A1
/// addresses and typed input, read computed values.
///
/// ```dart
/// final t = FormulaTestBench();
/// t.set('A1', 2);
/// t.set('A2', '=A1*3');
/// expect(t.value('A2'), const FNumber(6));
/// ```
final class FormulaTestBench {
  final MemoryWorkbook workbook;
  late final FormulaEngine engine;
  final FixedEngineClock clock;
  final MemoryExternalDataProvider externalData = MemoryExternalDataProvider();

  FormulaTestBench({
    int rows = 1000,
    int cols = 26,
    CalcSettings settings = const CalcSettings(),
    DateTime? now,
    List<String> sheets = const ['Sheet1'],
    CustomFunctionProvider? customFunctions,
  }) : workbook = MemoryWorkbook(settings: settings),
       clock = FixedEngineClock(now ?? DateTime.utc(2026, 10, 12, 14, 30, 15)) {
    for (final s in sheets) {
      workbook.addSheet(s, rows: rows, cols: cols);
    }
    engine = FormulaEngine(
      workbook: workbook,
      clock: clock,
      external: externalData,
      customFunctions: customFunctions,
      timeZones: const FixedOffsetResolver(),
    );
  }

  MemorySheet get sheet1 => workbook.sheets.first;

  MemorySheet sheet(String? name) =>
      name == null ? sheet1 : (workbook.sheetByName(name) ?? (throw ArgumentError('no sheet $name')));

  FormulaLocale get locale => FormulaLocale.forId(workbook.settings.locale);

  (MemorySheet, int, int) _addr(String a1) {
    final area = A1Area.tryParse(a1);
    if (area == null || area.row1 == null || area.col1 == null) {
      throw ArgumentError('bad address $a1');
    }
    return (sheet(area.sheet), area.row1!, area.col1!);
  }

  /// Typed input → cell input (formulas encoded with the codec).
  EngineCellInput? inputFor(MemorySheet s, int row, int col, Object? value) {
    if (value == null) return null;
    if (value is EngineCellInput) return value;
    if (value is FValue) return EngineCellInput.value(value);
    if (value is num) return EngineCellInput.value(FNumber(value.toDouble()));
    if (value is bool) return EngineCellInput.value(FBool(value));
    final text = value as String;
    if (text.startsWith('=')) {
      final stored = FormulaCodec.toStored(
        text,
        CodecContext(workbook: workbook, hostSheetId: s.id, hostRow: row, hostCol: col, locale: locale),
      );
      return EngineCellInput.formula(stored);
    }
    if (text.startsWith("'")) return EngineCellInput.value(FText(text.substring(1)));
    final upper = text.toUpperCase();
    if (upper == 'TRUE' || upper == 'FALSE') return EngineCellInput.value(FBool(upper == 'TRUE'));
    final err = ErrorKind.fromLiteral(upper);
    if (err != null) return EngineCellInput.value(FError(err));
    final n = TextNumberParser.parse(text, locale);
    if (n != null && text.trim().isNotEmpty) return EngineCellInput.value(FNumber(n.$1));
    return EngineCellInput.value(FText(text));
  }

  /// Sets a cell (`'Sheet2!B3'` allowed) and notifies the engine.
  void set(String a1, Object? value) {
    final (s, r, c) = _addr(a1);
    s.setInput(r, c, inputFor(s, r, c, value));
    engine.cellsChanged(s.id, [CellPos(r, c)]);
  }

  /// Sets many cells: `{'A1': 1, 'B1': '=A1+1'}`.
  void setAll(Map<String, Object?> cells) => cells.forEach(set);

  /// Sets a column of values starting at [a1].
  void setColumn(String a1, List<Object?> values) {
    final (s, r, c) = _addr(a1);
    for (var i = 0; i < values.length; i++) {
      s.setInput(r + i, c, inputFor(s, r + i, c, values[i]));
    }
    engine.rectChanged(s.id, GridRect(r, c, r + values.length - 1, c));
  }

  /// Sets a block of rows starting at [a1].
  void setRows(String a1, List<List<Object?>> rows) {
    final (s, r, c) = _addr(a1);
    var w = 0;
    for (var i = 0; i < rows.length; i++) {
      for (var j = 0; j < rows[i].length; j++) {
        s.setInput(r + i, c + j, inputFor(s, r + i, c + j, rows[i][j]));
      }
      if (rows[i].length > w) w = rows[i].length;
    }
    engine.rectChanged(s.id, GridRect(r, c, r + rows.length - 1, c + (w == 0 ? 0 : w - 1)));
  }

  /// Computed value after settling all pending recalculation.
  FValue value(String a1) {
    engine.settle();
    final (s, r, c) = _addr(a1);
    return engine.valueAt(s.id, r, c);
  }

  /// Full computed value.
  ComputedValue computed(String a1) {
    engine.settle();
    final (s, r, c) = _addr(a1);
    return engine.computedAt(s.id, r, c);
  }

  /// Evaluates an A1 formula at [at] without storing it.
  FValue eval(String formula, {String at = 'Z1000'}) {
    engine.settle();
    final (s, r, c) = _addr(at);
    final v = engine.evaluate(formula, sheetId: s.id, row: r, col: c);
    return v;
  }

  /// A1 display text of a stored cell formula.
  String formula(String a1) {
    final (s, r, c) = _addr(a1);
    final stored = s.inputAt(r, c)?.formula;
    if (stored == null) return '';
    return FormulaCodec.toA1(
      stored,
      CodecContext(workbook: workbook, hostSheetId: s.id, hostRow: r, hostCol: c, locale: locale),
    );
  }

  /// Inserts rows before [index] (zero-based) on [sheetName].
  List<String> insertRows(int index, int count, {String? sheetName}) {
    final s = sheet(sheetName);
    final ids = s.rows.insert(index, count);
    s.structureChanged();
    engine.axisChanged(s.id, GridDimension.rows, AxisChange.inserted(index, count));
    return ids;
  }

  List<String> deleteRows(int index, int count, {String? sheetName}) {
    final s = sheet(sheetName);
    final ids = s.rows.delete(index, count);
    s.purgeDeleted();
    engine.axisChanged(s.id, GridDimension.rows, AxisChange.deleted(index, count, ids));
    return ids;
  }

  List<String> insertColumns(int index, int count, {String? sheetName}) {
    final s = sheet(sheetName);
    final ids = s.columns.insert(index, count);
    s.structureChanged();
    engine.axisChanged(s.id, GridDimension.columns, AxisChange.inserted(index, count));
    return ids;
  }

  List<String> deleteColumns(int index, int count, {String? sheetName}) {
    final s = sheet(sheetName);
    final ids = s.columns.delete(index, count);
    s.purgeDeleted();
    engine.axisChanged(s.id, GridDimension.columns, AxisChange.deleted(index, count, ids));
    return ids;
  }

  void moveRows(int from, int count, int to, {String? sheetName}) {
    final s = sheet(sheetName);
    final ids = s.rows.move(from, count, to);
    s.structureChanged();
    engine.axisChanged(s.id, GridDimension.rows, AxisChange.moved(ids));
  }

  MemorySheet addSheet(String name) {
    final s = workbook.addSheet(name);
    engine.sheetsChanged();
    return s;
  }

  void renameSheet(String oldName, String newName) {
    sheet(oldName).name = newName;
    engine.sheetsChanged();
  }

  void updateSettings(CalcSettings settings) {
    workbook.settings = settings;
    engine.settingsChanged(settings);
  }
}
