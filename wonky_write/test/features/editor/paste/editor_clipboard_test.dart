import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_write/features/editor/commands/write_editor_commands.dart';
import 'package:wonky_write/features/editor/paste/clipboard_codec.dart';
import 'package:wonky_write/features/editor/paste/editor_clipboard.dart';
import 'package:wonky_write/features/editor/paste/system_clipboard.dart';

import '../support/editor_harness.dart';

void main() {
  late EditorHarness h;
  late EditorClipboard clipboard;
  late MemoryClipboard memory;

  void setUpWith(Delta delta) {
    h = EditorHarness(delta);
    memory = MemoryClipboard();
    clipboard = EditorClipboard(
      controller: h.controller,
      commands: WriteEditorCommands(h.controller),
      clipboard: memory,
    );
  }

  tearDown(() => h.dispose());

  final rich = Delta()
    ..insert('Title')
    ..insert('\n', {'header': 1})
    ..insert('item ')
    ..insert('bold', {'bold': true, 'cmt_t1': true})
    ..insert('\n', {'list': 'bullet'})
    ..insert({
      'table': {
        'id': 't1',
        'align': [null],
        'rows': [
          ['A'],
          ['1'],
        ],
      },
    })
    ..insert('\n');

  test(
    'Given a heading, list and table when copying and pasting into another document then it is reproduced (AC-23.1)',
    () async {
      setUpWith(rich);
      h.select(0, h.controller.length - 1);
      await clipboard.copy();

      expect(memory.content!.plainText, contains('# Title'));
      expect(memory.content!.html, contains('<h1'));
      expect(memory.content!.html, contains('data-wonky-delta'));

      final target = EditorHarness(Delta()..insert('\n'))..select(0);
      final targetClipboard = EditorClipboard(
        controller: target.controller,
        commands: WriteEditorCommands(target.controller),
        clipboard: memory,
      );
      await targetClipboard.paste();
      final pasted = target.delta;
      // Comments are never copied; embeds get new ids.
      expect(
        pasted.operations.any(
          (op) => op.attributes?.containsKey('cmt_t1') ?? false,
        ),
        isFalse,
      );
      expect(pasted.operations[0].data, 'Title');
      expect(
        pasted.operations.where((op) => op.data is Map).single.data,
        isNot(contains('t1')),
      );
      target.dispose();
    },
  );

  test('Given Markdown text when pasting then it is parsed', () {
    setUpWith(Delta()..insert('\n'));
    h.select(0);
    clipboard.pasteContent(
      const ClipboardContent(plainText: '## Heading\n\n- one\n- two\n'),
    );
    expect(h.delta.operations.first.data, 'Heading');
    expect(h.delta.operations[1].attributes, {'header': 2});
  });

  test(
    'Given a selected word when pasting a URL then the word becomes a link (§23.4)',
    () {
      setUpWith(Delta()..insert('read docs\n'));
      h.select(5, 9);
      clipboard.pasteContent(
        const ClipboardContent(plainText: 'https://x.dev'),
      );
      expect(
        h.delta,
        Delta()
          ..insert('read ')
          ..insert('docs', {'link': 'https://x.dev'})
          ..insert('\n'),
      );
    },
  );

  test(
    'Given a code block when pasting Markdown then it stays plain code lines (AC-23.3)',
    () {
      setUpWith(
        Delta()
          ..insert('x')
          ..insert('\n', {'code-block': 'dart'}),
      );
      h.select(1);
      clipboard.pasteContent(
        const ClipboardContent(plainText: '\n# not a heading\n**b**'),
      );
      expect(
        h.delta.operations.every(
          (op) =>
              op.attributes == null ||
              op.attributes!.keys.every((k) => k == 'code-block'),
        ),
        isTrue,
      );
      expect(h.plainText, 'x\n# not a heading\n**b**\n');
    },
  );

  test(
    'Given HTML from another app when pasting then bold and links are kept and underline dropped',
    () {
      setUpWith(Delta()..insert('\n'));
      h.select(0);
      clipboard.pasteContent(
        const ClipboardContent(
          plainText: 'Hello world',
          html:
              '<p><b>Hello</b> <u>world</u> <a href="https://x.dev">x</a></p>',
        ),
      );
      expect(
        h.delta.operations.first,
        Operation.insert('Hello', {'bold': true}),
      );
      expect(
        h.delta.operations.any(
          (op) => op.attributes?['link'] == 'https://x.dev',
        ),
        isTrue,
      );
      expect(
        h.delta.operations.any(
          (op) => op.attributes?.containsKey('underline') ?? false,
        ),
        isFalse,
      );
    },
  );

  test(
    'Given a selection when cutting then it is copied and removed in one step',
    () async {
      setUpWith(Delta()..insert('abc def\n'));
      h.select(0, 3);
      await clipboard.cut();
      expect(h.plainText, ' def\n');
      expect(h.changes.single.label, 'Cut');
      expect(memory.content!.plainText, 'abc');
    },
  );

  test(
    'Given plain text with Markdown-free lines when pasting without formatting then lines become paragraphs',
    () {
      setUpWith(Delta()..insert('\n'));
      h.select(0);
      clipboard.pasteContent(
        const ClipboardContent(plainText: '# a\nb'),
        plainOnly: true,
      );
      expect(h.plainText, '# a\nb\n');
    },
  );
}
