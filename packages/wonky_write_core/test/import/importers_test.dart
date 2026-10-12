import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_write_core/testing.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../support/property.dart';

ImportOptions opts({
  TxtLineBreaks lines = TxtLineBreaks.paragraph,
  String? fileName,
}) {
  var n = 0;
  return ImportOptions(
    idGenerator: () => 'id${n++}',
    txtLineBreaks: lines,
    fileName: fileName,
  );
}

List<Map<String, dynamic>> html(String source) =>
    const HtmlImporter().importHtml(source, opts()).delta.toJson();

void main() {
  group('Given plain text', () {
    test(
      'when importing with paragraph line breaks then each line is a paragraph',
      () {
        final r = const TxtImporter().importText(
          'a\tb\r\nc\u0007\n\nd',
          opts(),
        );

        expect(r.delta.toJson(), [
          {'insert': 'a    b\nc\n\nd\n'},
        ]);
      },
    );

    test(
      'when importing with soft line breaks then blank lines separate paragraphs',
      () {
        final r = const TxtImporter().importText(
          'a\nb\n\nc',
          opts(lines: TxtLineBreaks.soft),
        );

        expect(r.delta.toJson(), [
          {'insert': 'a\u2028b\nc\n'},
        ]);
      },
    );

    test('when text looks like Markdown then the heuristic says so', () {
      expect(
        looksLikeMarkdown('# Title\n\n- item\n\n**bold** and [x](y)'),
        isTrue,
      );
      expect(looksLikeMarkdown('Just a note.\nAnother line.'), isFalse);
    });
  });

  group('Given encodings', () {
    test('when bytes are UTF-16 LE with BOM then they decode', () {
      final bytes = Uint8List.fromList([0xFF, 0xFE, 0x68, 0x00, 0xE9, 0x00]);

      expect(ImportTextDecoder.decode(bytes).text, 'hé');
    });

    test('when bytes are invalid UTF-8 then Windows-1252 is guessed', () {
      final d = ImportTextDecoder.decode(
        Uint8List.fromList([0x63, 0x61, 0x66, 0xE9, 0x80]),
      );

      expect(d.text, 'café€');
      expect(d.guessed, isTrue);
    });
  });

  group('Given HTML', () {
    final cases = <(String, String, List<Map<String, dynamic>>)>[
      (
        'headings and inline formatting',
        '<h2>T <b>b</b></h2><p>x <i>i</i> <s>s</s> <code>c</code></p>',
        [
          {'insert': 'T '},
          {
            'insert': 'b',
            'attributes': {'bold': true},
          },
          {
            'insert': '\n',
            'attributes': {'header': 2},
          },
          {'insert': 'x '},
          {
            'insert': 'i',
            'attributes': {'italic': true},
          },
          {'insert': ' '},
          {
            'insert': 's',
            'attributes': {'strike': true},
          },
          {'insert': ' '},
          {
            'insert': 'c',
            'attributes': {'code': true},
          },
          {'insert': '\n'},
        ],
      ),
      (
        'style-based formatting',
        '<p><span style="font-weight:700">B</span><span style="font-style:italic">I</span></p>',
        [
          {
            'insert': 'B',
            'attributes': {'bold': true},
          },
          {
            'insert': 'I',
            'attributes': {'italic': true},
          },
          {'insert': '\n'},
        ],
      ),
      (
        'nested lists and tasks',
        '<ul><li>a<ol><li>b</li></ol></li><li><input type="checkbox" checked> c</li></ul>',
        [
          {'insert': 'a'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': 'b'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered', 'indent': 1},
          },
          {'insert': 'c'},
          {
            'insert': '\n',
            'attributes': {'list': 'checked'},
          },
        ],
      ),
      (
        'scripts and styles',
        '<p>a<script>alert(1)</script></p><style>p{}</style>',
        [
          {'insert': 'a\n'},
        ],
      ),
      (
        'a javascript link',
        '<p><a href="javascript:x()">t</a></p>',
        [
          {'insert': 't\n'},
        ],
      ),
      (
        'a horizontal rule',
        '<p>a</p><hr><p>b</p>',
        [
          {'insert': 'a\n'},
          {
            'insert': {
              'divider': {'id': 'id0'},
            },
          },
          {'insert': '\nb\n'},
        ],
      ),
    ];
    for (final (name, source, expected) in cases) {
      test('when importing $name then the delta matches', () {
        expect(html(source), equals(expected));
      });
    }

    test(
      'when importing Google Docs HTML then the bold wrapper is ignored and lists use aria-level',
      () {
        const gdocs =
            '<meta charset="utf-8"><b style="font-weight:normal;" id="docs-internal-guid-1234">'
            '<p dir="ltr"><span style="font-weight:700;">Bold</span><span style="font-weight:400;"> plain</span></p>'
            '<ul><li dir="ltr" aria-level="1"><p dir="ltr"><span>one</span></p></li>'
            '<li dir="ltr" aria-level="2"><p dir="ltr"><span>two</span></p></li></ul></b>';

        final r = const HtmlImporter().importFragment(gdocs, options: opts());

        expect(r.delta.toJson(), [
          {
            'insert': 'Bold',
            'attributes': {'bold': true},
          },
          {'insert': ' plain\none'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': 'two'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 1},
          },
        ]);
      },
    );

    test('when importing Word HTML then Mso lists and headings are mapped', () {
      const word =
          '<html xmlns:w="urn:schemas-microsoft-com:office:word"><body>'
          '<p class=MsoHeading1>Title</p>'
          '<p class=MsoListParagraphCxSpFirst style="mso-list:l0 level1 lfo1"><![if !supportLists]><span style="mso-list:Ignore">1.<span>&nbsp;</span></span><![endif]>First</p>'
          '<p class=MsoListParagraphCxSpLast style="mso-list:l0 level2 lfo1"><![if !supportLists]><span style="mso-list:Ignore">a.<span>&nbsp;</span></span><![endif]>Second</p>'
          '</body></html>';

      final r = const HtmlImporter().importHtml(word, opts());

      expect(r.delta.toJson(), [
        {'insert': 'Title'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
        {'insert': 'First'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'Second'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered', 'indent': 1},
        },
      ]);
    });

    test(
      'when importing a data URI image then it becomes an imported image',
      () {
        final png = base64Encode([137, 80, 78, 71, 13, 10, 26, 10]);
        final r = const HtmlImporter().importHtml(
          '<p><img src="data:image/png;base64,$png" alt="dot"></p>',
          opts(),
        );

        expect(r.images.single.mime, 'image/png');
        expect(
          (r.delta.toJson().first['insert'] as Map)['image']['src'],
          r.images.single.src,
        );
      },
    );

    test('when importing a full document then title and language are read', () {
      final r = const HtmlImporter().importHtml(
        '<html lang="de"><head><title>Hallo</title></head><body><p>x</p></body></html>',
        opts(),
      );

      expect((r.title, r.language), ('Hallo', 'de'));
    });

    propertyTest(
      'when importing random HTML then the result always validates',
      (random, _) {
        final gen = DeltaGen(random);
        final body = const HtmlBodyWriter().article(
          const DocTreeBuilder().fromDelta(gen.document()),
        );
        final noise = [
          '<div>',
          '</span>',
          '<b>',
          '<table><tr><td>x',
          '<ul><li>',
          '&nbsp;',
          '<br>',
          '<font color=red>',
        ];
        final mangled = StringBuffer();
        for (final part in body.split('>')) {
          mangled.write('$part>');
          if (random.nextInt(6) == 0) {
            mangled.write(noise[random.nextInt(noise.length)]);
          }
        }

        final r = const HtmlImporter().importFragment(
          mangled.toString(),
          options: opts(),
        );

        expect(const WonkyDeltaValidator().validate(r.delta).issues, isEmpty);
      },
      runs: 100,
    );
  });

  group('Given the importer dispatcher', () {
    test('when detecting formats then extensions and sniffing are used', () {
      Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

      expect(
        ImportFormatDetector.detect(b('# x'), fileName: 'a.md').format,
        ImportFormat.markdown,
      );
      expect(
        ImportFormatDetector.detect(
          b('<!DOCTYPE html><p>x'),
          fileName: 'page',
        ).format,
        ImportFormat.html,
      );
      expect(
        ImportFormatDetector.detect(b(r'{\rtf1 x}')).format,
        ImportFormat.rtf,
      );
      expect(
        ImportFormatDetector.detect(b('hello'), fileName: 'notes.txt').format,
        ImportFormat.txt,
      );
      expect(
        ImportFormatDetector.detect(
          DeterministicZip.encode([ZipEntry.text('[Content_Types].xml', '')]),
        ).format,
        ImportFormat.docx,
      );
    });

    test(
      'when importing a Markdown zip then relative images are resolved',
      () async {
        final zip = DeterministicZip.encode([
          ZipEntry.text('doc/readme.md', '# T\n\n![Logo](img/logo.png)\n'),
          ZipEntry('doc/img/logo.png', Uint8List.fromList([1, 2, 3])),
        ]);

        final r = await const WonkyImporters().import(
          zip,
          opts(fileName: 'export.zip'),
        );

        expect(r.images.single.bytes, [1, 2, 3]);
        final processed = await ImportPostProcessor.process(
          r,
          (img) async => 'file-uuid',
        );
        expect(processed.delta.toJson()[2]['insert'], {
          'image': {
            'id': 'id0',
            'src': 'wonky-file://file-uuid',
            'alt': 'Logo',
          },
        });
      },
    );

    test('when an upload fails then the image becomes a placeholder', () async {
      final r = const HtmlImporter().importHtml(
        '<p><img src="data:image/png;base64,AAAA" alt="x"></p>',
        opts(),
      );

      final processed = await ImportPostProcessor.process(
        r,
        (img) async => null,
      );

      expect(DeltaUtils.text(processed.delta), '[image: x]\n');
      expect(
        processed.warnings.map((w) => w.kind),
        contains(ImportWarningKind.unresolvedImage),
      );
    });

    test(
      'when importing a damaged DOCX then it imports what it can with a warning',
      () async {
        final r = await const WonkyImporters().import(
          DeterministicZip.encode([ZipEntry.text('[Content_Types].xml', '')]),
          opts(),
        );
        expect(
          r.warnings.map((w) => w.kind),
          contains(ImportWarningKind.contentDropped),
        );
      },
    );

    test(
      'when the input exceeds the limit then ImportTooLargeException is thrown',
      () {
        expect(
          () => const WonkyImporters(
            limits: ImportLimits.client,
          ).import(Uint8List(6 * 1024 * 1024), opts(fileName: 'x.txt')),
          throwsA(isA<ImportTooLargeException>()),
        );
      },
    );
  });

  test('random guard', () => expect(Random(1).nextInt(2), lessThan(2)));
}
