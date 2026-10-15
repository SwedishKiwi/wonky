import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_core/files.dart';

/// `ImageDimensions.read` (Drive 02 §6.2): the preview reads an image's size
/// from its header because `ImageDescriptor.encoded` can't on the web (D-18:
/// every uploaded image showed "This image can't be displayed").
void main() {
  Uint8List b64(String s) => base64Decode(s);
  Uint8List bytes(List<int> b) => Uint8List.fromList(b);

  group('server fixtures', () {
    test('PNG', () {
      expect(ImageDimensions.read(b64(_png)), const ImageDimensions(8, 6));
    });
    test('JPEG with EXIF orientation 6 swaps the sides', () {
      expect(ImageDimensions.read(b64(_jpeg)), const ImageDimensions(12, 16));
    });
    test('GIF', () {
      expect(ImageDimensions.read(b64(_gif)), const ImageDimensions(4, 4));
    });
    test('BMP', () {
      expect(ImageDimensions.read(b64(_bmp)), const ImageDimensions(4, 4));
    });
    test('ICO', () {
      expect(ImageDimensions.read(b64(_ico)), const ImageDimensions(4, 4));
    });
  });

  group('crafted headers', () {
    List<int> riff(String chunk, List<int> payload) => [
      ...'RIFF'.codeUnits,
      0,
      0,
      0,
      0,
      ...'WEBP'.codeUnits,
      ...chunk.codeUnits,
      0,
      0,
      0,
      0,
      ...payload,
    ];

    test('WebP lossy (VP8)', () {
      final b = riff('VP8 ', [
        0, 0, 0, // frame tag
        0x9D, 0x01, 0x2A,
        0x80, 0x02, // 640
        0x90, 0x01, // 400
      ]);
      expect(ImageDimensions.read(bytes(b)), const ImageDimensions(640, 400));
    });

    test('WebP lossless (VP8L)', () {
      // 14-bit width-1 and height-1 packed little-endian after 0x2F.
      const w = 300, h = 200;
      final bits = (w - 1) | ((h - 1) << 14);
      final b = riff('VP8L', [
        0x2F,
        bits & 0xFF,
        (bits >> 8) & 0xFF,
        (bits >> 16) & 0xFF,
        (bits >> 24) & 0xFF,
      ]);
      expect(ImageDimensions.read(bytes(b)), const ImageDimensions(300, 200));
    });

    test('WebP extended (VP8X)', () {
      final b = riff('VP8X', [
        0, 0, 0, 0, // flags + reserved
        0xFF, 0x0F, 0x00, // 4096 - 1
        0xFF, 0x07, 0x00, // 2048 - 1
      ]);
      expect(ImageDimensions.read(bytes(b)), const ImageDimensions(4096, 2048));
    });

    test('progressive JPEG (SOF2) after other segments', () {
      final b = [
        0xFF, 0xD8,
        0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0, 2 bytes payload
        0xFF, 0xDB, 0x00, 0x03, 0x00, // DQT
        0xFF, 0xC2, 0x00, 0x0B, 0x08, 0x0F, 0xA0, 0x1F, 0x40, 0x03, 0, 0, 0,
      ];
      // height 4000, width 8000.
      expect(ImageDimensions.read(bytes(b)), const ImageDimensions(8000, 4000));
      expect(ImageDimensions.read(bytes(b))!.pixels, 32000000);
    });

    test('APNG and large PNG sizes', () {
      final b = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0, 0, 0, 13, ...'IHDR'.codeUnits,
        0x00, 0x00, 0x27, 0x10, // 10000
        0x00, 0x00, 0x1F, 0x40, // 8000
      ];
      expect(ImageDimensions.read(bytes(b))!.pixels, 80000000);
    });
  });

  group('not an image or broken', () {
    test('null for text, empty and truncated headers', () {
      expect(ImageDimensions.read(bytes(utf8.encode('hello'))), isNull);
      expect(ImageDimensions.read(Uint8List(0)), isNull);
      final png = b64(_png);
      expect(ImageDimensions.read(png.sublist(0, 18)), isNull);
      final jpeg = b64(_jpeg);
      expect(ImageDimensions.read(jpeg.sublist(0, 40)), isNull);
    });

    test('null for a zero-sized header and a JPEG without a frame', () {
      final png = Uint8List.fromList(b64(_png));
      for (var i = 16; i < 24; i++) {
        png[i] = 0;
      }
      expect(ImageDimensions.read(png), isNull);
      expect(
        ImageDimensions.read(bytes([0xFF, 0xD8, 0xFF, 0xD9, 0, 0])),
        isNull,
      );
    });
  });
}

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAGCAYAAAD+Bd/7AAAAFUlEQVR4nGM5ISfXwIAH'
    'sOCTHCwKADRjAZ2WYZY7AAAAAElFTkSuQmCC';

