import 'package:wonky_sheets_core/formula.dart'
    show
        AxisView,
        CalcSettings,
        CodecContext,
        EngineCellInput,
        FormulaCodec,
        GridRect,
        NamedRangeView,
        SheetView,
        WorkbookView;

/// Converts A1 template formulas to the stored, id-based form (Sheets 02 §2)
/// with `FormulaCodec` over a minimal one-sheet workbook view.
class TemplateFormulas implements WorkbookView {
  TemplateFormulas({
    required String sheetId,
    required String sheetName,
    required List<String> rowIds,
    required List<String> rowKeys,
    required List<String> columnIds,
    required List<String> columnKeys,
  }) : _sheet = _TemplateSheetView(
         sheetId,
         sheetName,
         _TemplateAxis(rowIds, rowKeys),
         _TemplateAxis(columnIds, columnKeys),
       );

  final _TemplateSheetView _sheet;

  /// Stored form of [a1] (with `=`) at ([row], [col]).
  String toStored(String a1, int row, int col) => FormulaCodec.toStored(
    a1,
    CodecContext(
      workbook: this,
      hostSheetId: _sheet.id,
      hostRow: row,
      hostCol: col,
    ),
  );

  @override
  String get spreadsheetId => _sheet.id;

  @override
  List<SheetView> get sheets => [_sheet];

  @override
  SheetView? sheetById(String id) => id == _sheet.id ? _sheet : null;

  @override
  SheetView? sheetByName(String name) =>
      name.toLowerCase() == _sheet.name.toLowerCase() ? _sheet : null;

  @override
  Iterable<NamedRangeView> get namedRanges => const [];

  @override
  CalcSettings get settings => const CalcSettings();
}

class _TemplateAxis implements AxisView {
  _TemplateAxis(this._ids, this._keys)
    : _index = {for (var i = 0; i < _ids.length; i++) _ids[i]: i};

  final List<String> _ids;
  final List<String> _keys;
  final Map<String, int> _index;

  @override
  int get length => _ids.length;

  @override
  String idAt(int index) => _ids[index];

  @override
  int indexOf(String id) => _index[id] ?? -1;

  @override
  String sortKeyAt(int index) => _keys[index];

  @override
  int lowerBound(String sortKey, String id) {
    var lo = 0;
    var hi = _keys.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      final c = _keys[mid].compareTo(sortKey);
      if (c < 0 || (c == 0 && _ids[mid].compareTo(id) < 0)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  @override
  bool isHidden(int index) => false;
}

class _TemplateSheetView implements SheetView {
  _TemplateSheetView(this.id, this.name, this.rows, this.columns);

  @override
  final String id;
  @override
  final String name;
  @override
  final AxisView rows;
  @override
  final AxisView columns;

  @override
  EngineCellInput? inputAt(int row, int col) => null;

  @override
  void forEachInput(
    GridRect rect,
    void Function(int row, int col, EngineCellInput input) visit,
  ) {}

  @override
  int get usedRowCount => 0;

  @override
  int get usedColumnCount => 0;

  @override
  String? numberFormatAt(int row, int col) => null;

  @override
  bool isRowFilterHidden(int row) => false;

  @override
  double columnWidthAt(int col) => 100;
}
