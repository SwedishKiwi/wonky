import '../../addressing/grid_geometry.dart';
import '../codec/ref_token.dart';
import '../external/external_data.dart';
import '../functions/function_spec.dart';
import '../functions/registry.dart';
import '../model/workbook_view.dart';
import '../parser/formula_locale.dart';
import '../values/errors.dart';
import '../values/format_hint.dart';
import '../values/fvalue.dart';
import '../recalc/lookup_cache.dart';
import 'lambda.dart';
import 'runtime_services.dart';

/// A compiled expression (closure tree, 05 §7.2).
typedef CompiledExpr = FValue Function(EvalContext ctx);

/// Formats a value with a number format pattern (TEXT(), TO_TEXT, DOLLAR, FIXED). The default
/// is the engine's built-in formatter; hosts may plug in the 06 number-format engine.
abstract interface class NumberTextFormatter {
  /// Formats [value] (number, text, bool) with [pattern]; null when the pattern is invalid.
  String? format(FValue value, String pattern, FormulaLocale locale);
}

/// Thrown by function helpers to return an error value (caught by the dispatcher).
final class FormulaError implements Exception {
  final FError error;
  const FormulaError(this.error);

  @override
  String toString() => 'FormulaError(${error.kind.literal}: ${error.message})';
}

/// Control-flow signal used by the engine to restart an evaluation (never an error value).
abstract class EvaluationInterrupt implements Exception {}

/// Throws a [FormulaError].
Never fail(ErrorKind kind, [String? message]) => throw FormulaError(FError(kind, message));

/// What the evaluator needs from the engine (implemented by `FormulaEngine`).
abstract interface class EvalHost {
  WorkbookView get workbook;
  FunctionRegistry get registry;
  FormulaLocale get locale;
  CalcSettings get settings;
  EngineClock get clock;
  TimeZoneResolver get timeZones;
  ExternalDataProvider? get external;
  CustomFunctionProvider? get customFunctions;
  PivotDataProvider? get pivots;
  NumberTextFormatter get textFormatter;

  /// Epoch string for RAND seeds (05 §12).
  String get randomEpoch;

  /// Computed scalar value of a cell (formula results are evaluated on demand).
  FValue cellValue(SheetView sheet, int row, int col);

  /// Format hint of a cell value: explicit number format, else the formula result's hint.
  FormatHint cellHint(SheetView sheet, int row, int col);

  /// Visits the non-empty computed values in [rect] (inputs and spill overlays).
  void forEachValue(SheetView sheet, GridRect rect, void Function(int row, int col, FValue v) visit);

  /// Used extent including spill overlays.
  int usedRows(SheetView sheet);
  int usedColumns(SheetView sheet);

  /// Stored formula text at the cell, or null.
  String? formulaAt(SheetView sheet, int row, int col);

  /// Named range (case-insensitive).
  NamedRangeView? namedRange(String name);

  /// Named function closure (case-insensitive), or null.
  FCallable? namedFunction(String upperName);

  /// Lookup and criteria caches (05 §11.2).
  LookupCache get lookupCache;

  /// Filter-hidden / user-hidden rows (SUBTOTAL).
  bool isRowHidden(SheetView sheet, int row, {required bool includeUserHidden});
}

/// Records dynamic dependencies discovered during one evaluation (05 §8.2).
final class DependencyRecorder {
  final List<ResolvedArea> areas = [];
  final Set<String> names = {};
  final Set<String> axisSheets = {};
  final Set<ExternalKey> external = {};
  final Set<String> customFunctions = {};
  bool sheetNames = false;
  bool filter = false;
  bool volatile = false;

  void clear() {
    areas.clear();
    names.clear();
    axisSheets.clear();
    external.clear();
    customFunctions.clear();
    sheetNames = false;
    filter = false;
    volatile = false;
  }
}

/// Per-evaluation state (05 §7.3).
final class EvalContext {
  final EvalHost host;
  final SheetView sheet;
  final int row;
  final int col;

  /// Ids of the host cell (RAND seeds, custom function callers); may be empty in previews.
  final String rowId;
  final String colId;

  /// Array mode (inside ARRAYFORMULA / array-evaluated arguments).
  bool arrayMode;

  /// LET/LAMBDA bindings.
  LambdaEnv? env;

  /// Lambda recursion depth.
  int callDepth = 0;

  /// Template slots (stored references of this cell).
  final List<StoredRef> slots;

  final DependencyRecorder deps;

  /// RAND call counter within this evaluation.
  int randCounter = 0;

  /// Abort flag for detached previews.
  bool Function()? shouldAbort;

  /// Offsets applied to relative reference parts (rule formulas, `compileRelative`).
  int rowOffset = 0;
  int colOffset = 0;

  EvalContext({
    required this.host,
    required this.sheet,
    required this.row,
    required this.col,
    this.rowId = '',
    this.colId = '',
    this.arrayMode = false,
    this.slots = const [],
    DependencyRecorder? deps,
  }) : deps = deps ?? DependencyRecorder();

  FormulaLocale get locale => host.locale;
  WorkbookView get workbook => host.workbook;

  /// Cell id string `sheetId:rowId:colId`.
  String get cellId => '${sheet.id}:$rowId:$colId';

  /// Evaluates [e] with array mode set to [mode], restoring the previous mode.
  FValue withMode(bool mode, CompiledExpr e) {
    final prev = arrayMode;
    arrayMode = mode;
    try {
      return e(this);
    } finally {
      arrayMode = prev;
    }
  }

  /// Current year in the spreadsheet time zone (dates without a year).
  int get currentYear {
    final now = host.clock.nowUtc();
    final off = host.timeZones.offsetAt(host.settings.timeZone, now);
    return now.add(off).year;
  }

  /// Looks up the spec of a built-in.
  FunctionSpec? builtin(String upper) => host.registry.lookup(upper);
}
