import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart' show Delta;
import 'package:wonky_slides_core/clipboard.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_sync_models/ids.dart';

const _slide = SuRect(0, 0, 1920, 1080);

Matcher _has(Map<String, Object?> op) => predicate<List<Object?>>(
  (ops) => ops.any((o) => equals(op).matches(o, {})),
  'contains $op',
);

void main() {
  group('Given a Slides text body', () {
    test('when rendered as HTML then styles, lists and inline formatting '
        'become tags', () {
      final d = Delta()
        ..insert('Title')
        ..insert('\n', {'style': 'title'})
        ..insert('one ')
        ..insert('bold', {'bold': true})
        ..insert('\n', {'list': 'bullet'})
        ..insert('nested')
        ..insert('\n', {'list': 'bullet', 'indent': 1})
        ..insert('<b>')
        ..insert('\n');
      expect(
        SlidesHtml.ofDelta(d),
        '<h1>Title</h1><ul><li>one <b>bold</b><ul><li>nested</li></ul>'
        '</li></ul><p>&lt;b&gt;</p>',
      );
    });
  });

  group('Given a copied elements payload', () {
    late Map<String, Object?> payload;
    setUp(() {
      final b = DeckBuilder();
      final s = b.slide(layoutKey: 'blank');
      b.textBox(s, 'Hello');
      final (t, rows, cols) = b.table(s);
      b.cell(t, rows[0], cols[0], 'A1');
      b.cell(t, rows[1], cols[1], 'B2');
      final model = b.build();
      payload = SlidesClipboardCodec.copyElements(model, [
        for (final e in model.elementsOf(s)) e.id,
      ]);
    });

    test('when written as HTML then the payload is embedded and decodes '
        'back losslessly', () {
      final html = SlidesHtml.ofPayload(payload);
      expect(html, contains('data-wonky-slides="'));
      expect(html, contains('<p>Hello</p>'));
      expect(html, contains('<table><tbody><tr><td>A1</td><td></td></tr>'));
      final back = SlidesHtml.payloadOf(html)!;
      expect(back['kind'], 'elements');
      expect(
        (back['elements']! as List).length,
        (payload['elements']! as List).length,
      );
    });

    test('when the HTML table is read back then it is a 2 × 2 grid', () {
      final grid = SlidesHtml.tableOf(
        SlidesClipboardCodec.htmlBody({
          ...payload,
          'elements': [
            for (final e in payload['elements']! as List)
              if ((e as Map)[SlidesCols.kind] == 'table') e,
          ],
        }),
      )!;
      expect(
        [
          for (final r in grid) [for (final c in r) c.text],
        ],
        [
          ['A1', ''],
          ['', 'B2'],
        ],
      );
    });
  });

  group('Given clipboard HTML from Wonky Write', () {
    test('when it carries data-wonky-delta then the Delta is decoded', () {
      final delta = [
        {'insert': 'Hi'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
      ];
      final html =
          '<div data-wonky-delta="'
          '${base64Url.encode(utf8.encode(jsonEncode(delta)))}"><h1>Hi</h1>'
          '</div>';
      expect(SlidesHtml.writeDeltaOf(html)!.toJson(), delta);
      expect(SlidesHtml.payloadOf(html), isNull);
    });
  });

  group('Given a Sheets cells table', () {
    const html =
        '<meta charset="utf-8"><style>br{}</style>'
        '<table data-wonky-clip="x"><colgroup><col width="100"/></colgroup>'
        '<tbody><tr><td style="font-weight:bold;color:#ff0000;'
        'text-align:center" colspan="2">Head</td></tr>'
        '<tr><td style="background-color:rgb(0, 128, 255)">1</td>'
        '<td style="font-style:italic">2</td></tr></tbody></table>';

    test('when read then values, formatting and the merge are mapped', () {
      final grid = SlidesHtml.tableOf(html)!;
      expect(grid.length, 2);
      expect(grid[0].length, 2);
      final head = grid[0][0];
      expect(
        (head.text, head.bold, head.color, head.align, head.colSpan),
        ('Head', true, '#ff0000', 'center', 2),
      );
      expect(grid[0][1].text, '');
      expect(grid[1][0].fill, '#0080ff');
      expect(grid[1][1].italic, isTrue);
    });

    test('when mapped then a table element with a merged header arrives', () {
      final r = SlidesPasteMappers.html(
        html,
        slide: _slide,
        ids: SequentialIdGenerator(100),
      );
      expect(r.elements.single[SlidesCols.kind], 'table');
      final cells = (r.payload['tableCells']! as List)
          .cast<Map<String, Object?>>();
      expect(cells.where((c) => c[TableCellCols.colSpan] == 2).length, 1);
    });
  });

  group('Given rich HTML from another app', () {
    const html =
        '<b style="font-weight:normal" id="docs-internal-guid">'
        '<h1>Plan</h1><p>Some <strong>bold</strong> and '
        '<a href="https://example.com">a link</a></p>'
        '<ul><li>one<ul><li>two</li></ul></li></ul>'
        '<p><img src="https://example.com/a.png" alt="A"></p>'
        '<pre><code class="language-dart">main() {}\n</code></pre>'
        '<p style="font-family:Comic Sans">styled</p></b>';

    test('when imported then headings, lists, links, images and code are '
        'Write blocks', () {
      final r = SlidesHtml.importHtml(html);
      expect(r.dropped, isTrue);
      final ops = r.delta.toJson();
      expect(
        ops,
        _has({
          'insert': '\n',
          'attributes': {'header': 1},
        }),
      );
      expect(
        ops,
        _has({
          'insert': 'bold',
          'attributes': {'bold': true},
        }),
      );
      expect(
        ops,
        _has({
          'insert': 'a link',
          'attributes': {'link': 'https://example.com'},
        }),
      );
      expect(
        ops,
        _has({
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 1},
        }),
      );
      expect(
        ops,
        _has({
          'insert': {
            'image': {'src': 'https://example.com/a.png', 'alt': 'A'},
          },
        }),
      );
      expect(
        ops,
        _has({
          'insert': '\n',
          'attributes': {'code-block': 'dart'},
        }),
      );
      // "Plan" is not bold although the whole fragment is in <b>.
      expect(ops.first, {'insert': 'Plan'});
    });

    test('when mapped then a text box, an image and a code element arrive', () {
      final r = SlidesPasteMappers.html(
        html,
        slide: _slide,
        ids: SequentialIdGenerator(100),
      );
      expect(
        [for (final e in r.elements) e[SlidesCols.kind]],
        ['text', 'image', 'code', 'text'],
      );
      expect(r.warnings, containsAll(['remote_images', 'formatting_dropped']));
      final text = SlidesText.parse(
        r.elements.first[SlidesCols.text] as String,
      );
      expect(text.toJson().first, {'insert': 'Plan'});
    });
  });

  group('Given Write rich text pasted into a text body', () {
    test('when mapped then embeds are dropped and code becomes paragraphs', () {
      final write = Delta()
        ..insert('Head')
        ..insert('\n', {'header': 2})
        ..insert({
          'image': {'src': 'wonky-file://x'},
        })
        ..insert('code')
        ..insert('\n', {'code-block': 'dart'})
        ..insert('item')
        ..insert('\n', {'list': 'ordered'});
      expect(SlidesPasteMappers.writeText(write).toJson(), [
        {'insert': 'Head'},
        {
          'insert': '\n',
          'attributes': {'style': 'heading'},
        },
        {'insert': 'code\nitem'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
      ]);
    });
  });
}
