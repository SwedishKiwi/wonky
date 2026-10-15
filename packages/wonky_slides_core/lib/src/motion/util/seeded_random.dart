/// Deterministic hashing and pseudo-random numbers of the timeline (06
/// §9.3): random part order, dissolve noise seeds and typewriter jitter.
///
/// Everything is 32-bit integer arithmetic that gives the same results on
/// the Dart VM (server, tests), dart2wasm (release web build) and dart2js /
/// DDC (debug web builds, whose integers are JavaScript doubles), so client,
/// server and PDF agree bit for bit. (06 names SplitMix64; 64-bit
/// multiplication is not exact on JavaScript, so the core uses the 32-bit
/// Mulberry32 generator seeded by FNV-1a.)
library;

/// 32-bit integer helpers that are exact on every Dart platform.
abstract final class Int32Math {
  /// `0xFFFFFFFF`.
  static const int mask = 0xFFFFFFFF;

  /// The low 32 bits of `a × b` (JavaScript `Math.imul`, unsigned).
  static int imul(int a, int b) {
    final ah = (a >> 16) & 0xFFFF, al = a & 0xFFFF;
    final bh = (b >> 16) & 0xFFFF, bl = b & 0xFFFF;
    final hi = ((ah * bl + al * bh) & 0xFFFF) * 0x10000;
    return (al * bl + hi) % 0x100000000;
  }

  /// Unsigned right shift of a 32-bit value.
  static int shr(int a, int n) => (a & mask) >> n;
}

/// FNV-1a over the UTF-16 code units of a string (32-bit, unsigned).
int stableHash(String s) {
  var h = 0x811C9DC5;
  for (var i = 0; i < s.length; i++) {
    h = (h ^ s.codeUnitAt(i)) & Int32Math.mask;
    h = Int32Math.imul(h, 0x01000193);
  }
  return h;
}

/// The seed of a build part: `hash("<buildId>:<part>[:<salt>]")`.
int partSeed(String buildId, int part, [String salt = '']) =>
    stableHash(salt.isEmpty ? '$buildId:$part' : '$buildId:$part:$salt');

/// Mulberry32: a small, fast 32-bit generator with a full 2^32 period.
final class SeededRandom {
  /// Creates a generator from a 32-bit [seed].
  SeededRandom(int seed) : _state = seed & Int32Math.mask;

  int _state;

  /// The next unsigned 32-bit value.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) % 0x100000000;
    var t = _state;
    t = Int32Math.imul(t ^ Int32Math.shr(t, 15), t | 1);
    t =
        (t ^
            ((t + Int32Math.imul(t ^ Int32Math.shr(t, 7), t | 61)) %
                0x100000000)) &
        Int32Math.mask;
    return (t ^ Int32Math.shr(t, 14)) & Int32Math.mask;
  }

  /// A double in `[0, 1)`.
  double nextDouble() => nextUint32() / 4294967296.0;

  /// An int in `[0, max)`.
  int nextInt(int max) => max <= 1 ? 0 : (nextDouble() * max).floor();

  /// Fisher–Yates shuffle of [list] in place.
  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }
}
