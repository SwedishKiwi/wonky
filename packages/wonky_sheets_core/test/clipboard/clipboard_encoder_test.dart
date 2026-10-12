import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/clipboard/clipboard.dart';

import 'support/clipboard_support.dart';

void main() {
  group('Given a 3×3 range with a formula, bold text and a merge', () {
    late WorkbookBuilder b;
    late WorkbookModel m;
    late ClipboardContent content;
    setUp(() {
      b = WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 5);
      b
        ..value('A1', 1)
        ..value('A2', 2)
        ..set('A3', '=SUM(A1:A2)', format: {FormatAttr.bold: true})
        ..value('B1', 'Hello', format: {FormatAttr.bold: true, FormatAttr.textColor: '#FF0000'})
        ..value('C1', 'x\ty')
        ..value('B2', 'Merged', format: {FormatAttr.fillColor: '#FCE8B2'});
      addMerge(b, 'Sheet1', 'B2:C3');
      m = b.build();
      final range = m.parseA1('A1:C3');
      content = ClipboardEncoder.copy(
        m,
        range,
        sourceWith(m, {'A3': 3}),
        clipId: 'clip-1',
        hooks: const IdentityFormulaHooks(),
      );
    });

    test('when copying then the TSV holds the displayed values with quoting', () {
      expect(content.tsv, '1\tHello\t"x\ty"\n2\tMerged\t\n3\t\t');
    });

    test('when copying then the HTML carries styles, merges and Google attributes', () {
      final html = content.html;
      expect(html, contains('data-wonky-clip="clip-1"'));
      expect(html, contains('<!--wonky:'));
      expect(html, contains('colspan="2" rowspan="2"'));
      expect(html, contains('data-sheets-formula="=SUM(R[-2]C:R[-1]C)"'));
      expect(html, contains('data-sheets-value="{&quot;1&quot;:3,&quot;3&quot;:3}"'));
      expect(html, contains('data-sheets-value="{&quot;1&quot;:2,&quot;2&quot;:&quot;Hello&quot;}"'));
      expect(html, contains('font-weight:bold'));
      expect(html, contains('color:#FF0000'));
      expect(html, contains('background-color:#FCE8B2'));
      expect(html, contains('<col width="100"/>'));
      expect(content.payloadEmbedded, isTrue);
    });

    test('when copying then the payload holds stored content, values and the merge', () {
      final p = content.payload;
      expect(p.rowCount, 3);
      expect(p.colCount, 3);
      expect(p.cellAt(2, 0)!.content, '=SUM(A1:A2)');
      expect(p.cellAt(2, 0)!.value, const NumberValue(3));
      expect(p.cellAt(2, 0)!.formulaA1, '=SUM(A1:A2)');
      expect(p.cellAt(0, 1)!.format[FormatAttr.bold], isTrue);
      expect(p.merges, [const GridRect(1, 1, 2, 2)]);
      expect(p.sourceRange.r1, b.rowId(0));
    });

    test('when parsing the copied HTML then values, bold, merge and formula are restored', () {
      final table = HtmlTableCodec.parse(content.html)!;
      expect(table.origin, ClipboardOrigin.wonky);
      expect(table.wonkyClipId, 'clip-1');
      expect(table.wonkyPayload!.encodeJson(), content.payload.encodeJson());
      expect(table.rowCount, 3);
      expect(table.colCount, 3);
      expect(table.merges, [const GridRect(1, 1, 2, 2)]);
      expect(table.cellAt(0, 0)!.typedValue, const NumberValue(1));
      expect(table.cellAt(0, 1)!.text, 'Hello');
      expect(table.cellAt(0, 1)!.format[FormatAttr.bold], isTrue);
      expect(table.cellAt(0, 1)!.format[FormatAttr.textColor], '#FF0000');
      expect(table.cellAt(0, 2)!.text, 'x\ty');
      expect(table.cellAt(1, 1)!.format[FormatAttr.fillColor], '#FCE8B2');
      expect(table.cellAt(1, 2), isNull);
      final formula = table.cellAt(2, 0)!;
      expect(formula.formulaR1C1, '=SUM(R[-2]C:R[-1]C)');
      expect(formula.resolve(targetRow: 5, targetCol: 2).formulaA1, '=SUM(C4:C5)');
      expect(formula.format[FormatAttr.bold], isTrue);
    });

    test('when pasting the 3×3 copy into a 6×6 selection then it tiles four times', () {
      const selection = GridRect(0, 0, 5, 5);
      expect(PasteTiling.target(3, 3, selection), selection);
      expect(PasteTiling.tiles(3, 3, selection), (2, 2));
    });
  });

  group('Given a range with a hidden row', () {
    late WorkbookModel m;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 5, cols: 3);
      b.values('A1', [
        ['a', 'b'],
        ['hidden', 'x'],
        ['c', 'd'],
      ]);
      m = b.build();
      final rowId = b.rowId(1);
      final before = m.sheets.single.rowRecords[rowId]!.toColumns();
      m.applyChanges([
        RowChange.update(SheetsTables.sheetRow, rowId, {Cols.hidden: false}, {
          ...before,
          Cols.hidden: true,
        }),
      ]);
    });

    test('when copying then only visible rows are included', () {
      final c = ClipboardEncoder.copy(
        m,
        m.parseA1('A1:B3'),
        ModelCellSource(m),
        clipId: 'c',
      );
      expect(c.tsv, 'a\tb\nc\td');
      expect(c.payload.rowIndices, [0, 2]);
      expect(c.html, isNot(contains('>hidden<')));
    });

    test('when copying whole columns then the copy stops at the used range', () {
      final c = ClipboardEncoder.copy(m, m.parseA1('A:B'), ModelCellSource(m), clipId: 'c');
      expect(c.payload.rowIndices, [0, 2]);
    });
  });

  group('Given cells with rich text, a link and HTML-special characters', () {
    late ClipboardContent c;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 3, cols: 3);
      b
        ..set(
          'A1',
          'r:{"t":"Total <EUR>","runs":[{"s":0,"e":5,"f":{"bold":true}}]}',
        )
        ..value('B1', 'Docs', format: {FormatAttr.linkUrl: 'https://example.com/?a=1&b=2'})
        ..value('C1', 'evil', format: {FormatAttr.linkUrl: 'javascript:alert(1)'});
      final m = b.build();
      c = ClipboardEncoder.copy(m, m.parseA1('A1:C1'), ModelCellSource(m), clipId: 'c');
    });

    test('when copying then text is escaped and runs become spans', () {
      expect(c.html, contains('<span style="font-weight:bold;">Total</span> &lt;EUR&gt;'));
      expect(c.html, contains('<a href="https://example.com/?a=1&amp;b=2">Docs</a>'));
      expect(c.html, isNot(contains('javascript:')));
    });

    test('when parsing it back then the partial bold stays a run and the link is the cell link', () {
      final t = HtmlTableCodec.parse(c.html)!;
      final a1 = t.cellAt(0, 0)!;
      expect(a1.text, 'Total <EUR>');
      expect(a1.rich!.runs.single, const RichRun(0, 5, {'bold': true}));
      expect(a1.format[FormatAttr.bold], isNull);
      expect(t.cellAt(0, 1)!.format[FormatAttr.linkUrl], 'https://example.com/?a=1&b=2');
    });
  });
}
