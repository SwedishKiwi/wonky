import '../../addressing/grid_geometry.dart';
import '../../formula/model/workbook_view.dart';
import '../../model/axis_index.dart';

/// Row or column ids of a sheet as they will exist after an import plan: the
/// ids of an existing axis (if any) followed by appended ids.
final class PlannedAxis implements AxisView {
  /// Creates an axis over [base] (existing rows/columns, or null for a new
  /// sheet) followed by [ids]/[keys].
  PlannedAxis({this.base, List<String>? ids, List<String>? keys})
    : _ids = ids ?? [],
      _keys = keys ?? [];

  /// Existing axis (model), or null.
  final AxisIndex? base;
  final List<String> _ids;
  final List<String> _keys;
  Map<String, int>? _index;

  int get _baseLength => base?.length ?? 0;

  /// Appends an entry.
  void add(String id, String key) {
    _ids.add(id);
    _keys.add(key);
    _index?[id] = _baseLength + _ids.length - 1;
  }

  /// The last sort key (null when empty).
  String? get lastKey => _keys.isNotEmpty
      ? _keys.last
      : (_baseLength > 0 ? base!.sortKeyAt(_baseLength - 1) : null);

  @override
  int get length => _baseLength + _ids.length;

  @override
  String idAt(int index) {
    final n = _baseLength;
    return index < n ? base!.idAt(index) : _ids[index - n];
  }

  /// Id at [index] or null when out of range.
  String? tryIdAt(int index) =>
      index < 0 || index >= length ? null : idAt(index);

  @override
  int indexOf(String id) {
    final b = base?.indexOf(id) ?? -1;
    if (b >= 0) return b;
    final idx = _index ??= {
      for (var i = 0; i < _ids.length; i++) _ids[i]: _baseLength + i,
    };
    return idx[id] ?? -1;
  }

  @override
  String sortKeyAt(int index) {
    final n = _baseLength;
    return index < n ? base!.sortKeyAt(index) : _keys[index - n];
  }

  @override
  int lowerBound(String sortKey, String id) {
    var lo = 0;
    var hi = length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      final k = sortKeyAt(mid);
      final c = k.compareTo(sortKey);
      if (c < 0 || (c == 0 && idAt(mid).compareTo(id) < 0)) {
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

/// A sheet as it will exist after an import plan (ids only, no content):
/// enough for converting A1 formulas to the stored form.
final class PlannedSheetView implements SheetView {
  /// Creates a view.
  PlannedSheetView(this.id, this.name, this.rows, this.columns);

  @override
  final String id;

  @override
  final String name;

  @override
  final PlannedAxis rows;

  @override
  final PlannedAxis columns;

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

/// A named range as it will exist after an import plan.
final class PlannedNameView implements NamedRangeView {
  /// Creates a view.
  const PlannedNameView(this.id, this.name);

  @override
  final String id;

  @override
  final String name;

  @override
  IdRange? get range => null;

  @override
  String? get formula => null;

  @override
  String? get comment => null;

  @override
  String? get metaJson => null;
}

/// The workbook as it will exist after an import plan: planned and kept
/// sheets and names (formula codec input, 11 §1.2).
final class PlannedWorkbookView implements WorkbookView {
  /// Creates a view.
  PlannedWorkbookView(
    this.spreadsheetId, {
    this.settings = const CalcSettings(),
  });

  @override
  final String spreadsheetId;

  @override
  final CalcSettings settings;

  final List<PlannedSheetView> _sheets = [];
  final Map<String, PlannedSheetView> _byId = {};
  final Map<String, PlannedSheetView> _byName = {};
  final List<PlannedNameView> _names = [];

  /// Adds a sheet (later sheets with the same name do not replace earlier
  /// ones).
  void addSheet(PlannedSheetView s) {
    _sheets.add(s);
    _byId[s.id] = s;
    _byName.putIfAbsent(s.name.toLowerCase(), () => s);
  }

  /// Adds a name.
  void addName(PlannedNameView n) => _names.add(n);

  @override
  List<SheetView> get sheets => List.unmodifiable(_sheets);

  @override
  PlannedSheetView? sheetById(String id) => _byId[id];

  @override
  PlannedSheetView? sheetByName(String name) => _byName[name.toLowerCase()];

  @override
  Iterable<NamedRangeView> get namedRanges => _names;
}
