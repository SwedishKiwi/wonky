part of 'hunspell.dart';

/// Hunspell capitalization types.
enum _Cap {
  /// No uppercase letters (`hello`).
  lower,

  /// Only the first letter is uppercase (`Hello`).
  init,

  /// All cased letters are uppercase (`HELLO`).
  all,

  /// Mixed, starting lowercase (`iPhone`).
  huh,

  /// Mixed, starting uppercase (`JavaScript`).
  huhInit,
}

/// Whether the UTF-16 code unit [c] is an uppercase letter.
bool _isUpperUnit(int c) {
  if (c < 0x80) return c >= 0x41 && c <= 0x5A;
  final s = String.fromCharCode(c);
  return s.toLowerCase() != s;
}

/// Whether the UTF-16 code unit [c] has no case (digits, punctuation, …).
bool _isNeutralUnit(int c) {
  if (c < 0x80) return !((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A));
  final s = String.fromCharCode(c);
  return s.toLowerCase() == s.toUpperCase();
}

_Cap _capType(String w) {
  var upper = 0;
  var neutral = 0;
  var firstUpper = false;
  for (var i = 0; i < w.length; i++) {
    final c = w.codeUnitAt(i);
    if (_isUpperUnit(c)) {
      upper++;
      if (i == 0) firstUpper = true;
    } else if (_isNeutralUnit(c)) {
      neutral++;
    }
  }
  if (upper == 0) return _Cap.lower;
  if (upper == 1 && firstUpper) return _Cap.init;
  if (upper + neutral == w.length) return _Cap.all;
  return firstUpper ? _Cap.huhInit : _Cap.huh;
}

int _firstCharLength(String w) =>
    w.length > 1 && _isHighSurrogate(w.codeUnitAt(0)) ? 2 : 1;

/// `hELLO` → `Hello`.
String _initCap(String w) {
  if (w.isEmpty) return w;
  final n = _firstCharLength(w);
  return w.substring(0, n).toUpperCase() + w.substring(n).toLowerCase();
}

/// `hello` → `Hello` (rest unchanged).
String _upperFirst(String w) {
  if (w.isEmpty) return w;
  final n = _firstCharLength(w);
  return w.substring(0, n).toUpperCase() + w.substring(n);
}

/// `L'AMOUR` → `L'Amour`, `O'BRIEN` → `O'Brien`.
String _apostropheCap(String w) {
  final lower = w.toLowerCase();
  final sb = StringBuffer();
  var capNext = true;
  for (var i = 0; i < lower.length; i++) {
    final ch = lower[i];
    sb.write(capNext ? ch.toUpperCase() : ch);
    capNext = ch == "'" || ch == '’';
  }
  return sb.toString();
}
