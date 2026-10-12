import 'dart:collection';
import 'dart:typed_data';

/// A row-major sparse grid (11 §1.1): rows are stored as compact, column-sorted
/// arrays so large imports avoid a hash map entry per cell.
final class SparseGrid<T extends Object> {
  /// Creates an empty grid.
  SparseGrid();

  final Map<int, _GridRow<T>> _rows = {};
  List<int>? _sortedRows;
  int _count = 0;

  /// Number of stored values.
  int get length => _count;

  /// Whether the grid holds no value.
  bool get isEmpty => _count == 0;

  /// Whether the grid holds a value.
  bool get isNotEmpty => _count != 0;

  /// The value at ([row], [col]) or null.
  T? get(int row, int col) => _rows[row]?.get(col);

  /// Sets (or with null removes) the value at ([row], [col]).
  void set(int row, int col, T? value) {
    if (row < 0 || col < 0) throw RangeError('Negative grid position ($row, $col)');
    var r = _rows[row];
    if (value == null) {
      if (r == null) return;
      if (r.remove(col)) {
        _count--;
        if (r.length == 0) {
          _rows.remove(row);
          _sortedRows = null;
        }
      }
      return;
    }
    if (r == null) {
      r = _GridRow<T>();
      _rows[row] = r;
      final sorted = _sortedRows;
      if (sorted != null && (sorted.isEmpty || sorted.last < row)) {
        sorted.add(row);
      } else {
        _sortedRows = null;
      }
    }
    if (r.put(col, value)) _count++;
  }

  /// Row indices holding values, ascending.
  List<int> get rowIndices => _sortedRows ??= (_rows.keys.toList()..sort());

  /// `(col, value)` pairs of [row], ascending by column.
  Iterable<(int col, T value)> rowEntries(int row) sync* {
    final r = _rows[row];
    if (r == null) return;
    for (var i = 0; i < r.length; i++) {
      yield (r.cols[i], r.values[i] as T);
    }
  }

  /// Number of values in [row].
  int rowLength(int row) => _rows[row]?.length ?? 0;

  /// All values in row-major order.
  Iterable<(int row, int col, T value)> get entries sync* {
    for (final row in rowIndices) {
      final r = _rows[row]!;
      for (var i = 0; i < r.length; i++) {
        yield (row, r.cols[i], r.values[i] as T);
      }
    }
  }

  /// Largest row index holding a value, or -1.
  int get maxRow => _rows.isEmpty ? -1 : rowIndices.last;

  /// Largest column index holding a value, or -1.
  int get maxCol {
    var m = -1;
    for (final r in _rows.values) {
      if (r.length > 0 && r.cols[r.length - 1] > m) m = r.cols[r.length - 1];
    }
    return m;
  }

  /// Removes every value.
  void clear() {
    _rows.clear();
    _sortedRows = null;
    _count = 0;
  }
}

final class _GridRow<T extends Object> {
  Int32List cols = Int32List(4);
  List<T?> values = List<T?>.filled(4, null);
  int length = 0;

  int _find(int col) {
    var lo = 0;
    var hi = length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final c = cols[mid];
      if (c == col) return mid;
      if (c < col) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return -(lo + 1);
  }

  T? get(int col) {
    if (length == 0) return null;
    if (cols[length - 1] == col) return values[length - 1];
    final i = _find(col);
    return i >= 0 ? values[i] : null;
  }

  /// Returns true when a new entry was added (false when replaced).
  bool put(int col, T value) {
    if (length == 0 || cols[length - 1] < col) {
      _grow();
      cols[length] = col;
      values[length] = value;
      length++;
      return true;
    }
    final i = _find(col);
    if (i >= 0) {
      values[i] = value;
      return false;
    }
    final at = -(i + 1);
    _grow();
    cols.setRange(at + 1, length + 1, cols, at);
    values.setRange(at + 1, length + 1, values, at);
    cols[at] = col;
    values[at] = value;
    length++;
    return true;
  }

  bool remove(int col) {
    final i = _find(col);
    if (i < 0) return false;
    cols.setRange(i, length - 1, cols, i + 1);
    values.setRange(i, length - 1, values, i + 1);
    length--;
    values[length] = null;
    return true;
  }

  void _grow() {
    if (length < cols.length) return;
    final n = cols.length * 2;
    final c = Int32List(n)..setRange(0, length, cols);
    final v = List<T?>.filled(n, null)..setRange(0, length, values);
    cols = c;
    values = v;
  }
}

/// A sparse, ordered map of row or column index → value (row/column
/// properties of an [IrSheet]).
final class SparseAxis<T extends Object> {
  /// Creates an empty axis.
  SparseAxis();

  final SplayTreeMap<int, T> _map = SplayTreeMap();

  /// Value at [index] or null.
  T? operator [](int index) => _map[index];

  /// Sets (null removes) the value at [index].
  void operator []=(int index, T? value) {
    if (value == null) {
      _map.remove(index);
    } else {
      _map[index] = value;
    }
  }

  /// Entries ascending by index.
  Iterable<MapEntry<int, T>> get entries => _map.entries;

  /// Number of entries.
  int get length => _map.length;

  /// Whether empty.
  bool get isEmpty => _map.isEmpty;

  /// Largest index or -1.
  int get maxIndex => _map.isEmpty ? -1 : _map.lastKey()!;

  /// Removes all entries.
  void clear() => _map.clear();
}
