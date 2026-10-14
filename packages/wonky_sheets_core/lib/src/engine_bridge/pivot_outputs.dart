import '../addressing/grid_geometry.dart';
import '../formula/recalc/formula_engine.dart';
import '../model/grid_range.dart';
import '../model/records.dart';
import '../model/sheet_model.dart';
import '../model/workbook_model.dart';
import '../pivot/pivot_engine.dart';
import '../pivot/pivot_layout.dart';
import '../pivot/pivot_spec.dart';
import '../pivot/source_table.dart';
import '../rules/conditions/condition_evaluator.dart';
import '../rules/conditions/display_text.dart';
import 'engine_formula_hooks.dart';
import 'model_workbook_view.dart';
import 'pivot_formula_evaluator.dart';

/// A pivot table placed on its sheet: its laid-out output at its anchor.
final class PivotPlacement {
  /// Creates a placement.
  const PivotPlacement({
    required this.pivotId,
    required this.sheetId,
    required this.row,
    required this.col,
    required this.grid,
  });

  /// The pivot table id.
  final String pivotId;

  /// The sheet of the output.
  final String sheetId;

  /// The anchor (top-left cell).
  final int row;
  final int col;

  /// The laid-out output (never empty).
  final PivotGrid grid;

  /// The output rectangle.
  GridRect get rect =>
      GridRect(row, col, row + grid.rowCount - 1, col + grid.columnCount - 1);

  /// The output cell at absolute ([r], [c]), or null.
  PivotCell? cellAt(int r, int c) => grid.cellAt(r - row, c - col);
}

/// Pivot table outputs computed headlessly (07 §7.4–7.6) for consumers
/// without the app's overlay service — exports write pivot output as cells
/// (11 §1.3). Same placement rules as the app: per sheet in anchor order; an
/// output is left out when content is in its rectangle, an earlier pivot or
/// an earlier dynamic array overlaps it, or it doesn't fit the grid.
abstract final class PivotOutputs {
  /// Places every pivot of [model]; values come from [engine] (its workbook
  /// is a view of [model]).
  static List<PivotPlacement> compute(
    WorkbookModel model,
    FormulaEngine engine,
  ) {
    final locale = model.spreadsheet.locale;
    final display = FormatterDisplayText(locale: locale);
    final wb = engine.workbook;
    final hooks = EngineFormulaHooks(
      model,
      engine: engine,
      view: wb is ModelWorkbookView ? wb : null,
    );
    final out = <PivotPlacement>[];
    for (final s in model.sheets) {
      if (s.pivots.isEmpty) continue;
      final recs = s.pivots.values.toList();
      (int, int) pos(PivotTableRecord r) =>
          (s.rows.indexOf(r.anchorRowId), s.columns.indexOf(r.anchorColId));
      recs.sort((a, b) {
        final (ar, ac) = pos(a);
        final (br, bc) = pos(b);
        return ar != br ? ar - br : (ac != bc ? ac - bc : a.id.compareTo(b.id));
      });
      final spills = engine.spillAreas(s.id);
      final placed = <GridRect>[];
      for (final rec in recs) {
        final (row, col) = pos(rec);
        if (row < 0 || col < 0) continue;
        final grid = _layout(model, engine, hooks, display, s, rec, row, col);
        if (grid == null || grid.isEmpty || grid.error != null) continue;
        final p = PivotPlacement(
          pivotId: rec.id,
          sheetId: s.id,
          row: row,
          col: col,
          grid: grid,
        );
        final rect = p.rect;
        if (rect.bottom >= s.rows.length || rect.right >= s.columns.length) {
          continue;
        }
        if (s.cellsIn(rect, contentOnly: true).isNotEmpty) continue;
        if (placed.any((r) => r.intersects(rect))) continue;
        if (spills.any(
          (a) =>
              a.rect.intersects(rect) &&
              (a.row < row || (a.row == row && a.col < col)),
        )) {
          continue;
        }
        placed.add(rect);
        out.add(p);
      }
    }
    return out;
  }

  static PivotGrid? _layout(
    WorkbookModel model,
    FormulaEngine engine,
    EngineFormulaHooks hooks,
    FormatterDisplayText display,
    SheetModel s,
    PivotTableRecord rec,
    int row,
    int col,
  ) {
    final g = GridRange.tryParse(rec.sourceRangeJson);
    final source = g == null ? null : model.resolve(g);
    if (source == null || model.sheet(source.sheetId) == null) return null;
    try {
      final table = SourceTable.fromModel(model, engine, source, display);
      final result = const PivotEngine().compute(
        PivotSpec.parse(rec.specJson),
        table,
        PivotContext(
          locale: model.spreadsheet.locale,
          conditions: ConditionEvaluator(
            locale: model.spreadsheet.locale,
            hooks: hooks,
          ),
          formulas: EnginePivotFormulaEvaluator(
            engine,
            sheetId: s.id,
            row: row,
            col: col,
          ),
        ),
      );
      return PivotLayout.build(result, labelText: display.displayText);
    } on Object {
      return null;
    }
  }
}
