import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_write/features/editor/components/wonky_components.dart';
import 'package:wonky_write/features/editor/styles/editor_theme.dart';
import 'package:wonky_write/features/editor/ui/wonky_editor.dart';

import '../support/editor_harness.dart';

Delta _codeBlock(String language, List<String> lines) {
  final delta = Delta()..insert('Intro\n');
  for (final line in lines) {
    delta
      ..insert(line)
      ..insert('\n', {'code-block': language});
  }
  return delta..insert('Outro\n');
}

Future<EditorHarness> _pump(
  WidgetTester tester,
  Delta delta, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final h = EditorHarness(delta);
  addTearDown(h.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WonkyEditor(controller: h.controller, documentTitle: 'Test doc'),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return h;
}

String _codeNodeId(EditorHarness h) => h.controller.document.toList()[1].id;

Finder _box(String nodeId) =>
    find.byKey(ValueKey('${WonkyEditorKeys.codeBlock}.$nodeId'));

/// The text spans rendered inside the code block box.
List<TextSpan> _spans(WidgetTester tester, String nodeId) {
  final spans = <TextSpan>[];
  for (final text in tester.widgetList<RichText>(
    find.descendant(
      of: _box(nodeId),
      matching: find.byWidgetPredicate((w) => w is RichText),
    ),
  )) {
    text.text.visitChildren((span) {
      if (span is TextSpan && (span.text ?? '').isNotEmpty) spans.add(span);
      return true;
    });
  }
  return spans;
}

void main() {
  final theme = EditorTheme.fallback(Brightness.light);

  group('Given a three-line Dart code block', () {
    const lines = ['final x = 1;', '', '// done'];

    testWidgets('then it renders as one padded box around all its lines', (
      tester,
    ) async {
      final h = await _pump(tester, _codeBlock('dart', lines));
      final nodeId = _codeNodeId(h);

      expect(_box(nodeId), findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: _box(nodeId), matching: find.byType(DecoratedBox)),
      );
      expect(
        box.decoration,
        isA<BoxDecoration>().having(
          (d) => d.color,
          'color',
          theme.codeBlockBackground,
        ),
      );
      final boxRect = tester.getRect(_box(nodeId));
      final textRect = tester.getRect(
        find.descendant(of: _box(nodeId), matching: find.byType(TextComponent)),
      );
      expect(textRect.left - boxRect.left, theme.codeBlockPadding.left);
      expect(textRect.top - boxRect.top, theme.codeBlockPadding.top);
      expect(boxRect.bottom - textRect.bottom, theme.codeBlockPadding.bottom);
      expect(
        _spans(tester, nodeId).map((s) => s.text).join(),
        lines.join('\n'),
      );
    });

    testWidgets('then the code is set in JetBrains Mono', (tester) async {
      final h = await _pump(tester, _codeBlock('dart', lines));

      final families = {
        for (final span in _spans(tester, _codeNodeId(h)))
          span.style?.fontFamily,
      };

      expect(families, {'JetBrains Mono'});
    });

    testWidgets('then keywords and comments are colored from the theme', (
      tester,
    ) async {
      final h = await _pump(tester, _codeBlock('dart', lines));

      final spans = _spans(tester, _codeNodeId(h));

      expect(
        spans,
        contains(
          isA<TextSpan>()
              .having((s) => s.text, 'text', 'final')
              .having((s) => s.style?.color, 'color', theme.syntax['keyword']),
        ),
      );
      expect(
        spans,
        contains(
          isA<TextSpan>()
              .having((s) => s.text, 'text', '// done')
              .having((s) => s.style?.color, 'color', theme.syntax['comment']),
        ),
      );
    });

    testWidgets('when tapping in the box padding then the caret goes into '
        'the block', (tester) async {
      final h = await _pump(tester, _codeBlock('dart', lines));
      final nodeId = _codeNodeId(h);
      final boxRect = tester.getRect(_box(nodeId));

      await tester.tapAt(boxRect.topLeft + const Offset(4, 4));
      await tester.pump(kTapMinTime + const Duration(milliseconds: 1));
      await tester.pump(kTapTimeout);
      await tester.pumpAndSettle();

      final selection = h.editor.composer.selection;
      expect(selection?.extent.nodeId, nodeId);
      expect(selection?.extent.nodePosition, const TextNodePosition(offset: 0));
    });
  });

  testWidgets('Given a Go block when it is first shown then it is already '
      'highlighted (no plain flash while a grammar loads)', (tester) async {
    final h = await _pump(
      tester,
      _codeBlock('go', ['func main() {}']),
      settle: false,
    );
    final nodeId = _codeNodeId(h);

    expect(
      _spans(tester, nodeId),
      contains(
        isA<TextSpan>()
            .having((s) => s.text, 'text', 'func')
            .having((s) => s.style?.color, 'color', theme.syntax['keyword']),
      ),
    );
  });

  testWidgets('Given a code block in a language without a grammar then it '
      'renders plain in the box', (tester) async {
    final h = await _pump(tester, _codeBlock('bash', ['echo "hi" # c']));
    final nodeId = _codeNodeId(h);

    expect(_box(nodeId), findsOneWidget);
    expect(
      {for (final span in _spans(tester, nodeId)) span.style?.color},
      {theme.codeBlock.color},
    );
  });
}
