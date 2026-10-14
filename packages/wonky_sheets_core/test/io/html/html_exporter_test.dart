import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

import '../print/support/print_support.dart';
import '../support/ir_corpus.dart' show kTinyPng;

void main() {
  group('Given a workbook with styles, a merge, links and a hidden sheet', () {
    late WorkbookBuilder b;
    late WorkbookModel m;
    late Map<String, String> files;
    setUp(() {
      b = WorkbookBuilder()..sheet('Budget 2026', rows: 10, cols: 5);
      b
        ..value(
          'A1',
          '<b>Item</b> & "co"',
          format: {FormatAttr.bold: true, FormatAttr.fillColor: '#FCE8B2'},
        )
        ..value('B1', 1234.5, format: {FormatAttr.numberFormat: '#,##0.00'})
        ..value(
          'C1',
          'Docs',
          format: {FormatAttr.linkUrl: 'https://x.test/?a=1&b=2'},
        )
        ..value(
          'D1',
          'Evil',
          format: {FormatAttr.linkUrl: 'javascript:alert(1)'},
        )
        ..value('A2', 'Merged')
        ..value('A4', 'Hidden row')
        ..value('A5', 'Line 1\nLine 2')
        ..value(
          'B5',
          'Bordered',
          format: {
            FormatAttr.borderBottom: 'thick|#FF0000',
            FormatAttr.italic: true,
            FormatAttr.hAlign: HorizontalAlign.center,
          },
        );
      addMergeA1(b, 'Budget 2026', 'A2:B3');
      final otherId = b.sheet('Other', rows: 5, cols: 3);
      b.value('A1', 'second');
      b.sheet('Secret', rows: 5, cols: 3, hidden: true);
      b.value('A1', 'secret');
      b
        ..use('Budget 2026')
        ..value(
          'E1',
          'Jump',
          format: {FormatAttr.linkUrl: '#sheet=$otherId&range=A1'},
        );
      addImage(b, 'Budget 2026', 'img1', row: 6, col: 1);
      m = b.build();
      hideRow(m, b, 'Budget 2026', 3);
      final raw = HtmlExporter.exportFiles(
        m,
        ModelCellSource(m),
        images: (o) => HtmlImage(Uint8List.fromList(kTinyPng), 'image/png'),
      );
      files = {
        for (final e in raw.entries)
          e.key: utf8.decode(e.value, allowMalformed: true),
      };
    });

    test('when exporting then the index links every visible sheet', () {
      expect(
        files.keys,
        containsAll(['index.html', 'Budget_2026.html', 'Other.html']),
      );
      expect(files.keys, isNot(contains('Secret.html')));
      final index = files['index.html']!;
      expect(index, contains('<a href="Budget_2026.html">Budget 2026</a>'));
      expect(index, contains('<title>Test</title>'));
    });

    test('when exporting then text is escaped', () {
      final page = files['Budget_2026.html']!;
      expect(page, contains('&lt;b&gt;Item&lt;/b&gt; &amp; &quot;co&quot;'));
      expect(page, isNot(contains('<b>Item')));
      expect(page, contains('Line 1<br/>Line 2'));
    });

    test('when exporting then merges become colspan and rowspan', () {
      expect(
        files['Budget_2026.html']!,
        contains('<td colspan="2" rowspan="2" style="'),
      );
    });

    test('when exporting then column widths and inline styles are written', () {
      final page = files['Budget_2026.html']!;
      expect(page, contains('<col style="width:100px">'));
      expect(page, contains('font-weight:bold;'));
      expect(page, contains('background-color:#FCE8B2;'));
      expect(page, contains('border-bottom:3px solid #FF0000;'));
      expect(page, contains('font-style:italic;'));
      expect(page, contains('text-align:center;'));
      expect(page, contains('>1,234.50</td>'));
      expect(page, contains('border-top:1px solid #e0e0e0;'));
    });

    test('when exporting then hidden rows are skipped', () {
      expect(files['Budget_2026.html']!, isNot(contains('Hidden row')));
    });

    test(
      'when exporting then safe links are kept and internal links point to pages',
      () {
        final page = files['Budget_2026.html']!;
        expect(
          page,
          contains('<a href="https://x.test/?a=1&amp;b=2">Docs</a>'),
        );
        expect(page, isNot(contains('javascript:')));
        expect(page, contains('<a href="Other.html">Jump</a>'));
      },
    );

    test('when exporting then images are written to resources', () {
      expect(files.keys, contains('resources/img1.png'));
      expect(
        files['Budget_2026.html']!,
        contains(
          '<img class="obj" src="resources/img1.png" alt="Picture img1"',
        ),
      );
    });

    test(
      'when exporting hidden content too then the hidden sheet and row appear',
      () {
        final all = HtmlExporter.exportFiles(
          m,
          ModelCellSource(m),
          includeHidden: true,
        );
        expect(all.keys, contains('Secret.html'));
        expect(utf8.decode(all['Budget_2026.html']!), contains('Hidden row'));
      },
    );

    test(
      'when zipping twice with a fixed time then the archives are identical',
      () {
        final t = DateTime.utc(2026, 10, 14);
        final a = HtmlExporter.export(m, ModelCellSource(m), modified: t);
        final c = HtmlExporter.export(m, ModelCellSource(m), modified: t);
        expect(a, equals(c));
        final names = [
          for (final f in ZipDecoder().decodeBytes(a).files) f.name,
        ];
        expect(
          names,
          containsAll(['index.html', 'Budget_2026.html', 'Other.html']),
        );
      },
    );
  });

  group('Given a sheet without gridlines and an empty sheet', () {
    test(
      'when exporting then no gridline borders and an empty notice are written',
      () {
        final b = WorkbookBuilder()
          ..sheet('Plain', rows: 3, cols: 3)
          ..value('A1', 'x')
          ..sheet('Empty', rows: 3, cols: 3);
        final m = b.build();
        patchSheet(m, b, 'Plain', {SheetCols.showGridlines: false});
        final files = HtmlExporter.exportFiles(m, ModelCellSource(m));
        expect(
          utf8.decode(files['Plain.html']!),
          isNot(contains('border-top:1px solid #e0e0e0;')),
        );
        expect(
          utf8.decode(files['Empty.html']!),
          contains('<p>This sheet is empty.</p>'),
        );
      },
    );
  });

  group('Given sheet names that are not file-name safe', () {
    test('when exporting then file names are sanitized and unique', () {
      final b = WorkbookBuilder()
        ..sheet('Q1/Q2', rows: 2, cols: 2)
        ..sheet('Q1 Q2', rows: 2, cols: 2)
        ..sheet('…', rows: 2, cols: 2);
      final m = b.build();
      expect(
        HtmlExporter.exportFiles(m, ModelCellSource(m)).keys,
        containsAll(['Q1_Q2.html', 'Q1_Q2-2.html', 'sheet-3.html']),
      );
    });
  });

  group('Given HTML text helpers', () {
    for (final (input, expected) in [
      ('a<b>&"\'', 'a&lt;b&gt;&amp;&quot;&#39;'),
      ('ctl\x01\x7f', 'ctl'),
      ('tab\tkept', 'tab\tkept'),
    ]) {
      test('when escaping "$input" then it reads "$expected"', () {
        expect(HtmlText.escape(input), expected);
      });
    }

    for (final (url, expected) in [
      ('https://a.test', 'https://a.test'),
      ('mailto:x@y.test', 'mailto:x@y.test'),
      ('www.a.test', 'https://www.a.test'),
      ('javascript:alert(1)', null),
      ('data:text/html,x', null),
    ]) {
      test('when checking the URL "$url" then the href is $expected', () {
        expect(HtmlText.safeUrl(url), expected);
      });
    }

    test(
      'when quoting a font family then dangerous characters are removed',
      () {
        expect(
          HtmlText.cssFontFamily('Evil";}<script>'),
          "'Evilscript',sans-serif",
        );
      },
    );
  });
}
