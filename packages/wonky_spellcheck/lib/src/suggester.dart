part of 'hunspell.dart';

// Edit costs: lower is better. Dictionary-specific replacements (REP, MAP)
// and case fixes come first, then the typo classes by likelihood.
const double _costCase = 0;
const double _costRep = 0.5;
const double _costMap = 0.5;
const double _costSwap = 0.9;
const double _costDoubled = 0.9;
const double _costKey = 1.0;
const double _costDoubleTwo = 1.0;
const double _costExtra = 1.4;
const double _costForgot = 1.4;
const double _costBadChar = 1.5;
const double _costSplit = 1.6;
const double _costMove = 1.8;
const double _costShortSplit = 3.5;
const double _costNgram = 2.0;

const int _ngramTopRoots = 120;
const int _maxMapLeaves = 1500;

/// One suggestion run (state, budget and candidate collection).
final class _Suggester {
  _Suggester(this.c, this.sw, this.limitUs) : d = c.dictionary;

  final SpellChecker c;
  final HunspellDictionary d;
  final Stopwatch sw;
  final int limitUs;

  /// Dictionary-form candidate → best cost.
  final Map<String, double> _cands = {};
  final Map<String, bool> _validMemo = {};
  bool _allowCompound = false;
  int _inputCapClass = 0;
  int _ticks = 0;
  bool _timeUp = false;

  bool get timeUp {
    if (_timeUp) return true;
    return _timeUp = sw.elapsedMicroseconds >= limitUs;
  }

  /// [timeUp], read from the stopwatch only every 16 calls.
  bool get _tick {
    if (_timeUp) return true;
    if ((++_ticks & 15) != 0) return false;
    return timeUp;
  }

  bool _valid(String cand) {
    if (cand.isEmpty) return false;
    final memo = _validMemo[cand];
    if (memo != null) return memo;
    final ok = c._check(cand, forSuggest: true, compound: _allowCompound);
    _validMemo[cand] = ok;
    return ok;
  }

  bool _validPhrase(String cand) {
    if (!cand.contains(' ')) return _valid(cand);
    final parts = cand.split(' ');
    return parts.every((p) => p.isNotEmpty && _valid(p));
  }

  void _add(String cand, double rawCost) {
    // Compound fragments (`huis-`, `-achtig`) are not useful suggestions.
    if (cand.startsWith('-') || cand.endsWith('-')) return;
    // Prefer candidates whose capitalization matches the input's.
    final cost = rawCost + (_capClass(cand) != _inputCapClass ? 0.3 : 0);
    final prev = _cands[cand];
    if (prev == null || cost < prev) _cands[cand] = cost;
  }

  void _try(String cand, double cost) {
    if (_tick) return;
    if (_validPhrase(cand)) _add(cand, cost);
  }

  List<String> run(String input, int max) {
    if (timeUp) return const [];
    var w = d._normalize(input.trim());
    var dots = '';
    while (w.length > 1 && w.endsWith('.')) {
      w = w.substring(0, w.length - 1);
      dots += '.';
    }
    if (w.isEmpty) return const [];

    final hyphenated = _hyphenated(input, w, dots, max);
    if (hyphenated != null) return hyphenated;

    final cap = _capType(w);
    _inputCapClass = _capClass(w);
    final lower = w.toLowerCase();
    final variants = switch (cap) {
      _Cap.lower => [w],
      _Cap.init || _Cap.huh || _Cap.huhInit => [w, lower],
      _Cap.all => [lower, _initCap(w)],
    };

    // Case fixes (nasa → NASA, paris → Paris, hELLO → Hello).
    final inputOk = c.check(w);
    if (!inputOk) {
      _try(lower, _costCase);
      _try(_initCap(w), _costCase);
      _try(w.toUpperCase(), _costCase + 0.1);
    }
    for (final v in variants) {
      if (timeUp) break;
      _edits(v);
    }
    if (_cands.isEmpty &&
        d.hasCompounding &&
        d._maxCompoundSugs != 0 &&
        !timeUp) {
      // Second pass allowing compound words, as Hunspell does.
      _allowCompound = true;
      _validMemo.clear();
      for (final v in variants) {
        if (timeUp) break;
        _edits(v, cheapOnly: true);
      }
      if (_cands.length > d._maxCompoundSugs) {
        final keep = _ranked(lower).take(d._maxCompoundSugs).toSet();
        _cands.removeWhere((k, _) => !keep.contains(k));
      }
      _allowCompound = false;
      _validMemo.clear();
    }
    if (_cands.length < max && d._maxNgramSugs != 0 && !timeUp) {
      _ngram(lower);
    }

    final out = <String>{};
    for (final cand in _ranked(lower)) {
      var s = _restoreCase(cand, cap) + dots;
      s = d._oconv.apply(s);
      if (s == input || s == w + dots) continue;
      if (inputOk && s.toLowerCase() == (w + dots).toLowerCase()) continue;
      if (out.add(s) && out.length >= max) break;
    }
    return out.toList(growable: false);
  }

