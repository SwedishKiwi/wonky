// Tests for WONKY PATCH SE-8: the selection highlight paints each pixel once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/selection_highlight.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('SE-8 selection highlight >', () {
    testWidgets('a selection over several lines is painted as one path',
        (tester) async {
      final document = MutableDocument(nodes: [
        ParagraphNode(
          id: 'p',
          text: AttributedText('First line\nSecond line\nThird line'),
        ),
      ]);
      final composer = MutableDocumentComposer(
        initialSelection: const DocumentSelection(
          base: DocumentPosition(
              nodeId: 'p', nodePosition: TextNodePosition(offset: 0)),
          extent: DocumentPosition(
              nodeId: 'p', nodePosition: TextNodePosition(offset: 33)),
        ),
      );
      final editor =
          createDefaultDocumentEditor(document: document, composer: composer);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SuperEditor(
            editor: editor,
            gestureMode: DocumentGestureMode.mouse,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final highlight = find.byType(NonOverlappingSelectionHighlight);
      expect(highlight, findsOneWidget);
      final paint = find.descendant(
        of: highlight,
        matching: find.byType(CustomPaint),
      );
      expect(paint, paintsExactlyCountTimes(#drawPath, 1));
      expect(paint, paintsExactlyCountTimes(#drawRRect, 0));

      final painter = tester.widget<CustomPaint>(paint).painter!
          as NonOverlappingSelectionPainter;
      final bounds = painter.selectionPath()!.getBounds();
      // Three lines tall.
      expect(bounds.height, greaterThan(40));
    });
  });
}
