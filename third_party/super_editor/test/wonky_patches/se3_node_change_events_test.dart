// Tests for WONKY PATCH SE-3 (detailed change events) and the SE-5 list fixes.
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('SE-3 detailed change events >', () {
    late MutableDocument document;
    late Editor editor;
    late List<DocumentChange> changes;

    setUp(() {
      document = MutableDocument(nodes: [
        ParagraphNode(id: 'p', text: AttributedText('Title')),
        ListItemNode.unordered(id: 'l1', text: AttributedText('one')),
        ListItemNode.unordered(id: 'l2', text: AttributedText('two'), indent: 1),
        TaskNode(id: 't1', text: AttributedText('task'), isComplete: false),
        TaskNode(id: 't2', text: AttributedText('sub'), isComplete: false),
      ]);
      editor = createDefaultDocumentEditor(document: document, composer: MutableDocumentComposer());
      changes = [];
      editor.addListener(FunctionalEditListener((events) {
        changes.addAll(events.whereType<DocumentEdit>().map((e) => e.change));
      }));
    });

    test('block type changes report before and after', () {
      editor.execute([ChangeParagraphBlockTypeRequest(nodeId: 'p', blockType: header2Attribution)]);

      expect(
        changes.single,
        isA<BlockTypeChangeEvent>()
            .having((e) => e.before, 'before', paragraphAttribution)
            .having((e) => e.after, 'after', header2Attribution),
      );
    });

    test('list item type changes report before and after and keep the indent', () {
      editor.execute([ChangeListItemTypeRequest(nodeId: 'l2', newType: ListItemType.ordered)]);

      expect(
        changes.single,
        isA<ListItemTypeChangeEvent>()
            .having((e) => e.before, 'before', ListItemType.unordered)
            .having((e) => e.after, 'after', ListItemType.ordered),
      );
      expect((document.getNodeById('l2') as ListItemNode).indent, 1);
    });

    test('indentation changes report before and after', () {
      editor.execute([IndentListItemRequest(nodeId: 'l2')]);
      editor.execute([const IndentTaskRequest('t2')]);

      expect(changes[0], isA<IndentChangeEvent>().having((e) => e.after, 'after', 2));
      expect(changes[1], isA<IndentChangeEvent>().having((e) => e.before, 'before', 0).having((e) => e.after, 'after', 1));
    });

    test('list items indent up to level 8', () {
      for (int i = 0; i < 10; i += 1) {
        editor.execute([IndentListItemRequest(nodeId: 'l2')]);
      }

      expect((document.getNodeById('l2') as ListItemNode).indent, maxListItemIndent);
      expect(maxListItemIndent, 8);
    });

    test('task completion changes report before and after', () {
      editor.execute([ChangeTaskCompletionRequest(nodeId: 't1', isComplete: true)]);

      expect(
        changes.single,
        isA<TaskCompletionChangeEvent>().having((e) => e.before, 'before', false).having((e) => e.after, 'after', true),
      );
    });

    test('node conversions report the replaced nodes', () {
      editor.execute([ConvertParagraphToListItemRequest(nodeId: 'p', type: ListItemType.ordered)]);

      expect(
        changes.single,
        isA<NodeReplacedEvent>()
            .having((e) => e.before, 'before', isA<ParagraphNode>())
            .having((e) => e.after, 'after', isA<ListItemNode>()),
      );
    });

    test('metadata changes report the changed keys', () {
      editor.execute([
        const ChangeNodeMetadataRequest(nodeId: 'p', metadata: {'codeLanguage': 'dart'}),
      ]);

      expect(
        changes.single,
        isA<NodeMetadataChangeEvent>()
            .having((e) => e.before, 'before', isEmpty)
            .having((e) => e.after, 'after', {'codeLanguage': 'dart'}),
      );
      expect(document.getNodeById('p')!.getMetadataValue('codeLanguage'), 'dart');
    });
  });
}
