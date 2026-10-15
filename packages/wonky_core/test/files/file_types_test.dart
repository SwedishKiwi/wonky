import 'package:test/test.dart';
import 'package:wonky_core/files.dart';

void main() {
  group('Given a sniffed MIME type', () {
    const cases = <String, FileTypeCategory>{
      'image/jpeg': FileTypeCategory.image,
      'image/png': FileTypeCategory.image,
      'image/heic': FileTypeCategory.image,
      'application/pdf': FileTypeCategory.pdf,
      'text/plain': FileTypeCategory.text,
      'text/markdown; charset=utf-8': FileTypeCategory.text,
      'application/json': FileTypeCategory.text,
      'image/svg+xml': FileTypeCategory.text,
      'text/html': FileTypeCategory.text,
      'audio/mpeg': FileTypeCategory.audio,
      'video/mp4': FileTypeCategory.video,
      'application/zip': FileTypeCategory.archive,
      'application/gzip': FileTypeCategory.archive,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
          FileTypeCategory.document,
      'application/rtf': FileTypeCategory.document,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
          FileTypeCategory.spreadsheet,
      'text/csv': FileTypeCategory.spreadsheet,
      'application/vnd.openxmlformats-officedocument.presentationml.presentation':
          FileTypeCategory.presentation,
      'application/vnd.apple.keynote': FileTypeCategory.presentation,
      'application/octet-stream': FileTypeCategory.other,
    };
    for (final c in cases.entries) {
      test('when it is ${c.key} then the category is ${c.value.name}', () {
        expect(FileTypes.categoryOf(c.key), c.value);
      });
    }

    test('when every category is listed then each one is reachable', () {
      final reached = cases.values.toSet();
      expect(reached, containsAll(FileTypeCategory.values));
    });
  });

  group('Given a generic type with a file name', () {
    test('when text/plain is named .csv then it is a spreadsheet', () {
      expect(
        FileTypes.categoryOf('text/plain', fileName: 'data.CSV'),
        FileTypeCategory.spreadsheet,
      );
    });

    test('when text/plain is named .dart then it stays text', () {
      expect(
        FileTypes.categoryOf('text/plain', fileName: 'main.dart'),
        FileTypeCategory.text,
      );
    });

    test('when octet-stream is named .docx then it is a document', () {
      expect(
        FileTypes.categoryOf(FileTypes.octetStream, fileName: 'a.docx'),
        FileTypeCategory.document,
      );
    });

    test('when octet-stream is named .txt then it does not become text', () {
      expect(
        FileTypes.categoryOf(FileTypes.octetStream, fileName: 'a.txt'),
        FileTypeCategory.other,
      );
    });

    test('when text/plain is named .png then it does not become an image', () {
      expect(
        FileTypes.categoryOf('text/plain', fileName: 'fake.png'),
        FileTypeCategory.text,
      );
    });

    test('when a binary signature was sniffed then the name is ignored', () {
      expect(
        FileTypes.categoryOf('application/pdf', fileName: 'photo.png'),
        FileTypeCategory.pdf,
      );
    });
  });

  group('Given file names', () {
    test('when taking extensions then compound and dot files work', () {
      expect(FileTypes.extensionOf('model.spy.yaml'), 'spy.yaml');
      expect(FileTypes.extensionOf('backup.TAR.GZ'), 'tar.gz');
      expect(FileTypes.extensionOf('dir/Report.PDF'), 'pdf');
      expect(FileTypes.extensionOf('.gitignore'), 'gitignore');
      expect(FileTypes.extensionOf('Dockerfile'), 'dockerfile');
      expect(FileTypes.extensionOf('README'), '');
      expect(FileTypes.extensionOf('trailing.'), '');
    });

    test('when mapping extensions to languages then the table holds', () {
      const expected = {
        'a.dart': 'dart',
        'a.py': 'python',
        'a.js': 'javascript',
        'a.ts': 'typescript',
        'a.json': 'json',
        'a.yaml': 'yaml',
        'a.yml': 'yaml',
        'a.html': 'html',
        'a.css': 'css',
        'a.sql': 'sql',
        'a.go': 'go',
        'a.rs': 'rust',
        'a.java': 'java',
        'a.kt': 'kotlin',
        'a.swift': 'swift',
        'a.md': 'markdown',
        'user.spy.yaml': 'serverpod',
      };
      for (final e in expected.entries) {
        expect(FileTypes.languageOf(e.key), e.value, reason: e.key);
      }
      expect(FileTypes.languageOf('notes.txt'), isNull);
      for (final ext in FileTypes.languagesByExtension.keys) {
        expect(FileTypes.textExtensions, contains(ext), reason: ext);
      }
    });

    test('when asking for conversions then Write and Sheets types map', () {
      expect(FileTypes.convertTargetOf('a.csv'), ConvertTarget.sheets);
      expect(FileTypes.convertTargetOf('a.xlsx'), ConvertTarget.sheets);
      expect(FileTypes.convertTargetOf('a.docx'), ConvertTarget.write);
      expect(FileTypes.convertTargetOf('a.md'), ConvertTarget.write);
      expect(FileTypes.convertTargetOf('a.pptx'), isNull);
      expect(FileTypes.convertTargetOf('a.zip'), isNull);
      expect(FileTypes.convertibleExtensions(ConvertTarget.sheets), {
        'csv',
        'tsv',
        'xlsx',
        'xls',
        'ods',
      });
    });

    test('when checking active and renderable types then they differ', () {
      expect(FileTypes.isRenderableImage('image/png'), isTrue);
      expect(FileTypes.isRenderableImage('image/svg+xml'), isFalse);
      expect(FileTypes.isActive('text/html; charset=utf-8'), isTrue);
      expect(FileTypes.isActive('image/png'), isFalse);
    });
  });

  group('Given byte counts', () {
    test('when formatting then units follow Drive 03 §3', () {
      expect(formatStorageBytes(0), '0 bytes');
      expect(formatStorageBytes(1), '1 byte');
      expect(formatStorageBytes(512), '512 bytes');
      expect(formatStorageBytes(820 * 1024), '820 KB');
      expect(formatStorageBytes(2 * 1024 * 1024), '2.0 MB');
      expect(formatStorageBytes(12998246), '12.4 MB');
      expect(formatStorageBytes(50 * 1024 * 1024), '50.0 MB');
    });
  });
}