  /// `well-knwon` → suggestions for the one misspelled part.
  List<String>? _hyphenated(String input, String w, String dots, int max) {
    if (!d._breaks.contains('-') || !w.contains('-')) return null;
    final parts = w.split('-');
    if (parts.length < 2 || parts.any((p) => p.isEmpty)) return null;
    final wrong = [
      for (var i = 0; i < parts.length; i++)
        if (!c.check(parts[i])) i,
    ];
    if (wrong.length != 1) return null;
    final i = wrong.single;
    final fixes = c.suggest(
      parts[i],
      max: max,
      budget: Duration(microseconds: limitUs),
      stopwatch: sw,
    );
    return [
      for (final f in fixes)
        [...parts.sublist(0, i), f, ...parts.sublist(i + 1)].join('-') + dots,
    ].where((s) => s != input).take(max).toList(growable: false);
  }

  String _restoreCase(String cand, _Cap cap) {
    String out;
    switch (cap) {
      case _Cap.init || _Cap.huhInit:
        out = _upperFirst(cand);
      case _Cap.all:
        out = cand.toUpperCase();
      case _Cap.lower || _Cap.huh:
        return cand;
    }
    if (out == cand) return cand;
    if (cand.contains(' ')) return out;
    return c._check(out, forSuggest: true, compound: true) ? out : cand;
  }

  List<String> _ranked(String lower) {
    final entries = _cands.entries.toList();
    final sim = <String, int>{
      for (final e in entries) e.key: _similarity(lower, e.key.toLowerCase()),
    };
    entries.sort((a, b) {
      final byCost = a.value.compareTo(b.value);
      if (byCost != 0) return byCost;
      final bySim = sim[b.key]!.compareTo(sim[a.key]!);
      if (bySim != 0) return bySim;
      return a.key.compareTo(b.key);
    });
    return [for (final e in entries) e.key];
  }

  // ---------------------------------------------------------- edits

  void _edits(String v, {bool cheapOnly = false}) {
    _rep(v);
    _map(v);
    _swap(v);
    _keyChars(v);
    _doubleTwo(v);
    _extra(v);
    _forgot(v);
    if (cheapOnly) return;
    _badChar(v);
    _split(v);
    _longSwapAndMove(v);
  }

  void _rep(String v) {
    for (final rep in d._reps) {
      if (_tick) return;
      final from = rep.from;
      if (from.isEmpty) continue;
      if (rep.atStart || rep.atEnd) {
        if (rep.atStart && rep.atEnd) {
          if (v == from) _try(rep.to, _costRep);
        } else if (rep.atStart) {
          if (v.startsWith(from)) {
            _try(rep.to + v.substring(from.length), _costRep);
          }
        } else if (v.endsWith(from)) {
          _try(v.substring(0, v.length - from.length) + rep.to, _costRep);
        }
        continue;
      }
      var i = v.indexOf(from);
      while (i >= 0) {
        _try(
          v.substring(0, i) + rep.to + v.substring(i + from.length),
          _costRep,
        );
        i = v.indexOf(from, i + 1);
      }
    }
  }

  void _map(String v) {
    if (d._maps.isEmpty) return;
    var leaves = 0;
    void rec(int pos, String built, int changes) {
      if (leaves > _maxMapLeaves || _tick) return;
      if (pos >= v.length) {
        leaves++;
        if (changes > 0) _try(built, _costMap);
        return;
      }
      if (changes < 2) {
        for (final group in d._maps) {
          for (final m in group) {
            if (!v.startsWith(m, pos)) continue;
            for (final other in group) {
              if (other != m) rec(pos + m.length, built + other, changes + 1);
            }
          }
        }
      }
      rec(pos + 1, built + v[pos], changes);
    }

    rec(0, '', 0);
  }

  void _swap(String v) {
    for (var i = 0; i + 1 < v.length; i++) {
      final a = v[i];
      final b = v[i + 1];
      if (a == b) continue;
      _try(v.substring(0, i) + b + a + v.substring(i + 2), _costSwap);
    }
  }

