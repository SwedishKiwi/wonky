/// Column letters ⇄ zero-based column index (`A` = 0, `Z` = 25, `AA` = 26, `ZZZ` = 18,277).
abstract final class ColumnLetters {
  /// Maximum number of columns addressable with letters (`A` … `ZZZ`).
  static const int maxColumns = 18278;

  /// Maximum number of rows (05 §3.4).
  static const int maxRows = 10000000;

  static final List<String> _cache = List<String>.filled(1024, '');

  /// Letters for the zero-based [index] (`0` → `A`). Throws [RangeError] for negative indices.
  static String fromIndex(int index) {
    if (index < 0) throw RangeError.value(index, 'index', 'must be >= 0');
    if (index < _cache.length) {
      final cached = _cache[index];
      if (cached.isNotEmpty) return cached;
    }
    var n = index + 1;
    final codes = <int>[];
    while (n > 0) {
      final rem = (n - 1) % 26;
      codes.add(0x41 + rem);
      n = (n - 1) ~/ 26;
    }
    final s = String.fromCharCodes(codes.reversed);
    if (index < _cache.length) _cache[index] = s;
    return s;
  }

  /// Zero-based index of [letters] (case-insensitive), or `-1` when [letters] is not 1–3 ASCII
  /// letters.
  static int toIndex(String letters) {
    if (letters.isEmpty || letters.length > 3) return -1;
    var n = 0;
    for (var i = 0; i < letters.length; i++) {
      var c = letters.codeUnitAt(i);
      if (c >= 0x61 && c <= 0x7a) c -= 0x20;
      if (c < 0x41 || c > 0x5a) return -1;
      n = n * 26 + (c - 0x40);
    }
    return n - 1;
  }

  /// Whether [c] is an ASCII letter code unit.
  static bool isLetter(int c) => (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a);

  /// Whether [c] is an ASCII digit code unit.
  static bool isDigit(int c) => c >= 0x30 && c <= 0x39;
}
