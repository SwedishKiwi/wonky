import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/files/file_names.dart';

void main() {
  group('Given uploaded file names', () {
    final cases = <(String, String)>[
      ('  report.pdf  ', 'report.pdf'),
      ('a/b\\c.txt', 'a_b_c.txt'),
      ('invoice\u202Efdp.exe', 'invoicefdp.exe'),
      ('isolate\u2066d\u2069.txt', 'isolated.txt'),
      ('tab\tand\nnewline.txt', 'tabandnewline.txt'),
      ('Ünïcödé 日本.md', 'Ünïcödé 日本.md'),
    ];
    for (final (input, expected) in cases) {
      test('when sanitizing "$input" then it is "$expected"', () {
        expect(FileNames.sanitize(input), expected);
      });
    }

    test('when the name is empty after cleaning then it is refused', () {
      expect(
        () => FileNames.sanitize(' \u202E '),
        throwsA(isA<WonkyException>()),
      );
    });

    test('when the name is longer than 255 characters then it is refused', () {
      expect(
        () => FileNames.sanitize('${'a' * 252}.txt'),
        throwsA(isA<WonkyException>()),
      );
    });

    test('when numbering a name then the number goes before the extension', () {
      expect(FileNames.numbered('photo.jpg', 1), 'photo (1).jpg');
      expect(FileNames.numbered('README', 2), 'README (2)');
      expect(FileNames.numbered('.env', 1), '.env (1)');
    });

    test(
      'when building the download header then both filename forms are set',
      () {
        expect(
          FileNames.contentDisposition('Résumé "final".pdf'),
          'attachment; filename="R_sum_ _final_.pdf"; '
          "filename*=UTF-8''R%C3%A9sum%C3%A9%20%22final%22.pdf",
        );
      },
    );
  });
}
