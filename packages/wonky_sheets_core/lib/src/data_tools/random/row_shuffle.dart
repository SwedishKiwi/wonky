import 'dart:math';
import 'dart:typed_data';

/// Randomize range (07 §14): a Fisher–Yates permutation of the range's rows.
abstract final class RowShuffle {
  /// A uniformly random permutation of `0..n-1` (`result[i]` = source row
  /// offset placed at position `i`). Production passes `Random.secure()`;
  /// tests a seeded [Random].
  static Int32List permutation(int n, Random random) {
    final p = Int32List(n);
    for (var i = 0; i < n; i++) {
      p[i] = i;
    }
    for (var i = n - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final t = p[i];
      p[i] = p[j];
      p[j] = t;
    }
    return p;
  }
}