const _jpeg =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/4QA8RXhpZgAATU0AKgAAAAgAAgESAAMAAAABAAYA'
    'AIglAAQAAAABAAAAJgAAAAAAAQABAAIAAAACTgAAAP/bAIQAAQEBAQEBAQEBAQEBAQEB'
    'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB'
    'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB'
    'AQEBAQEBAQEBAQEB/8AAEQgADAAQAwERAAIRAQMRAf/EAaIAAAEFAQEBAQEBAAAAAAAA'
    'AAABAgMEBQYHCAkKCxAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKB'
    'kaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZ'
    'WmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5'
    'usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6AQADAQEBAQEBAQEB'
    'AAAAAAAAAQIDBAUGBwgJCgsRAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXET'
    'IjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNU'
    'VVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKz'
    'tLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/aAAwDAQAC'
    'EQMRAD8A/P8Ar/dg/wADwoAKACgD/9k=';

const _gif =
    'R0lGODlhBAAEAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQIUAAAACwAAAAABAAEAIcA'
    'AAAAAAAAAAABAQECAgIDAwMEBAQFBQUGBgYHBwcICAgJCQkKCgoLCwsMDAwNDQ0ODg4P'
    'Dw8QEBARERESEhITExMUFBQVFRUWFhYXFxcYGBgZGRkaGhobGxscHBwdHR0eHh4fHx8g'
    'ICAhISEiIiIjIyMkJCQlJSUmJiYnJycoKCgpKSkqKiorKyssLCwtLS0uLi4vLy8wMDAx'
    'MTEyMjIzMzM0NDQ1NTU2NjY3Nzc4ODg5OTk6Ojo7Ozs8PDw9PT0+Pj4/Pz9BQUFCQkJD'
    'Q0NERERFRUVGRkZHR0dISEhJSUlKSkpLS0tMTExNTU1OTk5PT09QUFBRUVFSUlJTU1NU'
    'VFRVVVVWVlZXV1dYWFhZWVlaWlpbW1tcXFxdXV1eXl5fX19gYGBhYWFiYmJjY2NkZGRl'
    'ZWVmZmZnZ2doaGhpaWlqampra2tsbGxtbW1ubm5vb29wcHBxcXFycnJzc3N0dHR1dXV2'
    'dnZ3d3d4eHh5eXl6enp7e3t8fHx9fX1+fn5/f3+AgICBgYGCgoKDg4OEhISFhYWGhoaH'
    'h4eIiIiJiYmKioqLi4uMjIyNjY2Ojo6Pj4+QkJCRkZGSkpKTk5OUlJSVlZWWlpaXl5eY'
    'mJiZmZmampqbm5ucnJydnZ2enp6fn5+goKChoaGioqKjo6OkpKSlpaWmpqanp6eoqKip'
    'qamqqqqrq6usrKytra2urq6vr6+wsLCxsbGysrKzs7O0tLS1tbW2tra3t7e4uLi5ubm6'
    'urq7u7u8vLy9vb2+vr7AwMDBwcHCwsLDw8PExMTFxcXGxsbHx8fIyMjJycnKysrLy8vM'
    'zMzNzc3Ozs7Pz8/Q0NDR0dHS0tLT09PU1NTV1dXW1tbX19fY2NjZ2dna2trb29vc3Nzd'
    '3d3e3t7f39/g4ODh4eHi4uLj4+Pk5OTl5eXm5ubn5+fo6Ojp6enq6urr6+vs7Ozt7e3u'
    '7u7v7+/w8PDx8fHy8vLz8/P09PT19fX29vb39/f4+Pj5+fn6+vr7+/v8/Pz9/f3+/v7/'
    '//8ICQADCBxIsGCAgAA7';

const _bmp =
    'Qk26AAAAAAAAAIoAAAB8AAAABAAAAAQAAAABABgAAwAAADAAAAAjLgAAIy4AAAAAAAAA'
    'AAAAAAD/AAD/AAD/AAAAAAAA/0JHUnMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

const _ico =
    'AAABAAEABAQAAAAAIABHAAAAFgAAAIlQTkcNChoKAAAADUlIRFIAAAAEAAAABAgCAAAA'
    'JpMJKQAAAA5JREFUeJxjYUACLMRxAAI8ABEdLqrKAAAAAElFTkSuQmCC';
