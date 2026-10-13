part of 'hunspell.dart';

/// Sorted, de-duplicated set of interned flag ids (see [_Flags.id]).
///
/// Id 0 means "flag not set" and is never contained.
final class _FlagSet {
  _FlagSet(this.ids);

  static final _FlagSet empty = _FlagSet(Uint16List(0));

  final Uint16List ids;

  bool get isEmpty => ids.isEmpty;

  bool contains(int id) {
    if (id == 0) return false;
    final a = ids;
    final n = a.length;
    if (n <= 8) {
      for (var i = 0; i < n; i++) {
        final v = a[i];
        if (v >= id) return v == id;
      }
      return false;
    }
    var lo = 0;
    var hi = n - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final v = a[mid];
      if (v == id) return true;
      if (v < id) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return false;
  }

  bool containsAny(Set<int> other) {
    for (final v in ids) {
      if (other.contains(v)) return true;
    }
    return false;
  }
}

enum _FlagMode { single, long, number, utf8 }

/// Flag syntax (`FLAG`), interning of flag names to small integer ids,
/// flag-set caching and `AF` aliases.
final class _Flags {
  _FlagMode mode = _FlagMode.single;

  final Map<String, int> _ids = {};
  final Map<String, _FlagSet> _cache = {};

  /// `AF` aliases (1-based in the files), or null when not used.
  List<_FlagSet>? aliases;

  int id(String name) {
    final existing = _ids[name];
    if (existing != null) return existing;
    final next = _ids.length + 1;
    if (next > 0xFFFF) {
      throw const FormatException('Too many distinct affix flags');
    }
    _ids[name] = next;
    return next;
  }

  /// Splits a flag string into flag names according to [mode].
  List<String> names(String s) {
    switch (mode) {
      case _FlagMode.single:
        return [for (var i = 0; i < s.length; i++) s[i]];
      case _FlagMode.long:
        return [
          for (var i = 0; i < s.length; i += 2)
            s.substring(i, math.min(i + 2, s.length)),
        ];
      case _FlagMode.number:
        return [
          for (final p in s.split(','))
            if (p.trim().isNotEmpty) p.trim(),
        ];
      case _FlagMode.utf8:
        return [for (final r in s.runes) String.fromCharCode(r)];
    }
  }

  /// The id of the first flag in [s] (0 when empty), for directives such
  /// as `NEEDAFFIX`.
  int one(String s) {
    final n = names(s);
    return n.isEmpty ? 0 : id(n.first);
  }

  /// Parses [s] as literal flags (no alias interpretation).
  _FlagSet raw(String s) {
    final n = names(s);
    if (n.isEmpty) return _FlagSet.empty;
    final ids = Uint16List(n.length);
    for (var i = 0; i < n.length; i++) {
      ids[i] = id(n[i]);
    }
    ids.sort();
    var w = 0;
    for (var i = 0; i < ids.length; i++) {
      if (i == 0 || ids[i] != ids[i - 1]) ids[w++] = ids[i];
    }
    return _FlagSet(w == ids.length ? ids : Uint16List.fromList(ids.sublist(0, w)));
  }

  /// Parses a flag field of a `.dic` entry or an affix continuation class,
  /// resolving `AF` aliases. Results are interned per raw string.
  _FlagSet set(String s) {
    if (s.isEmpty) return _FlagSet.empty;
    final cached = _cache[s];
    if (cached != null) return cached;
    final al = aliases;
    _FlagSet result;
    if (al != null && _isDigits(s)) {
      final i = int.parse(s);
      result = i >= 1 && i <= al.length ? al[i - 1] : _FlagSet.empty;
    } else {
      result = raw(s);
    }
    _cache[s] = result;
    return result;
  }

  /// Parses a `COMPOUNDRULE` pattern (`n*1t`, `(N1)(n2)?`, …).
  _CompoundRule? rule(String s) {
    final flags = <int>[];
    final quants = <int>[];
    var i = 0;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '*' || ch == '?') {
        if (quants.isNotEmpty) quants[quants.length - 1] = ch == '*' ? 2 : 1;
        i++;
        continue;
      }
      String name;
      if (ch == '(') {
        final close = s.indexOf(')', i + 1);
        if (close < 0) break;
        name = s.substring(i + 1, close);
        i = close + 1;
      } else if (mode == _FlagMode.long) {
        name = s.substring(i, math.min(i + 2, s.length));
        i += 2;
      } else if (mode == _FlagMode.utf8 &&
          _isHighSurrogate(s.codeUnitAt(i)) &&
          i + 1 < s.length) {
        name = s.substring(i, i + 2);
        i += 2;
      } else {
        name = ch;
        i++;
      }
      flags.add(id(name));
      quants.add(0);
    }
    if (flags.isEmpty) return null;
    return _CompoundRule(flags, quants);
  }
}

/// A `COMPOUNDRULE`: a sequence of flags with `?`/`*` quantifiers.
final class _CompoundRule {
  _CompoundRule(this.flags, this.quants);

  final List<int> flags;

  /// 0: exactly one, 1: `?`, 2: `*`.
  final List<int> quants;

  bool matches(List<_FlagSet> parts, {required bool partial}) =>
      _match(0, 0, parts, partial);

  bool _match(int ri, int pi, List<_FlagSet> parts, bool partial) {
    if (pi == parts.length) {
      if (partial) return true;
      for (var i = ri; i < flags.length; i++) {
        if (quants[i] == 0) return false;
      }
      return true;
    }
    if (ri == flags.length) return false;
    final has = parts[pi].contains(flags[ri]);
    switch (quants[ri]) {
      case 0:
        return has && _match(ri + 1, pi + 1, parts, partial);
      case 1:
        return (has && _match(ri + 1, pi + 1, parts, partial)) ||
            _match(ri + 1, pi, parts, partial);
      default:
        return (has && _match(ri, pi + 1, parts, partial)) ||
            _match(ri + 1, pi, parts, partial);
    }
  }
}

bool _isDigits(String s) {
  if (s.isEmpty) return false;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) return false;
  }
  return true;
}

bool _isHighSurrogate(int c) => c >= 0xD800 && c <= 0xDBFF;
