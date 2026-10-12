import '../../content/cell_content.dart';
import '../sort/sort_keys.dart';
import 'filter_engine.dart';

/// Display text → rows of one filter column (07 §3.4), maintained
/// incrementally so toggling a checklist value is O(rows with that value).
final class ValueIndex {
  ValueIndex._(this.col, this.top, this._texts, this._rows, this._repr);

  /// Builds the index for rows [top]..[bottom] of column [col].
  factory ValueIndex.build(FilterDataSource source, int col, int top, int bottom) {
    final n = bottom - top + 1 < 0 ? 0 : bottom - top + 1;
    final texts = List<String>.filled(n, '');
    final rows = <String, List<int>>{};
    final repr = <String, CellValue>{};
    for (var i = 0; i < n; i++) {
      final r = top + i;
      final v = source.valueAt(r, col);
      final t = v.isBlank() ? '' : source.displayTextAt(r, col);
      texts[i] = t;
      (rows[t] ??= []).add(r);
      repr.putIfAbsent(t, () => v);
    }
    return ValueIndex._(col, top, texts, rows, repr);
  }

  /// Column index.
  final int col;

  /// First indexed row.
  final int top;
  final List<String> _texts;
  final Map<String, List<int>> _rows;
  final Map<String, CellValue> _repr;
  List<String>? _sorted;

  /// Number of indexed rows.
  int get length => _texts.length;

  /// Display text of [row] (`""` for blanks).
  String textAt(int row) {
    final i = row - top;
    return i >= 0 && i < _texts.length ? _texts[i] : '';
  }

  /// Rows showing [text], ascending.
  List<int> rowsOf(String text) => _rows[text] ?? const [];

  /// Number of rows showing [text].
  int count(String text) => _rows[text]?.length ?? 0;

  /// Distinct texts.
  Iterable<String> get texts => _rows.keys;

  /// Distinct texts: `""` (Blanks) first, then by the sort order of their values (07 §2.3).
  List<String> get sortedTexts => _sorted ??= () {
    final l = _rows.keys.toList();
    l.sort((a, b) {
      if (a.isEmpty || b.isEmpty) return a.isEmpty ? (b.isEmpty ? 0 : -1) : 1;
      final c = SortKeys.compare(_repr[a]!, _repr[b]!);
      return c != 0 ? c : a.compareTo(b);
    });
    return l;
  }();

  /// Updates [row] after its value changed.
  void update(int row, CellValue value, String displayText) {
    final i = row - top;
    if (i < 0 || i >= _texts.length) return;
    final t = value.isBlank() ? '' : displayText;
    final old = _texts[i];
    if (old == t) return;
    final oldRows = _rows[old];
    if (oldRows != null) {
      oldRows.remove(row);
      if (oldRows.isEmpty) {
        _rows.remove(old);
        _repr.remove(old);
      }
    }
    final list = _rows[t] ??= [];
    var pos = list.length;
    while (pos > 0 && list[pos - 1] > row) {
      pos--;
    }
    list.insert(pos, row);
    _repr.putIfAbsent(t, () => value);
    _texts[i] = t;
    _sorted = null;
  }
}
