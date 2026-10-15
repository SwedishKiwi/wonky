import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/pdf.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';

import '../../support/pdf_fixture.dart';

String _delta(List<Map<String, Object?>> ops) => jsonEncode(ops);

/// A deck of 7 slides: an ungrouped title slide, the group *Intro* (3
/// slides, one skipped), an untitled slide, the group *Details* (2 slides).
final class _Deck {
  _Deck() {
    first = b.slide(layoutKey: 'title', title: 'Welcome', notes: 'Say hello');
    intro = b.group('Intro');
    introA = b.slide(title: 'Agenda', groupId: intro);
    introB = b.slide(title: 'Skipped one', groupId: intro, skipped: true);
    introC = b.slide(title: 'Team', groupId: intro);
    untitled = b.slide(layoutKey: 'blank');
    details = b.group('Details');
    detailsA = b.slide(title: 'Numbers', groupId: details);
    detailsB = b.slide(title: 'Outlook', groupId: details);
  }

  final b = DeckBuilder(title: 'Q3 Review');
  late final String first, intro, introA, introB, introC, untitled;
  late final String details, detailsA, detailsB;

  DeckModel build({List<SlidesRow> extra = const []}) =>
      DeckModel.fromRows(b.deckId, [...b.rows, ...extra]);
}

