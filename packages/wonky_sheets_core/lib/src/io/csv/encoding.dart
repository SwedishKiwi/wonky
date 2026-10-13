import 'dart:convert';
import 'dart:typed_data';

/// Text encodings supported by CSV import (11 §4.1).
enum TextEncoding {
  utf8('utf-8', 'UTF-8'),
  utf16le('utf-16le', 'UTF-16LE'),
  utf16be('utf-16be', 'UTF-16BE'),
  windows1252('windows-1252', 'Windows-1252'),
  iso88591('iso-8859-1', 'ISO-8859-1'),
  iso885915('iso-8859-15', 'ISO-8859-15'),
  macRoman('macintosh', 'Mac Roman');

  const TextEncoding(this.id, this.label);

  /// Id used in `ImportOptions.encoding`.
  final String id;

  /// Display label.
  final String label;

  /// By id (case-insensitive; common aliases accepted) or null.
  static TextEncoding? byId(String? id) {
    if (id == null) return null;
    final l = id.toLowerCase().replaceAll('_', '-');
    const aliases = {
      'utf8': 'utf-8',
      'cp1252': 'windows-1252',
      'latin1': 'iso-8859-1',
      'latin-1': 'iso-8859-1',
      'latin9': 'iso-8859-15',
      'mac-roman': 'macintosh',
      'macroman': 'macintosh',
      'utf-16': 'utf-16le',
    };
    final k = aliases[l] ?? l;
    for (final e in values) {
      if (e.id == k) return e;
    }
    return null;
  }

  /// A chunked decoder for this encoding.
  ChunkedTextDecoder decoder() => switch (this) {
    utf8 => _Utf8ChunkDecoder(),
    utf16le => _Utf16ChunkDecoder(littleEndian: true),
    utf16be => _Utf16ChunkDecoder(littleEndian: false),
    windows1252 => SingleByteDecoder(SingleByteDecoder.windows1252),
    iso88591 => SingleByteDecoder(SingleByteDecoder.latin1),
    iso885915 => SingleByteDecoder(SingleByteDecoder.latin9),
    macRoman => SingleByteDecoder(SingleByteDecoder.macRoman),
  };

  /// Decodes [bytes] completely (a BOM of this encoding is skipped).
  String decode(List<int> bytes) {
    final d = decoder();
    return d.convert(bytes) + d.close();
  }

  /// Encodes [text] (no BOM).
  Uint8List encode(String text) {
    switch (this) {
      case utf8:
        return const Utf8Encoder().convert(text);
      case utf16le:
      case utf16be:
        final out = Uint8List(text.length * 2);
        for (var i = 0; i < text.length; i++) {
          final c = text.codeUnitAt(i);
          final hi = c >> 8, lo = c & 0xff;
          out[2 * i] = this == utf16le ? lo : hi;
          out[2 * i + 1] = this == utf16le ? hi : lo;
        }
        return out;
      default:
        final table = (decoder() as SingleByteDecoder).table;
        final reverse = <int, int>{for (var i = 0; i < 256; i++) table[i]: i};
        final out = Uint8List(text.length);
        for (var i = 0; i < text.length; i++) {
          out[i] = reverse[text.codeUnitAt(i)] ?? 0x3f;
        }
        return out;
    }
  }
}

/// Incremental bytes → text decoding (sequences may span chunks).
abstract class ChunkedTextDecoder {
  /// Decodes the next chunk.
  String convert(List<int> bytes);

  /// Flushes pending bytes (malformed tails become U+FFFD).
  String close();
}

final class _Utf8ChunkDecoder extends ChunkedTextDecoder {
  final StringBuffer _sink = StringBuffer();
  late final ByteConversionSink _conv = const Utf8Decoder(
    allowMalformed: true,
  ).startChunkedConversion(StringConversionSink.fromStringSink(_sink));
  bool _first = true;

  @override
  String convert(List<int> bytes) {
    var b = bytes;
    if (_first && b.isNotEmpty) {
      _first = false;
      if (b.length >= 3 && b[0] == 0xef && b[1] == 0xbb && b[2] == 0xbf) {
        b = b.sublist(3);
      }
    }
    _conv.add(b);
    final s = _sink.toString();
    _sink.clear();
    return s;
  }

  @override
  String close() {
    _conv.close();
    final s = _sink.toString();
    _sink.clear();
    return s;
  }
}

final class _Utf16ChunkDecoder extends ChunkedTextDecoder {
  _Utf16ChunkDecoder({required this.littleEndian});

