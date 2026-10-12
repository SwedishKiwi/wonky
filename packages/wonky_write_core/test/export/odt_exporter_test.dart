import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_write_core/wonky_write_core.dart';
import 'package:xml/xml.dart';

import 'export_support.dart';

const _office = 'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
const _style = 'urn:oasis:names:tc:opendocument:xmlns:style:1.0';
const _text = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0';
const _table = 'urn:oasis:names:tc:opendocument:xmlns:table:1.0';
const _draw = 'urn:oasis:names:tc:opendocument:xmlns:drawing:1.0';
const _fo = 'urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0';
const _svg = 'urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0';
const _xlink = 'http://www.w3.org/1999/xlink';
const _manifest = 'urn:oasis:names:tc:opendocument:xmlns:manifest:1.0';

/// An exported package: artifact plus decoded parts.
final class _Odt {
  _Odt(this.artifact) : files = DeterministicZip.decode(artifact.bytes);

  final ExportArtifact artifact;
  final Map<String, Uint8List> files;

  XmlDocument xml(String part) => XmlDocument.parse(utf8.decode(files[part]!));

  XmlDocument get content => xml('content.xml');
  XmlDocument get styles => xml('styles.xml');

  /// The `office:text` element of `content.xml`.
  XmlElement get body => content.rootElement
      .getElement('body', namespaceUri: _office)!
      .getElement('text', namespaceUri: _office)!;
}

Future<_Odt> _export(
  ExportInput input, [
  OfficeExportOptions options = const OfficeExportOptions(),
]) async => _Odt(await const OdtExporter().export(input, options));

Iterable<XmlElement> _all(XmlNode n, String ns, String local) => n
    .descendantElements
    .where((e) => e.name.local == local && e.name.namespaceUri == ns);

XmlElement? _namedStyle(XmlDocument doc, String name) =>
    _all(doc, _style, 'style').where((e) {
      return e.getAttribute('name', namespaceUri: _style) == name;
    }).firstOrNull;

