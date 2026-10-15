import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_rich_editor/wonky_rich_editor.dart';

/// Drives a [MarkdownEditingController] the way typing does.
class _Field {
  _Field([
    String markdown = '',
    MarkdownBlockFeatures features = MarkdownBlockFeatures.all,
  ]) : c = MarkdownEditingController(markdown: markdown, features: features) {
    c.moveCaretToEnd();
  }

  final MarkdownEditingController c;

  String get md => c.markdown;

  void type(String text) {
    for (final char in text.split('')) {
      if (char == '\n') {
        c.editor.execute([InsertNewlineAtCaretRequest()]);
      } else {
        c.editor.execute([InsertCharacterAtCaretRequest(character: char)]);
      }
    }
  }

  void backspace() => c.editor.execute([const DeleteUpstreamRequest()]);

  /// Selects [start]…[end] of block [index].
  void select(int index, int start, [int? end]) {
    final id = c.document.getNodeAt(index)!.id;
    c.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: id,
            nodePosition: TextNodePosition(offset: start),
          ),
          extent: DocumentPosition(
            nodeId: id,
            nodePosition: TextNodePosition(offset: end ?? start),
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  List<String> get kinds =>
      c.document.map(MarkdownDocumentCodec.kindOf).toList();

  void dispose() => c.dispose();
}

void main() {
  late _Field f;
  tearDown(() => f.dispose());

  group('Given Markdown set on the controller', () {
    test('when nothing is edited then the text is returned exactly', () {
      const source = '*  loose*   **text**\n\n\n- a\n* b';
      f = _Field(source);
      expect(f.md, source);
      expect(f.c.isEmpty, isFalse);
    });

    test('when it is replaced then the new text is returned exactly and '
        'listeners hear it', () {
      f = _Field('old');
      var heard = 0;
      f.c.addListener(() => heard++);
      f.c.markdown = '# new';
      expect(f.md, '# new');
      expect(f.kinds, ['h1']);
      expect(heard, greaterThan(0));
    });
  });

  group('Given typing (Write 04 §7)', () {
    final blocks = {
      '# Title': '# Title',
      '### Small': '### Small',
      '- item': '- item',
      '* item': '- item',
      '1. first': '1. first',
      '[] task': '- [ ] task',
      '[x] done': '- [x] done',
      '- [ ] task': '- [ ] task',
      '> quoted': '> quoted',
      '```dart code': '```dart\ncode\n```',
    };
    for (final MapEntry(key: typed, value: written) in blocks.entries) {
      test('when typing "$typed" then the block is "$written"', () {
        f = _Field();
        f.type(typed);
        expect(f.md, written);
      });
    }

    test('when typing --- and a space then a rule is inserted', () {
      f = _Field();
      f.type('--- after');
      expect(f.kinds, ['hr', 'p']);
      expect(f.md, '---\n\nafter');
    });

    final inline = {
      'a **bold** b': 'a **bold** b',
      'a *it* b': 'a *it* b',
      'a `code` b': 'a `code` b',
      'a ~~gone~~ b': 'a ~~gone~~ b',
      'see https://wonky.work now': 'see https://wonky.work now',
      'a __strong__ b': 'a **strong** b',
      'a _em_ b': 'a *em* b',
      'snake_case_name': 'snake_case_name',
      '2*3*4': r'2\*3\*4',
      'see [docs](wonky.work) x': 'see [docs](https://wonky.work) x',
      '[bad](javascript:x) y': r'\[bad\](javascript:x) y',
    };
    for (final MapEntry(key: typed, value: written) in inline.entries) {
      test('when typing "$typed" then it is "$written"', () {
        f = _Field();
        f.type(typed);
        expect(f.md, written);
        expect(f.c.document.first, isA<ParagraphNode>());
      });
    }

    test('when typing Markdown in a code block then it stays text', () {
      f = _Field();
      f.type('``` # not **bold**');
      expect(f.kinds, ['code']);
      expect(f.md, '```\n# not **bold**\n```');
    });

    test('when typing in a comment field then headings and quotes stay '
        'text', () {
      f = _Field('', MarkdownBlockFeatures.comment);
      f.type('# no\n> no');
      expect(f.kinds, ['p', 'p']);
      expect(f.md, '\\# no\n\n\\> no');
    });

    test('when Enter follows a list item then the next item continues the '
        'list, and Enter on an empty item ends it', () {
      f = _Field();
      f.type('- a\nb\n\nafter');
      expect(f.md, '- a\n- b\n\nafter');
    });
  });

  group('Given the toolbar actions', () {
    test('when bold is toggled on a selection then it is added, shown as '
        'active and removed again', () {
      f = _Field('hello world');
      f.select(0, 6, 11);
      expect(f.c.isActive(InlineFormat.bold), isFalse);
      f.c.toggleInline(InlineFormat.bold);
      expect(f.md, 'hello **world**');
      expect(f.c.isActive(InlineFormat.bold), isTrue);
      f.c.toggleInline(InlineFormat.bold);
      expect(f.md, 'hello world');
    });

    test('when code is applied then bold goes', () {
      f = _Field('**ab**');
      f.select(0, 0, 2);
      f.c.toggleInline(InlineFormat.code);
      expect(f.md, '`ab`');
    });

    test(
      'when a style is toggled at the caret then the next typing has it',
      () {
        f = _Field('a');
        f.c.toggleInline(InlineFormat.italic);
        expect(f.c.isActive(InlineFormat.italic), isTrue);
        f.type('b');
        expect(f.md, 'a*b*');
      },
    );

    test('when list, task, quote and code blocks are toggled then the '
        'blocks change and change back', () {
      f = _Field('one\n\ntwo');
      f.c.selectAll();
      f.c.toggleBlock(BlockFormat.bulletList);
      expect(f.md, '- one\n- two');
      expect(f.c.blockFormat, BlockFormat.bulletList);
      f.c.toggleBlock(BlockFormat.numberedList);
      expect(f.md, '1. one\n2. two');
      f.c.toggleBlock(BlockFormat.taskList);
      expect(f.md, '- [ ] one\n- [ ] two');
      f.c.toggleBlock(BlockFormat.taskList);
      expect(f.md, 'one\n\ntwo');
      f.c.toggleBlock(BlockFormat.quote);
      expect(f.md, '> one\n>\n> two');
      f.c.toggleBlock(BlockFormat.codeBlock);
      expect(f.md, '```\none\ntwo\n```');
      expect(f.kinds, ['code']);
    });

    test('when a comment field is asked for a quote then nothing happens', () {
      f = _Field('x', MarkdownBlockFeatures.comment);
      expect(f.c.canFormatBlock(BlockFormat.quote), isFalse);
      f.c.toggleBlock(BlockFormat.quote);
      expect(f.md, 'x');
    });

    test('when items are indented then they nest', () {
      f = _Field('- a\n- b');
      f.select(1, 1);
      expect(f.c.indentItems(), isTrue);
      expect(f.md, '- a\n  - b');
      expect(f.c.indentItems(outdent: true), isTrue);
      expect(f.md, '- a\n- b');
    });
  });

  group('Given links', () {
    test('when a selection gets a link then it is written, read at the '
        'caret, changed and removed', () {
      f = _Field('see docs');
      f.select(0, 4, 8);
      f.c.setLink('wonky.work');
      expect(f.md, 'see [docs](https://wonky.work)');
      f.select(0, 6);
      expect(f.c.link, 'https://wonky.work');
      f.c.setLink('https://wonky.work/b');
      expect(f.md, 'see [docs](https://wonky.work/b)');
      f.select(0, 8);
      f.c.setLink(null);
      expect(f.md, 'see docs');
    });

    test('when there is no selection then the URL is inserted as a link', () {
      f = _Field('mail');
      f.type(' ');
      f.c.setLink('a@b.co');
      expect(f.md, 'mail [a@b.co](mailto:a@b.co)');
    });

    test('when the URL is not a link then nothing changes', () {
      f = _Field('x');
      f.select(0, 0, 1);
      f.c.setLink('javascript:alert(1)');
      expect(f.md, 'x');
    });
  });

  group('Given paste', () {
    test('when Markdown is pasted then it becomes blocks and styles', () {
      f = _Field('start');
      f.type(' ');
      f.c.paste('**bold** text\n\n- one\n- two');
      expect(f.md, 'start **bold** text\n\n- one\n- two');
    });

    test('when plain text is pasted then it is inserted as is', () {
      f = _Field('');
      f.c.paste('**not bold**', plain: true);
      expect(f.md, r'\*\*not bold\*\*');
    });

    test('when a URL is pasted over a selection then it becomes a link', () {
      f = _Field('the docs');
      f.select(0, 4, 8);
      f.c.paste('https://wonky.work');
      expect(f.md, 'the [docs](https://wonky.work)');
    });

    test('when the paste is too long then it is refused', () {
      f = _Field('abc');
      f.c.maxLength = 5;
      expect(f.c.paste('defg'), isFalse);
      expect(f.md, 'abc');
    });
  });

  group('Given the field history', () {
    test('when undoing and redoing then typing, formatting and replacing '
        'are steps of their own', () {
      f = _Field();
      withClock(Clock.fixed(DateTime(2026)), () => f.type('hello'));
      expect(f.md, 'hello');
      f.c.selectAll();
      f.c.toggleInline(InlineFormat.bold);
      expect(f.md, '**hello**');
      f.c.undo();
      expect(f.md, 'hello');
      f.c.undo();
      expect(f.md, '');
      expect(f.c.canUndo, isFalse);
      f.c.redo();
      expect(f.md, 'hello');
      f.c.redo();
      expect(f.md, '**hello**');
      expect(f.c.canRedo, isFalse);
    });

    test('when undoing an autoformat then the typed text is back', () {
      f = _Field();
      withClock(Clock.fixed(DateTime(2026)), () => f.type('##'));
      f.type(' ');
      expect(f.kinds, ['h2']);
      f.c.undo();
      expect(f.kinds, ['p']);
      expect(f.md, r'\##');
    });
  });

  group('Given limits', () {
    test('when the Markdown reaches the max length then typing is refused', () {
      f = _Field('abcd');
      f.c.maxLength = 5;
      f.type('ef');
      expect(f.md, 'abcde');
    });

    test('when read-only then typing changes nothing', () {
      f = _Field('abc');
      f.c.readOnly = true;
      f.type('d');
      f.backspace();
      expect(f.md, 'abc');
    });
  });
}
