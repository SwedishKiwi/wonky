import 'package:wonky_sync_models/ids.dart' show FractionalIndex;

/// One item of a key space: `(sortKey, id)` (02 §2.3).
typedef KeyedItem = (String key, String id);

/// Fractional key helpers for the key spaces of a deck (02 §2.3): robust
/// against duplicate and malformed keys written by concurrent writers.
abstract final class OrderKeys {
  /// Sorts [items] by `(key, id)`.
  static List<KeyedItem> sorted(Iterable<KeyedItem> items) =>
      items.toList()
        ..sort((a, b) => FractionalIndex.compare(a.$1, a.$2, b.$1, b.$2));

  static String? _valid(String? k) =>
      k == null || k.isEmpty || !FractionalIndex.isValid(k) ? null : k;

  /// [count] ascending keys strictly between [lo] and [hi] (either null =
  /// unbounded). When the bounds are malformed or not ascending (duplicate
  /// keys), the upper bound is dropped.
  static List<String> between(String? lo, String? hi, int count) {
    if (count <= 0) return const [];
    // A malformed bound is treated as unbounded (the order of rows with
    // malformed keys is only defined by the `(key, id)` tie-break).
    final a = _valid(lo);
    var b = _valid(hi);
    if (a != null && b != null && a.compareTo(b) >= 0) b = null;
    return FractionalIndex.nBetween(a, b, count);
  }

  /// [count] keys inserted at position [index] of the sorted key space
  /// [siblings] (0 = first, `siblings.length` = last), skipping the items
  /// whose ids are in [exclude] (rows being moved). Duplicate neighbor keys
  /// are stepped over so the new keys land strictly between distinct keys.
  static List<String> at(
    List<KeyedItem> siblings,
    int index,
    int count, {
    Set<String> exclude = const {},
  }) {
    String? lo;
    for (var i = index - 1; i >= 0; i--) {
      if (exclude.contains(siblings[i].$2)) continue;
      lo = siblings[i].$1;
      break;
    }
    String? hi;
    for (var i = index; i < siblings.length; i++) {
      if (exclude.contains(siblings[i].$2)) continue;
      final k = siblings[i].$1;
      if (lo != null && k.compareTo(lo) <= 0) continue;
      hi = k;
      break;
    }
    return between(lo, hi, count);
  }

  /// The insertion index for "before [beforeId]" / "after [afterId]" in
  /// [siblings] (both null = the end). Returns -1 when the anchor is
  /// missing.
  static int indexFor(
    List<KeyedItem> siblings, {
    String? beforeId,
    String? afterId,
  }) {
    if (afterId != null) {
      final i = siblings.indexWhere((s) => s.$2 == afterId);
      return i < 0 ? -1 : i + 1;
    }
    if (beforeId != null) {
      return siblings.indexWhere((s) => s.$2 == beforeId);
    }
    return siblings.length;
  }

  /// A key after every key of [siblings] (excluding [exclude]).
  static String last(
    List<KeyedItem> siblings, {
    Set<String> exclude = const {},
  }) => at(siblings, siblings.length, 1, exclude: exclude).single;
}
