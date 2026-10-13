// Tests for WONKY PATCH SE-7: list markers don't inherit text highlights.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

const _highlight = NamedAttribution('highlight');
const _red = Color(0xFFFF0000);

Future<void> _pump(WidgetTester tester, ListItemNode node) async {
  final text = AttributedText('Highlighted item')
    ..addAttribution(_highlight, const SpanRange(0, 10));
  final document = MutableDocument(nodes: [node.copyListItemWith(text: text)]);
  final editor = createDefaultDocumentEditor(
    document: document,
    composer: MutableDocumentComposer(),
  );
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SuperEditor(
        editor: editor,
        stylesheet: defaultStylesheet.copyWith(
          inlineTextStyler: (attributions, style) {
            final base = defaultInlineTextStyler(attributions, style);
            return attributions.contains(_highlight)
                ? base.copyWith(
                    backgroundColor: _red,
                    decoration: TextDecoration.lineThrough,
                  )
                : base;
          },
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// The style of the marker: the rich text that isn't the item's text.
TextStyle _markerStyle(WidgetTester tester, Type component) {
  final marker = tester
      .widgetList<RichText>(
        find.descendant(of: find.byType(component), matching: find.byType(RichText)),
      )
      .firstWhere((r) => !r.text.toPlainText().contains('Highlighted'));
  final span = marker.text as TextSpan;
  return (span.children?.whereType<TextSpan>().firstOrNull ?? span).style ??
      span.style!;
}

void main() {
  group('SE-7 list marker style >', () {
    testWidgets('a highlighted first character does not highlight the bullet',
        (tester) async {
      await _pump(
        tester,
        ListItemNode.unordered(id: 'l', text: AttributedText()),
      );

      final style = _markerStyle(tester, UnorderedListItemComponent);
      expect(style.backgroundColor, isNull);
      expect(style.decoration, isNull);
      expect(style.fontSize, isNotNull);
    });

    testWidgets('a highlighted first character does not highlight the numeral',
        (tester) async {
      await _pump(
        tester,
        ListItemNode.ordered(id: 'l', text: AttributedText()),
      );

      final style = _markerStyle(tester, OrderedListItemComponent);
      expect(style.backgroundColor, isNull);
      expect(style.decoration, isNull);
    });
  });
}
