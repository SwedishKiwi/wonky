/// Deterministic seeds and jitter for type-in (Slides 07 §5.3).
///
/// 32-bit integer arithmetic only, so the Dart VM (server, tests),
/// dart2wasm and dart2js produce the same numbers (07 §5.8, acceptance
/// criterion 10). 07 names SplitMix64; 64-bit multiplication is not exact on
/// JavaScript, so — like the Slides timeline (06 §9.3) — type-in uses the
/// 32-bit Mulberry32 generator seeded with FNV-1a.
library;

/// The seed of the typing script into a state:
/// `fnv1a("<elementId>:<targetStateId>")`.
int typingSeed(String elementId, String targetStateId) =>
    fnv1a32('$elementId:$targetStateId');

/// FNV-1a over the UTF-16 code units of [s] (32-bit, unsigned).
int fnv1a32(String s) {
  var h = 0x811C9DC5;
  for (var i = 0; i < s.length; i++) {
    h = (h ^ s.codeUnitAt(i)) & 0xFFFFFFFF;
    h = _imul(h, 0x01000193);
  }
  return h;
}

/// Mulberry32: a small 32-bit generator.
final class TypingRandom {
  /// Creates a generator from a 32-bit [seed].
  TypingRandom(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  /// The next unsigned 32-bit value.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) % 0x100000000;
    var t = _state;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) % 0x100000000)) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  /// A double in `[0, 1)`.
  double nextDouble() => nextUint32() / 4294967296.0;
}

/// The low 32 bits of `a × b` (unsigned), exact on every platform.
int _imul(int a, int b) {
  final ah = (a >> 16) & 0xFFFF, al = a & 0xFFFF;
  final bh = (b >> 16) & 0xFFFF, bl = b & 0xFFFF;
  final hi = ((ah * bl + al * bh) & 0xFFFF) * 0x10000;
  return (al * bl + hi) % 0x100000000;
}
