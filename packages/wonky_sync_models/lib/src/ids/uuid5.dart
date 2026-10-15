import 'dart:convert';
import 'dart:typed_data';

/// UUIDv5 (RFC 4122 §4.3: SHA-1 of namespace bytes + UTF-8 name, version 5,
/// RFC variant) for one fixed namespace, without per-call parsing (the
/// `Uuid.v5` of `package:uuid` parses and validates the namespace on every
/// call). Equal to `Uuid().v5(namespace, name)`. Internal to the id helpers
/// (not exported by `ids.dart`).
final class Uuid5 {
  /// A hasher for the dashed lower-case UUID [namespace].
  Uuid5(String namespace)
    : _ns = [
        for (var i = 0; i < 32; i += 2)
          int.parse(
            namespace.replaceAll('-', '').substring(i, i + 2),
            radix: 16,
          ),
      ];

  final List<int> _ns;
  final Uint32List _w = Uint32List(80);

  static const _hex = '0123456789abcdef';

  /// `UUIDv5(namespace, name)` as a dashed lower-case UUID string.
  String of(String name) {
    final bytes = <int>[..._ns, ...utf8.encode(name)];
    final h = _sha1(bytes);
    h[6] = (h[6] & 0x0f) | 0x50;
    h[8] = (h[8] & 0x3f) | 0x80;
    final out = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) out.write('-');
      out
        ..write(_hex[h[i] >> 4])
        ..write(_hex[h[i] & 0x0f]);
    }
    return out.toString();
  }

  /// The first 16 bytes of the SHA-1 digest of [message].
  Uint8List _sha1(List<int> message) {
    final ml = message.length;
    final padded = Uint8List(((ml + 8) ~/ 64 + 1) * 64)..setAll(0, message);
    padded[ml] = 0x80;
    final bits = ml * 8;
    for (var i = 0; i < 8; i++) {
      padded[padded.length - 1 - i] = (bits >> (8 * i)) & 0xff;
    }
    var h0 = 0x67452301, h1 = 0xefcdab89, h2 = 0x98badcfe;
    var h3 = 0x10325476, h4 = 0xc3d2e1f0;
    final w = _w;
    int rotl(int x, int n) => ((x << n) | (x >> (32 - n))) & 0xffffffff;
    for (var off = 0; off < padded.length; off += 64) {
      for (var i = 0; i < 16; i++) {
        final j = off + i * 4;
        w[i] =
            (padded[j] << 24) |
            (padded[j + 1] << 16) |
            (padded[j + 2] << 8) |
            padded[j + 3];
      }
      for (var i = 16; i < 80; i++) {
        w[i] = rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
      }
      var a = h0, b = h1, c = h2, d = h3, e = h4;
      for (var i = 0; i < 80; i++) {
        final int f, k;
        if (i < 20) {
          f = (b & c) | ((~b & 0xffffffff) & d);
          k = 0x5a827999;
        } else if (i < 40) {
          f = b ^ c ^ d;
          k = 0x6ed9eba1;
        } else if (i < 60) {
          f = (b & c) | (b & d) | (c & d);
          k = 0x8f1bbcdc;
        } else {
          f = b ^ c ^ d;
          k = 0xca62c1d6;
        }
        final t = (rotl(a, 5) + f + e + k + w[i]) & 0xffffffff;
        e = d;
        d = c;
        c = rotl(b, 30);
        b = a;
        a = t;
      }
      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
    }
    final out = Uint8List(16);
    for (final (i, h) in [h0, h1, h2, h3].indexed) {
      out[i * 4] = h >> 24;
      out[i * 4 + 1] = (h >> 16) & 0xff;
      out[i * 4 + 2] = (h >> 8) & 0xff;
      out[i * 4 + 3] = h & 0xff;
    }
    return out;
  }
}
