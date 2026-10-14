import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

import '../support/ir_corpus.dart' show kTinyPng;
import 'support/print_support.dart';

final _now = DateTime.utc(2026, 10, 14, 9, 30);

Future<String> _pdf(
  WorkbookModel m, {
  PrintJob job = const PrintJob(),
  ChartPdfDrawer? charts,
  PrintImageProvider? images,
  bool compress = false,
}) async {
  final bytes = await SheetsPdfRenderer.render(
    m,
    ModelCellSource(m),
    Paginator.paginate(m, job),
    now: _now,
    charts: charts,
    images: images,
    compress: compress,
  );
  return latin1.decode(bytes);
}

int _count(String haystack, String needle) =>
    needle.allMatches(haystack).length;

String _withoutId(String pdf) =>
    pdf.replaceAll(RegExp(r'/ID\s*\[<[0-9a-f]+><[0-9a-f]+>\]'), '/ID[]');

final class _RecordingCharts implements ChartPdfDrawer {
  final List<(String, PdfRect)> calls = [];

  @override
  void drawChart(
    PdfDocument doc,
    PdfGraphics g,
    EmbeddedObjectRecord chart,
    PdfRect bounds,
  ) => calls.add((chart.id, bounds));
}

void main() {
  group('Given a 60 × 10 number grid on Letter paper', () {
    late WorkbookBuilder b;
    late WorkbookModel m;
    setUp(() => (b, m) = numberGrid());

    test(
      'when rendering then a PDF with one page per PageSpec is produced',
      () async {
        final pdf = await _pdf(m, compress: true);
        expect(pdf, startsWith('%PDF-1.'));
        expect(pdf.trimRight(), endsWith('%%EOF'));
        expect(_count(pdf, '/Type/Page/'), 4);
        expect(pdf, contains('/Count 4'));
        expect(pdf, contains('/MediaBox[0 0 612 792]'));
      },
    );

    test(
      'when rendering twice with the same time then the bytes match except the id',
      () async {
        final a = await _pdf(m, compress: true);
        final c = await _pdf(m, compress: true);
        expect(_withoutId(a), _withoutId(c));
      },
    );

    test('when rendering then the metadata uses the injected time', () async {
      final pdf = await _pdf(m);
      expect(pdf, contains('/CreationDate(D:20261014093000Z)'));
      expect(pdf, contains('/Creator(Wonky Sheets)'));
      expect(pdf, contains('/Title(Test)'));
    });

    test(
      'when rendering then cell values and page numbers are drawn',
      () async {
        final pdf = await _pdf(m);
        expect(pdf, contains('[(5909)]TJ'));
        expect(pdf, contains('[(4)]TJ'));
      },
    );

    test(
      'when header and footer fields are set then tokens are substituted',
      () async {
        setPrintSettings(m, b, 'Sheet1', {
          'headerFooter': {
            'header': {'left': '{title} – {sheet}', 'right': '{date} {time}'},
            'footer': {'center': 'Page {page} of {pages}'},
            'flags': {'pageNumbers': false},
          },
        });
        final pdf = await _pdf(m);
        expect(pdf, contains('[(Page 3 of 4)]TJ'));
        // The en dash is WinAnsi 0x96 in the standard fonts.
        expect(pdf, contains('[(Test \x96 Sheet1)]TJ'));
        expect(pdf, contains('[(10/14/2026 9:30 AM)]TJ'));
      },
    );

    test('when gridlines are on then more lines are stroked', () async {
      final plain = await _pdf(m);
      setPrintSettings(m, b, 'Sheet1', {'gridlines': true});
      final grid = await _pdf(m);
      expect(_count(grid, 're S'), greaterThan(_count(plain, 're S') + 200));
    });

    test(
      'when headings are on then column letters and row numbers print',
      () async {
        setPrintSettings(m, b, 'Sheet1', {'headings': true});
        final pdf = await _pdf(m);
        expect(pdf, contains('[(A)]TJ'));
        expect(pdf, contains('[(F)]TJ'));
        expect(pdf, contains('[(41)]TJ'));
      },
    );
  });

  group('Given a merge split by the automatic page break', () {
    test(
      'when rendering then its content is drawn on the first part only',
      () async {
        final (_, m) = numberGrid(
          extra: (b) {
            addMergeA1(b, 'Sheet1', 'A40:A45');
            b.value('A40', 'MergedText');
          },
        );
        final pdf = await _pdf(m);
        expect(_count(pdf, '[(MergedText)]TJ'), 1);
      },
    );
  });

  group('Given formatted cells, links, a checkbox, an image and a note', () {
    late WorkbookBuilder b;
    late WorkbookModel m;
    setUp(() {
      b = WorkbookBuilder()..sheet('Sheet1', rows: 20, cols: 6);
      b
        ..value('A1', 'Bold', format: {FormatAttr.bold: true})
        ..value(
          'B1',
          'Wrapped text that is long enough to need several lines',
          format: {FormatAttr.wrap: WrapStrategy.wrap},
        )
        ..value('C1', 'Up', format: {FormatAttr.rotation: 90})
        ..value(
          'D1',
          'Site',
          format: {FormatAttr.linkUrl: 'https://example.com/'},
        )
        ..value('E1', '漢字')
        ..value(
          'A2',
          'Boxed',
          format: {
            FormatAttr.borderTop: 'double|#FF0000',
            FormatAttr.borderBottom: 'dashed|auto',
            FormatAttr.fillColor: '#FCE8B2',
          },
        )
        ..set(
          'B2',
          'r:{"t":"Total revenue","runs":[{"s":0,"e":5,"f":{"bold":true}}]}',
        )
        ..value('C2', true)
        ..set('A3', 'n:7', note: 'First note');
      addCheckboxes(b, 'Sheet1', 'C2:C2');
      addImage(b, 'Sheet1', 'img1', row: 4, col: 1);
      m = b.build();
    });

    test('when rendering then the page is drawn without errors', () async {
      final pdf = await _pdf(
        m,
        images: (o) => PrintImage(Uint8List.fromList(kTinyPng)),
      );
      expect(pdf, contains('[(Bold)]TJ'));
      expect(pdf, contains('[(Up)]TJ'));
      expect(pdf, contains('[(??)]TJ'), reason: 'CJK without a TTF font');
      expect(pdf, contains('/Subtype/Image'));
      expect(pdf, contains('/URI(https://example.com/)'));
      expect(pdf, contains('[(Total)]TJ'));
      expect(pdf, contains('[( revenue)]TJ'));
    });

    test(
      'when notes printing is on then an endnotes page lists the notes',
      () async {
        setPrintSettings(m, b, 'Sheet1', {'notes': true});
        final pdf = await _pdf(m);
        expect(_count(pdf, '/Type/Page/'), 2);
        expect(pdf, contains('[(A3: First note)]TJ'));
      },
    );
  });

  group('Given a link to a cell on another printed sheet', () {
    test(
      'when rendering the workbook then the link targets that page',
      () async {
        final b = WorkbookBuilder()
          ..sheet('One', rows: 5, cols: 3)
          ..sheet('Two', rows: 5, cols: 3)
          ..value('A1', 'target');
        final twoId = b.sheetId('Two');
        b
          ..use('One')
          ..value(
            'A1',
            'Go',
            format: {FormatAttr.linkUrl: '#sheet=$twoId&range=A1'},
          );
        final m = b.build();
        final pdf = await _pdf(
          m,
          job: const PrintJob(scope: PrintScope.workbook),
        );
        expect(pdf, contains('/S/GoTo/D(wonky-page-2)'));
      },
    );
  });

  group('Given a chart over cells and a chart sheet', () {
    test(
      'when rendering then the chart drawer gets the scaled bounds',
      () async {
        final b = WorkbookBuilder()..sheet('Sheet1', rows: 20, cols: 6);
        b.value('A1', 1);
        addImage(
          b,
          'Sheet1',
          'chart1',
          row: 2,
          col: 1,
          width: 200,
          height: 100,
          kind: 'chart',
        );
        final m = b.build();
        final charts = _RecordingCharts();
        await _pdf(m, charts: charts);
        final (id, bounds) = charts.calls.single;
        expect(id, 'chart1');
        expect(bounds.width, closeTo(150, 1e-6));
        expect(bounds.height, closeTo(75, 1e-6));
        expect(bounds.left, closeTo(50.4 + 75 + 1.5, 1e-6));
      },
    );
  });
}