  final bool littleEndian;
  int? _pending;
  bool _first = true;

  @override
  String convert(List<int> bytes) {
    final codes = <int>[];
    var i = 0;
    if (_pending != null && bytes.isNotEmpty) {
      codes.add(_unit(_pending!, bytes[0]));
      _pending = null;
      i = 1;
    }
    for (; i + 1 < bytes.length; i += 2) {
      codes.add(_unit(bytes[i], bytes[i + 1]));
    }
    if (i < bytes.length) _pending = bytes[i];
    if (_first && codes.isNotEmpty) {
      _first = false;
      if (codes.first == 0xfeff) codes.removeAt(0);
    }
    return String.fromCharCodes(codes);
  }

  int _unit(int a, int b) => littleEndian ? a | (b << 8) : (a << 8) | b;

  @override
  String close() {
    if (_pending != null) {
      _pending = null;
      return '�';
    }
    return '';
  }
}

/// A single-byte code page decoder.
final class SingleByteDecoder extends ChunkedTextDecoder {
  /// Creates a decoder for a 256-entry code point [table].
  SingleByteDecoder(this.table);

  /// Byte → code point.
  final List<int> table;

  @override
  String convert(List<int> bytes) {
    final codes = Uint16List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      codes[i] = table[bytes[i] & 0xff];
    }
    return String.fromCharCodes(codes);
  }

  @override
  String close() => '';

  /// ISO-8859-1.
  static final List<int> latin1 = List<int>.generate(
    256,
    (i) => i,
    growable: false,
  );

  /// Windows-1252 (0x80–0x9F differ from Latin-1; undefined bytes map to
  /// their Latin-1 control code).
  static final List<int> windows1252 = () {
    final t = List<int>.generate(256, (i) => i);
    const hi = [
      0x20AC,
      0x81,
      0x201A,
      0x0192,
      0x201E,
      0x2026,
      0x2020,
      0x2021,
      0x02C6,
      0x2030,
      0x0160,
      0x2039, //
      0x0152,
      0x8D,
      0x017D,
      0x8F,
      0x90,
      0x2018,
      0x2019,
      0x201C,
      0x201D,
      0x2022,
      0x2013,
      0x2014,
      0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178,
    ];
    for (var i = 0; i < 32; i++) {
      t[0x80 + i] = hi[i];
    }
    return List<int>.unmodifiable(t);
  }();

  /// ISO-8859-15 (Latin-9).
  static final List<int> latin9 = () {
    final t = List<int>.generate(256, (i) => i);
    const changes = {
      0xA4: 0x20AC,
      0xA6: 0x0160,
      0xA8: 0x0161,
      0xB4: 0x017D,
      0xB8: 0x017E,
      0xBC: 0x0152,
      0xBD: 0x0153,
      0xBE: 0x0178,
    };
    changes.forEach((k, v) => t[k] = v);
    return List<int>.unmodifiable(t);
  }();

  /// Mac OS Roman.
  static final List<int> macRoman = () {
    final t = List<int>.generate(256, (i) => i);
    const hi = [
      0x00C4,
      0x00C5,
      0x00C7,
      0x00C9,
      0x00D1,
      0x00D6,
      0x00DC,
      0x00E1,
      0x00E0,
      0x00E2,
      0x00E4,
      0x00E3, //
      0x00E5,
      0x00E7,
      0x00E9,
      0x00E8,
      0x00EA,
      0x00EB,
      0x00ED,
      0x00EC,
      0x00EE,
      0x00EF,
      0x00F1,
      0x00F3,
      0x00F2,
      0x00F4,
      0x00F6,
      0x00F5,
      0x00FA,
      0x00F9,
      0x00FB,
      0x00FC,
      0x2020,
      0x00B0,
      0x00A2,
      0x00A3,
      0x00A7,
      0x2022,
      0x00B6,
      0x00DF,
      0x00AE,
      0x00A9,
      0x2122,
      0x00B4,
      0x00A8,
      0x2260,
      0x00C6,
      0x00D8,
      0x221E,
      0x00B1,
      0x2264,
      0x2265,
      0x00A5,
      0x00B5,
      0x2202,
      0x2211,
      0x220F,
      0x03C0,
      0x222B,
      0x00AA,
      0x00BA,
      0x03A9,
      0x00E6,
      0x00F8,
      0x00BF,
      0x00A1,
      0x00AC,
      0x221A,
      0x0192,
      0x2248,
      0x2206,
      0x00AB,
      0x00BB,
      0x2026,
      0x00A0,
      0x00C0,
      0x00C3,
      0x00D5,
      0x0152,
      0x0153,
      0x2013,
      0x2014,
      0x201C,
      0x201D,
      0x2018,
      0x2019,
      0x00F7,
      0x25CA,
      0x00FF,
      0x0178,
      0x2044,
      0x20AC,
      0x2039,
      0x203A,
      0xFB01,
      0xFB02,
      0x2021,
      0x00B7,
      0x201A,
      0x201E,
      0x2030,
      0x00C2,
      0x00CA,
      0x00C1,
      0x00CB,
      0x00C8,
      0x00CD,
      0x00CE,
      0x00CF,
      0x00CC,
      0x00D3,
      0x00D4,
      0xF8FF,
      0x00D2,
      0x00DA,
      0x00DB,
      0x00D9,
      0x0131,
      0x02C6,
      0x02DC,
      0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB, 0x02C7,
    ];
    for (var i = 0; i < 128; i++) {
      t[0x80 + i] = hi[i];
    }
    return List<int>.unmodifiable(t);
  }();
}

