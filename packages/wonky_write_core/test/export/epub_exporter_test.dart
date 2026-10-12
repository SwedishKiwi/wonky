@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:wonky_write_core/src/export/epub/epub_cover.dart';
import 'package:wonky_write_core/wonky_write_core.dart';
import 'package:xml/xml.dart';

import 'export_support.dart';

const _opfNs = 'http://www.idpf.org/2007/opf';
const _xhtmlNs = 'http://www.w3.org/1999/xhtml';
const _epubNs = 'http://www.idpf.org/2007/ops';

/// An unpacked EPUB.
final class _Book {
  _Book(this.artifact)
    : files = DeterministicZip.decode(artifact.bytes),
      archive = ZipDecoder().decodeBytes(artifact.bytes);

  final ExportArtifact artifact;
  final Map<String, Uint8List> files;
  final Archive archive;

  String text(String path) => utf8.decode(files[path]!);

  XmlDocument xml(String path) => XmlDocument.parse(text(path));

  late final XmlDocument opf = xml('OEBPS/content.opf');

  List<XmlElement> get manifestItems =>
      opf.findAllElements('item', namespaceUri: _opfNs).toList();

  XmlElement? item(String id) =>
      manifestItems.where((e) => e.getAttribute('id') == id).firstOrNull;

  List<String> get spine => [
    for (final e in opf.findAllElements('itemref', namespaceUri: _opfNs))
      e.getAttribute('idref')!,
  ];

  List<String> get chapterPaths =>
      files.keys.where((p) => p.startsWith('OEBPS/text/')).toList()..sort();
}

Future<_Book> _export(
  ExportInput input, [
  EpubExportOptions options = const EpubExportOptions(),
]) async => _Book(await const EpubExporter().export(input, options));

FontFace _face(
  String family,
  String file, {
  int weight = 400,
  bool italic = false,
}) => FontFace(
  family: family,
  weight: weight,
  italic: italic,
  bytes: File('../../wonky_write/assets/fonts/$file').readAsBytesSync(),
);

ExportInput _with(
  ExportInput base, {
  FontProvider? fonts,
  DocMeta? meta,
  LinkResolver? links,
}) => ExportInput(
  document: base.document,
  revision: base.revision,
  meta: meta ?? base.meta,
  theme: base.theme,
  variant: base.variant,
  images: base.images,
  fonts: fonts ?? base.fonts,
  links: links ?? base.links,
  now: base.now,
);

const _doc = 'wonky://doc/0192aaaa-0000-7000-8000-000000000001';

/// Links to the document itself resolve to `#anchor` fragments.
const _selfLinks = DefaultLinkResolver(
  origin: 'https://wonky.work',
  documentUuid: '0192aaaa-0000-7000-8000-000000000001',
);

const _chapters =
    '''Preface text before any heading.

# One

See [two]($_doc#h-two-1) and [here]($_doc#h-one-1).

## One A

Text.

### One A i

# Two

## Two A

Back to [one A]($_doc#h-one-a-1) and [unknown]($_doc#nowhere).
''';

