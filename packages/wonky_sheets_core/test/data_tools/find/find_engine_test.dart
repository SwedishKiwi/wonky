import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/data_tools/data_tools.dart';

import '../../rules/support/core.dart';

const kCur = r'"$"#,##0.00';
const display = FunctionDisplayText(_fmt);
String _fmt(CellValue v, String? f) {
  if (v is NumberValue && f == kCur) return '\$${v.number.toStringAsFixed(2)}';
  if (v is NumberValue && f == 'date') return '2026-10-12';
  return ValueText.automatic(v);
}

void main() {
  late WorkbookBuilder b;
  late String s1;
  late String s2;
  setUp(() {
    b = WorkbookBuilder();
    s1 = b.sheet('Sheet1', rows: 10, cols: 4);
    b.values('A1', [
      ['East', 'Northeast'],
      ['west', 'EAST'],
      [100, '12-34'],
    ]);
    b.set('C1', 'n:1234.5', format: {FormatAttr.numberFormat: kCur});
    b.set('D1', '=SUM(A3)', format: {FormatAttr.linkUrl: 'https://east.example'});
    s2 = b.sheet('Sheet2', rows: 5, cols: 2);
    b.value('A1', 'east coast');
    b.sheet('Hidden', rows: 5, cols: 2, hidden: true);
    b.value('A1', 'east');
  });

  FindEngine engine(WorkbookModel m) => FindEngine(m, CellTextReader(ModelCellSource(m), display));

  group('Given the find query', () {
    test('when the regex is invalid then compiling throws a pattern error', () {
      expect(() => const FindQuery('(', regex: true).compile(), throwsA(isA<FindPatternException>()));
    });

    final expand = <(String, String, String, String)>[
      (r'(\d+)-(\d+)', r'$2-$1', '12-34', '34-12'),
      (r'(\d+)', r'[$&]', 'a1b22', 'a[1]b[22]'),
      (r'x', r'$$', 'axb', r'a$b'),
      (r'(a)', r'$9', 'a', r'$9'),
      (r'(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)(k)', r'$11$10$1', 'abcdefghijk', 'kja'),
      (r'(a)', r'$10', 'a', 'a0'),
    ];
    for (final (p, r, input, out) in expand) {
      test('when replacing /$p/ with "$r" in "$input" then the result is "$out"', () {
        expect(FindQuery(p, regex: true).compile().replaceAll(input, r).$1, out);
      });
    }

    test('when not in regex mode then the replacement is literal and special characters are escaped', () {
      final m = const FindQuery('a.b').compile();
      expect(m.matches('axb'), isFalse);
      expect(m.replaceAll('a.b a.b', r'$1').$1, r'$1 $1');
    });
  });

  group('Given a workbook with text in several sheets', () {
    test('when searching "east" then East and Northeast match case-insensitively', () {
      final r = engine(b.build()).find(FindQuery('east', sheetId: s1), startSheetId: s1);
      expect([for (final x in r.matches) CellPos(x.row, x.col).a1], ['A1', 'B1', 'B2']);
    });

    test('when matching the entire cell then only exact cells match', () {
      final r = engine(b.build()).find(FindQuery('east', entireCell: true, sheetId: s1), startSheetId: s1);
      expect([for (final x in r.matches) CellPos(x.row, x.col).a1], ['A1', 'B2']);
    });

    test('when matching case then only exact case matches', () {
      final r = engine(b.build()).find(FindQuery('East', matchCase: true, sheetId: s1), startSheetId: s1);
      expect([for (final x in r.matches) CellPos(x.row, x.col).a1], ['A1']);
    });

    test('when starting after a cell then the order wraps row-major', () {
      final r = engine(b.build()).find(FindQuery('east', sheetId: s1), startSheetId: s1, startRow: 0, startCol: 1);
      expect([for (final x in r.matches) CellPos(x.row, x.col).a1], ['B2', 'A1', 'B1']);
    });

    test('when searching all sheets then sheet order continues and hidden sheets are skipped', () {
      final r = engine(b.build()).find(const FindQuery('east', scope: FindScope.allSheets), startSheetId: s2);
      expect([for (final x in r.matches) x.sheetId], [s2, s1, s1, s1]);
    });

    test('when searching a range then only cells inside match', () {
      final r = engine(b.build()).find(
        FindQuery('east', scope: FindScope.range, sheetId: s1, range: const GridRect(0, 1, 1, 1)),
        startSheetId: s1,
      );
      expect(r.matches, hasLength(2));
    });

    test('when searching formulas then the formula text matches', () {
      final m = b.build();
      expect(engine(m).find(FindQuery('SUM', sheetId: s1), startSheetId: s1).matches, isEmpty);
      final r = engine(m).find(FindQuery('SUM', searchFormulas: true, sheetId: s1), startSheetId: s1);
      expect(r.matches.single.kind, FindMatchKind.formula);
    });

    test('when searching links then link URLs match', () {
      final r = engine(b.build()).find(FindQuery('example', searchLinks: true, sheetId: s1), startSheetId: s1);
      expect(r.matches.single, FindMatch(s1, 0, 3, FindMatchKind.link));
    });

    test('when the cap is reached then the result is capped', () {
      final r = engine(b.build()).find(FindQuery('e', sheetId: s1), startSheetId: s1, cap: 2);
      expect((r.matches.length, r.capped), (2, true));
    });

    test('when a row is hidden then navigation skips it but replace-all keeps it', () {
      final m = b.build();
      m.sheets.first.rows.setHiddenLayer(HiddenLayers.filter, {b.rowId(1, sheet: 'Sheet1')});
      final e = engine(m);
      expect(e.find(FindQuery('east', sheetId: s1), startSheetId: s1, skipHidden: true).matches, hasLength(2));
      final all = e.find(FindQuery('east', sheetId: s1), startSheetId: s1);
      expect(all.hiddenRowCount, 1);
    });

    test('when overlay cells are given then they are found but not replaced', () {
      final m = b.build();
      final e = FindEngine(m, CellTextReader(ModelCellSource(m, computed: (s, r, c) => r == 5 && c == 0 ? const FText('east') : null), display),
          overlayCells: (s) => s == s1 ? const [CellPos(5, 0)] : const []);
      final q = FindQuery('east', sheetId: s1);
      final r = e.find(q, startSheetId: s1);
      expect(r.matches.last.isOverlay, isTrue);
      final plan = ReplaceEngine(e).plan(q, 'x', r.matches);
      expect(plan.skipped.single.reason, ReplaceSkipReason.overlay);
    });
  });

  group('Given replacements', () {
    test('when replacing 1 with 2 in 100 then the edit text becomes 200 for re-parsing', () {
      final m = b.build();
      final e = engine(m);
      const q = FindQuery('1', entireCell: false);
      final matches = e.find(FindQuery('100', sheetId: s1), startSheetId: s1).matches;
      final plan = ReplaceEngine(e).plan(q, '2', matches);
      expect(plan.replacements.single.newEditText, '200');
    });

    test('when the match exists only in the display text then the cell is skipped', () {
      final e = engine(b.build());
      final q = FindQuery(r'$', sheetId: s1);
      final matches = e.find(q, startSheetId: s1).matches;
      expect(matches.single.col, 2);
      final plan = ReplaceEngine(e).plan(q, 'EUR', matches);
      expect(plan.replacements, isEmpty);
      expect(plan.skipped.single.reason, ReplaceSkipReason.displayOnly);
    });

    test('when replacing with a regex then parts swap', () {
      final e = engine(b.build());
      final q = FindQuery(r'(\d+)-(\d+)', regex: true, sheetId: s1);
      final plan = ReplaceEngine(e).plan(q, r'$2-$1', e.find(q, startSheetId: s1).matches);
      expect(plan.replacements.single.newEditText, '34-12');
      expect(plan.instanceCount, 1);
    });

    test('when replacing in formulas then the A1 text is rewritten', () {
      final e = engine(b.build());
      final q = FindQuery('SUM', searchFormulas: true, sheetId: s1);
      final plan = ReplaceEngine(e).plan(q, 'AVERAGE', e.find(q, startSheetId: s1).matches);
      expect(plan.replacements.single.newFormulaA1, '=AVERAGE(A3)');
    });

    test('when a cell is protected then it is skipped and counted', () {
      final e = engine(b.build());
      final q = FindQuery('east', sheetId: s1);
      final plan = ReplaceEngine(e).plan(q, 'x', e.find(q, startSheetId: s1).matches, canEdit: (s, r, c) => c != 0);
      expect(plan.protectedCount, 1);
      expect(plan.replacements.map((r) => r.newEditText), ['Northx', 'x']);
    });

    test('when replacing in rich text then runs are re-offset', () {
      b.use('Sheet2');
      b.set('B1', RichTextContent(const RichText('hello east world', [RichRun(11, 16, {'bold': true})])).encode());
      final e = engine(b.build());
      final q = FindQuery('east', sheetId: s2);
      final matches = e.find(q, startSheetId: s2).matches.where((x) => x.col == 1);
      final r = ReplaceEngine(e).plan(q, 'EAST COAST', matches).replacements.single;
      expect(r.newRichText!.text, 'hello EAST COAST world');
      expect(r.newRichText!.runs.single, const RichRun(17, 22, {'bold': true}));
    });

    test('when computing edit texts then numbers use the Automatic form and dates their display', () {
      expect(ReplaceEngine.editText(NumberValue(1234.5), kCur, r'$1,234.50'), '1234.5');
      expect(ReplaceEngine.editText(NumberValue(46307), 'yyyy-mm-dd', '2026-10-12'), '2026-10-12');
      expect(ReplaceEngine.editText(const BoolValue(true), null, 'TRUE'), 'TRUE');
      expect(ReplaceEngine.editText(NumberValue(1.5), null, '1,5', decimal: ','), '1,5');
    });
  });
}