  void _keyChars(String v) {
    final neighbours = d._neighbours;
    for (var i = 0; i < v.length; i++) {
      final ch = v[i];
      final up = ch.toUpperCase();
      final head = v.substring(0, i);
      final tail = v.substring(i + 1);
      if (up != ch && up.length == 1) _try(head + up + tail, _costKey);
      final n = neighbours[v.codeUnitAt(i)];
      if (n == null) continue;
      for (var k = 0; k < n.length; k++) {
        _try(head + n[k] + tail, _costKey);
      }
    }
  }

  void _doubleTwo(String v) {
    for (var i = 0; i + 3 < v.length; i++) {
      if (v.codeUnitAt(i) == v.codeUnitAt(i + 2) &&
          v.codeUnitAt(i + 1) == v.codeUnitAt(i + 3)) {
        _try(v.substring(0, i + 2) + v.substring(i + 4), _costDoubleTwo);
      }
    }
  }

  void _extra(String v) {
    if (v.length < 2) return;
    for (var i = 0; i < v.length; i++) {
      final c = v.codeUnitAt(i);
      final doubled =
          (i > 0 && v.codeUnitAt(i - 1) == c) ||
          (i + 1 < v.length && v.codeUnitAt(i + 1) == c);
      _try(
        v.substring(0, i) + v.substring(i + 1),
        doubled ? _costDoubled : _costExtra,
      );
    }
  }

  void _forgot(String v) {
    final tryChars = d._tryForSuggest;
    for (var i = 0; i <= v.length; i++) {
      final head = v.substring(0, i);
      final tail = v.substring(i);
      for (var k = 0; k < tryChars.length; k++) {
        final c = tryChars.codeUnitAt(k);
        final doubled =
            (i > 0 && v.codeUnitAt(i - 1) == c) ||
            (i < v.length && v.codeUnitAt(i) == c);
        _try(head + tryChars[k] + tail, doubled ? _costDoubled : _costForgot);
        if (_timeUp) return;
      }
    }
  }

  void _badChar(String v) {
    final tryChars = d._tryForSuggest;
    for (var i = 0; i < v.length; i++) {
      final head = v.substring(0, i);
      final tail = v.substring(i + 1);
      final cur = v.codeUnitAt(i);
      for (var k = 0; k < tryChars.length; k++) {
        if (tryChars.codeUnitAt(k) == cur) continue;
        _try(head + tryChars[k] + tail, _costBadChar);
        if (_timeUp) return;
      }
    }
  }

  void _split(String v) {
    if (d._noSplitSugs || v.length < 3) return;
    for (var i = 1; i < v.length; i++) {
      if (_tick) return;
      final left = v.substring(0, i);
      final right = v.substring(i);
      if (_valid(left) && _valid(right)) {
        final short = left.length < 3 || right.length < 3;
        _add('$left $right', short ? _costShortSplit : _costSplit);
      }
    }
  }

  void _longSwapAndMove(String v) {
    final n = v.length;
    for (var i = 0; i < n; i++) {
      for (var j = i + 2; j < n && j <= i + 4; j++) {
        if (_tick) return;
        if (v[i] != v[j]) {
          _try(
            v.substring(0, i) +
                v[j] +
                v.substring(i + 1, j) +
                v[i] +
                v.substring(j + 1),
            _costMove,
          );
        }
        // Move v[i] behind v[j], and v[j] in front of v[i].
        _try(
          v.substring(0, i) +
              v.substring(i + 1, j + 1) +
              v[i] +
              v.substring(j + 1),
          _costMove,
        );
        _try(
          v.substring(0, i) + v[j] + v.substring(i, j) + v.substring(j + 1),
          _costMove,
        );
      }
    }
  }

  // ---------------------------------------------------------- n-grams

