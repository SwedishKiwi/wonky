import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_rich_editor/wonky_rich_editor.dart';

const _codec = MarkdownDocumentCodec();

/// Writes [markdown] after reading it as if every block had been edited
/// (no remembered sources): the codec's own Markdown.
String _fresh(String markdown, {MarkdownDocumentCodec codec = _codec}) {
  final nodes = [
    for (final n in codec.decodeNodes(markdown))
      n.copyAndReplaceMetadata({
        for (final e in n.metadata.entries)
          if (!e.key.startsWith('wonky.md.') ||
              e.key == MarkdownNodeMetadata.raw ||
              e.key == MarkdownNodeMetadata.info ||
              e.key == MarkdownNodeMetadata.fence)
            e.key: e.value,
      }),
  ];
  return codec.encode(MutableDocument(nodes: nodes));
}

String _roundTrip(String markdown) => _codec.encode(_codec.decode(markdown));

/// Real task prompt bodies (specs/16 §10.1) and board posts.
const _prompts = [
  '''
## Goal

Let people pin a document to the top of **Recent** in Wonky Drive, so the
files they work on every day are one click away.

## Acceptance criteria
- [ ] A *Pin to top* command (`drive.item.pin`) on files and folders
- [ ] Pinned items show first in **Recent**, with a pin icon
- [x] Unpinning restores the normal order
- [ ] Works in light and dark, and with the keyboard

## Specs to read
- `specs/wonky_drive/03-ui.md` §4 (Recent)
- `specs/08-commands-and-undo.md`

## Likely code
- `wonky_drive/lib/features/recent/`
- `packages/wonky_app/lib/src/drive/drive_repository.dart`

## Out of scope
Sorting rules of the other views.

## Tests to add
1. A widget test for the pin command
2. A repository test for the order
   - pinned first
   - then by date''',
  '''
## Goal

Fix the crash when pasting a table from Excel into Wonky Sheets.

Steps to reproduce:

1. Copy `A1:C3` in Excel
2. Paste into an empty sheet
3. See the error toast

```dart
final rows = parseClipboard(html);
```

> The clipboard HTML has `<colgroup>` elements the parser does not expect.

See [the issue](https://github.com/serverpod/wonky/issues/42) and https://wonky.work/improvements/p/12 for details.

---

## Tests to add
- [ ] `test/clipboard/excel_paste_test.dart`''',
  'The button is ~~blue~~ *green* now, and `Mod+K` opens the link dialog.',
  '''
# Title

### Smaller

Text with **bold**, *italic*, ~~strike~~, `code` and a [link](https://example.com).
A second line in the same paragraph.

- one
- two
  - nested
    - deeper
- three

1. first
2. second
   1. inner
3. third''',
];

