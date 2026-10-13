// Tests for WONKY PATCH SE-4: editable tables (cell content builder).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

TableBlockNode _table() => TableBlockNode(
      id: 't',
      cells: [
        [
          TextNode(id: 'h0', text: AttributedText('Name')),
          TextNode(id: 'h1', text: AttributedText('Qty')),
        ],
        [
          TextNode(id: 'c0', text: AttributedText('Apples')),
          TextNode(id: 'c1', text: AttributedText('3')),
        ],
      ],
    );

Widget _component(TableCellContentBuilder? cellBuilder) {
  final document = MutableDocument(nodes: [_table()]);
  final viewModel = const MarkdownTableComponentBuilder()
      .createViewModel(document, document.first) as MarkdownTableViewModel;
  return MaterialApp(
    home: Scaffold(
      body: MarkdownTableComponent(
        componentKey: GlobalKey(),
        viewModel: viewModel,
        cellBuilder: cellBuilder,
      ),
    ),
  );
}

void main() {
  group('SE-4 table cell builder >', () {
    testWidgets('without a builder the cells render read-only text',
        (tester) async {
      await tester.pumpWidget(_component(null));

      expect(find.text('Apples', findRichText: true), findsOneWidget);
      expect(find.byType(IgnorePointer), findsWidgets);
    });

    testWidgets('the builder is called for every cell with its coordinates',
        (tester) async {
      final seen = <(String, int, int, bool)>[];
      await tester.pumpWidget(_component((context, cell) {
        seen.add(
            (cell.tableNodeId, cell.rowIndex, cell.columnIndex, cell.isHeader));
        return null;
      }));

      expect(seen.toSet(), {
        ('t', 0, 0, true),
        ('t', 0, 1, true),
        ('t', 1, 0, false),
        ('t', 1, 1, false),
      });
      expect(find.text('Qty', findRichText: true), findsOneWidget);
    });

    testWidgets('a built cell replaces the default content and receives taps',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_component((context, cell) {
        if (cell.rowIndex != 1 || cell.columnIndex != 0) return null;
        return GestureDetector(
          onTap: () => taps += 1,
          child: Text('edit ${cell.cell.text.toPlainText()}'),
        );
      }));

      await tester.tap(find.text('edit Apples'));

      expect(taps, 1);
      expect(find.text('Apples', findRichText: true), findsNothing);
    });
  });
}
