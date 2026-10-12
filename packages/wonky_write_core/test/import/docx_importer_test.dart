import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _r =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

/// A Word-like package built from [body] (inner XML of `w:body`).
Uint8List wordDocx(
  String body, {
  String styles = _styles,
  String numbering = _numbering,
  String? comments,
  Map<String, Uint8List> media = const {},
  String extraRels = '',
}) {
  const rel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  return DeterministicZip.encode([
    ZipEntry.text(
      '[Content_Types].xml',
      '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="xml" ContentType="application/xml"/></Types>',
    ),
    ZipEntry.text(
      '_rels/.rels',
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="$rel/officeDocument" Target="word/document.xml"/>'
          '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
          '</Relationships>',
    ),
    ZipEntry.text(
      'docProps/core.xml',
      '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
          'xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Word title</dc:title>'
          '<dc:language>de-DE</dc:language></cp:coreProperties>',
    ),
    ZipEntry.text(
      'word/_rels/document.xml.rels',
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rS" Type="$rel/styles" Target="styles.xml"/>'
          '<Relationship Id="rN" Type="$rel/numbering" Target="numbering.xml"/>'
          '<Relationship Id="rL" Type="$rel/hyperlink" Target="https://example.com/x" TargetMode="External"/>'
          '${comments == null ? '' : '<Relationship Id="rC" Type="$rel/comments" Target="comments.xml"/>'}'
          '$extraRels</Relationships>',
    ),
    ZipEntry.text('word/styles.xml', styles),
    ZipEntry.text('word/numbering.xml', numbering),
    if (comments != null) ZipEntry.text('word/comments.xml', comments),
    for (final m in media.entries) ZipEntry('word/${m.key}', m.value),
    ZipEntry.text(
      'word/document.xml',
      '<w:document xmlns:w="$_w" xmlns:r="$_r" '
          'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
          'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
          'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
          '<w:body>$body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
          '<w:pgMar w:top="1440" w:right="1080" w:bottom="1440" w:left="1080"/></w:sectPr>'
          '</w:body></w:document>',
    ),
  ]);
}

const _styles =
    '<w:styles xmlns:w="$_w">'
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/>'
    '<w:rPr><w:rFonts w:ascii="Calibri"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="berschrift1"><w:name w:val="heading 1"/>'
    '<w:basedOn w:val="Normal"/><w:rPr><w:b/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="MyHeading"><w:name w:val="Custom outline"/>'
    '<w:pPr><w:outlineLvl w:val="2"/></w:pPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Zitat"><w:name w:val="Quote"/></w:style>'
    '<w:style w:type="paragraph" w:styleId="Code"><w:name w:val="HTML Preformatted"/></w:style>'
    '<w:style w:type="character" w:styleId="Strong"><w:name w:val="Strong"/><w:rPr><w:b/></w:rPr></w:style>'
    '<w:style w:type="character" w:styleId="Mono"><w:name w:val="Mono"/>'
    '<w:rPr><w:rFonts w:ascii="Consolas"/></w:rPr></w:style>'
    '</w:styles>';

const _numbering =
    '<w:numbering xmlns:w="$_w">'
    '<w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/></w:lvl>'
    '<w:lvl w:ilvl="1"><w:numFmt w:val="decimal"/><w:lvlText w:val="%2."/></w:lvl></w:abstractNum>'
    '<w:abstractNum w:abstractNumId="1"><w:lvl w:ilvl="0"><w:start w:val="4"/><w:numFmt w:val="decimal"/>'
    '<w:lvlText w:val="%1."/></w:lvl></w:abstractNum>'
    '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
    '<w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>'
    '</w:numbering>';

String _p(String inner, {String? style, String? numPr}) =>
    '<w:p><w:pPr>${style == null ? '' : '<w:pStyle w:val="$style"/>'}'
    '${numPr ?? ''}</w:pPr>$inner</w:p>';

String _t(String text, {String rPr = ''}) =>
    '<w:r>${rPr.isEmpty ? '' : '<w:rPr>$rPr</w:rPr>'}'
    '<w:t xml:space="preserve">$text</w:t></w:r>';

String _num(int id, int level) =>
    '<w:numPr><w:ilvl w:val="$level"/><w:numId w:val="$id"/></w:numPr>';