void main() {
  group('Given the codec when Markdown is read', () {
    test('then paragraphs, headings, lists, tasks, quotes, code and rules '
        'become their nodes', () {
      final nodes = _codec.decodeNodes(
        '# One\n\npara\n\n- a\n  - b\n1. c\n- [x] d\n\n> q\n\n```dart\nx\n```\n\n---\n',
      );
      expect(nodes.map(MarkdownDocumentCodec.kindOf), [
        'h1',
        'p',
        'ul',
        'ul',
        'ol',
        'task',
        'quote',
        'code',
        'hr',
        'p',
      ]);
      expect((nodes[3] as ListItemNode).indent, 1);
      expect((nodes[5] as TaskNode).isComplete, isTrue);
      expect(nodes[7].getMetadataValue(MarkdownNodeMetadata.info), 'dart');
    });

    test('then inline styles become attributions', () {
      final p =
          _codec.decodeNodes('a **b** *c* ~~d~~ `e` [f](https://x.y)').first
              as ParagraphNode;
      final t = p.text;
      expect(t.toPlainText(), 'a b c d e f');
      expect(t.hasAttributionAt(2, attribution: boldAttribution), isTrue);
      expect(t.hasAttributionAt(4, attribution: italicsAttribution), isTrue);
      expect(
        t.hasAttributionAt(6, attribution: strikethroughAttribution),
        isTrue,
      );
      expect(t.hasAttributionAt(8, attribution: codeAttribution), isTrue);
      expect(
        t
            .getAllAttributionsAt(10)
            .whereType<LinkAttribution>()
            .single
            .plainTextUri,
        'https://x.y',
      );
    });

    test('then the lines of a paragraph stay lines', () {
      final p = _codec.decodeNodes('one\ntwo **b**').single as ParagraphNode;
      expect(p.text.toPlainText(), 'one\ntwo b');
      expect(_fresh('one\ntwo **b**'), 'one\ntwo **b**');
    });

    test('then a comment field keeps headings, quotes and rules as text', () {
      const comment = MarkdownDocumentCodec(
        features: MarkdownBlockFeatures.comment,
      );
      final nodes = comment.decodeNodes('# Not a title\n> nor a quote\n---');
      expect(nodes.map(MarkdownDocumentCodec.kindOf), ['p']);
      expect(
        (nodes.single as ParagraphNode).text.toPlainText(),
        '# Not a title\n> nor a quote\n---',
      );
      expect(_fresh('# Not a title', codec: comment), r'\# Not a title');
    });
  });

  group('Given unsupported Markdown', () {
    const kept = [
      '| a | b |\n|---|---|\n| 1 | 2 |',
      '<details>\n<summary>More</summary>\nHidden\n</details>',
      'See ![the screenshot](https://x.y/s.png) here',
      'A <kbd>Ctrl</kbd> key',
      '[relative](/docs/a.md)',
      '[titled](https://x.y "Title")',
      '**bold\nacross lines**',
      '- > a quote in an item',
      '> - a list in a quote',
      '    indented code',
      '[ref]: https://x.y',
      '  ```\n  indented fence\n  ```',
    ];
    for (final source in kept) {
      test('when "${source.split('\n').first}" is written back after an edit '
          'then it is unchanged', () {
        final nodes = _codec.decodeNodes(source);
        expect(
          nodes.first.getMetadataValue(MarkdownNodeMetadata.raw),
          isTrue,
          reason: 'kept as a literal block',
        );
        expect(_fresh(source), source);
        expect(_roundTrip(source), source);
      });
    }

    test('when a literal block sits between paragraphs then the paragraphs '
        'stay editable', () {
      final nodes = _codec.decodeNodes('before\n\n| a |\n|---|\n\nafter');
      expect(nodes.map(MarkdownDocumentCodec.kindOf), ['p', 'raw', 'p']);
    });
  });

  group('Given Markdown written by the codec', () {
    const canonical = [
      'plain text',
      '**bold** and *italic* and ~~gone~~ and `code`',
      '[a link](https://example.com/path?q=1) and https://wonky.work/x',
      '# One\n\n## Two\n\n### Three',
      '- a\n- b\n  - c\n    - d\n- e',
      '1. a\n2. b\n   1. c\n   2. d\n3. e',
      '- [ ] open\n- [x] done\n  - [ ] nested',
      '> quoted *text*\n> on two lines',
      '> one\n>\n> two',
      '```dart\nvoid main() {}\n```',
      '````\n```\nnested fence\n```\n````',
      'a\n\n---\n\nb',
      'Use [optional] args, a | b, ~/path, 2 * 3 and snake_case.',
      r'Literal \*stars\* and # not a title',
      r'A \_ and a \` and \\ stay escaped',
      'Ends with a backtick \\` here',
      'email me at mailto:a@b.c or [mail](mailto:a@b.c)',
    ];
    for (final source in canonical) {
      test('when "${source.split('\n').first}" is read and written then it '
          'is unchanged', () {
        expect(_fresh(source), source);
      });
    }

    for (final (i, prompt) in _prompts.indexed) {
      test('when task prompt #$i is read and written then it is stable', () {
        // Untouched: exactly the source.
        expect(_roundTrip(prompt), prompt);
        // Rewritten: a fixed point after one pass.
        final once = _fresh(prompt);
        expect(_fresh(once), once);
        expect(_roundTrip(once), once);
      });
    }

    test('when a prompt is rewritten then only the blank lines around '
        'lists change', () {
      expect(
        _fresh(_prompts.first),
        _prompts.first
            .replaceAll('criteria\n- [ ]', 'criteria\n\n- [ ]')
            .replaceAll('read\n- ', 'read\n\n- ')
            .replaceAll('code\n- ', 'code\n\n- ')
            .replaceAll('scope\nSorting', 'scope\n\nSorting')
            .replaceAll('add\n1.', 'add\n\n1.'),
      );
    });

    test('when lists use other markers and numbers then they are '
        'normalized', () {
      expect(_fresh('* a\n+ b\n\n3. c\n7. d'), '- a\n- b\n1. c\n2. d');
      expect(_fresh('1) a\n1) b'), '1. a\n2. b');
    });

    test(
      'when an empty task item is in the template then it stays an item',
      () {
        const blank = '## Acceptance criteria\n\n- [ ] \n\n## Specs to read';
        expect(_fresh(blank), blank);
      },
    );
  });

  group('Given an edited document', () {
    test('when one block changes then the others keep their exact text', () {
      const source =
          '*   loose marker\n\n\nA  paragraph   with __old__ style.\n'
          'Second para line';
      final doc = _codec.decode(source);
      final last = doc.last as ParagraphNode;
      doc.replaceNodeById(
        last.id,
        last.copyParagraphWith(
          text: last.text.copyAndAppend(AttributedText(' edited')),
        ),
      );
      expect(
        _codec.encode(doc),
        '*   loose marker\n\n\n'
        'A  paragraph   with **old** style.\nSecond para line edited',
      );
    });

    test('when an item is inserted then the numbering after it follows', () {
      final doc = _codec.decode('1. a\n2. b\n3. c');
      doc.insertNodeAt(
        1,
        ListItemNode.ordered(id: 'new', text: AttributedText('new')),
      );
      expect(_codec.encode(doc), '1. a\n2. new\n3. b\n4. c');
    });

    test('when nodes are typed fresh then the default separators are used', () {
      final doc = MutableDocument(
        nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('Title'),
            metadata: {NodeMetadata.blockType: header2Attribution},
          ),
          ParagraphNode(id: '2', text: AttributedText('Intro')),
          ListItemNode.unordered(id: '3', text: AttributedText('a')),
          TaskNode(id: '4', text: AttributedText('b'), isComplete: false),
          ListItemNode.ordered(id: '5', text: AttributedText('c'), indent: 1),
          ParagraphNode(
            id: '6',
            text: AttributedText('q1'),
            metadata: {NodeMetadata.blockType: blockquoteAttribution},
          ),
          ParagraphNode(
            id: '7',
            text: AttributedText('q2'),
            metadata: {NodeMetadata.blockType: blockquoteAttribution},
          ),
          ParagraphNode(id: '8', text: AttributedText('')),
          HorizontalRuleNode(id: '9'),
          ParagraphNode(
            id: '10',
            text: AttributedText('x = 1'),
            metadata: {NodeMetadata.blockType: codeAttribution},
          ),
        ],
      );
      expect(
        _codec.encode(doc),
        '## Title\n\nIntro\n\n- a\n- [ ] b\n  1. c\n\n> q1\n>\n> q2\n\n'
        '---\n\n```\nx = 1\n```',
      );
    });

    test('when a link has no scheme or an unsafe one then it is fixed or '
        'dropped', () {
      final text = AttributedText('a b')
        ..addAttribution(LinkAttribution('example.com'), const SpanRange(0, 0))
        ..addAttribution(
          LinkAttribution('javascript:alert(1)'),
          const SpanRange(2, 2),
        );
      final doc = MutableDocument(
        nodes: [ParagraphNode(id: '1', text: text)],
      );
      expect(_codec.encode(doc), '[a](https://example.com) b');
    });

    test('when text has leading or trailing spaces then they are trimmed '
        'rather than written as entities', () {
      final doc = MutableDocument(
        nodes: [ParagraphNode(id: '1', text: AttributedText('  hi  \nyo '))],
      );
      expect(_codec.encode(doc), 'hi\nyo');
    });
  });
}