Uint8List _png(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(200, 30, 30));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('Given a deck with groups and a skipped slide', () {
    late _Deck d;
    late DeckModel deck;
    setUp(() {
      d = _Deck();
      deck = d.build();
    });

    test('when exporting slides then there is one 960 × 540 pt page per '
        'non-skipped slide', () async {
      final (r, pdf) = await PdfFixture.render(deck, const SlidesPdfOptions());

      expect(r.pageCount, 6);
      expect(PdfFixture.pageObjects(pdf), 6);
      expect(PdfFixture.mediaBoxes(pdf).toSet(), {'0 0 960 540'});
      expect(r.warnings, isEmpty);
    });

    test(
      'when including skipped slides then the skipped slide is a page too',
      () async {
        final (r, _) = await PdfFixture.render(
          deck,
          const SlidesPdfOptions(includeSkipped: true),
        );

        expect(r.pageCount, 7);
      },
    );

    test(
      'when exporting on Letter then the pages are landscape Letter',
      () async {
        final (_, pdf) = await PdfFixture.render(
          deck,
          const SlidesPdfOptions(
            pageSize: SlidesPdfPageSize.letter,
            margins: SlidesPdfMargins.normal,
          ),
        );

        expect(PdfFixture.mediaBoxes(pdf).toSet(), {'0 0 792 612'});
      },
    );

    test('when exporting one group then only its slides are pages', () async {
      final (r, _) = await PdfFixture.render(
        deck,
        SlidesPdfOptions(groupIds: [d.details]),
      );

      expect(r.pageCount, 2);
    });

    test(
      'when exporting with bookmarks then the outline has the groups with '
      'their slides and untitled slides as "Slide n" (their slide number)',
      () async {
        final (_, pdf) = await PdfFixture.render(
          deck,
          const SlidesPdfOptions(),
        );
        final titles = PdfFixture.titles(pdf);

        expect(pdf, contains('/Outlines'));
        expect(
          titles,
          containsAllInOrder([
            'Welcome',
            'Intro',
            'Agenda',
            'Team',
            'Slide 4',
            'Details',
            'Numbers',
            'Outlook',
          ]),
        );
        expect(titles, isNot(contains('Skipped one')));
        final parents = PdfFixture.outlineParents(pdf);
        expect(parents['Agenda'], 'Intro');
        expect(parents['Team'], 'Intro');
        expect(parents['Outlook'], 'Details');
        expect(parents['Welcome'], isNull);
        expect(parents['Intro'], isNull);
      },
    );

    test('when exporting without bookmarks then there is no outline', () async {
      final (_, pdf) = await PdfFixture.render(
        deck,
        const SlidesPdfOptions(bookmarks: false),
      );

      expect(pdf, isNot(contains('/Outlines')));
    });

    test('when exporting notes pages then pages are portrait and long notes '
        'continue on a following page', () async {
      final longNotes = List.generate(
        120,
        (i) => 'Line $i of the speaker notes with a few more words.',
      ).join('\n');
      final rows = d.b.rows;
      final slideRow = rows.firstWhere(
        (r) => r.$1 == SlidesTables.slide && r.$2[SlidesCols.id] == d.first,
      );
      final patched = [
        for (final r in rows)
          identical(r, slideRow)
              ? (r.$1, {...r.$2, SlideCols.notes: deltaOf(longNotes)})
              : r,
      ];
      final notesDeck = DeckModel.fromRows(d.b.deckId, patched);

      final (r, pdf) = await PdfFixture.render(
        notesDeck,
        const SlidesPdfOptions().withLayout(
          SlidesPdfLayout.notes,
          locale: 'en-US',
        ),
      );

      expect(PdfFixture.mediaBoxes(pdf).toSet(), {'0 0 612 792'});
      expect(r.pageCount, greaterThanOrEqualTo(8));
    });

    for (final (perPage, pages) in [
      (1, 6),
      (2, 3),
      (3, 2),
      (4, 2),
      (6, 1),
      (9, 1),
    ]) {
      test('when exporting handouts with $perPage per page then 6 slides make '
          '$pages pages', () async {
        final (r, pdf) = await PdfFixture.render(
          deck,
          SlidesPdfOptions(
            handoutsPerPage: perPage,
          ).withLayout(SlidesPdfLayout.handouts, locale: 'en-US'),
        );

        expect(r.pageCount, pages);
        expect(PdfFixture.mediaBoxes(pdf).toSet(), {'0 0 612 792'});
      });
    }

    test(
      'when exporting twice with the same input then the bytes are equal',
      () async {
        final a = await SlidesPdfExporter().render(
          deck,
          const SlidesPdfOptions(),
          await PdfFixture.resources(
            info: SlidesPdfDocumentInfo(modified: DateTime.utc(2026, 10, 1)),
          ),
        );
        final b = await SlidesPdfExporter().render(
          deck,
          const SlidesPdfOptions(),
          await PdfFixture.resources(
            info: SlidesPdfDocumentInfo(modified: DateTime.utc(2026, 10, 1)),
          ),
        );

        expect(a.bytes, b.bytes);
      },
    );

    test(
      'when exporting then the metadata names Wonky Slides and the title',
      () async {
        final (_, pdf) = await PdfFixture.render(
          deck,
          const SlidesPdfOptions(),
          resources: await PdfFixture.resources(
            info: const SlidesPdfDocumentInfo(author: 'Anna'),
          ),
        );

        expect(PdfFixture.titles(pdf).first, 'Q3 Review');
        expect(pdf, contains('/Creator'));
        expect(pdf, contains('Wonky Slides'));
        expect(pdf, contains('Anna'));
      },
    );

    test('when the export is cancelled then it stops with an exception', () {
      final exporter = SlidesPdfExporter(isCancelled: () => true);

      expect(
        () async => exporter.render(
          deck,
          const SlidesPdfOptions(),
          await PdfFixture.resources(),
        ),
        throwsA(isA<SlidesPdfCancelledException>()),
      );
    });

    test('when exporting then progress runs through the phases to 1', () async {
      final phases = <String>[];
      double last = 0;
      await PdfFixture.render(
        deck,
        const SlidesPdfOptions(),
        exporter: SlidesPdfExporter(
          compress: false,
          onProgress: (phase, p) {
            if (phases.isEmpty || phases.last != phase) phases.add(phase);
            last = p;
          },
        ),
      );

      expect(
        phases,
        containsAllInOrder(['layout', 'fonts', 'images', 'packaging']),
      );
      expect(last, 1);
    });

    test('when nothing is selected then one empty page is produced with a '
        'warning', () async {
      final (r, _) = await PdfFixture.render(
        deck,
        const SlidesPdfOptions(groupIds: ['missing']),
      );

      expect(r.pageCount, 1);
      expect(r.warnings, contains('empty_selection'));
    });
  });

  group('Given text with links', () {
    late _Deck d;
    late DeckModel deck;
    setUp(() {
      d = _Deck();
      d.b.element(
        d.untitled,
        ElementKind.text,
        columns: {
          SlidesCols.text: _delta([
            {
              'insert': 'Website',
              'attributes': {'link': 'https://example.com/wonky'},
            },
            {'insert': ' and '},
            {
              'insert': 'Team slide',
              'attributes': {'link': 'slide:${d.introC}'},
            },
            {'insert': ' and '},
            {
              'insert': 'hidden',
              'attributes': {'link': 'slide:${d.introB}'},
            },
            {'insert': '\n'},
          ]),
        },
      );
      deck = d.build();
    });

    test('when exporting then the URL and the slide link are clickable and '
        'the link to the excluded slide is dropped', () async {
      final (r, pdf) = await PdfFixture.render(deck, const SlidesPdfOptions());

      expect(pdf, contains('/URI'));
      expect(pdf, contains('https://example.com/wonky'));
      expect(pdf, contains('slide-${d.introC}'));
      expect(r.warnings, contains('link_dropped'));
    });

    test('when links are off then there are no link annotations', () async {
      final (_, pdf) = await PdfFixture.render(
        deck,
        const SlidesPdfOptions(links: false),
      );

      expect(pdf, isNot(contains('/URI')));
      expect(pdf, isNot(contains('/Subtype/Link')));
    });
  });

  group('Given an element with a click link', () {
    test('when exporting then its frame links to the URL', () async {
      final d = _Deck();
      d.b.shape(d.first, x: 100, y: 100);
      final id = d.b.element(
        d.first,
        ElementKind.shape,
        columns: {
          ElementCols.dataJson: jsonEncode({'v': 1, 'geometry': 'rect'}),
          ElementCols.linkJson: jsonEncode({'url': 'https://wonky.example/x'}),
        },
      );
      expect(id, isNotEmpty);

      final (_, pdf) = await PdfFixture.render(
        d.build(),
        const SlidesPdfOptions(),
      );

      expect(pdf, contains('https://wonky.example/x'));
    });
  });

  group('Given a code element', () {
    test(
      'when exporting then JetBrains Mono is embedded as a subset',
      () async {
        final d = _Deck();
        final code = d.b.element(
          d.first,
          ElementKind.code,
          width: 800,
          height: 300,
          columns: {
            ElementCols.dataJson: jsonEncode({'v': 1, 'language': 'dart'}),
          },
        );
        final state = (
          SlidesTables.codeState,
          {
            for (final c in SlidesTables.columns[SlidesTables.codeState]!)
              c: null,
            SlidesCols.id: '00000000-0000-7000-8000-00000000c001',
            SlidesCols.elementId: code,
            SlidesCols.sortKey: 'a0',
            CodeStateCols.code: 'void main() {\n  print("hi");\n}',
            SlidesCols.createdAt: testNow,
          },
        );

        final (r, pdf) = await PdfFixture.render(
          d.build(extra: [state]),
          const SlidesPdfOptions(range: '1'),
        );

        expect(pdf, contains('/BaseFont/JetBrainsMono'));
        expect(pdf, contains('/FontFile2'));
        // Subset: far smaller than the 200 KB face.
        expect(r.bytes.length, lessThan(120 * 1024));
      },
    );
  });

  group('Given a code element with a window frame and line steps (SL-31)', () {
    Future<String> export(Map<String, Object?> data) async {
      final d = _Deck();
      d.b.codeBlock(
        d.first,
        states: ['void main() {\n  print("hi");\n}'],
        highlights: ['2'],
        data: {'v': 1, 'language': 'dart', ...data},
      );
      final (_, pdf) = await PdfFixture.render(
        d.build(),
        const SlidesPdfOptions(range: '1'),
      );
      return pdf;
    }

    int fills(String pdf) => ' rg'.allMatches(pdf).length;

    test('when exporting then the window bar and its traffic lights are '
        'drawn as vector fills', () async {
      final plain = await export({'chrome': 'none'});
      final window = await export({'chrome': 'window'});

      expect(fills(window), greaterThanOrEqualTo(fills(plain) + 4));
    });
  });

  group('Given an image element', () {
    late _Deck d;
    setUp(() {
      d = _Deck();
      d.b.element(
        d.first,
        ElementKind.image,
        width: 400,
        height: 300,
        columns: {
          ElementCols.dataJson: jsonEncode({
            'v': 1,
            'src': 'wonky-file://00000000-0000-7000-8000-0000000000f1',
            'naturalWidth': 8,
            'naturalHeight': 6,
            'adjust': {'brightness': 0.2},
          }),
        },
      );
    });

    test('when the image is available then it is embedded', () async {
      final (r, pdf) = await PdfFixture.render(
        d.build(),
        const SlidesPdfOptions(range: '1'),
        resources: await PdfFixture.resources(
          images: {
            'wonky-file://00000000-0000-7000-8000-0000000000f1': _png(8, 6),
          },
        ),
      );

      expect(pdf, contains('/Subtype/Image'));
      expect(r.warnings, isNot(contains('image_missing')));
    });

    test('when the image is missing then the export warns', () async {
      final (r, pdf) = await PdfFixture.render(
        d.build(),
        const SlidesPdfOptions(range: '1'),
      );

      expect(pdf, isNot(contains('/Subtype/Image')));
      expect(r.warnings, contains('image_missing'));
    });
  });

  group('Given a family that cannot be loaded', () {
    test('when exporting then text falls back to the standard font with a '
        'warning', () async {
      final d = _Deck();
      final (r, _) = await PdfFixture.render(
        d.build(),
        const SlidesPdfOptions(range: '1'),
        resources: SlidesExportResources(
          fonts: BundledFileFontProvider((_) async => null),
          images: MemorySlideImageResolver(),
        ),
      );

      expect(r.pageCount, 1);
      expect(r.warnings, contains('font_fallback'));
    });
  });
}
