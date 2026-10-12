/// Result of a successful fuzzy match.
class FuzzyMatch {
  const FuzzyMatch(this.score, this.indices);

  /// Higher is better.
  final double score;

  /// Indices in the candidate that matched the query characters.
  final List<int> indices;

  @override
  String toString() => 'FuzzyMatch($score, $indices)';
}

/// Subsequence fuzzy matching used by the command palette and the quick
/// switcher (suite 08 §1.3).
///
/// Every query character must appear in order in the candidate (case
/// insensitive; whitespace in the query is ignored). Matches score higher
/// when they are consecutive, start a word (after space, `.`, `›`, `-`, `_`,
/// `/` or a lower→upper camel-case boundary), or start the candidate. Exact
/// prefix and exact substring matches get large bonuses.
abstract final class Fuzzy {
  /// Scores [candidate] against [query]; null when it does not match.
  static FuzzyMatch? match(String query, String candidate) {
    final q = query.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (q.isEmpty) return const FuzzyMatch(0, []);
    final c = candidate.toLowerCase();
    if (q.length > c.length) return null;

    // Greedy-with-lookahead: prefer word-start positions for each char.
    final indices = <int>[];
    var ci = 0;
    for (var qi = 0; qi < q.length; qi++) {
      final ch = q[qi];
      int? found;
      int? firstAny;
      for (var j = ci; j < c.length; j++) {
        if (c[j] != ch) continue;
        firstAny ??= j;
        final consecutive = indices.isNotEmpty && indices.last == j - 1;
        if (consecutive || _isWordStart(candidate, j)) {
          found = j;
          break;
        }
      }
      found ??= firstAny;
      if (found == null) return null;
      // Make sure the rest still fits after `found`; otherwise fall back to
      // the earliest occurrence.
      if (!_restFits(q, qi + 1, c, found + 1) && firstAny != null) {
        found = firstAny;
      }
      indices.add(found);
      ci = found + 1;
    }

    var score = 0.0;
    for (var i = 0; i < indices.length; i++) {
      final idx = indices[i];
      score += 1;
      if (i > 0 && indices[i - 1] == idx - 1) score += 2.5;
      if (_isWordStart(candidate, idx)) score += 3;
      if (idx == 0) score += 2;
    }
    // Penalize spread and length.
    score -= (indices.last - indices.first + 1 - indices.length) * 0.15;
    score -= c.length * 0.01;
    final plain = query.toLowerCase().trim();
    if (c.startsWith(plain)) {
      score += 10;
    } else if (c.contains(plain)) {
      score += 5;
    }
    return FuzzyMatch(score, indices);
  }

  /// Best match of [query] against several fields of one item (title,
  /// aliases, menu path…). Fields after the first are weighted by [secondaryWeight].
  static FuzzyMatch? bestOf(
    String query,
    List<String> fields, {
    double secondaryWeight = 0.8,
  }) {
    FuzzyMatch? best;
    double? bestScore;
    for (var i = 0; i < fields.length; i++) {
      final m = match(query, fields[i]);
      if (m == null) continue;
      final s = i == 0 ? m.score : m.score * secondaryWeight;
      if (bestScore == null || s > bestScore) {
        bestScore = s;
        best = i == 0 ? m : FuzzyMatch(s, const []);
      }
    }
    return best;
  }

  /// Filters and sorts [items] by match quality (stable for ties).
  static List<T> rank<T>(
    String query,
    Iterable<T> items,
    List<String> Function(T item) fieldsOf,
  ) {
    if (query.trim().isEmpty) return items.toList();
    final scored = <(T, double, int)>[];
    var i = 0;
    for (final item in items) {
      final m = bestOf(query, fieldsOf(item));
      if (m != null) scored.add((item, m.score, i));
      i++;
    }
    scored.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : a.$3.compareTo(b.$3);
    });
    return [for (final s in scored) s.$1];
  }

  static bool _restFits(String q, int qi, String c, int ci) {
    var j = ci;
    for (var i = qi; i < q.length; i++) {
      j = c.indexOf(q[i], j);
      if (j < 0) return false;
      j++;
    }
    return true;
  }

  static bool _isWordStart(String s, int i) {
    if (i == 0) return true;
    final prev = s[i - 1];
    if (' .›-_/:()'.contains(prev)) return true;
    final cur = s[i];
    return prev.toLowerCase() == prev &&
        prev.toUpperCase() != prev &&
        cur.toUpperCase() == cur &&
        cur.toLowerCase() != cur;
  }
}
