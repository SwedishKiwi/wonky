import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

List<int> _utf16(String s, {required bool little}) => [
  for (final c in s.codeUnits)
    ...(little ? [c & 0xff, c >> 8] : [c >> 8, c & 0xff]),
];

void main() {
  group('Given byte order marks', () {
    final vectors = [
      ([0xef, 0xbb, 0xbf, 0x61], TextEncoding.utf8, 3),
      ([0xff, 0xfe, 0x61, 0x00], TextEncoding.utf16le, 2),
      ([0xfe, 0xff, 0x00, 0x61], TextEncoding.utf16be, 2),
    ];
    for (final (bytes, encoding, bom) in vectors) {
      test('when sniffing $bytes then the encoding is ${encoding.label}', () {
        final s = EncodingSniffer.sniff(bytes);
        expect((s.encoding, s.bomLength, s.reason), (encoding, bom, 'bom'));
      });
    }
  });

  group('Given bytes without a byte order mark', () {
    test('when every other byte is zero then it is UTF-16', () {
      expect(
        EncodingSniffer.sniff(_utf16('a,b\n1,2\n', little: true)).encoding,
        TextEncoding.utf16le,
      );
      expect(
        EncodingSniffer.sniff(_utf16('a,b\n1,2\n', little: false)).encoding,
        TextEncoding.utf16be,
      );
    });

    test('when the bytes are valid UTF-8 then it is UTF-8', () {
      final s = EncodingSniffer.sniff(utf8.encode('Grüße,漢字\n'));
      expect((s.encoding, s.reason), (TextEncoding.utf8, 'validUtf8'));
    });

    test('when the sample ends inside a UTF-8 sequence then it is UTF-8', () {
      final bytes = utf8.encode('ab€');
      expect(
        EncodingSniffer.sniff(bytes.sublist(0, bytes.length - 1)).encoding,
        TextEncoding.utf8,
      );
    });

    test('when the bytes are not UTF-8 then Windows-1252 is the fallback', () {
      final s = EncodingSniffer.sniff(latin1.encode('café;1\n'));
      expect((s.encoding, s.reason), (TextEncoding.windows1252, 'fallback'));
    });
  });

  group('Given single-byte code pages', () {
    const vectors = [
      (TextEncoding.windows1252, [0x80, 0x93, 0xe9], '€“é'),
      (TextEncoding.iso88591, [0xa4, 0xe9], '¤é'),
      (TextEncoding.iso885915, [0xa4, 0xbd], '€œ'),
      (TextEncoding.macRoman, [0x80, 0xa5, 0xdb], 'Ä•€'),
    ];
    for (final (enc, bytes, text) in vectors) {
      test('when decoding ${enc.label} then the characters map correctly', () {
        expect(enc.decode(bytes), text);
        expect(enc.encode(text), bytes);
      });
    }
  });

  group('Given chunked decoding', () {
    test('when UTF-8 sequences span chunks then they decode once', () {
      final bytes = [0xef, 0xbb, 0xbf, ...utf8.encode('a€b😀')];
      final d = TextEncoding.utf8.decoder();
      final out = StringBuffer();
      for (final b in bytes) {
        out.write(d.convert([b]));
      }
      out.write(d.close());
      expect(out.toString(), 'a€b😀');
    });

    test('when UTF-16 units span chunks then they decode once', () {
      final bytes = [0xff, 0xfe, ..._utf16('x€', little: true)];
      final d = TextEncoding.utf16le.decoder();
      final out = StringBuffer();
      for (final b in bytes) {
        out.write(d.convert([b]));
      }
      out.write(d.close());
      expect(out.toString(), 'x€');
    });
  });

  group('Given encoding ids', () {
    const vectors = [
      ('UTF-8', TextEncoding.utf8),
      ('utf8', TextEncoding.utf8),
      ('cp1252', TextEncoding.windows1252),
      ('latin1', TextEncoding.iso88591),
      ('macintosh', TextEncoding.macRoman),
      ('shift_jis', null),
    ];
    for (final (id, enc) in vectors) {
      test('when looking up "$id" then it is ${enc?.label}', () {
        expect(TextEncoding.byId(id), enc);
      });
    }
  });
}