  void _ngram(String lower) {
    final n = lower.length;
    if (n < 3) return;
    final bigrams = <int>{};
    for (var i = 0; i + 1 < n; i++) {
      bigrams.add(lower.codeUnitAt(i) * 65536 + lower.codeUnitAt(i + 1));
    }
    final threshold = math.max(1, (bigrams.length + 1) ~/ 3);
    final top = <(int, String)>[];
    var minTop = 0;

    void consider(String root) {
      final rl = root.length;
      final diff = (rl - n).abs();
      if (diff > 4 || rl < 2) return;
      var score = 0;
      var prev = _fold(root.codeUnitAt(0));
      for (var i = 1; i < rl; i++) {
        final cur = _fold(root.codeUnitAt(i));
        if (bigrams.contains(prev * 65536 + cur)) score++;
        prev = cur;
      }
      if (_fold(root.codeUnitAt(0)) == lower.codeUnitAt(0)) score++;
      score = score * 2 - diff;
      if (score < threshold * 2) return;
      if (top.length >= _ngramTopRoots && score <= minTop) return;
      top.add((score, root));
      if (top.length > _ngramTopRoots * 2) {
        _sortTop(top);
        top.length = _ngramTopRoots;
        minTop = top.last.$1;
      }
    }

    final roots = d._roots;
    for (var i = 0; i < roots.length; i++) {
      if ((i & 255) == 0 && timeUp) break;
      consider(roots[i]);
    }
    for (final p in c._personal) {
      consider(p);
    }
    _sortTop(top);
    if (top.length > _ngramTopRoots) top.length = _ngramTopRoots;

    // Expand the best roots with their affixes and score the forms.
    final scored = <(int, int, String)>[];
    final seen = <String>{};
    final maxDist = n <= 4 ? 1 : (n <= 8 ? 2 : 3);
    void rate(String form) {
      if ((form.length - n).abs() > 2 || !seen.add(form)) return;
      final fl = form.toLowerCase();
      if (fl == lower) return;
      final dist = _distance(lower, fl);
      if (dist > maxDist) return;
      if (!_valid(form)) return;
      scored.add((dist, _similarity(lower, fl), form));
    }

    for (final (_, root) in top) {
      if (timeUp) break;
      rate(root);
      for (final flags in c._homonyms(root)) {
        for (final f in flags.ids) {
          for (final a in d._suffixesByFlag[f] ?? const <_Affix>[]) {
            final form = a.applyTo(root);
            if (form != null) rate(form);
          }
          for (final a in d._prefixesByFlag[f] ?? const <_Affix>[]) {
            final form = a.applyTo(root);
            if (form != null) rate(form);
          }
        }
      }
    }
    scored.sort((a, b) {
      if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
      if (a.$2 != b.$2) return b.$2.compareTo(a.$2);
      return a.$3.compareTo(b.$3);
    });
    var added = 0;
    for (final (dist, _, form) in scored) {
      if (added >= d._maxNgramSugs) break;
      if (_cands.containsKey(form)) continue;
      _add(form, _costNgram + dist);
      added++;
    }
  }

  static void _sortTop(List<(int, String)> top) {
    top.sort((a, b) {
      if (a.$1 != b.$1) return b.$1.compareTo(a.$1);
      return a.$2.compareTo(b.$2);
    });
  }
}

/// 0: no uppercase, 1: uppercase first letter only, 2: other.
int _capClass(String w) => switch (_capType(w)) {
  _Cap.lower => 0,
  _Cap.init => 1,
  _ => 2,
};

int _fold(int c) => c >= 0x41 && c <= 0x5A ? c + 32 : c;

/// Hunspell-style n-gram similarity (substrings of length 1–3 shared, in
/// both directions), minus the length difference.
int _similarity(String a, String b) {
  int grams(String x, String y) {
    var score = 0;
    for (var len = 1; len <= 3; len++) {
      var hits = 0;
      for (var i = 0; i + len <= x.length; i++) {
        if (y.contains(x.substring(i, i + len))) hits++;
      }
      score += hits;
      if (hits < 2) break;
    }
    return score;
  }

  var prefix = 0;
  while (prefix < a.length &&
      prefix < b.length &&
      a.codeUnitAt(prefix) == b.codeUnitAt(prefix)) {
    prefix++;
  }
  return grams(a, b) + grams(b, a) + prefix - 2 * (a.length - b.length).abs();
}

/// Optimal-string-alignment distance (Damerau–Levenshtein without
/// repeated edits of a substring).
int _distance(String a, String b) {
  final n = a.length;
  final m = b.length;
  if (n == 0) return m;
  if (m == 0) return n;
  var prev2 = List<int>.filled(m + 1, 0);
  var prev = List<int>.generate(m + 1, (j) => j);
  var cur = List<int>.filled(m + 1, 0);
  for (var i = 1; i <= n; i++) {
    cur[0] = i;
    for (var j = 1; j <= m; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var v = math.min(
        math.min(prev[j] + 1, cur[j - 1] + 1),
        prev[j - 1] + cost,
      );
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        v = math.min(v, prev2[j - 2] + 1);
      }
      cur[j] = v;
    }
    final t = prev2;
    prev2 = prev;
    prev = cur;
    cur = t;
  }
  return prev[m];
}
