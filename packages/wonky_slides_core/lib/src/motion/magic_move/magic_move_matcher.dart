/// Magic Move matching (06 §8.3, normative): pairs the elements of the
/// outgoing slide's final frame with those of the incoming slide's initial
/// frame — pass 1 by match key, pass 2 by content signature, pass 3 by
/// kind + name — and element groups recursively by the same passes.
library;

import 'dart:math' as math;

import '../builds/transition_spec.dart' show MagicMoveOptions;
import 'magic_move_slide.dart';

/// How a pair was matched.
enum MatchPass {
  /// Equal `matchKey` (pass 1).
  key,

  /// Same kind and content signature (pass 2).
  content,

  /// Same kind and non-empty name (pass 3).
  name,
}

/// A matched pair; groups carry the matches of their children.
final class MagicMoveMatch {
  /// Creates a match.
  const MagicMoveMatch(
    this.from,
    this.to,
    this.pass, {
    this.children = const MagicMoveMatches(),
  });

  /// The element on the outgoing slide.
  final MagicMoveElement from;

  /// The element on the incoming slide.
  final MagicMoveElement to;
  final MatchPass pass;

  /// Matches among the children of two matched groups.
  final MagicMoveMatches children;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'from': from.id,
    'to': to.id,
    'pass': pass.name,
    if (!children.isEmpty) 'children': children.toJson(),
  };
}

/// The result of matching two element lists.
final class MagicMoveMatches {
  /// Creates the result.
  const MagicMoveMatches({
    this.pairs = const [],
    this.outgoing = const [],
    this.incoming = const [],
  });

  /// Matched pairs in the incoming slide's order (back to front).
  final List<MagicMoveMatch> pairs;

  /// Unmatched elements of the outgoing slide (fade out), in its order.
  final List<MagicMoveElement> outgoing;

  /// Unmatched elements of the incoming slide (fade in), in its order.
  final List<MagicMoveElement> incoming;

  /// Whether nothing is listed.
  bool get isEmpty => pairs.isEmpty && outgoing.isEmpty && incoming.isEmpty;

  /// Matched pairs including those of group children (depth first).
  Iterable<MagicMoveMatch> get allPairs sync* {
    for (final p in pairs) {
      yield p;
      yield* p.children.allPairs;
    }
  }

  /// The match of incoming element [toId] (any depth), or null.
  MagicMoveMatch? pairOf(String toId) {
    for (final p in allPairs) {
      if (p.to.id == toId) return p;
    }
    return null;
  }

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'pairs': [for (final p in pairs) p.toJson()],
    'outgoing': [for (final e in outgoing) e.id],
    'incoming': [for (final e in incoming) e.id],
  };
}

/// The Magic Move matcher (06 §8.3).
abstract final class MagicMoveMatcher {
  /// Matches [from] (the outgoing slide's top-level elements, back to
  /// front) with [to] (the incoming slide's): deterministic for equal
  /// inputs.
  static MagicMoveMatches match(
    List<MagicMoveElement> from,
    List<MagicMoveElement> to, {
    MagicMoveOptions options = const MagicMoveOptions(),
  }) {
    final usedA = <int>{}, usedB = <int>{};
    final found = <int, (int, MatchPass)>{}; // b index → (a index, pass)

    // Pass 1 — keys (duplicates pair by z-order rank).
    final byKeyA = <String, List<int>>{}, byKeyB = <String, List<int>>{};
    for (var i = 0; i < from.length; i++) {
      final k = from[i].matchKey;
      if (k.isNotEmpty) (byKeyA[k] ??= []).add(i);
    }
    for (var j = 0; j < to.length; j++) {
      final k = to[j].matchKey;
      if (k.isNotEmpty) (byKeyB[k] ??= []).add(j);
    }
    for (final k in byKeyB.keys) {
      final as = byKeyA[k];
      if (as == null) continue;
      final bs = byKeyB[k]!;
      int byZ(List<MagicMoveElement> l, int x, int y) {
        final c = l[x].z.compareTo(l[y].z);
        return c != 0 ? c : x.compareTo(y);
      }

      final sa = [...as]..sort((x, y) => byZ(from, x, y));
      final sb = [...bs]..sort((x, y) => byZ(to, x, y));
      for (var n = 0; n < math.min(sa.length, sb.length); n++) {
        found[sb[n]] = (sa[n], MatchPass.key);
        usedA.add(sa[n]);
        usedB.add(sb[n]);
      }
    }

    // Pass 2 — content signatures (ties: nearest center distance).
    if (options.matchByContent) {
      _greedy(from, to, usedA, usedB, found, MatchPass.content, (e) {
        final s = e.signature;
        return s == null || s.isEmpty ? null : '${e.kind.name}\u0000$s';
      });
    }

    // Pass 3 — kind + name.
    _greedy(from, to, usedA, usedB, found, MatchPass.name, (e) {
      final n = e.name?.trim();
      return n == null || n.isEmpty ? null : '${e.kind.name}\u0000$n';
    });

    final pairs = <MagicMoveMatch>[];
    for (var j = 0; j < to.length; j++) {
      final f = found[j];
      if (f == null) continue;
      final a = from[f.$1], b = to[j];
      pairs.add(
        MagicMoveMatch(
          a,
          b,
          f.$2,
          children: a.children.isEmpty && b.children.isEmpty
              ? const MagicMoveMatches()
              : match(a.children, b.children, options: options),
        ),
      );
    }
    return MagicMoveMatches(
      pairs: pairs,
      outgoing: [
        for (var i = 0; i < from.length; i++)
          if (!usedA.contains(i)) from[i],
      ],
      incoming: [
        for (var j = 0; j < to.length; j++)
          if (!usedB.contains(j)) to[j],
      ],
    );
  }

  /// Pairs still-unmatched elements with equal [keyOf] values, nearest
  /// centers first (ties: outgoing order, then incoming order).
  static void _greedy(
    List<MagicMoveElement> from,
    List<MagicMoveElement> to,
    Set<int> usedA,
    Set<int> usedB,
    Map<int, (int, MatchPass)> found,
    MatchPass pass,
    String? Function(MagicMoveElement) keyOf,
  ) {
    final groupsA = <String, List<int>>{};
    for (var i = 0; i < from.length; i++) {
      if (usedA.contains(i)) continue;
      final k = keyOf(from[i]);
      if (k != null) (groupsA[k] ??= []).add(i);
    }
    if (groupsA.isEmpty) return;
    final candidates = <(double, int, int)>[];
    for (var j = 0; j < to.length; j++) {
      if (usedB.contains(j)) continue;
      final k = keyOf(to[j]);
      final as = k == null ? null : groupsA[k];
      if (as == null) continue;
      final gb = to[j].geometry;
      for (final i in as) {
        final ga = from[i].geometry;
        final dx = ga.cx - gb.cx, dy = ga.cy - gb.cy;
        candidates.add((dx * dx + dy * dy, i, j));
      }
    }
    candidates.sort((x, y) {
      final c = x.$1.compareTo(y.$1);
      if (c != 0) return c;
      final ci = x.$2.compareTo(y.$2);
      return ci != 0 ? ci : x.$3.compareTo(y.$3);
    });
    for (final (_, i, j) in candidates) {
      if (usedA.contains(i) || usedB.contains(j)) continue;
      usedA.add(i);
      usedB.add(j);
      found[j] = (i, pass);
    }
  }
}
