import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_core/files.dart';
import 'package:wonky_server/src/platform/files/file_type_sniffer.dart';

import '../../support/file_fixtures.dart';

Uint8List _b(List<int> bytes) => Uint8List.fromList(bytes);
Uint8List _s(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  // (fixture, file name the user gave it, expected MIME type)
  final fixtures = <(String, String, String)>[
    ('image.png', 'image.png', 'image/png'),
    ('photo.jpg', 'photo.jpg', 'image/jpeg'),
    ('anim.gif', 'anim.gif', 'image/gif'),
    ('pic.bmp', 'pic.bmp', 'image/bmp'),
    ('scan.tif', 'scan.tif', 'image/tiff'),
    ('icon.ico', 'icon.ico', 'image/vnd.microsoft.icon'),
    ('report.pdf', 'report.pdf', 'application/pdf'),
    (
      'doc.docx',
      'doc.docx',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ),
    (
      'sheet.xlsx',
      'sheet.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ),
    (
      'deck.pptx',
      'deck.pptx',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    ),
    ('text.odt', 'text.odt', 'application/vnd.oasis.opendocument.text'),
    ('book.epub', 'book.epub', 'application/epub+zip'),
    ('plain.zip', 'plain.zip', 'application/zip'),
    ('data.gz', 'data.gz', 'application/gzip'),
    ('song.mp3', 'song.mp3', 'audio/mpeg'),
    ('program.exe', 'program.exe', 'application/x-msdownload'),
    ('random.bin', 'random.bin', 'application/octet-stream'),
    ('notes.md', 'notes.md', 'text/markdown'),
    ('main_dart.txt', 'main.dart', 'text/x-dart'),
    ('data.csv', 'data.csv', 'text/csv'),
    ('latin1.txt', 'latin1.txt', 'text/plain'),
    ('utf16.txt', 'utf16.txt', 'text/plain'),
    ('html_page.html', 'page.html', 'text/html'),
    ('drawing.svg', 'drawing.svg', 'image/svg+xml'),
    // Spoofed extensions: the signature wins.
    ('image.png', 'notes.txt', 'image/png'),
    ('report.pdf', 'photo.jpg', 'application/pdf'),
    ('program.exe', 'invoice.pdf', 'application/x-msdownload'),
    ('photo.jpg', 'document.docx', 'image/jpeg'),
    (
      'doc.docx',
      'archive.zip',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ),
    ('plain.zip', 'fake.docx', 'application/zip'),
    ('data.gz', 'readme.txt', 'application/gzip'),
    // Active content is found by content, never trusted from the name.
    ('html_page.html', 'photo.jpg', 'text/html'),
    ('html_page.html', 'notes.txt', 'text/html'),
    ('drawing.svg', 'image.png', 'image/svg+xml'),
    ('notes.md', 'page.html', 'text/html'),
    ('notes.md', 'drawing.svg', 'text/plain'),
    ('main_dart.txt', 'image.png', 'text/plain'),
  ];

  group('Given the sample files', () {
    for (final (fixture, name, expected) in fixtures) {
      test('when sniffing $fixture named "$name" then it is $expected', () {
        final result = FileTypeSniffer.sniff(
          FileFixtures.bytes(fixture),
          fileName: name,
        );

        expect(result.mimeType, expected);
      });
    }
  });

  // (description, bytes, file name, expected MIME type)
  final vectors = <(String, Uint8List, String, String)>[
    (
      'WebP',
      _b([...ascii.encode('RIFF'), 0, 0, 0, 0, ...ascii.encode('WEBPVP8 ')]),
      'x.webp',
      'image/webp',
    ),
    (
      'WAV',
      _b([...ascii.encode('RIFF'), 0, 0, 0, 0, ...ascii.encode('WAVEfmt ')]),
      'x.wav',
      'audio/wav',
    ),
    (
      'AVI',
      _b([...ascii.encode('RIFF'), 0, 0, 0, 0, ...ascii.encode('AVI LIST')]),
      'x.avi',
      'video/x-msvideo',
    ),
    (
      'HEIC',
      _b([0, 0, 0, 24, ...ascii.encode('ftypheic'), 0, 0, 0, 0]),
      'x.heic',
      'image/heic',
    ),
    (
      'M4A',
      _b([0, 0, 0, 24, ...ascii.encode('ftypM4A '), 0, 0, 0, 0]),
      'x.m4a',
      'audio/mp4',
    ),
    (
      'MP4',
      _b([0, 0, 0, 24, ...ascii.encode('ftypisom'), 0, 0, 0, 0]),
      'x.mp4',
      'video/mp4',
    ),
    (
      'QuickTime',
      _b([0, 0, 0, 20, ...ascii.encode('ftypqt  '), 0, 0, 0, 0]),
      'x.mov',
      'video/quicktime',
    ),
    ('Ogg', _b([...ascii.encode('OggS'), 0, 2, 0, 0]), 'x.ogg', 'audio/ogg'),
    (
      'FLAC',
      _b([...ascii.encode('fLaC'), 0, 0, 0, 34]),
      'x.flac',
      'audio/flac',
    ),
    ('MP3 frame', _b([0xFF, 0xFB, 0x90, 0x64, 0, 0]), 'x.mp3', 'audio/mpeg'),
    (
      'WebM',
      _b([0x1A, 0x45, 0xDF, 0xA3, 0x42, 0x82, 0x84, ...ascii.encode('webm')]),
      'x.webm',
      'video/webm',
    ),
    (
      '7z',
      _b([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0, 4]),
      'x.7z',
      'application/x-7z-compressed',
    ),
    (
      'RAR',
      _b([...ascii.encode('Rar!'), 0x1A, 0x07, 0x01, 0]),
      'x.rar',
      'application/vnd.rar',
    ),
    (
      'tar',
      _b([...List.filled(257, 0x61), ...ascii.encode('ustar'), 0]),
      'x.tar',
      'application/x-tar',
    ),
    (
      'OLE2 .doc',
      _b([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0]),
      'old.doc',
      'application/msword',
    ),
    (
      'OLE2 .xls',
      _b([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0]),
      'old.xls',
      'application/vnd.ms-excel',
    ),
    (
      'OLE2 unknown',
      _b([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0]),
      'x.bin',
      'application/x-ole-storage',
    ),
    ('RTF', _s(r'{\rtf1\ansi Hello}'), 'x.rtf', 'application/rtf'),
    (
      'SQLite',
      _b([...ascii.encode('SQLite format 3'), 0, 16, 0]),
      'x.db',
      'application/vnd.sqlite3',
    ),
    (
      'ELF',
      _b([0x7F, 0x45, 0x4C, 0x46, 2, 1, 1, 0]),
      'run',
      'application/x-executable',
    ),
    (
      'wasm',
      _b([0, 0x61, 0x73, 0x6D, 1, 0, 0, 0]),
      'x.wasm',
      'application/wasm',
    ),
    ('WOFF2', _s('wOF2abcd'), 'x.woff2', 'font/woff2'),
    ('empty file', _b([]), 'empty.txt', 'text/plain'),
    ('JSON', _s('{"a": 1}'), 'data.json', 'application/json'),
    ('YAML', _s('a: 1\n'), 'config.yaml', 'application/yaml'),
    (
      'Serverpod model',
      _s('class: A\nfields:\n  a: int\n'),
      'a.spy.yaml',
      'application/yaml',
    ),
    ('text without extension', _s('hello world'), 'README', 'text/plain'),
    (
      'UTF-8 BOM',
      _b([0xEF, 0xBB, 0xBF, ...utf8.encode('hej')]),
      'x.txt',
      'text/plain',
    ),
    ('XML', _s('<?xml version="1.0"?><root/>'), 'data.txt', 'text/xml'),
    (
      'script tag in text',
      _s('hello <script>alert(1)</script>'),
      'x.txt',
      'text/html',
    ),
    (
      'NUL in text',
      _b([0x61, 0x62, 0, 0x63]),
      'x.txt',
      'application/octet-stream',
    ),
    // Polyglots: the first signature decides.
    (
      'GIF + HTML polyglot',
      _s('GIF89a<html><script>alert(1)</script>'),
      'x.gif',
      'image/gif',
    ),
    (
      'PNG + ZIP polyglot',
      _b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x50, 0x4B, 3, 4]),
      'x.zip',
      'image/png',
    ),
    (
      'PDF + HTML polyglot',
      _s('%PDF-1.4 <html><script>x</script>'),
      'x.html',
      'application/pdf',
    ),
    ('HTML with late %PDF', _s('<html>%PDF-1.4</html>'), 'x.pdf', 'text/html'),
    ('BM text is not BMP', _s('BMW cars are fast'), 'cars.bmp', 'text/plain'),
  ];

  group('Given byte vectors', () {
    for (final (what, bytes, name, expected) in vectors) {
      test('when sniffing $what named "$name" then it is $expected', () {
        expect(
          FileTypeSniffer.sniff(bytes, fileName: name).mimeType,
          expected,
        );
      });
    }
  });

  group('Given text files', () {
    test('when sniffing UTF-8 then the encoding is utf-8', () {
      expect(
        FileTypeSniffer.sniff(FileFixtures.bytes('notes.md')).encoding,
        'utf-8',
      );
    });

    test('when sniffing Latin-1 then it is text shown as Latin-1', () {
      expect(
        FileTypeSniffer.sniff(FileFixtures.bytes('latin1.txt')).encoding,
        'latin1',
      );
    });

    test('when sniffing UTF-16 LE with BOM then the encoding is utf-16le', () {
      expect(
        FileTypeSniffer.sniff(FileFixtures.bytes('utf16.txt')).encoding,
        'utf-16le',
      );
    });

    test(
      'when a multi-byte character is cut at the end of the sample then it is still UTF-8',
      () {
        final text = '${'a' * (FileTypeSniffer.sampleSize - 1)}é and more';

        final result = FileTypeSniffer.sniff(_s(text), fileName: 'x.txt');

        expect(result.encoding, 'utf-8');
      },
    );

    test('when sniffing binary then there is no encoding', () {
      expect(
        FileTypeSniffer.sniff(FileFixtures.bytes('image.png')).isText,
        isFalse,
      );
    });
  });

  group('Given sniffed types', () {
    final categories = <(String, String, FileTypeCategory)>[
      ('image.png', 'image.png', FileTypeCategory.image),
      ('report.pdf', 'report.pdf', FileTypeCategory.pdf),
      ('data.csv', 'data.csv', FileTypeCategory.spreadsheet),
      ('doc.docx', 'doc.docx', FileTypeCategory.document),
      ('deck.pptx', 'deck.pptx', FileTypeCategory.presentation),
      ('plain.zip', 'plain.zip', FileTypeCategory.archive),
      ('main_dart.txt', 'main.dart', FileTypeCategory.text),
      ('drawing.svg', 'drawing.svg', FileTypeCategory.text),
      ('song.mp3', 'song.mp3', FileTypeCategory.audio),
      ('program.exe', 'invoice.pdf', FileTypeCategory.other),
    ];
    for (final (fixture, name, category) in categories) {
      test('when categorizing $fixture named "$name" then it is $category', () {
        final result = FileTypeSniffer.sniff(
          FileFixtures.bytes(fixture),
          fileName: name,
        );

        expect(result.categoryFor(name), category);
      });
    }
  });

  group('Given a large ZIP whose part names are only in the tail', () {
    test('when sniffing with the tail then the OOXML type is found', () {
      final docx = FileFixtures.bytes('doc.docx');
      // A head without local headers we can walk, plus the real tail.
      final head = Uint8List.fromList([
        0x50,
        0x4B,
        0x03,
        0x04,
        ...List.filled(40, 0),
      ]);

      final result = FileTypeSniffer.sniff(
        head,
        fileName: 'x.zip',
        tail: docx,
      );

      expect(
        result.mimeType,
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    });
  });
}
