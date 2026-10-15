import 'dart:convert';
import 'dart:typed_data';

/// A minimal ZIP writer for already-compressed files (PNG exports, Slides
/// 10 §13): entries are *stored* (no deflate — PNGs don't shrink), with
/// CRC-32 and a fixed timestamp (1980-01-01), so equal inputs give equal
/// bytes. UTF-8 names (general purpose flag 11). Pure Dart.
abstract final class StoredZip {
  /// The ZIP of [entries] (name → bytes, in order).
  static Uint8List encode(List<(String name, Uint8List bytes)> entries) {
    final out = BytesBuilder(copy: false);
    final central = BytesBuilder(copy: false);
    var offset = 0;
    for (final (name, bytes) in entries) {
      final n = utf8.encode(name);
      final crc = crc32(bytes);
      final local = ByteData(30)
        ..setUint32(0, 0x04034b50, Endian.little)
        ..setUint16(4, 20, Endian.little) // version needed
        ..setUint16(6, 0x0800, Endian.little) // UTF-8 names
        ..setUint16(8, 0, Endian.little) // stored
        ..setUint16(10, 0, Endian.little) // time 00:00
        ..setUint16(12, 0x21, Endian.little) // date 1980-01-01
        ..setUint32(14, crc, Endian.little)
        ..setUint32(18, bytes.length, Endian.little)
        ..setUint32(22, bytes.length, Endian.little)
        ..setUint16(26, n.length, Endian.little)
        ..setUint16(28, 0, Endian.little);
      out
        ..add(local.buffer.asUint8List())
        ..add(n)
        ..add(bytes);
      final dir = ByteData(46)
        ..setUint32(0, 0x02014b50, Endian.little)
        ..setUint16(4, 20, Endian.little) // version made by
        ..setUint16(6, 20, Endian.little)
        ..setUint16(8, 0x0800, Endian.little)
        ..setUint16(10, 0, Endian.little)
        ..setUint16(12, 0, Endian.little)
        ..setUint16(14, 0x21, Endian.little)
        ..setUint32(16, crc, Endian.little)
        ..setUint32(20, bytes.length, Endian.little)
        ..setUint32(24, bytes.length, Endian.little)
        ..setUint16(28, n.length, Endian.little)
        ..setUint16(30, 0, Endian.little) // extra
        ..setUint16(32, 0, Endian.little) // comment
        ..setUint16(34, 0, Endian.little) // disk
        ..setUint16(36, 0, Endian.little) // internal attributes
        ..setUint32(38, 0, Endian.little) // external attributes
        ..setUint32(42, offset, Endian.little);
      central
        ..add(dir.buffer.asUint8List())
        ..add(n);
      offset += 30 + n.length + bytes.length;
    }
    final dirBytes = central.takeBytes();
    final end = ByteData(22)
      ..setUint32(0, 0x06054b50, Endian.little)
      ..setUint16(4, 0, Endian.little)
      ..setUint16(6, 0, Endian.little)
      ..setUint16(8, entries.length, Endian.little)
      ..setUint16(10, entries.length, Endian.little)
      ..setUint32(12, dirBytes.length, Endian.little)
      ..setUint32(16, offset, Endian.little)
      ..setUint16(20, 0, Endian.little);
    out
      ..add(dirBytes)
      ..add(end.buffer.asUint8List());
    return out.takeBytes();
  }

  static final Uint32List _table = () {
    final t = Uint32List(256);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      }
      t[n] = c;
    }
    return t;
  }();

  /// The CRC-32 (IEEE) of [bytes].
  static int crc32(List<int> bytes) {
    var c = 0xffffffff;
    for (final b in bytes) {
      c = _table[(c ^ b) & 0xff] ^ (c >>> 8);
    }
    return (c ^ 0xffffffff) & 0xffffffff;
  }
}