void main() {
  final logo = ResolvedImage(
    bytes: pngBytes(),
    mime: 'image/png',
    widthPx: 4,
    heightPx: 2,
  );
  final images = {'https://img.example.com/logo.png': logo};

  group('Given the EPUB exporter and the sample document', () {
    late _Book book;
    setUpAll(
      () async => book = await _export(input(md(sample), images: images)),
    );

    test('when exporting then the artifact is an .epub', () {
      expect(book.artifact.fileName, 'Q3 planning.epub');
      expect(book.artifact.mimeType, 'application/epub+zip');
    });

    test(
      'when reading the zip then mimetype is the first, stored entry without extra fields',
      () {
        final b = book.artifact.bytes;
        final header = ByteData.sublistView(b);
        expect(header.getUint32(0, Endian.little), 0x04034b50);
        expect(header.getUint16(8, Endian.little), 0, reason: 'stored');
        expect(header.getUint16(26, Endian.little), 8);
        expect(header.getUint16(28, Endian.little), 0, reason: 'no extra');
        expect(ascii.decode(b.sublist(30, 38)), 'mimetype');
        expect(ascii.decode(b.sublist(38, 58)), 'application/epub+zip');
        expect(book.archive.files.first.name, 'mimetype');
        expect(book.archive.files.first.compression, CompressionType.none);
      },
    );

    test('when reading container.xml then it points to the OPF', () {
      final rootfile = book
          .xml('META-INF/container.xml')
          .findAllElements('rootfile')
          .single;
      expect(rootfile.getAttribute('full-path'), 'OEBPS/content.opf');
      expect(
        rootfile.getAttribute('media-type'),
        'application/oebps-package+xml',
      );
    });

    test('when parsing every XML part then all are well-formed', () {
      final xmlParts = book.files.keys.where(
        (p) =>
            p.endsWith('.xml') ||
            p.endsWith('.opf') ||
            p.endsWith('.ncx') ||
            p.endsWith('.xhtml'),
      );
      expect(xmlParts.length, greaterThanOrEqualTo(6));
      for (final p in xmlParts) {
        expect(() => book.xml(p), returnsNormally, reason: p);
      }
    });

    test('when reading the OPF then metadata matches the document', () {
      final package = book.opf.rootElement;
      expect(package.getAttribute('version'), '3.0');
      final idRef = package.getAttribute('unique-identifier');
      final identifier = book.opf
          .findAllElements(
            'identifier',
            namespaceUri: 'http://purl.org/dc/elements/1.1/',
          )
          .single;
      expect(identifier.getAttribute('id'), idRef);
      expect(
        identifier.innerText,
        'urn:uuid:0192aaaa-0000-7000-8000-000000000001',
      );
      String dc(String name) => book.opf
          .findAllElements(
            name,
            namespaceUri: 'http://purl.org/dc/elements/1.1/',
          )
          .single
          .innerText;
      expect(dc('title'), 'Q3 planning');
      expect(dc('creator'), 'Anna');
      expect(dc('language'), 'en');
      final modified = book.opf
          .findAllElements('meta', namespaceUri: _opfNs)
          .where((m) => m.getAttribute('property') == 'dcterms:modified')
          .single;
      expect(modified.innerText, '2026-10-01T12:00:00Z');
    });

    test(
      'when comparing manifest and zip then every file is listed exactly once',
      () {
        final hrefs = [
          for (final i in book.manifestItems) 'OEBPS/${i.getAttribute('href')}',
        ];
        expect(hrefs.toSet().length, hrefs.length);
        for (final h in hrefs) {
          expect(book.files.containsKey(h), isTrue, reason: h);
        }
        final listed = {
          ...hrefs,
          'mimetype',
          'META-INF/container.xml',
          'OEBPS/content.opf',
        };
        expect(book.files.keys.toSet().difference(listed), isEmpty);
      },
    );

    test(
      'when reading the manifest then media types and properties are set',
      () {
        expect(book.item('nav')!.getAttribute('properties'), 'nav');
        expect(
          book.item('ncx')!.getAttribute('media-type'),
          'application/x-dtbncx+xml',
        );
        expect(book.item('css')!.getAttribute('media-type'), 'text/css');
        final img = book.item('img-001')!;
        expect(img.getAttribute('href'), 'images/image-001.png');
        expect(img.getAttribute('media-type'), 'image/png');
        expect(img.getAttribute('properties'), 'cover-image');
        for (final i in book.manifestItems) {
          if (i.getAttribute('href')!.endsWith('.xhtml')) {
            expect(i.getAttribute('media-type'), 'application/xhtml+xml');
          }
        }
      },
    );

    test('when reading the spine then the cover comes before the chapters', () {
      expect(book.spine, ['cover', 'chapter-001']);
      expect(book.spine, isNot(contains('nav')));
      expect(
        book.opf
            .findAllElements('spine', namespaceUri: _opfNs)
            .single
            .getAttribute('toc'),
        'ncx',
      );
    });

    test('when reading a chapter then it is themed XHTML5', () {
      final xhtml = book.text('OEBPS/text/chapter-001.xhtml');
      expect(
        xhtml,
        startsWith('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n'),
      );
      final doc = book.xml('OEBPS/text/chapter-001.xhtml');
      final html = doc.rootElement;
      expect(html.name.namespaceUri, _xhtmlNs);
      expect(html.getAttribute('lang'), 'en');
      expect(html.getAttribute('xml:lang'), 'en');
      expect(doc.findAllElements('title').single.innerText, 'Q3 planning');
      expect(
        doc.findAllElements('link').single.getAttribute('href'),
        '../styles/theme.css',
      );
      final article = doc.findAllElements('article').single;
      expect(article.getAttribute('class'), 'wonky-doc');
      expect(
        doc.findAllElements('img').single.getAttribute('src'),
        '../images/image-001.png',
      );
      final tasks = doc.findAllElements('input').toList();
      expect(tasks, hasLength(2));
      expect(tasks.first.getAttribute('checked'), 'checked');
      expect(tasks.first.getAttribute('disabled'), 'disabled');
      expect(xhtml, isNot(contains('&nbsp;')));
      expect(
        RegExp(r'&(?!amp;|lt;|gt;|quot;|apos;|#)').hasMatch(xhtml),
        isFalse,
      );
    });

    test('when reading the stylesheet then it targets EPUB without colors', () {
      final css = book.text('OEBPS/styles/theme.css');
      expect(css, contains('.wonky-doc'));
      expect(css, isNot(contains('background-color: #')));
      expect(css, isNot(contains('@font-face')), reason: 'no fonts available');
    });

    test('when reading nav.xhtml then toc and landmarks navs exist', () {
      final doc = book.xml('OEBPS/nav.xhtml');
      final navs = doc.findAllElements('nav', namespaceUri: _xhtmlNs).toList();
      String type(XmlElement e) =>
          e.getAttribute('type', namespaceUri: _epubNs)!;
      expect(navs.map(type), ['toc', 'landmarks']);
      final toc = navs.first;
      final top = toc.findElements('ol').single.findElements('li').toList();
      expect(top, hasLength(1));
      expect(
        top.single.findElements('a').single.getAttribute('href'),
        'text/chapter-001.xhtml#h-q3-planning-1',
      );
      final nested = top.single.findElements('ol').single.findElements('li');
      expect(nested.single.findElements('a').single.innerText, 'Goals');
      final landmarks = [
        for (final a in navs.last.findAllElements('a'))
          (type(a), a.getAttribute('href')),
      ];
      expect(landmarks, [
        ('cover', 'cover.xhtml'),
        ('bodymatter', 'text/chapter-001.xhtml'),
      ]);
    });

    test(
      'when reading toc.ncx then dtb:uid matches and playOrder is sequential',
      () {
        final ncx = book.xml('OEBPS/toc.ncx');
        final uid = ncx
            .findAllElements('meta')
            .where((m) => m.getAttribute('name') == 'dtb:uid')
            .single;
        expect(
          uid.getAttribute('content'),
          'urn:uuid:0192aaaa-0000-7000-8000-000000000001',
        );
        final orders = [
          for (final p in ncx.findAllElements('navPoint'))
            int.parse(p.getAttribute('playOrder')!),
        ];
        expect(orders, [1, 2]);
      },
    );

    test('when reading the cover then the first image is shown', () {
      final cover = book.xml('OEBPS/cover.xhtml');
      expect(
        cover.findAllElements('img').single.getAttribute('src'),
        'images/image-001.png',
      );
      expect(book.item('cover')!.getAttribute('properties'), isNull);
      final coverMeta = book.opf
          .findAllElements('meta', namespaceUri: _opfNs)
          .where((m) => m.getAttribute('name') == 'cover')
          .single;
      expect(coverMeta.getAttribute('content'), 'img-001');
    });

    test('when exporting twice then the bytes are identical', () async {
      final again = await _export(input(md(sample), images: images));
      expect(again.artifact.bytes, equals(book.artifact.bytes));
    });
  });

  group('Given a document with several headings', () {
    test(
      'when splitting at h1 then preface becomes chapter 000 and H1s start chapters',
      () async {
        final book = await _export(input(md(_chapters)));

        expect(book.chapterPaths, [
          'OEBPS/text/chapter-000.xhtml',
          'OEBPS/text/chapter-001.xhtml',
          'OEBPS/text/chapter-002.xhtml',
        ]);
        expect(book.spine, [
          'cover',
          'chapter-000',
          'chapter-001',
          'chapter-002',
        ]);
        String title(String p) =>
            book.xml(p).findAllElements('title').single.innerText;
        expect(title('OEBPS/text/chapter-000.xhtml'), 'Q3 planning');
        expect(title('OEBPS/text/chapter-001.xhtml'), 'One');
        expect(title('OEBPS/text/chapter-002.xhtml'), 'Two');
      },
    );

    test(
      'when splitting at h2 then level-2 headings start chapters too',
      () async {
        final book = await _export(
          input(md(_chapters)),
          const EpubExportOptions(chapterSplit: EpubChapterSplit.h2),
        );

        expect(book.chapterPaths, hasLength(5));
        expect(
          book
              .xml('OEBPS/text/chapter-002.xhtml')
              .findAllElements('h2')
              .single
              .innerText,
          'One A',
        );
        expect(
          book
              .xml('OEBPS/text/chapter-002.xhtml')
              .findAllElements('h3')
              .single
              .innerText,
          'One A i',
        );
      },
    );

    test('when not splitting then everything is one chapter 001', () async {
      final book = await _export(
        input(md(_chapters)),
        const EpubExportOptions(chapterSplit: EpubChapterSplit.none),
      );

      expect(book.chapterPaths, ['OEBPS/text/chapter-001.xhtml']);
      expect(book.spine, ['cover', 'chapter-001']);
    });

    test(
      'when the document starts with a heading then numbering starts at 001',
      () async {
        final book = await _export(input(md('# A\n\nx\n\n# B\n\ny\n')));

        expect(book.chapterPaths, [
          'OEBPS/text/chapter-001.xhtml',
          'OEBPS/text/chapter-002.xhtml',
        ]);
      },
    );

    test(
      'when linking to a heading in another chapter then the href names its file',
      () async {
        final book = await _export(
          _with(input(md(_chapters)), links: _selfLinks),
        );

        List<String> hrefs(String p) => [
          for (final a
              in book.xml(p).findAllElements('a', namespaceUri: _xhtmlNs))
            a.getAttribute('href')!,
        ];
        expect(hrefs('OEBPS/text/chapter-001.xhtml'), [
          'chapter-002.xhtml#h-two-1',
          '#h-one-1',
        ]);
        expect(hrefs('OEBPS/text/chapter-002.xhtml'), [
          'chapter-001.xhtml#h-one-a-1',
          'chapter-000.xhtml',
        ]);
      },
    );

    test(
      'when reading the nav then H1–H3 are nested and preface listed',
      () async {
        final book = await _export(input(md(_chapters)));

        final toc = book
            .xml('OEBPS/nav.xhtml')
            .findAllElements('nav', namespaceUri: _xhtmlNs)
            .first;
        String outline(XmlElement ol, String indent) => [
          for (final li in ol.findElements('li'))
            '$indent${li.findElements('a').single.innerText}'
                ' → ${li.findElements('a').single.getAttribute('href')}\n'
                '${li.findElements('ol').map((o) => outline(o, '$indent  ')).join()}',
        ].join();
        expect(
          outline(toc.findElements('ol').single, ''),
          'Q3 planning → text/chapter-000.xhtml\n'
          'One → text/chapter-001.xhtml#h-one-1\n'
          '  One A → text/chapter-001.xhtml#h-one-a-1\n'
          '    One A i → text/chapter-001.xhtml#h-one-a-i-1\n'
          'Two → text/chapter-002.xhtml#h-two-1\n'
          '  Two A → text/chapter-002.xhtml#h-two-a-1\n',
        );
        final ncx = book.xml('OEBPS/toc.ncx');
        expect(ncx.findAllElements('navPoint'), hasLength(6));
        expect(
          ncx
              .findAllElements('meta')
              .where((m) => m.getAttribute('name') == 'dtb:depth')
              .single
              .getAttribute('content'),
          '3',
        );
      },
    );

    test(
      'when the theme numbers headings then chapters continue the counters',
      () async {
        final book = await _export(input(md(_chapters), theme: 'technical'));
        final resolved = ThemeResolver.instance.resolve(
          BuiltinThemes.byKey('technical')!.theme,
          ThemeVariant.light,
        );
        if (!resolved.headingNumbering.enabled) {
          markTestSkipped('technical theme does not number headings');
          return;
        }

        final article = book
            .xml('OEBPS/text/chapter-002.xhtml')
            .findAllElements('article')
            .single;
        expect(article.getAttribute('style'), contains('wk-h1 1'));
      },
    );
  });

  group('Given cover options', () {
    test(
      'when the document has no image then a generated SVG cover is used',
      () async {
        final book = await _export(input(md('# Hello\n\nWorld\n')));

        final cover = book.xml('OEBPS/cover.xhtml');
        final svg = cover
            .findAllElements('svg', namespaceUri: 'http://www.w3.org/2000/svg')
            .single;
        expect(svg.innerText, contains('Q3 planning'));
        expect(svg.innerText, contains('Anna'));
        expect(
          svg.findAllElements('text').first.getAttribute('font-family'),
          contains('Inter'),
        );
        expect(book.item('cover')!.getAttribute('properties'), 'svg');
        expect(
          book.manifestItems.where(
            (i) => i.getAttribute('properties') == 'cover-image',
          ),
          isEmpty,
        );
      },
    );

    test('when cover is none then there is no cover page', () async {
      final book = await _export(
        input(md(sample), images: images),
        const EpubExportOptions(cover: 'none'),
      );

      expect(book.files.containsKey('OEBPS/cover.xhtml'), isFalse);
      expect(book.spine, ['chapter-001']);
      expect(book.item('img-001')!.getAttribute('properties'), isNull);
      expect(
        book
            .xml('OEBPS/nav.xhtml')
            .findAllElements('a')
            .map((a) => a.getAttribute('href')),
        isNot(contains('cover.xhtml')),
      );
    });

    test(
      'when cover names an image file then it is resolved and embedded',
      () async {
        const uuid = '0192bbbb-0000-7000-8000-000000000002';
        final book = await _export(
          input(md(sample), images: {...images, 'wonky-file://$uuid': logo}),
          const EpubExportOptions(cover: uuid),
        );

        final item = book.item('img-cover')!;
        expect(item.getAttribute('href'), 'images/cover.png');
        expect(item.getAttribute('properties'), 'cover-image');
        expect(book.item('img-001')!.getAttribute('properties'), isNull);
        expect(
          book
              .xml('OEBPS/cover.xhtml')
              .findAllElements('img')
              .single
              .getAttribute('src'),
          'images/cover.png',
        );
      },
    );

    test(
      'when the named cover image is missing then a generated cover is used',
      () async {
        final book = await _export(
          input(md(sample), images: images),
          const EpubExportOptions(cover: 'missing-uuid'),
        );

        expect(
          book.artifact.warnings.map((w) => w.code),
          contains('image_unavailable'),
        );
        expect(book.item('cover')!.getAttribute('properties'), 'svg');
      },
    );
  });

  group('Given images that cannot be loaded', () {
    test(
      'when exporting then a placeholder is written and a warning added',
      () async {
        final book = await _export(input(md(sample)));

        expect(
          book.artifact.warnings.map((w) => w.code),
          contains('image_unavailable'),
        );
        final chapter = book.text('OEBPS/text/chapter-001.xhtml');
        expect(chapter, contains('class="wonky-image-missing"'));
        expect(
          book.files.keys.where((p) => p.startsWith('OEBPS/images/')),
          isEmpty,
        );
        expect(book.item('cover')!.getAttribute('properties'), 'svg');
      },
    );
  });

  group('Given font embedding', () {
    final provider = InMemoryFontProvider([
      _face('Inter', 'OpenSans-Regular.ttf'),
      _face('Inter', 'OpenSans-Italic.ttf', italic: true),
      _face('Inter', 'OpenSans-Bold.ttf', weight: 700),
      _face('Inter', 'OpenSans-BoldItalic.ttf', weight: 700, italic: true),
      _face('JetBrains Mono', 'JetBrainsMono-Regular.ttf'),
    ]);

    test(
      'when the provider has the faces then used faces are embedded',
      () async {
        final book = await _export(_with(input(md(sample)), fonts: provider));

        final fonts =
            book.files.keys
                .where(
                  (p) => p.startsWith('OEBPS/fonts/') && p.endsWith('.ttf'),
                )
                .toList()
              ..sort();
        expect(fonts, [
          'OEBPS/fonts/inter-400-italic.ttf',
          'OEBPS/fonts/inter-400.ttf',
          'OEBPS/fonts/inter-700-italic.ttf',
          'OEBPS/fonts/inter-700.ttf',
          'OEBPS/fonts/jetbrains-mono-400.ttf',
        ]);
        for (final i in book.manifestItems) {
          if (i.getAttribute('href')!.endsWith('.ttf')) {
            expect(i.getAttribute('media-type'), 'font/ttf');
          }
        }
        expect(book.files.containsKey('OEBPS/fonts/LICENSE-OFL.txt'), isTrue);
        expect(
          book.text('OEBPS/fonts/LICENSE-OFL.txt'),
          contains('SIL Open Font License'),
        );
        final css = book.text('OEBPS/styles/theme.css');
        expect(css, contains('url("../fonts/inter-400.ttf")'));
        expect(css, contains('font-family: "Inter"'));
      },
    );

    test(
      'when the provider has one face per family then each file is embedded once',
      () async {
        final book = await _export(
          _with(
            input(md(sample)),
            fonts: InMemoryFontProvider([
              _face('Inter', 'OpenSans-Regular.ttf'),
              _face('JetBrains Mono', 'OpenSans-Regular.ttf'),
            ]),
          ),
        );

        expect(book.files.keys.where((p) => p.endsWith('.ttf')), [
          'OEBPS/fonts/inter-400.ttf',
        ]);
        final css = book.text('OEBPS/styles/theme.css');
        expect('@font-face'.allMatches(css), hasLength(2));
        expect(
          css,
          contains(
            'font-family: "JetBrains Mono"; src: url("../fonts/inter-400.ttf")',
          ),
        );
      },
    );

    test('when embedFonts is off then no fonts are embedded', () async {
      final book = await _export(
        _with(input(md(sample)), fonts: provider),
        const EpubExportOptions(embedFonts: false),
      );

      expect(
        book.files.keys.where((p) => p.startsWith('OEBPS/fonts/')),
        isEmpty,
      );
      expect(
        book.text('OEBPS/styles/theme.css'),
        isNot(contains('@font-face')),
      );
    });

    test(
      'when the provider lacks a family then a font_fallback warning is added',
      () async {
        final book = await _export(input(md(sample)));

        expect(
          book.artifact.warnings.map((w) => w.code),
          contains('font_fallback'),
        );
        expect(
          book.files.keys.where((p) => p.startsWith('OEBPS/fonts/')),
          isEmpty,
        );
      },
    );
  });

  group('Given the generated cover', () {
    test('when the title is long then it is wrapped onto several lines', () {
      final svg = EpubCoverWriter.svg(
        title:
            'A rather long document title that certainly needs wrapping '
            'across several lines of the cover',
        author: null,
        theme: ThemeResolver.instance.resolve(
          BuiltinThemes.wonkyDefault.theme,
          ThemeVariant.light,
        ),
      );

      final doc = XmlDocument.parse(svg);
      final lines = doc.findAllElements('tspan').map((e) => e.innerText);
      expect(lines.length, greaterThan(1));
      expect(lines.join(' '), startsWith('A rather long document title'));
      expect(doc.findAllElements('text'), hasLength(1), reason: 'no author');
    });
  });

  group('Given document metadata', () {
    test(
      'when there is no document UUID then the identifier is derived',
      () async {
        final base = input(md(sample));
        final a = await _export(_with(base, meta: const DocMeta(title: 'T')));
        final b = await _export(_with(base, meta: const DocMeta(title: 'T')));
        final c = await _export(_with(base, meta: const DocMeta(title: 'U')));

        String id(_Book book) => book.opf
            .findAllElements(
              'identifier',
              namespaceUri: 'http://purl.org/dc/elements/1.1/',
            )
            .single
            .innerText;
        expect(
          id(a),
          matches(
            RegExp(
              r'^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(id(a), id(b));
        expect(id(a), isNot(id(c)));
        expect(
          a
              .xml('OEBPS/toc.ncx')
              .findAllElements('meta')
              .first
              .getAttribute('content'),
          id(a),
        );
      },
    );

    test('when the author option is set then it overrides the owner', () async {
      final book = await _export(
        input(md(sample)),
        const EpubExportOptions(author: 'Ada <Lovelace> & Co'),
      );

      expect(
        book.opf
            .findAllElements(
              'creator',
              namespaceUri: 'http://purl.org/dc/elements/1.1/',
            )
            .single
            .innerText,
        'Ada <Lovelace> & Co',
      );
    });

    test('when the language is invalid then en is used', () async {
      final book = await _export(
        _with(
          input(md(sample)),
          meta: const DocMeta(title: 'T', language: 'not a tag'),
        ),
      );

      expect(
        book
            .xml('OEBPS/text/chapter-001.xhtml')
            .rootElement
            .getAttribute('lang'),
        'en',
      );
    });

    test(
      'when text contains XML-invalid control characters then they are dropped',
      () async {
        final book = await _export(
          input(md('# A\u0001B\n\nx\u0008y & 1 < 2\n')),
        );

        for (final p in book.chapterPaths) {
          expect(() => book.xml(p), returnsNormally);
        }
        expect(
          book.text('OEBPS/text/chapter-001.xhtml'),
          contains('xy &amp; 1 &lt; 2'),
        );
      },
    );

    test(
      'when the document is empty then one empty chapter is exported',
      () async {
        final book = await _export(input(Delta()..insert('\n')));

        expect(book.chapterPaths, ['OEBPS/text/chapter-001.xhtml']);
        expect(book.xml('OEBPS/nav.xhtml').findAllElements('li'), isNotEmpty);
      },
    );
  });

  group('Given every built-in theme', () {
    for (final t in BuiltinThemes.all) {
      test(
        'when exporting with ${t.key} then a well-formed EPUB results',
        () async {
          final book = await _export(
            input(md('$sample\n$_chapters'), images: images, theme: t.key),
            const EpubExportOptions(useThemeColors: true),
          );

          for (final p in book.files.keys.where(
            (p) =>
                p.endsWith('.xhtml') ||
                p.endsWith('.opf') ||
                p.endsWith('.ncx'),
          )) {
            expect(() => book.xml(p), returnsNormally, reason: p);
          }
          expect(book.text('OEBPS/styles/theme.css'), contains('.wonky-doc'));
        },
      );
    }
  });
}
