/// Test helpers for screens with a [WonkyRichEditor] (suite 15 §7). Never
/// import from `lib/` code.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'wonky_rich_editor.dart';

/// The state of the rich editor at [finder]: the editor itself, its field
/// key (`<fieldKey>`), or a widget around it.
WonkyRichEditorState richEditorStateOf(WidgetTester tester, Finder finder) {
  var editors = find.descendant(
    of: finder,
    matching: find.byType(WonkyRichEditor),
    matchRoot: true,
  );
  if (editors.evaluate().isEmpty) {
    editors = find.ancestor(of: finder, matching: find.byType(WonkyRichEditor));
  }
  return tester.state<WonkyRichEditorState>(editors.first);
}

/// Replaces the Markdown of the rich editor at [finder], like
/// `WidgetTester.enterText` does for a text field (focus, then the text).
Future<void> enterMarkdown(
  WidgetTester tester,
  Finder finder,
  String markdown,
) async {
  final state = richEditorStateOf(tester, finder);
  state.focus();
  await tester.pump();
  state.controller.markdown = markdown;
  await tester.pump();
}

/// Focuses the rich editor at [finder] and types [text] through the IME,
/// character by character (autoformat runs as it does for a person).
Future<void> typeMarkdown(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  richEditorStateOf(tester, finder).focus();
  await tester.pump();
  await tester.typeImeText(text);
  await tester.pump();
}

/// Focuses the rich editor at [finder] and selects [start]…[end] (a
/// caret when [end] is null) in its block number [block].
Future<void> selectRichText(
  WidgetTester tester,
  Finder finder,
  int start, {
  int? end,
  int block = 0,
}) async {
  final state = richEditorStateOf(tester, finder);
  state.focus();
  await tester.pump();
  final c = state.controller;
  final id = c.document.getNodeAt(block)!.id;
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
      SelectionChangeType.expandSelection,
      SelectionReason.userInteraction,
    ),
  ]);
  await tester.pump();
}
