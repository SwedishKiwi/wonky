import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

void main() {
  group('Given single-width text', () {
    test('when measuring then each character is one column', () {
      expect(CodeColumns.columnsOf('final x = 1;'), 12);
    });

    test('when splitting then every character is a grapheme', () {
      expect(CodeColumns.boundaries('abc'), [0, 1, 2, 3]);
    });
  });

  group('Given tabs', () {
    for (final (line, size, cols) in [
      ('\tx', 4, 5),
      ('ab\tx', 4, 5),
      ('abcd\tx', 4, 9),
      ('\t\tx', 2, 5),
      ('a\tb', 8, 9),
    ]) {
      test('when measuring "$line" with tab size $size then it has $cols '
          'columns', () {
        expect(CodeColumns.columnsOf(line, tabSize: size), cols);
      });
    }

    test('when expanding then tabs become spaces to the next stop', () {
      expect(CodeColumns.expandTabs('ab\tc', tabSize: 4), 'ab  c');
    });
  });

  group('Given wide characters', () {
    for (final (text, cols) in [
      ('漢字', 4),
      ('한국어', 6),
      ('ｆｕｌｌ', 8),
      ('a😀b', 4),
      ('👍🏽', 2),
      ('👨‍👩‍👧', 2),
      ('🇸🇪', 2),
      ('❤️', 2),
    ]) {
      test('when measuring "$text" then it has $cols columns', () {
        expect(CodeColumns.columnsOf(text), cols);
      });
    }

    test('when splitting a ZWJ family then it is one grapheme', () {
      const family = '👨‍👩‍👧';

      expect(CodeColumns.boundaries(family), [0, family.length]);
    });

    test('when splitting two flags then each flag is one grapheme', () {
      const flags = '🇸🇪🇫🇮';

      expect(CodeColumns.boundaries(flags), [0, 4, 8]);
    });
  });

  group('Given combining marks', () {
    test('when splitting "e" + acute then it is one grapheme of one '
        'column', () {
      const s = 'éx';

      expect(CodeColumns.boundaries(s), [0, 2, 3]);
      expect(CodeColumns.columnsOf(s), 2);
    });
  });

  test('when splitting CRLF then it is one grapheme', () {
    expect(CodeColumns.boundaries('a\r\nb'), [0, 1, 3, 4]);
  });
}
