import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:wonky_rich_editor/testing.dart';
import 'package:wonky_rich_editor/wonky_rich_editor.dart';
import 'package:wonky_ui/testing.dart';

/// The editor has no code blocks (specs/16 §7.3): fenced code set or pasted
/// as Markdown is a literal block, and every way of editing or deleting
/// around it works like with a paragraph and never throws. Keys go through
/// the hardware keyboard first and then the IME, like in a browser.

Finder _key(String k) => find.byKey(ValueKey<String>(k));

/// A paragraph, a fenced block and a paragraph: blocks 0, 1 and 2.
const _fenced = 'before\n\n```dart\nfinal x = 1;\n```\n\nafter';

/// The plain text of the fenced block.
const _code = '```dart\nfinal x = 1;\n```';

Future<MarkdownEditingController> _pump(
  WidgetTester tester, {
  String markdown = _fenced,
}) async {
  final c = MarkdownEditingController(markdown: markdown);
  addTearDown(c.dispose);
  await pumpWonky(
    tester,
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 500,
        child: WonkyRichEditor(controller: c, maxHeight: 600),
      ),
    ),
  );
  richEditorStateOf(tester, _key('markdown.composer')).focus();
  await tester.pump();
  return c;
}

List<String> _kinds(MarkdownEditingController c) =>
    c.document.map(MarkdownDocumentCodec.kindOf).toList();

List<String> _texts(MarkdownEditingController c) => [
  for (final n in c.document)
    if (n is TextNode) n.text.toPlainText() else '-',
];

DocumentPosition _at(MarkdownEditingController c, int block, int offset) =>
    DocumentPosition(
      nodeId: c.document.getNodeAt(block)!.id,
      nodePosition: TextNodePosition(offset: offset),
    );

Future<void> _select(
  WidgetTester tester,
  MarkdownEditingController c,
  DocumentPosition base, [
  DocumentPosition? extent,
]) async {
  c.editor.execute([
    ChangeSelectionRequest(
      DocumentSelection(base: base, extent: extent ?? base),
      SelectionChangeType.placeCaret,
      SelectionReason.userInteraction,
    ),
  ]);
  await tester.pump();
}

/// Backspace: the editor's key handling, else the IME's deletion.
Future<void> _backspace(WidgetTester tester) async {
  if (!await tester.sendKeyEvent(LogicalKeyboardKey.backspace)) {
    await tester.ime.backspace(getter: imeClientGetter);
  }
  await tester.pump();
}

/// Delete (forward): the editor's key handling, else the IME's selector.
Future<void> _delete(WidgetTester tester) async {
  if (!await tester.sendKeyEvent(LogicalKeyboardKey.delete)) {
    imeClientGetter().performSelector(MacOsSelectors.deleteForward);
  }
  await tester.pump();
}

Future<void> _enter(WidgetTester tester) async {
  await tester.pressEnterAdaptive(getter: imeClientGetter);
  await tester.pump();
}

Future<void> _chord(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pump();
}

/// Undoes everything with `Mod+Z`; the content is [_fenced] again.
Future<void> _undoAll(WidgetTester tester, MarkdownEditingController c) async {
  var steps = 0;
  while (c.canUndo && steps++ < 50) {
    await _chord(tester, LogicalKeyboardKey.keyZ);
  }
  expect(tester.takeException(), isNull);
  expect(c.markdown, _fenced, reason: 'undo restores the literal block');
  expect(_kinds(c), ['p', 'raw', 'p']);
}

/// The Markdown reads back as the same blocks (nothing is lost or added).
void _expectStable(MarkdownEditingController c) {
  final back = MarkdownEditingController(markdown: c.markdown);
  addTearDown(back.dispose);
  expect(_texts(back), _texts(c), reason: c.markdown);
}

