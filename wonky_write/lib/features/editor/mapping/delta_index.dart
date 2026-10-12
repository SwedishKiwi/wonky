/// Prefix sums over node Delta lengths (Write 02 §4.1): a Fenwick tree keyed by
/// node order.
///
/// Length changes of a node are O(log n). Structural changes (nodes inserted or
/// removed) rebuild the tree in O(n), which is cheap compared to the layout
/// work they cause.
class DeltaIndex {
  DeltaIndex([Iterable<int> lengths = const []]) {
    reset(lengths);
  }

  List<int> _lengths = [];
  List<int> _tree = [0];
  int _total = 0;

  /// Number of nodes.
  int get count => _lengths.length;

  /// Total Delta length of the document.
  int get totalLength => _total;

  /// Delta length of node [index].
  int lengthAt(int index) => _lengths[index];

  /// Replaces all lengths.
  void reset(Iterable<int> lengths) {
    _lengths = List<int>.of(lengths);
    _rebuild();
  }

  void _rebuild() {
    final n = _lengths.length;
    final tree = List<int>.filled(n + 1, 0);
    var total = 0;
    for (var i = 0; i < n; i += 1) {
      final length = _lengths[i];
      total += length;
      var j = i + 1;
      tree[j] += length;
      final parent = j + (j & -j);
      if (parent <= n) {
        tree[parent] += tree[j];
      }
    }
    _tree = tree;
    _total = total;
  }

  /// Sets the length of node [index].
  void setLength(int index, int length) {
    final diff = length - _lengths[index];
    if (diff == 0) {
      return;
    }
    _lengths[index] = length;
    _total += diff;
    for (var j = index + 1; j < _tree.length; j += j & -j) {
      _tree[j] += diff;
    }
  }

  /// Replaces the lengths of nodes `[start, end)` with [lengths].
  void replaceRange(int start, int end, List<int> lengths) {
    if (end - start == lengths.length) {
      for (var i = 0; i < lengths.length; i += 1) {
        setLength(start + i, lengths[i]);
      }
      return;
    }
    _lengths.replaceRange(start, end, lengths);
    _rebuild();
  }

  /// Delta offset at which node [index] starts (`index == count` → total).
  int startOf(int index) {
    var sum = 0;
    for (var j = index; j > 0; j -= j & -j) {
      sum += _tree[j];
    }
    return sum;
  }

  /// Index of the node that contains Delta [offset], i.e. the node with
  /// `startOf(i) <= offset < startOf(i) + lengthAt(i)`. Offsets at or past
  /// the end map to the last node. Zero-length nodes are skipped.
  int indexAt(int offset) {
    if (_lengths.isEmpty) {
      return -1;
    }
    if (offset >= _total) {
      return _lastNonEmpty();
    }
    if (offset < 0) {
      offset = 0;
    }
    // Find the largest prefix whose sum is <= offset.
    var pos = 0;
    var remaining = offset;
    var bit = 1;
    while (bit * 2 <= _lengths.length) {
      bit *= 2;
    }
    for (; bit > 0; bit >>= 1) {
      final next = pos + bit;
      if (next <= _lengths.length && _tree[next] <= remaining) {
        pos = next;
        remaining -= _tree[next];
      }
    }
    // `pos` nodes have a total length <= offset, so node `pos` contains it
    // (skipping empty nodes is implicit: a zero-length node never satisfies
    // `start <= offset < start + 0`, and the descent moves past it).
    return pos < _lengths.length ? pos : _lastNonEmpty();
  }

  int _lastNonEmpty() {
    for (var i = _lengths.length - 1; i >= 0; i -= 1) {
      if (_lengths[i] > 0) return i;
    }
    return _lengths.length - 1;
  }
}
