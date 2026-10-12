import 'dart:math';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_write/features/editor/controller/editor_pipeline.dart';
import 'package:wonky_write/features/editor/extractor/change_delta_extractor.dart';

import '../support/delta_gen.dart';

void main() {
  var ids = 0;
  String newId() => 'n${ids++}';

  late EditorPipeline pipeline;
  late List<ExtractedChange> changes;

  void setUpWith(Delta delta) {
    changes = [];
    pipeline = EditorPipeline(
      initialDelta: delta,
      newNodeId: newId,
      verifyInvariants: true,
      onTransaction: (extracted, _) => changes.addAll(extracted),
    );
  }

  DocumentPosition at(int offset) => pipeline.mirror.positionAt(offset)!;

  group('Given a paragraph', () {
    setUp(() => setUpWith(Delta()..insert('Hello world\n')));

    test('when typing a character then the change is an insertion classified as typing', () {
      pipeline.editor.execute([InsertTextRequest(documentPosition: at(5), textToInsert: '!', attributions: {})]);

      expect(changes.single.delta, Delta()
        ..retain(5)
        ..insert('!'));
      expect(changes.single.inverse, Delta()
        ..retain(5)
        ..delete(1));
      expect(changes.single.kind, LocalChangeKind.typing);
    });

    test('when bolding a word then the change is a retain with the bold attribute', () {
      pipeline.editor.execute([
        AddTextAttributionsRequest(
          documentRange: DocumentRange(start: at(0), end: at(5)),
          attributions: {boldAttribution},
        ),
      ]);

      expect(changes.single.delta, Delta()..retain(5, {'bold': true}));
      expect(changes.single.kind, LocalChangeKind.other);
    });

    test('when changing the block type then only the line end changes', () {
      pipeline.editor.execute([
        ChangeParagraphBlockTypeRequest(nodeId: pipeline.document.first.id, blockType: header2Attribution),
      ]);

      expect(changes.single.delta, Delta()
        ..retain(11)
        ..retain(1, {'header': 2}));
    });

    test('when only a presentation attribution changes then no change is reported', () {
      pipeline.editor.execute([
        AddTextAttributionsRequest(
          documentRange: DocumentRange(start: at(0), end: at(5)),
          attributions: {spellingErrorAttribution},
        ),
      ]);

      expect(changes, isEmpty);
    });

    test('when a reaction checkpoints a transaction then each segment is its own change', () {
      pipeline.editor.reactionPipeline.add(FunctionalEditReaction(react: (context, dispatcher, changeList) {
        final hasTyping = changeList.whereType<DocumentEdit>().any((e) => e.change is TextInsertionEvent);
        if (!hasTyping) return;
        pipeline.extractor.checkpoint(changeList, labelForNextSegment: 'Autoformat');
        dispatcher.execute([
          AddTextAttributionsRequest(
            documentRange: DocumentRange(start: at(0), end: at(5)),
            attributions: {italicsAttribution},
          ),
        ]);
        pipeline.extractor.checkpoint(changeList);
      }));

      pipeline.editor.execute([InsertTextRequest(documentPosition: at(11), textToInsert: '?', attributions: {})]);

      expect(changes, hasLength(2));
      expect(changes[0].label, isNull);
      expect(changes[1].label, 'Autoformat');
      expect(changes[1].delta, Delta()..retain(5, {'italic': true}));
    });
  });

  group('Given random documents and random editor requests', () {
    for (final seed in propertySeeds()) {
      test('when executing them (seed $seed) then every extracted change composes to the new document', () {
        final gen = DeltaGen(Random(seed));
        for (var run = 0; run < propertyRuns(20); run += 1) {
          setUpWith(gen.document(maxLines: 8));
          var expected = pipeline.delta;
          for (var step = 0; step < 10; step += 1) {
            final requests = _randomRequests(gen, pipeline);
            if (requests.isEmpty) continue;
            changes.clear();
            pipeline.editor.execute(requests);
            for (final change in changes) {
              expected = expected.compose(change.delta);
            }
            final actual = pipeline.mapper.deltaFromDocument(pipeline.document);
            expect(expected, actual, reason: 'seed $seed run $run step $step: $requests');
          }
          pipeline.dispose();
        }
      });
    }
  });
}

