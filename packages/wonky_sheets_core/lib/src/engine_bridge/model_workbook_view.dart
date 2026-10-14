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

/// Computed cell values layered under empty cells — pivot table output
/// (07 §7.6). The engine reads them as literal inputs, so formulas, the
/// grid and the clipboard see them like spilled values. The owner calls
/// `FormulaEngine.rectChanged` for the rectangles whose values changed.
abstract interface class ComputedOverlaySource {
  /// The overlay input at ([row], [col]) of [sheetId], or null. Only asked
  /// for cells without content.
  EngineCellInput? inputAt(String sheetId, int row, int col);

  /// The number format of the overlay cell, or null (Automatic).
  String? numberFormatAt(String sheetId, int row, int col);

  /// The overlay rectangles of [sheetId] (used extent, range scans).
  Iterable<GridRect> rectsOf(String sheetId);
}

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

  /// Computed overlays (pivot output) shown in empty cells, or null.
  ComputedOverlaySource? overlays;

  final Expando<_SheetView> _views = Expando();

  @override
  String get spreadsheetId => model.spreadsheetId;

  @override
  List<SheetView> get sheets => [
    for (final s in model.sheets)
      if (s.record!.kind == SheetKind.grid) _view(s),
  ];

  _SheetView _view(SheetModel s) => _views[s] ??= _SheetView(s, model, this);

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
  Iterable<NamedRangeView> get namedRanges =>
      model.namedRanges.map(_NamedView.new);

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
  _SheetView(this.s, this.model, this.owner)
    : rows = _AxisView(s.rows, true),
      columns = _AxisView(s.columns, false);

  final SheetModel s;
  final WorkbookModel model;
  final ModelWorkbookView owner;

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
  CellInput? inputAt(int row, int col) {
    final cell = s.cellAt(row, col);
    final input = cellInputOf(cell);
    if (input != null) return input;
    return owner.overlays?.inputAt(s.id, row, col);
  }

  @override
  void forEachInput(
    GridRect rect,
    void Function(int row, int col, CellInput input) visit,
  ) {
    final o = owner.overlays;
    final hits = o == null
        ? const <GridRect>[]
        : [
            for (final r in o.rectsOf(s.id))
              if (r.intersection(rect) case final GridRect i) i,
          ];
    if (hits.isEmpty) {
      for (final (r, c, cell) in s.cellsIn(rect, contentOnly: true)) {
        final input = cellInputOf(cell);
        if (input != null) visit(r, c, input);
      }
      return;
    }
    // Merge content and overlay cells in row-major order.
    final out = <(int, int, CellInput)>[];
    final seen = <int>{};
    for (final (r, c, cell) in s.cellsIn(rect, contentOnly: true)) {
      final input = cellInputOf(cell);
      if (input == null) continue;
      out.add((r, c, input));
      seen.add(r * 0x100000 + c);
    }
    for (final i in hits) {
      for (var r = i.top; r <= i.bottom; r++) {
        for (var c = i.left; c <= i.right; c++) {
          if (seen.contains(r * 0x100000 + c)) continue;
          final input = o!.inputAt(s.id, r, c);
          if (input != null) out.add((r, c, input));
        }
      }
    }
    out.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    for (final (r, c, input) in out) {
      visit(r, c, input);
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
    var n = _usedRows;
    for (final r in owner.overlays?.rectsOf(s.id) ?? const <GridRect>[]) {
      if (r.bottom + 1 > n) n = r.bottom + 1;
    }
    return n;
  }

  @override
  int get usedColumnCount {
    _computeUsed();
    var n = _usedCols;
    for (final r in owner.overlays?.rectsOf(s.id) ?? const <GridRect>[]) {
      if (r.right + 1 > n) n = r.right + 1;
    }
    return n;
  }

  @override
  String? numberFormatAt(int row, int col) {
    final f =
        model.explicitFormatChain(s.id, row, col)[FormatAttr.numberFormat]
            as String?;
    if (f != null) return f == 'preset:automatic' ? null : f;
    final o = owner.overlays;
    if (o == null || s.cellAt(row, col)?.content != null) return null;
    return o.numberFormatAt(s.id, row, col);
  }

  @override
  bool isRowFilterHidden(int row) =>
      row >= 0 &&
      row < s.rows.length &&
      (s.rows.isHiddenBy(HiddenLayers.filter, row) ||
          s.rows.isHiddenBy(HiddenLayers.slicer, row));

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
