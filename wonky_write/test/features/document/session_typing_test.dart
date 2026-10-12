import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:wonky_write/features/editor/ui/wonky_editor.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../sync/support/fake_document_server.dart';
import 'support/session_harness.dart';

Future<SessionHarness> _pump(WidgetTester tester, Delta initial) async {
  final server = FakeDocumentServer(initial: initial);
  final h = SessionHarness(server);
  addTearDown(() => tester.runAsync(h.dispose));
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: h.session.phase,
          builder: (context, phase, _) => phase.name == 'ready'
              ? WonkyEditor(controller: h.session.editor, documentTitle: 'Doc')
              : const SizedBox(),
        ),
      ),
    ),
  );
  await tester.runAsync(() => h.open());
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets(
    'Given an opened session in the editor widget when typing then the text reaches the server and is undoable',
    (tester) async {
      final h = await _pump(tester, Delta()..insert('Hi\n'));

      await tester.placeCaretInParagraph(h.session.editor.document.first.id, 2);
      await tester.typeImeText(' there');
      await tester.pump();
      await tester.runAsync(pumpEventQueue);

      expect(DeltaUtils.text(h.doc), 'Hi there\n');
      expect(DeltaUtils.text(h.server.document), 'Hi there\n');
      expect(h.undo.canUndo.value, isTrue);
    },
  );

  testWidgets(
    'Given a blank document when tapping into it and typing then the change is synced',
    (tester) async {
      final h = await _pump(tester, Delta()..insert('\n'));

      await tester.tapAt(const Offset(300, 60));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.typeImeText('abc');
      await tester.pump();
      await tester.runAsync(pumpEventQueue);

      expect(
        h.session.editor.mirror.toDelta(),
        h.session.editor.mapper.deltaFromDocument(h.session.editor.document),
      );
      expect(DeltaUtils.text(h.server.document), 'abc\n');
    },
  );
}
