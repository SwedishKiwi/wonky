part of 'hunspell.dart';

/// An affix condition (`[^aeiou]y`, `.`, `ance`, …) compiled to a list of
/// per-character tests.
final class _Condition {
  _Condition._(this._parts, this._negated);

  static final _Condition none = _Condition._(const [], const []);

  /// Allowed (or, when negated, forbidden) code units per position;
  /// null matches any character.
  final List<Uint16List?> _parts;
  final List<bool> _negated;

  factory _Condition.parse(String s) {
    if (s.isEmpty || s == '.') return none;
    final parts = <Uint16List?>[];
    final negated = <bool>[];
    var i = 0;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x5B /* [ */) {
        var close = s.indexOf(']', i + 1);
        if (close < 0) close = s.length;
        var content = s.substring(i + 1, close);
        final neg = content.startsWith('^');
        if (neg) content = content.substring(1);
        parts.add(Uint16List.fromList(content.codeUnits));
        negated.add(neg);
        i = close + 1;
      } else if (c == 0x2E /* . */) {
        parts.add(null);
        negated.add(false);
        i++;
      } else {
        parts.add(Uint16List.fromList([c]));
        negated.add(false);
        i++;
      }
    }
    if (parts.every((p) => p == null)) {
      return parts.isEmpty ? none : _Condition._(parts, negated);
    }
    return _Condition._(parts, negated);
  }

  bool _ok(int i, int c) {
    final p = _parts[i];
    if (p == null) return true;
    var found = false;
    for (var k = 0; k < p.length; k++) {
      if (p[k] == c) {
        found = true;
        break;
      }
    }
    return found != _negated[i];
  }

  /// Whether the condition matches the end of [w] (suffixes).
  bool matchesEnd(String w) {
    final n = _parts.length;
    if (n == 0) return true;
    final off = w.length - n;
    if (off < 0) return false;
    for (var i = 0; i < n; i++) {
      if (!_ok(i, w.codeUnitAt(off + i))) return false;
    }
    return true;
  }

  /// Whether the condition matches the start of [w] (prefixes).
  bool matchesStart(String w) {
    final n = _parts.length;
    if (n == 0) return true;
    if (w.length < n) return false;
    for (var i = 0; i < n; i++) {
      if (!_ok(i, w.codeUnitAt(i))) return false;
    }
    return true;
  }
}

/// One `PFX`/`SFX` rule line.
final class _Affix {
  _Affix({
    required this.isPrefix,
    required this.flag,
    required this.cross,
    required this.strip,
    required this.append,
    required this.cont,
    required this.cond,
  });

  final bool isPrefix;
  final int flag;
  final bool cross;
  final String strip;
  final String append;

  /// Continuation class (flags of the affixed form).
  final _FlagSet cont;
  final _Condition cond;

  /// Applies this affix to [root] (for n-gram expansion), or null when the
  /// condition or strip does not fit.
  String? applyTo(String root) {
    if (isPrefix) {
      if (!cond.matchesStart(root) || !root.startsWith(strip)) return null;
      final rest = root.substring(strip.length);
      if (rest.isEmpty && append.isEmpty) return null;
      return append + rest;
    }
    if (!cond.matchesEnd(root) || !root.endsWith(strip)) return null;
    final rest = root.substring(0, root.length - strip.length);
    if (rest.isEmpty && append.isEmpty) return null;
    return rest + append;
  }
}

/// A `REP` replacement (`^`/`$` anchors, `_` for space).
final class _Rep {
  _Rep(this.from, this.to, {required this.atStart, required this.atEnd});

  factory _Rep.parse(String from, String to) {
    var s = false;
    var e = false;
    var f = from;
    if (f.startsWith('^')) {
      s = true;
      f = f.substring(1);
    }
    if (f.endsWith(r'$')) {
      e = true;
      f = f.substring(0, f.length - 1);
    }
    return _Rep(
      f.replaceAll('_', ' '),
      to.replaceAll('_', ' '),
      atStart: s,
      atEnd: e,
    );
  }

  final String from;
  final String to;
  final bool atStart;
  final bool atEnd;
}

/// An `ICONV`/`OCONV` table: longest match wins at each position.
final class _Conv {
  final Map<int, List<(String, String)>> _byFirst = {};

  bool get isEmpty => _byFirst.isEmpty;

  void add(String from, String to) {
    if (from.isEmpty) return;
    final list = _byFirst.putIfAbsent(from.codeUnitAt(0), () => []);
    list.add((from, to));
    list.sort((a, b) => b.$1.length.compareTo(a.$1.length));
  }

  String apply(String s) {
    final map = _byFirst;
    if (map.isEmpty) return s;
    var i = 0;
    while (i < s.length && !map.containsKey(s.codeUnitAt(i))) {
      i++;
    }
    if (i == s.length) return s;
    final sb = StringBuffer(s.substring(0, i));
    while (i < s.length) {
      final list = map[s.codeUnitAt(i)];
      var matched = false;
      if (list != null) {
        for (final (from, to) in list) {
          if (s.startsWith(from, i)) {
            sb.write(to);
            i += from.length;
            matched = true;
            break;
          }
        }
      }
      if (!matched) {
        sb.writeCharCode(s.codeUnitAt(i));
        i++;
      }
    }
    return sb.toString();
  }
}

/// A `CHECKCOMPOUNDPATTERN` entry (without the replacement form).
final class _CompoundPattern {
  _CompoundPattern(this.end, this.endFlag, this.begin, this.beginFlag);

  final String end;
  final int endFlag;
  final String begin;
  final int beginFlag;
}
