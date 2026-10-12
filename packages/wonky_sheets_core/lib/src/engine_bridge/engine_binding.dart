import '../addressing/grid_geometry.dart';
import '../formula/recalc/engine_types.dart';
import '../formula/recalc/formula_engine.dart';
import '../model/events.dart';
import '../model/schema.dart';
import '../model/workbook_model.dart';
import 'model_workbook_view.dart';

/// Forwards [WorkbookModel] change batches to a [FormulaEngine] (05 §7.1
/// change ingestion): content changes, axis inserts/deletes/moves (diffed
/// against the previous id order), sheet list, names and calc settings.
///
/// Used by the client `RecalcHost` and the server `HeadlessWorkbook`.
final class ModelEngineBinding {
  /// Binds [engine] (built over [view]) to [model]; call [dispose] to detach.
  ModelEngineBinding(this.model, this.engine, this.view) {
    _snapshotAll();
    model.addListener(_onBatch);
  }

  /// Creates a view, an engine (with [engineFactory]) and the binding.
  static ModelEngineBinding create(
    WorkbookModel model, {
    FormulaEngine Function(ModelWorkbookView view)? engineFactory,
  }) {
    final view = ModelWorkbookView(model);
    final engine = engineFactory?.call(view) ?? FormulaEngine(workbook: view);
    return ModelEngineBinding(model, engine, view);
  }

  final WorkbookModel model;
  final FormulaEngine engine;
  final ModelWorkbookView view;

  final Map<(String, Dimension), List<String>> _order = {};

  void _snapshotAll() {
    for (final s in model.sheets) {
      _order[(s.id, Dimension.rows)] = List.of(s.rows.ids);
      _order[(s.id, Dimension.columns)] = List.of(s.columns.ids);
    }
  }

  /// Stops listening.
  void dispose() => model.removeListener(_onBatch);

  void _onBatch(WorkbookChangeBatch batch) {
    for (final e in batch.events) {
      switch (e) {
        case SpreadsheetChanged(:final columns):
          if (columns.any(_calcColumns.contains)) engine.settingsChanged(view.settings);
        case SheetsChanged():
          engine.sheetsChanged();
          for (final id in e.sheetIds) {
            final s = model.sheet(id);
            if (s == null) {
              _order.remove((id, Dimension.rows));
              _order.remove((id, Dimension.columns));
            } else {
              _order.putIfAbsent((id, Dimension.rows), () => List.of(s.rows.ids));
              _order.putIfAbsent((id, Dimension.columns), () => List.of(s.columns.ids));
            }
          }
        case StructureChanged(:final sheetId, :final dimension):
          if (e.order) _axis(sheetId, dimension);
          if (e.sizes && dimension == Dimension.rows) engine.filterVisibilityChanged(sheetId);
          if (e.sizes && dimension == Dimension.columns) {
            engine.axisChanged(sheetId, GridDimension.columns, const AxisChange.resized());
          }
        case CellsChanged(:final sheetId):
          final s = model.sheet(sheetId);
          if (s == null || e.contentKeys.isEmpty) break;
          final positions = <CellPos>[];
          for (final k in e.contentKeys) {
            final r = s.rows.indexOf(k.rowId);
            final c = s.columns.indexOf(k.colId);
            if (r >= 0 && c >= 0) positions.add(CellPos(r, c));
          }
          if (positions.isNotEmpty) engine.cellsChanged(sheetId, positions);
        case NamesChanged(:final names):
          engine.namesChanged(names);
        case RulesChanged():
        case OtherRowsChanged():
          break;
      }
    }
  }

  static const _calcColumns = {
    SpreadsheetCols.locale,
    SpreadsheetCols.timeZone,
    SpreadsheetCols.recalcMode,
    SpreadsheetCols.iterativeCalc,
    SpreadsheetCols.maxIterations,
    SpreadsheetCols.convergenceThreshold,
  };

  void _axis(String sheetId, Dimension d) {
    final s = model.sheet(sheetId);
    if (s == null) return;
    final now = List.of(s.axis(d).ids);
    final before = _order[(sheetId, d)] ?? const <String>[];
    _order[(sheetId, d)] = now;
    final gd = d == Dimension.rows ? GridDimension.rows : GridDimension.columns;
    final nowSet = now.toSet();
    final beforeSet = before.toSet();
    final deleted = [
      for (final id in before)
        if (!nowSet.contains(id)) id,
    ];
    final inserted = [
      for (var i = 0; i < now.length; i++)
        if (!beforeSet.contains(now[i])) i,
    ];
    if (deleted.isNotEmpty) {
      final first = before.indexOf(deleted.first);
      engine.axisChanged(sheetId, gd, AxisChange.deleted(first, deleted.length, deleted));
    }
    if (inserted.isNotEmpty) {
      engine.axisChanged(
        sheetId,
        gd,
        AxisChange.inserted(inserted.first, inserted.last - inserted.first + 1),
      );
    }
    if (deleted.isEmpty && inserted.isEmpty) {
      final moved = <String>[];
      final oldPos = {for (var i = 0; i < before.length; i++) before[i]: i};
      for (var i = 0; i < now.length; i++) {
        if (oldPos[now[i]] != i) moved.add(now[i]);
      }
      if (moved.isNotEmpty) engine.axisChanged(sheetId, gd, AxisChange.moved(moved));
    }
  }
}
