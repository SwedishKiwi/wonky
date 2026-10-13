import '../addressing/grid_geometry.dart';
import '../content/cell_content.dart';
import '../formula/model/workbook_view.dart';
import '../formula/values/fvalue.dart';
import '../model/workbook_model.dart';
import 'value_bridge.dart';

/// A [CellSource] over a [WorkbookModel]: literal cell values plus, for
/// formula cells, the values supplied by [computed] (the formula engine) —
/// without an engine formulas read as empty.
///
/// Used where no engine runs (tests, import previews) and as the base the app
/// and server wrap around their `FormulaEngine`.
final class ModelCellSource implements CellSource {
  /// Creates the source. [_computed] returns the engine value of a formula
  /// cell (or null to fall back to empty); [_formatHint] returns the result's
  /// format hint pattern for cells with Automatic format.
  ModelCellSource(this.model, {this._computed, this._formatHint});

  /// The model.
  final WorkbookModel model;
  final FValue? Function(String, int, int)? _computed;
  final String? Function(String, int, int)? _formatHint;

  @override
  FValue valueAt(String sheetId, int row, int col) {
    final cell = model.cellAt(sheetId, row, col);
    final content = cell?.decoded;
    if (content == null) {
      // Spill/pivot overlays come from the engine.
      return _computed?.call(sheetId, row, col) ?? FEmpty.instance;
    }
    if (content is FormulaContent) {
      return _computed?.call(sheetId, row, col) ?? FEmpty.instance;
    }
    return content.literalValue.toFValue();
  }

  /// [valueAt] as a model [CellValue].
  CellValue cellValueAt(String sheetId, int row, int col) =>
      valueAt(sheetId, row, col).toCellValue();

  @override
  String? numberFormatAt(String sheetId, int row, int col) {
    final explicit =
        model.explicitFormatChain(sheetId, row, col).toMap()['numberFormat']
            as String?;
    return explicit ?? _formatHint?.call(sheetId, row, col);
  }

  @override
  bool isHidden(
    String sheetId,
    GridDimension dimension,
    int index, {
    bool includeFilter = true,
  }) {
    final s = model.sheet(sheetId);
    if (s == null) return false;
    final axis = dimension == GridDimension.rows ? s.rows : s.columns;
    if (index < 0 || index >= axis.length) return false;
    if (axis.isUserHidden(index)) return true;
    if (axis.isHiddenBy('groups', index)) return true;
    if (includeFilter &&
        (axis.isHiddenBy('filter', index) ||
            axis.isHiddenBy('slicer', index))) {
      return true;
    }
    return false;
  }
}

/// Names of the computed hidden layers of `AxisIndex` used across the app.
abstract final class HiddenLayers {
  /// Rows hidden by the basic filter.
  static const filter = 'filter';

  /// Rows hidden by slicers.
  static const slicer = 'slicer';

  /// Rows/columns inside collapsed groups.
  static const groups = 'groups';

  /// Rows hidden by the active filter view (this user only; not used by formulas).
  static const filterView = 'filterView';
}
