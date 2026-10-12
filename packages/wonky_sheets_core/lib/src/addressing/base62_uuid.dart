/// UUID ⇄ 22-character base-62 form used inside stored formula reference tokens (02 §2).
///
/// Alphabet `0-9A-Za-z` (same order as the fractional index), big-endian, left-padded with `0`.
/// This mirrors `wonky_sync_models/lib/ids.dart`; it lives here so the formula engine has no
/// dependency on the synced models.
abstract final class Base62Uuid {
  static const String alphabet =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  static const int length = 22;
  static final BigInt _62 = BigInt.from(62);
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final Map<String, String> _encodeCache = {};
  static final Map<String, String> _decodeCache = {};

  /// Whether [s] is a canonical (dashed) UUID string.
  static bool isUuid(String s) => s.length == 36 && _uuid.hasMatch(s);

  /// Whether [s] is a 22-char base-62 string.
  static bool isBase62(String s) {
    if (s.length != length) return false;
    for (var i = 0; i < s.length; i++) {
      if (_digit(s.codeUnitAt(i)) < 0) return false;
    }
    return true;
  }

  static int _digit(int c) {
    if (c >= 0x30 && c <= 0x39) return c - 0x30;
    if (c >= 0x41 && c <= 0x5a) return c - 0x41 + 10;
    if (c >= 0x61 && c <= 0x7a) return c - 0x61 + 36;
    return -1;
  }

  /// Canonical UUID → 22-char base-62.
  static String encode(String uuid) {
    final cached = _encodeCache[uuid];
    if (cached != null) return cached;
    var n = BigInt.parse(uuid.replaceAll('-', ''), radix: 16);
    final codes = List<int>.filled(length, 0x30);
    for (var i = length - 1; i >= 0 && n > BigInt.zero; i--) {
      final rem = (n % _62).toInt();
      codes[i] = alphabet.codeUnitAt(rem);
      n = n ~/ _62;
    }
    final s = String.fromCharCodes(codes);
    if (_encodeCache.length > 200000) _encodeCache.clear();
    _encodeCache[uuid] = s;
    return s;
  }

  /// 22-char base-62 → canonical lower-case UUID.
  static String decode(String b62) {
    final cached = _decodeCache[b62];
    if (cached != null) return cached;
    var n = BigInt.zero;
    for (var i = 0; i < b62.length; i++) {
      n = n * _62 + BigInt.from(_digit(b62.codeUnitAt(i)));
    }
    final hex = n.toRadixString(16).padLeft(32, '0');
    final s =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
    if (_decodeCache.length > 200000) _decodeCache.clear();
    _decodeCache[b62] = s;
    return s;
  }

  /// Id as written into a reference token: UUIDs become base-62; other ids (tests, synthetic
  /// ids) are written verbatim.
  static String toToken(String id) => isUuid(id) ? encode(id) : id;

  /// Inverse of [toToken].
  static String fromToken(String token) => isBase62(token) ? decode(token) : token;
}
