import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/data_tools/data_tools.dart';

import '../../rules/support/core.dart';

void main() {
  group('Given rows to deduplicate', () {
    final rows = <List<CellValue>>[
      [const TextValue('Name'), const TextValue('N')],
      [const TextValue('a'), NumberValue(1)],
      [const TextValue('A'), NumberValue(1)],
      [const TextValue('a'), NumberValue(1.0)],
      [CellValue.empty, CellValue.empty],
      [const TextValue(''), CellValue.empty],
      [const TextValue('a '), NumberValue(1)],
      [const BoolValue(true), const ErrorValue(CellErrorKind.na)],
      [const BoolValue(true), const ErrorValue(CellErrorKind.na)],
      [const TextValue('TRUE'), const ErrorValue(CellErrorKind.na)],
    ];
    CellValue v(int r, int c) => rows[r][c];
    final rect = GridRect(0, 0, rows.length - 1, 1);

    test(
      'when removing duplicates with a header then first occurrences are kept (07 §12.1 equality)',
      () {
        final r = Dedupe.findDuplicates(v, rect, hasHeader: true);
        expect(r.keptRows, [1, 2, 4, 6, 7, 9]);
        expect(r.duplicateRows, [3, 5, 8]);
        expect(
          r.message,
          '3 duplicate rows found and removed. 6 unique rows remain.',
        );
      },
    );

    test(
      'when comparing only the second column then numbers compare numerically',
      () {
        final r = Dedupe.findDuplicates(v, rect, hasHeader: true, cols: [1]);
        expect(r.keptRows, [1, 4, 7]);
      },
    );

    test('when there are no duplicates then the message says so', () {
      final r = Dedupe.findDuplicates(v, const GridRect(0, 0, 1, 1));
      expect(r.message, 'No duplicate rows found.');
    });

    test('when compacting then kept rows come first and duplicates last', () {
      final r = Dedupe.findDuplicates(v, rect, hasHeader: true);
      expect(Dedupe.compactPermutation(r, 1), [0, 1, 3, 5, 6, 8, 2, 4, 7]);
    });
  });

  group('Given whitespace to trim', () {
    final cases = <(String, String)>[
      ('  hello  ', 'hello'),
      ('\t a  b \n', 'a b'),
      ('a  b', 'a b'),
      ('a b', 'a b'),
      ('line 1\nline  2', 'line 1\nline 2'),
      ('tab\tkept', 'tab\tkept'),
      ('none', 'none'),
      ('   ', ''),
    ];
    for (final (input, out) in cases) {
      test('when trimming ${input.codeUnits} then the result is "$out"', () {
        expect(WhitespaceTrimmer.trimText(input), out);
      });
    }

    test(
      'when trimming content then only text changes and rich runs re-offset',
      () {
        expect(WhitespaceTrimmer.trimContent(const NumberContent(1)), isNull);
        expect(
          WhitespaceTrimmer.trimContent(const FormulaContent('= 1')),
          isNull,
        );
        expect(WhitespaceTrimmer.trimContent(const TextContent('x')), isNull);
        expect(
          WhitespaceTrimmer.trimContent(const TextContent(' x ')),
          const TextContent('x'),
        );
        final rich = RichTextContent(
          const RichText('  bold   text ', [
            RichRun(2, 6, {'bold': true}),
            RichRun(9, 13, {'italic': true}),
          ]),
        );
        final out = WhitespaceTrimmer.trimContent(rich) as RichTextContent;
        expect(out.rich.text, 'bold text');
        expect(out.rich.runs, const [
          RichRun(0, 4, {'bold': true}),
          RichRun(5, 9, {'italic': true}),
        ]);
        expect(WhitespaceTrimmer.message(0), 'No whitespace to trim.');
        expect(
          WhitespaceTrimmer.message(2),
          'Trimmed whitespace from 2 cells.',
        );
      },
    );
  });

  group('Given text to split', () {
    test(
      'when splitting "Doe, John",42,2026-10-12 then quoting is honoured (07 §13 acceptance)',
      () {
        const t = '"Doe, John",42,2026-10-12';
        expect(SeparatorDetector.detect([t]), SplitSeparator.comma);
        expect(TextSplitter.split(t, ','), ['Doe, John', '42', '2026-10-12']);
        final parsed = TextSplitter.parsePart('42');
        expect(parsed.content, const NumberContent(42));
        expect(
          TextSplitter.parsePart('42', targetNumberFormat: '@').content,
          const TextContent('42'),
        );
      },
    );

    test(
      'when switching to semicolon then the same text splits differently',
      () {
        expect(TextSplitter.split('"Doe, John",42,2026-10-12', ';'), [
          '"Doe, John",42,2026-10-12'.replaceAll('"', ''),
        ]);
      },
    );

    final splits = <(String, String, List<String>)>[
      ('a,,b', ',', ['a', '', 'b']),
      (' a , b ', ',', ['a', 'b']),
      ('a  b', ' ', ['a', '', 'b']),
      ('a|b|c', '|', ['a', 'b', 'c']),
      ('"x ""y""";z', ';', ['x "y"', 'z']),
      ('a\tb', '\t', ['a', 'b']),
      ('1.2.3', '.', ['1', '2', '3']),
      ('abc', '::', ['abc']),
    ];
    for (final (t, sep, parts) in splits) {
      test('when splitting "$t" by "$sep" then the parts are $parts', () {
        expect(TextSplitter.split(t, sep), parts);
      });
    }

    final detect = <(List<String>, SplitSeparator?)>[
      (['a;b', 'c;d', 'e,f'], SplitSeparator.semicolon),
      (['a,b;c', 'd,e;f'], SplitSeparator.comma),
      (['a b c', 'd e f'], SplitSeparator.space),
      (['a\tb', 'c\td'], SplitSeparator.tab),
      (['a|b,c,d', 'e|f,g'], SplitSeparator.pipe),
      (['abc', 'def'], null),
      ([], null),
    ];
    for (final (texts, sep) in detect) {
      test(
        'when detecting the separator of $texts then it is ${sep?.name}',
        () {
          expect(SeparatorDetector.detect(texts), sep);
        },
      );
    }

    test('when splitting a column then the maximum part count is reported', () {
      final (parts, max) = TextSplitter.splitColumn([
        'a,b',
        null,
        'c,d,e',
      ], ',');
      expect(max, 3);
      expect(parts[1], isEmpty);
    });
  });

  group('Given more values to compare (07 §12.1)', () {
    test(
      'when errors, booleans and blanks repeat then they are duplicates',
      () {
        final rows = <CellValue>[
          const ErrorValue(CellErrorKind.na),
          const ErrorValue(CellErrorKind.na),
          const ErrorValue(CellErrorKind.div0),
          const BoolValue(true),
          const BoolValue(true),
          CellValue.empty,
          const TextValue(''),
          NumberValue(0),
          NumberValue(-0.0),
        ];
        final r = Dedupe.findDuplicates(
          (row, col) => rows[row],
          GridRect(0, 0, rows.length - 1, 0),
        );
        expect(r.keptRows, [0, 2, 3, 5, 7]);
        expect(r.duplicateRows, [1, 4, 6, 8]);
        expect(Dedupe.sameValue(NumberValue(1), const TextValue('1')), isFalse);
      },
    );

    test('when a header row is excluded then it is never compared', () {
      final rows = <CellValue>[
        const TextValue('x'),
        const TextValue('x'),
        const TextValue('x'),
      ];
      final r = Dedupe.findDuplicates(
        (row, col) => rows[row],
        const GridRect(0, 0, 2, 0),
        hasHeader: true,
      );
      expect(r.keptRows, [1]);
      expect(r.duplicateRows, [2]);
      expect(r.dataRowCount, 2);
      expect(Dedupe.compactPermutation(r, 1), [0, 1]);
    });
  });

  group('Given rich text with whitespace (07 §12.2)', () {
    test('when trimming then the runs follow the text', () {
      const rich = RichText('  ab   cd ', [
        RichRun(2, 4, {RichRunKeys.bold: true}),
        RichRun(7, 9, {RichRunKeys.italic: true}),
      ]);
      final out = WhitespaceTrimmer.trimContent(const RichTextContent(rich));
      expect(out, isA<RichTextContent>());
      final r = (out! as RichTextContent).rich;
      expect(r.text, 'ab cd');
      expect(r.runs, const [
        RichRun(0, 2, {RichRunKeys.bold: true}),
        RichRun(3, 5, {RichRunKeys.italic: true}),
      ]);
    });

    test('when the content is not text then it is untouched', () {
      expect(WhitespaceTrimmer.trimContent(const NumberContent(1)), isNull);
      expect(
        WhitespaceTrimmer.trimContent(const FormulaContent('= 1 ')),
        isNull,
      );
      expect(WhitespaceTrimmer.trimContent(null), isNull);
    });
  });

  group('Given randomize range', () {
    test(
      'when shuffling with a seeded random then the result is a deterministic permutation',
      () {
        final a = RowShuffle.permutation(10, Random(42));
        final b = RowShuffle.permutation(10, Random(42));
        expect(a, b);
        expect(a.toSet(), {for (var i = 0; i < 10; i++) i});
        expect(RowShuffle.permutation(0, Random(1)), isEmpty);
      },
    );
  });
}
