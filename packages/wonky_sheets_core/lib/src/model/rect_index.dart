import '../addressing/grid_geometry.dart';

/// A static index of rectangles answering point and rectangle queries in
/// O(log n + k) (centered interval tree over rows; columns checked per hit).
///
/// Used by `RuleIndex` for merges, CF, DV, protections, filters, banding and
/// objects (02 §6). Rebuild when the underlying rules or the axis order change.
final class RectIndex<T> {
  /// Builds an index over `(rect, value)` entries.
  RectIndex(Iterable<(GridRect, T)> entries)
    : _entries = List.unmodifiable(entries.map((e) => _Item(e.$1, e.$2))) {
    _root = _build([for (var i = 0; i < _entries.length; i++) i]);
  }

  /// An empty index.
  RectIndex.empty() : _entries = const [] {
    _root = null;
  }

  final List<_Item<T>> _entries;
  _Node? _root;

  /// Number of entries.
  int get length => _entries.length;

  /// Whether empty.
  bool get isEmpty => _entries.isEmpty;

  /// All entries in insertion order.
  Iterable<(GridRect, T)> get entries => _entries.map((e) => (e.rect, e.value));

  _Node? _build(List<int> items) {
    if (items.isEmpty) return null;
    // Median of interval midpoints.
    final mids = [for (final i in items) (_entries[i].rect.top + _entries[i].rect.bottom) ~/ 2]
      ..sort();
    final center = mids[mids.length ~/ 2];
    final left = <int>[];
    final right = <int>[];
    final here = <int>[];
    for (final i in items) {
      final r = _entries[i].rect;
      if (r.bottom < center) {
        left.add(i);
      } else if (r.top > center) {
        right.add(i);
      } else {
        here.add(i);
      }
    }
    final byTop = List.of(here)..sort((a, b) => _entries[a].rect.top - _entries[b].rect.top);
    final byBottom = List.of(here)
      ..sort((a, b) => _entries[b].rect.bottom - _entries[a].rect.bottom);
    return _Node(center, byTop, byBottom, _build(left), _build(right));
  }

  /// Values whose rectangle contains (row, col), in insertion order.
  List<T> at(int row, int col) {
    final hits = <int>[];
    var node = _root;
    while (node != null) {
      if (row < node.center) {
        for (final i in node.byTop) {
          if (_entries[i].rect.top > row) break;
          hits.add(i);
        }
        node = node.left;
      } else if (row > node.center) {
        for (final i in node.byBottom) {
          if (_entries[i].rect.bottom < row) break;
          hits.add(i);
        }
        node = node.right;
      } else {
        hits.addAll(node.byTop);
        node = null;
      }
    }
    final out = <int>[];
    for (final i in hits) {
      final r = _entries[i].rect;
      if (col >= r.left && col <= r.right) out.add(i);
    }
    out.sort();
    return [for (final i in out) _entries[i].value];
  }

  /// Values whose rectangle intersects [q], in insertion order (deduplicated).
  List<T> intersecting(GridRect q) {
    final hits = <int>{};
    void visit(_Node? node) {
      if (node == null) return;
      // Intervals at this node contain `center`.
      for (final i in node.byTop) {
        final r = _entries[i].rect;
        if (r.top > q.bottom) break;
        if (r.bottom >= q.top) hits.add(i);
      }
      if (q.top < node.center) visit(node.left);
      if (q.bottom > node.center) visit(node.right);
    }

    visit(_root);
    final out = [
      for (final i in hits)
        if (_entries[i].rect.left <= q.right && _entries[i].rect.right >= q.left) i,
    ]..sort();
    return [for (final i in out) _entries[i].value];
  }

  /// `(rect, value)` pairs intersecting [q].
  List<(GridRect, T)> entriesIntersecting(GridRect q) {
    final values = intersecting(q).toSet();
    return [
      for (final e in _entries)
        if (values.contains(e.value) && e.rect.intersects(q)) (e.rect, e.value),
    ];
  }
}

final class _Item<T> {
  const _Item(this.rect, this.value);
  final GridRect rect;
  final T value;
}

final class _Node {
  _Node(this.center, this.byTop, this.byBottom, this.left, this.right);
  final int center;
  final List<int> byTop;
  final List<int> byBottom;
  final _Node? left;
  final _Node? right;
}
