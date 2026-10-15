import 'package:test/test.dart';
import 'package:wonky_core/files.dart';

void main() {
  group('Given CSV text for delimiter detection', () {
    final cases = <(String, String, String?, String)>[
      ('commas', 'a,b,c\n1,2,3\n4,5,6\n', null, ','),
      ('semicolons', 'a;b;c\n1,5;2;3\n4;5;6\n', null, ';'),
      ('tabs', 'a\tb\n1\t2\n', null, '\t'),
      ('pipes', 'a|b|c\n1|2|3\n', null, '|'),
      ('a sep= line', 'sep=;\na,b;c\n', null, ';'),
      ('no delimiter', 'just text\nmore text\n', null, ','),
      ('no delimiter in a .tsv', 'just text\n', 'data.tsv', '\t'),
      ('a tie in a .tsv', 'a,b\tc\n1,2\t3\n', 'data.tsv', '\t'),
    ];
    for (final (name, text, fileName, expected) in cases) {
      test('when the text has $name then "$expected" is detected', () {
        expect(CsvSniffer.detectDelimiter(text, fileName: fileName), expected);
      });
    }
  });

  group('Given CSV text to parse', () {
    test('when fields are quoted then quotes, delimiters and newlines are '
        'kept as text', () {
      final t = CsvSniffer.parse('name,note\r\n"Smith, J","said ""hi""\nok"\n');

      expect(t.rows, [
        ['name', 'note'],
        ['Smith, J', 'said "hi"\nok'],
      ]);
      expect(t.columnCount, 2);
      expect(t.truncated, isFalse);
    });

    test('when rows are ragged then the widest row sets the column count', () {
      final t = CsvSniffer.parse('a,b\n1,2,3\n4\n');

      expect(t.rows, [
        ['a', 'b'],
        ['1', '2', '3'],
        ['4'],
      ]);
      expect(t.columnCount, 3);
    });

    test('when the last line has no line break then it is still a row', () {
      final t = CsvSniffer.parse('a,b\n1,2');

      expect(t.rows.last, ['1', '2']);
    });

    test('when a quote is never closed then the field runs to the end', () {
      final t = CsvSniffer.parse('a,"b\nc');

      expect(t.rows, [
        ['a', 'b\nc'],
      ]);
    });

    test('when there are more rows than the limit then it is truncated', () {
      final text = List.generate(10, (i) => '$i,x').join('\n');

      final t = CsvSniffer.parse(text, maxRows: 4);

      expect(t.rows, hasLength(4));
      expect(t.truncated, isTrue);
    });

    test('when there are exactly as many rows as the limit then it is not '
        'truncated', () {
      final t = CsvSniffer.parse('1,a\n2,b\n', maxRows: 2);

      expect(t.rows, hasLength(2));
      expect(t.truncated, isFalse);
    });

    test('when the text starts with a sep= line then it is skipped', () {
      final t = CsvSniffer.parse('sep=;\na;b\n');

      expect(t.delimiter, ';');
      expect(t.rows, [
        ['a', 'b'],
      ]);
    });

    test('when values look like numbers then they stay text', () {
      final t = CsvSniffer.parse('n\n007\n1e3\n');

      expect(t.rows.skip(1).map((r) => r.single), ['007', '1e3']);
    });
  });
}
