import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_write/features/editor/applier/delta_applier.dart';
import 'package:wonky_write/features/editor/controller/editor_types.dart';

import '../support/editor_harness.dart';

void main() {
  late EditorHarness h;
  tearDown(() => h.dispose());

  group('Auto-pair (Write 04 §9)', () {
    test('when typing ( then the pair is inserted with the caret inside', () {
      h = EditorHarness.text('a [] b');
      h.select(2);
      h.type('(');
      expect(h.plainText, 'a () b\n');
      expect(h.selection, const DeltaSelection.collapsed(3));
    });

    test('when typing the closer then it overtypes the auto-inserted one', () {
      h = EditorHarness(Delta()..insert('\n'))..select(0);
      h.type('(x)');
      expect(h.plainText, '(x)\n');
    });

    test(
      'when pressing Backspace in an empty pair then both characters go',
      () {
        h = EditorHarness(Delta()..insert('\n'))..select(0);
        h.type('[');
        h.backspace();
        expect(h.plainText, '\n');
      },
    );

    test(
      'when typing a backtick over "foo" then it becomes inline code without backticks (AC-9.1)',
      () {
        h = EditorHarness(Delta()..insert('a foo b\n'))..select(2, 5);
        h.type('`');
        expect(
          h.delta,
          Delta()
            ..insert('a ')
            ..insert('foo', {'code': true})
            ..insert(' b\n'),
        );
      },
    );

    test('when typing ( over a selection then it is wrapped', () {
      h = EditorHarness(Delta()..insert('a foo b\n'))..select(2, 5);
      h.type('(');
      expect(h.plainText, 'a (foo) b\n');
    });

    test('with auto-pair off when typing ( then no closer is added', () {
      h = EditorHarness(
        Delta()..insert('\n'),
        preferences: const WriteEditorPreferences(autoPair: false),
      )..select(0);
      h.type('(');
      expect(h.plainText, '(\n');
    });
  });

  group('Markdown autoformat with multi-character insertions (Write 04 §7)', () {
    void insertAtCaret(EditorHarness h, String text) {
      final caret = h.editor.composer.selection!.extent;
      h.editor.execute([
        InsertTextRequest(
          documentPosition: caret,
          textToInsert: text,
          attributions: const {},
        ),
      ]);
    }

    test('when an IME inserts "## " at once then the paragraph becomes a '
        'heading', () {
      h = EditorHarness(Delta()..insert('\n'))..select(0);
      insertAtCaret(h, '## ');
      expect(h.delta, Delta()..insert('\n', {'header': 2}));
    });

    test('when an IME inserts "**bold**" at once then it becomes bold', () {
      h = EditorHarness(Delta()..insert('a \n'))..select(2);
      insertAtCaret(h, '**bold**');
      expect(
        h.delta,
        Delta()
          ..insert('a ')
          ..insert('bold', {'bold': true})
          ..insert('\n'),
      );
    });

    test('when pasting "## " then nothing is converted', () {
      h = EditorHarness(Delta()..insert('\n'))..select(0);
      h.controller.applyLocal(Delta()..insert('## '), label: 'Paste');
      expect(h.plainText, '## \n');
    });
  });

  group('Smart typography (Write 04 §8)', () {
    test(
      'when undoing right after a smart quote then the straight quote comes back (AC-8.1)',
      () {
        h = EditorHarness(Delta()..insert('\n'))..select(0);
        h.type('"Hi,"');
        final smart = h.changes.last;
        expect(smart.label, 'Smart quote');
        h.undo(smart);
        expect(h.plainText, '“Hi,"\n');
      },
    );

    test('in a code block nothing is converted', () {
      h = EditorHarness(Delta()..insert('\n', {'code-block': ''}))..select(0);
      h.type('"a" -- ...');
      expect(h.plainText, '"a" -- ...\n');
    });
  });

  group('Mentions (Write 04 §19.3)', () {
    final mention = Delta()
      ..insert('hi ')
      ..insert('@Anna', {'mention': 'u', 'link': 'mailto:a@x.dev'})
      ..insert(' there\n');

    test(
      'when one character of a mention is deleted (IME) then the whole mention goes',
      () {
        h = EditorHarness(mention);
        final node = h.controller.document.first as TextNode;
        h.editor.execute([
          DeleteContentRequest(
            documentRange: DocumentRange(
              start: DocumentPosition(
                nodeId: node.id,
                nodePosition: const TextNodePosition(offset: 7),
              ),
              end: DocumentPosition(
                nodeId: node.id,
                nodePosition: const TextNodePosition(offset: 8),
              ),
            ),
          ),
        ]);
        expect(h.plainText, 'hi  there\n');
      },
    );

    test(
      'when placing the caret inside a mention then it snaps to the nearest edge',
      () {
        h = EditorHarness(mention)..select(4);
        expect(h.selection, const DeltaSelection.collapsed(3));
        h.select(7);
        expect(h.selection, const DeltaSelection.collapsed(8));
      },
    );

    test(
      'when typing at a mention end then the text is not part of the mention',
      () {
        h = EditorHarness(mention)..select(8);
        h.type('x');
        expect(h.delta.operations[2].data, 'x there\n');
      },
    );
  });

  group('Typing attributes (Write 04 §10.3)', () {
    test('when typing at the end of a link then the link does not grow', () {
      h = EditorHarness(
        Delta()
          ..insert('link', {'link': 'https://x.dev'})
          ..insert('\n'),
      )..select(4);
      h.type('s');
      expect(
        h.delta,
        Delta()
          ..insert('link', {'link': 'https://x.dev'})
          ..insert('s\n'),
      );
    });

    test('when typing inside a link then it grows', () {
      h = EditorHarness(
        Delta()
          ..insert('link', {'link': 'https://x.dev'})
          ..insert('\n'),
      )..select(2);
      h.type('x');
      expect(h.delta.operations.first.data, 'lixnk');
    });

    test(
      'when typing inside a comment anchor then it extends, at its edge it does not',
      () {
        h = EditorHarness(
          Delta()
            ..insert('abc', {'cmt_t': true})
            ..insert('\n'),
        )..select(1);
        h.type('x');
        h.select(4);
        h.type('y');
        expect(
          h.delta,
          Delta()
            ..insert('axbc', {'cmt_t': true})
            ..insert('y\n'),
        );
      },
    );

    test('when typing after bold text then the new text is bold', () {
      h = EditorHarness(
        Delta()
          ..insert('bold', {'bold': true})
          ..insert('\n'),
      )..select(4);
      h.type('er');
      expect(h.delta.operations.first.data, 'bolder');
    });
  });

  group('Schema guard (Write 04 §2.4)', () {
    test(
      'when a tab is typed outside code then it becomes four spaces in the same step',
      () {
        h = EditorHarness(Delta()..insert('a\n'))..select(1);
        h.type('\t');
        expect(h.plainText, 'a    \n');
        expect(h.changes, hasLength(1));
      },
    );

    test('when underline is applied then it is removed', () {
      h = EditorHarness(Delta()..insert('abc\n'));
      final node = h.controller.document.first;
      h.editor.execute([
        AddTextAttributionsRequest(
          documentRange: DocumentRange(
            start: DocumentPosition(
              nodeId: node.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
            end: DocumentPosition(
              nodeId: node.id,
              nodePosition: const TextNodePosition(offset: 3),
            ),
          ),
          attributions: {underlineAttribution},
        ),
      ]);
      expect(h.delta, Delta()..insert('abc\n'));
      expect(h.changes, isEmpty);
    });
  });
}
