// Tests for WONKY PATCH SE-6: content drag delegate.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

class _Delegate implements ContentDragDelegate {
  _Delegate({required this.accept});

  final bool accept;
  final events = <String>[];
  DocumentPosition? lastPosition;

  @override
  bool onDragStart(ContentDragDetails details) {
    events.add('start');
    return accept;
  }

  @override
  void onDragUpdate(ContentDragDetails details) {
    events.add('update');
    lastPosition = details.position;
  }

  @override
  void onDragEnd(ContentDragDetails details) => events.add('end');

  @override
  void onDragCancel() => events.add('cancel');
}

Future<(Editor, MutableDocumentComposer)> _pump(
  WidgetTester tester,
  ContentDragDelegate delegate,
) async {
  final document = MutableDocument(nodes: [
    ParagraphNode(id: 'p', text: AttributedText('Hello world, this is text')),
  ]);
  final composer = MutableDocumentComposer(
    initialSelection: const DocumentSelection(
      base: DocumentPosition(
          nodeId: 'p', nodePosition: TextNodePosition(offset: 0)),
      extent: DocumentPosition(
          nodeId: 'p', nodePosition: TextNodePosition(offset: 5)),
    ),
  );
  final editor =
      createDefaultDocumentEditor(document: document, composer: composer);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SuperEditor(
        editor: editor,
        gestureMode: DocumentGestureMode.mouse,
        contentDragDelegate: delegate,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return (editor, composer);
}

Future<void> _drag(WidgetTester tester) async {
  final text = find.byType(SuperEditor);
  final start = tester.getTopLeft(text) + const Offset(30, 30);
  final gesture =
      await tester.startGesture(start, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(const Offset(20, 0));
  await tester.pump();
  await gesture.moveBy(const Offset(60, 0));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('SE-6 content drag delegate >', () {
    testWidgets('an accepting delegate owns the drag and the selection stays',
        (tester) async {
      final delegate = _Delegate(accept: true);
      final (_, composer) = await _pump(tester, delegate);
      final before = composer.selection;

      await _drag(tester);

      expect(delegate.events.first, 'start');
      expect(delegate.events.where((e) => e == 'update'), isNotEmpty);
      expect(delegate.events.last, 'end');
      expect(delegate.lastPosition?.nodeId, 'p');
      expect(composer.selection, before);
    });

    testWidgets(
        'a refusing delegate leaves the drag to the editor (drag selection)',
        (tester) async {
      final delegate = _Delegate(accept: false);
      final (_, composer) = await _pump(tester, delegate);
      final before = composer.selection;

      await _drag(tester);

      expect(delegate.events, ['start']);
      expect(composer.selection, isNot(before));
    });
  });
}
