import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

List<List<String>> _parse(String text, {String delimiter = ','}) => [
  for (final r in CsvParser.parseAll(text, delimiter: delimiter)) r.fields,
];

void main() {
  group('Given RFC 4180 input', () {
    const vectors = [
      (
        'a,b,c\n1,2,3\n',
        [
          ['a', 'b', 'c'],
          ['1', '2', '3'],
        ],
      ),
      (
        '"a,b","c""d"\n',
        [
          ['a,b', 'c"d'],
        ],
      ),
      (
        '"multi\nline",x\r\ny,z',
        [
          ['multi\nline', 'x'],
          ['y', 'z'],
        ],
      ),
      (
        'a\rb\r\nc\n',
        [
          ['a'],
          ['b'],
          ['c'],
        ],
      ),
      (
        'a,,c\n,\n',
        [
          ['a', '', 'c'],
          ['', ''],
        ],
      ),
      (
        '"",x\n',
        [
          ['', 'x'],
        ],
      ),
    ];
    for (final (text, rows) in vectors) {
      test(
        'when parsing ${text.replaceAll('\n', r'\n').replaceAll('\r', r'\r')} '
        'then the fields are $rows',
        () {
          expect(_parse(text), rows);
        },
      );
    }
  });

  group('Given lenient cases', () {
    test('when a quote is inside an unquoted field then it is literal', () {
      expect(_parse('ab"c,d\n'), [
        ['ab"c', 'd'],
      ]);
    });

    test('when text follows a closing quote then it is appended', () {
      expect(_parse('"ab"c,d\n'), [
        ['abc', 'd'],
      ]);
    });

    test('when rows have different lengths then they are kept ragged', () {
      expect(_parse('a,b,c\n1\n1,2\n'), [
        ['a', 'b', 'c'],
        ['1'],
        ['1', '2'],
      ]);
    });

    test('when a line is blank then it is a record without fields', () {
      expect(_parse('a\n\nb\n'), [
        ['a'],
        <String>[],
        ['b'],
      ]);
    });

    test('when a quote is never closed then the field ends at EOF', () {
      final p = CsvParser();
      final records = [...p.feed('a,"open\nstill'), ...p.close()];
      expect(records.single.fields, ['a', 'open\nstill']);
      expect(p.unterminatedQuoteLine, 1);
    });

    test('when a field is too long then it is truncated and counted', () {
      final p = CsvParser(maxFieldLength: 5);
      final records = [...p.feed('abcdefgh,ok\n"123456789"\n'), ...p.close()];
      expect(records.first.fields, ['abcde', 'ok']);
      expect(records.last.fields, ['12345']);
      expect(p.truncatedFields, 2);
      expect(p.firstTruncatedLine, 1);
    });
  });

  group('Given chunked input', () {
    const text = 'a,"b\r\nc",""""\r\nd,e,f\r\n';
    test('when the text is fed one character at a time then the result is '
        'the same', () {
      final p = CsvParser();
      final records = <CsvRecord>[];
      for (var i = 0; i < text.length; i++) {
        records.addAll(p.feed(text[i]));
      }
      records.addAll(p.close());
      expect([for (final r in records) r.fields], _parse(text));
      expect([for (final r in records) r.line], [1, 3]);
    });
  });

  group('Given a multi-character delimiter', () {
    test('when parsing then it splits fields', () {
      expect(_parse('a::b::"c::d"\n', delimiter: '::'), [
        ['a', 'b', 'c::d'],
      ]);
    });
  });

  group('Given delimiter detection', () {
    const vectors = [
      ('a,b,c\n1,2,3\n4,5,6\n', ',', null, false),
      ('a;b;c\n1;2;3\n', ';', null, false),
      ('a\tb\n1\t2\n', '\t', null, false),
      ('a|b|c\n1|2|3\n', '|', null, false),
      ('sep=;\na,b;c\n', ';', null, false),
      ('a,b;c\n', ',', null, false),
      ('a,b;c\n', ';', null, true),
      ('single\n', '\t', 'data.tsv', false),
    ];
    for (final (sample, expected, file, comma) in vectors) {
      test('when detecting in ${sample.split('\n').first} '
          '${file == null ? '' : '($file) '}${comma ? '(decimal comma) ' : ''}'
          'then the delimiter is ${expected == '\t' ? 'tab' : expected}', () {
        expect(
          CsvDelimiterDetector.detect(
            sample,
            fileName: file,
            decimalCommaLocale: comma,
          ).delimiter,
          expected,
        );
      });
    }

    test('when a sep= line is present then its length is reported', () {
      final d = CsvDelimiterDetector.detect('sep=|\r\na|b');
      expect(d.fromSepLine, isTrue);
      expect(d.sepLineLength, 7);
    });

    test(
      'when quoted fields contain other delimiters then they are ignored',
      () {
        expect(
          CsvDelimiterDetector.detect('"a;b",c\n"d;e",f\n').delimiter,
          ',',
        );
      },
    );
  });
}
