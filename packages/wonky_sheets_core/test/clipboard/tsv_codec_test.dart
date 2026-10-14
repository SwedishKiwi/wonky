import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/clipboard/clipboard.dart';

void main() {
  group('Given rows to copy as TSV', () {
    const cases = [
      (
        [
          ['a', 'b'],
          ['c', 'd'],
        ],
        'a\tb\nc\td',
      ),
      (
        [
          ['tab\there', 'x'],
        ],
        '"tab\there"\tx',
      ),
      (
        [
          ['line1\nline2'],
        ],
        '"line1\nline2"',
      ),
      (
        [
          ['say "hi"'],
        ],
        '"say ""hi"""',
      ),
      (
        [
          ['', '', 'x'],
        ],
        '\t\tx',
      ),
      (
        [
          ['cr\rlf'],
        ],
        '"cr\rlf"',
      ),
    ];
    for (final (rows, expected) in cases) {
      test('when encoding $rows then fields are quoted only when needed', () {
        expect(TsvCodec.encode(rows), expected);
      });
    }

    test('when a CRLF line ending is requested then rows end with it', () {
      expect(
        TsvCodec.encode([
          ['a'],
          ['b'],
        ], lineEnding: '\r\n'),
        'a\r\nb',
      );
    });
  });

  group('Given TSV text to paste', () {
    const cases = [
      (
        'a\tb\nc\td',
        [
          ['a', 'b'],
          ['c', 'd'],
        ],
      ),
      (
        'a\tb\r\nc\td\r\n',
        [
          ['a', 'b'],
          ['c', 'd'],
        ],
      ),
      (
        'a\rb',
        [
          ['a'],
          ['b'],
        ],
      ),
      (
        '"x\ny"\tz',
        [
          ['x\ny', 'z'],
        ],
      ),
      (
        '"a""b"',
        [
          ['a"b'],
        ],
      ),
      (
        '"quoted"tail\tx',
        [
          ['quotedtail', 'x'],
        ],
      ),
      (
        'mid"quote\tx',
        [
          ['mid"quote', 'x'],
        ],
      ),
      (
        'a\tb\tc\nd',
        [
          ['a', 'b', 'c'],
          ['d', '', ''],
        ],
      ),
      (
        '﻿bom\tx',
        [
          ['bom', 'x'],
        ],
      ),
      (
        '\t\n',
        [
          ['', ''],
        ],
      ),
      (
        '"unterminated\tstill',
        [
          ['unterminated\tstill'],
        ],
      ),
    ];
    for (final (text, rows) in cases) {
      test(
        'when parsing ${text.replaceAll('\n', r'\n')} then the rows are $rows',
        () {
          expect(TsvCodec.parse(text), rows);
        },
      );
    }

    test('when parsing empty text then there are no rows', () {
      expect(TsvCodec.parse(''), isEmpty);
    });

    test(
      'when a field exceeds 50,000 characters then it is truncated and counted',
      () {
        final r = TsvCodec.parseWithReport('${'x' * 50001}\tok');
        expect(r.rows.single.first.length, kMaxPastedCellChars);
        expect(r.rows.single.last, 'ok');
        expect(r.truncatedCells, 1);
      },
    );

    test(
      'when one column holds comma-separated lines then splitting is suggested',
      () {
        final r = TsvCodec.parseWithReport('a,b,c\nd,e,f\ng,h,i\n\nj;k,l');
        expect(r.suggestSplit?.delimiter, ',');
        expect(r.suggestSplit?.ratio, 1);
      },
    );

    test(
      'when only some lines contain delimiters then nothing is suggested',
      () {
        expect(
          TsvCodec.parseWithReport('a,b\nc\nd\ne\nf').suggestSplit,
          isNull,
        );
      },
    );

    test('when the text has several columns then nothing is suggested', () {
      expect(TsvCodec.parseWithReport('a,b\tc').suggestSplit, isNull);
    });

    test('when semicolons dominate then the semicolon is suggested', () {
      expect(TsvCodec.parseWithReport('a;b\nc;d').suggestSplit?.delimiter, ';');
    });
  });
}