void main() {
  ImportOptions opts() {
    var n = 0;
    return ImportOptions(idGenerator: () => 'id${n++}', fileName: 'w.docx');
  }

  String mdOf(ImportResult r) => const MarkdownCodec().exportMarkdown(r.delta);

  group('Given a Word document', () {
    test('when importing then styles map to headings, quotes and code', () {
      final docx = wordDocx(
        _p(_t('Title'), style: 'berschrift1') +
            _p(_t('Outline'), style: 'MyHeading') +
            _p(
              _t('Plain ') +
                  _t('bold', rPr: '<w:b/>') +
                  _t('Strong', rPr: '<w:rStyle w:val="Strong"/>') +
                  _t(' ') +
                  _t('it', rPr: '<w:i/>') +
                  _t(' ') +
                  _t('gone', rPr: '<w:strike/>') +
                  _t(' ') +
                  _t('code', rPr: '<w:rStyle w:val="Mono"/>'),
            ) +
            _p(_t('Wise words'), style: 'Zitat') +
            _p(_t('int x = 1;'), style: 'Code') +
            _p(_t('  return x;'), style: 'Code'),
      );

      final r = const DocxImporter().importSync(docx, opts());

      expect(
        mdOf(r),
        '# Title\n\n### Outline\n\n'
        'Plain **boldStrong** *it* ~~gone~~ `code`\n\n'
        '> Wise words\n\n```\nint x = 1;\n  return x;\n```\n',
      );
      expect(r.title, 'Word title');
      expect(r.language, 'de-DE');
      expect(r.pageSetup!.widthPt, closeTo(595.3, 0.1));
      expect(r.pageSetup!.marginLeftPt, 54);
    });

    test('when importing numbering then lists nest and starts warn', () {
      final docx = wordDocx(
        _p(_t('Bullet'), numPr: _num(1, 0)) +
            _p(_t('Nested number'), numPr: _num(1, 1)) +
            _p(_t('Starts at four'), numPr: _num(2, 0)) +
            _p(_t('☐ open task'), numPr: _num(1, 0)) +
            _p(_t('☒ done task')),
      );

      final r = const DocxImporter().importSync(docx, opts());

      expect(
        mdOf(r),
        '- Bullet\n  1. Nested number\n1. Starts at four\n'
        '- [ ] open task\n- [x] done task\n',
      );
      expect(
        r.warnings.map((w) => w.kind),
        contains(ImportWarningKind.orderedListStart),
      );
    });

    test('when importing links, tables and images then they are kept', () {
      final png = img.encodePng(img.Image(width: 3, height: 3));
      final link = _p('<w:hyperlink r:id="rL">${_t('a link')}</w:hyperlink>');
      final drawing = _p(
        '<w:r><w:drawing><wp:inline><wp:extent cx="1" cy="1"/>'
        '<wp:docPr id="1" name="p" descr="A picture"/><a:graphic><a:graphicData>'
        '<pic:pic><pic:blipFill><a:blip r:embed="rI"/></pic:blipFill></pic:pic>'
        '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>',
      );
      final docx = wordDocx(
        '$link<w:tbl><w:tr><w:tc>${_p(_t('H1'))}</w:tc><w:tc>'
        '<w:p><w:pPr><w:jc w:val="right"/></w:pPr>${_t('H2')}</w:p></w:tc></w:tr>'
        '<w:tr><w:tc><w:tcPr><w:gridSpan w:val="2"/></w:tcPr>${_p(_t('wide'))}</w:tc></w:tr></w:tbl>'
        '$drawing',
        media: {'media/p.png': Uint8List.fromList(png)},
        extraRels:
            '<Relationship Id="rI" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/p.png"/>',
      );

      final r = const DocxImporter().importSync(docx, opts());

      expect(
        mdOf(r),
        '[a link](https://example.com/x)\n\n| H1 | H2 |\n| --- | ---: |\n'
        '| wide |  |\n\n![A picture](import-image://img1)\n',
      );
      expect(r.images.single.mime, 'image/png');
      expect(
        r.warnings.map((w) => w.kind),
        contains(ImportWarningKind.tableFlattened),
      );
    });

    test('when the document has comments and formatting then it warns', () {
      final docx = wordDocx(
        _p(
          '<w:commentRangeStart w:id="0"/>${_t('Noted', rPr: '<w:u w:val="single"/><w:color w:val="FF0000"/>')}'
          '<w:commentRangeEnd w:id="0"/><w:r><w:commentReference w:id="0"/></w:r>',
        ),
        comments:
            '<w:comments xmlns:w="$_w"><w:comment w:id="0"><w:p><w:r><w:t>Hm</w:t></w:r></w:p></w:comment></w:comments>',
      );

      final r = const DocxImporter().importSync(docx, opts());

      expect(mdOf(r), 'Noted\n');
      final kinds = r.warnings.map((w) => w.kind);
      expect(kinds, contains(ImportWarningKind.commentsDropped));
      expect(kinds, contains(ImportWarningKind.formattingRemoved));
    });

    test(
      'when the dispatcher sees a DOCX then it uses the DOCX importer',
      () async {
        final docx = wordDocx(_p(_t('Hello')));
        final r = await const WonkyImporters().import(docx, opts());
        expect(mdOf(r), 'Hello\n');
        expect(ImportFormatDetector.detect(docx).isSupported, isTrue);
      },
    );

    test('when the bytes are not a package then it throws a format error', () {
      expect(
        () => const DocxImporter().importSync(
          Uint8List.fromList([1, 2, 3]),
          opts(),
        ),
        throwsA(isA<ImportFormatException>()),
      );
    });
  });
}
