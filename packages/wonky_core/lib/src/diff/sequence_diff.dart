import 'line_diff.dart' show DiffOp;

/// Shortest edit scripts between two sequences (Myers' O(ND) algorithm).
///
/// The generic core of [LineDiff](line_diff.dart): lines of a script, tokens
/// of a code state (Slides 07 §5.2) or text runs of a Magic Move match
/// (Slides 06 §9.5).
abstract final class SequenceDiff {
  /// The operations turning [a] into [b], in order: [DiffOp.equal] consumes
  /// one element of each, [DiffOp.delete] one of [a], [DiffOp.insert] one of
  /// [b]. The script is minimal (fewest inserts + deletes).
  ///
  /// [equals] compares elements (default `==`).
  static List<DiffOp> diff<T>(
    List<T> a,
    List<T> b, {
    bool Function(T x, T y)? equals,
  }) {
    final eq = equals ?? _defaultEquals;
    // Common prefix and suffix are cheap and keep the search small.
    var start = 0;
    while (start < a.length && start < b.length && eq(a[start], b[start])) {
      start++;
    }
    var endA = a.length, endB = b.length;
    while (endA > start && endB > start && eq(a[endA - 1], b[endB - 1])) {
      endA--;
      endB--;
    }
    return [
      for (var i = 0; i < start; i++) DiffOp.equal,
      ..._myers(a.sublist(start, endA), b.sublist(start, endB), eq),
      for (var i = endA; i < a.length; i++) DiffOp.equal,
    ];
  }

  static bool _defaultEquals(Object? x, Object? y) => x == y;

  /// Myers' greedy algorithm with a trace for backtracking. Returns the
  /// operations in order.
  static List<DiffOp> _myers<T>(
    List<T> a,
    List<T> b,
    bool Function(T x, T y) eq,
  ) {
    final n = a.length, m = b.length;
    if (n == 0) return List.filled(m, DiffOp.insert);
    if (m == 0) return List.filled(n, DiffOp.delete);
    final max = n + m;
    final offset = max;
    var v = List<int>.filled(2 * max + 2, 0);
    final trace = <List<int>>[];
    var found = false;
    for (var d = 0; d <= max && !found; d++) {
      trace.add(List.of(v));
      for (var k = -d; k <= d; k += 2) {
        int x;
        if (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1])) {
          x = v[offset + k + 1];
        } else {
          x = v[offset + k - 1] + 1;
        }
        var y = x - k;
        while (x < n && y < m && eq(a[x], b[y])) {
          x++;
          y++;
        }
        v[offset + k] = x;
        if (x >= n && y >= m) {
          found = true;
          break;
        }
      }
    }
    // Backtrack.
    final ops = <DiffOp>[];
    var x = n, y = m;
    for (var d = trace.length - 1; d >= 0; d--) {
      v = trace[d];
      final k = x - y;
      int prevK;
      if (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1])) {
        prevK = k + 1;
      } else {
        prevK = k - 1;
      }
      final prevX = v[offset + prevK];
      final prevY = prevX - prevK;
      while (x > prevX && y > prevY) {
        ops.add(DiffOp.equal);
        x--;
        y--;
      }
      if (d > 0) {
        if (x == prevX) {
          ops.add(DiffOp.insert);
          y--;
        } else {
          ops.add(DiffOp.delete);
          x--;
        }
      }
    }
    return ops.reversed.toList();
  }
}
