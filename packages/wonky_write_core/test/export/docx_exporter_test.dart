import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_write_core/testing.dart';
import 'package:wonky_write_core/wonky_write_core.dart';
import 'package:xml/xml.dart';

import '../support/property.dart';
import 'export_support.dart';

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

/// A document exercising every construct the DOCX round trip supports.
const roundTripSample = '''# Q3 planning

Intro with **bold**, *italic*, ~~strike~~, `code`, a [link](https://example.com) and ***[bold italic link](https://example.org/a?b=1)***.

## Goals

1. First
2. Second
   - nested bullet
     1. deep ordered
     2. deep ordered two
3. Third

Between lists.

1. Restarted

- bullet
- [x] done
- [ ] todo
  - [ ] nested todo

> A quote
>
> Second quote line

```
plain code
  indented\tand tab
```

---

![Logo](https://img.example.com/logo.png "The logo")

| Name | Value | Mid | Plain |
| :--- | ---: | :---: | --- |
| a **b** | 1 | `x` | [l](https://example.com/t) |
| c |  | ~~d~~ | e |

### Third level

Final paragraph with ünïcödé — 日本語 and an emoji 🎉.
''';

Map<String, XmlDocument> _parts(Uint8List docx) => {
  for (final e in DeterministicZip.decode(docx).entries)
    if (e.key.endsWith('.xml') || e.key.endsWith('.rels'))
      e.key: XmlDocument.parse(utf8.decode(e.value)),
};

Iterable<XmlElement> _w14(XmlNode n, String local) => n.descendantElements
    .where((e) => e.name.local == local && e.name.namespaceUri == _w);

String? _val(XmlElement e, String attr) =>
    e.getAttribute(attr, namespaceUri: _w);

