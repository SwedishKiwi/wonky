import 'package:test/test.dart';
import 'package:wonky_write_core/src/layout/header_footer_tokens.dart';
import 'package:wonky_write_core/src/layout/page_setup.dart';
import 'package:wonky_write_core/src/layout/pagination_engine.dart';

import '../support/property.dart';

// A page with 100pt of content height.
const geometry = PageGeometry(pageWidth: 200, pageHeight: 140, margins: EdgeInsetsPt.all(20));

BlockMetrics text(int index, int lines, {double lineHeight = 10, bool keep = false, double before = 0, double after = 0}) =>
    BlockMetrics(
      blockIndex: index,
      lineHeights: List.filled(lines, lineHeight),
      keepWithNext: keep,
      spaceBefore: before,
      spaceAfter: after,
    );

void main() {
  const engine = PaginationEngine();

  group('Given blocks that fit on one page', () {
    test('when paginating then spacing collapses to max(after, before)', () {
      final r = engine.paginate([text(0, 2, after: 8), text(1, 2, before: 5)], geometry);

      expect(r.pages.single.slices.map((s) => s.y), [0, 28]);
    });
  });

  group('Given a long paragraph', () {
    test('when it crosses the page end then it splits at line boundaries keeping 2-line widows', () {
      final r = engine.paginate([text(0, 9), text(1, 4)], geometry);

      // 9 lines fit; 4 lines of block 1: 1 line left on page 0 → moved.
      expect(r.pages[0].slices.map((s) => (s.blockIndex, s.lineFrom, s.lineTo)), [(0, 0, 9)]);
      expect(r.pages[1].slices.map((s) => (s.blockIndex, s.lineFrom, s.lineTo)), [(1, 0, 4)]);
    });

    test('when a split would leave one line at the top then widows pull a line over', () {
      final r = engine.paginate([text(0, 5), text(1, 6)], geometry);

      expect(r.pages[0].slices.last.lineTo, 4);
      expect(r.pages[1].slices.first.lineFrom, 4);
    });

    test('when a paragraph is longer than a page then it continues over several pages', () {
      final r = engine.paginate([text(0, 25)], geometry);

      expect(r.pages.length, 3);
      expect(r.pages.map((p) => p.slices.single.isContinuation), [false, true, true]);
    });
  });

  group('Given a heading at the end of a page', () {
    test('when the heading and the next block\'s first lines do not fit then the heading moves', () {
      final r = engine.paginate([text(0, 8), text(1, 1, keep: true), text(2, 5)], geometry);

      expect(r.pageOfBlock(1), 1);
      expect(r.pageOfBlock(2), 1);
    });
  });

  group('Given images, rules and page breaks', () {
    test('when an image is taller than the page then it is scaled to fit', () {
      final r = engine.paginate([
        text(0, 1),
        const BlockMetrics(blockIndex: 1, fixedHeight: 300, kind: BlockMetricsKind.image, captionHeight: 10),
      ], geometry);

      final img = r.pages[1].slices.single;
      expect(img.height, 100);
      expect(img.scale, closeTo(90 / 290, 1e-9));
    });

    test('when a rule lands at the top of a page then it has zero height', () {
      final r = engine.paginate([
        text(0, 10),
        const BlockMetrics(blockIndex: 1, fixedHeight: 5, kind: BlockMetricsKind.rule),
        text(2, 1),
      ], geometry);

      expect(r.pages[1].slices.first.height, 0);
    });

    test('when a block requests a page break then it starts a new page', () {
      final r = engine.paginate([text(0, 1), const BlockMetrics(blockIndex: 1, lineHeights: [10], pageBreakBefore: true)], geometry);

      expect(r.pages.length, 2);
    });
  });

  group('Given a long table', () {
    final table = BlockMetrics(
      blockIndex: 0,
      kind: BlockMetricsKind.table,
      rows: List.generate(15, (_) => const RowMetrics(10)),
    );

    test('when it spans pages then the header row repeats', () {
      final r = engine.paginate([table], geometry);

      expect(r.pages.map((p) => (p.slices.single.rowFrom, p.slices.single.rowTo, p.slices.single.repeatHeader)), [
        (1, 10, true),
        (10, 15, true),
      ]);
    });

    test('when a row is taller than a page then it is split per cell at line boundaries', () {
      final tall = BlockMetrics(
        blockIndex: 0,
        kind: BlockMetricsKind.table,
        rows: [
          const RowMetrics(10, cellLineHeights: [
            [10],
          ]),
          RowMetrics(200, cellLineHeights: [List.filled(20, 10)]),
        ],
      );

      final r = engine.paginate([tall], geometry);

      expect(r.pages.length, 3);
      expect(r.pages[0].slices.single.rowSplit, [(0, 9)]);
      expect(r.pages[1].slices.single.rowSplit, [(9, 18)]);
    });
  });

  propertyTest('Given random blocks when paginating then no slice overflows and every line is placed once', (
    random,
    _,
  ) {
    final blocks = [
      for (var i = 0; i < 1 + random.nextInt(30); i++)
        text(i, 1 + random.nextInt(14), keep: random.nextInt(6) == 0, before: random.nextInt(8).toDouble(), after: random.nextInt(8).toDouble()),
    ];

    final r = engine.paginate(blocks, geometry);

    final placed = <int, int>{};
    for (final p in r.pages) {
      for (final s in p.slices) {
        expect(s.y + s.height, lessThanOrEqualTo(geometry.contentHeight + 1e-9));
        placed[s.blockIndex] = (placed[s.blockIndex] ?? 0) + (s.lineTo! - s.lineFrom!);
      }
    }
    expect(placed, {for (final b in blocks) b.blockIndex: b.lineHeights!.length});
  });

  group('Given page setup JSON', () {
    test('when parsing and serializing then values round-trip', () {
      final json = {
        'v': 1,
        'layout': 'pages',
        'paper': 'a4',
        'orientation': 'landscape',
        'margins': {'top': '1in', 'right': '0.75in', 'bottom': '1in', 'left': '0.75in'},
        'header': {'enabled': true, 'left': '', 'center': '', 'right': '{title}', 'distance': '0.5in'},
        'footer': {'enabled': true, 'left': '', 'center': '{page} / {pages}', 'right': '', 'distance': '0.5in'},
        'differentFirstPage': false,
        'firstPage': {
          'header': {'enabled': false, 'left': '', 'center': '', 'right': '', 'distance': '0.5in'},
          'footer': {'enabled': false, 'left': '', 'center': '', 'right': '', 'distance': '0.5in'},
        },
        'pageNumberStart': 3,
        'pageNumberFormat': 'lowerRoman',
      };

      final p = PageSetup.fromJson(json);

      expect(p.toJson(), json);
      expect((p.pageWidthPt.round(), p.pageHeightPt.round()), (842, 595));
      expect(p.pageLabel(1), 'iv');
    });

    test('when a header distance exceeds the margin then validation fails', () {
      expect(
        () => const PageSetup().applyPatch({
          'margins': '0.25in',
          'header': {'distance': '0.5in'},
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('when the locale is en-US then Letter is the default, else A4', () {
      expect(PageSetup.defaultsFor('en-US').paper, PaperSize.letter);
      expect(PageSetup.defaultsFor('sv-SE').paper, PaperSize.a4);
    });
  });

  group('Given header/footer tokens', () {
    final ctx = TokenContext(
      title: 'Q3',
      author: 'Anna',
      now: DateTime.utc(2026, 10, 12, 9, 5),
      pageIndex: 1,
      pageCount: 4,
    );
    final cases = <(String, String)>[
      ('{title} — {page}/{pages}', 'Q3 — 2/4'),
      ('{date}', 'Oct 12, 2026'),
      ('{date:yyyy-MM-dd HH:mm}', '2026-10-12 09:05'),
      ('{{literal}} {unknown}', '{literal} {unknown}'),
      ('{author}', 'Anna'),
    ];
    for (final (template, expected) in cases) {
      test('when expanding "$template" then it is "$expected"', () {
        expect(HeaderFooterTokens.expand(template, ctx), expected);
      });
    }
  });
}