List<EditRequest> _randomRequests(DeltaGen gen, EditorPipeline pipeline) {
  final document = pipeline.document;
  final nodes = document.toList();
  final node = gen.pick(nodes);
  final textNodes = nodes.whereType<TextNode>().toList();
  DocumentPosition textPosition(TextNode n) => DocumentPosition(
        nodeId: n.id,
        nodePosition: TextNodePosition(offset: gen.random.nextInt(n.text.length + 1)),
      );
  DocumentPosition anyPosition() {
    final n = gen.pick(nodes);
    return n is TextNode
        ? textPosition(n)
        : DocumentPosition(
            nodeId: n.id,
            nodePosition: gen.chance(0.5)
                ? const UpstreamDownstreamNodePosition.upstream()
                : const UpstreamDownstreamNodePosition.downstream(),
          );
  }

  DocumentRange orderedRange(DocumentPosition a, DocumentPosition b) {
    final oa = pipeline.mirror.offsetOf(a)!;
    final ob = pipeline.mirror.offsetOf(b)!;
    return oa <= ob ? DocumentRange(start: a, end: b) : DocumentRange(start: b, end: a);
  }

  switch (gen.random.nextInt(11)) {
    case 0 || 1:
      if (textNodes.isEmpty) return const [];
      return [
        InsertTextRequest(
          documentPosition: textPosition(gen.pick(textNodes)),
          textToInsert: gen.chance(0.8) ? 'x' : 'two words',
          attributions: gen.chance(0.3) ? {boldAttribution} : {},
        ),
      ];
    case 2:
      if (textNodes.isEmpty) return const [];
      final n = gen.pick(textNodes);
      final a = textPosition(n);
      final b = textPosition(n);
      return [DeleteContentRequest(documentRange: orderedRange(a, b))];
    case 3:
      return [DeleteContentRequest(documentRange: orderedRange(anyPosition(), anyPosition()))];
    case 4:
      if (textNodes.isEmpty) return const [];
      final n = gen.pick(textNodes);
      final a = textPosition(n);
      final b = textPosition(n);
      return [
        AddTextAttributionsRequest(documentRange: orderedRange(a, b), attributions: {italicsAttribution}),
      ];
    case 5:
      if (node is! ParagraphNode) return const [];
      return [
        ChangeParagraphBlockTypeRequest(
          nodeId: node.id,
          blockType: gen.pick([header1Attribution, blockquoteAttribution, paragraphAttribution, codeAttribution]),
        ),
      ];
    case 6:
      if (node is ParagraphNode) {
        return [ConvertParagraphToListItemRequest(nodeId: node.id, type: ListItemType.unordered)];
      }
      if (node is ListItemNode) {
        return [IndentListItemRequest(nodeId: node.id)];
      }
      if (node is TaskNode) {
        return [ChangeTaskCompletionRequest(nodeId: node.id, isComplete: !node.isComplete)];
      }
      return const [];
    case 7:
      if (nodes.length < 2) return const [];
      return [DeleteNodeRequest(nodeId: node.id)];
    case 8:
      return [
        InsertNodeAtIndexRequest(
          nodeIndex: gen.random.nextInt(nodes.length + 1),
          newNode: gen.chance(0.5)
              ? HorizontalRuleNode(id: gen.nextId('hr'))
              : ParagraphNode(id: gen.nextId('p'), text: AttributedText('inserted')),
        ),
      ];
    case 9:
      return [MoveNodeRequest(nodeId: node.id, newIndex: gen.random.nextInt(nodes.length))];
    default:
      // Several requests in one transaction (far apart).
      if (textNodes.length < 2) return const [];
      return [
        InsertTextRequest(documentPosition: textPosition(textNodes.first), textToInsert: 'A', attributions: {}),
        InsertTextRequest(documentPosition: textPosition(textNodes.last), textToInsert: 'Z', attributions: {}),
      ];
  }
}