void main() {
  final logo = ResolvedImage(
    bytes: pngBytes(width: 40, height: 20),
    mime: 'image/png',
    widthPx: 40,
    heightPx: 20,
  );
  final images = {'https://img.example.com/logo.png': logo};

  Future<ExportArtifact> export(
    Delta doc, {
    OfficeExportOptions options = const OfficeExportOptions(),
    PageSetup pageSetup = const PageSetup(),
    String theme = 'wonky-default',
    ThemeVariant variant = ThemeVariant.light,
  }) => const DocxExporter().export(
    input(
      doc,
      images: images,
      pageSetup: pageSetup,
      theme: theme,
      variant: variant,
    ),
    options,
  );

  group('Given the DOCX exporter', () {
    test('when exporting then the package has every required part', () async {
      final a = await export(md(sample));

      expect(a.fileName, 'Q3 planning.docx');
      expect(a.mimeType, ExportFormat.docx.mimeType);
      final files = DeterministicZip.decode(a.bytes);
      expect(
        files.keys,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'docProps/core.xml',
          'docProps/app.xml',
          'word/document.xml',
          'word/styles.xml',
          'word/numbering.xml',
          'word/settings.xml',
          'word/fontTable.xml',
          'word/_rels/document.xml.rels',
          'word/media/image1.png',
        ]),
      );
      expect(files.keys.first, '[Content_Types].xml');
      final parts = _parts(a.bytes);
      final types = parts['[Content_Types].xml']!;
      final overrides = types.rootElement.childElements
          .where((e) => e.name.local == 'Override')
          .map((e) => e.getAttribute('PartName')!.substring(1))
          .toSet();
      for (final p in files.keys) {
        if (p.endsWith('.xml') && p != '[Content_Types].xml') {
          expect(overrides, contains(p), reason: '$p needs a content type');
        }
      }
      final rels = parts['word/_rels/document.xml.rels']!;
      for (final r in rels.rootElement.childElements) {
        if (r.getAttribute('TargetMode') == 'External') continue;
        expect(
          files.keys,
          contains('word/${r.getAttribute('Target')}'),
          reason: 'relationship ${r.getAttribute('Id')} target exists',
        );
      }
    });

    test(
      'when exporting then core properties carry title, author and dates',
      () async {
        final a = await export(md(sample));
        final core = _parts(a.bytes)['docProps/core.xml']!;
        String text(String local) => core.rootElement.childElements
            .firstWhere((e) => e.name.local == local)
            .innerText;

        expect(text('title'), 'Q3 planning');
        expect(text('creator'), 'Anna');
        expect(text('language'), 'en');
        expect(text('keywords'), 'plan, q3');
        expect(text('modified'), '2026-10-01T12:00:00Z');
        final app = _parts(a.bytes)['docProps/app.xml']!;
        expect(app.rootElement.innerText, contains('Wonky Write'));
      },
    );

    test(
      'when exporting then styles come from the theme with heading outline levels',
      () async {
        final a = await export(md(sample), theme: 'classic-serif');
        final styles = _parts(a.bytes)['word/styles.xml']!;
        final byId = {
          for (final s in _w14(styles, 'style')) _val(s, 'styleId')!: s,
        };

        for (final id in [
          'Normal',
          'Heading1',
          'Heading6',
          'Quote',
          'CodeBlock',
          'CodeChar',
          'Hyperlink',
          'ListParagraph',
          'Caption',
          'Header',
          'Footer',
          'TOCHeading',
          'TOC1',
          'WonkyTable',
        ]) {
          expect(byId, contains(id));
        }
        final h2 = byId['Heading2']!;
        expect(_val(_w14(h2, 'outlineLvl').single, 'val'), '1');
        expect(_w14(h2, 'keepNext'), isNotEmpty);
        final theme = ThemeResolver.instance.resolve(
          BuiltinThemes.byKey('classic-serif')!.theme,
          ThemeVariant.light,
        );
        final normalFonts = _w14(byId['Normal']!, 'rFonts').single;
        expect(_val(normalFonts, 'ascii'), theme.body.style.fontFamily);
        expect(
          _val(_w14(byId['Normal']!, 'sz').single, 'val'),
          '${(theme.body.style.fontSize * 2).round()}',
        );
        // Justified body text (classic serif).
        expect(_val(_w14(byId['Normal']!, 'jc').single, 'val'), 'both');
        expect(_w14(byId['Quote']!, 'ind'), isNotEmpty);
      },
    );

    test(
      'when exporting nested lists then numbering restarts per ordered run',
      () async {
        final a = await export(md(roundTripSample));
        final parts = _parts(a.bytes);
        final numbering = parts['word/numbering.xml']!;
        final abstract = _w14(numbering, 'abstractNum').toList();
        expect(abstract.length, greaterThanOrEqualTo(3));
        expect(_w14(abstract.first, 'lvl').length, 9);
        final doc = parts['word/document.xml']!;
        final items = <(int, int)>[];
        for (final p in _w14(doc, 'p')) {
          final numPr = _w14(p, 'numPr').firstOrNull;
          if (numPr == null) continue;
          items.add((
            int.parse(_val(_w14(numPr, 'numId').single, 'val')!),
            int.parse(_val(_w14(numPr, 'ilvl').single, 'val')!),
          ));
        }
        // 1. First, 2. Second (same num), nested bullet, deep ordered ×2
        // (own num), 3. Third (back to the first num), "Restarted" (new).
        expect(items[0], items[1]);
        expect(items[2], (DocxNumIdsForTest.bullets, 1));
        expect(items[3].$1, items[4].$1);
        expect(items[3].$1, isNot(items[0].$1));
        expect(items[5], items[0]);
        expect(items[6].$1, isNot(items[0].$1));
        final nums = _w14(numbering, 'num').map((n) => _val(n, 'numId'));
        for (final (id, _) in items) {
          expect(nums, contains('$id'));
        }
      },
    );

    test(
      'when exporting then headers and footers carry page-number fields',
      () async {
        const setup = PageSetup(
          header: HeaderFooterSpec(enabled: true, left: '{title}'),
          footer: HeaderFooterSpec(enabled: true, center: '{page} / {pages}'),
          differentFirstPage: true,
          firstPageFooter: HeaderFooterSpec(
            enabled: true,
            right: '{date:yyyy}',
          ),
          pageNumberStart: 3,
          pageNumberFormat: PageNumberFormat.lowerRoman,
          orientation: PageOrientation.landscape,
          paper: PaperSize.a4,
        );
        final a = await export(md(sample), pageSetup: setup);
        final parts = _parts(a.bytes);
        final doc = parts['word/document.xml']!;
        final sect = _w14(doc, 'sectPr').single;
        final refs = _w14(sect, 'footerReference').toList();
        expect(refs.map((r) => _val(r, 'type')), ['default', 'first']);
        expect(_w14(sect, 'titlePg'), isNotEmpty);
        final pgSz = _w14(sect, 'pgSz').single;
        expect(_val(pgSz, 'orient'), 'landscape');
        expect(
          int.parse(_val(pgSz, 'w')!),
          greaterThan(int.parse(_val(pgSz, 'h')!)),
        );
        final pgNum = _w14(sect, 'pgNumType').single;
        expect(_val(pgNum, 'start'), '3');
        expect(_val(pgNum, 'fmt'), 'lowerRoman');

        final rels = parts['word/_rels/document.xml.rels']!;
        String target(String id) => rels.rootElement.childElements
            .firstWhere((r) => r.getAttribute('Id') == id)
            .getAttribute('Target')!;
        final footer =
            parts['word/${target(refs.first.getAttribute('r:id')!)}']!;
        final instr = [
          ..._w14(footer, 'fldSimple').map((f) => _val(f, 'instr')!),
          ..._w14(footer, 'instrText').map((t) => t.innerText),
        ].join('|');
        expect(instr, contains('PAGE'));
        expect(instr, contains('NUMPAGES'));
        expect(footer.rootElement.innerText, contains(' / '));
        final first = parts['word/${target(refs.last.getAttribute('r:id')!)}']!;
        expect(first.rootElement.innerText, contains('2026'));
        final header = parts['word/header1.xml']!;
        expect(header.rootElement.innerText, contains('Q3 planning'));
      },
    );

    test(
      'when exporting then images are embedded inline with alt text',
      () async {
        final a = await export(md(sample));
        final parts = _parts(a.bytes);
        final doc = parts['word/document.xml']!;
        final docPr = doc.descendantElements.firstWhere(
          (e) => e.name.local == 'docPr',
        );
        expect(docPr.getAttribute('descr'), 'Logo');
        expect(docPr.getAttribute('title'), 'The logo');
        final extent = doc.descendantElements.firstWhere(
          (e) => e.name.local == 'extent',
        );
        // 40×20 px at 96 dpi = 30×15 pt.
        expect(extent.getAttribute('cx'), '${30 * 12700}');
        expect(extent.getAttribute('cy'), '${15 * 12700}');
        expect(
          DeterministicZip.decode(a.bytes)['word/media/image1.png'],
          logo.bytes,
        );
      },
    );

    test(
      'when an image is missing then a placeholder and a warning are written',
      () async {
        final a = await const DocxExporter().export(
          input(md(sample)),
          const OfficeExportOptions(),
        );
        expect(a.warnings.map((w) => w.code), contains('image_unavailable'));
        final doc = _parts(a.bytes)['word/document.xml']!;
        expect(doc.rootElement.innerText, contains('[Image: Logo]'));
      },
    );

    test(
      'when exporting tables then the header repeats and cells are aligned',
      () async {
        final a = await export(md(roundTripSample));
        final doc = _parts(a.bytes)['word/document.xml']!;
        final tbl = _w14(doc, 'tbl').single;
        final rows = _w14(tbl, 'tr').toList();
        expect(_w14(rows.first, 'tblHeader'), isNotEmpty);
        expect(_w14(rows[1], 'tblHeader'), isEmpty);
        expect(_w14(tbl, 'gridCol').length, 4);
        final jc = [
          for (final tc in _w14(rows[1], 'tc'))
            _w14(tc, 'jc').map((e) => _val(e, 'val')).firstOrNull,
        ];
        expect(jc, ['left', 'right', 'center', null]);
      },
    );

    test(
      'when exporting links then external relationships are written',
      () async {
        final a = await export(md(roundTripSample));
        final rels = _parts(a.bytes)['word/_rels/document.xml.rels']!;
        final external = rels.rootElement.childElements
            .where((r) => r.getAttribute('TargetMode') == 'External')
            .map((r) => r.getAttribute('Target'))
            .toList();
        expect(
          external,
          containsAll([
            'https://example.com',
            'https://example.org/a?b=1',
            'https://example.com/t',
          ]),
        );
      },
    );

    test(
      'when exporting a code block then token colors become run colors',
      () async {
        final a = await export(md(sample));
        final doc = _parts(a.bytes)['word/document.xml']!;
        final code = _w14(doc, 'p')
            .where(
              (p) =>
                  _w14(p, 'pStyle').any((s) => _val(s, 'val') == 'CodeBlock'),
            )
            .toList();
        expect(code, isNotEmpty);
        expect(_w14(code.first, 'color'), isNotEmpty);
      },
    );

    test(
      'when including a TOC then a TOC field is inserted after the title',
      () async {
        final a = await export(
          md(sample),
          options: const OfficeExportOptions(includeToc: true),
        );
        final parts = _parts(a.bytes);
        final doc = parts['word/document.xml']!;
        final instr = _w14(doc, 'instrText').map((e) => e.innerText).join();
        expect(instr, contains('TOC'));
        final settings = parts['word/settings.xml']!;
        expect(_w14(settings, 'updateFields'), isNotEmpty);
        final paragraphs = _w14(doc, 'p').toList();
        expect(_w14(paragraphs[1], 'pStyle').map((s) => _val(s, 'val')), [
          'TOCHeading',
        ]);
      },
    );

    test(
      'when exporting the dark variant then a page background is set',
      () async {
        final a = await export(md(sample), variant: ThemeVariant.dark);
        final parts = _parts(a.bytes);
        expect(_w14(parts['word/document.xml']!, 'background'), isNotEmpty);
        expect(
          _w14(parts['word/settings.xml']!, 'displayBackgroundShape'),
          isNotEmpty,
        );
      },
    );

    test('when exporting twice then the bytes are identical', () async {
      final a = await export(md(sample));
      final b = await export(md(sample));
      expect(a.bytes, b.bytes);
    });

    for (final b in BuiltinThemes.all) {
      test(
        'when exporting with ${b.key} then every part is well-formed',
        () async {
          final a = await export(md(roundTripSample), theme: b.key);
          expect(_parts(a.bytes), isNotEmpty);
        },
      );
    }
  });

  group('Given a DOCX export imported again', () {
    String mdOf(Delta d) => const MarkdownCodec().exportMarkdown(d);

    Future<ImportResult> roundTrip(
      Delta source, {
      String theme = 'wonky-default',
      OfficeExportOptions options = const OfficeExportOptions(),
    }) async {
      final a = await export(source, theme: theme, options: options);
      var n = 0;
      return const DocxImporter().importSync(
        a.bytes,
        ImportOptions(idGenerator: () => 'i${n++}', fileName: a.fileName),
      );
    }

    String normalized(ImportResult r) => mdOf(
      r.delta,
    ).replaceAll('import-image://img1', 'https://img.example.com/logo.png');

    test('when importing then the delta equals the source', () async {
      final source = md(roundTripSample);
      final r = await roundTrip(source);

      expect(normalized(r), mdOf(source));
      // Headers/footers are page setup, which imports geometry only.
      expect(r.warnings.map((w) => w.kind), [
        ImportWarningKind.headersFootersDropped,
      ]);
      expect(r.title, 'Q3 planning');
      expect(r.language, 'en');
      expect(r.images.single.bytes, logo.bytes);
      expect(r.pageSetup?.widthPt, closeTo(612, 0.1));
    });

    for (final b in BuiltinThemes.all) {
      test(
        'when exporting with ${b.key} then the round trip is exact',
        () async {
          final source = md(roundTripSample);
          final r = await roundTrip(source, theme: b.key);
          expect(normalized(r), mdOf(source));
        },
      );
    }

    test('when the export has a TOC then the round trip skips it', () async {
      final source = md(roundTripSample);
      final r = await roundTrip(
        source,
        options: const OfficeExportOptions(includeToc: true),
      );
      expect(normalized(r), mdOf(source));
    });

    test('when exporting soft breaks and mentions then they survive', () async {
      final source = Delta()
        ..insert('Line one line two ')
        ..insert('@Anna', {
          'link': 'mailto:anna@example.com',
          'mention': '0192aaaa-0000-7000-8000-00000000000a',
        })
        ..insert('\n');
      final r = await roundTrip(source);
      expect(DeltaUtils.canonical(r.delta), DeltaUtils.canonical(source));
    });

    test(
      'Given random documents when exporting and importing then the result is valid',
      () async {
        for (final seed in propertySeeds()) {
          final random = Random(seed);
          for (var run = 0; run < propertyRuns(15); run++) {
            final doc = DeltaGen(random).document();
            final a = await const DocxExporter().export(
              input(doc),
              const OfficeExportOptions(),
            );
            expect(_parts(a.bytes), isNotEmpty);
            final r = const DocxImporter().importSync(a.bytes, ImportOptions());
            expect(
              const WonkyDeltaValidator().validate(r.delta).isValid,
              isTrue,
              reason: 'seed $seed run $run',
            );
          }
        }
      },
    );
  });
}

/// Mirrors the exporter's fixed numbering ids.
abstract final class DocxNumIdsForTest {
  static const bullets = 1;
}
