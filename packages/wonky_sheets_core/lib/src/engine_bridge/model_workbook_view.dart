import '../addressing/grid_geometry.dart';
import '../format/attributes.dart';
import '../formula/model/workbook_view.dart';
import '../model/axis_index.dart';
import '../model/grid_range.dart';
import '../model/records.dart';
import '../model/schema.dart';
import '../model/sheet_model.dart';
import '../model/workbook_model.dart';
import 'model_cell_source.dart';

/// Adapts a [WorkbookModel] to the formula engine's [WorkbookView] (05 §2.1),
/// used by the client `RecalcHost`, the server `HeadlessWorkbook` and the
/// planner's formula hooks.
///
/// Views are cached per sheet; `CellInput` instances are cached per immutable
/// [CellRecord], so the engine sees a new input exactly when content changes.
final class ModelWorkbookView implements WorkbookView {
  /// Creates the adapter.
  ModelWorkbookView(this.model);

  /// The model.
  final WorkbookModel model;

  final Expando<_SheetView> _views = Expando();

  @override
  String get spreadsheetId => model.spreadsheetId;

  @override
  List<SheetView> get sheets => [
    for (final s in model.sheets)
      if (s.record!.kind == SheetKind.grid) _view(s),
  ];

  _SheetView _view(SheetModel s) => _views[s] ??= _SheetView(s, model);

  @override
  SheetView? sheetById(String id) {
    final s = model.sheet(id);
    return s == null || s.record!.kind != SheetKind.grid ? null : _view(s);
  }

  @override
  SheetView? sheetByName(String name) {
    final s = model.sheetByName(name);
    return s == null || s.record!.kind != SheetKind.grid ? null : _view(s);
  }

  @override
  Iterable<NamedRangeView> get namedRanges => model.namedRanges.map(_NamedView.new);

  @override
  CalcSettings get settings {
    final sp = model.spreadsheet;
    return CalcSettings(
      locale: sp.locale,
      timeZone: sp.timeZone,
      recalcMode: sp.recalcMode,
      iterativeCalc: sp.iterativeCalc,
      maxIterations: sp.maxIterations,
      convergenceThreshold: sp.convergenceThreshold,
    );
  }
}

final Expando<CellInput> _inputs = Expando();

/// The engine input of a cell record (cached per record instance).
CellInput? cellInputOf(CellRecord? c) {
  if (c == null || c.content == null) return null;
  final cached = _inputs[c];
  if (cached != null) return cached;
  final input = CellInput.fromContent(c.content);
  if (input != null) _inputs[c] = input;
  return input;
}

final class _AxisView implements AxisView {
  _AxisView(this.axis, this.isRows);
  final AxisIndex axis;
  final bool isRows;

  @override
  int get length => axis.length;

  @override
  String idAt(int index) => axis.idAt(index);

  @override
  int indexOf(String id) => axis.indexOf(id);

  @override
  String sortKeyAt(int index) => axis.sortKeyAt(index);

  @override
  int lowerBound(String sortKey, String id) => axis.insertionIndex(sortKey, id);

  @override
  bool isHidden(int index) =>
      axis.isUserHidden(index) || axis.isHiddenBy(HiddenLayers.groups, index);
}

final class _SheetView implements SheetView {
  _SheetView(this.s, this.model)
    : rows = _AxisView(s.rows, true),
      columns = _AxisView(s.columns, false);

  final SheetModel s;
  final WorkbookModel model;

  @override
  final AxisView rows;

  @override
  final AxisView columns;

  int _usedVersion = -1;
  int _usedRows = 0;
  int _usedCols = 0;

  @override
  String get id => s.id;

  @override
  String get name => s.name;

  @override
  CellInput? inputAt(int row, int col) => cellInputOf(s.cellAt(row, col));

  @override
  void forEachInput(GridRect rect, void Function(int row, int col, CellInput input) visit) {
    for (final (r, c, cell) in s.cellsIn(rect, contentOnly: true)) {
      final input = cellInputOf(cell);
      if (input != null) visit(r, c, input);
    }
  }

  void _computeUsed() {
    if (_usedVersion == model.version) return;
    final e = s.cells.usedExtent(s.rows, s.columns);
    _usedRows = e == null ? 0 : e.$1 + 1;
    _usedCols = e == null ? 0 : e.$2 + 1;
    _usedVersion = model.version;
  }

  @override
  int get usedRowCount {
    _computeUsed();
    return _usedRows;
  }

  @override
  int get usedColumnCount {
    _computeUsed();
    return _usedCols;
  }

  @override
  String? numberFormatAt(int row, int col) {
    final f = model.explicitFormatChain(s.id, row, col)[FormatAttr.numberFormat] as String?;
    return f == 'preset:automatic' ? null : f;
  }

  @override
  bool isRowFilterHidden(int row) =>
      row >= 0 &&
      row < s.rows.length &&
      (s.rows.isHiddenBy(HiddenLayers.filter, row) || s.rows.isHiddenBy(HiddenLayers.slicer, row));

  @override
  double columnWidthAt(int col) =>
      col >= 0 && col < s.columns.length ? s.columns.naturalSizeAt(col) : 100;
}

final class _NamedView implements NamedRangeView {
  _NamedView(this.r);
  final NamedRangeRecord r;

  @override
  String get id => r.id;

  @override
  String get name => r.name;

  @override
  IdRange? get range {
    final g = GridRange.tryParse(r.rangeJson);
    if (g == null) return null;
    return IdRange(
      g.sheetId,
      rowStart: g.r1,
      rowEnd: g.r2,
      colStart: g.c1,
      colEnd: g.c2,
      rowStartKey: g.r1k,
      rowEndKey: g.r2k,
      colStartKey: g.c1k,
      colEndKey: g.c2k,
    );
  }

  @override
  String? get formula => r.formula;

  @override
  String? get comment => r.comment;

  @override
  String? get metaJson => r.metaJson;
}
