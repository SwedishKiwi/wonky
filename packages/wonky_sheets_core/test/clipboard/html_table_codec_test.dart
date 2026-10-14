import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/model.dart';

import 'support/clipboard_support.dart';

void main() {
  group('Given Google Sheets clipboard HTML', () {
    late ClipboardTable t;
    setUp(
      () => t = HtmlTableCodec.parse(
        readFixture('clipboard', 'google_sheets.html'),
      )!,
    );

    test('when parsing then the origin, shape and widths are detected', () {
      expect(t.origin, ClipboardOrigin.googleSheets);
      expect((t.rowCount, t.colCount), (3, 3));
      expect(t.columnWidths, [120, 100, 100]);
      expect(t.rowHeights, [21, 21, 21]);
      expect(t.merges, [const GridRect(2, 0, 2, 1)]);
    });

    test(
      'when parsing then typed values, number formats and notes are read',
      () {
        expect(t.cellAt(0, 2)!.typedValue, const BoolValue(true));
        final price = t.cellAt(1, 1)!;
        expect(price.typedValue, const NumberValue(12.5));
        expect(price.numberFormat, r'"$"#,##0.00');
        expect(t.cellAt(1, 0)!.note, 'Arabica');
      },
    );

    test(
      'when parsing then styles map to formats and the gridline rule is ignored',
      () {
        expect(t.cellAt(0, 0)!.format[FormatAttr.bold], isTrue);
        final coffee = t.cellAt(1, 0)!;
        expect(coffee.format[FormatAttr.fillColor], '#FCE8B2');
        expect(coffee.format[FormatAttr.wrap], WrapStrategy.wrap);
        expect(coffee.format[FormatAttr.borderTop], isNull);
        expect(coffee.format[FormatAttr.fontFamily], isNull);
        expect(
          t.cellAt(1, 1)!.format[FormatAttr.borderBottom],
          'medium|#FF0000',
        );
      },
    );

    test(
      'when resolving formulas at a target then R1C1 becomes relative A1',
      () {
        expect(
          t.cellAt(1, 2)!.resolve(targetRow: 1, targetCol: 2).formulaA1,
          '=B2*2',
        );
        expect(
          t.cellAt(2, 2)!.resolve(targetRow: 9, targetCol: 4).formulaA1,
          '=SUM(D9:E9)',
        );
      },
    );

    test(
      'when resolving a typed number then the general alignment is not explicit',
      () {
        final v = t.cellAt(1, 1)!.resolve(targetRow: 0, targetCol: 0);
        expect(v.content, const NumberContent(12.5));
        expect(v.format[FormatAttr.hAlign], isNull);
        expect(v.format[FormatAttr.numberFormat], r'"$"#,##0.00');
        final text = t.cellAt(0, 1)!.resolve(targetRow: 0, targetCol: 0);
        expect(text.format[FormatAttr.hAlign], HorizontalAlign.right);
      },
    );
  });

  group('Given Excel clipboard HTML with class styles', () {
    late ClipboardTable t;
    setUp(
      () => t = HtmlTableCodec.parse(readFixture('clipboard', 'excel.html'))!,
    );

    test(
      'when parsing then the hidden helper row is skipped and widths come from col',
      () {
        expect(t.origin, ClipboardOrigin.excel);
        expect((t.rowCount, t.colCount), (3, 3));
        expect(t.columnWidths, [64, 64, 64]);
      },
    );

    test('when parsing then class rules give bold, fill, italic and color', () {
      final name = t.cellAt(0, 0)!;
      expect(name.format[FormatAttr.bold], isTrue);
      expect(name.format[FormatAttr.fillColor], '#FFFF00');
      expect(name.format[FormatAttr.fontFamily], isNull);
      final wrapped = t.cellAt(1, 0)!;
      expect(wrapped.text, 'Long wrapped text');
      expect(wrapped.format[FormatAttr.italic], isTrue);
      expect(wrapped.format[FormatAttr.textColor], '#C00000');
      expect(wrapped.format[FormatAttr.wrap], WrapStrategy.wrap);
    });

    test(
      'when parsing then x:num, mso-number-format and pt borders are mapped',
      () {
        final amount = t.cellAt(1, 1)!;
        expect(amount.typedValue, const NumberValue(1234.5));
        expect(amount.numberFormat, '0.00');
        expect(amount.excelFormula, '=B1*2');
        expect(amount.format[FormatAttr.borderTop], 'thin|auto');
        expect(amount.format[FormatAttr.borderBottom], 'double|auto');
        final date = t.cellAt(1, 2)!;
        expect(date.typedValue, const NumberValue(46303));
        expect(date.numberFormat, 'preset:date');
        expect(date.format[FormatAttr.hAlign], HorizontalAlign.center);
      },
    );

    test('when parsing then x:str, bare x:num and x:bool are typed', () {
      expect(t.cellAt(2, 0)!.typedValue, const TextValue('007'));
      expect(t.cellAt(2, 1)!.typedValue, const NumberValue(42));
      expect(t.cellAt(2, 2)!.typedValue, const BoolValue(true));
    });
  });

  group('Given LibreOffice clipboard HTML', () {
    late ClipboardTable t;
    setUp(
      () => t = HtmlTableCodec.parse(
        readFixture('clipboard', 'libreoffice.html'),
      )!,
    );

    test(
      'when parsing then font tags, bgcolor, sdval and sdnum are mapped',
      () {
        expect(t.origin, ClipboardOrigin.libreOffice);
        expect(t.columnWidths, [85, 113]);
        final region = t.cellAt(0, 0)!;
        expect(region.format[FormatAttr.bold], isTrue);
        expect(region.format[FormatAttr.textColor], '#2A6099');
        expect(region.format[FormatAttr.fontSize], isNull);
        expect(t.cellAt(0, 1)!.format[FormatAttr.fillColor], '#DDE8CB');
        expect(t.cellAt(0, 1)!.format[FormatAttr.italic], isTrue);
        expect(t.cellAt(1, 1)!.typedValue, const NumberValue(1500.25));
        expect(t.cellAt(1, 1)!.numberFormat, '#,##0.00');
        expect(t.cellAt(2, 1)!.numberFormat, '0%');
      },
    );

    test('when parsing then px borders map to the nearest style', () {
      final south = t.cellAt(2, 0)!;
      expect(south.format[FormatAttr.borderTop], 'thin|auto');
      expect(south.format[FormatAttr.borderBottom], 'thick|auto');
    });
  });

  group('Given a web page with two tables', () {
    late ClipboardTable t;
    setUp(
      () =>
          t = HtmlTableCodec.parse(readFixture('clipboard', 'web_page.html'))!,
    );

    test('when parsing then the tables are stacked with a blank row', () {
      expect(t.origin, ClipboardOrigin.web);
      expect((t.rowCount, t.colCount), (6, 3));
      expect(t.texts[4], ['', '', '']);
      expect(t.cellAt(5, 0)!.text, 'Second');
    });

    test('when parsing only the first table then the second is dropped', () {
      final first = HtmlTableCodec.parse(
        readFixture('clipboard', 'web_page.html'),
        firstTableOnly: true,
      )!;
      expect(first.rowCount, 4);
    });

    test(
      'when parsing then th cells are bold and links become cell links or runs',
      () {
        expect(t.cellAt(0, 0)!.format[FormatAttr.bold], isTrue);
        expect(
          t.cellAt(1, 0)!.format[FormatAttr.linkUrl],
          'https://en.wikipedia.org/wiki/Mars',
        );
        final notes = t.cellAt(1, 2)!;
        expect(notes.text, 'Has Phobos and Deimos');
        expect(
          notes.rich!.runs.single,
          const RichRun(4, 10, {'link': 'https://example.com/phobos'}),
        );
      },
    );

    test(
      'when parsing then rowspan merges shift later cells and br breaks lines',
      () {
        expect(t.merges, [const GridRect(2, 0, 3, 0)]);
        expect(t.cellAt(2, 2)!.text, 'Line one\nLine two');
        final moons = t.cellAt(3, 1)!;
        expect(moons.text, '146');
        expect(moons.format[FormatAttr.textColor], '#008000');
        expect(moons.format[FormatAttr.hAlign], HorizontalAlign.center);
        final mixed = t.cellAt(3, 2)!;
        expect(mixed.text, 'bold and italic');
        expect(mixed.rich!.runs, [
          const RichRun(0, 4, {'bold': true}),
          const RichRun(9, 15, {'italic': true}),
        ]);
      },
    );

    test('when resolving untyped text then it is parsed like typed input', () {
      expect(
        t.cellAt(1, 1)!.resolve(targetRow: 0, targetCol: 0).content,
        const NumberContent(2),
      );
      expect(
        t.cellAt(1, 2)!.resolve(targetRow: 0, targetCol: 0).content,
        isA<RichTextContent>(),
      );
    });
  });

  group('Given messy HTML', () {
    late ClipboardTable t;
    setUp(
      () => t = HtmlTableCodec.parse(readFixture('clipboard', 'messy.html'))!,
    );

    test(
      'when parsing then entities, implicit closes and uppercase tags are handled',
      () {
        final a = t.cellAt(0, 0)!;
        expect(a.text, 'A & B <c> © € 😀 &bogus;');
        expect(a.format[FormatAttr.bold], isTrue);
        expect(a.format[FormatAttr.textColor], '#00FF00');
        expect(t.cellAt(0, 1)!.text, 'unterminated');
      },
    );

    test(
      'when parsing then nested tables flatten into the cell and spans are clamped',
      () {
        expect(t.cellAt(1, 0)!.text, 'inner1\tinner2\ninner3');
        expect(t.colCount, 1 + HtmlTableCodec.maxSpan);
        expect(
          t.merges.single,
          const GridRect(1, 1, 1, HtmlTableCodec.maxSpan),
        );
        expect(t.rowCount, 2);
      },
    );

    test('when there is no table then parsing returns null', () {
      expect(HtmlTableCodec.parse('<p>Just <b>text</b></p>'), isNull);
      expect(HtmlTableCodec.parse(''), isNull);
    });

    test(
      'when a cell exceeds 50,000 characters then it is truncated and counted',
      () {
        final big = 'x' * 60000;
        final r = HtmlTableCodec.parse(
          '<table><tr><td>$big</td></tr></table>',
        )!;
        expect(r.cellAt(0, 0)!.text.length, kMaxPastedCellChars);
        expect(r.truncatedCells, 1);
      },
    );

    test('when a wonky comment is corrupt then it is ignored', () {
      final r = HtmlTableCodec.parse(
        '<table><!--wonky:%%%--><tr><td>1</td></tr></table>',
      )!;
      expect(r.wonkyPayload, isNull);
      expect(r.origin, ClipboardOrigin.web);
    });
  });

  group('Given CSS color values', () {
    const cases = [
      ('<td style="color:#abc">x</td>', '#AABBCC'),
      ('<td style="color:rgb(255, 0, 128)">x</td>', '#FF0080'),
      ('<td style="color:rgba(0,0,255,0.5)">x</td>', '#0000FF'),
      ('<td style="color:hsl(120, 100%, 25%)">x</td>', '#008000'),
      ('<td style="color:rebeccapurple">x</td>', '#663399'),
      ('<td style="color:transparent">x</td>', null),
      ('<td style="color:#12345600">x</td>', null),
    ];
    for (final (html, expected) in cases) {
      test('when parsing $html then the text color is $expected', () {
        final t = HtmlTableCodec.parse('<table><tr>$html</tr></table>')!;
        expect(t.cellAt(0, 0)!.format[FormatAttr.textColor], expected);
      });
    }
  });
}