void main() {
  group('Given fenced code in the field', () {
    testWidgets('then it is one literal block in a box, the toolbar has no '
        'Code block button and typing a fence keeps it text', (tester) async {
      final c = await _pump(tester);

      expect(_kinds(c), ['p', 'raw', 'p']);
      expect(_texts(c)[1], _code);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Markdown',
        ),
        findsOneWidget,
        reason: 'the literal box',
      );
      expect(_key('markdown.composer.codeBlock'), findsNothing);
      expect(_key('markdown.composer.code'), findsOneWidget);

      await _select(tester, c, _at(c, 2, 5));
      await _enter(tester);
      await tester.typeImeText('```dart');
      await _enter(tester);
      await tester.typeImeText('``` x');
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'raw', 'p', 'p', 'p']);
      expect(_texts(c).sublist(3), ['```dart', '``` x']);
      _expectStable(c);
      await settleTooltips(tester);
    });

    testWidgets('when Backspace is pressed at its start then it becomes a '
        'paragraph, then joins the one before', (tester) async {
      final c = await _pump(tester);
      await _select(tester, c, _at(c, 1, 0));

      await _backspace(tester);
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'p', 'p']);
      expect(_texts(c)[1], _code);
      _expectStable(c);

      await _backspace(tester);
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'p']);
      expect(_texts(c), ['before$_code', 'after']);
      _expectStable(c);

      await _undoAll(tester, c);
    });

    testWidgets('when Backspace is pressed at the start of the paragraph '
        'after it then that text joins the literal block', (tester) async {
      final c = await _pump(tester);
      await _select(tester, c, _at(c, 2, 0));

      await _backspace(tester);
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'raw']);
      expect(_texts(c)[1], '${_code}after');
      expect(c.markdown, 'before\n\n${_code}after');

      await _undoAll(tester, c);
    });

    testWidgets('when Delete is pressed at the end of the paragraph before it '
        'then the literal text joins that paragraph', (tester) async {
      final c = await _pump(tester);
      await _select(tester, c, _at(c, 0, 6));

      await _delete(tester);
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'p']);
      expect(_texts(c), ['before$_code', 'after']);
      _expectStable(c);

      await _undoAll(tester, c);
    });

    testWidgets('when Delete is pressed at its end then the paragraph after '
        'it joins it', (tester) async {
      final c = await _pump(tester);
      await _select(tester, c, _at(c, 1, _code.length));

      await _delete(tester);
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'raw']);
      expect(_texts(c)[1], '${_code}after');

      await _undoAll(tester, c);
    });

    testWidgets('when its whole text is selected and deleted then it is gone '
        'from the Markdown, and Backspace removes the empty block', (
      tester,
    ) async {
      final c = await _pump(tester);
      await _select(tester, c, _at(c, 1, 0), _at(c, 1, _code.length));

      await _backspace(tester);
      expect(tester.takeException(), isNull);
      expect(c.markdown, 'before\n\nafter');

      await _backspace(tester);
      await _backspace(tester);
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'p']);
      expect(c.markdown, 'before\n\nafter');

      await _undoAll(tester, c);
    });

    testWidgets('when a selection across it is deleted or typed over then '
        'the paragraphs around it join', (tester) async {
      final c = await _pump(tester);
      await _select(tester, c, _at(c, 0, 3), _at(c, 2, 2));

      await _backspace(tester);
      expect(tester.takeException(), isNull);
      expect(c.markdown, 'befter');
      await _undoAll(tester, c);

      await _select(tester, c, _at(c, 0, 3), _at(c, 2, 2));
      await tester.typeImeText('X');
      expect(tester.takeException(), isNull);
      expect(c.markdown, 'befXter');
      await _undoAll(tester, c);
    });

    testWidgets('when a selection from inside it is deleted then the rest '
        'stays literal', (tester) async {
      final c = await _pump(tester);
      await _select(tester, c, _at(c, 1, 8), _at(c, 2, 3));

      await _backspace(tester);
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'raw']);
      expect(_texts(c)[1], '```dart\ner');

      await _undoAll(tester, c);
    });

    testWidgets('when everything is selected and deleted then the field is '
        'empty', (tester) async {
      final c = await _pump(tester);
      c.selectAll();
      await tester.pump();

      await _backspace(tester);
      expect(tester.takeException(), isNull);
      expect(c.markdown, isEmpty);
      expect(_kinds(c).length, 1);

      await _undoAll(tester, c);
    });

    testWidgets('when it is cut across blocks and pasted back then the '
        'content is the same', (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final c = await _pump(tester);
      await _select(tester, c, _at(c, 0, 3), _at(c, 2, 2));

      await _chord(tester, LogicalKeyboardKey.keyX);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(clipboard, 'ore\n\n$_code\n\naf');
      expect(c.markdown, 'befter');

      await _chord(tester, LogicalKeyboardKey.keyV);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(c.markdown, _fenced);
      expect(_kinds(c), ['p', 'raw', 'p']);
    });

    testWidgets('when typing and pressing Enter inside it then the text stays '
        'literal, and Enter twice at its end leaves it', (tester) async {
      final c = await _pump(tester);
      await _select(tester, c, _at(c, 1, '```dart\nfinal x = 1;'.length));

      await tester.typeImeText(' // **ok**');
      await _enter(tester);
      await tester.typeImeText('y');
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'raw', 'p']);
      expect(_texts(c)[1], '```dart\nfinal x = 1; // **ok**\ny\n```');
      expect(c.markdown, contains('final x = 1; // **ok**\ny\n```'));

      await _select(tester, c, _at(c, 1, _texts(c)[1].length));
      await _enter(tester);
      await _enter(tester);
      await tester.typeImeText('z');
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'raw', 'p', 'p']);
      expect(_texts(c)[2], 'z');

      await _undoAll(tester, c);
    });

    testWidgets('when Enter is pressed over a selection in it then the '
        'selection becomes a line break at that place', (tester) async {
      final c = await _pump(tester);
      await _select(tester, c, _at(c, 1, 8), _at(c, 1, 14));

      await _enter(tester);
      await tester.typeImeText('var');
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'raw', 'p']);
      expect(_texts(c)[1], '```dart\n\nvarx = 1;\n```');

      await _undoAll(tester, c);
    });

    testWidgets('when Backspace is held from the end then everything is '
        'deleted without errors', (tester) async {
      final c = await _pump(tester);
      c.moveCaretToEnd();
      await tester.pump();

      var steps = 0;
      while (c.markdown.isNotEmpty) {
        await _backspace(tester);
        expect(tester.takeException(), isNull, reason: 'step $steps');
        expect(++steps, lessThan(80), reason: 'Backspace makes progress');
      }
      expect(_kinds(c).length, 1);

      await _undoAll(tester, c);
    });

    testWidgets('when Delete is held from the start then everything is '
        'deleted without errors', (tester) async {
      final c = await _pump(tester);
      await _select(tester, c, _at(c, 0, 0));

      var steps = 0;
      while (c.markdown.isNotEmpty) {
        await _delete(tester);
        expect(tester.takeException(), isNull, reason: 'step $steps');
        expect(++steps, lessThan(80), reason: 'Delete makes progress');
      }

      await _undoAll(tester, c);
    });

    testWidgets('when it is pasted into a paragraph then it is a literal '
        'block, and removing it leaves the paragraph', (tester) async {
      final c = await _pump(tester, markdown: 'one two');
      await _select(tester, c, _at(c, 0, 3));

      expect(c.paste('\n\n$_code\n\n'), isTrue);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_kinds(c), ['p', 'raw', 'p']);
      expect(c.markdown, 'one\n\n$_code\n\ntwo');

      await _select(tester, c, _at(c, 1, 0), _at(c, 1, _code.length));
      await _backspace(tester);
      await _backspace(tester);
      await _backspace(tester);
      expect(tester.takeException(), isNull);
      expect(c.markdown, 'one\n\ntwo');
    });

    testWidgets('when its node is removed with the caret in it then the '
        'toolbar rebuilds without errors', (tester) async {
      // Board report #5: removing a code block showed "No such position in
      // document" from the toolbar's state check (canFormatInline).
      final c = await _pump(tester, markdown: 'before\n\n```\ncode\n```');
      await _select(tester, c, _at(c, 1, 2));
      c.editor.execute([
        DeleteNodeRequest(nodeId: c.document.getNodeAt(1)!.id),
      ]);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(c.canFormatInline, isFalse);
      expect(c.selection, isNull);
      expect(c.markdown, 'before');
    });
  });
}
