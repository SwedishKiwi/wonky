import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/files.dart';
import 'package:wonky_drive/features/preview/preview_cache.dart';
import 'package:wonky_drive/features/preview/preview_content.dart';

import '../../support/preview_fakes.dart';

void main() {
  final api = FakePreviewApi();
  DriveItemView file(String name, String mime, FileCategory category) =>
      api.addFile(name, mimeType: mime, category: category);

  group('Given uploaded files of every kind', () {
    final cases = <(String, String, FileCategory, PreviewViewer, String?)>[
      (
        'holiday.jpg',
        'image/jpeg',
        FileCategory.image,
        PreviewViewer.image,
        null,
      ),
      ('anim.gif', 'image/gif', FileCategory.image, PreviewViewer.image, null),
      (
        'photo.heic',
        'image/heic',
        FileCategory.image,
        PreviewViewer.unsupported,
        null,
      ),
      // No PDF previews in v2 (Drive 02 §6.3): the *Download* card.
      (
        'report.pdf',
        'application/pdf',
        FileCategory.pdf,
        PreviewViewer.unsupported,
        null,
      ),
      (
        'main.dart',
        'text/x-dart',
        FileCategory.text,
        PreviewViewer.text,
        'dart',
      ),
      ('notes.txt', 'text/plain', FileCategory.text, PreviewViewer.text, null),
      (
        'model.spy.yaml',
        'application/yaml',
        FileCategory.text,
        PreviewViewer.text,
        'serverpod',
      ),
      (
        'data.csv',
        'text/csv',
        FileCategory.spreadsheet,
        PreviewViewer.csv,
        null,
      ),
      (
        'data.tsv',
        'text/tab-separated-values',
        FileCategory.spreadsheet,
        PreviewViewer.csv,
        null,
      ),
      ('page.html', 'text/html', FileCategory.text, PreviewViewer.text, 'html'),
      (
        'logo.svg',
        'image/svg+xml',
        FileCategory.text,
        PreviewViewer.text,
        null,
      ),
      // A .jpg that is really HTML (AC-D2.4): source text, never rendered.
      ('cat.jpg', 'text/html', FileCategory.text, PreviewViewer.text, 'html'),
      // A .png that is really a PDF is not shown as an image.
      (
        'scan.png',
        'application/pdf',
        FileCategory.pdf,
        PreviewViewer.unsupported,
        null,
      ),
      (
        'song.mp3',
        'audio/mpeg',
        FileCategory.audio,
        PreviewViewer.unsupported,
        null,
      ),
      (
        'clip.mp4',
        'video/mp4',
        FileCategory.video,
        PreviewViewer.unsupported,
        null,
      ),
      (
        'backup.zip',
        'application/zip',
        FileCategory.archive,
        PreviewViewer.unsupported,
        null,
      ),
      (
        'notes.txt',
        FileTypes.octetStream,
        FileCategory.other,
        PreviewViewer.unsupported,
        null,
      ),
    ];
    for (final (name, mime, cat, viewer, lang) in cases) {
      test('when previewing "$name" ($mime) then the ${viewer.name} viewer '
          'is used', () {
        final t = PreviewType.of(file(name, mime, cat));

        expect(t.viewer, viewer);
        expect(t.language, lang);
      });
    }

    test('when a file is a CSV then Open with offers Wonky Sheets', () {
      final t = PreviewType.of(
        file('data.csv', 'text/csv', FileCategory.spreadsheet),
      );

      expect(t.convertTarget, ConvertTarget.sheets);
    });

    test('when a .docx is really binary garbage then Open with is still '
        'offered for documents', () {
      final t = PreviewType.of(
        file(
          'letter.docx',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          FileCategory.document,
        ),
      );

      expect(t.convertTarget, ConvertTarget.write);
      expect(t.viewer, PreviewViewer.unsupported);
    });

    test('when a .csv name hides a PDF then Open with is not offered', () {
      final t = PreviewType.of(
        file('fake.csv', 'application/pdf', FileCategory.pdf),
      );

      expect(t.convertTarget, isNull);
    });
  });

  group('Given bytes of a text file', () {
    test('when they are UTF-8 then they decode with the line count', () {
      final t = TextPreview.decode(PreviewFixtures.dart)!;

      expect(t.text, startsWith("import 'dart:math';"));
      expect(t.latin1, isFalse);
      expect(t.truncated, isFalse);
      expect(t.lineCount, 4);
    });

    test('when they are Latin-1 then they decode with the notice flag', () {
      final t = TextPreview.decode(PreviewFixtures.latin1Text)!;

      expect(t.text, 'café\nnaïve');
      expect(t.latin1, isTrue);
    });

    test('when they start with a UTF-16 BOM then they decode as UTF-16', () {
      final bytes = Uint8List.fromList([0xff, 0xfe, 0x68, 0, 0x69, 0]);

      expect(TextPreview.decode(bytes)!.text, 'hi');
    });

    test('when they start with a UTF-8 BOM then the BOM is dropped', () {
      final bytes = Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode('x')]);

      expect(TextPreview.decode(bytes)!.text, 'x');
    });

    test('when they are binary then nothing is decoded', () {
      expect(TextPreview.decode(PreviewFixtures.binaryText), isNull);
    });

    test('when they are longer than the limit then the text is cut at a '
        'character boundary and flagged', () {
      final bytes = Uint8List.fromList(utf8.encode('aé' * 10));

      final t = TextPreview.decode(bytes, limit: 5)!;

      expect(t.truncated, isTrue);
      expect(t.latin1, isFalse);
      expect(t.text, 'aéa');
    });
  });

  group('Given the preview byte cache', () {
    test('when it is full then the least recently used entry is evicted', () {
      final cache = PreviewByteCache(maxBytes: 10)
        ..put('a', Uint8List(4))
        ..put('b', Uint8List(4));
      cache.get('a');

      cache.put('c', Uint8List(4));

      expect(cache.get('b'), isNull);
      expect(cache.get('a'), isNotNull);
      expect(cache.get('c'), isNotNull);
      expect(cache.sizeBytes, 8);
    });

    test('when an entry is larger than the cache then it is not kept', () {
      final cache = PreviewByteCache(maxBytes: 10)..put('a', Uint8List(11));

      expect(cache.get('a'), isNull);
    });
  });
}
