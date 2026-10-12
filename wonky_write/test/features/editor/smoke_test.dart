import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  testWidgets('smoke', (tester) async {
    final doc = MutableDocument(nodes: [ParagraphNode(id: '1', text: AttributedText('hi'))]);
    final composer = MutableDocumentComposer();
    final editor = createDefaultDocumentEditor(document: doc, composer: composer, isHistoryEnabled: false);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SuperEditor(editor: editor))));
    expect(find.byType(SuperEditor), findsOneWidget);
  });
}
