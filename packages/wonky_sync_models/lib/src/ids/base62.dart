/// Base-62 helpers shared by the id codec and the fractional index.
///
/// The alphabet is in ASCII order (`0-9A-Za-z`), so lexicographic comparison of
/// equal-length base-62 strings equals numeric comparison.
library;

/// The base-62 alphabet in ASCII order.
const String base62Digits =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

final List<int> _digitValues = () {
  final table = List<int>.filled(128, -1);
  for (var i = 0; i < base62Digits.length; i++) {
    table[base62Digits.codeUnitAt(i)] = i;
  }
  return table;
}();

/// Value of a base-62 digit code unit, or -1 if [codeUnit] is not a digit.
int base62Value(int codeUnit) =>
    codeUnit < 128 ? _digitValues[codeUnit] : -1;

/// Codec between UUIDs and their 22-character base-62 form used inside
/// stored formula reference tokens (`⟦R:<id22>;C:<id22>⟧`, specs/wonky_sheets/02 §2).
///
/// The 128-bit UUID value is written big-endian in base 62, left-padded with
/// `0` to 22 characters (62^22 > 2^128). Encoding preserves order: comparing two
/// encodings as strings compares the UUIDs numerically. Implemented with byte
/// long-division so it is exact on the web (no 64-bit ints, no BigInt).
abstract final class Base62Uuid {
  /// Length of an encoded id.
  static const int length = 22;

  /// Encodes a UUID string (`xxxxxxxx-xxxx-…`, any case, dashes optional).
  static String encode(String uuid) => encodeBytes(_parseUuid(uuid));

  /// Encodes 16 raw UUID bytes.
  static String encodeBytes(List<int> bytes) {
    if (bytes.length != 16) {
      throw ArgumentError.value(bytes.length, 'bytes', 'must be 16 bytes');
    }
    final work = List<int>.of(bytes);
    final out = List<int>.filled(length, 0x30);
    for (var pos = length - 1; pos >= 0; pos--) {
      var rem = 0;
      for (var i = 0; i < 16; i++) {
        final acc = (rem << 8) | work[i];
        work[i] = acc ~/ 62;
        rem = acc % 62;
      }
      out[pos] = base62Digits.codeUnitAt(rem);
    }
    return String.fromCharCodes(out);
  }

  /// Decodes a 22-char base-62 id to the canonical lower-case dashed UUID string.
  /// Throws [FormatException] for malformed input.
  static String decode(String id22) => _formatUuid(decodeBytes(id22));

  /// Decodes a 22-char base-62 id to 16 bytes. Throws [FormatException].
  static List<int> decodeBytes(String id22) {
    if (id22.length != length) {
      throw FormatException('Base-62 id must be $length characters', id22);
    }
    final bytes = List<int>.filled(16, 0);
    for (var p = 0; p < length; p++) {
      final d = base62Value(id22.codeUnitAt(p));
      if (d < 0) throw FormatException('Invalid base-62 digit', id22, p);
      // bytes = bytes * 62 + d
      var carry = d;
      for (var i = 15; i >= 0; i--) {
        final acc = bytes[i] * 62 + carry;
        bytes[i] = acc & 0xff;
        carry = acc >> 8;
      }
      if (carry != 0) throw FormatException('Base-62 id overflows 128 bits', id22);
    }
    return bytes;
  }

  /// Whether [s] is a well-formed 22-char base-62 id.
  static bool isValid(String s) {
    if (s.length != length) return false;
    for (var i = 0; i < s.length; i++) {
      if (base62Value(s.codeUnitAt(i)) < 0) return false;
    }
    try {
      decodeBytes(s);
      return true;
    } on FormatException {
      return false;
    }
  }

  static List<int> _parseUuid(String uuid) {
    final hex = uuid.replaceAll('-', '');
    if (hex.length != 32) throw FormatException('Invalid UUID', uuid);
    final bytes = List<int>.filled(16, 0);
    for (var i = 0; i < 16; i++) {
      final v = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (v == null) throw FormatException('Invalid UUID', uuid);
      bytes[i] = v;
    }
    return bytes;
  }

  static String _formatUuid(List<int> b) {
    final sb = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) sb.write('-');
      sb.write(b[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