void main() {
  final logo = ResolvedImage(
    bytes: pngBytes(),
    mime: 'image/png',
    widthPx: 4,
    heightPx: 2,
  );
  final images = {'https://img.example.com/logo.png': logo};

  group('Given the sample document exported as ODT', () {
    late _Odt odt;
    setUpAll(
      () async => odt = await _export(input(md(sample), images: images)),
    );

    test('when reading the zip then mimetype is the first, stored entry', () {
      final b = odt.artifact.bytes;
      // Local file header: signature, method 0 (stored), name, no extra.
      expect(b.sublist(0, 4), [0x50, 0x4B, 0x03, 0x04]);
      expect(b[8] | (b[9] << 8), 0, reason: 'compression method');
      final nameLength = b[26] | (b[27] << 8);
      final extraLength = b[28] | (b[29] << 8);
      expect(ascii.decode(b.sublist(30, 30 + nameLength)), 'mimetype');
      expect(extraLength, 0);
      final start = 30 + nameLength;
      expect(
        ascii.decode(b.sublist(start, start + 39)),
        'application/vnd.oasis.opendocument.text',
      );
      expect(odt.artifact.fileName, 'Q3 planning.odt');
      expect(odt.artifact.mimeType, 'application/vnd.oasis.opendocument.text');
    });

    test('when reading the manifest then it lists every part', () {
      final entries = {
        for (final e in _all(
          odt.xml('META-INF/manifest.xml'),
          _manifest,
          'file-entry',
        ))
          e.getAttribute('full-path', namespaceUri: _manifest)!: e.getAttribute(
            'media-type',
            namespaceUri: _manifest,
          ),
      };
      final parts = odt.files.keys.where(
        (p) => p != 'mimetype' && p != 'META-INF/manifest.xml',
      );
      expect(entries.keys, containsAll(parts));
      expect(entries['/'], 'application/vnd.oasis.opendocument.text');
      expect(entries['Pictures/image1.png'], 'image/png');
      expect(entries['content.xml'], 'text/xml');
    });

    test('when parsing every XML part then each is well-formed ODF 1.3', () {
      for (final part in [
        'content.xml',
        'styles.xml',
        'meta.xml',
        'settings.xml',
      ]) {
        final root = odt.xml(part).rootElement;
        expect(root.name.namespaceUri, _office, reason: part);
        expect(root.getAttribute('version', namespaceUri: _office), '1.3');
      }
      final manifest = odt.xml('META-INF/manifest.xml').rootElement;
      expect(manifest.getAttribute('version', namespaceUri: _manifest), '1.3');
    });

    test(
      'when reading meta.xml then title, author, language and dates are set',
      () {
        final meta = odt.xml('meta.xml').rootElement.innerXml;
        expect(meta, contains('<dc:title>Q3 planning</dc:title>'));
        expect(meta, contains('<dc:creator>Anna</dc:creator>'));
        expect(meta, contains('<dc:language>en</dc:language>'));
        expect(meta, contains('<meta:generator>Wonky Write</meta:generator>'));
        expect(meta, contains('<dc:date>2026-10-01T12:00:00Z</dc:date>'));
        expect(
          meta,
          contains(
            '<meta:creation-date>2026-10-01T12:00:00Z</meta:creation-date>',
          ),
        );
      },
    );

    test('when reading styles.xml then the theme styles are defined', () {
      for (final name in [
        'Standard',
        'Heading',
        for (var l = 1; l <= 6; l++) 'Heading_20_$l',
        'Quotations',
        'Preformatted_20_Text',
        'Source_20_Text',
        'Internet_20_link',
        'Table_20_Heading',
        'Table_20_Contents',
        'Caption',
        'Header',
        'Footer',
        'Horizontal_20_Line',
      ]) {
        expect(_namedStyle(odt.styles, name), isNotNull, reason: name);
      }
      final h2 = _namedStyle(odt.styles, 'Heading_20_2')!;
      expect(
        h2.getAttribute('default-outline-level', namespaceUri: _style),
        '2',
      );
      expect(
        h2
            .getElement('paragraph-properties', namespaceUri: _style)!
            .getAttribute('keep-with-next', namespaceUri: _fo),
        'always',
      );
      final code = _namedStyle(odt.styles, 'Source_20_Text')!;
      expect(
        code
            .getElement('text-properties', namespaceUri: _style)!
            .getAttribute('font-name', namespaceUri: _style),
        'JetBrains Mono',
      );
      expect(_all(odt.styles, _text, 'outline-style'), hasLength(1));
    });

    test(
      'when reading the list styles then bullets and numbers have 9 levels',
      () {
        final lists = {
          for (final l in _all(odt.styles, _text, 'list-style'))
            l.getAttribute('name', namespaceUri: _style)!: l,
        };
        expect(lists.keys, containsAll(['WonkyBullets', 'WonkyNumbers']));
        final bullets = lists['WonkyBullets']!.childElements.toList();
        final numbers = lists['WonkyNumbers']!.childElements.toList();
        expect(bullets.length, greaterThanOrEqualTo(9));
        expect(numbers.length, greaterThanOrEqualTo(9));
        expect(
          bullets[0].getAttribute('bullet-char', namespaceUri: _text),
          '•',
        );
        expect(
          bullets[1].getAttribute('bullet-char', namespaceUri: _text),
          '◦',
        );
        expect(
          [
            for (final n in numbers.take(3))
              n.getAttribute('num-format', namespaceUri: _style),
          ],
          ['1', 'a', 'i'],
        );
        expect(
          numbers[0].getAttribute('num-suffix', namespaceUri: _style),
          '.',
        );
      },
    );

    test('when reading the body then headings carry their outline level', () {
      final hs = _all(odt.body, _text, 'h').toList();
      expect(hs.map((h) => h.innerText), ['Q3 planning', 'Goals']);
      expect(
        hs.map((h) => h.getAttribute('outline-level', namespaceUri: _text)),
        ['1', '2'],
      );
    });

    test('when reading the lists then the bullet list is nested in item 2', () {
      final top = odt.body.childElements
          .where((e) => e.name.local == 'list')
          .toList();
      expect(top, hasLength(2), reason: 'numbered list, then task list');
      expect(
        top[0].getAttribute('style-name', namespaceUri: _text),
        'WonkyNumbers',
      );
      final items = top[0]
          .findElements('list-item', namespaceUri: _text)
          .toList();
      expect(items, hasLength(2));
      final nested = items[1].getElement('list', namespaceUri: _text)!;
      expect(
        nested.getAttribute('style-name', namespaceUri: _text),
        'WonkyBullets',
      );
      expect(nested.innerText, 'nested');
      expect(
        top[1].getAttribute('style-name', namespaceUri: _text),
        'WonkyTasks',
      );
      expect(top[1].innerText, contains('☒ done'));
      expect(top[1].innerText, contains('☐ todo'));
    });

    test(
      'when reading inline content then spans, code and links are styled',
      () {
        final p = _all(
          odt.body,
          _text,
          'p',
        ).firstWhere((e) => e.innerText.startsWith('Intro'));
        final a = p.getElement('a', namespaceUri: _text)!;
        expect(
          a.getAttribute('href', namespaceUri: _xlink),
          'https://example.com',
        );
        expect(a.innerText, 'link');
        final spans = p.findElements('span', namespaceUri: _text).toList();
        expect(spans.map((s) => s.innerText), [
          'bold',
          'italic',
          'strike',
          'code',
        ]);
        expect(
          spans[3].getAttribute('style-name', namespaceUri: _text),
          'Source_20_Text',
        );
      },
    );

    test('when reading the table then the header row repeats', () {
      final table = _all(odt.body, _table, 'table').single;
      final header = table.getElement(
        'table-header-rows',
        namespaceUri: _table,
      )!;
      expect(header.innerText, 'NameValue');
      final body = table
          .findElements('table-row', namespaceUri: _table)
          .toList();
      expect(body, hasLength(1));
      // The second column is right-aligned through an automatic style.
      final cell = body.single
          .findElements('table-cell', namespaceUri: _table)
          .last
          .getElement('p', namespaceUri: _text)!;
      final style = _namedStyle(
        odt.content,
        cell.getAttribute('style-name', namespaceUri: _text)!,
      )!;
      expect(
        style
            .getElement('paragraph-properties', namespaceUri: _style)!
            .getAttribute('text-align', namespaceUri: _fo),
        'end',
      );
    });

    test('when reading the image then the picture part and frame match', () {
      expect(odt.files['Pictures/image1.png'], logo.bytes);
      final frame = _all(odt.body, _draw, 'frame').single;
      expect(frame.getAttribute('width', namespaceUri: _svg), '3pt');
      expect(frame.getAttribute('height', namespaceUri: _svg), '1.5pt');
      expect(
        frame
            .getElement('image', namespaceUri: _draw)!
            .getAttribute('href', namespaceUri: _xlink),
        'Pictures/image1.png',
      );
      expect(frame.getElement('desc', namespaceUri: _svg)!.innerText, 'Logo');
      final caption = _all(odt.body, _text, 'p').firstWhere(
        (p) => p.getAttribute('style-name', namespaceUri: _text) == 'Caption',
      );
      expect(caption.innerText, 'The logo');
    });

    test(
      'when reading the code block then lines are preformatted paragraphs',
      () {
        final code = _all(odt.body, _text, 'p').where((p) {
          final s = p.getAttribute('style-name', namespaceUri: _text)!;
          final st = _namedStyle(odt.content, s);
          return st?.getAttribute('parent-style-name', namespaceUri: _style) ==
              'Preformatted_20_Text';
        }).toList();
        expect(code.single.innerText, "void main() => print('hi');");
        expect(
          code.single.findElements('span', namespaceUri: _text),
          isNotEmpty,
        );
      },
    );

    test('when reading the master page then header and footer have slots', () {
      final master = _all(odt.styles, _style, 'master-page').single;
      expect(master.getAttribute('name', namespaceUri: _style), 'Standard');
      final header = master.getElement('header', namespaceUri: _style)!;
      expect(header.innerText, 'Q3 planning');
      expect(_all(header, _text, 'tab'), hasLength(2));
      final footer = master.getElement('footer', namespaceUri: _style)!;
      expect(_all(footer, _text, 'page-number'), hasLength(1));
    });

    test('when exporting twice then the bytes are identical', () async {
      final again = await _export(input(md(sample), images: images));
      expect(again.artifact.bytes, odt.artifact.bytes);
    });
  });

  group('Given page setup options', () {
    test(
      'when footer shows page of pages then both fields are written',
      () async {
        final odt = await _export(
          input(
            md('Hello'),
            pageSetup: const PageSetup(
              paper: PaperSize.a4,
              orientation: PageOrientation.landscape,
              margins: PageMargins.all(54),
              header: HeaderFooterSpec(enabled: false),
              footer: HeaderFooterSpec(
                left: '{author}',
                right: 'Page {page} of {pages}',
                distancePt: 18,
              ),
              pageNumberStart: 5,
              pageNumberFormat: PageNumberFormat.lowerRoman,
            ),
          ),
        );
        final layout = _all(
          odt.styles,
          _style,
          'page-layout-properties',
        ).single;
        expect(
          layout.getAttribute('page-width', namespaceUri: _fo),
          '841.89pt',
        );
        expect(
          layout.getAttribute('print-orientation', namespaceUri: _style),
          'landscape',
        );
        expect(layout.getAttribute('num-format', namespaceUri: _style), 'i');
        expect(layout.getAttribute('margin-bottom', namespaceUri: _fo), '18pt');
        expect(layout.getAttribute('margin-left', namespaceUri: _fo), '54pt');
        final master = _all(odt.styles, _style, 'master-page').single;
        expect(master.getElement('header', namespaceUri: _style), isNull);
        final footer = master.getElement('footer', namespaceUri: _style)!;
        expect(footer.innerText, startsWith('Anna'));
        expect(_all(footer, _text, 'page-number'), hasLength(1));
        expect(_all(footer, _text, 'page-count'), hasLength(1));
        // The first paragraph starts the page numbering at 5.
        final first = _all(odt.body, _text, 'p').first;
        final style = _namedStyle(
          odt.content,
          first.getAttribute('style-name', namespaceUri: _text)!,
        )!;
        expect(
          style.getAttribute('master-page-name', namespaceUri: _style),
          'Standard',
        );
        expect(
          style
              .getElement('paragraph-properties', namespaceUri: _style)!
              .getAttribute('page-number', namespaceUri: _style),
          '5',
        );
      },
    );

    test(
      'when the first page differs then header-first and footer-first exist',
      () async {
        final odt = await _export(
          input(
            md('Hello'),
            pageSetup: const PageSetup(
              differentFirstPage: true,
              firstPageHeader: HeaderFooterSpec(center: 'Cover'),
              firstPageFooter: HeaderFooterSpec(enabled: false),
            ),
          ),
        );
        final master = _all(odt.styles, _style, 'master-page').single;
        expect(
          master.getElement('header-first', namespaceUri: _style)!.innerText,
          'Cover',
        );
        expect(
          master
              .getElement('footer-first', namespaceUri: _style)!
              .getAttribute('display', namespaceUri: _style),
          'false',
        );
      },
    );

    test(
      'when exporting the dark variant then the page has a background',
      () async {
        final light = await _export(input(md('Hi')));
        final dark = await _export(input(md('Hi'), variant: ThemeVariant.dark));
        String? bg(_Odt o) => _all(
          o.styles,
          _style,
          'page-layout-properties',
        ).single.getAttribute('background-color', namespaceUri: _fo);
        expect(bg(light), isNull);
        expect(bg(dark), isNotNull);
      },
    );
  });

  group('Given list, rule, code and text edge cases', () {
    test('when two numbered lists are separated then each restarts', () async {
      final odt = await _export(input(md('1. a\n2. b\n\nBetween\n\n1. c\n')));
      final lists = odt.body.childElements
          .where((e) => e.name.local == 'list')
          .toList();
      expect(lists, hasLength(2));
      for (final l in lists) {
        expect(
          l.getAttribute('style-name', namespaceUri: _text),
          'WonkyNumbers',
        );
        expect(
          l.getAttribute('continue-numbering', namespaceUri: _text),
          'false',
        );
      }
    });

    test(
      'when an item skips a level then an empty item holds the nested list',
      () async {
        final odt = await _export(input(md('- a\n    - b\n')));
        final top = odt.body.getElement('list', namespaceUri: _text)!;
        final item = top.getElement('list-item', namespaceUri: _text)!;
        expect(item.getElement('p', namespaceUri: _text)!.innerText, 'a');
        expect(item.getElement('list', namespaceUri: _text)!.innerText, 'b');
      },
    );

    test(
      'when text has runs of spaces, tabs and soft breaks then they are kept',
      () async {
        final doc = Delta()
          ..insert('  lead  two\u2028next')
          ..insert('\n')
          ..insert('\tx')
          ..insert('\n', {'code-block': ''});
        final odt = await _export(input(doc));
        final ps = _all(odt.body, _text, 'p').toList();
        expect(
          ps[0].toXmlString(),
          contains(
            '<text:s text:c="2"/>lead <text:s/>two<text:line-break/>next',
          ),
        );
        expect(ps[1].toXmlString(), contains('<text:tab/>x'));
      },
    );

    test(
      'when the theme uses an ornament rule then a glyph paragraph is written',
      () async {
        final odt = await _export(
          input(md('a\n\n---\n\nb'), theme: 'classic-serif'),
        );
        final rule = _all(odt.body, _text, 'p').firstWhere(
          (p) =>
              p.getAttribute('style-name', namespaceUri: _text)!.isNotEmpty &&
              p.innerText == '⁂',
        );
        final style = rule.getAttribute('style-name', namespaceUri: _text)!;
        final parent = style == 'Horizontal_20_Line'
            ? style
            : _namedStyle(
                odt.content,
                style,
              )!.getAttribute('parent-style-name', namespaceUri: _style);
        expect(parent, 'Horizontal_20_Line');
      },
    );

    test(
      'when the theme numbers headings then the outline style numbers them',
      () async {
        final odt = await _export(input(md('# A\n\n## B'), theme: 'technical'));
        final levels = _all(odt.styles, _text, 'outline-level-style').toList();
        expect(levels, hasLength(10));
        expect(
          levels
              .take(2)
              .map((l) => l.getAttribute('num-format', namespaceUri: _style)),
          everyElement(isNotEmpty),
        );
        // Heading text itself carries no label.
        expect(_all(odt.body, _text, 'h').first.innerText, 'A');
      },
    );

    test(
      'when a table of contents is requested then entries link to headings',
      () async {
        final odt = await _export(
          input(md(sample), images: images),
          const OfficeExportOptions(includeToc: true),
        );
        final toc = _all(odt.body, _text, 'table-of-content').single;
        final links = _all(
          toc,
          _text,
          'a',
        ).map((a) => a.getAttribute('href', namespaceUri: _xlink)).toList();
        expect(links, ['#h-q3-planning-1', '#h-goals-1']);
        expect(
          _all(
            odt.body,
            _text,
            'bookmark',
          ).map((b) => b.getAttribute('name', namespaceUri: _text)),
          ['h-q3-planning-1', 'h-goals-1'],
        );
      },
    );

    test(
      'when an image is missing then a placeholder and a warning are written',
      () async {
        final odt = await _export(input(md(sample)));
        expect(
          odt.artifact.warnings.map((w) => w.code),
          contains('image_unavailable'),
        );
        expect(_all(odt.body, _draw, 'frame'), isEmpty);
        expect(odt.files.keys.where((k) => k.startsWith('Pictures/')), isEmpty);
        expect(
          _all(odt.body, _text, 'p').map((p) => p.innerText),
          contains('[Image: Logo]'),
        );
      },
    );

    test(
      'when an image is wider than the page then the frame is scaled down',
      () async {
        final big = ResolvedImage(
          bytes: pngBytes(width: 1200, height: 600),
          mime: 'image/png',
          widthPx: 1200,
          heightPx: 600,
        );
        final odt = await _export(
          input(
            md('![Big](https://img.example.com/big.png)'),
            images: {'https://img.example.com/big.png': big},
          ),
        );
        final frame = _all(odt.body, _draw, 'frame').single;
        final w = double.parse(
          frame.getAttribute('width', namespaceUri: _svg)!.replaceAll('pt', ''),
        );
        final h = double.parse(
          frame
              .getAttribute('height', namespaceUri: _svg)!
              .replaceAll('pt', ''),
        );
        expect(w, lessThanOrEqualTo(468));
        expect(w / h, closeTo(2, 0.01));
      },
    );
  });

  group('Given every built-in theme', () {
    for (final theme in BuiltinThemes.all) {
      for (final variant in ThemeVariant.values) {
        test('when exporting with ${theme.key} (${variant.name}) then the '
            'package is valid', () async {
          final odt = await _export(
            input(
              md(sample),
              images: images,
              theme: theme.key,
              variant: variant,
            ),
            const OfficeExportOptions(includeToc: true),
          );
          for (final part in ['content.xml', 'styles.xml', 'meta.xml']) {
            expect(() => odt.xml(part), returnsNormally, reason: part);
          }
          expect(odt.files.keys.first, 'mimetype');
        });
      }
    }
  });
}