/// Result of [EncodingSniffer.sniff].
final class SniffedEncoding {
  /// Creates a result.
  const SniffedEncoding(
    this.encoding, {
    this.bomLength = 0,
    required this.reason,
  });

  final TextEncoding encoding;

  /// Length of the byte-order mark (to skip).
  final int bomLength;

  /// `bom`, `nulBytes`, `validUtf8` or `fallback`.
  final String reason;
}

/// Detects the encoding of CSV bytes (11 §4.1).
abstract final class EncodingSniffer {
  /// Sniffs [head] (the first bytes of the file; ≥ 64 KB when available).
  static SniffedEncoding sniff(List<int> head) {
    if (head.length >= 3 &&
        head[0] == 0xef &&
        head[1] == 0xbb &&
        head[2] == 0xbf) {
      return const SniffedEncoding(
        TextEncoding.utf8,
        bomLength: 3,
        reason: 'bom',
      );
    }
    if (head.length >= 2 && head[0] == 0xff && head[1] == 0xfe) {
      return const SniffedEncoding(
        TextEncoding.utf16le,
        bomLength: 2,
        reason: 'bom',
      );
    }
    if (head.length >= 2 && head[0] == 0xfe && head[1] == 0xff) {
      return const SniffedEncoding(
        TextEncoding.utf16be,
        bomLength: 2,
        reason: 'bom',
      );
    }
    final n4k = head.length < 4096 ? head.length : 4096;
    if (n4k >= 2) {
      var oddZero = 0, evenZero = 0;
      for (var i = 0; i < n4k; i++) {
        if (head[i] == 0) {
          if (i.isOdd) {
            oddZero++;
          } else {
            evenZero++;
          }
        }
      }
      final half = n4k / 2;
      if (oddZero >= half * 0.1 && oddZero > evenZero) {
        return const SniffedEncoding(TextEncoding.utf16le, reason: 'nulBytes');
      }
      if (evenZero >= half * 0.1 && evenZero > oddZero) {
        return const SniffedEncoding(TextEncoding.utf16be, reason: 'nulBytes');
      }
    }
    final n64k = head.length < 65536 ? head.length : 65536;
    if (_isUtf8(head, n64k)) {
      return const SniffedEncoding(TextEncoding.utf8, reason: 'validUtf8');
    }
    return const SniffedEncoding(TextEncoding.windows1252, reason: 'fallback');
  }

  /// Strict UTF-8 validation of `bytes[0, n)`, ignoring a truncated final
  /// sequence.
  static bool _isUtf8(List<int> bytes, int n) {
    var i = 0;
    while (i < n) {
      final b = bytes[i];
      if (b < 0x80) {
        i++;
        continue;
      }
      int len;
      int min;
      if (b >= 0xc2 && b <= 0xdf) {
        len = 2;
        min = 0x80;
      } else if (b >= 0xe0 && b <= 0xef) {
        len = 3;
        min = 0x800;
      } else if (b >= 0xf0 && b <= 0xf4) {
        len = 4;
        min = 0x10000;
      } else {
        return false;
      }
      if (i + len > n) return true; // truncated final sequence
      var cp = b & (0xff >> (len + 1));
      for (var k = 1; k < len; k++) {
        final c = bytes[i + k];
        if (c & 0xc0 != 0x80) return false;
        cp = (cp << 6) | (c & 0x3f);
      }
      if (cp < min || cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff)) {
        return false;
      }
      i += len;
    }
    return true;
  }
}
