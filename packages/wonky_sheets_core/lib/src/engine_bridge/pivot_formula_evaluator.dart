import '../content/cell_content.dart';
import '../formula/recalc/formula_engine.dart';
import '../formula/values/fvalue.dart';
import '../pivot/pivot_engine.dart';
import '../pivot/pivot_spec.dart';
import 'value_bridge.dart';

/// [PivotFormulaEvaluator] over the formula engine (07 §7.4 step 4): the field
/// tokens `⟦F:<colId>⟧` of a calculated field are LET-like bindings of
/// [FormulaEngine.compileWithBindings]. Each formula is compiled once and
/// reused for every source row / output cell.
final class EnginePivotFormulaEvaluator implements PivotFormulaEvaluator {
  /// Creates the evaluator. Other references in calculated field formulas
  /// resolve on [sheetId] relative to ([row], [col]) (normally the pivot's
  /// anchor).
  EnginePivotFormulaEvaluator(
    this.engine, {
    required this.sheetId,
    this.row = 0,
    this.col = 0,
  });

  /// The formula engine.
  final FormulaEngine engine;

  /// Sheet the formulas' other references resolve against.
  final String sheetId;

  /// Position the formulas' relative references resolve against.
  final int row;
  final int col;

  final Map<String, BoundFormula> _compiled = {};

  BoundFormula _compile(String formula) => _compiled.putIfAbsent(
    formula,
    () => engine.compileWithBindings(
      formula,
      PivotFormula.fieldIds(formula),
      sheetId: sheetId,
      row: row,
      col: col,
      stored: true,
    ),
  );

  @override
  CellValue evaluateRow(
    String formula,
    CellValue Function(String colId) field,
  ) {
    final f = _compile(formula);
    return f.evaluate([
      for (final id in f.names) field(id).toFValue(),
    ]).toCellValue();
  }

  @override
  CellValue evaluateGroup(
    String formula,
    List<CellValue> Function(String colId) field,
  ) {
    final f = _compile(formula);
    return f.evaluate([
      for (final id in f.names) _column(field(id)),
    ]).toCellValue();
  }

  static FValue _column(List<CellValue> values) => values.isEmpty
      ? FEmpty.instance
      : FArray.column([for (final v in values) v.toFValue()]);
}
