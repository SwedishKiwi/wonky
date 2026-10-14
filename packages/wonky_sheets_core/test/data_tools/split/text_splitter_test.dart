import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/data_tools/data_tools.dart';

import '../../rules/support/core.dart';

void main() {
  group('Given texts to split (07 §13)', () {
    final cases = <(String, String, List<String>)>[
      ('a,', ',', ['a', '']),
      (',a', ',', ['', 'a']),
      ('  "a, b" , c', ',', ['a, b', 'c']),
      ('"unterminated, x', ',', ['unterminated, x']),
      ('a"b,c', ',', ['a"b', 'c']),
      ('x;;y', ';', ['x', '', 'y']),
      ('a::b::c', '::', ['a', 'b', 'c']),
      ('"a,b"', '|', ['"a,b"']),
      (' lead', ' ', ['', 'lead']),
    ];
    for (final (text, sep, parts) in cases) {
      test('when splitting "$text" by "$sep" then the parts are $parts', () {
        expect(TextSplitter.split(text, sep), parts);
      });
    }

    test('when an empty separator is given then the text stays whole', () {
      expect(TextSplitter.split('a,b', ''), ['a,b']);
    });

    test('when counting separators then quoted ones are ignored', () {
      expect(TextSplitter.countSeparators('"a,b",c', ',', quoting: true), 1);
      expect(TextSplitter.countSeparators('"a,b",c', ','), 2);
    });
  });

  group('Given separator detection', () {
    test(
      'when two separators occur in every cell then the most consistent wins',
      () {
        expect(
          SeparatorDetector.detect(['a;b|c|d', 'e;f', 'g;h|i']),
          SplitSeparator.semicolon,
        );
      },
    );

    test('when candidates tie then the priority order decides', () {
      expect(SeparatorDetector.detect(['1.5,2']), SplitSeparator.comma);
      expect(SeparatorDetector.detect(['a b|c']), SplitSeparator.pipe);
    });

    test('when only blank texts are given then nothing is detected', () {
      expect(SeparatorDetector.detect(['', '   ']), isNull);
    });
  });

  group('Given parts parsed like typed input', () {
    test('when the locale uses a decimal comma then numbers follow it', () {
      expect(
        TextSplitter.parsePart('1,5', locale: 'de_DE').content,
        const NumberContent(1.5),
      );
    });

    test('when the part is a percentage then a format is suggested', () {
      final p = TextSplitter.parsePart('5%');
      expect(p.content, const NumberContent(0.05));
      expect(p.autoNumberFormat, isNotNull);
    });

    test('when the part is empty then nothing is written', () {
      expect(TextSplitter.parsePart('').content, isNull);
    });
  });
}
